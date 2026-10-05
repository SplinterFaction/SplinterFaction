-- ============================================================
-- SimpleAI Enhanced -- based on original by Damgam (2020)
-- v4: AdaptiveAI luaai entry (real-time difficulty controller in
--     b_adaptive.lua), NeverStall resource floor internalized (replaces
--     the old lump-injection cheat), behavior hooks for kills/losses and
--     finished units.
-- v5: Storage growth (b_construction raises storage toward 100k over the
--     game) plus the "signal pool": every stock/storage ratio the AI reads
--     (overflow test, construction thresholds) is now measured against
--     SignalPool() instead of raw storage, so a large bank does not turn
--     "62% full" into "62,000 banked". (The NeverStall floor is a fixed
--     amount; see NEVERSTALL_BASE.)
-- v6: Stall signal (demand vs income, ctx.stall) and demand throttling:
--     b_throttle pauses factories and cancels barely-started expensive
--     builds while a team is stalling; b_construction picks cheaper units
--     and stops adding factories/constructors.
-- v3: Tech-aware build lists, faction detection, economy teching
--     goals, coordinated attack waves, commander survival,
--     repair logic, mex expansion, threat response.
-- ============================================================

local enabled        = false
local teams          = Spring.GetTeamList()
local wind           = Game.windMax
local mapsizeX       = Game.mapSizeX
local mapsizeZ       = Game.mapSizeZ
local gameShortName  = Game.gameShortName
local gaiaTeamID     = Spring.GetGaiaTeamID()

-- ============================================================
-- CONSTANTS
-- ============================================================

local WAVE_INTERVAL     = 3600   -- frames between attack wave launches (legacy: attackTimer init only)
-- Wave sizes, muster radius, wave cooldown, retarget interval, and the retreat
-- hysteresis thresholds are owned by b_combat.lua (stage 3 of the modular split).

-- Combat composition. Multiplies a unit's build weight by its role so the AI
-- leans on skirmishers (the bread-and-butter line) while still fielding support.
-- Keyed by customParams.buildmenucategory (SF factory categories). Tune freely.
local COMBAT_ROLE_WEIGHT = {
	Skirmish = 1.00,   -- general-purpose front-line units: build the most of these
	Support  = 0.40,   -- good and needed, but secondary
	Scout    = 0.30,
	Utility  = 0.35,
	Unsorted = 0.60,   -- uncategorised armed units
	default  = 0.60,   -- anything with no/unknown buildmenucategory

	-- Ceilings for units that deal no direct damage, whatever their build
	-- menu category says. They are force multipliers, not the force:
	--   heat only (Flashpoint, Cauterizer): can kill units, but cannot fire
	--     at buildings at all, so an army of them cannot take a base
	--   disruption only (Equalizer, Dominator): disables, never kills
	-- Detected from the weapon customparams heatweapon / disruptionweapon.
	HeatOnly    = 0.40,
	DisruptOnly = 0.25,
}

-- Weak-point attack targeting
local ATTACK_SCAN_R     = 650    -- radius around an enemy building used to tally its defenders
local ATTACK_DIST_W     = 0.10   -- how strongly distance-from-muster penalises a candidate target

local FACTORY_OVERFLOW      = 0.62 -- metal & energy signal-pool fraction that counts as "overflowing"

-- Signal pool. The AI's economy signals are all "stock as a fraction of X".
-- X used to be raw storage, which only worked because storage never left the
-- stock 1k: late game that 1k pool filled and drained within a single AI tick
-- and every threshold flapped. Now that the AI builds real storage (see
-- b_construction), raw storage would be wrong in the other direction: with
-- 100k storage, "50% full" would mean hoarding 50,000 before expanding.
-- So thresholds are measured against the SIGNAL POOL instead:
--     pool = SIGNAL_POOL_SECONDS of current income,
--            never below SIGNAL_POOL_MIN (the stock pool, so early game is
--            exactly what it always was), never above real storage.
-- Until storage is built, pool == storage and nothing changes. Afterward the
-- thresholds scale with throughput while the real bank absorbs the swings.
local SIGNAL_POOL_MIN     = 1000

-- Stall signal. "Is the bank low?" is a poor question: it says nothing about
-- WHY, and it flaps whenever storage is small next to income. The engine also
-- reports how much a team is TRYING to spend each second (pull). A team is
-- stalling on a resource when it wants more than it earns AND has no bank
-- left to cover the difference:
--     raw stall = 1 - income / pull      (0 = fine, 0.5 = wants double its income)
-- smoothed over a few AI ticks. Published per team in ctx.stall and the tick:
--     e = energy stall, m = metal stall,
--     v = the combined figure factory pausing runs on: max(e, m * STALL_METAL_WEIGHT)
-- Metal is discounted on purpose. Wanting more metal than you earn is the
-- normal state of an AI that spends everything; it only means builds run
-- slower, and total output is the same either way. Energy is different: its
-- cost climbs steeply with tech, so an energy stall can actually be fixed by
-- building cheaper. Hence: cheaper-unit bias and cancelling key off ENERGY
-- stall alone; pausing factories keys off v. See b_throttle.lua and
-- b_construction.lua.
local STALL_STOCK_SECONDS = 3      -- "no bank left" = stock below this many seconds of demand
local STALL_SMOOTH        = 0.35   -- blend factor per AI tick
local STALL_ON            = 0.20   -- stalling: start shedding demand
local STALL_OFF           = 0.08   -- recovered: start restoring it
local STALL_HARD          = 0.45   -- badly stalling: cancel barely-started expensive builds
local STALL_METAL_WEIGHT  = 0.5    -- metal stall counts half toward v (0.2 = wants ~1.7x its metal income)
local function StallStep(prev, current, pull, income)
	local raw = 0
	if pull and pull > 0 and pull > income and current < pull * STALL_STOCK_SECONDS then
		raw = 1 - income / pull
	end
	return prev + (raw - prev) * STALL_SMOOTH
end

-- Commander lost. Teching up IS the commander morphing, so a team whose
-- commander is dead is locked at its tech level for good. ctx.comm.lost flags
-- that (after a grace period, since a morph swaps the commander unit and a
-- replacement can be built); b_upgrades and b_economy then pour Research
-- Points into weapons and armor instead of saving them for a morph.
local COMM_LOST_GRACE     = 300    -- frames without a commander before the team counts as having lost it (~10s)
local commSeen            = {}     -- [teamID] = true once the team has had a commander
local commGoneAt          = {}     -- [teamID] = frame the commander was first found missing

