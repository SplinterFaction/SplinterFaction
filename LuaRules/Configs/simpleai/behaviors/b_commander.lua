--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    luarules/configs/simpleai/behaviors/b_commander.lua
--  brief:   Commander behavior for the SimpleAI gadget (stage 4 of the modular
--           split). Owns the commander's survival state machine (committed-
--           haven retreat, so it runs in ONE direction instead of re-rolling
--           every time it's hit), self-defence, and idle building — the last
--           via services.SelectConstructionProject, which b_construction
--           registers, so that module must appear before this one in the
--           core's BEHAVIOR_FILES manifest.
--
--           Owns ctx state: ctx.comm.retreating, ctx.comm.retreatPos,
--           ctx.comm.leash (how far from home the commander may work;
--           b_construction reads it).
--
--           THE LEASH. A side loses the game when its last commander dies,
--           and recordings showed commanders being treated as roaming
--           builders: their distance from home climbed steadily through
--           every game (about 600 elmos at five minutes, 2,500 to 3,700 by
--           the end), and half of all commanders lost died more than 3,000
--           elmos out. Now a commander works within COMM_LEASH of home,
--           walks back if it finds itself outside, retreats toward home
--           (never toward a forward turret), and only fights what comes to
--           it. When it is the LAST commander on its side the leash
--           shortens.
--
--           FIGHT OR ESCAPE. With an enemy close, the commander looks at
--           what is around it: friendly armed units and turrets against
--           enemy ones. If there is a defending force worth the name, it
--           stays and helps it. If there is not, it ESCAPES: it leaves for
--           the safest place its side holds (its own home if that is quiet,
--           otherwise an ally's base) and shelters there until home is
--           clear. A Loz-style commander, which can kill, counts itself as
--           part of the defending force. A Fed-style one, whose disruption
--           weapon disables but cannot kill, does not: it only stands and
--           fights beside units that can finish what it stops.
--
--  license: GNU GPL, v2 or later
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return function(ctx, lib, cfg, services)

	--------------------------------------------------------------------------
	-- Tunables (owned by this behavior)
	--------------------------------------------------------------------------
	local COMM_RETREAT_HP   = 0.65   -- commander starts running below this EFFECTIVE hp fraction
	local COMM_DANGER_R     = 750    -- enemy within this range counts as "in danger" while retreating
	local COMM_HAVEN_REACH  = 250    -- considered "arrived" at a haven within this distance
	local COMM_LEASH        = 1800   -- how far from home the commander works
	local COMM_LEASH_LAST   = 1100   -- ...when it is the last commander on its side
	local COMM_LEASH_SLACK  = 250    -- it is called back once this far past the leash
	local COMM_RECALL_EVERY = 150    -- frames between repeats of the walk-home order
	local COMM_SIDE_RECOUNT = 150    -- frames between recounts of the side's commanders
	local COMM_LOOK_R       = 1200   -- friendly and enemy strength within this of the commander decide fight or escape
	local COMM_DEFEND_RATIO = 0.7    -- "a defending army is present" = friendly strength at least this x enemy strength
	local COMM_SHELTER_R    = 600    -- while sheltering away from home it stays this close to its refuge
	local COMM_HOME_CLEAR_R = 1500   -- home counts as clear when no armed enemy is within this of it
	local COMM_REFUGE_MIN   = 1000   -- a refuge must be at least this far from where the commander is escaping from

	local IsCommander          = ctx.IsCommander
	local SimpleCommRetreating = ctx.comm.retreating
	local SimpleCommRetreatPos = ctx.comm.retreatPos

	local FindCommanderHaven = lib.FindCommanderHaven

	ctx.comm.leash = ctx.comm.leash or {}
	local CommLeash  = ctx.comm.leash     -- [teamID] = current leash (elmos)
	local teamHome   = ctx.home or {}
	local recallAt   = {}                 -- [teamID] = frame the walk-home order may be repeated
	local refuge     = {}                 -- [teamID] = { x, y, z } where the commander is sheltering away from home
	local IsCombat   = ctx.IsCombat or {}
	local IsTurret   = ctx.IsTurret or {}

	local valueOf = {}
	local function UnitValue(unitDefID)
		local v = valueOf[unitDefID]
		if not v then
			local ud = UnitDefs[unitDefID]
			v = (ud and ud.metalCost) or 0
			valueOf[unitDefID] = v
		end
		return v
	end

	-- Does this commander type kill, or only disable? (lib.NonDirectClass:
	-- "disrupt" = every weapon is a disruption weapon.)
	local function CanKill(unitDefID)
		return not (lib.NonDirectClass and lib.NonDirectClass(unitDefID) == "disrupt")
	end

	-- What a unit type counts for in a fight (lib.UnitStrength: metal cost,
	-- except that a commander counts for far more than its price).
	local function Weight(unitDefID)
		if lib.UnitStrength then return lib.UnitStrength(unitDefID) end
		return UnitValue(unitDefID)
	end

	-- Friendly and enemy armed strength (combat units, turrets and
	-- commanders) within `radius` of a point. Enemy commanders always count.
	-- A friendly commander counts only if it is the killing kind, and the
	-- commander asking (selfID) is left out: the caller adds its own weight.
	local function Strength(teamID, x, z, radius, selfID)
		local friendly, enemy = 0, 0
		local near = Spring.GetUnitsInCylinder(x, z, radius)
		for i = 1, #near do
			local uid = near[i]
			local d = Spring.GetUnitDefID(uid)
			if d and uid ~= selfID and (IsCombat[d] or IsTurret[d] or IsCommander[d]) then
				local ut = Spring.GetUnitTeam(uid)
				if ut == teamID or Spring.AreTeamsAllied(teamID, ut) then
					if not IsCommander[d] or CanKill(d) then friendly = friendly + Weight(d) end
				else
					enemy = enemy + Weight(d)
				end
			end
		end
		return friendly, enemy
	end

	-- Where to escape to: the safest place this side holds. Candidates are
	-- the team's own home, every allied team's home, and the best building
	-- haven; the one with the least enemy strength around it wins, nearer
	-- first among equals. It must be somewhere the commander can walk to
	-- and far enough from where it stands to count as getting away.
	local function EscapeSpot(unitID, unitDefID, teamID, allyTeamID, ux, uz, nearEnemy)
		local cands = {}
		local allies = Spring.GetTeamList(allyTeamID) or {}
		for i = 1, #allies do
			local h = teamHome[allies[i]]
			if h then cands[#cands + 1] = { x = h.x, z = h.z } end
		end
		local hv = FindCommanderHaven(unitID, teamID, nearEnemy)
		if hv then cands[#cands + 1] = { x = hv.x, z = hv.z } end
		local best, bestThreat, bestDist
		for i = 1, #cands do
			local c = cands[i]
			local dx, dz = c.x - ux, c.z - uz
			local dist = math.sqrt(dx * dx + dz * dz)
			if dist >= COMM_REFUGE_MIN
					and (not lib.Reachable or lib.Reachable(teamID, unitDefID, c.x, c.z, 200)) then
				local _, threat = Strength(teamID, c.x, c.z, COMM_LOOK_R)
				if not best or threat < bestThreat or (threat == bestThreat and dist < bestDist) then
					best, bestThreat, bestDist = c, threat, dist
				end
			end
		end
		if best then return { x = best.x, y = Spring.GetGroundHeight(best.x, best.z), z = best.z } end
		return hv      -- nowhere better: the old haven (or straight away from the enemy)
	end
	local sideCount  = {}                 -- [teamID] = { n =, frame = } commanders alive on this side

	-- Commanders alive on this team's side, counted from the units
	-- themselves so allied players and other AIs are included.
	local function SideCommanders(teamID, allyTeamID, frame)
		local c = sideCount[teamID]
		if c and (frame - c.frame) < COMM_SIDE_RECOUNT then return c.n end
		local n = 0
		local allies = Spring.GetTeamList(allyTeamID) or {}
		for i = 1, #allies do
			local tUnits = Spring.GetTeamUnits(allies[i])
			for k = 1, #tUnits do
				local d = Spring.GetUnitDefID(tUnits[k])
				if d and IsCommander[d] then n = n + 1 end
			end
		end
		sideCount[teamID] = { n = n, frame = frame }
		return n
	end

	local B = { name = "commander", order = 20 }

	function B.TeamInit(teamID)
		SimpleCommRetreating[teamID] = false
		SimpleCommRetreatPos[teamID] = nil
	end

	--------------------------------------------------------------------------
	-- Ownership: commanders.
	--------------------------------------------------------------------------
	function B.unitFilter(unitDefID)
		return IsCommander[unitDefID] == true
	end

	--------------------------------------------------------------------------
	-- Per-unit commander logic.
	--------------------------------------------------------------------------
	function B.UnitTick(tick, unitID, unitDefID, hpRatio, ux, uy, uz, unitCmds)
		local teamID     = tick.teamID
		local allyTeamID = tick.allyTeamID
		local units      = tick.units
		local allunits   = tick.allUnits

		local frame = tick.frame or 0
		local home  = teamHome[teamID]
		local last  = SideCommanders(teamID, allyTeamID, frame) <= 1
		local leash = last and COMM_LEASH_LAST or COMM_LEASH

		-- Sheltering away from home? Then the refuge is the centre of its
		-- world until home is clear again, and it does no building (leash 0
		-- tells b_construction there is nothing in reach).
		local shelter = refuge[teamID]
		if shelter and home then
			local _, atHome = Strength(teamID, home.x, home.z, COMM_HOME_CLEAR_R)
			if atHome == 0 then
				refuge[teamID] = nil
				shelter = nil
			end
		end
		local cx, cz = home and home.x, home and home.z
		if shelter then
			cx, cz = shelter.x, shelter.z
			leash = COMM_SHELTER_R
		end
		CommLeash[teamID] = shelter and 0 or leash
		local outside = false
		if cx then
			local dx, dz = ux - cx, uz - cz
			local limit = leash + COMM_LEASH_SLACK
			outside = (dx * dx + dz * dz) > limit * limit
		end

		local nearEnemy = Spring.GetUnitNearestEnemy(unitID, COMM_DANGER_R, true)

		-- Is there a defending force here worth standing with?
		local defended = false
		if nearEnemy then
			local friendly, enemy = Strength(teamID, ux, uz, COMM_LOOK_R, unitID)
			if CanKill(unitDefID) then friendly = friendly + Weight(unitDefID) end
			defended = friendly >= enemy * COMM_DEFEND_RATIO
		end

		-- Where to run. With defenders about: a building near home, as
		-- before. Without: out of there (see EscapeSpot), and remember the
		-- place as a refuge if it is not home.
		local function RunTo()
			if defended and home and not shelter then
				return FindCommanderHaven(unitID, teamID, nearEnemy, home.x, home.z, leash)
			end
			local spot = EscapeSpot(unitID, unitDefID, teamID, allyTeamID, ux, uz, nearEnemy)
			if spot and home then
				local dx, dz = spot.x - home.x, spot.z - home.z
				if dx * dx + dz * dz > COMM_REFUGE_MIN * COMM_REFUGE_MIN then
					refuge[teamID] = spot
				else
					refuge[teamID] = nil
				end
			end
			return spot
		end

		if SimpleCommRetreating[teamID] then
			-- Already fleeing. Commit to the chosen spot; only re-issue an
			-- order when we genuinely need to, so the commander runs in one
			-- direction instead of re-rolling every time it's hit.
			if not nearEnemy and not outside then
				-- Threat gone and where it should be: resume normal duties.
				SimpleCommRetreating[teamID] = false
				SimpleCommRetreatPos[teamID] = nil
			else
				local rp = SimpleCommRetreatPos[teamID]
				local needNew = (rp == nil)
				if rp then
					local dx, dz = ux - rp.x, uz - rp.z
					if (dx * dx + dz * dz) < (COMM_HAVEN_REACH * COMM_HAVEN_REACH) then
						-- Arrived. Still in danger: pick again. Safe but
						-- "outside" (it ran to a refuge): settle here.
						if nearEnemy then
							needNew = true
						else
							SimpleCommRetreating[teamID] = false
							SimpleCommRetreatPos[teamID] = nil
							rp = nil
						end
					end
				end
				if needNew then
					rp = RunTo()
					SimpleCommRetreatPos[teamID] = rp
					if rp then
						Spring.GiveOrderToUnit(unitID, CMD.MOVE,
						                       { rp.x, rp.y, rp.z }, 0)
					end
				elseif unitCmds == 0 and rp then
					-- Order queue emptied unexpectedly: resume toward the
					-- SAME committed spot (do not pick a new direction).
					Spring.GiveOrderToUnit(unitID, CMD.MOVE,
					                       { rp.x, rp.y, rp.z }, 0)
				end
				-- Otherwise: leave the existing move order alone.
			end

		elseif nearEnemy and (hpRatio <= COMM_RETREAT_HP or outside or not defended) then
			-- Run: hurt, caught outside its leash, or facing an enemy with
			-- no defending force to stand with.
			local rp = RunTo()
			SimpleCommRetreating[teamID] = true
			SimpleCommRetreatPos[teamID] = rp
			if rp then
				Spring.GiveOrderToUnit(unitID, CMD.MOVE,
				                       { rp.x, rp.y, rp.z }, 0)
			end

		elseif outside then
			-- Outside the leash with no enemy near: drop whatever it was
			-- doing and walk back. Repeated now and then, not every tick.
			if frame >= (recallAt[teamID] or 0) then
				recallAt[teamID] = frame + COMM_RECALL_EVERY
				local tx = cx + math.random(-150, 150)
				local tz = cz + math.random(-150, 150)
				Spring.GiveOrderToUnit(unitID, CMD.MOVE,
				                       { tx, Spring.GetGroundHeight(tx, tz), tz }, 0)
			end

		elseif nearEnemy and unitCmds == 0 then
			-- Healthy, where it should be, defenders present: help them,
			-- but do not follow the enemy out of the leash.
			local tx, ty, tz = Spring.GetUnitPosition(nearEnemy)
			local chase = true
			if cx and tx then
				local dx, dz = tx - cx, tz - cz
				chase = (dx * dx + dz * dz) <= leash * leash
			end
			if chase then
				Spring.GiveOrderToUnit(unitID, CMD.FIGHT, { tx, ty, tz }, 0)
			end

		elseif unitCmds == 0 and not shelter then
			-- Idle at home: build something
			services.SelectConstructionProject(
					unitID, unitDefID, teamID, allyTeamID,
					units, allunits, "Commander")
		end
	end

	return B
end
