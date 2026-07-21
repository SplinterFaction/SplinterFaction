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
		layer   = -5,    -- forge damage amp (UnitPreDamaged) must run BEFORE
		                 -- the Protoss shields gadget at layer 0
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

--------------------------------------------------------------------------------
-- Difficulty presets: each one genuinely bends the game, not just the budget.
--   budget   -> multiplier on every wave's metal budget
--   linear   -> multiplier on the linear growth term (early-game ramp)
--   compound -> additive delta to the compound term (late-game explosion)
--   interval -> multiplier on the wave interval (pressure cadence)
-- Presets scale ON TOP of the granular modoptions below, so lobby tweaks and
-- preset choice compose instead of fighting.
--------------------------------------------------------------------------------

local PRESETS = {
	easy       = { label = "Easy",       budget = 0.5, linear = 0.6, compound = -0.02, interval = 1.25 },
	normal     = { label = "Normal",     budget = 1.0, linear = 1.0, compound =  0.00, interval = 1.00 },
	hard       = { label = "Hard",       budget = 2.0, linear = 1.2, compound =  0.02, interval = 0.90 },
	impossibru = { label = "Impossibru", budget = 3.0, linear = 1.5, compound =  0.04, interval = 0.75 },
}

local modOptions = Spring.GetModOptions()

local presetKey = modOptions.survivalaidifficulty or "normal"
local preset    = PRESETS[presetKey]
if not preset then
	Spring.Echo("[Survival AI] Unrecognised difficulty '" .. tostring(presetKey) .. "'; using Normal")
	preset = PRESETS.normal
end

local DIFFICULTIES = {
	["SurvivalAI"] = { budgetMult = preset.budget },
}

--------------------------------------------------------------------------------
-- Granular tuning via modoptions (section: survivalaioptions). Every knob
-- falls back to the tuned default when the option is absent or malformed, so
-- the gadget runs identically on lobbies that don't set them.
--------------------------------------------------------------------------------

local function NumOpt(key, default)
	local v = tonumber(modOptions[key])
	if v == nil then return default end
	return v
end

local GRACE_SECONDS     = NumOpt("survivalai_graceperiod",    180)
local WAVE_INTERVAL_SEC = NumOpt("survivalai_waveinterval",    60)
local BASE_BUDGET       = NumOpt("survivalai_basebudget",     400)
local LINEAR_GROWTH     = NumOpt("survivalai_lineargrowth",   0.30)
local COMPOUND_GROWTH   = NumOpt("survivalai_compoundgrowth", 1.06)
local MAX_WAVE_UNITS    = NumOpt("survivalai_maxwaveunits",    40)
local FACTION_PURE_CHANCE = NumOpt("survivalai_factionpure",  0.25)

-- Apply the preset's shaping on top of the granular values
LINEAR_GROWTH     = LINEAR_GROWTH * preset.linear
COMPOUND_GROWTH   = math.max(1.0, COMPOUND_GROWTH + preset.compound)
WAVE_INTERVAL_SEC = math.max(15, WAVE_INTERVAL_SEC * preset.interval)

Spring.Echo(string.format(
	"[Survival AI] Difficulty %s: budget x%.2f, linear growth %.2f, compound %.2f, wave interval %.0fs",
	preset.label, preset.budget, LINEAR_GROWTH, COMPOUND_GROWTH, WAVE_INTERVAL_SEC))

-- Drop waves (gunship-carried assaults)
local DROP_LOAD_TIMEOUT_SEC = 25   -- give up loading after this; leftovers walk
local DROP_STANDOFF         = 350  -- unload this many elmos short of the target
local DROP_RADIUS           = 256  -- area-unload radius at the drop point

-- Minutes (on the wave clock) at which each tech tier joins the pools
local TIER_UNLOCK_MINUTES = {
	[1] = 0,
	[2] = NumOpt("survivalai_t2minutes", 10),
	[3] = NumOpt("survivalai_t3minutes", 20),
}