-- Decision trace. Every TRACE_INTERVAL frames each AI team publishes one
-- string to the team rules param "simpleai_trace": its tech level, the
-- signals the construction chain keys off, and how many times each priority
-- rung took a builder since the last publish. The game recorder widget
-- (LuaUI/Widgets/dbg_game_recorder.lua) reads it when spectating or watching
-- a replay, which is how a recorded game shows WHY a team did what it did.
-- It is one string per team per 10s and changes nothing the AI does.
local TRACE_INTERVAL      = 300
local traceLast           = {}    -- [teamID] = frame of the last publish
local traceAttacked       = {}    -- [teamID] = AI ticks spent under attack since then
local traceTicks          = {}    -- [teamID] = AI ticks since then
local traceKeys           = {}    -- scratch
local SIGNAL_POOL_SECONDS = 20
local function SignalPool(storage, income)
	local pool = (income or 0) * SIGNAL_POOL_SECONDS
	if pool < SIGNAL_POOL_MIN then pool = SIGNAL_POOL_MIN end
	if pool > storage then pool = storage end
	return pool
end

-- Resource floor (the NeverStall mechanism, internalized). Every 30 frames a
-- covered team's metal/energy stock is topped up to NEVERSTALL_FLOOR of a
-- FIXED base (NEVERSTALL_BASE, the stock 1k pool), i.e. to 150, exactly what
-- it was before the AI built storage. It must not scale with storage OR with
-- the signal pool: a recorded game showed the pool-scaled version handing a
-- 7,000 E/s team an 18,000 E floor every second, so it spent 2.5x the energy
-- it produced. Coverage:
--   * AdaptiveAI teams: ALWAYS. Stalling must not exist as a variable for the
--     difficulty controller -- throughput is steered by build speed instead.
--   * plain SimpleAI/Defender/Constructor teams: only when the ai_neverstall
--     modoption is enabled (same gate the standalone gadget used).
-- The standalone ai_neverstall.lua gadget now SKIPS all teams handled here and
-- remains only as the backstop for other AI types (e.g. SurvivalAI games).
local NEVERSTALL_FLOOR = 0.15
local NEVERSTALL_BASE  = 1000   -- floor = FLOOR * min(storage, BASE); raise BASE to make the AI cheat harder
local neverstallOn = (Spring.GetModOptions().ai_neverstall or "disabled") ~= "disabled"

-- Factory unit names that are air or sea plants.
-- Everything else that is a factory is treated as a land factory.
local AIR_FACTORY_NAMES = {
	fedairplant = true,
	lozairplant = true,
}
local SEA_FACTORY_NAMES = {
	fedseaplant = true,
	lozseaplant = true,
}

-- ============================================================
-- PER-TEAM STATE
-- ============================================================

-- ============================================================
-- SHARED AI CONTEXT (ctx)
-- ALL shared mutable state lives in this one object. It is the interface
-- future behavior modules will receive (stage 3 of the modular split):
-- a module sees ONLY ctx, never this file's locals.
--
-- Transitional pattern: the monolith's existing code keeps its historical
-- names via the alias block below -- each alias is the SAME table object as
-- its ctx field, so both names always agree. As behaviors are extracted,
-- their code moves to modules and adopts the ctx names; the corresponding
-- aliases then disappear. Do NOT reassign any of these tables wholesale
-- (always mutate keys), or alias and ctx would silently diverge.
-- ============================================================
local ctx = {
	-- ---- identity ----
	aiTeams      = {},   -- array of AI team IDs (count kept in a core local)
	isAITeam     = {},   -- [teamID] = true; O(1) membership for per-event callins
	adaptiveTeams = {},  -- [teamID] = true for AdaptiveAI teams (b_adaptive keys off this)

	-- ---- unit classification (defID-keyed, immutable after load) ----
	IsCommander = {}, IsFactory = {}, IsConstructor = {}, IsExtractor = {},
	IsCombat    = {}, IsConverter = {}, IsTurret = {}, IsAir = {},
	IsAATurret  = {},   -- [defID] = true: turret with a dedicated AA weapon (onlyTargetCategory "AIR")
	ShieldMax   = {},   -- [defID] = shield capacity (Loz personal shields)
	BoostCost   = {},   -- [defID] = Build Boost RP cost (factories only)
	commanderDefs = {}, factoryDefs = {}, constructorDefs = {},
	extractorDefs = {}, undefinedDefs = {},

	-- ---- decision trace (see TRACE_INTERVAL) ----
	trace = {},          -- [teamID] = { [rungKey] = count } since the last publish

	-- ---- stall signal (see StallStep; all keyed by teamID, 0..1) ----
	stall = { m = {}, e = {}, v = {}, paused = {} },   -- paused = factories on WAIT (b_throttle)

	-- ---- reclaim field (b_construction) ----
	reclaim = { near = {} },   -- [teamID] = reclaimable metal within reach of home

	-- ---- per-team persistent state (all keyed by teamID) ----
	counters = {
		factories = {}, factoriesByDef = {}, mexes = {}, constructors = {},
		army = {}, converters = {}, turrets = {}, landFactories = {},
		aaTurrets = {},
	},
	pacing = {
		factoryDelay = {}, constructorDelay = {},
		lastConStart = {}, lastFacStart = {},
		lastLaunch = {}, lastTargetScan = {}, lastBoost = {},
	},
	squad   = { muster = {}, state = {}, attackWave = {}, attackTimer = {} },
	intel   = { underAttack = {}, enemyBase = {}, baseThreat = {}, airThreat = {} },
	comm    = { retreating = {}, retreatPos = {}, id = {},
	            lost = {} },   -- lost[teamID] = true once the team has had no commander for COMM_LOST_GRACE
	techLevel  = {},   -- 0-4 per team
	faction    = {},   -- "fed" | "loz" | "neutral" per team
	buildLists = {},   -- [teamID][techLevel][category] = {defID, ...}

	-- ---- per-unit state ----
	retreat = {},      -- [unitID] = frame retreat began (hysteresis machine)

	-- ---- per-team-tick snapshot ----
	-- Rebuilt at the top of every AI team tick; modules read, core writes.
	tick = {},
}

-- ---- transitional aliases (same objects as ctx fields) ----
local SimpleAITeamIDs             = ctx.aiTeams
local SimpleAITeamIDsCount        = 0
local IsAITeamID                  = ctx.isAITeam
local AdaptiveTeams               = ctx.adaptiveTeams

