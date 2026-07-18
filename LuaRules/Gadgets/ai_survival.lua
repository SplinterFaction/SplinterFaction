--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    ai_survival.lua
--  brief:   Survival AI core. A selectable Lua AI ("SurvivalAI" in LuaAI.lua)
--           that sends escalating waves of regular units at every enemy team.
--           Pools are built from factory build lists at load time; composition,
--           targeting, placement and beacons live in the survivalai modules.
--
--           The survival team's physical presence is its beacons ("beacon"
--           unitdef, commander-class): the spawn gadget plants the master
--           beacon in place of a commander, waves spawn from live beacons,
--           new beacons creep toward the players every few waves, and killing
--           one awards RP and triggers a retaliation wave within seconds.
--           Clearing every beacon eliminates the team = player victory via the
--           normal commander-elimination flow.
--
--  author:  SF
--  license: GNU GPL, v2 or later
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name    = "SurvivalAI",
		desc    = "Wave-based survival opponent (selectable Lua AI)",
		author  = "SF",
		date    = "2026",
		license = "GNU GPL, v2 or later",
		layer   = 100,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

-- LuaAI.lua entry names -> difficulty tuning. Add variants here AND in
-- LuaAI.lua with the exact same string, or the team is silently not recognised.
local DIFFICULTIES = {
	["SurvivalAI"] = { budgetMult = 1.0 },
}

local GRACE_SECONDS     = 180    -- calm before the first wave (after placement)
local WAVE_INTERVAL_SEC = 60     -- seconds between waves
local BASE_BUDGET       = 1000    -- metal value of wave 1
local LINEAR_GROWTH     = 0.30   -- +30% of base per wave, linearly
local COMPOUND_GROWTH   = 1.06   -- and 6% compounding on top
local MAX_WAVE_UNITS    = 40     -- hard cap per wave per survival team (perf)

-- Minutes (on the wave clock) at which each tech tier joins the pools
local TIER_UNLOCK_MINUTES = { [1] = 0, [2] = 10, [3] = 20 }

-- Beacons
local BEACON_UNIT           = "beacon"
local BEACON_EVERY_N_WAVES  = 3      -- creep a new beacon after every Nth wave
local BEACON_BUDGET_BONUS   = 0.15   -- +15% wave budget per live beacon beyond the first
local BEACON_RP_REWARD      = 250    -- research points to the killer of a beacon
local RETALIATION_DELAY_SEC = 5      -- beacon death pulls the next wave to now + this
local BEACON_CREEP_MIN_DIST = 900    -- new beacon spawns at least this far from its source...
local BEACON_CREEP_MAX_DIST = 2000   -- ...and at most this far (the leash)
local SURVIVAL_DEBUG        = true   -- echo per-attempt creep placement rejections

local CHECK_PERIOD_FRAMES   = 15   -- scheduler granularity
local REORDER_PERIOD_FRAMES = 150  -- idle-straggler sweep (5 s)

local MODULE_DIR = "luaRules/configs/survivalai/"

--------------------------------------------------------------------------------

local Pools    = VFS.Include(MODULE_DIR .. "s_pools.lua")
local Composer = VFS.Include(MODULE_DIR .. "s_wavecomposer.lua")
local Spawner  = VFS.Include(MODULE_DIR .. "s_spawner.lua")
local Beacons  = VFS.Include(MODULE_DIR .. "s_beacons.lua")