-- Beacons
local BEACON_UNIT           = "beacon"
local BEACON_EVERY_N_WAVES  = math.max(1, math.floor(NumOpt("survivalai_beaconwaves", 3)))
local BEACON_BUDGET_BONUS   = NumOpt("survivalai_beaconbonus",       0.15)
local BEACON_RP_REWARD      = NumOpt("survivalai_beaconrp",           250)
local RETALIATION_DELAY_SEC = NumOpt("survivalai_retaliationdelay",     5)
local BEACON_CREEP_MIN_DIST = NumOpt("survivalai_creepmin",           900)
local BEACON_CREEP_MAX_DIST = NumOpt("survivalai_creepmax",          3000)
local SURVIVAL_DEBUG        = true   -- echo per-attempt creep placement rejections

-- Beacon specialization: creep beacons roll a kind; the master is standard.
local SPECIAL_CHANCE       = NumOpt("survivalai_specialchance", 0.6)
local SPECIAL_KINDS        = { "shield", "jammer", "accelerator", "forge" }
local BEACON_SHIELD_MAX    = 300    -- shield-beacon overshield on spawned waves
local BEACON_SHIELD_REGEN  = 10
local BEACON_SHIELD_DELAY  = 8      -- seconds
local JAMMER_CLOAK_LEVEL   = 2      -- Spring.SetUnitCloak scriptCloak level (verify in game)
local ACCEL_SECONDS        = 8      -- interval shaved per live accelerator beacon
local MIN_WAVE_INTERVAL    = 20     -- floor, whatever accelerators/rage do
local FORGE_HP_MULT        = 1.4
local FORGE_DMG_MULT       = 1.5
local FORGE_RULES_PARAM    = "survival_forge"

-- Network aging: beacons dig in after this long alive (0 disables)
local AGE_MINUTES      = NumOpt("survivalai_agingminutes", 4)
local GARRISON_COUNT   = 3
local GARRISON_RADIUS  = 190
local GARRISON_T1      = { "fedmenlo", "fedstinger", "lozjericho", "lozrazor" }
local GARRISON_T2      = { "fedimmolator", "fedjavelin", "lozinferno", "lozrattlesnake" }

-- Last-beacon rage
local RAGE_BUDGET_MULT   = 1.5
local RAGE_INTERVAL_MULT = 0.5
local RAGE_SHIELD_MAX    = 2000
local RAGE_SHIELD_REGEN  = 40
local RAGE_SHIELD_DELAY  = 10

-- Surge waves: every Nth wave doubles the budget with a dramatic archetype
local SURGE_EVERY       = math.floor(NumOpt("survivalai_surgewaves", 10))
local SURGE_BUDGET_MULT = 2.0
local SURGE_ARCHETYPES  = { "siege", "air", "drop" }

local KIND_TIPS = {
	standard    = "Spawn Beacon",
	shield      = "Shield Beacon - waves from this beacon are overshielded",
	jammer      = "Jammer Beacon - waves from this beacon spawn cloaked",
	accelerator = "Accelerator Beacon - waves arrive faster while this stands",
	forge       = "Forge Beacon - waves from this beacon hit harder and endure more",
}

-- Sanity: a crossed leash (min > max) collapses to a fixed-distance ring
if BEACON_CREEP_MIN_DIST > BEACON_CREEP_MAX_DIST then
	Spring.Echo("[Survival AI] creepmin > creepmax; swapping")
	BEACON_CREEP_MIN_DIST, BEACON_CREEP_MAX_DIST =
		BEACON_CREEP_MAX_DIST, BEACON_CREEP_MIN_DIST
end

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
local spSetUnitCloak         = Spring.SetUnitCloak
local spGetUnitHealth        = Spring.GetUnitHealth
local spSetUnitHealth        = Spring.SetUnitHealth
local spSetUnitMaxHealth     = Spring.SetUnitMaxHealth
local spSetUnitRulesParam    = Spring.SetUnitRulesParam
local spGetUnitRulesParam    = Spring.GetUnitRulesParam
local spSetUnitTooltip       = Spring.SetUnitTooltip

local INLOS = { inlos = true }

