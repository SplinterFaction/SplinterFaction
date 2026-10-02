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
--           beacon in place of a commander, and this gadget seeds the rest of
--           the network around it (garrisoned from the start). Waves stage
--           from the beacons nearest their target. Killing a beacon awards RP,
--           draws a counterattack from its neighbors, and eases the pressure;
--           a network below full strength regrows one beacon at a time on a
--           countdown. Clearing every beacon eliminates the team = player
--           victory via the normal commander-elimination flow.
--
--           Pressure is a budget curve on the wave clock (an S-curve to a
--           plateau, see s_wavecomposer M.Budget) and it is field-aware: metal
--           already alive on the map counts against each new wave.
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
--   budget   -> multiplier on the whole budget curve (base and peak alike)
--   midShift -> minutes added to the ramp midpoint (negative = ramps sooner)
--   creep    -> multiplier on the late creep (0 = a true plateau)
--   interval -> multiplier on the wave interval (pressure cadence)
-- Presets scale ON TOP of the granular modoptions below, so lobby tweaks and
-- preset choice compose instead of fighting.
--
-- Design intent: on Normal the plateau is something a good player out-produces
-- and then pushes through to clear the network. Hard and Impossibru stack the
-- deck: higher plateau, earlier ramp, and a late creep that never lets up.
--------------------------------------------------------------------------------