local spGetTeamList          = Spring.GetTeamList
local spGetTeamInfo          = Spring.GetTeamInfo
local spGetTeamLuaAI         = Spring.GetTeamLuaAI
local spGetGaiaTeamID        = Spring.GetGaiaTeamID
local spGetTeamRulesParam    = Spring.GetTeamRulesParam
local spGetGameRulesParam    = Spring.GetGameRulesParam
local spSetGameRulesParam    = Spring.SetGameRulesParam
local spGetTeamStartPosition = Spring.GetTeamStartPosition
local spGetUnitPosition      = Spring.GetUnitPosition
local spGetUnitTeam          = Spring.GetUnitTeam
local spGetUnitsInCylinder   = Spring.GetUnitsInCylinder
local spGetGroundHeight      = Spring.GetGroundHeight
local spTestBuildOrder       = Spring.TestBuildOrder
local spAreTeamsAllied       = Spring.AreTeamsAllied
local spCreateUnit           = Spring.CreateUnit
local spGetGameFrame         = Spring.GetGameFrame
local spIsGameOver           = Spring.IsGameOver
local spEcho                 = Spring.Echo

local gaiaID = spGetGaiaTeamID()

local survivalTeams = {}    -- [teamID] = { diff, spawnX, spawnZ, targetX, targetZ,
                            --              clockStartFrame, defeated }
local anySurvival   = false

local pools           = nil
local isBuildingByDef = {}  -- [unitDefID] = true (for target weighting)
local beaconDefID     = nil

local clockStarted  = false -- wave clock starts once the pre-game phase is done
local nextWaveFrame = nil
local waveNumber    = 0     -- shared wave counter (all survival teams in step)
local gameOverSeen  = false

local waveUnits = {}        -- [unitID] = owning survival teamID
local idleUnits = {}        -- [unitID] = true, flushed by the reorder sweep

-- Engine bridge handed to the spawner (stubbed in smoke tests)
local env = {
	GetTeamList          = Spring.GetTeamList,
	GetTeamInfo          = Spring.GetTeamInfo,
	AreTeamsAllied       = Spring.AreTeamsAllied,
	GetTeamUnits         = Spring.GetTeamUnits,
	GetUnitDefID         = Spring.GetUnitDefID,
	GetUnitPosition      = Spring.GetUnitPosition,
	GetTeamStartPosition = Spring.GetTeamStartPosition,
	GetGroundHeight      = Spring.GetGroundHeight,
	CreateUnit           = Spring.CreateUnit,
	GiveOrderToUnit      = Spring.GiveOrderToUnit,
	mapSizeX             = Game.mapSizeX,
	mapSizeZ             = Game.mapSizeZ,
	CMD_FIGHT            = CMD.FIGHT,
	gaiaID               = gaiaID,
	random               = math.random,
}

-- Bridge for beacon placement (closures filled in Initialize once beaconDefID
-- is known)
local beaconEnv = {
	random   = math.random,
	mapSizeX = Game.mapSizeX,
	mapSizeZ = Game.mapSizeZ,
}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function MaxUnlockedTier(elapsedFrames)
	local minutes = elapsedFrames / (30 * 60)
	local best = 1
	for tier, unlockMin in pairs(TIER_UNLOCK_MINUTES) do
		if minutes >= unlockMin and tier > best and pools.byTier[tier] then
			best = tier
		end
	end
	return best
end

-- The placement phase confirms a spot for AI teams; read it back, falling back
-- to the engine start position if placement was skipped on this map. Only used
-- until the master beacon registers (beacons own spawn geometry after that).
local function ResolveSpawnPoint(teamID)
	local spotIdx = (spGetTeamRulesParam(teamID, "confirmedSpot"))
	if spotIdx and spotIdx >= 1 then
		local sx = (spGetGameRulesParam("spot_" .. spotIdx .. "_x"))
		local sz = (spGetGameRulesParam("spot_" .. spotIdx .. "_z"))
		if sx and sz then return sx, sz end
	end
	local x, _, z = spGetTeamStartPosition(teamID)
	if x and x > 0 then return x, z end
	return env.mapSizeX / 2, env.mapSizeZ / 2   -- last resort: map centre
end

local function TeamIsDead(teamID)
	return select(3, spGetTeamInfo(teamID, false)) and true or false
end

local function TotalLiveBeacons()
	local n = 0
	for teamID in pairs(survivalTeams) do
		n = n + Beacons.Count(teamID)
	end
	return n
end