local gaiaID = spGetGaiaTeamID()

local survivalTeams = {}    -- [teamID] = { diff, spawnX, spawnZ, targetX, targetZ,
                            --              clockStartFrame, defeated }
local anySurvival   = false

local pools           = nil
local isBuildingByDef = {}  -- [unitDefID] = true (for target weighting)
local beaconDefID     = nil

local clockStarted    = false -- wave clock starts once the pre-game phase is done
local clockStartFrame = nil
local nextWaveFrame   = nil
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
	CMD_MOVE             = CMD.MOVE,
	CMD_LOAD             = CMD.LOAD_UNITS,
	CMD_UNLOAD           = CMD.UNLOAD_UNITS,
	OPT_SHIFT            = CMD.OPT_SHIFT,
	gaiaID               = gaiaID,
	random               = math.random,
}

-- Live drop-wave groups (loading phase only; dispatched groups dissolve into
-- dropPending, which maps still-embarked riders to their disembark target)
local dropGroups  = {}   -- array of { teamID, carriers, passengers, byCarrier,
                         --            tx, tz, dropX, dropZ, deadline }
local dropPending = {}   -- [unitID] = { tx =, tz = }  (skip idle sweep, order on unload)

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

--------------------------------------------------------------------------------
-- Beacon specialization
--------------------------------------------------------------------------------

-- Set just before CreateUnit'ing a creep beacon; consumed by UnitCreated
-- (which fires synchronously inside the CreateUnit call). The master beacon
-- arrives from game_spawn with this unset and defaults to standard.
local pendingBeaconKind = nil