-- classic counters (kept as globals for compatibility, now backed by ctx)
SimpleFactoriesCount   = ctx.counters.factories
SimpleFactories        = ctx.counters.factoriesByDef
SimpleT1Mexes          = ctx.counters.mexes
SimpleConstructorCount = ctx.counters.constructors
SimpleFactoryDelay     = ctx.pacing.factoryDelay
SimpleConstructorDelay = ctx.pacing.constructorDelay
SimpleLastConStart     = ctx.pacing.lastConStart   -- frame the team last STARTED a constructor (rate limit)
SimpleLastFacStart     = ctx.pacing.lastFacStart   -- frame the team last STARTED a factory (rate limit)

-- enhanced state
local SimpleArmyCount      = ctx.counters.army
local SimpleAttackWave     = ctx.squad.attackWave
local SimpleAttackTimer    = ctx.squad.attackTimer
local SimpleUnderAttack    = ctx.intel.underAttack
local SimpleEnemyBasePos   = ctx.intel.enemyBase
local SimpleConverterCount = ctx.counters.converters
local SimpleTurretCount    = ctx.counters.turrets      -- total defensive turrets per team
local SimpleAATurretCount  = ctx.counters.aaTurrets    -- dedicated AA turrets per team (subset of turrets)
local SimpleLandFacCount   = ctx.counters.landFactories -- land-only factory count per team

-- Air-threat evidence: [teamID] = frame of the last enemy-aircraft sighting
-- (base scan in b_defense) or air-delivered damage (UnitDamaged below).
-- Construction reads this timestamp and raises AA turrets while it is fresh.
local SimpleAirThreat      = ctx.intel.airThreat

-- Strike team / staging system
local SimpleMusterPos      = ctx.squad.muster       -- rally point where ground units assemble
local SimpleSquadState     = ctx.squad.state        -- "mustering" | "attacking" per team
local SimpleLastLaunch     = ctx.pacing.lastLaunch  -- frame of last wave launch (cooldown)
local SimpleLastTargetScan = ctx.pacing.lastTargetScan -- frame of last weak-point target scan

-- Commander retreat state machine
local SimpleCommRetreating = ctx.comm.retreating    -- bool: is the commander currently fleeing?
local SimpleCommRetreatPos = ctx.comm.retreatPos    -- committed haven {x,y,z} for the current retreat

-- Base defense
local SimpleBaseThreat     = ctx.intel.baseThreat   -- nearest enemy inside the base {x,y,z,uid} or nil

-- Retreat hysteresis: per-UNIT (not per-team). [unitID] = frame retreat began.
-- Cleared on exit conditions and unconditionally in UnitDestroyed (unitIDs are
-- recycled by the engine, so a stale entry could tag a brand-new unit).
local SimpleRetreatState   = ctx.retreat

-- Build Boost pacing: [teamID] = frame of last boost order.
local SimpleLastBoost      = ctx.pacing.lastBoost

-- tech / faction state
local TeamTechLevel  = ctx.techLevel   -- 0-4 per team
local TeamFaction    = ctx.faction     -- "fed" | "loz" | "neutral" per team
local TeamCommID     = ctx.comm.id     -- commander unitID per team

-- Per-team, per-tech, per-category build lists.
-- TeamBuildLists[teamID][techLevel][category] = {defID, ...}
local TeamBuildLists = ctx.buildLists

-- ============================================================
-- FACTION CONSTANTS
-- ============================================================
local FACTION_FED = "Federation of Kala"
local FACTION_LOZ = "Loz Alliance"

-- ============================================================
-- HELPERS (available before IsSyncedCode)
-- ============================================================

local function TechStrToNum(s)
	if s == "tech0" then return 0
	elseif s == "tech1" then return 1
	elseif s == "tech2" then return 2
	elseif s == "tech3" then return 3
	elseif s == "tech4" then return 4
	end
	return 0
end

-- ============================================================
-- INITIALISE TEAM RECORDS
-- ============================================================
for i = 1, #teams do
	local teamID = teams[i]
	local luaAI  = Spring.GetTeamLuaAI(teamID)
	local isAdaptive = luaAI ~= nil and luaAI ~= ""
			and string.sub(luaAI, 1, 10) == 'AdaptiveAI'
	if luaAI and luaAI ~= "" and (
			isAdaptive or
					string.sub(luaAI, 1, 8)  == 'SimpleAI' or
					string.sub(luaAI, 1, 16) == 'SimpleDefenderAI' or
					string.sub(luaAI, 1, 19) == 'SimpleConstructorAI'
	) then
		enabled = true
		if isAdaptive then
			AdaptiveTeams[teamID] = true
		end
		SimpleAITeamIDsCount = SimpleAITeamIDsCount + 1
		SimpleAITeamIDs[SimpleAITeamIDsCount] = teamID
		IsAITeamID[teamID] = true

		SimpleFactoriesCount[teamID]   = 0
		SimpleFactories[teamID]        = {}
		SimpleT1Mexes[teamID]          = 0
		SimpleConstructorCount[teamID] = 0
		SimpleArmyCount[teamID]        = 0
		SimpleAttackTimer[teamID]      = WAVE_INTERVAL
		SimpleUnderAttack[teamID]      = false
		SimpleEnemyBasePos[teamID]     = nil
		SimpleConverterCount[teamID]   = 0
		SimpleTurretCount[teamID]      = 0
		SimpleAATurretCount[teamID]    = 0
		SimpleLandFacCount[teamID]     = 0
		SimpleAirThreat[teamID]        = nil
		TeamTechLevel[teamID]          = 1   -- game starts at tech1
		ctx.trace[teamID]              = {}
		ctx.stall.m[teamID], ctx.stall.e[teamID] = 0, 0
		ctx.stall.v[teamID], ctx.stall.paused[teamID] = 0, 0
		TeamFaction[teamID]            = nil
		TeamCommID[teamID]             = nil
		-- Behavior-owned per-team state (squad, pacing seeds, comm retreat,
		-- baseThreat, boost timer) is seeded by each module's TeamInit hook,
		-- invoked right after the behavior modules load below.
		TeamBuildLists[teamID]         = {}
		for t = 0, 4 do
			TeamBuildLists[teamID][t] = {
				extractor   = {},
				generator   = {},
				converter   = {},
				turret      = {},
				supply      = {},
				storage     = {},
				factory     = {},
				constructor = {},
				combat      = {},
				building    = {},
			}
		end
	end