local PRESETS = {
	easy       = { label = "Easy",       budget = 0.6, midShift =  3, creep =  0, interval = 1.25 },
	normal     = { label = "Normal",     budget = 1.0, midShift =  0, creep =  1, interval = 1.00 },
	hard       = { label = "Hard",       budget = 1.6, midShift = -1, creep =  4, interval = 0.90 },
	impossibru = { label = "Impossibru", budget = 2.5, midShift = -3, creep = 12, interval = 0.75 },
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
local MAX_WAVE_UNITS    = NumOpt("survivalai_maxwaveunits",    40)
local FACTION_PURE_CHANCE = NumOpt("survivalai_factionpure",  0.25)

WAVE_INTERVAL_SEC = math.max(15, WAVE_INTERVAL_SEC * preset.interval)

-- Budget curve (minutes are on the wave clock, the same clock as tier unlocks)
local BASE_BUDGET       = NumOpt("survivalai_basebudget",    1500)   -- first wave, full network
local PEAK_BUDGET       = NumOpt("survivalai_peakbudget",   10000)   -- the plateau
local RAMP_MID_MINUTES  = NumOpt("survivalai_rampminutes",     12)   -- halfway up the ramp
local LATE_CREEP        = NumOpt("survivalai_latecreep",      100)   -- metal per minute past the plateau
local RAMP_STEEPNESS    = 0.30   -- logistic steepness per minute
local PLATEAU_AFTER_MID = 12     -- minutes past the midpoint at which the creep starts

-- Field awareness: live wave metal may reach FIELD_CAP_MULT budgets; a wave
-- tops the field up to that, between MIN_WAVE_FRACTION and one full budget.
local FIELD_CAP_MULT    = math.max(1, NumOpt("survivalai_fieldcap", 2.0))
local MIN_WAVE_FRACTION = 0.25

local CURVE = {
	base  = BASE_BUDGET,
	peak  = math.max(BASE_BUDGET, PEAK_BUDGET),
	start = GRACE_SECONDS / 60,
	steep = RAMP_STEEPNESS,
	creep = LATE_CREEP * preset.creep,
}
CURVE.mid     = math.max(CURVE.start + 1, RAMP_MID_MINUTES + preset.midShift)
CURVE.plateau = CURVE.mid + PLATEAU_AFTER_MID

Spring.Echo(string.format(
	"[Survival AI] Difficulty %s: budget x%.2f, curve %d -> %d metal (mid %.0f min, creep %d/min after %.0f min), field cap x%.1f, wave interval %.0fs",
	preset.label, preset.budget, CURVE.base, CURVE.peak, CURVE.mid, CURVE.creep,
	CURVE.plateau, FIELD_CAP_MULT, WAVE_INTERVAL_SEC))

-- Drop waves (gunship-carried assaults)
local DROP_LOAD_TIMEOUT_SEC = 25   -- give up loading after this; leftovers walk
local DROP_STANDOFF         = 350  -- unload this many elmos short of the target
local DROP_RADIUS           = 256  -- area-unload radius at the drop point

-- Minutes (on the wave clock) at which each tech tier joins the pools
local TIER_UNLOCK_MINUTES = {
	[1] = 0,
	[2] = NumOpt("survivalai_t2minutes", 10),
	[3] = NumOpt("survivalai_t3minutes", 20),
	[4] = NumOpt("survivalai_t4minutes", 30),
}

-- The top tier is rationed: never more than one live unit per
-- LIMITED_PLAYERS_PER_UNIT opposing teams (rounded up), across all survival
-- teams and all waves.
local LIMITED_TIER             = 4
local LIMITED_PLAYERS_PER_UNIT = 2

-- Beacon network
local BEACON_UNIT           = "beacon"
local NETWORK_SIZE          = math.max(1, math.floor(NumOpt("survivalai_networksize", 8)))
local NETWORK_FLOOR         = 0.5    -- budget share left with one beacon standing
local RESPAWN_MINUTES       = NumOpt("survivalai_respawnminutes",      10)   -- 0 disables regrowth
local RESPAWN_RETRY_FRAMES  = 300    -- placement found no spot: try again this soon
local SEED_MIN_DIST         = 600    -- starting beacons: step from an existing beacon
local SEED_MAX_DIST         = 1400
local HOME_FRACTION         = 0.4    -- network stays within this share of the way to the nearest enemy start
local HOME_MIN_RADIUS       = 1500
local HOME_MAX_FRACTION     = 0.6    -- ...and the minimum never pushes it past this share
local BEACON_RP_REWARD      = NumOpt("survivalai_beaconrp",           250)
local RP_START_FRACTION     = 0.4    -- bounty at minute 0, ramping to full...
local RP_FULL_MINUTES       = 15     -- ...by this minute on the wave clock
local RETALIATION_DELAY_SEC = NumOpt("survivalai_retaliationdelay",     5)
local RETALIATION_FRACTION  = 0.5    -- of a regular wave budget
local RETALIATION_STAGE     = 2      -- beacons nearest the dead one that answer
local BEACON_CREEP_MIN_DIST = NumOpt("survivalai_creepmin",           900)
local BEACON_CREEP_MAX_DIST = NumOpt("survivalai_creepmax",          3000)
local SURVIVAL_DEBUG        = true   -- echo per-attempt beacon placement rejections

-- Beacon specialization: every beacon but the master rolls a kind.
local SPECIAL_CHANCE       = NumOpt("survivalai_specialchance", 0.6)
local SPECIAL_KINDS        = { "shield", "jammer", "accelerator", "forge" }
local MAX_ACCELERATORS     = 2      -- per team; they stack on the wave clock
local BEACON_SHIELD_MAX    = 300    -- shield-beacon overshield on spawned waves
local BEACON_SHIELD_REGEN  = 10
local BEACON_SHIELD_DELAY  = 8      -- seconds
local JAMMER_CLOAK_LEVEL   = 2      -- Spring.SetUnitCloak scriptCloak level (verify in game)
local ACCEL_SECONDS        = 8      -- interval shaved per live accelerator beacon
local MIN_WAVE_INTERVAL    = 20     -- floor, whatever accelerators/rage do
local FORGE_HP_MULT        = 1.4
local FORGE_DMG_MULT       = 1.5
local FORGE_RULES_PARAM    = "survival_forge"

-- Garrisons: every beacon is fortified the moment it appears, at the tier the
-- wave clock has reached. When Tech 2 unlocks, standing T1 garrisons are
-- replaced (not added to) by T2 ones, one beacon per sweep. A garrison may
-- also include a shield generator; that survives the upgrade.
local GARRISON_COUNT         = math.max(0, math.floor(NumOpt("survivalai_garrison", 3)))   -- 0 disables
local GARRISON_RADIUS        = 190
local GARRISON_T1            = { "fedmenlo", "fedstinger", "lozjericho", "lozrazor" }
local GARRISON_T2            = { "fedimmolator", "fedjavelin", "lozinferno", "lozrattlesnake" }
local GARRISON_MAX_TIER      = 2
local GARRISON_SHIELD_CHANCE = NumOpt("survivalai_garrisonshield", 0.35)
local GARRISON_SHIELDS       = { [1] = "smallshieldgenerator", [2] = "smallshieldgenerator" }

-- Last-beacon rage
local RAGE_BUDGET_MULT   = 1.5
local RAGE_INTERVAL_MULT = 0.5
local RAGE_SHIELD_MAX    = 2000
local RAGE_SHIELD_REGEN  = 40
local RAGE_SHIELD_DELAY  = 10

-- Surge waves: every Nth wave doubles the budget with a dramatic archetype,
-- launched from the whole network at once
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
local spGetUnitDefID         = Spring.GetUnitDefID
local spDestroyUnit          = Spring.DestroyUnit
local spGetUnitTransporter   = Spring.GetUnitTransporter
local spValidUnitID          = Spring.ValidUnitID
local spGiveOrderToUnit      = Spring.GiveOrderToUnit

local INLOS = { inlos = true }

local gaiaID = spGetGaiaTeamID()

local survivalTeams = {}    -- [teamID] = { diff, spawnX, spawnZ, targetX, targetZ,
                            --              clockStartFrame, defeated, rage,
                            --              seeded, networkSize, respawnFrame,
                            --              planX, planZ, stagingIDs, retal }
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

-- Field accounting (see TrackWaveUnit)
local costByDef    = {}     -- [unitDefID] = metal cost
local tierByDef    = {}     -- [unitDefID] = tier, for pool units
local unitCost     = {}     -- [unitID] = metal cost of a live wave unit
local fieldValue   = {}     -- [teamID] = live wave metal on the field
local limitedUnits = {}     -- [unitID] = true for live LIMITED_TIER wave units
local limitedLive  = 0      -- how many of those are alive, all survival teams

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

-- Minutes on the wave clock (0 until it starts)
local function ClockMinutes(frame)
	if not clockStartFrame then return 0 end
	return (frame - clockStartFrame) / (30 * 60)
end

local function TeamIsDead(teamID)
	return select(3, spGetTeamInfo(teamID, false)) and true or false
end

--------------------------------------------------------------------------------
-- Wave unit bookkeeping. Every wave unit carries its metal cost, so the live
-- value on the field is known without ever polling: it moves only on spawn and
-- on death (or capture). Garrison structures are not wave units and never
-- count.
--------------------------------------------------------------------------------

local function TrackWaveUnit(unitID, teamID)
	if waveUnits[unitID] then return end
	waveUnits[unitID] = teamID
	local udid = spGetUnitDefID(unitID)
	local cost = (udid and costByDef[udid]) or 0
	unitCost[unitID]   = cost
	fieldValue[teamID] = (fieldValue[teamID] or 0) + cost
	if udid and tierByDef[udid] == LIMITED_TIER then
		limitedUnits[unitID] = true
		limitedLive = limitedLive + 1
	end
end

local function UntrackWaveUnit(unitID)
	local teamID = waveUnits[unitID]
	if not teamID then return end
	waveUnits[unitID] = nil
	fieldValue[teamID] = math.max(0, (fieldValue[teamID] or 0) - (unitCost[unitID] or 0))
	unitCost[unitID] = nil
	if limitedUnits[unitID] then
		limitedUnits[unitID] = nil
		limitedLive = math.max(0, limitedLive - 1)
	end
end

-- Live opposing teams (the "players" the top-tier ration is counted against)
local function CountOpponents(teamID)
	local n = 0
	for _, t in ipairs(spGetTeamList()) do
		if t ~= gaiaID and t ~= teamID and not survivalTeams[t]
			and not spAreTeamsAllied(teamID, t) and not TeamIsDead(t) then
			n = n + 1
		end
	end
	return n
end

-- How many more top-tier units may be alive right now
local function LimitedTierRoom(teamID)
	local cap = math.ceil(CountOpponents(teamID) / LIMITED_PLAYERS_PER_UNIT)
	return math.max(0, cap - limitedLive)
end

--------------------------------------------------------------------------------
-- Budget
--------------------------------------------------------------------------------

-- Share of the full-network budget this team gets with the beacons it has
-- left. Killing beacons eases the pressure, but never below NETWORK_FLOOR.
local function NetworkScale(teamID, state)
	local size = state.networkSize or 1
	if size <= 1 then return 1 end
	local live = math.min(size, Beacons.Count(teamID))
	return NETWORK_FLOOR + (1 - NETWORK_FLOOR) * (live / size)
end

-- budget: what the curve asks for right now. spawn: what actually gets bought
-- once the metal already on the field is counted against it.
local function WaveBudget(teamID, state, frame, extraMult)
	local mult = state.diff.budgetMult * NetworkScale(teamID, state) * (extraMult or 1)
	if state.rage then mult = mult * RAGE_BUDGET_MULT end
	local budget = Composer.Budget(ClockMinutes(frame), CURVE, mult)
	local field  = fieldValue[teamID] or 0
	local spawn  = Composer.FieldClamp(budget, field, FIELD_CAP_MULT, MIN_WAVE_FRACTION)
	return budget, spawn, field
end

--------------------------------------------------------------------------------
-- Beacon specialization
--------------------------------------------------------------------------------

-- Set just before CreateUnit'ing a beacon; consumed by UnitCreated (which
-- fires synchronously inside the CreateUnit call). The master beacon arrives
-- from game_spawn with this unset and defaults to standard.
local pendingBeaconKind = nil

