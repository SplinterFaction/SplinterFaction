--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    luarules/configs/simpleai/lib.lua
--  brief:   Stateless helper library for the SimpleAI gadget (stage 2 of the
--           modular split). Every function here is a QUERY: it may read ctx
--           and call Spring, but it never mutates ctx and never registers
--           callins. Behavior modules and the core both call through this.
--
--  usage:   local lib = VFS.Include("luarules/configs/simpleai/lib.lua")(ctx, cfg)
--           cfg carries the map/game constants listed below; ctx is the shared
--           AI context owned by the core gadget.
--
--  license: GNU GPL, v2 or later
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return function(ctx, cfg)

	local L = {}

	-- config constants (owned by the core, passed in)
	local mapsizeX           = cfg.mapsizeX
	local mapsizeZ           = cfg.mapsizeZ
	local gaiaTeamID         = cfg.gaiaTeamID
	local ATTACK_SCAN_R      = cfg.ATTACK_SCAN_R
	local ATTACK_DIST_W      = cfg.ATTACK_DIST_W
	local COMBAT_ROLE_WEIGHT = cfg.COMBAT_ROLE_WEIGHT

	-- shared state (read-only from here)
	local ShieldMax          = ctx.ShieldMax
	local IsTurret           = ctx.IsTurret
	local TeamTechLevel      = ctx.techLevel
	local TeamBuildLists     = ctx.buildLists
	local SimpleMusterPos    = ctx.squad.muster
	local SimpleEnemyBasePos = ctx.intel.enemyBase

	-- Effective hp ratio in [0,1]: hull + personal shield over the combined pool.
	-- For unshielded (Fed) units this is plain hull fraction.
	function L.EffectiveRatio(unitID, unitDefID, hp, maxhp)
		local smax = ShieldMax[unitDefID]
		if smax then
			local s = Spring.GetUnitRulesParam(unitID, "personalShield") or 0
			return (hp + s) / (maxhp + smax)
		end
		return hp / maxhp
	end

	-- ============================================================
	-- GET BUILDABLE LIST
	-- Returns all defIDs in a category available at or below
	-- the team's current tech level.
	-- ============================================================
	function L.GetBuildable(teamID, cat)
		local techLevel = TeamTechLevel[teamID] or 1
		local result    = {}
		local lists     = TeamBuildLists[teamID]
		if not lists then return result end
		for t = 0, techLevel do
			local bucket = lists[t] and lists[t][cat]
			if bucket then
				for _, id in ipairs(bucket) do
					result[#result + 1] = id
				end
			end
		end
		return result
	end

	-- ============================================================
	-- GET BUILDABLE LIST (TECH-WEIGHTED)
	-- Like GetBuildable, but repeats higher-tech defIDs more often so the
	-- downstream shuffle-and-pick favours advanced units/factories while
	-- still occasionally choosing cheaper lower-tier options.
	-- biasPow controls the skew: weight per unit = (techTier + 1) ^ biasPow.
	-- ============================================================
	function L.GetBuildableTechBiased(teamID, cat, biasPow)
		local techLevel = TeamTechLevel[teamID] or 1
		local result    = {}
		local lists     = TeamBuildLists[teamID]
		if not lists then return result end
		biasPow = biasPow or 1.8
		for t = 0, techLevel do
			local bucket = lists[t] and lists[t][cat]
			if bucket and #bucket > 0 then
				local weight = math.max(1, math.floor((t + 1) ^ biasPow + 0.5))
				for _, id in ipairs(bucket) do
					for _ = 1, weight do
						result[#result + 1] = id
					end
				end
			end
		end
		return result
	end

	-- ============================================================
	-- COMBAT ROLE WEIGHT
	-- Looks up a unit's build-menu category and returns the composition weight
	-- (skirmishers high, support/scout/utility lower). Used to skew which combat
	-- units the factories produce without ever fully excluding a role.
	-- ============================================================
	-- "heat" if every weapon on the def is a heat weapon, "disrupt" if every
	-- one is a disruption weapon, false otherwise (any direct-damage weapon,
	-- or a mix, makes it an ordinary combat unit). Cached per def.
	local nonDirect = {}
	local function NonDirectClass(defID)
		local c = nonDirect[defID]
		if c ~= nil then return c end
		c = false
		local ud = UnitDefs[defID]
		local weapons = ud and ud.weapons
		if weapons and #weapons > 0 then
			local heat, disrupt = 0, 0
			for i = 1, #weapons do
				local wd  = WeaponDefs[weapons[i].weaponDef]
				local wcp = wd and (wd.customParams or wd.customparams)
				local h   = wcp and wcp.heatweapon
				local d   = wcp and wcp.disruptionweapon
				if h and h ~= "0" and h ~= "false" then heat = heat + 1
				elseif d and d ~= "0" and d ~= "false" then disrupt = disrupt + 1 end
			end
			if heat == #weapons then c = "heat"
			elseif disrupt == #weapons then c = "disrupt" end
		end
		nonDirect[defID] = c
		return c
	end
	L.NonDirectClass = NonDirectClass

	function L.CombatRoleWeight(defID)
		local ud  = UnitDefs[defID]
		local cat = ud and ud.customParams and ud.customParams.buildmenucategory
		local w   = COMBAT_ROLE_WEIGHT[cat] or COMBAT_ROLE_WEIGHT.default
		-- No direct damage: capped, whatever the build menu calls it (see
		-- COMBAT_ROLE_WEIGHT.HeatOnly / DisruptOnly in the core).
		local class = NonDirectClass(defID)
		local cap = (class == "heat" and COMBAT_ROLE_WEIGHT.HeatOnly)
				or (class == "disrupt" and COMBAT_ROLE_WEIGHT.DisruptOnly)
		if cap and w > cap then w = cap end
		return w
	end

	-- ============================================================
	-- GET WEIGHTED BUILDABLE  ->  { {id=defID, w=weight}, ... }
	-- Combines tech weight (advanced tiers favoured) with an optional per-unit
	-- weight function (e.g. combat role). Returns weighted pairs for a weighted
	-- random pick, so we get composition control without duplicating list entries.
	-- ============================================================
	function L.GetWeightedBuildable(teamID, cat, biasPow, weightFn)
		local techLevel = TeamTechLevel[teamID] or 1
		local out       = {}
		local lists     = TeamBuildLists[teamID]
		if not lists then return out end
		biasPow = biasPow or 1.8
		for t = 0, techLevel do
			local bucket = lists[t] and lists[t][cat]
			if bucket then
				local techW = (t + 1) ^ biasPow
				for _, id in ipairs(bucket) do
					local w = techW
					if weightFn then w = w * weightFn(id) end
					if w > 0 then
						out[#out + 1] = { id = id, w = w }
					end
				end
			end
		end
		return out
	end

	-- teamID and unitDefID are optional: given, spots that unit type cannot
	-- walk to from the team's home are passed over.
	function L.GetClosestMexSpot(x, z, maxRange, teamID, unitDefID)
		local bestSpot
		local bestDist  = maxRange and (maxRange * maxRange) or math.huge
		local metalSpots = GG.metalMakerSpots
		if metalSpots then
			for i = 1, #metalSpots do
				local spot = metalSpots[i]
				local dx, dz = x - spot.x, z - spot.z
				local dist = dx * dx + dz * dz
				if dist < bestDist then
					local units = Spring.GetUnitsInCylinder(spot.x, spot.z, 128)
					if #units == 0 and (not teamID or L.Reachable(teamID, unitDefID, spot.x, spot.z)) then
						bestSpot = spot
						bestDist = dist
					end
				end
			end
		end
		return bestSpot
	end

	function L.EstimateEnemyBase(teamID)
		local allUnits = Spring.GetAllUnits()
		local ex, ez, count = 0, 0, 0
		for i = 1, #allUnits do
			local uid    = allUnits[i]
			local uteam  = Spring.GetUnitTeam(uid)
			-- Allies and gaia are NOT enemies: without this guard the "enemy base"
			-- centroid gets dragged toward allied bases in team games, and builder
			-- reclaim roams (which aim at this point) wander into friendly territory.
			if uteam ~= teamID and uteam ~= gaiaTeamID
					and not Spring.AreTeamsAllied(teamID, uteam) then
				local uDefID = Spring.GetUnitDefID(uid)
				if uDefID and UnitDefs[uDefID] and UnitDefs[uDefID].isBuilding then
					local ux, _, uz = Spring.GetUnitPosition(uid)
					ex = ex + ux
					ez = ez + uz
					count = count + 1
				end
			end
		end
		if count > 0 then
			local cx, cz = ex / count, ez / count
			return { x = cx, z = cz, y = Spring.GetGroundHeight(cx, cz) }
		end
		return nil
	end

	-- Compute a muster (staging) position for ground forces.
	-- We pick a spot 600-900 units in front of the team's base,
	-- angled toward the map centre so units don't stage in a wall.
	function L.ComputeMusterPos(teamID)
		local units = Spring.GetTeamUnits(teamID)
		-- Find centroid of friendly buildings as "base centre"
		local bx, bz, bcount = 0, 0, 0
		for i = 1, #units do
			local uid    = units[i]
			local uDefID = Spring.GetUnitDefID(uid)
			if uDefID and UnitDefs[uDefID] and UnitDefs[uDefID].isBuilding then
				local ux, _, uz = Spring.GetUnitPosition(uid)
				bx = bx + ux
				bz = bz + uz
				bcount = bcount + 1
			end
		end
		if bcount == 0 then return nil end
		bx = bx / bcount
		bz = bz / bcount

		-- Direction from base toward map centre
		local cx, cz = mapsizeX / 2, mapsizeZ / 2
		local dx, dz = cx - bx, cz - bz
		local len = math.sqrt(dx * dx + dz * dz)
		if len < 1 then return nil end
		dx, dz = dx / len, dz / len

		-- Stage 700 units out from the base centroid toward the centre, or
		-- nearer if the army cannot walk to that spot (a cliff, a mesa top).
		for _, stageDist in ipairs({ 700, 400, 150 }) do
			local mx = bx + dx * stageDist
			local mz = bz + dz * stageDist
			mx = math.max(256, math.min(mapsizeX - 256, mx))
			mz = math.max(256, math.min(mapsizeZ - 256, mz))
			if L.ArmyReachable(teamID, mx, mz, 150) then
				return { x = mx, z = mz, y = Spring.GetGroundHeight(mx, mz) }
			end
		end
		local home = ctx.home and ctx.home[teamID]
		if home then return { x = home.x, z = home.z, y = Spring.GetGroundHeight(home.x, home.z) } end
		return { x = bx, z = bz, y = Spring.GetGroundHeight(bx, bz) }
	end

	-- ============================================================
	-- COMMANDER HAVEN SELECTION
	-- Deterministically picks ONE safe spot to flee to: a friendly building
	-- that is far from the threat but not absurdly far from the commander,
	-- with a strong bonus for turret cover. No randomness, so repeated calls
	-- return a stable destination (prevents retreat-order thrashing).
	-- ============================================================
	-- homeX/homeZ/maxDist (optional): only buildings within maxDist of home
	-- count as havens. Without that the best-scoring "haven" was often a
	-- forward turret thousands of elmos out, and commanders ran TOWARD the
	-- front; half of all commanders lost in recordings died beyond 3,000
	-- elmos from their start.
	function L.FindCommanderHaven(unitID, teamID, enemyID, homeX, homeZ, maxDist)
		local ux, uy, uz = Spring.GetUnitPosition(unitID)
		local ex, ez
		if enemyID then
			local x, _, z = Spring.GetUnitPosition(enemyID)
			ex, ez = x, z
		end

		local teamUnits = Spring.GetTeamUnits(teamID)
		local best, bestScore
		for i = 1, #teamUnits do
			local cand = teamUnits[i]
			if cand ~= unitID then
				local cDefID = Spring.GetUnitDefID(cand)
				local bx, by, bz
				if cDefID and UnitDefs[cDefID] and UnitDefs[cDefID].isBuilding then
					bx, by, bz = Spring.GetUnitPosition(cand)
					if homeX and bx then
						local hdx, hdz = bx - homeX, bz - homeZ
						if hdx * hdx + hdz * hdz > maxDist * maxDist then bx = nil end
					end
				end
				if bx then
					local cdx, cdz = bx - ux, bz - uz
					local distComm = math.sqrt(cdx * cdx + cdz * cdz)
					local distEnemy = 100000
					if ex then
						local edx, edz = bx - ex, bz - ez
						distEnemy = math.sqrt(edx * edx + edz * edz)
					end
					-- Want: far from enemy, close-ish to commander, prefer turret cover
					local score = distEnemy - distComm * 0.5
					if IsTurret[cDefID] then score = score + 1000 end
					if not bestScore or score > bestScore then
						bestScore = score
						best = { x = bx, y = by, z = bz }
					end
				end
			end
		end

		if best then return best end
		-- nothing standing near home: home itself
		if homeX then return { x = homeX, y = Spring.GetGroundHeight(homeX, homeZ), z = homeZ } end

		-- No buildings left: flee directly away from the enemy.
		if ex then
			local fx = ux + (ux - ex)
			local fz = uz + (uz - ez)
			fx = math.max(256, math.min(mapsizeX - 256, fx))
			fz = math.max(256, math.min(mapsizeZ - 256, fz))
			return { x = fx, y = Spring.GetGroundHeight(fx, fz), z = fz }
		end
		return nil
	end

	-- ============================================================
	-- WEAK-POINT ATTACK TARGETING
	-- Scans all enemy structures and tallies the defensive strength near each
	-- (combat units + armed turrets within ATTACK_SCAN_R, weighted by their HP).
	-- Returns the lowest-defended structure, lightly penalised by distance from
	-- our muster so we don't trek across the map for a marginally softer target.
	-- ============================================================
	-- ============================================================
	-- FIND COMMANDER TARGET
	-- A side is out of the game when its last commander dies, so an enemy
	-- commander the wave can beat is worth more than any building. Returns
	-- { x, y, z, uid, last } for the best enemy commander to go after, or
	-- nil when none is worth it:
	--   * the wave (waveValue, in metal) must outweigh what it would meet
	--     there by COMM_HUNT_EDGE: every enemy armed unit and turret within
	--     COMM_GUARD_R of the commander, AND the commander itself. (The
	--     first version left the commander out of its own guard, so a
	--     commander standing alone looked free: a recording showed five
	--     starting units sent at one two minutes into the game.) The radius
	--     matches the one a wave uses to judge whether it is outmatched,
	--     so a hunt is not launched into a fight the wave would at once be
	--     pulled out of. The army must also be able to walk there;
	--   * a commander that is the LAST on its side always comes first;
	--   * otherwise the least-guarded, nearer one.
	-- ============================================================
	local COMM_GUARD_R   = 1400

	-- How much a unit type counts for in a fight, in metal. For everything
	-- but commanders that is simply its metal cost. A commander is far
	-- stronger than its price: a recording's unit table shows a first-tier
	-- commander costing 150 to 225 metal, about one basic tank, and waves
	-- of four or five starting units were being sent to "hunt" one two and
	-- a half minutes into a game. A commander therefore counts as
	-- COMM_WEIGHT times its cost (first tier about 1,200 to 1,800, top tier
	-- about 58,000 to 79,000). One number, used everywhere strength is
	-- compared: hunting, a wave judging whether it is outmatched, and a
	-- commander deciding whether to stand or escape.
	L.COMM_WEIGHT = 8
	local strengthOf = {}
	function L.UnitStrength(unitDefID)
		local s = strengthOf[unitDefID]
		if not s then
			local ud = UnitDefs[unitDefID]
			s = (ud and ud.metalCost) or 0
			if ctx.IsCommander and ctx.IsCommander[unitDefID] then s = s * L.COMM_WEIGHT end
			strengthOf[unitDefID] = s
		end
		return s
	end
	local COMM_HUNT_EDGE = 1.3
	function L.FindCommanderTarget(teamID, waveValue)
		local isComm = ctx.IsCommander
		if not isComm or not waveValue or waveValue <= 0 then return nil end
		local myAlly = select(6, Spring.GetTeamInfo(teamID, false))
		local teamList = Spring.GetTeamList()
		local found, perSide = {}, {}
		for i = 1, #teamList do
			local t = teamList[i]
			if t ~= teamID and t ~= gaiaTeamID and not Spring.AreTeamsAllied(teamID, t) then
				local side = select(6, Spring.GetTeamInfo(t, false))
				local tUnits = Spring.GetTeamUnits(t)
				for k = 1, #tUnits do
					local d = Spring.GetUnitDefID(tUnits[k])
					if d and isComm[d] then
						perSide[side] = (perSide[side] or 0) + 1
						found[#found + 1] = { uid = tUnits[k], side = side }
					end
				end
			end
		end
		if #found == 0 then return nil end
		local origin = SimpleMusterPos[teamID]
		local best, bestScore
		for i = 1, #found do
			local c = found[i]
			local x, y, z = Spring.GetUnitPosition(c.uid)
			if x then
				local guard = 0
				local near = Spring.GetUnitsInCylinder(x, z, COMM_GUARD_R)
				for k = 1, #near do
					local u = near[k]
					local ut = Spring.GetUnitTeam(u)
					if ut and ut ~= teamID and not Spring.AreTeamsAllied(teamID, ut) then
						local ud_id = Spring.GetUnitDefID(u)
						local ud = UnitDefs[ud_id or 0]
						if ud and ud.weapons and #ud.weapons > 0 then guard = guard + L.UnitStrength(ud_id) end
					end
				end
				if waveValue >= guard * COMM_HUNT_EDGE and L.ArmyReachable(teamID, x, z) then
					local score = guard
					if origin then
						local dx, dz = x - origin.x, z - origin.z
						score = score + math.sqrt(dx * dx + dz * dz) * ATTACK_DIST_W
					end
					local last = (perSide[c.side] == 1)
					if last then score = score - 1e9 end
					if not bestScore or score < bestScore or (score == bestScore and c.uid < best.uid) then
						bestScore = score
						best = { x = x, y = y, z = z, uid = c.uid, last = last, guard = guard }
					end
				end
			end
		end
		return best
	end

	-- ============================================================
	-- FIND RAID TARGET
	-- A raid is a small, fast party sent at the enemy's economy where it is
	-- NOT defended, to make the enemy look away from the front. Returns
	-- { x, y, z, uid, defense } for the best enemy metal extractor to hit,
	-- or nil when nothing is soft enough:
	--   * what guards it (enemy armed units, turrets and commanders within
	--     RAID_SCAN_R, by fighting weight) must be at most RAID_EDGE times
	--     the raid's own value, so the party clearly outweighs it;
	--   * the raiders (repDefID stands for how they move) must be able to
	--     walk there;
	--   * extractors another allied raid was sent at in the last
	--     RAID_CLAIM frames are skipped, so raids spread out;
	--   * the straight line there (from fromX, fromZ if given, else the
	--     staging point) must not run through enemy strength the party
	--     cannot survive: at every RAID_PATH_STEP along it, enemy weight
	--     within RAID_PATH_R must be at most the raid's own value. A
	--     recording showed 7 of 17 raids wiped out, four of them before
	--     reaching anything: the target was undefended, the road was not.
	--   * among what is left: least guarded first, then nearest.
	-- ============================================================
	local RAID_SCAN_R = 800
	local RAID_EDGE   = 0.5
	local RAID_CLAIM  = 3600
	local RAID_SPREAD = 600
	local RAID_PATH_STEP = 450
	local RAID_PATH_R    = 650
	local RAID_PATH_TRIES = 8     -- best candidates whose route is checked before giving up
	local raidClaims  = {}     -- { x =, z =, untilFrame =, ally = }
	function L.FindRaidTarget(teamID, raidValue, repDefID, fromX, fromZ)
		local isMex = ctx.IsExtractor
		if not isMex or not raidValue or raidValue <= 0 then return nil end
		local now = Spring.GetGameFrame()
		local myAlly = select(6, Spring.GetTeamInfo(teamID, false))
		local mexes, threats = {}, {}
		local allUnits = Spring.GetAllUnits()
		for i = 1, #allUnits do
			local uid = allUnits[i]
			local ut  = Spring.GetUnitTeam(uid)
			if ut ~= teamID and ut ~= gaiaTeamID and not Spring.AreTeamsAllied(teamID, ut) then
				local d  = Spring.GetUnitDefID(uid)
				local ud = d and UnitDefs[d]
				if ud then
					local x, _, z = Spring.GetUnitPosition(uid)
					if isMex[d] then
						mexes[#mexes + 1] = { uid = uid, x = x, z = z }
					elseif ud.weapons and #ud.weapons > 0 then
						threats[#threats + 1] = { x = x, z = z, w = L.UnitStrength(d) }
					end
				end
			end
		end
		if #mexes == 0 then return nil end
		local origin = SimpleMusterPos[teamID]
		local scan2, spread2 = RAID_SCAN_R * RAID_SCAN_R, RAID_SPREAD * RAID_SPREAD
		local limit = raidValue * RAID_EDGE
		if not fromX and origin then fromX, fromZ = origin.x, origin.z end
		local cands = {}
		for i = 1, #mexes do
			local m = mexes[i]
			local claimed = false
			for c = 1, #raidClaims do
				local rc = raidClaims[c]
				if rc.ally == myAlly and rc.untilFrame > now then
					local dx, dz = rc.x - m.x, rc.z - m.z
					if dx * dx + dz * dz < spread2 then claimed = true; break end
				end
			end
			if not claimed then
				local defense = 0
				for t = 1, #threats do
					local th = threats[t]
					local dx, dz = th.x - m.x, th.z - m.z
					if dx * dx + dz * dz < scan2 then
						defense = defense + th.w
						if defense > limit then break end
					end
				end
				if defense <= limit then
					local score = defense * 4
					if fromX then
						local dx, dz = m.x - fromX, m.z - fromZ
						score = score + math.sqrt(dx * dx + dz * dz) * ATTACK_DIST_W
					end
					cands[#cands + 1] = { x = m.x, z = m.z, uid = m.uid, defense = defense, score = score }
				end
			end
		end
		table.sort(cands, function(a, b)
			if a.score ~= b.score then return a.score < b.score end
			return a.uid < b.uid
		end)
		-- Is the straight road from the party to (tx, tz) survivable?
		local path2 = RAID_PATH_R * RAID_PATH_R
		local function RoadClear(tx, tz)
			if not fromX then return true end
			local dx, dz = tx - fromX, tz - fromZ
			local dist = math.sqrt(dx * dx + dz * dz)
			local steps = math.floor(dist / RAID_PATH_STEP)
			for s = 1, steps - 1 do                -- (the end point itself was judged above, more strictly)
				local px, pz = fromX + dx * s / steps, fromZ + dz * s / steps
				local weight = 0
				for t = 1, #threats do
					local th = threats[t]
					local ex, ez = th.x - px, th.z - pz
					if ex * ex + ez * ez < path2 then
						weight = weight + th.w
						if weight > raidValue then return false end
					end
				end
			end
			return true
		end
		local best
		local tries = 0
		for i = 1, #cands do
			local c = cands[i]
			if not repDefID or L.Reachable(teamID, repDefID, c.x, c.z, 300) then
				tries = tries + 1
				if RoadClear(c.x, c.z) then best = c; break end
				if tries >= RAID_PATH_TRIES then break end
			end
		end
		if not best then return nil end
		best.y = Spring.GetGroundHeight(best.x, best.z)
		-- remember it, and forget claims that have lapsed
		local keep = {}
		for c = 1, #raidClaims do
			if raidClaims[c].untilFrame > now then keep[#keep + 1] = raidClaims[c] end
		end
		keep[#keep + 1] = { x = best.x, z = best.z, untilFrame = now + RAID_CLAIM, ally = myAlly }
		raidClaims = keep
		return best
	end

	function L.FindWeakestEnemyTarget(teamID)
		local allUnits = Spring.GetAllUnits()
		local enemyBuildings = {}
		local threats = {}

		for i = 1, #allUnits do
			local uid = allUnits[i]
			local ut  = Spring.GetUnitTeam(uid)
			if ut ~= teamID and ut ~= gaiaTeamID then
				local allied = Spring.AreTeamsAllied(teamID, ut)
				if not allied then   -- nil (unallied) or false both count as enemy
					local dID = Spring.GetUnitDefID(uid)
					local ud  = dID and UnitDefs[dID]
					if ud then
						local x, _, z = Spring.GetUnitPosition(uid)
						if ud.isBuilding then
							enemyBuildings[#enemyBuildings + 1] = { x = x, z = z }
						end
						if ud.weapons and #ud.weapons > 0 then
							local _, maxHP = Spring.GetUnitHealth(uid)
							threats[#threats + 1] = { x = x, z = z, w = (maxHP or 100) }
						end
					end
				end
			end
		end

		if #enemyBuildings == 0 then return nil end

		local origin = SimpleMusterPos[teamID] or SimpleEnemyBasePos[teamID]
		local scanR2 = ATTACK_SCAN_R * ATTACK_SCAN_R

		local scored = {}
		for _, b in ipairs(enemyBuildings) do
			local defense = 0
			for _, t in ipairs(threats) do
				local dx, dz = t.x - b.x, t.z - b.z
				if dx * dx + dz * dz < scanR2 then
					defense = defense + t.w
				end
			end
			local distPen = 0
			if origin then
				local dx, dz = b.x - origin.x, b.z - origin.z
				distPen = math.sqrt(dx * dx + dz * dz) * ATTACK_DIST_W
			end
			b.score = defense + distPen
			scored[#scored + 1] = b
		end
		-- Softest first; the first one the army can actually walk to wins.
		-- (Targets on sealed-off high ground used to be picked like any
		-- other, and the wave piled up against the cliff below them.)
		table.sort(scored, function(a, b)
			if a.score ~= b.score then return a.score < b.score end
			if a.x ~= b.x then return a.x < b.x end
			return a.z < b.z
		end)
		for i = 1, #scored do
			local b = scored[i]
			if L.ArmyReachable(teamID, b.x, b.z) then
				return { x = b.x, z = b.z, y = Spring.GetGroundHeight(b.x, b.z) }
			end
		end
		return nil
	end

	-- ============================================================
	-- REACHABILITY
	-- "Can a unit of this kind get from the team's home to that spot?"
	-- A recorded game showed what happens without the question: factories
	-- built on top of sealed-off mesas (builders can build up a cliff from
	-- below) whose output could never leave, commanders standing at a cliff
	-- edge trying to reach a site across a chasm, and whole armies packed
	-- against cliffs under targets they could not walk to.
	--
	-- HOW (second attempt). The first version asked the engine pathfinder
	-- (Spring.RequestPath) and looked at where the path ended. Control probes
	-- in a recording showed that does not work on this engine setup: the
	-- returned path always ends exactly at the goal, reachable or not, so
	-- the check said "yes" 29,110 times out of 29,110. This version does not
	-- depend on the pathfinder at all:
	--
	--   1. SURVEY. The map is cut into cells (32 elmos on ordinary maps). For
	--      each cell the steepest ground slope and lowest ground height in it
	--      are read from the engine (Spring.GetGroundNormal / GetGroundHeight),
	--      the same slope figures the engine itself uses to decide where a
	--      unit may go. The survey runs once, a few rows per AI tick.
	--   2. REGIONS. For each kind of mover (its slope limit and how deep it
	--      may wade, from UnitDefs[...].moveDef) the passable cells are
	--      grouped into connected regions with a flood fill. Done on first
	--      use per kind of mover; movers with the same limits share it.
	--   3. ANSWER. A spot is reachable if a cell of the home region lies
	--      within the tolerance the caller gives (a builder only needs to get
	--      near a site, a factory's output has to stand on it).
	--
	-- Until the survey is finished the answer is "yes" (the old behavior).
	-- Aircraft, ships and anything else without a ground movement class
	-- always get "yes". Safety net: the first time a kind of mover is used, a
	-- spread of metal spots is tested; if almost none come back reachable the
	-- check is assumed wrong for that kind and switched off for it. This is
	-- an approximation of the pathfinder (it ignores unit width and other
	-- units), so tolerances are generous. REACH.ENABLED = false turns it off.
	-- ============================================================
	local REACH = {
		ENABLED     = true,
		CELL        = 32,      -- cell size in elmos (raised automatically on very large maps)
		MAX_CELLS   = 260000,  -- ...so the survey never exceeds this many cells
		ROWS_PER_TICK = 24,    -- survey rows read per call to ReachTick
		TOL_BUILD   = 250,     -- a builder only has to get this close to a site
		TOL_FACTORY = 48,      -- a factory's output has to reach the spot itself
		TOL_ATTACK  = 400,     -- an attacker only has to get within weapon range
		CAL_SPOTS   = 12,      -- metal spots tested when a kind of mover is first used
		CAL_MIN     = 0.25,    -- below this share reachable, the check is assumed wrong
		slope  = {},           -- [cell] = steepest slope in the cell (survey)
		height = {},           -- [cell] = lowest ground height in the cell (survey)
		rowsDone = 0,          -- survey progress
		ready  = false,
		labels = {},           -- [moverKey] = { [cell] = region number, 0 = impassable }
		off    = {},           -- [teamID][moverKey] = true: switched off for this kind of mover
		stats  = { asked = 0, no = 0 },
	}
	L.REACH = REACH
	do
		local cell = REACH.CELL
		while (mapsizeX / cell) * (mapsizeZ / cell) > REACH.MAX_CELLS do cell = cell + 16 end
		REACH.CELL = cell
	end
	local RNX = math.ceil(mapsizeX / REACH.CELL)
	local RNZ = math.ceil(mapsizeZ / REACH.CELL)

	-- What limits a unit type's movement: nil for anything this check does
	-- not apply to (aircraft, ships, buildings).
	local moverCache = {}
	local function MoverOf(unitDefID)
		local m = moverCache[unitDefID]
		if m ~= nil then return m or nil end
		m = false
		local ud = unitDefID and UnitDefs[unitDefID]
		local md = ud and not ud.canFly and ud.moveDef
		if md and md.id and md.maxSlope and md.smClass ~= 3 then      -- smClass 3 = ship
			local hover = (md.smClass == 2)
			local depth = hover and 1e9 or (md.depth or 1e9)
			m = { maxSlope = md.maxSlope, depth = depth,
			      key = ("%.4f/%s"):format(md.maxSlope, hover and "hover" or tostring(math.floor(depth))) }
		end
		moverCache[unitDefID] = m
		return m or nil
	end

	-- Survey a batch of rows: steepest slope and lowest height per cell.
	local function Survey(rows)
		local cell = REACH.CELL
		local slope, height = REACH.slope, REACH.height
		local half = cell / 2
		local z0 = REACH.rowsDone
		local z1 = math.min(RNZ, z0 + rows) - 1
		for gz = z0, z1 do
			local base = gz * RNX
			for gx = 0, RNX - 1 do
				-- the engine's slope figures are on a 16-elmo grid: read each one in the cell
				local smax, hmin = 0, math.huge
				for oz = 8, cell - 1, 16 do
					for ox = 8, cell - 1, 16 do
						local x, z = gx * cell + ox, gz * cell + oz
						local _, ny, _, s = Spring.GetGroundNormal(x, z)
						if not s then s = 1 - (ny or 1) end
						if s > smax then smax = s end
						local h = Spring.GetGroundHeight(x, z)
						if h < hmin then hmin = h end
					end
				end
				slope[base + gx]  = smax
				height[base + gx] = hmin
			end
		end
		REACH.rowsDone = z1 + 1
		if REACH.rowsDone >= RNZ then REACH.ready = true end
	end

	-- Connected regions of the cells this kind of mover can stand on.
	local function Regions(mover)
		local labels = REACH.labels[mover.key]
		if labels then return labels end
		labels = {}
		local slope, height = REACH.slope, REACH.height
		local maxSlope, minHeight = mover.maxSlope, -mover.depth
		local total = RNX * RNZ
		for c = 0, total - 1 do
			labels[c] = (slope[c] <= maxSlope and height[c] >= minHeight) and -1 or 0   -- -1 = passable, not yet numbered
		end
		local stack, region = {}, 0
		for start = 0, total - 1 do
			if labels[start] == -1 then
				region = region + 1
				labels[start] = region
				local n = 1
				stack[1] = start
				while n > 0 do
					local c = stack[n]; n = n - 1
					local gx = c % RNX
					if gx > 0 and labels[c - 1] == -1 then labels[c - 1] = region; n = n + 1; stack[n] = c - 1 end
					if gx < RNX - 1 and labels[c + 1] == -1 then labels[c + 1] = region; n = n + 1; stack[n] = c + 1 end
					if c >= RNX and labels[c - RNX] == -1 then labels[c - RNX] = region; n = n + 1; stack[n] = c - RNX end
					if c < total - RNX and labels[c + RNX] == -1 then labels[c + RNX] = region; n = n + 1; stack[n] = c + RNX end
				end
			end
		end
		REACH.labels[mover.key] = labels
		return labels
	end

	-- The nearest numbered region to (x, z) within `reach` elmos, searching
	-- outward ring by ring. Returns region, distance; or nil.
	local function RegionNear(labels, x, z, reach, want)
		local cell = REACH.CELL
		local gx0 = math.max(0, math.min(RNX - 1, math.floor(x / cell)))
		local gz0 = math.max(0, math.min(RNZ - 1, math.floor(z / cell)))
		local first = labels[gz0 * RNX + gx0]
		if first ~= 0 and (not want or first == want) then return first, 0 end
		local rings = math.ceil(reach / cell)
		for r = 1, rings do
			for gz = gz0 - r, gz0 + r do
				if gz >= 0 and gz < RNZ then
					local edge = (gz == gz0 - r or gz == gz0 + r)
					local step = edge and 1 or (2 * r)
					for gx = gx0 - r, gx0 + r, step do
						if gx >= 0 and gx < RNX then
							local lab = labels[gz * RNX + gx]
							if lab ~= 0 and (not want or lab == want) then
								local dx, dz = (gx - gx0) * cell, (gz - gz0) * cell
								local d = math.sqrt(dx * dx + dz * dz)
								if d <= reach then return lab, d end
							end
						end
					end
				end
			end
		end
		return nil
	end

	-- The region a team's home belongs to for this kind of mover (cached).
	local homeRegion = {}   -- [teamID][moverKey] = region or false
	local function HomeRegion(teamID, mover, home)
		local byTeam = homeRegion[teamID]
		if not byTeam then byTeam = {}; homeRegion[teamID] = byTeam end
		local r = byTeam[mover.key]
		if r == nil then
			r = RegionNear(Regions(mover), home.x, home.z, 300) or false
			byTeam[mover.key] = r
		end
		return r or nil
	end

	-- First use of a kind of mover by a team: does the check give sane answers?
	local function Calibrate(teamID, mover, home)
		local offByTeam = REACH.off[teamID]
		if not offByTeam then offByTeam = {}; REACH.off[teamID] = offByTeam end
		offByTeam[mover.key] = false
		local region = HomeRegion(teamID, mover, home)
		local spots = GG.metalMakerSpots
		local tested, reached = 0, 0
		if region and spots and #spots >= 4 then
			local labels = Regions(mover)
			local step = math.max(1, math.floor(#spots / REACH.CAL_SPOTS))
			for i = 1, #spots, step do
				tested = tested + 1
				if RegionNear(labels, spots[i].x, spots[i].z, REACH.TOL_BUILD, region) then reached = reached + 1 end
			end
		end
		local share = (tested > 0) and (reached / tested) or 1
		if not region or share < REACH.CAL_MIN then
			offByTeam[mover.key] = true
			Spring.Echo(("[SimpleAI] team %d: reachability check for mover %s switched off (home region %s, %d of %d test spots reachable)"):format(
				teamID, mover.key, tostring(region), reached, tested))
		end
		if GG.Recorder and GG.Recorder.Log then
			GG.Recorder.Log(teamID, "reach", ("mover=%s;region=%s;tested=%d;reached=%d;on=%s"):format(
				mover.key, tostring(region), tested, reached, offByTeam[mover.key] and "0" or "1"))
		end
	end

	-- Once per team tick: carry the one-time survey forward.
	function L.ReachTick(teamID)
		if REACH.ENABLED and not REACH.ready then
			local ok, err = pcall(Survey, REACH.ROWS_PER_TICK)
			if not ok then
				REACH.ENABLED = false
				Spring.Echo("[SimpleAI] reachability check switched off: " .. tostring(err))
			elseif REACH.ready and GG.Recorder and GG.Recorder.Log then
				GG.Recorder.Log(teamID, "reach", ("survey=done;cells=%d;cell=%d"):format(RNX * RNZ, REACH.CELL))
			end
		end
	end

	-- Can a unit of type unitDefID, starting from the team's home, get within
	-- `tol` elmos of (x, z)? Unknown (survey not finished, check off, no
	-- home, an aircraft) counts as yes. (`exact` is accepted for
	-- compatibility with the first version and ignored.)
	function L.Reachable(teamID, unitDefID, x, z, tol, exact)
		if not REACH.ENABLED or not REACH.ready then return true end
		local home = ctx.home and ctx.home[teamID]
		if not home then return true end
		local mover = MoverOf(unitDefID)
		if not mover then return true end
		local offByTeam = REACH.off[teamID]
		if not offByTeam or offByTeam[mover.key] == nil then
			Calibrate(teamID, mover, home)
			offByTeam = REACH.off[teamID]
		end
		if offByTeam[mover.key] then return true end
		local region = HomeRegion(teamID, mover, home)
		if not region then return true end
		REACH.stats.asked = REACH.stats.asked + 1
		if RegionNear(Regions(mover), x, z, tol or REACH.TOL_BUILD, region) then return true end
		REACH.stats.no = REACH.stats.no + 1
		return false
	end

	-- Diagnostic: how far is (x, z) from the nearest ground this unit type
	-- can walk to from home? 0 = it can stand on the spot. nil if the
	-- question cannot be asked yet. Logged as control probes.
	function L.ReachProbe(teamID, unitDefID, x, z)
		local home = ctx.home and ctx.home[teamID]
		local mover = MoverOf(unitDefID)
		if not REACH.ENABLED or not REACH.ready or not home or not mover then return nil end
		local region = HomeRegion(teamID, mover, home)
		if not region then return nil end
		local _, d = RegionNear(Regions(mover), x, z, 2000, region)
		return d and math.floor(d + 0.5) or 99999, mover.key
	end

	-- A factory site is good only if everything the factory builds can walk
	-- away from it: every kind of ground mover among its build options is
	-- checked.
	local factoryClasses = {}   -- [factoryDefID] = { representative unitDefID per movement class }
	function L.FactorySiteReachable(teamID, factoryDefID, x, z)
		local reps = factoryClasses[factoryDefID]
		if not reps then
			reps = {}
			local seen = {}
			local ud = UnitDefs[factoryDefID]
			for _, optID in ipairs((ud and ud.buildOptions) or {}) do
				local mover = MoverOf(optID)
				if mover and not seen[mover.key] then seen[mover.key] = true; reps[#reps + 1] = optID end
			end
			factoryClasses[factoryDefID] = reps
		end
		for i = 1, #reps do
			if not L.Reachable(teamID, reps[i], x, z, REACH.TOL_FACTORY, true) then return false end
		end
		return true
	end

	-- The team's army, for target and staging choices: one representative
	-- unit type (set by the combat behavior to the most common ground class).
	local armyDef = {}
	function L.SetArmyDef(teamID, unitDefID) armyDef[teamID] = unitDefID end
	function L.ArmyReachable(teamID, x, z, tol)
		local def = armyDef[teamID]
		if not def then return true end
		return L.Reachable(teamID, def, x, z, tol or REACH.TOL_ATTACK)
	end


	-- Why the most recent BuildOrder call did or did not find a site. Reset on
	-- every call; read by the construction behavior for its diagnostics.
	--   sites    = candidate positions tested
	--   blocked  = engine said blocked (terrain, slope, a building, map edge)
	--   occupied = a mobile unit was standing on the site
	--   crowded  = site was buildable but too close to another structure
	--              (would close a lane or a factory's surroundings)
	--   noAnchor = search rings that held no friendly unit to build next to
	--   unreach  = site was fine but cannot be walked to from home
	L.placeStats = { sites = 0, blocked = 0, occupied = 0, crowded = 0, noAnchor = 0, unreach = 0 }

	-- Base layout rules. The AI used to drop each building right beside
	-- another with a small random gap and only checked a little box around
	-- the new building's CENTER, so big buildings ended up touching and whole
	-- armies were walled in behind rows of supply depots. Now every site must
	-- leave a real lane to every other structure, measured edge to edge, and
	-- a wider apron around factories so their output can get out.
	local LANE          = 112   -- min gap between any two structures (elmos)
	local FACTORY_APRON = 256   -- min gap between a factory and anything else
	local GAP_JITTER    = 96    -- extra random gap so bases do not form a perfect grid
	local QUERY_PAD     = 420   -- how far past a site to look for neighbors (largest half-footprint + apron)
	local PENDING_FOR   = 1800  -- frames an ordered-but-unstarted site keeps its claim (~60s)
	local PENDING_MAX   = 32
	local ANCHORS_PER_RING = 4  -- different anchors tried in each search ring
	local FAR_STEP      = 192   -- second try in each direction, this much further from the anchor

	-- Sites ordered recently that may not have a nanoframe yet. Without this,
	-- two builders choosing in the same few seconds can pick neighboring spots.
	local pending, pendingNext = {}, 1

	local function IsStructure(ud)
		return ud and (ud.isBuilding or ud.isImmobile) and true or false
	end

	-- Half extents (elmos) of a def's footprint for a build facing.
	local function HalfSize(ud, facing)
		local hx, hz = (ud.xsize or 2) * 4, (ud.zsize or 2) * 4
		if facing == 1 or facing == 3 then hx, hz = hz, hx end
		return hx, hz
	end

	-- True if a structure of half-size hx,hz at bx,bz keeps the required gap
	-- to every structure already there or on order.
	local allBricks = {}   -- every brick ever planned, all teams: { x=, z=, hx=, hz= } (see the brick planner)

	local function SiteHasLanes(bx, bz, hx, hz, isFactory, ignoreID, ignoreBrick)
		local nearby = Spring.GetUnitsInRectangle(bx - hx - QUERY_PAD, bz - hz - QUERY_PAD,
		                                          bx + hx + QUERY_PAD, bz + hz + QUERY_PAD)
		for i = 1, #nearby do
			local other = nearby[i]
			if other ~= ignoreID then
				local ud = UnitDefs[Spring.GetUnitDefID(other) or 0]
				if IsStructure(ud) then
					local ox, _, oz = Spring.GetUnitPosition(other)
					-- the neighbor's facing is not known cheaply: use its longer side both ways
					local oh  = math.max(ud.xsize or 2, ud.zsize or 2) * 4
					local gap = (isFactory or ud.isFactory) and FACTORY_APRON or LANE
					if math.abs(ox - bx) < hx + oh + gap and math.abs(oz - bz) < hz + oh + gap then
						return false
					end
				end
			end
		end
		local now = Spring.GetGameFrame()
		for i = 1, #pending do
			local p = pending[i]
			if p.untilFrame > now then
				local gap = (isFactory or p.isFactory) and FACTORY_APRON or LANE
				if math.abs(p.x - bx) < hx + p.hx + gap and math.abs(p.z - bz) < hz + p.hz + gap then
					return false
				end
			end
		end
		-- planned bricks keep their whole rectangle, filled or not
		for i = 1, #allBricks do
			local b = allBricks[i]
			if b ~= ignoreBrick then
				local gap = isFactory and FACTORY_APRON or LANE
				if math.abs(b.x - bx) < hx + b.hx + gap and math.abs(b.z - bz) < hz + b.hz + gap then
					return false
				end
			end
		end
		return true
	end
	L.SiteHasLanes = SiteHasLanes

	-- originX/originZ (optional): search outward from this point instead of
	-- from the builder. Base buildings pass the team's home, so the base grows
	-- around home and not around wherever a builder happens to be standing.
	-- maxDist (optional, with an origin): sites farther than this from the
	-- origin are not considered (the commander's leash).
	function L.BuildOrder(cUnitID, building, originX, originZ, maxDist)
		local ps = L.placeStats
		ps.sites, ps.blocked, ps.occupied, ps.crowded, ps.noAnchor, ps.unreach = 0, 0, 0, 0, 0, 0
		local team = Spring.GetUnitTeam(cUnitID)
		local cx, _, cz = Spring.GetUnitPosition(cUnitID)
		if originX and originZ then cx, cz = originX, originZ end
		local builderDefID = Spring.GetUnitDefID(cUnitID)
		local newDef = UnitDefs[building]
		if not newDef or not cx then return false end
		local newIsFactory = newDef.isFactory and true or false

		-- Compute a "safe interior" direction: push away from whichever map edge
		-- is closest so buildings never pile up against a wall.
		local edgePushX = 0
		local edgePushZ = 0
		local edgeMargin = 1500
		if cx < edgeMargin then edgePushX =  1
		elseif cx > mapsizeX - edgeMargin then edgePushX = -1
		end
		if cz < edgeMargin then edgePushZ =  1
		elseif cz > mapsizeZ - edgeMargin then edgePushZ = -1
		end

		local searchRange = 0
		for b2 = 1, 30 do
			searchRange = searchRange + 150

			local units = Spring.GetUnitsInCylinder(cx, cz, searchRange, team)
			if #units > 1 then
			 -- Several anchors per ring. One random anchor used to be the whole
			 -- ring's chance, and in a filled-in base or a start tucked into a
			 -- corner most anchors have no free side: recordings showed two such
			 -- teams failing 40% of their placements while open-ground teams
			 -- failed 3%. Up to ANCHORS_PER_RING different anchors are tried.
			 local triedAnchor = nil
			 for anchorTry = 1, ANCHORS_PER_RING do
				-- Prefer a building as the reference anchor, but exclude the builder itself
				local buildnear = nil
				for attempt = 1, 8 do
					local candidate = units[math.random(1, #units)]
					if candidate ~= cUnitID and not (triedAnchor and triedAnchor[candidate]) then
						local cDefID = Spring.GetUnitDefID(candidate)
						if cDefID and UnitDefs[cDefID].isBuilding then
							buildnear = candidate
							break
						end
					end
				end
				-- Fall back to any nearby unit that isn't the builder
				if not buildnear then
					for attempt = 1, 8 do
						local candidate = units[math.random(1, #units)]
						if candidate ~= cUnitID and not (triedAnchor and triedAnchor[candidate]) then
							buildnear = candidate
							break
						end
					end
				end
				if not buildnear then
					if anchorTry == 1 then ps.noAnchor = ps.noAnchor + 1 end
					break
				end
				triedAnchor = triedAnchor or {}
				triedAnchor[buildnear] = true

				local refDefID = Spring.GetUnitDefID(buildnear)
				if not refDefID then ps.noAnchor = ps.noAnchor + 1; break end
				local refDef = UnitDefs[refDefID]
				local refx, _, refz = Spring.GetUnitPosition(buildnear)
				local refIsStructure = IsStructure(refDef)
				local refHalf = refIsStructure and math.max(refDef.xsize or 2, refDef.zsize or 2) * 4 or 0

				-- Gap to the anchor, edge to edge: a lane (an apron if either
				-- side is a factory) plus a little jitter. Next to a mobile
				-- anchor there is nothing to keep clear of.
				local gap = math.random(0, GAP_JITTER)
				if refIsStructure then
					gap = gap + ((newIsFactory or refDef.isFactory) and FACTORY_APRON or LANE)
				end

				-- Build a direction priority list: prefer directions that move
				-- away from map edges, shuffle the rest.
				local dirs = {0, 1, 2, 3}
				-- Simple bubble: put edge-biased directions first
				if edgePushX > 0 then -- prefer +X (dir 1)
					table.remove(dirs, 2); table.insert(dirs, 1, 1)
				elseif edgePushX < 0 then -- prefer -X (dir 3)
					table.remove(dirs, 4); table.insert(dirs, 1, 3)
				end
				if edgePushZ > 0 then -- prefer +Z (dir 0)
					table.remove(dirs, 1); table.insert(dirs, 1, 0)
				elseif edgePushZ < 0 then -- prefer -Z (dir 2)
					for di = 1, #dirs do
						if dirs[di] == 2 then table.remove(dirs, di); break end
					end
					table.insert(dirs, 1, 2)
				end

				-- Each direction is tried at the lane distance and again a step
				-- further out, which is what gets a building past a ramp or a
				-- cliff edge beside the anchor instead of giving up on that side.
				for _, r in ipairs(dirs) do
				 for step = 0, 1 do
					local hx, hz = HalfSize(newDef, r)
					local reach = gap + step * FAR_STEP
					local bposx, bposz
					if     r == 0 then bposx = refx;                          bposz = refz + refHalf + hz + reach
					elseif r == 1 then bposx = refx + refHalf + hx + reach;   bposz = refz
					elseif r == 2 then bposx = refx;                          bposz = refz - refHalf - hz - reach
					else               bposx = refx - refHalf - hx - reach;   bposz = refz
					end

					-- A site that would have to be pushed back inside the map is
					-- not the site the lane arithmetic chose: skip it.
					local inLeash = true
					if maxDist and originX then
						local ldx, ldz = bposx - originX, bposz - originZ
						inLeash = (ldx * ldx + ldz * ldz) <= maxDist * maxDist
					end
					if inLeash and bposx >= 256 and bposx <= mapsizeX - 256 and bposz >= 256 and bposz <= mapsizeZ - 256 then
						local bposy   = Spring.GetGroundHeight(bposx, bposz)
						local testpos = Spring.TestBuildOrder(building, bposx, bposy, bposz, r)
						ps.sites = ps.sites + 1
						if testpos == 2 then
							if not SiteHasLanes(bposx, bposz, hx, hz, newIsFactory, cUnitID) then
								ps.crowded = ps.crowded + 1
							elseif (newIsFactory and not L.FactorySiteReachable(team, building, bposx, bposz))
									or not L.Reachable(team, builderDefID, bposx, bposz, REACH.TOL_BUILD) then
								ps.unreach = ps.unreach + 1
							else
								Spring.GiveOrderToUnit(cUnitID, -building, { bposx, bposy, bposz, r }, { "shift" })
								local p = pending[pendingNext]
								if not p then p = {}; pending[pendingNext] = p end
								p.x, p.z, p.hx, p.hz = bposx, bposz, hx, hz
								p.isFactory  = newIsFactory
								p.untilFrame = Spring.GetGameFrame() + PENDING_FOR
								pendingNext = (pendingNext % PENDING_MAX) + 1
								return true
							end
						elseif testpos == 0 then ps.blocked = ps.blocked + 1
						else ps.occupied = ps.occupied + 1 end
					end
				 end
				end
			 end
			else
				ps.noAnchor = ps.noAnchor + 1
			end
		end
		return false
	end


	-- ============================================================
	-- BRICK PLANNER
	-- How a player lays out a base: find a flat rectangle behind the base,
	-- then fill it with one kind of building, touching, row by row (shift-
	-- alt-drag). The AI can do the same because the engine will answer "can
	-- this building go exactly here?" for any spot (Spring.TestBuildOrder).
	--
	--   * A BRICK is a rectangle of slots for ONE unit type. Before a brick is
	--     adopted every slot is tested, so the whole block is known to be
	--     buildable, and the rectangle as a whole keeps a lane to everything
	--     around it. Inside the brick, buildings touch.
	--   * Bricks are sited by scanning outward from HOME, with ground on the
	--     enemy's side counted as farther away than it is, so economy fills
	--     the back of the base first.
	--   * A slot whose building later dies is simply free again, so losses are
	--     rebuilt in place before the base grows.
	--   * On cramped ground the brick shrinks (half size, then single
	--     building) before the planner gives up.
	-- State lives here because placement does (see `pending` above).
	-- ============================================================
	local BRICK = {
		STEP          = 96,     -- spacing of candidate brick centers (elmos)
		RADIUS        = 4000,   -- how far from home a brick may be
		MIN_DIST      = 320,    -- nearest a brick's center may be to home
		-- Ground toward the enemy counts up to (1 + this) times farther away
		-- than it is. Kept moderate on purpose: a strong bias gave tidy
		-- back-of-base layouts on open ground, but for a start against the
		-- map edge "behind" does not exist, and the base was pushed sideways
		-- along the edge for thousands of elmos instead of 600 forward.
		FRONT_PENALTY = 1.5,
		HOME_CLEAR    = 250,    -- no brick comes closer than this to the start position itself
		SCAN_PER_CALL = 300,    -- candidate centers examined when a builder asks (the search resumes later)
		SCAN_PER_TICK = 900,    -- ...and per team per AI tick by BrickService, for searches builders are waiting on
		NEAR          = 1400,   -- search bands (see BrickStages): nearer ground is tried at every
		MID           = 2600,   -- size before farther ground is tried at all
		RESCAN        = 9000,   -- frames after which the search starts over from home (~5 min)
		CLAIM         = 1800,   -- frames a slot stays reserved for the builder sent to it (~60s)
		SPOT_MARGIN   = 96,     -- keep bricks this far from metal spots
		MAX_W         = 576,    -- target brick width  (elmos): sets how many columns fit
		MAX_H         = 320,    -- target brick height (elmos): sets how many rows fit
		MAX_COLS      = 4,
		MAX_ROWS      = 3,
	}
	L.BRICK = BRICK
	-- what the last BrickOrder call did: "slot" (filled a slot of an existing
	-- brick), "new" (planned a brick and filled its first slot), "searching"
	-- (still looking; try again), "exhausted" (no room anywhere in range)
	L.brickResult = "searching"

	local brickTeams = {}   -- [teamID] = { cand = {...}, frontX, frontZ, bricks = { [defID] = {...} }, cursor = { [defID] = {...} } }

	-- Candidate centers around home, nearest first, back of the base first.
	local function BuildCandidates(homeX, homeZ, frontX, frontZ)
		local cand = {}
		local n = math.floor(BRICK.RADIUS / BRICK.STEP)
		for gz = -n, n do
			for gx = -n, n do
				local dx, dz = gx * BRICK.STEP, gz * BRICK.STEP
				local d = math.sqrt(dx * dx + dz * dz)
				if d >= BRICK.MIN_DIST and d <= BRICK.RADIUS then
					local x, z = homeX + dx, homeZ + dz
					if x > 128 and z > 128 and x < mapsizeX - 128 and z < mapsizeZ - 128 then
						local toward = (dx * frontX + dz * frontZ) / d      -- 1 = straight at the enemy
						local cost = d * (1 + BRICK.FRONT_PENALTY * math.max(0, toward))
						cand[#cand + 1] = { x = x, z = z, cost = cost }
					end
				end
			end
		end
		table.sort(cand, function(a, b)
			if a.cost ~= b.cost then return a.cost < b.cost end
			if a.x ~= b.x then return a.x < b.x end
			return a.z < b.z
		end)
		return cand
	end

	local function TeamBricks(teamID, homeX, homeZ, enemyX, enemyZ)
		local fx, fz
		if enemyX then fx, fz = enemyX - homeX, enemyZ - homeZ
		else fx, fz = mapsizeX / 2 - homeX, mapsizeZ / 2 - homeZ end
		local fl = math.sqrt(fx * fx + fz * fz)
		if fl < 1 then fx, fz, fl = 0, 1, 1 end
		fx, fz = fx / fl, fz / fl

		local T = brickTeams[teamID]
		if not T then
			T = { bricks = {}, cursor = {}, want = {}, knewEnemy = enemyX ~= nil }
			brickTeams[teamID] = T
			T.cand = BuildCandidates(homeX, homeZ, fx, fz)
		elseif enemyX and not T.knewEnemy then
			-- first sight of where the enemy is: re-rank the ground, once
			T.knewEnemy = true
			T.cand = BuildCandidates(homeX, homeZ, fx, fz)
			T.cursor = {}
		end
		return T
	end

	-- The brick sizes to try for a def, biggest first: full, half, single.
	local function BrickLevels(ud)
		local px, pz = (ud.xsize or 2) * 8, (ud.zsize or 2) * 8      -- slot pitch = footprint: buildings touch
		local cols = math.max(1, math.min(BRICK.MAX_COLS, math.floor(BRICK.MAX_W / px)))
		local rows = math.max(1, math.min(BRICK.MAX_ROWS, math.floor(BRICK.MAX_H / pz)))
		local levels = { { cols, rows } }
		local hc, hr = math.ceil(cols / 2), math.ceil(rows / 2)
		if hc ~= cols or hr ~= rows then levels[#levels + 1] = { hc, hr } end
		if hc ~= 1 or hr ~= 1 then levels[#levels + 1] = { 1, 1 } end
		return levels, px, pz
	end

	-- Build positions snap to the 16-elmo build grid (centers of odd footprints
	-- sit half a square off it). Snapping the first slot keeps every slot of
	-- the brick on the grid, since the pitch is a whole number of squares.
	local function Snap(v, sizeSquares)
		local odd = (sizeSquares % 4) == 2
		if odd then return math.floor(v / 16) * 16 + 8 end
		return math.floor(v / 16 + 0.5) * 16
	end

	local function NearMetalSpot(x1, z1, x2, z2)
		local spots = GG.metalMakerSpots
		if not spots then return false end
		local m = BRICK.SPOT_MARGIN
		for i = 1, #spots do
			local s = spots[i]
			if s.x > x1 - m and s.x < x2 + m and s.z > z1 - m and s.z < z2 + m then return true end
		end
		return false
	end

	-- Try to adopt a brick of cols x rows centered near (cx, cz). Returns the
	-- brick (already registered) or nil.
	local function TryBrick(defID, ud, cx, cz, cols, rows, px, pz, homeX, homeZ, teamID, builderDefID)
		local ps = L.placeStats
		local w, h = cols * px, rows * pz
		local x0 = Snap(cx - w / 2 + px / 2, ud.xsize or 2)       -- center of the first slot
		local z0 = Snap(cz - h / 2 + pz / 2, ud.zsize or 2)
		local left, top = x0 - px / 2, z0 - pz / 2
		local right, bottom = left + w, top + h
		if left < 128 or top < 128 or right > mapsizeX - 128 or bottom > mapsizeZ - 128 then return nil end
		-- cheapest test first: the middle of the rectangle
		local mx, mz = (left + right) / 2, (top + bottom) / 2
		-- leave the start position itself open (the commander, the first
		-- factory's traffic)
		if math.abs(mx - homeX) < w / 2 + BRICK.HOME_CLEAR and math.abs(mz - homeZ) < h / 2 + BRICK.HOME_CLEAR then
			return nil
		end
		if NearMetalSpot(left, top, right, bottom) then return nil end
		if not SiteHasLanes(mx, mz, w / 2, h / 2, ud.isFactory and true or false) then
			ps.crowded = ps.crowded + 1
			return nil
		end
		local slots = {}
		for r = 0, rows - 1 do
			for c = 0, cols - 1 do
				local sx, sz = x0 + c * px, z0 + r * pz
				local sy = Spring.GetGroundHeight(sx, sz)
				local test = Spring.TestBuildOrder(defID, sx, sy, sz, 0)
				ps.sites = ps.sites + 1
				if test == 0 then
					ps.blocked = ps.blocked + 1
					return nil       -- one bad slot spoils the rectangle
				end
				slots[#slots + 1] = { x = sx, y = sy, z = sz, claim = 0 }
			end
		end
		-- last, because it can cost a path request: can a builder walk to
		-- every slot? (A flat mesa top passes every test above.)
		if builderDefID then
			for i = 1, #slots do
				if not L.Reachable(teamID, builderDefID, slots[i].x, slots[i].z, REACH.TOL_BUILD) then
					ps.unreach = ps.unreach + 1
					return nil
				end
			end
		end
		local brick = { defID = defID, slots = slots, x = mx, z = mz, hx = w / 2, hz = h / 2 }
		allBricks[#allBricks + 1] = brick
		return brick
	end

	-- The order the search tries things in. A recorded game showed the cost of
	-- the simple order (every position at full size, then every position at
	-- half size...): on cramped ground the whole 4,000-elmo radius was scanned
	-- for a full brick before a smaller one right beside home was considered,
	-- and builders stood idle while it ran. Now nearer ground is tried at
	-- every useful size before farther ground is tried at all, which is both
	-- faster and keeps the base tighter:
	--     full, then half, within NEAR;  full, half within MID;
	--     single within NEAR;  full, half, single anywhere in range.
	-- "Within" is measured in the candidates' cost, so ground toward the enemy
	-- falls out of the near bands first.
	local function BrickStages(levels)
		local nearFar = { BRICK.NEAR, BRICK.MID, math.huge }
		local stages = {}
		local single = #levels                      -- the last level is always 1x1
		for band = 1, 3 do
			for lv = 1, #levels do
				if lv ~= single or #levels == 1 then
					stages[#stages + 1] = { level = lv, maxCost = nearFar[band] }
				end
			end
			if #levels > 1 and band == 2 then
				stages[#stages + 1] = { level = single, maxCost = nearFar[1] }
			end
		end
		if #levels > 1 then stages[#stages + 1] = { level = single, maxCost = math.huge } end
		return stages
	end

	-- Carry a def's brick search forward by up to `budget` candidates.
	-- Returns brick | nil, status ("found" | "searching" | "exhausted"), candidates used.
	local function SearchBrick(T, defID, ud, homeX, homeZ, now, budget, teamID)
		local levels, px, pz = BrickLevels(ud)
		local cur = T.cursor[defID]
		if not cur or (now - cur.since) >= BRICK.RESCAN then
			-- (re)start: every size begins again from the ground nearest home
			cur = { stage = 1, since = now, at = {}, stages = BrickStages(levels) }
			T.cursor[defID] = cur
		end
		local used = 0
		local cand = T.cand
		while cur.stage <= #cur.stages do
			local st = cur.stages[cur.stage]
			local cols, rows = levels[st.level][1], levels[st.level][2]
			local idx = cur.at[st.level] or 1      -- each size remembers how far out it has looked
			while idx <= #cand and cand[idx].cost <= st.maxCost do
				if used >= budget then
					cur.at[st.level] = idx
					return nil, "searching", used
				end
				used = used + 1
				local c = cand[idx]
				local brick = TryBrick(defID, ud, c.x, c.z, cols, rows, px, pz, homeX, homeZ, teamID, T.builderDef)
				if brick then
					-- next time start again from the first stage, but every
					-- size carries on from where it had got to
					cur.at[st.level] = idx
					cur.stage = 1
					return brick, "found", used
				end
				idx = idx + 1
			end
			cur.at[st.level] = idx
			cur.stage = cur.stage + 1
		end
		return nil, "exhausted", used          -- stays exhausted until the rescan
	end

	-- Order `cUnitID` to build `defID` in the team's base layout. Returns true
	-- if an order went out; L.brickResult says what happened either way.
	-- maxDist (optional): this builder only takes slots within maxDist of home
	-- (the commander's leash). A brick planned farther out is still adopted,
	-- for other builders; the result is then "leash" and no order goes out.
	function L.BrickOrder(cUnitID, defID, teamID, homeX, homeZ, enemyX, enemyZ, maxDist)
		local ps = L.placeStats
		ps.sites, ps.blocked, ps.occupied, ps.crowded, ps.noAnchor, ps.unreach = 0, 0, 0, 0, 0, 0
		local ud = UnitDefs[defID]
		if not ud or not homeX then L.brickResult = "exhausted"; return false end
		local now = Spring.GetGameFrame()
		local T = TeamBricks(teamID, homeX, homeZ, enemyX, enemyZ)

		local list = T.bricks[defID]
		if not list then list = {}; T.bricks[defID] = list end

		-- 1. A free slot in a brick this team already has (a first fill, or a
		--    building that died and left its slot open).
		local max2 = maxDist and maxDist * maxDist
		local leashed = false
		local function Fill(brick)
			for i = 1, #brick.slots do
				local s = brick.slots[i]
				local inLeash = true
				if max2 then
					local sdx, sdz = s.x - homeX, s.z - homeZ
					inLeash = (sdx * sdx + sdz * sdz) <= max2
					if not inLeash then leashed = true end
				end
				if inLeash and now >= s.claim then
					local test = Spring.TestBuildOrder(defID, s.x, s.y, s.z, 0)
					if test == 2 then
						Spring.GiveOrderToUnit(cUnitID, -defID, { s.x, s.y, s.z, 0 }, { "shift" })
						s.claim = now + BRICK.CLAIM
						-- The last slot of this team's newest brick is going
						-- out: have the service find the next brick now, so it
						-- is ready before a builder needs it.
						if brick == list[#list] and i == #brick.slots then T.want[defID] = true end
						return true
					elseif test == 1 then
						-- A unit is standing on the slot. It is passed over
						-- this time and stays free for later: a builder sent
						-- to an occupied site can wait there indefinitely.
						ps.occupied = ps.occupied + 1
					end
				end
			end
			return false
		end
		for i = 1, #list do
			if Fill(list[i]) then L.brickResult = "slot"; return true end
		end
		-- free slots exist, but beyond this builder's leash: leave them (and
		-- any further planning) to the builders who can go there
		if leashed then L.brickResult = "leash"; return false end

		-- 2. Plan the next brick.
		T.builderDef = Spring.GetUnitDefID(cUnitID) or T.builderDef   -- whose legs the reachability check uses
		local brick, status = SearchBrick(T, defID, ud, homeX, homeZ, now, BRICK.SCAN_PER_CALL, teamID)
		if brick then
			list[#list + 1] = brick
			T.want[defID] = nil
			if Fill(brick) then L.brickResult = "new"; return true end
			if leashed then L.brickResult = "leash"; return false end
		end
		-- Not found yet: the team's service call (BrickService, once per AI
		-- tick) carries the search on, so the next builder to ask usually
		-- finds the brick waiting.
		if status == "searching" then T.want[defID] = true else T.want[defID] = nil end
		L.brickResult = status
		return false
	end

	-- Once per AI tick per team: carry on any brick search a builder is
	-- waiting for, so builders do not have to stand idle while it runs.
	-- A brick found here is adopted empty; the next BrickOrder fills it.
	function L.BrickService(teamID, homeX, homeZ, enemyX, enemyZ)
		local T = brickTeams[teamID]
		if not T or not homeX then return end
		local now = Spring.GetGameFrame()
		local budget = BRICK.SCAN_PER_TICK
		-- fixed order so the outcome never depends on table iteration order
		local wanted = {}
		for defID in pairs(T.want) do wanted[#wanted + 1] = defID end
		table.sort(wanted)
		for i = 1, #wanted do
			if budget <= 0 then break end
			local defID = wanted[i]
			local ud = UnitDefs[defID]
			local brick, status, used = SearchBrick(T, defID, ud, homeX, homeZ, now, budget, teamID)
			budget = budget - (used or 0)
			if brick then
				local list = T.bricks[defID]
				if not list then list = {}; T.bricks[defID] = list end
				list[#list + 1] = brick
				T.want[defID] = nil
			elseif status ~= "searching" then
				T.want[defID] = nil
			end
		end
	end

	return L
end