end

-- ============================================================
-- GADGET INFO
-- ============================================================
function gadget:GetInfo()
	return {
		name    = "SimpleAI",
		desc    = "Tech-aware SimpleAI + AdaptiveAI (real-time difficulty) with faction build lists and economy teching goals",
		author  = "Damgam / Enhanced v3",
		date    = "2024",
		layer   = -100,
		enabled = enabled,
	}
end

-- ============================================================
-- GLOBAL UNIT-TYPE IDENTIFICATION SETS
-- (used to classify live units by role; not for build orders)
-- ============================================================
local IsCommander   = ctx.IsCommander
local IsFactory     = ctx.IsFactory
local IsConstructor = ctx.IsConstructor
local IsExtractor   = ctx.IsExtractor
local IsCombat      = ctx.IsCombat
local IsConverter   = ctx.IsConverter
local IsTurret      = ctx.IsTurret
local IsAir         = ctx.IsAir   -- canFly units get independent orders, not squad staging
local IsAATurret    = ctx.IsAATurret

-- A weapon defined with onlyTargetCategory = "AIR" appears in the Lua
-- UnitDefs proxy as weapons[i].onlyTargets = { air = true } (the engine
-- lowercases category names). Requiring "air" to be the ONLY key keeps the
-- test exact -- it cannot false-positive on whatever the engine reports for
-- unrestricted weapons, nor on mixed "AIR GROUND" restrictions.
local function HasAAOnlyWeapon(unitDef)
	local weps = unitDef.weapons
	if not weps then return false end
	for i = 1, #weps do
		local ot = weps[i].onlyTargets
		if ot and ot.air and next(ot, next(ot)) == nil then
			return true
		end
	end
	return false
end

-- Also keep plain lists for InList calls that need them
local SimpleCommanderDefs     = ctx.commanderDefs
local SimpleFactoriesDefs     = ctx.factoryDefs
local SimpleConstructorDefs   = ctx.constructorDefs
local SimpleExtractorDefs     = ctx.extractorDefs
local SimpleUndefinedUnitDefs = ctx.undefinedDefs