-- Kind for a regrown beacon: an independent roll, except that accelerators
-- are capped because they stack on the wave clock.
local function RollBeaconKind(teamID)
	if math.random() < SPECIAL_CHANCE then
		local kind = SPECIAL_KINDS[math.random(1, #SPECIAL_KINDS)]
		if kind == "accelerator"
			and Beacons.CountKind(teamID, "accelerator") >= MAX_ACCELERATORS then
			return "standard"
		end
		return kind
	end
	return "standard"
end

-- Kinds for the starting network, dealt from a deck instead of rolled one by
-- one: the share of specials is exact and they are spread across the four
-- kinds, so no game opens with a pile of accelerators.
local function BuildKindDeck(n)
	local order = {}
	for i = 1, #SPECIAL_KINDS do order[i] = SPECIAL_KINDS[i] end
	for i = #order, 2, -1 do
		local j = math.random(1, i)
		order[i], order[j] = order[j], order[i]
	end

	local specials = math.floor(n * SPECIAL_CHANCE + 0.5)
	local deck, accels = {}, 0
	for i = 1, n do
		local kind = "standard"
		if i <= specials then
			kind = order[(i - 1) % #order + 1]
			if kind == "accelerator" then
				accels = accels + 1
				if accels > MAX_ACCELERATORS then kind = "standard" end
			end
		end
		deck[i] = kind
	end
	for i = #deck, 2, -1 do
		local j = math.random(1, i)
		deck[i], deck[j] = deck[j], deck[i]
	end
	return deck
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

--------------------------------------------------------------------------------
-- Staging. The next wave's archetype, target and launch beacons are decided
-- as soon as the previous wave leaves, and the launch beacons are flagged
-- (survival_staging, in LOS only) so players can read where the next push
-- comes from, and act on it.
--------------------------------------------------------------------------------

local nextPlan = nil   -- { arch =, faction =, surge = }  shared by all survival teams

local function ClearStaging(state)
	local ids = state.stagingIDs
	if ids then
		for i = 1, #ids do
			if spValidUnitID(ids[i]) then
				spSetUnitRulesParam(ids[i], "survival_staging", 0, INLOS)
			end
		end
	end
	state.stagingIDs = nil
end

-- (Re)pick this team's staging beacons for the planned wave. Keeps the
-- planned target if there is one, so losing a staging beacon moves the launch
-- point, not the objective.
local function StageTeam(teamID, state)
	ClearStaging(state)
	if not nextPlan or state.defeated then return end

	if not state.planX then
		state.planX, state.planZ = Spawner.SelectTarget(env, teamID, isBuildingByDef)
	end
	local stage = nextPlan.surge and "all" or (nextPlan.arch.stage or 3)
	local list  = Beacons.PickStaging(teamID, state.planX, state.planZ, stage, math.random)

	local ids = {}
	for i = 1, #list do
		ids[i] = list[i].unitID
		spSetUnitRulesParam(list[i].unitID, "survival_staging", 1, INLOS)
	end
	state.stagingIDs = ids
end

-- The staging list as live beacon entries (dead ones dropped), nearest first.
local function ResolveStaging(state)
	local out, ids = {}, state.stagingIDs
	if ids then
		for i = 1, #ids do
			local x, z = Beacons.GetPos(ids[i])
			if x then
				out[#out + 1] = { unitID = ids[i], x = x, z = z, kind = Beacons.GetKind(ids[i]) }
			end
		end
	end
	return out
end

local function PickWaveArchetype(number, maxTier, isSurge)
	-- Surge waves force a dramatic archetype (viability-filtered)
	if isSurge then
		local cands = {}
		for _, name in ipairs(SURGE_ARCHETYPES) do
			local a = Composer.ByName[name]
			if a and Composer.IsViable(pools, a, maxTier) then
				cands[#cands + 1] = a
			end
		end
		if #cands > 0 then return cands[math.random(1, #cands)] end
	end
	return Composer.PickArchetype(pools, number, maxTier, math.random)
end

-- Decide wave (waveNumber + 1) now, for launch at nextWaveFrame.
local function PlanNextWave(frame)
	local number  = waveNumber + 1
	local eta     = nextWaveFrame or frame
	local maxTier = MaxUnlockedTier(eta - (clockStartFrame or eta))
	local isSurge = SURGE_EVERY > 0 and (number % SURGE_EVERY == 0)

	local faction = nil
	local arch    = PickWaveArchetype(number, maxTier, isSurge)
	if #pools.factions > 0 and math.random() < FACTION_PURE_CHANCE then
		faction = pools.factions[math.random(1, #pools.factions)]
	end
	nextPlan = { arch = arch, faction = faction, surge = isSurge }

	for teamID, state in pairs(survivalTeams) do
		state.planX, state.planZ = nil, nil
		StageTeam(teamID, state)
	end

	spSetGameRulesParam("survival_nextWaveType",  arch.name)
	spSetGameRulesParam("survival_nextWaveSurge", isSurge and 1 or 0)
	if isSurge then
		spEcho("[Survival] SURGE WAVE INCOMING -- brace for wave " .. number)
	end
end

--------------------------------------------------------------------------------
-- Wave execution
--
-- LaunchWave(teamID, state, frame, arch, faction, maxTier, o)
--   o.mult    extra budget multiplier (surge, retaliation)
--   o.staging explicit staging list ({unitID, x, z, kind}, nearest first);
--             omitted, the team's telegraphed staging beacons are used
--   o.tx,o.tz target; omitted, one is selected now
--   o.even    deal units evenly across the staging beacons
--   o.noDrop  never fly this one in (retaliation is an immediate ground answer)
--   o.label   echo prefix ("Wave 12" / "Retaliation")
--------------------------------------------------------------------------------

local function LaunchWave(teamID, state, frame, arch, faction, maxTier, o)
	if state.defeated or TeamIsDead(teamID) then return end

	if not state.spawnX then
		state.spawnX, state.spawnZ = ResolveSpawnPoint(teamID)
	end

	local beaconCount = Beacons.Count(teamID)
	local budget, spawnBudget, field = WaveBudget(teamID, state, frame, o.mult)

	local tx, tz = o.tx, o.tz
	if not tx then
		tx, tz = Spawner.SelectTarget(env, teamID, isBuildingByDef)
	end
	state.targetX, state.targetZ = tx, tz

	local staging = o.staging or ResolveStaging(state)
	if #staging == 0 and beaconCount > 0 then
		staging = Beacons.PickStaging(teamID, tx, tz, arch.stage or 3, math.random)
	end

	local tierLimit = { [LIMITED_TIER] = LimitedTierRoom(teamID) }
	local tierUsed  = {}

	----------------------------------------------------------------------------
	-- Drop archetype: gunships load the ground contingent and haul it to the
	-- target; the loading/dispatch state machine lives in GameFrame.
	----------------------------------------------------------------------------
	if arch.drop and tx and not o.noDrop then
		local drop = Composer.ComposeDrop(pools, spawnBudget, {
			maxTier = maxTier, maxUnits = MAX_WAVE_UNITS,
			weights = arch.weights, faction = faction, random = math.random,
			tierLimit = tierLimit, tierUsed = tierUsed,
		})
		if #drop.plan > 0 then
			-- The staging beacon nearest the target hosts the drop (its kind applies)
			local sx, sz, stageKind = state.spawnX, state.spawnZ, nil
			if staging[1] then
				sx, sz, stageKind = staging[1].x, staging[1].z, staging[1].kind
			end

			local g = Spawner.SpawnDropWave(env, teamID, sx, sz, drop, tx, tz)
			local touched = {}
			for _, cid in ipairs(g.carriers) do
				TrackWaveUnit(cid, teamID) ; touched[#touched + 1] = cid
			end
			for _, wid in ipairs(g.walkers)  do
				TrackWaveUnit(wid, teamID) ; touched[#touched + 1] = wid
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
				TrackWaveUnit(pid, teamID)
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
				"[Survival] %s team %d [drop%s%s]: %d riders / %d carriers / %d walkers, spawn %d of budget %d (field was %d), tier<=%d, %d/%d beacons",
				o.label, teamID, o.surge and " SURGE" or "",
				faction and (" / " .. faction) or "",
				nPassengers, #g.carriers, #g.walkers, spawnBudget, budget, field, maxTier,
				beaconCount, state.networkSize or beaconCount))
			return
		end
		-- No carriers could be bought: fall through and send it as ground.
		-- (tierUsed keeps what the abandoned drop counted; that only makes the
		-- ground wave more conservative with rationed units.)
	end

	-- Normal (non-drop) wave: compose once, deal it out to the staging
	-- beacons; pre-beacon fallback spawns everything at the start spot.
	local list, spent = Composer.Compose(pools, spawnBudget, {
		maxTier   = maxTier,
		maxUnits  = MAX_WAVE_UNITS,
		weights   = arch.weights,
		faction   = faction,
		random    = math.random,
		tierLimit = tierLimit,
		tierUsed  = tierUsed,
	})
	if #list == 0 then return end

	local groups
	if #staging > 0 then
		groups = Beacons.SplitAmong(staging, list, o.even or arch.split)
	else
		groups = { { x = state.spawnX, z = state.spawnZ, list = list } }
	end

	-- Split archetypes (raids) send every group at its own target; everything
	-- else converges on the one wave target.
	local splitTargets = arch.split and not o.tx and #groups > 1

	local createdTotal = 0
	for g = 1, #groups do
		local gx, gz = tx, tz
		if splitTargets and g > 1 then
			local sx, sz = Spawner.SelectTarget(env, teamID, isBuildingByDef)
			if sx then gx, gz = sx, sz end
		end
		local created = Spawner.SpawnWave(env, teamID, groups[g].x, groups[g].z,
		                                  groups[g].list, gx, gz)
		for i = 1, #created do
			TrackWaveUnit(created[i], teamID)
		end
		ApplyBeaconEffect(groups[g].kind, created)
		createdTotal = createdTotal + #created
	end

	spEcho(string.format(
		"[Survival] %s team %d [%s%s%s]: %d units from %d beacon(s), %d metal, spawn %d of budget %d (field was %d), tier<=%d, %d/%d beacons",
		o.label, teamID, arch.name, o.surge and " SURGE" or "",
		faction and (" / " .. faction) or "",
		createdTotal, #groups, spent, spawnBudget, budget, field, maxTier,
		beaconCount, state.networkSize or beaconCount))
end

--------------------------------------------------------------------------------
-- Garrisons
--------------------------------------------------------------------------------

local GARRISON_LISTS = { GARRISON_T1, GARRISON_T2 }   -- validated in Initialize

-- One structure on a ring around (bx, bz), widening on retries.
local function PlaceOnRing(name, bx, bz, radius, teamID)
	for attempt = 1, 5 do
		local ang = math.random() * 2 * math.pi
		local r   = radius + (attempt - 1) * 45
		local x   = math.max(48, math.min(env.mapSizeX - 48, bx + math.cos(ang) * r))
		local z   = math.max(48, math.min(env.mapSizeZ - 48, bz + math.sin(ang) * r))
		local uid = spCreateUnit(name, x, spGetGroundHeight(x, z), z, 0, teamID)
		if uid then return uid end
	end
	return nil
end

-- Bring a beacon's garrison to `tier`. Turrets of a lower tier are removed
-- and replaced. The shield generator is rolled once, when the beacon is first
-- fortified: one that has it keeps it through upgrades, one that missed the
-- roll never gets it.
local function Fortify(teamID, beaconID, bx, bz, tier)
	local oldTier, oldTurrets, shieldID = Beacons.GetGarrison(beaconID)
	if oldTier == nil then return 0 end
	if GARRISON_COUNT <= 0 then
		Beacons.SetGarrison(beaconID, tier, {}, nil)
		return 0
	end

	for i = 1, #oldTurrets do
		local uid = oldTurrets[i]
		if spValidUnitID(uid) and spGetUnitTeam(uid) == teamID then
			-- reclaimed = true: vanish without an explosion or a wreck
			spDestroyUnit(uid, false, true)
		end
	end

	local list = GARRISON_LISTS[tier] or GARRISON_T1
	if #list == 0 then list = GARRISON_T1 end

	local turrets = {}
	if #list > 0 then
		for i = 1, GARRISON_COUNT do
			local uid = PlaceOnRing(list[math.random(1, #list)], bx, bz, GARRISON_RADIUS, teamID)
			if uid then turrets[#turrets + 1] = uid end
		end
	end

	if shieldID and not spValidUnitID(shieldID) then shieldID = nil end
	local shieldName = GARRISON_SHIELDS[tier]
	if oldTier == 0 and shieldName and math.random() < GARRISON_SHIELD_CHANCE then
		shieldID = PlaceOnRing(shieldName, bx, bz, GARRISON_RADIUS, teamID)
	end

	Beacons.SetGarrison(beaconID, tier, turrets, shieldID)
	return #turrets, shieldID ~= nil
end

local function GarrisonTier(frame)
	local maxTier = MaxUnlockedTier(frame - (clockStartFrame or frame))
	return math.max(1, math.min(GARRISON_MAX_TIER, maxTier))
end

-- One beacon per survival team per sweep, so a tier unlock rolls through the
-- network over half a minute instead of landing in a single frame.
local function UpgradeGarrisons(frame)
	local tier = GarrisonTier(frame)
	if tier < 2 then return end
	for teamID, state in pairs(survivalTeams) do
		if not state.defeated then
			local beaconID, x, z = Beacons.NextUpgrade(teamID, tier)
			if beaconID then
				local placed, shielded = Fortify(teamID, beaconID, x, z, tier)
				spEcho(string.format(
					"[Survival] Team %d beacon at (%.0f, %.0f) garrison upgraded to T%d: %d turret(s)%s",
					teamID, x, z, tier, placed, shielded and " + shield generator" or ""))
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Beacon network: seeding and regrowth
--------------------------------------------------------------------------------

-- Create one beacon of the given kind; returns its unitID or nil.
local function SpawnBeacon(teamID, x, z, kind)
	-- Same grid snap the validator used, so CreateUnit tests the identical cell
	x = 16 * math.floor((x + 8) / 16)
	z = 16 * math.floor((z + 8) / 16)

	pendingBeaconKind = kind
	local uid = spCreateUnit(BEACON_UNIT, x, spGetGroundHeight(x, z), z, 0, teamID)
	pendingBeaconKind = nil

	if not uid then
		-- Validator passed but the engine refused: usually a unitdef instance
		-- cap (maxThisUnit / unitRestricted) or a unit-limit hit -- loud so it
		-- can never fail silently again.
		spEcho(string.format(
			"[Survival] Team %d: CreateUnit('%s') FAILED at (%.0f, %.0f) despite valid spot"
			.. " -- check the beacon unitdef for maxThisUnit / unitRestricted",
			teamID, BEACON_UNIT, x, z))
	end
	return uid, x, z
end

local function PublishNetwork()
	local live, size, respawn = 0, 0, 0
	for teamID, state in pairs(survivalTeams) do
		live = live + Beacons.Count(teamID)
		size = size + (state.networkSize or 0)
		if state.respawnFrame and (respawn == 0 or state.respawnFrame < respawn) then
			respawn = state.respawnFrame
		end
	end
	spSetGameRulesParam("survival_beacons",      live)
	spSetGameRulesParam("survival_beaconsMax",   math.max(size, live))
	spSetGameRulesParam("survival_respawnFrame", respawn)
end

-- Plant the starting network around the master beacon and garrison all of it.
-- Returns false while the master does not exist yet (the caller retries).
local function SeedNetwork(teamID, state, frame)
	local list = Beacons.GetAll(teamID)
	if #list == 0 then return false end
	state.seeded = true

	local master = list[1]

	-- Home territory: a circle around the master reaching part of the way to
	-- the nearest opposing start, so the network opens as a base, not a siege.
	local nearest = math.huge
	for _, t in ipairs(spGetTeamList()) do
		if t ~= gaiaID and t ~= teamID and not survivalTeams[t]
			and not spAreTeamsAllied(teamID, t) and not TeamIsDead(t) then
			local sx, sz = ResolveSpawnPoint(t)
			local dx, dz = sx - master.x, sz - master.z
			local d = math.sqrt(dx * dx + dz * dz)
			if d < nearest then nearest = d end
		end
	end
	local home = HOME_MIN_RADIUS * 2
	if nearest < math.huge then
		home = math.max(HOME_MIN_RADIUS, nearest * HOME_FRACTION)
		home = math.min(home, nearest * HOME_MAX_FRACTION)
	end

	local want = NETWORK_SIZE - #list
	local deck = BuildKindDeck(math.max(0, want))
	local debugWas = SURVIVAL_DEBUG
	SURVIVAL_DEBUG = false   -- seeding makes hundreds of attempts; keep the log readable
	for i = 1, want do
		local x, z = Beacons.PickSeedSpot(beaconEnv, teamID, master.x, master.z, home,
		                                  SEED_MIN_DIST, SEED_MAX_DIST)
		if not x then break end
		SpawnBeacon(teamID, x, z, deck[i])
	end
	SURVIVAL_DEBUG = debugWas

	state.networkSize = Beacons.Count(teamID)

	local tier = GarrisonTier(frame)
	local all  = Beacons.GetAll(teamID)
	for i = 1, #all do
		Fortify(teamID, all[i].unitID, all[i].x, all[i].z, tier)
	end

	spEcho(string.format(
		"[Survival] Team %d network seeded: %d of %d beacons within %.0f elmos of the master, T%d garrisons",
		teamID, state.networkSize, NETWORK_SIZE, home, tier))
	if state.networkSize < NETWORK_SIZE then
		spEcho("[Survival] Team " .. teamID .. ": map too tight for the full network; "
			.. "playing with " .. state.networkSize .. " beacons")
	end
	return true
end

-- Regrowth: one beacon, placed by the creep logic (forward of the network,
-- toward the current target), fortified at the current garrison tier.
local function CreepBeacon(teamID, state, frame)
	if state.defeated or Beacons.Count(teamID) == 0 then return nil end

	local cx, cz = Beacons.PickCreepSpot(beaconEnv, teamID, state.targetX, state.targetZ,
	                                     BEACON_CREEP_MIN_DIST, BEACON_CREEP_MAX_DIST)
	if not cx then
		spEcho("[Survival] Team " .. teamID .. ": no valid spot for a new beacon this cycle")
		return nil
	end

	local kind = RollBeaconKind(teamID)
	local uid, x, z = SpawnBeacon(teamID, cx, cz, kind)
	if uid then
		local tier = GarrisonTier(frame)
		Fortify(teamID, uid, x, z, tier)
		spEcho(string.format("[Survival] Team %d network regrows: [%s] beacon at (%.0f, %.0f), T%d garrison",
			teamID, kind, x, z, tier))
	end
	return uid
end

-- The regrowth countdown starts when the network first drops below full
-- strength and restarts after each new beacon, so a kill always buys the
-- players the whole interval. A raging team makes its last stand instead.
local function UpdateRespawn(teamID, state, frame)
	local before = state.respawnFrame
	local live   = Beacons.Count(teamID)

	if RESPAWN_MINUTES <= 0 or state.defeated or state.rage or not state.seeded
		or live == 0 or live >= (state.networkSize or 0) then
		state.respawnFrame = nil
	elseif not state.respawnFrame then
		state.respawnFrame = frame + math.floor(RESPAWN_MINUTES * 60 * 30)
	elseif frame >= state.respawnFrame then
		if CreepBeacon(teamID, state, frame) then
			state.respawnFrame = nil   -- re-arms on the next check if still short
		else
			state.respawnFrame = frame + RESPAWN_RETRY_FRAMES
		end
	end

	if state.respawnFrame ~= before then PublishNetwork() end
end

--------------------------------------------------------------------------------
-- Wave scheduling
--------------------------------------------------------------------------------

local function RunWave(frame)
	waveNumber = waveNumber + 1

	local maxTier = MaxUnlockedTier(frame - (clockStartFrame or frame))
	local plan    = nextPlan
	if not plan then
		local isSurge = SURGE_EVERY > 0 and (waveNumber % SURGE_EVERY == 0)
		plan = { arch = PickWaveArchetype(waveNumber, maxTier, isSurge), surge = isSurge }
	end

	for teamID, state in pairs(survivalTeams) do
		LaunchWave(teamID, state, frame, plan.arch, plan.faction, maxTier, {
			label = "Wave " .. waveNumber,
			surge = plan.surge,
			mult  = plan.surge and SURGE_BUDGET_MULT or 1,
			even  = plan.surge,
			tx    = (not plan.arch.split) and state.planX or nil,
			tz    = (not plan.arch.split) and state.planZ or nil,
		})
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

	spSetGameRulesParam("survival_waveNumber",    waveNumber)
	spSetGameRulesParam("survival_waveType",      plan.arch.name)
	spSetGameRulesParam("survival_nextWaveFrame", nextWaveFrame)

	-- Decide and telegraph the next one (type, surge flag, staging beacons)
	PlanNextWave(frame)
end

-- A destroyed beacon is answered by its nearest neighbors: a reduced, ground
-- only strike at whoever did it. It is not a wave: the wave counter, the
-- wave clock and the telegraphed plan are all left alone.
local function RunRetaliation(teamID, state, frame, r)
	if state.defeated or Beacons.Count(teamID) == 0 then return end

	local maxTier = MaxUnlockedTier(frame - (clockStartFrame or frame))
	local arch    = Composer.ByName["assault"]
	if not (arch and Composer.IsViable(pools, arch, maxTier)) then
		arch = Composer.PickArchetype(pools, math.max(1, waveNumber), maxTier, math.random)
	end

	LaunchWave(teamID, state, frame, arch, nil, maxTier, {
		label   = "Retaliation",
		mult    = RETALIATION_FRACTION,
		staging = Beacons.PickStaging(teamID, r.bx, r.bz, RETALIATION_STAGE, nil),
		tx      = r.tx,
		tz      = r.tz,
		noDrop  = true,
	})
end

local function TickRetaliations(frame)
	for teamID, state in pairs(survivalTeams) do
		local q = state.retal
		if q then
			for i = #q, 1, -1 do
				if frame >= q[i].frame then
					local r = table.remove(q, i)
					RunRetaliation(teamID, state, frame, r)
				end
			end
		end
	end
end

-- Field pressure for the UI: live wave metal against the field cap, 0-100.
local lastPressure = -1
local function PublishPressure(frame)
	local field, cap = 0, 0
	for teamID, state in pairs(survivalTeams) do
		if not state.defeated then
			local budget = WaveBudget(teamID, state, frame)
			field = field + (fieldValue[teamID] or 0)
			cap   = cap + budget * FIELD_CAP_MULT
		end
	end
	local pct = 0
	if cap > 0 then pct = math.floor(math.min(1, field / cap) * 100 + 0.5) end
	if pct ~= lastPressure then
		lastPressure = pct
		spSetGameRulesParam("survival_pressure", pct)
	end
end

-- Idle stragglers get re-marched at their team's current target (or a fresh
-- one if the old target area has been wiped).
local function FlushIdleUnits()
	local byTeam = {}
	for unitID, teamID in pairs(idleUnits) do
		-- Riders waiting for (or inside) a carrier are not stragglers
		if waveUnits[unitID] and not dropPending[unitID] then
			local teamOf = waveUnits[unitID]
			local list = byTeam[teamOf]
			if not list then list = {} ; byTeam[teamOf] = list end
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
-- Drop wave state machine. A group waits in loading until every surviving
-- rider is aboard (or the deadline hits), then dispatches: each carrier gets
-- move -> area-unload -> fight queued, riders left on the ground walk, and
-- embarked riders keep their dropPending entry so UnitUnloaded can order them
-- the moment they hit dirt.
--------------------------------------------------------------------------------

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

	for i = 1, #pools.entries do
		local e = pools.entries[i]
		costByDef[e.defID] = e.cost
		tierByDef[e.defID] = e.tier
	end

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

	-- Mid-game luarules reload: re-register beacons that already exist, with
	-- their kind. Garrison unit lists are lost across a reload, so the beacons
	-- are marked fully fortified (nothing is placed twice, nothing upgraded).
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		local udid = spGetUnitDefID(unitID)
		if udid == beaconDefID then
			local t = spGetUnitTeam(unitID)
			if t and survivalTeams[t] then
				local x, _, z = spGetUnitPosition(unitID)
				local kind = (spGetUnitRulesParam(unitID, "survival_beacon_kind"))
				Beacons.Register(t, unitID, x, z, kind, spGetGameFrame(), GARRISON_MAX_TIER)
				survivalTeams[t].seeded      = true
				survivalTeams[t].networkSize = NETWORK_SIZE
			end
		end
	end

	-- Validate garrison defs; drop unknowns loudly
	for _, list in ipairs(GARRISON_LISTS) do
		for i = #list, 1, -1 do
			if not UnitDefNames[list[i]] then
				spEcho("[Survival] WARNING: garrison turret '" .. list[i]
					.. "' not found; removed from rotation")
				table.remove(list, i)
			end
		end
	end
	for tier, name in pairs(GARRISON_SHIELDS) do
		if not UnitDefNames[name] then
			spEcho("[Survival] WARNING: garrison shield generator '" .. name
				.. "' not found; T" .. tier .. " garrisons get none")
			GARRISON_SHIELDS[tier] = nil
		end
	end

	spSetGameRulesParam("survival_active", 1)
	spSetGameRulesParam("survival_rage", 0)
	spSetGameRulesParam("survival_pressure", 0)
	PublishNetwork()

	GG.Survival = {
		IsSurvivalTeam = function(teamID) return survivalTeams[teamID] ~= nil end,
		GetWaveNumber  = function() return waveNumber end,
		GetBeaconCount = function(teamID) return Beacons.Count(teamID) end,
		GetFieldValue  = function(teamID) return fieldValue[teamID] or 0 end,
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

			for teamID, state in pairs(survivalTeams) do
				if not state.seeded then SeedNetwork(teamID, state, frame) end
			end
			PublishNetwork()
			PlanNextWave(frame)   -- telegraph wave 1 through the grace period
		end
		return
	end

	-- The master beacon was not there yet when the clock started: keep trying
	for teamID, state in pairs(survivalTeams) do
		if not state.seeded and not state.defeated then
			if SeedNetwork(teamID, state, frame) then
				PublishNetwork()
				state.planX, state.planZ = nil, nil
				StageTeam(teamID, state)
			end
		end
	end

	if frame >= nextWaveFrame then
		RunWave(frame)
	end

	TickRetaliations(frame)

	if #dropGroups > 0 then
		TickDropGroups(frame)
	end

	for teamID, state in pairs(survivalTeams) do
		UpdateRespawn(teamID, state, frame)
	end
	PublishPressure(frame)

	if frame % REORDER_PERIOD_FRAMES == 0 then
		UpgradeGarrisons(frame)
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
		spSetUnitRulesParam(unitID, "survival_staging", 0, INLOS)
		PublishNetwork()
	end
end

function gadget:UnitIdle(unitID, unitDefID, unitTeam)
	if waveUnits[unitID] then
		idleUnits[unitID] = true
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam,
                              attackerID, attackerDefID, attackerTeamID)
	UntrackWaveUnit(unitID)
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

	-- Beacon down: bounty, retaliation, restage, defeat check
	if unitDefID == beaconDefID then
		local bx, bz = Beacons.GetPos(unitID)
		if not Beacons.Remove(unitID) then return end
		local frame = spGetGameFrame()
		local state = survivalTeams[unitTeam]

		-- The bounty grows with the wave clock: clearing a fresh network early
		-- is worth less than cracking a dug-in one later.
		if attackerTeamID and attackerTeamID ~= unitTeam and attackerTeamID ~= gaiaID
			and GG.Research then
			local t = math.min(1, ClockMinutes(frame) / RP_FULL_MINUTES)
			local reward = BEACON_RP_REWARD * (RP_START_FRACTION + (1 - RP_START_FRACTION) * t)
			reward = 5 * math.floor(reward / 5 + 0.5)
			GG.Research.Add(attackerTeamID, reward, "beacon")
		end

		if state and clockStarted and not gameOverSeen then
			-- Its neighbors answer, aimed at the killer if we know where it is
			local tx, tz
			if attackerID then
				local ax, _, az = spGetUnitPosition(attackerID)
				tx, tz = ax, az
			end
			state.retal = state.retal or {}
			state.retal[#state.retal + 1] = {
				frame = frame + RETALIATION_DELAY_SEC * 30,
				bx = bx, bz = bz, tx = tx, tz = tz,
			}
			spEcho("[Survival] Beacon destroyed: retaliation incoming")

			-- It was due to launch the next wave: hand its slot to another
			local ids = state.stagingIDs
			if ids then
				for i = 1, #ids do
					if ids[i] == unitID then
						StageTeam(unitTeam, state)
						break
					end
				end
			end
		end

		local remaining = Beacons.Count(unitTeam)
		if remaining == 0 then
			if state then
				state.defeated = true
				state.retal    = nil
				ClearStaging(state)
				spEcho("[Survival] Team " .. unitTeam .. " has no beacons left")
			end
		elseif remaining == 1 and state and state.everHadTwo and not state.rage then
			-- LAST-BEACON RAGE: budget surges, waves accelerate, regrowth halts,
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
		PublishNetwork()
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
		UntrackWaveUnit(unitID)
		idleUnits[unitID] = nil
	end
end