--------------------------------------------------------------------------------
-- Wave execution
--------------------------------------------------------------------------------

local function SpawnWaveForTeam(teamID, state, frame)
	if state.defeated or TeamIsDead(teamID) then return end

	if not state.spawnX then
		state.spawnX, state.spawnZ = ResolveSpawnPoint(teamID)
	end

	local clockFrames  = frame - (state.clockStartFrame or frame)
	local maxTier      = MaxUnlockedTier(clockFrames)
	local beaconCount  = Beacons.Count(teamID)
	local beaconBonus  = 1 + BEACON_BUDGET_BONUS * math.max(0, beaconCount - 1)
	local budget       = Composer.Budget(waveNumber, BASE_BUDGET, LINEAR_GROWTH,
	                                     COMPOUND_GROWTH, state.diff.budgetMult * beaconBonus)

	local list, spent = Composer.Compose(pools, budget, maxTier, MAX_WAVE_UNITS, math.random)
	if #list == 0 then return end

	local tx, tz = Spawner.SelectTarget(env, teamID, isBuildingByDef)
	state.targetX, state.targetZ = tx, tz

	-- Split across live beacons (forward beacons carry most of the wave);
	-- pre-beacon fallback spawns everything at the start spot.
	local groups
	if beaconCount > 0 then
		groups = Beacons.SplitWave(teamID, list, tx, tz, math.random)
	else
		groups = { { x = state.spawnX, z = state.spawnZ, list = list } }
	end

	local createdTotal = 0
	for g = 1, #groups do
		local created = Spawner.SpawnWave(env, teamID, groups[g].x, groups[g].z,
		                                  groups[g].list, tx, tz)
		for i = 1, #created do
			waveUnits[created[i]] = teamID
		end
		createdTotal = createdTotal + #created
	end

	spEcho(string.format(
		"[Survival] Wave %d team %d: %d units, %d/%d metal, tier<=%d, %d beacon(s)",
		waveNumber, teamID, createdTotal, spent, budget, maxTier, beaconCount))
end

local function CreepBeacon(teamID, state)
	if state.defeated or Beacons.Count(teamID) == 0 then return end

	local cx, cz = Beacons.PickCreepSpot(beaconEnv, teamID, state.targetX, state.targetZ,
	                                     BEACON_CREEP_MIN_DIST, BEACON_CREEP_MAX_DIST)
	if not cx then
		spEcho("[Survival] Team " .. teamID .. ": no valid creep spot this cycle")
		return
	end

	-- Same grid snap the validator used, so CreateUnit tests the identical cell
	cx = 16 * math.floor((cx + 8) / 16)
	cz = 16 * math.floor((cz + 8) / 16)

	local y   = spGetGroundHeight(cx, cz)
	local uid = spCreateUnit(BEACON_UNIT, cx, y, cz, 0, teamID)
	if uid then
		spEcho(string.format("[Survival] Team %d beacon creep -> (%.0f, %.0f)", teamID, cx, cz))
	else
		-- Validator passed but the engine refused: usually a unitdef instance
		-- cap (maxThisUnit / unitRestricted) or a unit-limit hit -- loud so it
		-- can never fail silently again.
		spEcho(string.format(
			"[Survival] Team %d: CreateUnit('%s') FAILED at (%.0f, %.0f) despite valid spot"
			.. " -- check the beacon unitdef for maxThisUnit / unitRestricted",
			teamID, BEACON_UNIT, cx, cz))
	end
end

local function RunWave(frame)
	waveNumber = waveNumber + 1
	for teamID, state in pairs(survivalTeams) do
		SpawnWaveForTeam(teamID, state, frame)
	end

	-- Territory creep after every Nth wave
	if waveNumber % BEACON_EVERY_N_WAVES == 0 then
		for teamID, state in pairs(survivalTeams) do
			CreepBeacon(teamID, state)
		end
	end

	nextWaveFrame = frame + WAVE_INTERVAL_SEC * 30

	spSetGameRulesParam("survival_waveNumber",    waveNumber)
	spSetGameRulesParam("survival_nextWaveFrame", nextWaveFrame)