for unitDefID, unitDef in pairs(UnitDefs) do
	local cp = unitDef.customParams or {}

	if cp.unitrole == "Commander" then
		IsCommander[unitDefID] = true
		SimpleCommanderDefs[#SimpleCommanderDefs + 1] = unitDefID

	elseif unitDef.isFactory and #unitDef.buildOptions > 0 then
		IsFactory[unitDefID] = true
		SimpleFactoriesDefs[#SimpleFactoriesDefs + 1] = unitDefID

	elseif (unitDef.canMove and unitDef.isBuilder and #unitDef.buildOptions > 0)
			or (cp.unittype == "mobile" and cp.unitrole == "Builder")
			or (unitDef.isBuilder and #unitDef.buildOptions > 0 and not unitDef.isFactory) then
		IsConstructor[unitDefID] = true
		SimpleConstructorDefs[#SimpleConstructorDefs + 1] = unitDefID

	elseif unitDef.extractsMetal > 0 or cp.metal_extractor then
		IsExtractor[unitDefID] = true
		SimpleExtractorDefs[#SimpleExtractorDefs + 1] = unitDefID

	elseif cp.energyconv_capacity and cp.energyconv_efficiency then
		IsConverter[unitDefID] = true

	elseif unitDef.isBuilding and unitDef.weapons and #unitDef.weapons > 0
			and cp.unitrole ~= "Support Building" then
		-- (a "Support Building" with a weapon entry is a shield generator or
		-- similar: its weapon is the shield. It is not a turret and must not
		-- be built, counted or placed forward as one.)
		IsTurret[unitDefID] = true
		if HasAAOnlyWeapon(unitDef) then
			IsAATurret[unitDefID] = true
		end

	elseif unitDef.canMove and not unitDef.isBuilder and #(unitDef.weapons or {}) > 0 then
		IsCombat[unitDefID] = true
		SimpleUndefinedUnitDefs[#SimpleUndefinedUnitDefs + 1] = unitDefID
		if unitDef.canFly then
			IsAir[unitDefID] = true
		end
	end
end

-- Shield capacity per def (unit_protoss_style_shields.lua). Lets us compute
-- EFFECTIVE hp -- hull + current shield over hull max + shield max -- since
-- GetUnitHealth alone sees only hull and badly misjudges Loz units.
-- Default mirrors the shield gadget's fallback (100).
local ShieldMax = ctx.ShieldMax
-- Build Boost cost per FACTORY def (unit_research_buildboost.lua). Only defs the
-- boost gadget actually configures get an entry, so we never issue dead orders.
-- Default mirrors that gadget's DEF_COST (100).
local BoostCost = ctx.BoostCost
for unitDefID, unitDef in pairs(UnitDefs) do
	local cp = unitDef.customParams or {}
	if cp.isshieldedunit == "1" then
		ShieldMax[unitDefID] = tonumber(cp.shield_max_strength) or 100
	end
	if IsFactory[unitDefID] and (unitDef.buildSpeed or 0) > 0
			and cp.buildboost ~= "false" then
		BoostCost[unitDefID] = tonumber(cp.buildboost_cost) or 100
	end
end

-- ============================================================
-- HELPER LIBRARY (stage 2 of the modular split)
-- All stateless helpers live in luarules/configs/simpleai/lib.lua. They may
-- read ctx and call Spring but never mutate ctx. The cfg table passes the
-- constants they need; the aliases keep this file's call sites unchanged.
-- ============================================================
local sharedCfg = {
	mapsizeX           = mapsizeX,
	mapsizeZ           = mapsizeZ,
	gaiaTeamID         = gaiaTeamID,
	ATTACK_SCAN_R      = ATTACK_SCAN_R,
	ATTACK_DIST_W      = ATTACK_DIST_W,
	COMBAT_ROLE_WEIGHT = COMBAT_ROLE_WEIGHT,
	FACTORY_OVERFLOW   = FACTORY_OVERFLOW,
	SignalPool         = SignalPool,
	STALL_ON           = STALL_ON,
	STALL_OFF          = STALL_OFF,
	STALL_HARD         = STALL_HARD,
	AIR_FACTORY_NAMES  = AIR_FACTORY_NAMES,
	SEA_FACTORY_NAMES  = SEA_FACTORY_NAMES,
}
local lib = VFS.Include("luarules/configs/simpleai/lib.lua")(ctx, sharedCfg)

local EffectiveRatio          = lib.EffectiveRatio
local EstimateEnemyBase       = lib.EstimateEnemyBase

-- ============================================================
-- BEHAVIOR MODULES (stages 3-4 of the modular split)
-- Each behavior file returns function(ctx, lib, cfg, services) -> handler table:
--   name, order            identity; order sequences TeamTicks and unit claims
--   unitFilter(unitDefID)  which unit defs this behavior owns
--   TeamTick(tick)         once per AI team tick, after the core snapshot
--   UnitTick(tick, unitID, unitDefID, hpRatio, ux, uy, uz, unitCmds)
--   BaseDamaged(teamID, frame)   optional event hook
-- `services` is a shared registry: modules register callables for each other
-- (b_construction registers SelectConstructionProject; b_commander consumes
-- it). Consumers resolve services at CALL time, after all modules have
-- loaded, so manifest order is free -- a service is only missing if its
-- provider is absent from this list entirely. TeamTick RUN order is the
-- `order` field. Adding a behavior = one new file + one entry here.
-- ============================================================
local BEHAVIOR_FILES = {
	"luarules/configs/simpleai/behaviors/b_adaptive.lua",      -- order 5; difficulty controller, registers GetKnobs
	"luarules/configs/simpleai/behaviors/b_defense.lua",       -- order 10 (intel first)
	"luarules/configs/simpleai/behaviors/b_construction.lua",  -- order 40; registers services
	"luarules/configs/simpleai/behaviors/b_commander.lua",     -- order 20; consumes services
	"luarules/configs/simpleai/behaviors/b_economy.lua",       -- order 30
	"luarules/configs/simpleai/behaviors/b_throttle.lua",      -- order 32; pauses/cancels factory work while stalling
	"luarules/configs/simpleai/behaviors/b_upgrades.lua",      -- order 35
	"luarules/configs/simpleai/behaviors/b_combat.lua",        -- order 50
}

local services  = {}
local behaviors = {}
do
	for i = 1, #BEHAVIOR_FILES do
		behaviors[#behaviors + 1] = VFS.Include(BEHAVIOR_FILES[i])(ctx, lib, sharedCfg, services)
	end
	table.sort(behaviors, function(a, b)
		return (a.order or 100) < (b.order or 100)
	end)
	-- Seed behavior-owned per-team state (pacing timers, squad state, ...).
	for bi = 1, #behaviors do
		local b = behaviors[bi]
		if b.TeamInit then
			for ti = 1, #ctx.aiTeams do
				b.TeamInit(ctx.aiTeams[ti])
			end
		end
	end
end

-- First behavior (by order) whose unitFilter claims a def owns ALL units of
-- that def; cached per defID. false = explicitly unclaimed (core legacy path).
local unitOwnerCache = {}
local function OwnerOf(unitDefID)
	local owner = unitOwnerCache[unitDefID]
	if owner == nil then
		owner = false
		for i = 1, #behaviors do
			local b = behaviors[i]
			if b.unitFilter and b.unitFilter(unitDefID) then
				owner = b
				break
			end
		end
		unitOwnerCache[unitDefID] = owner
	end
	return owner
end

-- ============================================================
-- BUILD LIST POPULATION
-- Called once per team when faction is first detected, and again
-- whenever the team's tech level increases.
-- Scans all UnitDefs, filters by faction and requiretech,
-- and sorts into per-tech, per-category buckets.
-- ============================================================
local function PopulateBuildLists(teamID, faction)
	local lists = TeamBuildLists[teamID]

	-- Reset all buckets
	for t = 0, 4 do
		for _, cat in ipairs({
			                     "extractor","generator","converter","turret",
			                     "supply","storage","factory","constructor","combat","building"
		                     }) do
			lists[t][cat] = {}
		end
	end

	for unitDefID, unitDef in pairs(UnitDefs) do
		local cp = unitDef.customParams or {}

		-- Faction filter
		local fn = cp.factionname
		if fn == FACTION_FED and faction ~= "fed" then
			-- skip Federation units for Loz teams
		elseif fn == FACTION_LOZ and faction ~= "loz" then
			-- skip Loz units for Federation teams
		else
			local reqTech = TechStrToNum(cp.requiretech or "tech0")
			local cat     = nil

			-- Skip commanders (handled separately)
			if cp.unitrole == "Commander" then
				cat = nil

			elseif unitDef.extractsMetal > 0 or cp.metal_extractor then
				cat = "extractor"

			elseif (unitDef.energyMake and unitDef.energyMake > 19
					and (not unitDef.energyUpkeep or unitDef.energyUpkeep < 10))
					or (unitDef.windGenerator and unitDef.windGenerator > 0 and wind > 10)
					or (unitDef.tidalGenerator and unitDef.tidalGenerator > 0)
					or cp.solar
					or cp.simpleaiunittype == "energygenerator" then
				cat = "generator"

			elseif cp.energyconv_capacity and cp.energyconv_efficiency then
				cat = "converter"

			elseif cp.simpleaiunittype == "supplydepot" then
				cat = "supply"

			elseif cp.simpleaiunittype == "storage" then
				cat = "storage"

			elseif unitDef.isFactory and unitDef.buildOptions and #unitDef.buildOptions > 0 then
				cat = "factory"

			elseif (unitDef.canMove and unitDef.isBuilder
					and unitDef.buildOptions and #unitDef.buildOptions > 0)
					or (cp.unittype == "mobile" and cp.unitrole == "Builder")
					or (unitDef.isBuilder and unitDef.buildOptions
					and #unitDef.buildOptions > 0 and not unitDef.isFactory) then
				cat = "constructor"

			elseif unitDef.isBuilding and unitDef.weapons and #unitDef.weapons > 0
					and cp.unitrole ~= "Support Building" then
				cat = "turret"

			elseif unitDef.isBuilding then
				-- everything else that stands still, armed "Support Building"s
				-- (shield generators) included
				cat = "building"

			elseif unitDef.canMove and not unitDef.isBuilder
					and unitDef.weapons and #unitDef.weapons > 0 then
				cat = "combat"
			end

			if cat then
				local bucket = lists[reqTech][cat]
				if bucket then
					bucket[#bucket + 1] = unitDefID
				end
			end
		end
	end
end

-- ============================================================
-- LIFECYCLE
-- ============================================================
function gadget:GameOver()
	gadgetHandler:RemoveGadget(self)
end

if gadgetHandler:IsSyncedCode() then

	function gadget:GameFrame(n)

		-- Resource floor (NeverStall, internalized -- see NEVERSTALL_FLOOR
		-- above for the coverage rules). Replaces the old 30s lump-injection
		-- cheat: continuous, invisible, and identical to what the standalone
		-- gadget did. Frame offset 27 keeps it off the %15==0 AI-tick frames.
		if n % 30 == 27 then
			for j = 1, SimpleAITeamIDsCount do
				local teamID = SimpleAITeamIDs[j]
				if AdaptiveTeams[teamID] or neverstallOn then
					local mc, ms = Spring.GetTeamResources(teamID, "metal")
					local ec, es = Spring.GetTeamResources(teamID, "energy")
					if mc then
						local mFloor = math.min(ms, NEVERSTALL_BASE) * NEVERSTALL_FLOOR
						if mc < mFloor then
							Spring.SetTeamResource(teamID, "m", mFloor)
						end
					end
					if ec then
						local eFloor = math.min(es, NEVERSTALL_BASE) * NEVERSTALL_FLOOR
						if ec < eFloor then
							Spring.SetTeamResource(teamID, "e", eFloor)
						end
					end
				end
			end
		end

		-- Update enemy base estimate every ~20s
		if n % 1200 == 0 then
			for i = 1, SimpleAITeamIDsCount do
				SimpleEnemyBasePos[SimpleAITeamIDs[i]] =
				EstimateEnemyBase(SimpleAITeamIDs[i])
			end
		end

		-- Main per-unit loop (staggered across teams)
		if n % 15 == 0 then
			for i = 1, SimpleAITeamIDsCount do
				if n % (15 * SimpleAITeamIDsCount) == 15 * (i - 1) then

					local teamID = SimpleAITeamIDs[i]
					local _, _, isDead, _, _, allyTeamID = Spring.GetTeamInfo(teamID)
					local mcurrent, mstorage, mpull, mincome = Spring.GetTeamResources(teamID, "metal")
					local ecurrent, estorage, epull, eincome = Spring.GetTeamResources(teamID, "energy")
					local units    = Spring.GetTeamUnits(teamID)
					local allunits = Spring.GetAllUnits()
					local luaAI    = Spring.GetTeamLuaAI(teamID)

					-- ---- ctx.tick: the per-team-tick snapshot ----
					-- This is the read-only interface behavior modules consume
					-- (stage 3): the core computes each value ONCE per tick and
					-- modules must never rescan for them. Filled progressively
					-- below as each value is derived.
					local tick     = ctx.tick
					tick.frame     = n
					tick.teamID    = teamID
					tick.allyTeamID = allyTeamID
					tick.units     = units
					tick.allUnits  = allunits
					tick.mCur, tick.mStor, tick.mInc = mcurrent, mstorage, mincome
					tick.eCur, tick.eStor, tick.eInc = ecurrent, estorage, eincome
					-- Signal pools (see SignalPool above): the denominators for
					-- every stock-ratio test. Equal to raw storage until the AI
					-- has built storage beyond the stock pool.
					local mpool = SignalPool(mstorage, mincome)
					local epool = SignalPool(estorage, eincome)
					tick.mPool, tick.ePool = mpool, epool
					tick.overflowing = mstorage > 0 and estorage > 0
							and mcurrent > mpool * FACTORY_OVERFLOW
							and ecurrent > epool * FACTORY_OVERFLOW
					tick.luaAI = luaAI

					-- Commander lost? (see COMM_LOST_GRACE)
					if TeamCommID[teamID] then
						commSeen[teamID], commGoneAt[teamID] = true, nil
						ctx.comm.lost[teamID] = false
					elseif commSeen[teamID] then
						commGoneAt[teamID] = commGoneAt[teamID] or n
						if n - commGoneAt[teamID] >= COMM_LOST_GRACE then
							ctx.comm.lost[teamID] = true
						end
					end

					-- Stall signal (see StallStep above).
					local stall  = ctx.stall
					local mStall = StallStep(stall.m[teamID] or 0, mcurrent, mpull, mincome)
					local eStall = StallStep(stall.e[teamID] or 0, ecurrent, epull, eincome)
					stall.m[teamID], stall.e[teamID] = mStall, eStall
					local mWeighted = mStall * STALL_METAL_WEIGHT
					stall.v[teamID] = (mWeighted > eStall) and mWeighted or eStall
					tick.mStall, tick.eStall, tick.stall = mStall, eStall, stall.v[teamID]

					-- ---- Behavior TeamTicks ----
					-- Core intel (baseThreat, resources) is in tick; behaviors
					-- run in `order` sequence. Combat computes the muster point,
					-- the ground census, and squad transitions here, writing
					-- tick.muster / tick.atMuster / tick.readyGround for the
					-- per-unit loop below.
					for bi = 1, #behaviors do
						local b = behaviors[bi]
						if b.TeamTick then b.TeamTick(tick) end
					end

					-- Per-unit decisions
					for k = 1, #units do
						local unitID    = units[k]
						local unitDefID = Spring.GetUnitDefID(unitID)
						local unitHealth, unitMaxHealth = Spring.GetUnitHealth(unitID)

						if unitDefID and unitHealth then
							-- EFFECTIVE hp: hull + personal shield (Loz) over the
							-- combined pool. All retreat/flee thresholds below key
							-- off this, so a Loz unit with a healthy shield is not
							-- treated as wounded just because its hull is scratched.
							local hpRatio    = EffectiveRatio(unitID, unitDefID,
							                                  unitHealth, unitMaxHealth)
							local ux, uy, uz = Spring.GetUnitPosition(unitID)
							local unitCmds   = Spring.GetCommandQueue(unitID, 0)

							-- ======== BEHAVIOR DISPATCH ========
							-- Every AI-driven unit class is claimed by a behavior
							-- (commander, construction, combat); unclaimed defs
							-- (plain buildings, dummies) simply idle.
							local owner = OwnerOf(unitDefID)
							if owner and owner.UnitTick then
								owner.UnitTick(tick, unitID, unitDefID, hpRatio,
								               ux, uy, uz, unitCmds)
							end

						end -- if unitDefID and unitHealth
					end -- for each unit

					-- ---- Decision trace publish (see TRACE_INTERVAL) ----
					traceTicks[teamID] = (traceTicks[teamID] or 0) + 1
					if SimpleUnderAttack[teamID] then
						traceAttacked[teamID] = (traceAttacked[teamID] or 0) + 1
					end
					if n - (traceLast[teamID] or 0) >= TRACE_INTERVAL then
						local tally = ctx.trace[teamID]
						local nk = 0
						for key in pairs(tally) do nk = nk + 1; traceKeys[nk] = key end
						for k = nk + 1, #traceKeys do traceKeys[k] = nil end
						table.sort(traceKeys)
						for k = 1, nk do
							local key = traceKeys[k]
							traceKeys[k] = key .. ":" .. tally[key]
							tally[key] = nil
						end
						Spring.SetTeamRulesParam(teamID, "simpleai_trace", string.format(
							"f=%d;ai=%s;tech=%d;mpool=%d;epool=%d;ms=%.2f;es=%.2f;paused=%d;rec=%d;nocomm=%d;ua=%d/%d;fac=%d;con=%d;mex=%d;tur=%d;army=%d;r=%s",
							n, luaAI or "?", TeamTechLevel[teamID] or 1, mpool, epool,
							mStall, eStall, ctx.stall.paused[teamID] or 0,
							ctx.reclaim.near[teamID] or 0,
							ctx.comm.lost[teamID] and 1 or 0,
							traceAttacked[teamID] or 0, traceTicks[teamID] or 0,
							SimpleFactoriesCount[teamID] or 0, SimpleConstructorCount[teamID] or 0,
							SimpleT1Mexes[teamID] or 0, SimpleTurretCount[teamID] or 0,
							SimpleArmyCount[teamID] or 0,
							table.concat(traceKeys, ",")), { private = true })
						traceLast[teamID], traceAttacked[teamID], traceTicks[teamID] = n, 0, 0
					end

					SimpleUnderAttack[teamID] = false

				end
			end
		end -- n%15
	end

	-- ============================================================
	-- COUNTER BOOKKEEPING
	-- Units enter a team by being BUILT or GIVEN (share menu) and leave
	-- by DYING or being TAKEN. All four paths must move the same counters,
	-- or the caps (constructors, factories, turrets, converters, ...) drift
	-- permanently the first time a unit is shared to or from an AI team.
	-- ============================================================
	local commUnits = {}   -- [teamID] = { [unitID] = true } every commander the team holds
	local function RegisterUnit(unitID, unitDefID, unitTeam)
		-- Faction detection also runs here so an AI team that RECEIVES its
		-- first commander (rather than starting with one) gets build lists.
		if IsCommander[unitDefID] and TeamFaction[unitTeam] == nil then
			local cp = UnitDefs[unitDefID].customParams or {}
			local fn = cp.factionname or ""
			if fn == FACTION_FED then
				TeamFaction[unitTeam] = "fed"
			elseif fn == FACTION_LOZ then
				TeamFaction[unitTeam] = "loz"
			else
				TeamFaction[unitTeam] = "neutral"
			end
			PopulateBuildLists(unitTeam, TeamFaction[unitTeam])
		end
		-- Track EVERY commander the team holds, not just its first. A morph
		-- replaces the commander with a new unit; the ID used to be recorded
		-- only for the first one, so after the first morph the team looked
		-- commander-less forever.
		if IsCommander[unitDefID] then
			local set = commUnits[unitTeam]
			if not set then set = {}; commUnits[unitTeam] = set end
			set[unitID] = true
			TeamCommID[unitTeam] = unitID
		end

		if IsFactory[unitDefID] then
			SimpleFactoriesCount[unitTeam] = SimpleFactoriesCount[unitTeam] + 1
			SimpleFactories[unitTeam][unitDefID] =
			(SimpleFactories[unitTeam][unitDefID] or 0) + 1
			local uname = UnitDefs[unitDefID] and UnitDefs[unitDefID].name
			if not AIR_FACTORY_NAMES[uname] and not SEA_FACTORY_NAMES[uname] then
				SimpleLandFacCount[unitTeam] = (SimpleLandFacCount[unitTeam] or 0) + 1
			end
		end
		if IsExtractor[unitDefID] then
			SimpleT1Mexes[unitTeam] = SimpleT1Mexes[unitTeam] + 1
		end
		if IsConstructor[unitDefID] then
			SimpleConstructorCount[unitTeam] = SimpleConstructorCount[unitTeam] + 1
		end
		if IsCombat[unitDefID] then
			SimpleArmyCount[unitTeam] = (SimpleArmyCount[unitTeam] or 0) + 1
		end
		if IsConverter[unitDefID] then
			SimpleConverterCount[unitTeam] = (SimpleConverterCount[unitTeam] or 0) + 1
		end
		if IsTurret[unitDefID] then
			SimpleTurretCount[unitTeam] = (SimpleTurretCount[unitTeam] or 0) + 1
			if IsAATurret[unitDefID] then
				SimpleAATurretCount[unitTeam] = (SimpleAATurretCount[unitTeam] or 0) + 1
			end
		end
	end

	-- ============================================================
	-- UNIT CREATED
	-- ============================================================
	function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
		if IsAITeamID[unitTeam] then
			RegisterUnit(unitID, unitDefID, unitTeam)
		end
	end

	-- ============================================================
	-- UNIT FINISHED
	-- Mirrors ai_Commander_AutoUpgrade: read techlevel from
	-- commander customparams after each morph completes.
	-- ============================================================
	function gadget:UnitFinished(unitID, unitDefID, unitTeam)
		if not TeamBuildLists[unitTeam] then return end
		-- Behavior hook: b_adaptive stamps its build-speed multiplier onto
		-- freshly finished builders here.
		for i = 1, #behaviors do
			local b = behaviors[i]
			if b.UnitFinished then b.UnitFinished(unitID, unitDefID, unitTeam) end
		end
		local cp = UnitDefs[unitDefID] and (UnitDefs[unitDefID].customParams or {})
		if not cp then return end
		if cp.unitrole == "Commander" then
			local newTech = TechStrToNum(cp.techlevel or "tech1")
			local oldTech = TeamTechLevel[unitTeam] or 1
			TeamTechLevel[unitTeam] = newTech
			if newTech > oldTech and TeamFaction[unitTeam] then
				PopulateBuildLists(unitTeam, TeamFaction[unitTeam])
			end
		end
	end

	local function UnregisterUnit(unitID, unitDefID, unitTeam)
		if IsFactory[unitDefID] then
			SimpleFactoriesCount[unitTeam] =
			math.max(0, SimpleFactoriesCount[unitTeam] - 1)
			SimpleFactories[unitTeam][unitDefID] =
			math.max(0, (SimpleFactories[unitTeam][unitDefID] or 1) - 1)
			local uname = UnitDefs[unitDefID] and UnitDefs[unitDefID].name
			if not AIR_FACTORY_NAMES[uname] and not SEA_FACTORY_NAMES[uname] then
				SimpleLandFacCount[unitTeam] =
				math.max(0, (SimpleLandFacCount[unitTeam] or 1) - 1)
			end
		end
		if IsExtractor[unitDefID] then
			SimpleT1Mexes[unitTeam] = math.max(0, SimpleT1Mexes[unitTeam] - 1)
		end
		if IsConstructor[unitDefID] then
			SimpleConstructorCount[unitTeam] =
			math.max(0, SimpleConstructorCount[unitTeam] - 1)
		end
		if IsCombat[unitDefID] then
			SimpleArmyCount[unitTeam] =
			math.max(0, (SimpleArmyCount[unitTeam] or 1) - 1)
		end
		if IsConverter[unitDefID] then
			SimpleConverterCount[unitTeam] =
			math.max(0, (SimpleConverterCount[unitTeam] or 1) - 1)
		end
		if IsTurret[unitDefID] then
			SimpleTurretCount[unitTeam] =
			math.max(0, (SimpleTurretCount[unitTeam] or 1) - 1)
			if IsAATurret[unitDefID] then
				SimpleAATurretCount[unitTeam] =
				math.max(0, (SimpleAATurretCount[unitTeam] or 1) - 1)
			end
		end
		if IsCommander[unitDefID] then
			local set = commUnits[unitTeam]
			if set then set[unitID] = nil end
			if TeamCommID[unitTeam] == unitID then
				-- This commander is gone (died, morphed away, or shared away).
				-- Fall back to another one the team still holds, if any
				-- (lowest ID, so the choice never depends on table order).
				local other
				if set then
					for id in pairs(set) do
						if not other or id < other then other = id end
					end
				end
				TeamCommID[unitTeam] = other
				SimpleCommRetreating[unitTeam] = false
				SimpleCommRetreatPos[unitTeam] = nil
			end
		end
	end

	-- ============================================================
	-- UNIT DESTROYED
	-- ============================================================
	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam,
	                              attackerID, attackerDefID, attackerTeam)
		-- Unconditional: the engine RECYCLES unitIDs, so a stale retreat entry
		-- would tag a brand-new unit as wounded. Clear regardless of team.
		SimpleRetreatState[unitID] = nil
		if IsAITeamID[unitTeam] then
			UnregisterUnit(unitID, unitDefID, unitTeam)
			-- Behavior hook: one of an AI team's units was destroyed.
			-- (b_adaptive accumulates the loss value for its exchange metric.)
			for i = 1, #behaviors do
				local b = behaviors[i]
				if b.UnitLost then b.UnitLost(unitTeam, unitID, unitDefID) end
			end
		end
		-- Behavior hook: an AI team destroyed an ENEMY unit. Same enemy
		-- criteria as UnitDamaged: not self, not gaia, not allied.
		if attackerTeam and IsAITeamID[attackerTeam]
				and attackerTeam ~= unitTeam
				and unitTeam ~= gaiaTeamID
				and not Spring.AreTeamsAllied(attackerTeam, unitTeam) then
			for i = 1, #behaviors do
				local b = behaviors[i]
				if b.UnitKilled then b.UnitKilled(attackerTeam, unitID, unitDefID) end
			end
		end
	end

	-- ============================================================
	-- UNIT GIVEN / TAKEN (share menu, /take, capture)
	-- The engine fires BOTH on a transfer: UnitTaken for the old team,
	-- UnitGiven for the new one -- so each side moves its own counters
	-- exactly once and nothing double-counts.
	-- ============================================================
	function gadget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
		-- unitTeam is the NEW owner
		if IsAITeamID[unitTeam] then
			RegisterUnit(unitID, unitDefID, unitTeam)
			-- Behavior hook: a GIVEN unit is a finished unit -- b_adaptive
			-- stamps its build-speed multiplier so shared builders don't
			-- escape the band.
			for i = 1, #behaviors do
				local b = behaviors[i]
				if b.UnitFinished then b.UnitFinished(unitID, unitDefID, unitTeam) end
			end
		end
	end

	function gadget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
		-- unitTeam is the OLD owner
		if IsAITeamID[unitTeam] then
			UnregisterUnit(unitID, unitDefID, unitTeam)
			-- The AI should not remember a unit it no longer owns; if the unit
			-- comes back later it re-enters retreat on its own merits.
			SimpleRetreatState[unitID] = nil
		end
	end

	-- ============================================================
	-- UNIT DAMAGED
	-- ============================================================
	function gadget:UnitDamaged(unitID, unitDefID, damage, direction,
	                            attackerID, attackerDefID, attackerTeam, isParalyzer)
		if not unitDefID then return end
		local teamID = Spring.GetUnitTeam(unitID)
		if not IsAITeamID[teamID] then return end

		-- Only ENEMY damage counts as being under attack. Self-damage (our own
		-- disruption splash), ally accidents, and gaia debris must not trigger
		-- defensive turret spam, force-launches, or boost surges.
		if not attackerTeam
				or attackerTeam == teamID
				or attackerTeam == gaiaTeamID
				or Spring.AreTeamsAllied(teamID, attackerTeam) then
			return
		end

		-- Enemy AIRCRAFT hitting ANY unit of ours (not just buildings) is
		-- air-threat evidence: stamp the frame so construction raises AA
		-- while the memory is fresh. This is the reliable signal -- it needs
		-- no LOS scan and fires even if the bomber was never spotted coming.
		if attackerDefID and IsAir[attackerDefID] then
			SimpleAirThreat[teamID] = Spring.GetGameFrame()
		end

		if UnitDefs[unitDefID] and UnitDefs[unitDefID].isBuilding then
			SimpleUnderAttack[teamID] = true
			-- Notify behaviors (combat fast-tracks its next wave launch by
			-- clamping the wave cooldown; the clamp itself lives in b_combat).
			local nowF = Spring.GetGameFrame()
			for i = 1, #behaviors do
				local b = behaviors[i]
				if b.BaseDamaged then b.BaseDamaged(teamID, nowF) end
			end
		end
	end

end -- IsSyncedCode