local function RollBeaconKind()
	if math.random() < SPECIAL_CHANCE then
		return SPECIAL_KINDS[math.random(1, #SPECIAL_KINDS)]
	end
	return "standard"
end

-- Apply a source beacon's effect to freshly spawned wave units.
local function ApplyBeaconEffect(kind, unitIDs)
	if not kind or kind == "standard" or #unitIDs == 0 then return end

	if kind == "shield" then
		local Shields = GG.PersonalShields
		if Shields and Shields.Grant then
			for i = 1, #unitIDs do
				Shields.Grant(unitIDs[i], BEACON_SHIELD_MAX,
				              BEACON_SHIELD_REGEN, BEACON_SHIELD_DELAY)
			end
		end
	elseif kind == "jammer" then
		for i = 1, #unitIDs do
			spSetUnitCloak(unitIDs[i], JAMMER_CLOAK_LEVEL)
		end
	elseif kind == "forge" then
		for i = 1, #unitIDs do
			local uid = unitIDs[i]
			local hp, maxHp = spGetUnitHealth(uid)
			if hp and maxHp then
				spSetUnitMaxHealth(uid, maxHp * FORGE_HP_MULT)
				spSetUnitHealth(uid, hp * FORGE_HP_MULT)
			end
			spSetUnitRulesParam(uid, FORGE_RULES_PARAM, FORGE_DMG_MULT, INLOS)
		end
	end
	-- accelerator: no per-unit effect; it bends the wave clock in RunWave
end

local function SpawnWaveForTeam(teamID, state, frame, arch, faction, maxTier, surge)
	if state.defeated or TeamIsDead(teamID) then return end

	if not state.spawnX then
		state.spawnX, state.spawnZ = ResolveSpawnPoint(teamID)
	end

	local beaconCount  = Beacons.Count(teamID)
	local beaconBonus  = 1 + BEACON_BUDGET_BONUS * math.max(0, beaconCount - 1)
	local mult         = state.diff.budgetMult * beaconBonus
	if state.rage then mult = mult * RAGE_BUDGET_MULT end
	if surge then mult = mult * SURGE_BUDGET_MULT end
	local budget       = Composer.Budget(waveNumber, BASE_BUDGET, LINEAR_GROWTH,
	                                     COMPOUND_GROWTH, mult)

	local tx, tz = Spawner.SelectTarget(env, teamID, isBuildingByDef)
	state.targetX, state.targetZ = tx, tz

	----------------------------------------------------------------------------
	-- Drop archetype: gunships load the ground contingent and haul it to the
	-- target; the loading/dispatch state machine lives in GameFrame.
	----------------------------------------------------------------------------
	if arch.drop and tx then
		local drop = Composer.ComposeDrop(pools, budget, {
			maxTier = maxTier, maxUnits = MAX_WAVE_UNITS,
			weights = arch.weights, faction = faction, random = math.random,
		})
		if #drop.plan > 0 then
			-- Beacon closest to the target stages the drop (its kind applies)
			local sx, sz, stageKind = state.spawnX, state.spawnZ, nil
			local groups = Beacons.SplitWave(teamID, { true }, tx, tz, math.random)
			if groups[1] then
				sx, sz, stageKind = groups[1].x, groups[1].z, groups[1].kind
			end

			local g = Spawner.SpawnDropWave(env, teamID, sx, sz, drop, tx, tz)
			local touched = {}
			for _, cid in ipairs(g.carriers) do
				waveUnits[cid] = teamID ; touched[#touched + 1] = cid
			end
			for _, wid in ipairs(g.walkers)  do
				waveUnits[wid] = teamID ; touched[#touched + 1] = wid
			end

			-- Drop point: standoff short of the target, back along the approach
			local dx, dz = tx - sx, tz - sz
			local len    = math.sqrt(dx * dx + dz * dz)
			local dropX, dropZ = tx, tz
			if len > DROP_STANDOFF then
				dropX = tx - dx / len * DROP_STANDOFF
				dropZ = tz - dz / len * DROP_STANDOFF
			end

			local nPassengers = 0
			for pid in pairs(g.passengers) do
				waveUnits[pid]   = teamID
				dropPending[pid] = { tx = tx, tz = tz }
				touched[#touched + 1] = pid
				nPassengers = nPassengers + 1
			end
			ApplyBeaconEffect(stageKind, touched)
			dropGroups[#dropGroups + 1] = {
				teamID = teamID, carriers = g.carriers, passengers = g.passengers,
				byCarrier = g.byCarrier, tx = tx, tz = tz,
				dropX = dropX, dropZ = dropZ,
				deadline = frame + DROP_LOAD_TIMEOUT_SEC * 30,
			}
			spEcho(string.format(
				"[Survival] Wave %d team %d [drop%s]: %d riders / %d carriers / %d walkers, budget %d",
				waveNumber, teamID, faction and (" / " .. faction) or "",
				nPassengers, #g.carriers, #g.walkers, budget))
			return
		end
		-- No carriers could be bought: fall through and send it as ground
	end

	-- Normal (non-drop) wave: compose and split across live beacons (forward
	-- beacons carry most of the wave); pre-beacon fallback spawns everything
	-- at the start spot.
	local list, spent = Composer.Compose(pools, budget, {
		maxTier  = maxTier,
		maxUnits = MAX_WAVE_UNITS,
		weights  = arch.weights,
		faction  = faction,
		random   = math.random,
	})
	if #list == 0 then return end

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
		ApplyBeaconEffect(groups[g].kind, created)
		createdTotal = createdTotal + #created
	end

	spEcho(string.format(
		"[Survival] Wave %d team %d [%s%s%s]: %d units, %d/%d metal, tier<=%d, %d beacon(s)",
		waveNumber, teamID, arch.name, surge and " SURGE" or "",
		faction and (" / " .. faction) or "",
		createdTotal, spent, budget, maxTier, beaconCount))
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

	local y = spGetGroundHeight(cx, cz)
	pendingBeaconKind = RollBeaconKind()
	local uid = spCreateUnit(BEACON_UNIT, cx, y, cz, 0, teamID)
	local kind = pendingBeaconKind
	pendingBeaconKind = nil
	if uid then
		spEcho(string.format("[Survival] Team %d beacon creep [%s] -> (%.0f, %.0f)",
			teamID, kind or "standard", cx, cz))
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

	local maxTier = MaxUnlockedTier(frame - (clockStartFrame or frame))
	local isSurge = SURGE_EVERY > 0 and (waveNumber % SURGE_EVERY == 0)

	-- Surge waves force a dramatic archetype (viability-filtered)
	local arch = nil
	if isSurge then
		local cands = {}
		for _, name in ipairs(SURGE_ARCHETYPES) do
			local a = Composer.ByName[name]
			if a and Composer.IsViable(pools, a, maxTier) then
				cands[#cands + 1] = a
			end
		end
		if #cands > 0 then arch = cands[math.random(1, #cands)] end
	end
	arch = arch or Composer.PickArchetype(pools, waveNumber, maxTier, math.random)

	local faction = nil
	if #pools.factions > 0 and math.random() < FACTION_PURE_CHANCE then
		faction = pools.factions[math.random(1, #pools.factions)]
	end

	for teamID, state in pairs(survivalTeams) do
		SpawnWaveForTeam(teamID, state, frame, arch, faction, maxTier, isSurge)
	end

	-- Territory creep after every Nth wave; raging teams make their last stand
	-- instead of expanding
	if waveNumber % BEACON_EVERY_N_WAVES == 0 then
		for teamID, state in pairs(survivalTeams) do
			if not state.rage then
				CreepBeacon(teamID, state)
			end
		end
	end

	-- Wave cadence: accelerator beacons shave seconds, rage halves the rest.
	-- The clock is shared, so with multiple survival teams the fastest wins.
	local accels, anyRage = 0, false
	for teamID, state in pairs(survivalTeams) do
		if not state.defeated then
			accels = accels + Beacons.CountKind(teamID, "accelerator")
			if state.rage then anyRage = true end
		end
	end
	local interval = math.max(MIN_WAVE_INTERVAL, WAVE_INTERVAL_SEC - ACCEL_SECONDS * accels)
	if anyRage then
		interval = math.max(MIN_WAVE_INTERVAL, interval * RAGE_INTERVAL_MULT)
	end
	nextWaveFrame = frame + math.floor(interval * 30)

	-- Telegraph, including a full-interval surge warning
	local nextIsSurge = SURGE_EVERY > 0 and ((waveNumber + 1) % SURGE_EVERY == 0)
	spSetGameRulesParam("survival_waveNumber",    waveNumber)
	spSetGameRulesParam("survival_waveType",      arch.name)
	spSetGameRulesParam("survival_nextWaveFrame", nextWaveFrame)
	spSetGameRulesParam("survival_nextWaveSurge", nextIsSurge and 1 or 0)
	if nextIsSurge then
		spEcho("[Survival] SURGE WAVE INCOMING -- brace for wave " .. (waveNumber + 1))
	end
end

-- Idle stragglers get re-marched at their team's current target (or a fresh
-- one if the old target area has been wiped).
local function FlushIdleUnits()
	local byTeam = {}
	for unitID, teamID in pairs(idleUnits) do
		-- Riders waiting for (or inside) a carrier are not stragglers
		if waveUnits[unitID] and not dropPending[unitID] then
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
-- Network aging: beacons that survive long enough dig in, spawning a small
-- garrison of defense structures around themselves. Garrison turrets are not
-- wave units: they hold ground, and persist as ruins after their beacon dies.
--------------------------------------------------------------------------------

local GARRISON_LISTS = { GARRISON_T1, GARRISON_T2 }   -- validated in Initialize

local function DigIn(teamID, bx, bz, maxTier)
	local list = (maxTier >= 2) and GARRISON_T2 or GARRISON_T1
	if #list == 0 then return 0 end
	local placed = 0
	for i = 1, GARRISON_COUNT do
		local name = list[math.random(1, #list)]
		for attempt = 1, 5 do
			local ang = math.random() * 2 * math.pi
			local r   = GARRISON_RADIUS + (attempt - 1) * 45
			local x   = math.max(48, math.min(env.mapSizeX - 48, bx + math.cos(ang) * r))
			local z   = math.max(48, math.min(env.mapSizeZ - 48, bz + math.sin(ang) * r))
			local uid = spCreateUnit(name, x, spGetGroundHeight(x, z), z, 0, teamID)
			if uid then placed = placed + 1 break end
		end
	end
	return placed
end

local function AgeBeacons(frame)
	if AGE_MINUTES <= 0 then return end
	local ageFrames = AGE_MINUTES * 60 * 30
	local maxTier   = MaxUnlockedTier(frame - (clockStartFrame or frame))
	for teamID, state in pairs(survivalTeams) do
		if not state.defeated then
			local due = Beacons.DueForAging(teamID, frame, ageFrames)
			for i = 1, #due do
				Beacons.MarkDug(due[i].unitID)
				local placed = DigIn(teamID, due[i].x, due[i].z, maxTier)
				spEcho(string.format(
					"[Survival] Team %d beacon at (%.0f, %.0f) dug in: %d garrison turret(s)",
					teamID, due[i].x, due[i].z, placed))
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Drop wave state machine. A group waits in loading until every surviving
-- rider is aboard (or the deadline hits), then dispatches: each carrier gets
-- move -> area-unload -> fight queued, riders left on the ground walk, and
-- embarked riders keep their dropPending entry so UnitUnloaded can order them
-- the moment they hit dirt.
--------------------------------------------------------------------------------

local spGetUnitTransporter = Spring.GetUnitTransporter
local spValidUnitID        = Spring.ValidUnitID
local spGiveOrderToUnit    = Spring.GiveOrderToUnit

local function DispatchDropGroup(g)
	local dy = spGetGroundHeight(g.dropX, g.dropZ)
	local ty = spGetGroundHeight(g.tx, g.tz)

	for _, cid in ipairs(g.carriers) do
		if spValidUnitID(cid) then
			spGiveOrderToUnit(cid, CMD.MOVE, { g.dropX, dy, g.dropZ }, 0)
			spGiveOrderToUnit(cid, CMD.UNLOAD_UNITS,
				{ g.dropX, dy, g.dropZ, DROP_RADIUS }, CMD.OPT_SHIFT)
			spGiveOrderToUnit(cid, CMD.FIGHT, { g.tx, ty, g.tz }, CMD.OPT_SHIFT)
		end
	end

	-- Riders still on the ground at dispatch walk instead
	local walkers = {}
	for pid in pairs(g.passengers) do
		if spValidUnitID(pid) and not spGetUnitTransporter(pid) then
			walkers[#walkers + 1] = pid
			dropPending[pid] = nil
		end
	end
	if #walkers > 0 then
		Spawner.OrderToTarget(env, walkers, g.tx, g.tz)
	end
end

local function TickDropGroups(frame)
	for i = #dropGroups, 1, -1 do
		local g = dropGroups[i]
		local ready = true
		if frame < g.deadline then
			for pid in pairs(g.passengers) do
				if spValidUnitID(pid) and not spGetUnitTransporter(pid) then
					ready = false
					break
				end
			end
		end
		if ready then
			DispatchDropGroup(g)
			table.remove(dropGroups, i)
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
	-- TestBuildOrder: 0 = forbidden terrain (slope/water/metal restrictions),
	-- 1 = blocked by a removable unit/feature, 2 = fully open. CreateUnit is
	-- not a build order and ignores removable blockers entirely, so only 0
	-- rejects -- requiring 2 on a map littered with metal spots, decorative
	-- features and milling wave units starves placement for no gain.
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
		if test < 1 then
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

	-- Validate garrison turret defs; drop unknowns loudly
	for _, list in ipairs(GARRISON_LISTS) do
		for i = #list, 1, -1 do
			if not UnitDefNames[list[i]] then
				spEcho("[Survival] WARNING: garrison turret '" .. list[i]
					.. "' not found; removed from rotation")
				table.remove(list, i)
			end
		end
	end

	spSetGameRulesParam("survival_active", 1)
	spSetGameRulesParam("survival_beacons", TotalLiveBeacons())
	spSetGameRulesParam("survival_rage", 0)

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
			clockStarted    = true
			clockStartFrame = frame
			nextWaveFrame   = frame + GRACE_SECONDS * 30
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

	if #dropGroups > 0 then
		TickDropGroups(frame)
	end

	if frame % REORDER_PERIOD_FRAMES == 0 then
		AgeBeacons(frame)
		if next(idleUnits) then
			FlushIdleUnits()
		end
	end
end

function gadget:UnitUnloaded(unitID, unitDefID, unitTeam, transportID)
	local pending = dropPending[unitID]
	if pending then
		dropPending[unitID] = nil
		local ty = spGetGroundHeight(pending.tx, pending.tz)
		spGiveOrderToUnit(unitID, CMD.FIGHT, { pending.tx, ty, pending.tz }, 0)
	end
end

--------------------------------------------------------------------------------
-- Unit bookkeeping
--------------------------------------------------------------------------------

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	if unitDefID == beaconDefID and survivalTeams[unitTeam] then
		local x, _, z = spGetUnitPosition(unitID)
		local kind = pendingBeaconKind or "standard"
		Beacons.Register(unitTeam, unitID, x, z, kind, spGetGameFrame())
		spSetUnitRulesParam(unitID, "survival_beacon_kind", kind, INLOS)
		if spSetUnitTooltip and KIND_TIPS[kind] then
			spSetUnitTooltip(unitID, KIND_TIPS[kind])
		end
		local state = survivalTeams[unitTeam]
		if Beacons.Count(unitTeam) >= 2 then
			state.everHadTwo = true
		end
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
	waveUnits[unitID]   = nil
	idleUnits[unitID]   = nil
	dropPending[unitID] = nil

	-- Drop groups: forget dead riders (so all-loaded can complete) and dead
	-- carriers (their riders fall out of GetUnitTransporter and walk at dispatch)
	for i = 1, #dropGroups do
		local g = dropGroups[i]
		if g.passengers[unitID] then g.passengers[unitID] = nil end
		if g.byCarrier[unitID] then
			g.byCarrier[unitID] = nil
			for c = #g.carriers, 1, -1 do
				if g.carriers[c] == unitID then table.remove(g.carriers, c) end
			end
		end
	end

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

		local state     = survivalTeams[unitTeam]
		local remaining = Beacons.Count(unitTeam)
		if remaining == 0 then
			if state then
				state.defeated = true
				spEcho("[Survival] Team " .. unitTeam .. " has no beacons left")
			end
		elseif remaining == 1 and state and state.everHadTwo and not state.rage then
			-- LAST-BEACON RAGE: budget surges, waves accelerate, creep halts,
			-- and the survivor gets a heavy overshield. Ends only in death.
			state.rage = true
			local lastID = Beacons.GetLast(unitTeam)
			if lastID and GG.PersonalShields and GG.PersonalShields.Grant then
				GG.PersonalShields.Grant(lastID, RAGE_SHIELD_MAX,
				                         RAGE_SHIELD_REGEN, RAGE_SHIELD_DELAY)
			end
			spEcho("[Survival] Team " .. unitTeam
				.. " is down to its last beacon -- RAGE MODE ENGAGED")
		end

		-- survival_rage = number of currently raging, live teams
		local raging = 0
		for _, st in pairs(survivalTeams) do
			if st.rage and not st.defeated then raging = raging + 1 end
		end
		spSetGameRulesParam("survival_rage", raging)
	end
end

-- Forge-beacon spawns hit harder: amplify their outgoing damage before the
-- shields gadget (layer 0) absorbs it. Cheap guard first; the rules param is
-- only ever set on survival wave units.
function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer,
                               weaponDefID, projectileID, attackerID,
                               attackerDefID, attackerTeamID)
	if not anySurvival or not attackerID then
		return damage
	end
	local mult = spGetUnitRulesParam(attackerID, FORGE_RULES_PARAM)
	if mult then
		return damage * mult
	end
	return damage
end

-- If a wave unit is somehow captured, stop steering it.
function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if waveUnits[unitID] and not survivalTeams[newTeam] then
		waveUnits[unitID] = nil
		idleUnits[unitID] = nil
	end
end