end

-- Idle stragglers get re-marched at their team's current target (or a fresh
-- one if the old target area has been wiped).
local function FlushIdleUnits()
	local byTeam = {}
	for unitID, teamID in pairs(idleUnits) do
		if waveUnits[unitID] then
			local list = byTeam[teamID]
			if not list then list = {} ; byTeam[teamID] = list end
			list[#list + 1] = unitID
		end
	end
	idleUnits = {}

	for teamID, list in pairs(byTeam) do
		local state = survivalTeams[teamID]
		if state then
			local tx, tz = Spawner.SelectTarget(env, teamID, isBuildingByDef)
			if tx then
				state.targetX, state.targetZ = tx, tz
				Spawner.OrderToTarget(env, list, tx, tz)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function gadget:Initialize()
	-- Which teams picked us in the lobby? (GetTeamLuaAI returns "" — not nil —
	-- for non-Lua-AI teams, so test the string, don't test for nil.)
	for _, teamID in ipairs(spGetTeamList()) do
		if teamID ~= gaiaID then
			local luaAI = spGetTeamLuaAI(teamID)
			if luaAI and luaAI ~= "" and DIFFICULTIES[luaAI] then
				survivalTeams[teamID] = { diff = DIFFICULTIES[luaAI] }
				anySurvival = true
				spEcho("[Survival] Team " .. teamID .. " is " .. luaAI)
			end
		end
	end

	if not anySurvival then
		return   -- dormant this game
	end

	pools = Pools.Build(UnitDefs, UnitDefNames)
	Pools.Describe(pools, spEcho)

	-- Building lookup for target weighting
	for udid = 1, #UnitDefs do
		local ud = UnitDefs[udid]
		if ud and ((ud.speed or 0) == 0 or not ud.canMove) then
			isBuildingByDef[udid] = true
		end
	end

	local beaconDef = UnitDefNames[BEACON_UNIT]
	if beaconDef then
		beaconDefID = beaconDef.id
	else
		spEcho("[Survival] WARNING: unitdef '" .. BEACON_UNIT
			.. "' not found — running without beacons (fixed spawn point)")
	end

	-- Beacon placement validators.
	-- Coordinates are snapped to the 16-elmo build grid before testing so the
	-- 10x10 footprint is evaluated exactly where CreateUnit would place it.
	-- TestBuildOrder: 0 = forbidden, 1 = blocked by a removable unit/feature,
	-- 2 = fully open. Only 2 is accepted -- a large footprint near battle
	-- debris frequently scores 1 and then fails CreateUnit anyway.
	beaconEnv.CanPlace = function(x, z)
		if not beaconDefID then return true end
		x = 16 * math.floor((x + 8) / 16)
		z = 16 * math.floor((z + 8) / 16)
		local y = spGetGroundHeight(x, z)
		if y < 0 then
			if SURVIVAL_DEBUG then
				spEcho(string.format("[Survival] creep reject (%.0f, %.0f): underwater (y=%.1f)", x, z, y))
			end
			return false
		end
		local test = spTestBuildOrder(beaconDefID, x, y, z, 0)
		if test ~= 2 then
			if SURVIVAL_DEBUG then
				spEcho(string.format("[Survival] creep reject (%.0f, %.0f): TestBuildOrder=%d", x, z, test))
			end
			return false
		end
		return true
	end
	beaconEnv.EnemyNear = function(teamID, x, z, radius)
		local units = spGetUnitsInCylinder(x, z, radius)
		for i = 1, #units do
			local t = spGetUnitTeam(units[i])
			if t and t ~= teamID and t ~= gaiaID and not spAreTeamsAllied(teamID, t) then
				if SURVIVAL_DEBUG then
					spEcho(string.format("[Survival] creep reject (%.0f, %.0f): enemy within %d", x, z, radius))
				end
				return true
			end
		end
		return false
	end

	-- Mid-game luarules reload: re-register beacons that already exist.
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		local udid = Spring.GetUnitDefID(unitID)
		if udid == beaconDefID then
			local t = spGetUnitTeam(unitID)
			if t and survivalTeams[t] then
				local x, _, z = spGetUnitPosition(unitID)
				Beacons.Register(t, unitID, x, z)
			end
		end
	end

	spSetGameRulesParam("survival_active", 1)
	spSetGameRulesParam("survival_beacons", TotalLiveBeacons())

	GG.Survival = {
		IsSurvivalTeam = function(teamID) return survivalTeams[teamID] ~= nil end,
		GetWaveNumber  = function() return waveNumber end,
		GetBeaconCount = function(teamID) return Beacons.Count(teamID) end,
	}
end

function gadget:GameFrame(frame)
	if not anySurvival or gameOverSeen then return end
	if frame % CHECK_PERIOD_FRAMES ~= 0 then return end

	-- Polling IsGameOver is more reliable than the GameOver callin here
	if spIsGameOver() then
		gameOverSeen = true
		return
	end

	-- Start the wave clock only after the pre-game (faction + placement) flow
	-- has finished and start units exist.
	if not clockStarted then
		local phase = (spGetGameRulesParam("phase"))
		if phase == nil or phase == "done" then
			clockStarted  = true
			nextWaveFrame = frame + GRACE_SECONDS * 30
			for _, state in pairs(survivalTeams) do
				state.clockStartFrame = frame
			end
			spSetGameRulesParam("survival_waveNumber",    0)
			spSetGameRulesParam("survival_nextWaveFrame", nextWaveFrame)
			spEcho("[Survival] Clock started; first wave at frame " .. nextWaveFrame)
		end
		return
	end

	if frame >= nextWaveFrame then
		RunWave(frame)
	end

	if frame % REORDER_PERIOD_FRAMES == 0 and next(idleUnits) then
		FlushIdleUnits()
	end
end

--------------------------------------------------------------------------------
-- Unit bookkeeping
--------------------------------------------------------------------------------

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	if unitDefID == beaconDefID and survivalTeams[unitTeam] then
		local x, _, z = spGetUnitPosition(unitID)
		Beacons.Register(unitTeam, unitID, x, z)
		spSetGameRulesParam("survival_beacons", TotalLiveBeacons())
	end
end

function gadget:UnitIdle(unitID, unitDefID, unitTeam)
	if waveUnits[unitID] then
		idleUnits[unitID] = true
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam,
                              attackerID, attackerDefID, attackerTeamID)
	waveUnits[unitID] = nil
	idleUnits[unitID] = nil

	-- Beacon down: bounty, retaliation wave, defeat check
	if unitDefID == beaconDefID and Beacons.Remove(unitID) then
		spSetGameRulesParam("survival_beacons", TotalLiveBeacons())

		if attackerTeamID and attackerTeamID ~= unitTeam and attackerTeamID ~= gaiaID
			and GG.Research then
			GG.Research.Add(attackerTeamID, BEACON_RP_REWARD, "beacon")
		end

		if clockStarted and not gameOverSeen then
			local retal = spGetGameFrame() + RETALIATION_DELAY_SEC * 30
			if retal < nextWaveFrame then
				nextWaveFrame = retal
				spSetGameRulesParam("survival_nextWaveFrame", nextWaveFrame)
				spEcho("[Survival] Beacon destroyed — retaliation wave incoming")
			end
		end

		if Beacons.Count(unitTeam) == 0 then
			local state = survivalTeams[unitTeam]
			if state then
				state.defeated = true
				spEcho("[Survival] Team " .. unitTeam .. " has no beacons left")
			end
		end
	end
end

-- If a wave unit is somehow captured, stop steering it.
function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if waveUnits[unitID] and not survivalTeams[newTeam] then
		waveUnits[unitID] = nil
		idleUnits[unitID] = nil
	end
end
