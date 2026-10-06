--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    luarules/configs/simpleai/behaviors/b_combat.lua
--  brief:   Combat behavior for the SimpleAI gadget (stage 3 of the modular
--           split). Owns everything about fielding an army: the muster point,
--           the ground census, squad state transitions and wave launches,
--           per-unit retreat hysteresis, and air/ground unit orders.
--
--           Owns ctx state: ctx.squad.*, ctx.pacing.lastLaunch,
--           ctx.pacing.lastTargetScan, ctx.retreat.
--           Reads (never writes): ctx.intel.*, classification tables.
--
--  usage:   VFS.Include(path)(ctx, lib, cfg) -> handler table
--           Handlers the core dispatches to:
--             unitFilter(unitDefID)          which units this behavior owns
--             TeamTick(tick)                 once per AI team tick
--             UnitTick(tick, unitID, ...)    per owned unit
--             BaseDamaged(teamID, frame)     enemy damaged one of our buildings
--
--  license: GNU GPL, v2 or later
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return function(ctx, lib, cfg)

	--------------------------------------------------------------------------
	-- Tunables (owned by this behavior)
	--------------------------------------------------------------------------
	local WAVE_MUSTER_SIZE  = 4      -- units that must be at muster point to trigger launch
	local MUSTER_RADIUS     = 600    -- how close a unit must be to count as "at muster"
	local GATHER_RADIUS     = 900    -- ...and how close to be counted as gathered for a launch (big armies need room)
	local WAVE_MIN_VALUE    = 400    -- a wave is never worth less than this much metal
	local LAUNCH_RATIO      = 1.0    -- launch when gathered value >= this x our share of the enemy's army value
	local WAVE_PATIENCE     = 7200   -- frames (~4 min) a gathered army waits for that edge before going anyway
	local PATIENCE_SHARE    = 0.6    -- ...provided this share of the team's ready army is at the staging point
	local WAVE_BREAK        = 0.35   -- a wave down to this share of the value it set out with is called home
	local WAVE_REGROUP      = 600    -- frames (~20s) after a wave ends before the next may launch
	local REINFORCE_SHARE   = 0.5    -- gathered units join a wave still out when worth this share of it...
	local REINFORCE_HEALTH  = 0.6    -- ...and only while the wave still has this share of the value it set out with
	-- (0.9, raised from 0.7 once sides began attacking together: a recording shows a side at
	-- about 0.75 of the enemy marching its whole army into a defended base on patience, losing
	-- it, and being out of the game eight minutes later. The weaker side waits; the stronger
	-- one is the one that runs out of patience.)
	local PATIENCE_RATIO    = 0.9    -- a patience launch still needs this x our share of the enemy's army
	local OUTMATCH_RATIO    = 0.6    -- wave value near its centre below this x enemy value there = outmatched
	local OUTMATCH_TICKS    = 2      -- ...for this many AI ticks in a row before it pulls back
	local WAVE_CORE_RADIUS  = 1000   -- wave members within this of the wave's centre count as "there"
	local OUTMATCH_RADIUS   = 1400   -- enemy armed units and turrets within this of the centre count against it
	local WAVE_REGROUP_BEATEN = 1800 -- frames (~60s) before the next launch after a wave is outmatched or broken
	local HUNT_REAIM        = 500    -- a hunted commander that has moved this far gets the wave re-aimed at it
	local SIDE_FRESH        = 600    -- frames an allied team's "ready to go" report stays current

	-- Raids (see RAIDS in TeamTick): small fast parties sent at undefended extractors.
	-- (One table, constants and state together: Lua allows a function only 60 upvalues,
	-- and TeamTick is close to that.)
	local RAID = {
		INTERVAL       = 2700,   -- frames (~90s) between one raid ending and the next forming
		RETRY          = 600,   -- ...or this long after a look that found nothing to raid
		MIN_ARMY       = 10,   -- no raiding until the team has this many ready ground units
		MIN_SIZE       = 3,   -- a raid is at least this many units
		SIZE_BASE      = 4,   -- raid size at tech 1...
		SIZE_PER_TECH  = 2,   -- ...plus this many per tech level above it
		SIZE_MAX       = 10,
		ARMY_SHARE     = 0.15,   -- a raid takes at most this share of the team's ready army value
		SPEED_SHARE    = 0.75,   -- raiders are at least this fast, relative to the fastest unit gathered
		FLEE_RATIO     = 0.8,   -- enemy strength near the party above this x its own value: run
		DANGER_R       = 900,   -- ...measured within this of the party
		BODY_R         = 600,   -- raiders within this of each other count as the party
		MAX_TIME       = 7200,   -- frames (~4 min) a raid stays out at most
		HOME_WAIT      = 1800,   -- frames a returning raid is given to get home before it is stood down anyway
		active = {},   -- [teamID] = { members = {[uid]=true}, start =, target =, state = "out"|"home", began =, homeAt =, hits = }
		ended  = {},   -- [teamID] = frame the last raid ended (or was last looked for)
		x = {}, z = {}, v = {},   -- scratch: raid members' positions and values this tick
		cand = {},     -- scratch: candidates for a new raid
	}
	local CALL_WINDOW       = 450    -- frames (~15s) allied teams have to join a launch that was just called
	local ENEMY_SCAN        = 300    -- frames between recounts of the enemy's army value
	local WAVE_COOLDOWN     = 1500   -- minimum frames between launches (~50s at 30Hz)
	local ATTACK_RETARGET   = 300    -- frames between weak-point re-scans during an active push

	-- Retreat hysteresis, on EFFECTIVE hp: (hull + shield) / (maxHull + maxShield).
	-- SF has no repair. Fed hulls autoheal; Loz hulls never recover but their shield
	-- (up to half their pool) does. A single threshold on raw hull therefore benches
	-- Loz units forever. Instead: enter retreat low, exit when recovered ENOUGH --
	-- where "enough" for Loz is a full shield (the best that unit will ever be again).
	local RETREAT_ENTER     = 0.50   -- effective-hp fraction that triggers retreat
	local RETREAT_EXIT      = 0.75   -- effective-hp fraction that ends retreat (Fed heals to this)
	local RETREAT_TIMEOUT   = 750    -- frames (~25s); catch-all exit so nothing wedges

	--------------------------------------------------------------------------
	-- Shared state / config
	--------------------------------------------------------------------------
	local mapsizeX = cfg.mapsizeX
	local mapsizeZ = cfg.mapsizeZ

	local IsCombat  = ctx.IsCombat
	local IsAir     = ctx.IsAir
	local ShieldMax = ctx.ShieldMax

	local SimpleRetreatState   = ctx.retreat
	local SimpleMusterPos      = ctx.squad.muster
	local SimpleSquadState     = ctx.squad.state
	local SimpleAttackWave     = ctx.squad.attackWave
	local SimpleLastLaunch     = ctx.pacing.lastLaunch
	local SimpleLastTargetScan = ctx.pacing.lastTargetScan
	local SimpleUnderAttack    = ctx.intel.underAttack
	local SimpleEnemyBasePos   = ctx.intel.enemyBase
	local SimpleBaseThreat     = ctx.intel.baseThreat

	local FindWeakestEnemyTarget = lib.FindWeakestEnemyTarget
	local ComputeMusterPos       = lib.ComputeMusterPos

	local B = { name = "combat", order = 50 }

	-- Wave state (see WAVES in TeamTick).
	local waveMembers = {}   -- [teamID] = { [unitID] = true } units in the wave that is out
	local waveStart   = {}   -- [teamID] = metal value the wave set out with (plus reinforcements)
	local waveEnded   = {}   -- [teamID] = frame the last wave ended
	local gatherList  = {}   -- scratch: units at the staging point this tick
	local enemyShare  = {}   -- [teamID] = { value =, frame = } cached enemy army share
	local waveRegroup = {}   -- [teamID] = frames to wait after the last wave ended
	-- Fighting as a side (see WAVES): what each allied AI team could send right
	-- now, the launch most recently called, and the target the side is on.
	local SIDE = {
		ready  = {},     -- [allyTeamID] = { [teamID] = { value =, frame = } }
		call   = {},     -- [allyTeamID] = { frame =, by = teamID, target = }
		target = {},     -- [allyTeamID] = { frame =, target = }
	}
	local outmatched  = {}   -- [teamID] = consecutive ticks the wave has been outmatched
	local MEM = { x = {}, z = {}, v = {} }   -- scratch: wave members' positions and values this tick
	local IsTurret = ctx.IsTurret or {}

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

	-- Metal value of the enemy's armed units and turrets within `radius` of a
	-- point: what a wave standing there is actually up against.
	local function EnemyValueNear(teamID, x, z, radius)
		local near = Spring.GetUnitsInCylinder(x, z, radius)
		local total = 0
		for i = 1, #near do
			local uid = near[i]
			local ut  = Spring.GetUnitTeam(uid)
			if ut and ut ~= teamID and not Spring.AreTeamsAllied(teamID, ut) then
				local d = Spring.GetUnitDefID(uid)
				if d and (IsCombat[d] or IsTurret[d]) then
					-- (lib.UnitStrength: metal cost, except that a commander counts for far more than its price)
					total = total + (lib.UnitStrength and lib.UnitStrength(d) or UnitValue(d))
				end
			end
		end
		return total
	end

	-- Metal value of ALLIED teams' combat units within `radius` of a point
	-- (this team's own units are counted by the caller).
	local function AlliedValueNear(teamID, x, z, radius)
		local near = Spring.GetUnitsInCylinder(x, z, radius)
		local total = 0
		for i = 1, #near do
			local uid = near[i]
			local ut  = Spring.GetUnitTeam(uid)
			if ut and ut ~= teamID and Spring.AreTeamsAllied(teamID, ut) then
				local d = Spring.GetUnitDefID(uid)
				if d and IsCombat[d] and not IsAir[d] then total = total + UnitValue(d) end
			end
		end
		return total
	end

	-- This team's fair share of the enemy's army: the metal value of every
	-- enemy ground combat unit, divided among the allied teams that still
	-- have units. Recounted every ENEMY_SCAN frames.
	local function EnemyShare(teamID, allyTeamID, n)
		local c = enemyShare[teamID]
		if c and (n - c.frame) < ENEMY_SCAN then return c.value end
		local enemyValue, liveAllies = 0, 0
		local teamList = Spring.GetTeamList()
		local gaia = Spring.GetGaiaTeamID()
		for i = 1, #teamList do
			local t = teamList[i]
			if t ~= gaia then
				local _, _, _, _, _, tAlly = Spring.GetTeamInfo(t, false)
				local tUnits = Spring.GetTeamUnits(t)
				if tAlly == allyTeamID then
					if #tUnits > 0 then liveAllies = liveAllies + 1 end
				else
					for k = 1, #tUnits do
						local d = Spring.GetUnitDefID(tUnits[k])
						if d and IsCombat[d] and not IsAir[d] then enemyValue = enemyValue + UnitValue(d) end
					end
				end
			end
		end
		local value = enemyValue / math.max(1, liveAllies)
		enemyShare[teamID] = { value = value, frame = n }
		return value
	end

	-- Wave events go to the game recording (tag "combat"), so launches and
	-- endings can be read back afterwards.
	local function Log(teamID, text)
		if GG.Recorder and GG.Recorder.Log then GG.Recorder.Log(teamID, "combat", text) end
	end

	-- Can this unit type get within weapon range of (x, z) from the team's
	-- home? (lib.Reachable; "yes" when the library has no such check.)
	local function CanReach(teamID, unitDefID, x, z)
		if not lib.Reachable then return true end
		return lib.Reachable(teamID, unitDefID, x, z, lib.REACH and lib.REACH.TOL_ATTACK)
	end

	function B.TeamInit(teamID)
		SimpleMusterPos[teamID]      = nil   -- set when first factory/commander known
		SimpleSquadState[teamID]     = "mustering"
		SimpleAttackWave[teamID]     = nil
		SimpleLastLaunch[teamID]     = 0
		SimpleLastTargetScan[teamID] = 0
	end

	--------------------------------------------------------------------------
	-- Ownership: all combat units, air and ground.
	--------------------------------------------------------------------------
	function B.unitFilter(unitDefID)
		return IsCombat[unitDefID] == true
	end

	--------------------------------------------------------------------------
	-- Per-team tick: muster point, ground census, squad state transitions.
	-- Writes tick.muster / tick.atMuster / tick.totalGround / tick.readyGround
	-- for anything downstream.
	--------------------------------------------------------------------------
	function B.TeamTick(tick)
		local n      = tick.frame
		local teamID = tick.teamID
		local units  = tick.units

		-- Adaptive difficulty knobs (b_adaptive, order 5, stamps tick.knobs
		-- before we run; nil for plain SimpleAI teams -> stock constants).
		-- Every mid anchor over in b_adaptive equals the constant here, so
		-- D = 0.5 is exactly stock behavior.
		local K            = tick.knobs
		local waveCooldown = K and K.waveCooldown     or WAVE_COOLDOWN
		local musterSize   = K and K.musterSize       or WAVE_MUSTER_SIZE
		-- Difficulty: the adaptive "muster size" knob (2 easy, 4 normal, 7
		-- hard) scales how much of an edge the team waits for, and the wave
		-- cooldown knob scales its patience. Easy teams attack while weaker.
		local launchRatio  = LAUNCH_RATIO * (musterSize / WAVE_MUSTER_SIZE)
		local patience     = WAVE_PATIENCE * (waveCooldown / WAVE_COOLDOWN)
		local allyTeamID   = tick.allyTeamID
		local retargetIv   = K and K.retargetInterval or ATTACK_RETARGET
		local useWeak      = (K == nil) or K.weakTargeting

		-- ---- Muster point: compute/refresh every ~40s or if unset ----
		if not SimpleMusterPos[teamID] or n % 2400 == 0 then
			SimpleMusterPos[teamID] = ComputeMusterPos(teamID)
		end
		local muster = SimpleMusterPos[teamID]
		tick.muster = muster

		-- Count ground combat units. Units in retreat are counted in
		-- totalGround but NOT in readyGround/atMuster: the recovering
		-- garrison must not inflate launch math.
		local atMuster    = 0
		local totalGround = 0
		local readyGround = 0
		local gathered    = 0      -- metal value of ready units at the staging point
		local readyValue  = 0      -- metal value of every ready ground unit
		local defCount    = {}     -- [unitDefID] = how many of this ground type the team has
		local members     = waveMembers[teamID]
		local waveValue, waveCount = 0, 0
		local seen        = members and {} or nil
		local raid        = RAID.active[teamID]
		local raidValue, raidCount = 0, 0
		local raidSeen    = raid and {} or nil
		if lib.ReachTick then lib.ReachTick(teamID) end
		for k = 1, #units do
			local uid    = units[k]
			local uDefID = Spring.GetUnitDefID(uid)
			if uDefID and IsCombat[uDefID] and not IsAir[uDefID] then
				totalGround = totalGround + 1
				defCount[uDefID] = (defCount[uDefID] or 0) + 1
				local value = UnitValue(uDefID)
				if members and members[uid] then
					seen[uid] = true
					waveValue = waveValue + value
					waveCount = waveCount + 1
					local mx, _, mz = Spring.GetUnitPosition(uid)
					MEM.x[waveCount], MEM.z[waveCount], MEM.v[waveCount] = mx, mz, value
				elseif raid and raid.members[uid] then
					raidSeen[uid] = true
					raidValue = raidValue + value
					raidCount = raidCount + 1
					local mx, _, mz = Spring.GetUnitPosition(uid)
					RAID.x[raidCount], RAID.z[raidCount], RAID.v[raidCount] = mx, mz, value
				elseif not SimpleRetreatState[uid] then
					readyGround = readyGround + 1
					readyValue  = readyValue + value
					if muster then
						local ux2, _, uz2 = Spring.GetUnitPosition(uid)
						local dx2 = ux2 - muster.x
						local dz2 = uz2 - muster.z
						if dx2*dx2 + dz2*dz2 < GATHER_RADIUS * GATHER_RADIUS then
							atMuster = atMuster + 1
							gathered = gathered + value
							gatherList[atMuster] = uid
						end
					end
				end
			end
		end
		for i = atMuster + 1, #gatherList do gatherList[i] = nil end
		if members then
			for uid in pairs(members) do
				if not seen[uid] then members[uid] = nil end      -- died (or left the team)
			end
		end
		if raid then
			for uid in pairs(raid.members) do
				if not raidSeen[uid] then raid.members[uid] = nil end
			end
		end

		-- ================= RAIDS =================
		-- A raid is a handful of fast, cheap, direct-damage units sent at an
		-- enemy metal extractor that nothing is guarding. It is not meant to
		-- win anything: it is meant to make the enemy look away from the
		-- front, mop up, and not get on with its own plans. Raids run all
		-- game, beside the main waves, and never take more than a small
		-- share of the army.
		--   FORM   every RAID.INTERVAL: the cheapest of the fast units at
		--          the staging point, if lib.FindRaidTarget has something
		--          soft enough for them.
		--   HIT    the extractor (an ATTACK order on it, so the party goes
		--          past whatever it meets on the way), then the next one.
		--   RUN    the moment enemy strength near the party is close to its
		--          own: it goes home and rejoins the army.
		local function RaidHome(why)
			raid.state  = "home"
			raid.homeAt = n
			if muster then
				for uid in pairs(raid.members) do
					Spring.GiveOrderToUnit(uid, CMD.MOVE,
					                       { muster.x + math.random(-150, 150), muster.y,
					                         muster.z + math.random(-150, 150) }, 0)
				end
			end
			Log(teamID, ("raidhome;why=%s;left=%d;value=%d;of=%d;hits=%d"):format(
				why, raidCount, raidValue, raid.start, raid.hits))
		end
		local function RaidTarget(target)
			raid.target = target
			for uid in pairs(raid.members) do
				Spring.GiveOrderToUnit(uid, CMD.ATTACK, { target.uid }, 0)
			end
		end

		if raid then
			if raidCount == 0 then
				Log(teamID, ("raidend;why=wiped;of=%d;hits=%d"):format(raid.start, raid.hits))
				RAID.active[teamID], RAID.ended[teamID], raid = nil, n, nil
			else
				-- where the party is: the raider with the most raid value around it
				local here, cx, cz = 0, RAID.x[1], RAID.z[1]
				local body2 = RAID.BODY_R * RAID.BODY_R
				for i = 1, raidCount do
					local sum = 0
					for j = 1, raidCount do
						local dx, dz = RAID.x[j] - RAID.x[i], RAID.z[j] - RAID.z[i]
						if dx * dx + dz * dz <= body2 then sum = sum + RAID.v[j] end
					end
					if sum > here then here, cx, cz = sum, RAID.x[i], RAID.z[i] end
				end
				if raid.state == "out" then
					local against = EnemyValueNear(teamID, cx, cz, RAID.DANGER_R)
					local t = raid.target
					local alive = t and Spring.ValidUnitID(t.uid) and not Spring.GetUnitIsDead(t.uid)
					if against > raidValue * RAID.FLEE_RATIO then
						RaidHome("defenders")
					elseif (n - raid.began) > RAID.MAX_TIME then
						RaidHome("time")
					elseif not alive then
						if t then raid.hits = raid.hits + 1 end
						local nextTarget = (raidValue >= raid.start * 0.5) and lib.FindRaidTarget
								and lib.FindRaidTarget(teamID, raidValue, raid.repDef)
						if nextTarget then
							RaidTarget(nextTarget)
							Log(teamID, ("raidnext;units=%d;value=%d;defense=%d"):format(raidCount, raidValue, nextTarget.defense or 0))
						else
							RaidHome("done")
						end
					end
				else   -- going home
					local arrived = false
					if muster then
						local dx, dz = cx - muster.x, cz - muster.z
						arrived = (dx * dx + dz * dz) <= GATHER_RADIUS * GATHER_RADIUS
					end
					if arrived or (n - raid.homeAt) > RAID.HOME_WAIT then
						Log(teamID, ("raidend;why=home;left=%d;of=%d;hits=%d"):format(raidCount, raid.start, raid.hits))
						RAID.active[teamID], RAID.ended[teamID], raid = nil, n, nil
					end
				end
			end

		elseif useWeak and lib.FindRaidTarget and not tick.baseThreat
				and readyGround >= RAID.MIN_ARMY and atMuster >= RAID.MIN_SIZE
				and (n - (RAID.ended[teamID] or -99999)) >= RAID.INTERVAL then
			-- candidates: units at the staging point that deal direct damage
			-- (heat cannot touch buildings, disruption cannot kill)
			local nc, fastest = 0, 0
			for i = 1, atMuster do
				local uid = gatherList[i]
				local d   = Spring.GetUnitDefID(uid)
				if d and not (lib.NonDirectClass and lib.NonDirectClass(d)) then
					local speed = (UnitDefs[d] and UnitDefs[d].speed) or 0
					nc = nc + 1
					local c = RAID.cand[nc]
					if not c then c = {}; RAID.cand[nc] = c end
					c.uid, c.def, c.speed, c.value = uid, d, speed, UnitValue(d)
					if speed > fastest then fastest = speed end
				end
			end
			for i = nc + 1, #RAID.cand do RAID.cand[i] = nil end
			-- the fast ones, cheapest first
			table.sort(RAID.cand, function(a, b)
				local af, bf = a.speed >= fastest * RAID.SPEED_SHARE, b.speed >= fastest * RAID.SPEED_SHARE
				if af ~= bf then return af end
				if a.value ~= b.value then return a.value < b.value end
				return a.uid < b.uid
			end)
			local tech   = (ctx.techLevel and ctx.techLevel[teamID]) or 1
			local size   = math.min(RAID.SIZE_MAX, RAID.SIZE_BASE + RAID.SIZE_PER_TECH * math.max(0, tech - 1))
			local budget = readyValue * RAID.ARMY_SHARE
			local picked, pickedValue = {}, 0
			for i = 1, nc do
				local c = RAID.cand[i]
				if #picked >= size or c.speed < fastest * RAID.SPEED_SHARE then break end
				if pickedValue + c.value > budget and #picked >= RAID.MIN_SIZE then break end
				picked[#picked + 1] = c
				pickedValue = pickedValue + c.value
			end
			local target = (#picked >= RAID.MIN_SIZE) and lib.FindRaidTarget(teamID, pickedValue, picked[1].def)
			if target then
				raid = { members = {}, start = pickedValue, state = "out", began = n, hits = 0, repDef = picked[1].def }
				RAID.active[teamID] = raid
				local taken = {}
				for i = 1, #picked do
					raid.members[picked[i].uid] = true
					taken[picked[i].uid] = true
				end
				RaidTarget(target)
				Log(teamID, ("raid;units=%d;value=%d;defense=%d"):format(#picked, pickedValue, target.defense or 0))
				-- the raiders are no longer part of what is gathered for a wave
				local keep = 0
				for i = 1, atMuster do
					local uid = gatherList[i]
					if not taken[uid] then keep = keep + 1; gatherList[keep] = uid end
				end
				for i = keep + 1, atMuster do gatherList[i] = nil end
				atMuster    = keep
				gathered    = gathered - pickedValue
				readyValue  = readyValue - pickedValue
				readyGround = readyGround - #picked
			else
				RAID.ended[teamID] = n - RAID.INTERVAL + RAID.RETRY      -- nothing soft enough: look again soon
			end
		end

		tick.atMuster    = atMuster
		tick.totalGround = totalGround
		tick.readyGround = readyGround

		-- Tell the library what the army mostly is, so target and staging
		-- choices are checked against how THAT kind of unit moves (see
		-- REACHABILITY in lib.lua). Ties go to the lower def ID so the
		-- choice never depends on table order.
		if lib.SetArmyDef then
			local bestDef, bestN
			for d, c in pairs(defCount) do
				if not bestN or c > bestN or (c == bestN and d < bestDef) then bestDef, bestN = d, c end
			end
			if bestDef then lib.SetArmyDef(teamID, bestDef) end
		end

		local baseThreat = tick.baseThreat

		-- ================= WAVES =================
		-- Recordings showed the old rules produced a conveyor belt, not
		-- waves: a "wave" launched at four units, attack mode never ended
		-- while factories kept running, and so every new unit walked to the
		-- target alone. Units left base in 30+ of every 36 minutes, most were
		-- dead within two, and almost none reached an enemy base. Now:
		--
		--   LAUNCH on strength, as a side. Each allied AI team reports what it
		--     has gathered and could send. They go when the SUM is at least
		--     launchRatio times their part of the enemy's army (enemy army
		--     value divided among the allied teams still alive, times the
		--     number of teams reporting), and the teams that are ready go
		--     together at one target (see FIGHT AS A SIDE below). A team that has waited WAVE_PATIENCE with most of its
		--     army gathered goes anyway, so two cautious sides cannot stare
		--     at each other forever.
		--   MEMBERS. Only the units that launched are in the wave. Units
		--     built afterwards gather at the staging point like before a
		--     launch; they do not trickle after the wave.
		--   REINFORCE in groups. If the wave is still out and the gathered
		--     units are worth a real share of it, they are sent to join.
		--   END. A wave that is clearly outmatched where it stands pulls back
		--     (see READ THE FIGHT below). Failing that, when it is down to
		--     WAVE_BREAK of the value it set out with, the survivors are
		--     called home. Either way the team gathers again.
		local function Launch(why, fresh, preset)
			local list = waveMembers[teamID]
			if not list or fresh then list = {}; waveMembers[teamID] = list end
			local target = SimpleAttackWave[teamID]
			if preset then
				target = preset
				SimpleAttackWave[teamID] = target
			elseif fresh or not target then
				-- Aim at the WEAKEST-defended enemy structure, not the centre
				-- of mass (usually the most fortified spot). Low-difficulty
				-- adaptive teams skip the scan and plow at the centroid.
				-- ...unless an enemy commander is there for the taking: a
				-- side is out when its last commander dies (lib.FindCommanderTarget).
				local hunt = useWeak and lib.FindCommanderTarget and lib.FindCommanderTarget(teamID, gathered)
				if hunt then
					Log(teamID, ("hunt;last=%d;guard=%d;value=%d"):format(hunt.last and 1 or 0, hunt.guard or 0, gathered))
				end
				target = hunt
						or (useWeak and FindWeakestEnemyTarget(teamID) or nil)
						or SimpleEnemyBasePos[teamID]
						or {
							x = mapsizeX / 2 + math.random(-500, 500),
							z = mapsizeZ / 2 + math.random(-500, 500),
							y = Spring.GetGroundHeight(mapsizeX / 2, mapsizeZ / 2),
						}
				SimpleAttackWave[teamID] = target
			end
			local sent, sentValue = 0, 0
			for i = 1, atMuster do
				local uid    = gatherList[i]
				local uDefID = Spring.GetUnitDefID(uid)
				if uDefID and CanReach(teamID, uDefID, target.x, target.z) then
					list[uid] = true
					sent = sent + 1
					sentValue = sentValue + UnitValue(uDefID)
					Spring.GiveOrderToUnit(uid, CMD.FIGHT,
					                       { target.x + math.random(-200, 200),
					                         target.y,
					                         target.z + math.random(-200, 200) },
					                       { "alt", "ctrl" })
				end
			end
			if fresh then
				waveStart[teamID] = sentValue
			else
				waveStart[teamID] = (waveStart[teamID] or 0) + sentValue
			end
			Log(teamID, ("%s;why=%s;units=%d;value=%d;enemyShare=%d"):format(
				fresh and "launch" or "reinforce", why, sent, sentValue, EnemyShare(teamID, allyTeamID, n)))
			return sent
		end

		local function EndWave(why)
			local list = waveMembers[teamID]
			if list and muster then
				for uid in pairs(list) do
					Spring.GiveOrderToUnit(uid, CMD.MOVE,
					                       { muster.x + math.random(-150, 150), muster.y,
					                         muster.z + math.random(-150, 150) }, 0)
				end
			end
			Log(teamID, ("end;why=%s;left=%d;value=%d;of=%d"):format(why, waveCount, waveValue, waveStart[teamID] or 0))
			waveMembers[teamID]      = nil
			waveStart[teamID]        = nil
			waveEnded[teamID]        = n
			waveRegroup[teamID]      = WAVE_REGROUP_BEATEN
			outmatched[teamID]       = 0
			SimpleSquadState[teamID] = "mustering"
			SimpleAttackWave[teamID] = nil
		end

		local state = SimpleSquadState[teamID]
		if state == "attacking" then
			local start = waveStart[teamID] or 0
			if waveCount == 0 then
				EndWave("wiped")
			elseif waveValue < start * WAVE_BREAK then
				EndWave("broken")
			else
				-- READ THE FIGHT. The first version of waves only ended when
				-- 65% of the wave was dead, and a recording showed every
				-- single wave ending that way. Now the wave looks at what is
				-- in front of it: its own value where it stands against the
				-- enemy's armed units and turrets there. Clearly outmatched
				-- for a couple of ticks running, it pulls back while it is
				-- still an army, and the team gathers again.
				-- The judgement is made where the wave's MAIN BODY is: the
				-- member with the most wave value around it marks the spot.
				-- (The first version used the average position of all
				-- members. A wave strung out between home and the front
				-- has its average in the empty middle; a recording shows
				-- a 7,246-metal wave recalled because only 105 of it was
				-- near that point and 360 of enemy happened to be.)
				local here, cx, cz = 0, nil, nil
				local core2 = WAVE_CORE_RADIUS * WAVE_CORE_RADIUS
				for i = 1, waveCount do
					local xi, zi = MEM.x[i], MEM.z[i]
					local sum = 0
					for j = 1, waveCount do
						local dx, dz = MEM.x[j] - xi, MEM.z[j] - zi
						if dx * dx + dz * dz <= core2 then sum = sum + MEM.v[j] end
					end
					if sum > here then here, cx, cz = sum, xi, zi end
				end
				local beaten = false
				if cx then
					local against = EnemyValueNear(teamID, cx, cz, OUTMATCH_RADIUS)
					-- allied waves standing with this one count on its side
					if against > 0 then here = here + AlliedValueNear(teamID, cx, cz, WAVE_CORE_RADIUS) end
					if against > 0 and here < against * OUTMATCH_RATIO then
						outmatched[teamID] = (outmatched[teamID] or 0) + 1
						if outmatched[teamID] >= OUTMATCH_TICKS then
							Log(teamID, ("outmatched;here=%d;against=%d"):format(here, against))
							beaten = true
						end
					else
						outmatched[teamID] = 0
					end
				end
				if beaten then
					EndWave("outmatched")
				else
					-- still out: roll onto fresh weak points as defences collapse
					if useWeak and (n - SimpleLastTargetScan[teamID]) >= retargetIv then
						SimpleLastTargetScan[teamID] = n
						-- One target per side: the first allied wave to re-scan
						-- in an interval chooses, the others follow it. An enemy
						-- commander the wave can take comes first; failing that
						-- the softest building. Commanders move, so a hunted one
						-- that has gone elsewhere gets the wave re-aimed.
						local st  = SIDE.target[allyTeamID]
						local old = SimpleAttackWave[teamID]
						local newTarget
						if st and (n - st.frame) < retargetIv then
							newTarget = st.target
						else
							newTarget = (lib.FindCommanderTarget and lib.FindCommanderTarget(teamID, waveValue))
									or FindWeakestEnemyTarget(teamID)
							if newTarget then SIDE.target[allyTeamID] = { frame = n, target = newTarget } end
						end
						if newTarget then
							SimpleAttackWave[teamID] = newTarget
							if newTarget.uid then
								local moved = true
								if old then
									local dx, dz = newTarget.x - old.x, newTarget.z - old.z
									moved = (dx * dx + dz * dz) > HUNT_REAIM * HUNT_REAIM
								end
								if moved then
									if not (old and old.uid) then
										Log(teamID, ("hunt;last=%d;guard=%d;value=%d"):format(
											newTarget.last and 1 or 0, newTarget.guard or 0, waveValue))
									end
									for uid in pairs(members) do
										Spring.GiveOrderToUnit(uid, CMD.FIGHT,
										                       { newTarget.x + math.random(-150, 150), newTarget.y,
										                         newTarget.z + math.random(-150, 150) },
										                       { "alt", "ctrl" })
									end
								end
							end
						end
					end
					-- Reinforce in a group, never one by one, and only a
					-- wave that is holding up: sending groups after a dying
					-- wave was just a slower trickle (a recording showed a
					-- group leaving every 30 to 60 seconds).
					if not baseThreat and atMuster >= musterSize
							and (outmatched[teamID] or 0) == 0
							and waveValue >= start * REINFORCE_HEALTH
							and gathered >= math.max(WAVE_MIN_VALUE, waveValue * REINFORCE_SHARE) then
						Launch("group", false)
					end
				end
			end

		else   -- mustering
			-- FIGHT AS A SIDE. Each team used to weigh its own gathered
			-- army against its own share of the enemy and go alone, and a
			-- recording showed where that leads: the weaker teams of a side
			-- walked out by themselves into the whole enemy force (one took
			-- 90% of its losses outnumbered). Now the allied AI teams report
			-- what each could send, the SUM is weighed against the enemy,
			-- and when one team launches the others that are ready go with
			-- it, at the same target.
			local sinceEnd   = n - (waveEnded[teamID] or -99999)
			local cooldownOk = (n - SimpleLastLaunch[teamID]) >= waveCooldown
					and sinceEnd >= (waveRegroup[teamID] or WAVE_REGROUP)
			local canGo = cooldownOk and not baseThreat and atMuster >= musterSize and gathered >= WAVE_MIN_VALUE

			local ready = SIDE.ready[allyTeamID]
			if not ready then ready = {}; SIDE.ready[allyTeamID] = ready end
			ready[teamID] = { value = canGo and gathered or 0, frame = n }

			if canGo then
				local why, preset
				local call = SIDE.call[allyTeamID]
				if call and call.by ~= teamID and (n - call.frame) <= CALL_WINDOW then
					why, preset = "ally", call.target          -- an ally just launched: go with it
				else
					local sideValue, sideTeams = 0, 0
					for t, r in pairs(ready) do
						if (n - r.frame) <= SIDE_FRESH then
							sideValue = sideValue + r.value
							sideTeams = sideTeams + 1
						end
					end
					local share = EnemyShare(teamID, allyTeamID, n) * sideTeams   -- the reporting teams' part of the enemy
					if sideValue >= share * launchRatio then
						why = "strength"
					elseif (n - math.max(SimpleLastLaunch[teamID], waveEnded[teamID] or 0)) >= patience
							and gathered >= readyValue * PATIENCE_SHARE
							and sideValue >= share * PATIENCE_RATIO then
						-- (patience needs a real army: a side that weak stays
						-- home and defends)
						why = "patience"
					end
				end
				if why then
					SimpleSquadState[teamID]     = "attacking"
					SimpleLastLaunch[teamID]     = n
					SimpleLastTargetScan[teamID] = n
					if Launch(why, true, preset) == 0 then
						-- nothing could reach the target: stay home
						SimpleSquadState[teamID] = "mustering"
						waveMembers[teamID], waveStart[teamID] = nil, nil
						SimpleAttackWave[teamID] = nil
					else
						ready[teamID].value = 0
						if why ~= "ally" then
							SIDE.call[allyTeamID]   = { frame = n, by = teamID, target = SimpleAttackWave[teamID] }
							SIDE.target[allyTeamID] = { frame = n, target = SimpleAttackWave[teamID] }
						end
					end
				end
			end
		end
	end

	--------------------------------------------------------------------------
	-- Per-unit orders for owned (combat) units.
	--------------------------------------------------------------------------
	function B.UnitTick(tick, unitID, unitDefID, hpRatio, ux, uy, uz, unitCmds)
		local n          = tick.frame
		local teamID     = tick.teamID
		local allyTeamID = tick.allyTeamID
		local muster     = tick.muster
		local luaAI      = tick.luaAI
		local allunits   = tick.allUnits
		-- Adaptive retreat discipline: low difficulty fights nearly to the
		-- death (enter threshold sinks toward 0.20); exit rules stay stock.
		local K          = tick.knobs
		local rEnter     = K and K.retreatEnter or RETREAT_ENTER

		-- AIR: always independent, hunt nearest enemy
		if IsAir[unitDefID] then
			if unitCmds == 0 then
				local target = Spring.GetUnitNearestEnemy(unitID, 999999, false)
				if target then
					local tx, ty, tz = Spring.GetUnitPosition(target)
					Spring.GiveOrderToUnit(unitID, CMD.FIGHT,
					                       { tx + math.random(-80, 80), ty,
					                         tz + math.random(-80, 80) },
					                       { "shift", "alt", "ctrl" })
				end
			end

			-- DEFENDER AI: patrol near ally structures
		elseif string.sub(luaAI, 1, 16) == 'SimpleDefenderAI' then
			if unitCmds == 0 then
				for t = 1, 10 do
					local target = allunits[math.random(1, #allunits)]
					if Spring.GetUnitAllyTeam(target) == allyTeamID then
						local tx, ty, tz = Spring.GetUnitPosition(target)
						Spring.GiveOrderToUnit(unitID, CMD.FIGHT,
						                       { tx + math.random(-100, 100), ty,
						                         tz + math.random(-100, 100) },
						                       { "shift", "alt", "ctrl" })
						break
					end
				end
			end

			-- GROUND / SEA: squad staging system
		else
			-- ---- Retreat hysteresis ----
			-- Enter low on EFFECTIVE hp; exit on recovery,
			-- full shield (Loz's ceiling: hull never heals,
			-- so a topped-off shield means this unit is as
			-- good as it will ever get -- field it), or a
			-- timeout so nothing can wedge in retreat.
			local retreatFrame = SimpleRetreatState[unitID]
			if retreatFrame then
				local exitNow = hpRatio >= RETREAT_EXIT
						or (n - retreatFrame) >= RETREAT_TIMEOUT
				if not exitNow then
					local smax = ShieldMax[unitDefID]
					if smax then
						local s = Spring.GetUnitRulesParam(
								unitID, "personalShield") or 0
						if s >= smax then exitNow = true end
					end
				end
				if exitNow then
					SimpleRetreatState[unitID] = nil
					retreatFrame = nil
				end
			elseif hpRatio < rEnter then
				-- Enter retreat: break off IMMEDIATELY
				-- (replace the queue; a unit this hurt must
				-- not finish walking a FIGHT queue first).
				SimpleRetreatState[unitID] = n
				retreatFrame = n
				-- a unit this hurt leaves its wave: when it recovers it
				-- gathers with the rest instead of walking back out alone
				local wm = waveMembers[teamID]
				if wm then wm[unitID] = nil end
				local rd = RAID.active[teamID]
				if rd then rd.members[unitID] = nil end
				if muster then
					Spring.GiveOrderToUnit(unitID, CMD.MOVE,
					                       { muster.x + math.random(-100, 100),
					                         muster.y,
					                         muster.z + math.random(-100, 100) }, 0)
				end
			end

			if retreatFrame then
				-- Holding: if idle and drifted from muster,
				-- head back. Otherwise sit and recover.
				if unitCmds == 0 and muster and retreatFrame ~= n then
					local rdx = ux - muster.x
					local rdz = uz - muster.z
					if rdx * rdx + rdz * rdz
							> MUSTER_RADIUS * MUSTER_RADIUS then
						Spring.GiveOrderToUnit(unitID, CMD.MOVE,
						                       { muster.x + math.random(-100, 100),
						                         muster.y,
						                         muster.z + math.random(-100, 100) }, 0)
					end
				end

			elseif RAID.active[teamID] and RAID.active[teamID].members[unitID] then
				-- Raider: keep it on its job if its orders ran out.
				if unitCmds == 0 then
					local rd = RAID.active[teamID]
					local t  = rd.target
					if rd.state == "out" and t and Spring.ValidUnitID(t.uid) and not Spring.GetUnitIsDead(t.uid) then
						Spring.GiveOrderToUnit(unitID, CMD.ATTACK, { t.uid }, 0)
					elseif rd.state == "home" and muster then
						local mdx, mdz = ux - muster.x, uz - muster.z
						if mdx * mdx + mdz * mdz > MUSTER_RADIUS * MUSTER_RADIUS then
							Spring.GiveOrderToUnit(unitID, CMD.MOVE,
							                       { muster.x + math.random(-150, 150), muster.y,
							                         muster.z + math.random(-150, 150) }, 0)
						end
					end
				end

			elseif SimpleSquadState[teamID] == "attacking"
					and waveMembers[teamID] and waveMembers[teamID][unitID] then
				-- Attack mode: push to wave target or engage nearby foes
				if unitCmds == 0 then
					local wave = SimpleAttackWave[teamID]
					local nearEnemy = Spring.GetUnitNearestEnemy(
							unitID, 1500, false)
					-- An enemy this unit cannot get within range of (up on a
					-- sealed-off mesa, across a chasm) is not a target: units
					-- used to pack against the cliff below it and stay there.
					local tx, ty, tz
					if nearEnemy then
						tx, ty, tz = Spring.GetUnitPosition(nearEnemy)
						if tx and not CanReach(teamID, unitDefID, tx, tz) then tx = nil end
					end
					if tx then
						Spring.GiveOrderToUnit(unitID, CMD.FIGHT,
						                       { tx + math.random(-60, 60), ty,
						                         tz + math.random(-60, 60) },
						                       { "shift", "alt", "ctrl" })
					elseif wave and CanReach(teamID, unitDefID, wave.x, wave.z) then
						Spring.GiveOrderToUnit(unitID, CMD.FIGHT,
						                       { wave.x + math.random(-150, 150),
						                         wave.y,
						                         wave.z + math.random(-150, 150) },
						                       { "shift", "alt", "ctrl" })
					elseif muster then
						-- nothing it can get to: hold at the staging point
						local mdx, mdz = ux - muster.x, uz - muster.z
						if mdx * mdx + mdz * mdz > MUSTER_RADIUS * MUSTER_RADIUS then
							Spring.GiveOrderToUnit(unitID, CMD.FIGHT,
							                       { muster.x + math.random(-150, 150),
							                         muster.y,
							                         muster.z + math.random(-150, 150) }, 0)
						end
					end
				end

			else
				-- Muster / home-guard mode.
				local bthreat = SimpleBaseThreat[teamID]
				if bthreat then
					-- Intruder in the base: lock onto the specific unit so we
					-- chase and kill it instead of strolling past. ATTACK on the
					-- unitID tracks it if it moves. Only (re)issue if we are not
					-- already on this exact target, to avoid order thrashing.
					local cmds  = Spring.GetCommandQueue(unitID, 1)
					local first = cmds and cmds[1]
					local onIt  = first and first.id == CMD.ATTACK
					    and first.params and first.params[1] == bthreat.uid
					if not onIt then
						Spring.GiveOrderToUnit(unitID, CMD.ATTACK, { bthreat.uid }, 0)
					end
				else
					-- No intruder: attack-move to the staging area so we engage
					-- anything we pass on the way. (Plain MOVE used to ignore
					-- enemies en route, which is why units walked past raiders.)
					local nearEnemy = Spring.GetUnitNearestEnemy(unitID, 600, true)
					if nearEnemy then
						local ex, _, ez = Spring.GetUnitPosition(nearEnemy)
						if ex and not CanReach(teamID, unitDefID, ex, ez) then nearEnemy = nil end
					end
					if nearEnemy and unitCmds == 0 then
						local tx, ty, tz = Spring.GetUnitPosition(nearEnemy)
						Spring.GiveOrderToUnit(unitID, CMD.FIGHT,
						                       { tx, ty, tz }, { "shift", "alt", "ctrl" })
						if muster then
							Spring.GiveOrderToUnit(unitID, CMD.FIGHT,
							                       { muster.x + math.random(-150, 150),
							                         muster.y,
							                         muster.z + math.random(-150, 150) },
							                       { "shift" })
						end
					elseif unitCmds == 0 and muster then
						Spring.GiveOrderToUnit(unitID, CMD.FIGHT,
						                       { muster.x + math.random(-200, 200),
						                         muster.y,
						                         muster.z + math.random(-200, 200) }, 0)
					end
				end
			end
		end
	end

	--------------------------------------------------------------------------
	-- An enemy damaged one of our buildings: fast-track the next wave by
	-- reducing the REMAINING cooldown to at most half. min() against the
	-- CURRENT frame keeps this idempotent under sustained fire.
	--------------------------------------------------------------------------
	function B.BaseDamaged(teamID, frame)
		SimpleLastLaunch[teamID] = math.min(SimpleLastLaunch[teamID] or 0,
		                                    frame - WAVE_COOLDOWN / 2)
	end

	return B
end
