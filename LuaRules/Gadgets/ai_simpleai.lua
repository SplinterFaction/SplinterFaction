-- ============================================================
-- SimpleAI Enhanced -- based on original by Damgam (2020)
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
}

-- Weak-point attack targeting
local ATTACK_SCAN_R     = 650    -- radius around an enemy building used to tally its defenders
local ATTACK_DIST_W     = 0.10   -- how strongly distance-from-muster penalises a candidate target

local FACTORY_OVERFLOW      = 0.62 -- metal & energy storage fraction that counts as "overflowing"

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
	cheaterTeams = {},   -- array of cheater-AI team IDs

	-- ---- unit classification (defID-keyed, immutable after load) ----
	IsCommander = {}, IsFactory = {}, IsConstructor = {}, IsExtractor = {},
	IsCombat    = {}, IsConverter = {}, IsTurret = {}, IsAir = {},
	ShieldMax   = {},   -- [defID] = shield capacity (Loz personal shields)
	BoostCost   = {},   -- [defID] = Build Boost RP cost (factories only)
	commanderDefs = {}, factoryDefs = {}, constructorDefs = {},
	extractorDefs = {}, undefinedDefs = {},

	-- ---- per-team persistent state (all keyed by teamID) ----
	counters = {
		factories = {}, factoriesByDef = {}, mexes = {}, constructors = {},
		army = {}, converters = {}, turrets = {}, landFactories = {},
	},
	pacing = {
		factoryDelay = {}, constructorDelay = {},
		lastConStart = {}, lastFacStart = {},
		lastLaunch = {}, lastTargetScan = {}, lastBoost = {},
	},
	squad   = { muster = {}, state = {}, attackWave = {}, attackTimer = {} },
	intel   = { underAttack = {}, enemyBase = {}, baseThreat = {} },
	comm    = { retreating = {}, retreatPos = {}, id = {} },
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
local SimpleCheaterAITeamIDs      = ctx.cheaterTeams
local SimpleCheaterAITeamIDsCount = 0

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
local SimpleLandFacCount   = ctx.counters.landFactories -- land-only factory count per team

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
	if luaAI and luaAI ~= "" and (
			string.sub(luaAI, 1, 8)  == 'SimpleAI' or
					string.sub(luaAI, 1, 16) == 'SimpleDefenderAI' or
					string.sub(luaAI, 1, 19) == 'SimpleConstructorAI'
	) then
		enabled = true
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
		SimpleLandFacCount[teamID]     = 0
		TeamTechLevel[teamID]          = 1   -- game starts at tech1
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

		SimpleCheaterAITeamIDsCount = SimpleCheaterAITeamIDsCount + 1
		SimpleCheaterAITeamIDs[SimpleCheaterAITeamIDsCount] = teamID
	end
end

-- ============================================================
-- GADGET INFO
-- ============================================================
function gadget:GetInfo()
	return {
		name    = "SimpleAI",
		desc    = "Tech-aware SimpleAI with faction build lists and economy teching goals",
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

	elseif unitDef.isBuilding and unitDef.weapons and #unitDef.weapons > 0 then
		IsTurret[unitDefID] = true

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
	"luarules/configs/simpleai/behaviors/b_defense.lua",       -- order 10 (intel first)
	"luarules/configs/simpleai/behaviors/b_construction.lua",  -- order 40; registers services
	"luarules/configs/simpleai/behaviors/b_commander.lua",     -- order 20; consumes services
	"luarules/configs/simpleai/behaviors/b_economy.lua",       -- order 30
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

			elseif unitDef.isBuilding and unitDef.weapons and #unitDef.weapons > 0 then
				cat = "turret"

			elseif unitDef.isBuilding and not (unitDef.weapons and #unitDef.weapons > 0) then
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

		-- Cheater resource boost every 30s
		if n % 1800 == 0 then
			for j = 1, SimpleCheaterAITeamIDsCount do
				local teamID = SimpleCheaterAITeamIDs[j]
				local mcurrent, mstorage = Spring.GetTeamResources(teamID, "metal")
				local ecurrent, estorage = Spring.GetTeamResources(teamID, "energy")
				if mcurrent < mstorage * 0.15 then
					Spring.SetTeamResource(teamID, "m", mstorage * 0.40)
				end
				if ecurrent < estorage * 0.15 then
					Spring.SetTeamResource(teamID, "e", estorage * 0.40)
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
					local mcurrent, mstorage, _, mincome = Spring.GetTeamResources(teamID, "metal")
					local ecurrent, estorage, _, eincome = Spring.GetTeamResources(teamID, "energy")
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
					tick.overflowing = mstorage > 0 and estorage > 0
							and mcurrent > mstorage * FACTORY_OVERFLOW
							and ecurrent > estorage * FACTORY_OVERFLOW
					tick.luaAI = luaAI

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
		end
		if IsCommander[unitDefID] and TeamCommID[unitTeam] == unitID then
			-- Commander gone (died OR shared away); allow re-detection later
			TeamCommID[unitTeam] = nil
			SimpleCommRetreating[unitTeam] = false
			SimpleCommRetreatPos[unitTeam] = nil
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
