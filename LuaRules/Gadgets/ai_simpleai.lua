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

local WAVE_INTERVAL     = 3600   -- frames between attack wave launches
local WAVE_MIN_ARMY     = 4      -- minimum combat units before attacking
local WAVE_MUSTER_SIZE  = 4      -- units that must be at muster point to trigger launch
local WAVE_BIG_ARMY     = 9      -- if we have this many ground units, attack even if not fully mustered
local MUSTER_RADIUS     = 600    -- how close a unit must be to count as "at muster"
local RETREAT_HP        = 0.75   -- combat-unit retreat threshold

-- Commander survival
local COMM_RETREAT_HP   = 0.65   -- commander starts running below this HP fraction
local COMM_DANGER_R     = 750    -- enemy within this range counts as "in danger" while retreating
local COMM_HAVEN_REACH  = 250    -- considered "arrived" at a haven within this distance

-- Constructor caps
local CONSTRUCTOR_MAX         = 4   -- max constructors for normal AI teams
local CONSTRUCTOR_MAX_CON_AI  = 12  -- higher cap for dedicated SimpleConstructorAI teams
-- Minimum frames between STARTING any new constructor on a team. Because every
-- factory on a team is evaluated in the same GameFrame tick, without this they
-- all read the same stale count and queue a constructor at once. This rate-limit
-- lets the count catch up so the hard cap is actually respected.
local CON_BUILD_SPACING      = 150  -- ~5s at 30Hz

-- Higher-tier preference. Per-unit build weight scales with (techTier+1)^bias,
-- so advanced units/factories are chosen far more often while lower tiers still appear.
local TECH_UNIT_BIAS    = 1.8    -- combat unit tech preference
local TECH_FAC_BIAS     = 2.4    -- factory tech preference (want advanced plants to unlock advanced units)

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
local ATTACK_RETARGET   = 300    -- frames between weak-point re-scans during an active push

-- Base defense
local BASE_DEFEND_RADIUS = 1600  -- enemy within this range of base centre is an "intruder"
local TURRET_BASE        = 2     -- always want at least this many turrets once a factory exists
local TURRET_PER_FAC     = 1     -- + this many wanted per factory
local TURRET_PER_MEX_DIV = 3     -- + 1 wanted per this many mexes

local MEX_TARGET_EARLY  = 2      -- grab this many mexes before anything else
local MEX_TARGET_MID    = 8      -- expand to this many once economy is running
local MEX_RANGE_EARLY   = 2000   -- mex search radius before base established
local MEX_RANGE_MID     = 5000   -- mex search radius once we have 2+ factories
local CONVERTER_MAX     = 3      -- max energy converters per team
local FACTORY_MAX       = 12      -- max factories per team
local LAND_FAC_MIN      = 3      -- build at least this many land factories before any air/sea
-- Factory build pacing. A flat frame-based limiter (like the constructor one)
-- replaces the old escalating delay, so the Nth factory is no slower to start
-- than the 2nd. When resources are overflowing we build them much faster, since
-- extra production capacity is the best sink for a surplus.
local FACTORY_SPACING       = 90   -- normal min frames between starting factories (~3s)
local FACTORY_SPACING_FLOOD = 45   -- min frames when overflowing (~1.5s)
local FACTORY_OVERFLOW      = 0.62 -- metal & energy storage fraction that counts as "overflowing"
local TURRET_CAP        = 20     -- absolute max turrets to build per team
local WAVE_COOLDOWN     = 1500   -- minimum frames between launches (~50s at 30Hz)

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

-- Income targets required to trigger each tech upgrade.
-- Key = current tech level. Values are the income thresholds to AIM for.
local TECH_INCOME_GOALS = {
	[0] = { m = 10,  e = 170  },
	[1] = { m = 20,  e = 560  },
	[2] = { m = 40,  e = 1040 },
	[3] = { m = 80,  e = 3120 },
}

-- How strongly to bias toward economy when below the tech threshold.
-- 0.5 = balanced: economy prioritised but army still builds.
local TECH_ECONOMY_BIAS = 0.5

-- ============================================================
-- PER-TEAM STATE
-- ============================================================

local SimpleAITeamIDs             = {}
local SimpleAITeamIDsCount        = 0
local SimpleCheaterAITeamIDs      = {}
local SimpleCheaterAITeamIDsCount = 0

-- classic counters (globals for compatibility)
SimpleFactoriesCount   = {}
SimpleFactories        = {}
SimpleT1Mexes          = {}
SimpleConstructorCount = {}
SimpleFactoryDelay     = {}
SimpleConstructorDelay = {}
SimpleLastConStart     = {}   -- frame the team last STARTED a constructor (rate limit)
SimpleLastFacStart     = {}   -- frame the team last STARTED a factory (rate limit)

-- enhanced state
local SimpleArmyCount      = {}
local SimpleAttackWave     = {}
local SimpleAttackTimer    = {}
local SimpleUnderAttack    = {}
local SimpleEnemyBasePos   = {}
local SimpleConverterCount = {}
local SimpleTurretCount    = {}   -- total defensive turrets per team
local SimpleLandFacCount   = {}   -- land-only factory count per team

-- Strike team / staging system
local SimpleMusterPos      = {}   -- rally point where ground units assemble
local SimpleSquadState     = {}   -- "mustering" | "attacking" per team
local SimpleLastLaunch     = {}   -- frame of last wave launch (cooldown)
local SimpleLastTargetScan = {}   -- frame of last weak-point target scan

-- Commander retreat state machine
local SimpleCommRetreating = {}   -- bool: is the commander currently fleeing?
local SimpleCommRetreatPos = {}   -- committed haven {x,y,z} for the current retreat

-- Base defense
local SimpleBaseThreat     = {}   -- nearest enemy inside the base {x,y,z,uid} or nil

-- tech / faction state
local TeamTechLevel  = {}   -- 0-4 per team
local TeamFaction    = {}   -- "fed" | "loz" | "neutral" per team
local TeamCommID     = {}   -- commander unitID per team

-- Per-team, per-tech, per-category build lists.
-- TeamBuildLists[teamID][techLevel][category] = {defID, ...}
local TeamBuildLists = {}

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

		SimpleFactoriesCount[teamID]   = 0
		SimpleFactories[teamID]        = {}
		SimpleT1Mexes[teamID]          = 0
		SimpleConstructorCount[teamID] = 0
		SimpleFactoryDelay[teamID]     = 0
		SimpleConstructorDelay[teamID] = 0
		SimpleLastConStart[teamID]     = -CON_BUILD_SPACING
		SimpleLastFacStart[teamID]     = -FACTORY_SPACING
		SimpleArmyCount[teamID]        = 0
		SimpleAttackWave[teamID]       = nil
		SimpleAttackTimer[teamID]      = WAVE_INTERVAL
		SimpleUnderAttack[teamID]      = false
		SimpleEnemyBasePos[teamID]     = nil
		SimpleConverterCount[teamID]   = 0
		SimpleTurretCount[teamID]      = 0
		SimpleLandFacCount[teamID]     = 0
		SimpleMusterPos[teamID]        = nil   -- set when first factory/commander known
		SimpleSquadState[teamID]       = "mustering"
		SimpleLastLaunch[teamID]       = 0
		SimpleLastTargetScan[teamID]   = 0
		SimpleCommRetreating[teamID]   = false
		SimpleCommRetreatPos[teamID]   = nil
		SimpleBaseThreat[teamID]       = nil
		TeamTechLevel[teamID]          = 1   -- game starts at tech1
		TeamFaction[teamID]            = nil
		TeamCommID[teamID]             = nil
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
local IsCommander   = {}
local IsFactory     = {}
local IsConstructor = {}
local IsExtractor   = {}
local IsCombat      = {}
local IsConverter   = {}
local IsTurret      = {}
local IsAir         = {}   -- canFly units get independent orders, not squad staging

-- Also keep plain lists for InList calls that need them
local SimpleCommanderDefs     = {}
local SimpleFactoriesDefs     = {}
local SimpleConstructorDefs   = {}
local SimpleExtractorDefs     = {}
local SimpleUndefinedUnitDefs = {}

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
-- GET BUILDABLE LIST
-- Returns all defIDs in a category available at or below
-- the team's current tech level.
-- ============================================================
local function GetBuildable(teamID, cat)
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
local function GetBuildableTechBiased(teamID, cat, biasPow)
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
local function CombatRoleWeight(defID)
	local ud  = UnitDefs[defID]
	local cat = ud and ud.customParams and ud.customParams.buildmenucategory
	return COMBAT_ROLE_WEIGHT[cat] or COMBAT_ROLE_WEIGHT.default
end

-- ============================================================
-- GET WEIGHTED BUILDABLE  ->  { {id=defID, w=weight}, ... }
-- Combines tech weight (advanced tiers favoured) with an optional per-unit
-- weight function (e.g. combat role). Returns weighted pairs for a weighted
-- random pick, so we get composition control without duplicating list entries.
-- ============================================================
local function GetWeightedBuildable(teamID, cat, biasPow, weightFn)
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

local function SimpleGetClosestMexSpot(x, z, maxRange)
	local bestSpot
	local bestDist  = maxRange and (maxRange * maxRange) or math.huge
	local metalSpots = GG.metalMakerSpots
	if metalSpots then
		for i = 1, #metalSpots do
			local spot = metalSpots[i]
			local dx, dz = x - spot.x, z - spot.z
			local dist = dx * dx + dz * dz
			local units = Spring.GetUnitsInCylinder(spot.x, spot.z, 128)
			if dist < bestDist and #units == 0 then
				bestSpot = spot
				bestDist = dist
			end
		end
	end
	return bestSpot
end

local function EstimateEnemyBase(teamID)
	local allUnits = Spring.GetAllUnits()
	local ex, ez, count = 0, 0, 0
	for i = 1, #allUnits do
		local uid    = allUnits[i]
		local uteam  = Spring.GetUnitTeam(uid)
		local uDefID = Spring.GetUnitDefID(uid)
		if uteam ~= teamID and uDefID and UnitDefs[uDefID] and UnitDefs[uDefID].isBuilding then
			local ux, _, uz = Spring.GetUnitPosition(uid)
			ex = ex + ux
			ez = ez + uz
			count = count + 1
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
local function ComputeMusterPos(teamID)
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

	-- Stage 700 units out from the base centroid toward the centre
	local stageDist = 700
	local mx = bx + dx * stageDist
	local mz = bz + dz * stageDist
	mx = math.max(256, math.min(mapsizeX - 256, mx))
	mz = math.max(256, math.min(mapsizeZ - 256, mz))
	return { x = mx, z = mz, y = Spring.GetGroundHeight(mx, mz) }
end

-- ============================================================
-- COMMANDER HAVEN SELECTION
-- Deterministically picks ONE safe spot to flee to: a friendly building
-- that is far from the threat but not absurdly far from the commander,
-- with a strong bonus for turret cover. No randomness, so repeated calls
-- return a stable destination (prevents retreat-order thrashing).
-- ============================================================
local function FindCommanderHaven(unitID, teamID, enemyID)
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
			if cDefID and UnitDefs[cDefID] and UnitDefs[cDefID].isBuilding then
				local bx, by, bz = Spring.GetUnitPosition(cand)
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
local function FindWeakestEnemyTarget(teamID)
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

	local best, bestScore
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
		local score = defense + distPen
		if not bestScore or score < bestScore then
			bestScore = score
			best = b
		end
	end

	if best then
		return { x = best.x, z = best.z, y = Spring.GetGroundHeight(best.x, best.z) }
	end
	return nil
end

local function SimpleBuildOrder(cUnitID, building)
	local team = Spring.GetUnitTeam(cUnitID)
	local cx, _, cz = Spring.GetUnitPosition(cUnitID)

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
			-- Prefer a building as the reference anchor, but exclude the builder itself
			local buildnear = nil
			for attempt = 1, 8 do
				local candidate = units[math.random(1, #units)]
				if candidate ~= cUnitID then
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
					if candidate ~= cUnitID then
						buildnear = candidate
						break
					end
				end
			end
			if not buildnear then break end

			local refDefID = Spring.GetUnitDefID(buildnear)
			if not refDefID then break end
			local refx, _, refz = Spring.GetUnitPosition(buildnear)
			local reffootx = UnitDefs[refDefID].xsize * 8
			local reffootz = UnitDefs[refDefID].zsize * 8

			-- Use a larger minimum spacing to stop units being walled in.
			-- If near the map edge, also add the edge push to the offset.
			local spacing = math.random(96, 256)

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

			for _, r in ipairs(dirs) do
				local bposx, bposz
				if     r == 0 then bposx = refx;                    bposz = refz + reffootz + spacing
				elseif r == 1 then bposx = refx + reffootx + spacing; bposz = refz
				elseif r == 2 then bposx = refx;                    bposz = refz - reffootz - spacing
				else              bposx = refx - reffootx - spacing; bposz = refz
				end

				-- Apply edge push as an additional offset nudge
				bposx = bposx + edgePushX * spacing * 0.5
				bposz = bposz + edgePushZ * spacing * 0.5

				-- Keep well inside map bounds (larger margin than before)
				bposx = math.max(256, math.min(mapsizeX - 256, bposx))
				bposz = math.max(256, math.min(mapsizeZ - 256, bposz))

				local bposy   = Spring.GetGroundHeight(bposx, bposz)
				local testpos = Spring.TestBuildOrder(building, bposx, bposy, bposz, r)
				-- Use spacing as clearance check radius — avoids packing too tight
				local nearby  = Spring.GetUnitsInRectangle(
						bposx - spacing * 0.5, bposz - spacing * 0.5,
						bposx + spacing * 0.5, bposz + spacing * 0.5)
				if testpos == 2 and #nearby <= 0 then
					Spring.GiveOrderToUnit(cUnitID, -building, { bposx, bposy, bposz, r }, { "shift" })
					return true
				end
			end
		end
	end
	return false
end

local function SimpleRepairNearest(unitID, teamID, radius)
	local units = Spring.GetTeamUnits(teamID)
	local ux, _, uz = Spring.GetUnitPosition(unitID)
	for i = 1, #units do
		local target = units[i]
		if target ~= unitID then
			local hp, maxhp = Spring.GetUnitHealth(target)
			if hp and maxhp and hp < maxhp * 0.7 then
				local tx, _, tz = Spring.GetUnitPosition(target)
				local dx, dz = ux - tx, uz - tz
				if dx * dx + dz * dz < radius * radius then
					Spring.GiveOrderToUnit(unitID, CMD.REPAIR, { target }, { "shift" })
					return true
				end
			end
		end
	end
	return false
end

-- ============================================================
-- CONSTRUCTION PROJECT SELECTION
-- ============================================================
local function SimpleConstructionProjectSelection(
		unitID, unitDefID, unitTeam, allyTeamID, units, allunits, buildType)

	local success = false

	local nowFrame   = Spring.GetGameFrame()
	-- True only if enough frames have passed since this team last STARTED a
	-- constructor. Shared by every factory/builder so the whole team starts at
	-- most one constructor per CON_BUILD_SPACING, letting the count catch up.
	local conSpacingOk = (nowFrame - (SimpleLastConStart[unitTeam] or 0)) >= CON_BUILD_SPACING

	local supplyUsed = math.round(Spring.GetTeamRulesParam(unitTeam, "supplyUsed") or 0)
	local supplyMax  = math.round(Spring.GetTeamRulesParam(unitTeam, "supplyMax")  or 0)
	local mcurrent, mstorage, _, mincome = Spring.GetTeamResources(unitTeam, "metal")
	local ecurrent, estorage, _, eincome = Spring.GetTeamResources(unitTeam, "energy")
	local unitposx, unitposy, unitposz   = Spring.GetUnitPosition(unitID)
	local buildOptions = UnitDefs[unitDefID].buildOptions
	local techLevel    = TeamTechLevel[unitTeam] or 1

	-- Factory pacing: a single per-team frame limiter (no escalating delay), so
	-- factory #8 starts as readily as factory #2. When both metal and energy are
	-- piling up we drop to the faster "flood" spacing and pour the surplus into
	-- new production lines.
	local overflowing  = mstorage > 0 and estorage > 0
			and mcurrent > mstorage * FACTORY_OVERFLOW
			and ecurrent > estorage * FACTORY_OVERFLOW
	local facSpacing   = overflowing and FACTORY_SPACING_FLOOD or FACTORY_SPACING
	local facSpacingOk = (nowFrame - (SimpleLastFacStart[unitTeam] or 0)) >= facSpacing

	-- econPressure: 0 = at target, approaches 1 when far below next tech threshold
	local goal = TECH_INCOME_GOALS[techLevel]
	local econPressure = 0
	if goal and techLevel < 4 then
		local mRatio = (goal.m > 0) and math.min(1, mincome / goal.m) or 1
		local eRatio = (goal.e > 0) and math.min(1, eincome / goal.e) or 1
		econPressure = TECH_ECONOMY_BIAS * (1 - math.min(mRatio, eRatio))
	end

	-- TryBuild: find first unit from defList that is in our build options,
	-- shuffle so we don't always pick the same one.
	local function TryBuild(defList, orderFn)
		if not defList or #defList == 0 then return false end
		local shuffled = {}
		for _, v in ipairs(defList) do shuffled[#shuffled + 1] = v end
		for d = #shuffled, 2, -1 do
			local j = math.random(1, d)
			shuffled[d], shuffled[j] = shuffled[j], shuffled[d]
		end
		for _, project in ipairs(shuffled) do
			for i2 = 1, #buildOptions do
				if buildOptions[i2] == project then
					orderFn(project)
					return true
				end
			end
		end
		return false
	end

	-- Weighted-random variant: takes {id=,w=} pairs (from GetWeightedBuildable),
	-- filters to what this builder/factory can actually make, and picks one with
	-- probability proportional to weight. Used for combat composition control.
	local function TryBuildWeighted(weighted, orderFn)
		if not weighted or #weighted == 0 then return false end
		local cands, total = {}, 0
		for _, e in ipairs(weighted) do
			for i2 = 1, #buildOptions do
				if buildOptions[i2] == e.id then
					cands[#cands + 1] = e
					total = total + e.w
					break
				end
			end
		end
		if total <= 0 then return false end
		local roll, acc = math.random() * total, 0
		for _, e in ipairs(cands) do
			acc = acc + e.w
			if roll <= acc then
				orderFn(e.id)
				return true
			end
		end
		orderFn(cands[#cands].id)   -- float-rounding fallback
		return true
	end

	local function NearMe(project)
		local x, y, z = Spring.GetUnitPosition(unitID)
		-- Use a larger offset so we don't place inside the caller's own footprint.
		-- Also nudge away from map edges.
		local ox = math.random(-256, 256)
		local oz = math.random(-256, 256)
		if x + ox < 256 then ox = math.abs(ox) end
		if x + ox > mapsizeX - 256 then ox = -math.abs(ox) end
		if z + oz < 256 then oz = math.abs(oz) end
		if z + oz > mapsizeZ - 256 then oz = -math.abs(oz) end
		local bx, bz = x + ox, z + oz
		local by = Spring.GetGroundHeight(bx, bz)
		local facing = math.random(0, 3)
		local testpos = Spring.TestBuildOrder(project, bx, by, bz, facing)
		if testpos == 2 then
			Spring.GiveOrderToUnit(unitID, -project, { bx, by, bz, facing }, 0)
		else
			-- Fall back to SimpleBuildOrder if direct placement failed
			SimpleBuildOrder(unitID, project)
		end
	end

	local function AtMex(project, spot)
		Spring.GiveOrderToUnit(unitID, -project,
		                       { spot.x, spot.y, spot.z, 0 }, { "shift" })
	end

	SimpleFactoryDelay[unitTeam]     = SimpleFactoryDelay[unitTeam] - 1
	SimpleConstructorDelay[unitTeam] = SimpleConstructorDelay[unitTeam] - 1

	local r = math.random(0, 20)

	-- Dynamic mex search range: cast a wide net once we have factories running
	local mexRange  = (SimpleFactoriesCount[unitTeam] >= 2) and MEX_RANGE_MID or MEX_RANGE_EARLY
	local mexspot   = SimpleGetClosestMexSpot(unitposx, unitposz, mexRange)
	-- Also look globally for any unclaimed mex (no range limit) for roaming decisions
	local mexAny    = SimpleGetClosestMexSpot(unitposx, unitposz, nil)

	-- Fetch current tech-appropriate lists
	local extractors   = GetBuildable(unitTeam, "extractor")
	local generators   = GetBuildable(unitTeam, "generator")
	local converters   = GetBuildable(unitTeam, "converter")
	local turrets      = GetBuildable(unitTeam, "turret")
	local supplies     = GetBuildable(unitTeam, "supply")
	local storages     = GetBuildable(unitTeam, "storage")
	local factories    = GetBuildableTechBiased(unitTeam, "factory", TECH_FAC_BIAS)
	local constructors = GetBuildable(unitTeam, "constructor")
	local combats      = GetWeightedBuildable(unitTeam, "combat", TECH_UNIT_BIAS, CombatRoleWeight)
	local buildings    = GetBuildable(unitTeam, "building")

	-- Split factories: only offer air/sea once we have enough land factories
	local landFacCount  = SimpleLandFacCount[unitTeam] or 0
	local landFactories = {}
	local extraFactories = {}
	for _, id in ipairs(factories) do
		if AIR_FACTORY_NAMES[UnitDefs[id] and UnitDefs[id].name]
				or SEA_FACTORY_NAMES[UnitDefs[id] and UnitDefs[id].name] then
			extraFactories[#extraFactories + 1] = id
		else
			landFactories[#landFactories + 1] = id
		end
	end
	-- Before LAND_FAC_MIN land factories, only offer land factories
	if landFacCount < LAND_FAC_MIN then
		factories = landFactories
	end

	local turretCount  = SimpleTurretCount[unitTeam] or 0
	local belowTurretCap = turretCount < TURRET_CAP
	-- How many turrets this base actually wants, scaled to its size.
	local desiredTurrets = math.min(TURRET_CAP,
		TURRET_BASE
		+ (SimpleFactoriesCount[unitTeam] or 0) * TURRET_PER_FAC
		+ math.floor((SimpleT1Mexes[unitTeam] or 0) / TURRET_PER_MEX_DIV))
	local underDefended = (SimpleFactoriesCount[unitTeam] or 0) > 0
		and turretCount < desiredTurrets and belowTurretCap
	local canAffordTurret = ecurrent > estorage * 0.20 and mcurrent > mstorage * 0.15

	-- -------------------------------------------------------
	-- BUILDER / COMMANDER priority chain
	-- -------------------------------------------------------
	if buildType == "Builder" or buildType == "Commander" then

		-- PRIORITY 1: early mexes (always grab the first few immediately)
		if mexspot and SimpleT1Mexes[unitTeam] < MEX_TARGET_EARLY then
			success = TryBuild(extractors, function(p) AtMex(p, mexspot) end)

			-- PRIORITY 2: energy - urgent if low or econ pressure is high
		elseif ecurrent < estorage * 0.40 or eincome <= 80
				or (econPressure > 0.5 and goal and eincome < goal.e * 0.6) then
			if mcurrent > mstorage * 0.60 and SimpleConverterCount[unitTeam] < CONVERTER_MAX then
				if TryBuild(converters, function(p) SimpleBuildOrder(unitID, p) end) then
					SimpleConverterCount[unitTeam] = SimpleConverterCount[unitTeam] + 1
					success = true
				end
			end
			if not success then
				success = TryBuild(generators, function(p) SimpleBuildOrder(unitID, p) end)
			end

			-- PRIORITY 3: metal income low and econ pressure high — grab more mexes
		elseif econPressure > 0.5 and goal and mincome < goal.m * 0.6
				and mexspot and SimpleT1Mexes[unitTeam] < MEX_TARGET_MID then
			success = TryBuild(extractors, function(p) AtMex(p, mexspot) end)

			-- PRIORITY 4: supply if running short
		elseif SimpleFactoriesCount[unitTeam] > 0
				and ((supplyUsed > supplyMax * 0.55 and supplyMax < 950) or supplyMax < 20) then
			success = TryBuild(supplies, function(p) SimpleBuildOrder(unitID, p) end)

			-- PRIORITY 5: build first factory
		elseif SimpleFactoriesCount[unitTeam] == 0 and SimpleFactoryDelay[unitTeam] <= 0 then
			if TryBuild(factories, function(p) SimpleBuildOrder(unitID, p) end) then
				SimpleFactoryDelay[unitTeam] = 120
				SimpleLastFacStart[unitTeam] = nowFrame
				success = true
			end

			-- PRIORITY 5b: REACTIVE defense — if the base is under attack and we
			-- are under-defended, throw up a turret immediately (jumps the queue).
		elseif SimpleUnderAttack[unitTeam] and underDefended and canAffordTurret
				and buildType ~= "Commander" then
			success = TryBuild(turrets, function(p) SimpleBuildOrder(unitID, p) end)

			-- PRIORITY 5c: OVERFLOW → production. If resources are piling up, the
			-- single best thing to do is add a factory. This jumps ahead of mex
			-- expansion / generators / constructors / roaming so a surplus turns
			-- into production capacity fast instead of sitting in storage.
		elseif overflowing and SimpleFactoriesCount[unitTeam] > 0
				and SimpleFactoriesCount[unitTeam] < FACTORY_MAX
				and facSpacingOk then
			if TryBuild(factories, function(p) SimpleBuildOrder(unitID, p) end) then
				SimpleLastFacStart[unitTeam] = nowFrame
				success = true
			end

			-- PRIORITY 6: mid-game mex expansion (factory exists, energy healthy)
		elseif mexspot and SimpleT1Mexes[unitTeam] < MEX_TARGET_MID
				and SimpleFactoriesCount[unitTeam] > 0
				and ecurrent > estorage * 0.30 then
			success = TryBuild(extractors, function(p) AtMex(p, mexspot) end)

			-- PRIORITY 6b: STEADY defense — keep building toward the desired turret
			-- count. Gated by a coin-flip so it interleaves with expansion rather
			-- than monopolising the builder. (Builders only; commander keeps teching.)
		elseif underDefended and canAffordTurret and buildType ~= "Commander"
				and math.random(0, 1) == 0 then
			success = TryBuild(turrets, function(p) SimpleBuildOrder(unitID, p) end)

			-- PRIORITY 7: econ-biased generator building (to hit tech income target)
		elseif econPressure > 0.3 and goal and eincome < goal.e then
			success = TryBuild(generators, function(p) SimpleBuildOrder(unitID, p) end)

			-- PRIORITY 8: expand constructors
		elseif ecurrent > estorage * 0.50 and mcurrent > mstorage * 0.45
				and conSpacingOk
				and SimpleConstructorCount[unitTeam] < CONSTRUCTOR_MAX
				and supplyUsed < supplyMax - 5 then

			-- A commander may occasionally assist-build another commander; that
			-- does not count against the constructor rate limit.
			if buildType == "Commander" and math.random(0, 2) == 0 then
				success = TryBuild(SimpleCommanderDefs, function(p) NearMe(p) end)
			end
			if not success then
				local builtCon = TryBuild(constructors, function(p) NearMe(p) end)
				if builtCon then
					SimpleLastConStart[unitTeam] = nowFrame
					success = true
				end
			end

			-- PRIORITY 9: more factories (steady expansion when resources allow)
		elseif ecurrent > estorage * 0.50 and mcurrent > mstorage * 0.50
				and SimpleFactoriesCount[unitTeam] < FACTORY_MAX
				and facSpacingOk then
			if TryBuild(factories, function(p) SimpleBuildOrder(unitID, p) end) then
				SimpleLastFacStart[unitTeam] = nowFrame
				success = true
			end

			-- PRIORITY 10: storage when overflowing
		elseif ecurrent > estorage * 0.88 and mcurrent > mstorage * 0.88 then
			success = TryBuild(storages, function(p) SimpleBuildOrder(unitID, p) end)

			-- PRIORITY 11: roam to any unclaimed mex on the map (builders only)
			-- This fires before turrets so expansion always beats defense building.
		elseif mexAny and buildType ~= "Commander"
				and SimpleFactoriesCount[unitTeam] > 0 then
			success = TryBuild(extractors, function(p) AtMex(p, mexAny) end)

			-- PRIORITY 12: reclaim — send builders out to grab metal from wrecks.
			-- Fires on r <= 4 (5/21 chance) so it happens regularly but not constantly.
		elseif r <= 4 and buildType ~= "Commander" then
			local enemyBase = SimpleEnemyBasePos[unitTeam]
			if enemyBase then
				Spring.GiveOrderToUnit(unitID, CMD.RECLAIM,
				                       { enemyBase.x + math.random(-400, 400), enemyBase.y,
				                         enemyBase.z + math.random(-400, 400), 1500 }, 0)
			else
				-- Roam toward map center to reclaim neutral wrecks
				local cx, cz = mapsizeX / 2, mapsizeZ / 2
				Spring.GiveOrderToUnit(unitID, CMD.RECLAIM,
				                       { cx + math.random(-300, 300), Spring.GetGroundHeight(cx, cz),
				                         cz + math.random(-300, 300),
				                         math.ceil(math.sqrt(mapsizeX * mapsizeX + mapsizeZ * mapsizeZ)) }, 0)
			end
			success = true

			-- PRIORITY 13: extra defense only if still under the desired count
			-- (steady/reactive slots above are the primary defense builders).
		elseif (r == 5 or r == 6) and underDefended and canAffordTurret then
			success = TryBuild(turrets, function(p) SimpleBuildOrder(unitID, p) end)

			-- PRIORITY 14: area repair sweep
		elseif r == 7 and buildType ~= "Commander" then
			local cx, cz = mapsizeX / 2, mapsizeZ / 2
			Spring.GiveOrderToUnit(unitID, CMD.REPAIR,
			                       { cx + math.random(-200, 200), Spring.GetGroundHeight(cx, cz),
			                         cz + math.random(-200, 200),
			                         math.ceil(math.sqrt(mapsizeX * mapsizeX + mapsizeZ * mapsizeZ)) }, 0)
			success = true

			-- FALLBACK: misc buildings only — no extra turret roll here
		else
			if #buildings > 0 and math.random(0, 1) == 0 then
				success = TryBuild(buildings, function(p) SimpleBuildOrder(unitID, p) end)
			end
			-- If still no success and there are unclaimed mexes, go get one
			if not success and mexAny then
				success = TryBuild(extractors, function(p) AtMex(p, mexAny) end)
			end
		end

		-- -------------------------------------------------------
		-- FACTORY queue
		-- -------------------------------------------------------
	elseif buildType == "Factory" then
		if #Spring.GetFullBuildQueue(unitID, 0) < 10 and supplyUsed < supplyMax * 0.95 then
			local luaAI = Spring.GetTeamLuaAI(unitTeam)
			local isConAI = string.sub(luaAI, 1, 19) == 'SimpleConstructorAI'
			local conCap  = isConAI and CONSTRUCTOR_MAX_CON_AI or CONSTRUCTOR_MAX
			-- Two-part guard against worker floods:
			--   1. Hard cap: never exceed conCap live constructors.
			--   2. Spacing: only ONE constructor may START per team per window.
			-- Without (2) every factory evaluates in the same tick, all see the
			-- same stale count, and all queue a constructor at once. Dedicated
			-- SimpleConstructorAI teams skip the spacing (it's their whole job)
			-- but are still bounded by the higher cap.
			local haveConRoom = (SimpleConstructorCount[unitTeam] or 0) < conCap
			local wantConstructor = haveConRoom
					and (isConAI or conSpacingOk)
					and (
						isConAI
						or math.random(0, 5) == 0
						or supplyUsed > supplyMax * 0.85
						or econPressure > 0.4 )

			if wantConstructor then
				success = TryBuild(constructors, function(p)
					local x, y, z = Spring.GetUnitPosition(unitID)
					Spring.GiveOrderToUnit(unitID, -p, { x, y, z, 0 }, 0)
				end)
				if success then SimpleLastConStart[unitTeam] = nowFrame end
			end
			if not success then
				success = TryBuildWeighted(combats, function(p)
					local x, y, z = Spring.GetUnitPosition(unitID)
					Spring.GiveOrderToUnit(unitID, -p, { x, y, z, 0 }, 0)
				end)
			end
		else
			success = true
		end
	end

	return success
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

					-- ---- Muster point: compute/refresh every ~40s or if unset ----
					if not SimpleMusterPos[teamID] or n % 2400 == 0 then
						SimpleMusterPos[teamID] = ComputeMusterPos(teamID)
					end
					local muster = SimpleMusterPos[teamID]

					-- Count ground combat units and how many are at the muster point
					local atMuster    = 0
					local totalGround = 0
					if muster then
						for k = 1, #units do
							local uid    = units[k]
							local uDefID = Spring.GetUnitDefID(uid)
							if uDefID and IsCombat[uDefID] and not IsAir[uDefID] then
								totalGround = totalGround + 1
								local ux2, _, uz2 = Spring.GetUnitPosition(uid)
								local dx2 = ux2 - muster.x
								local dz2 = uz2 - muster.z
								if dx2*dx2 + dz2*dz2 < MUSTER_RADIUS * MUSTER_RADIUS then
									atMuster = atMuster + 1
								end
							end
						end
					end

					-- ---- Base intruder detection ----
					-- Find the enemy unit nearest our base centre that's inside the
					-- defend radius. The home guard will hunt it down. This is what
					-- stops units strolling past raiders chewing on the base.
					local baseThreat = nil
					do
						local bx, bz, bc = 0, 0, 0
						for k = 1, #units do
							local uDefID = Spring.GetUnitDefID(units[k])
							if uDefID and UnitDefs[uDefID] and UnitDefs[uDefID].isBuilding then
								local px, _, pz = Spring.GetUnitPosition(units[k])
								bx = bx + px; bz = bz + pz; bc = bc + 1
							end
						end
						if bc > 0 then
							bx, bz = bx / bc, bz / bc
							local near = Spring.GetUnitsInCylinder(bx, bz, BASE_DEFEND_RADIUS)
							local bestD
							for _, eu in ipairs(near) do
								local et = Spring.GetUnitTeam(eu)
								if et ~= teamID and et ~= gaiaTeamID
										and not Spring.AreTeamsAllied(teamID, et) then
									local ex, ey, ez = Spring.GetUnitPosition(eu)
									local dx, dz = ex - bx, ez - bz
									local d = dx * dx + dz * dz
									if not bestD or d < bestD then
										bestD = d
										baseThreat = { x = ex, y = ey, z = ez, uid = eu }
									end
								end
							end
						end
					end
					SimpleBaseThreat[teamID] = baseThreat

					-- Squad state transitions
					-- Launch when a wave has mustered, OR when we already have a big
					-- army (don't sit forever waiting for perfect muster), OR when
					-- the base is under attack and we have at least a token force.
					-- An active base intruder suppresses outward launches so the home
					-- guard stays to deal with it instead of marching off.
					local cooldownOk    = (n - SimpleLastLaunch[teamID]) >= WAVE_COOLDOWN
					local readyToLaunch = cooldownOk and not baseThreat
							and (atMuster >= WAVE_MUSTER_SIZE or totalGround >= WAVE_BIG_ARMY)
							and totalGround >= WAVE_MIN_ARMY
					local forceAttack   = SimpleUnderAttack[teamID] and not baseThreat
							and totalGround >= 3
							and (n - SimpleLastLaunch[teamID] >= WAVE_COOLDOWN / 2)

					if (readyToLaunch or forceAttack)
							and SimpleSquadState[teamID] == "mustering" then
						SimpleSquadState[teamID] = "attacking"
						SimpleLastLaunch[teamID] = n
						SimpleLastTargetScan[teamID] = n
						-- Aim at the WEAKEST-defended enemy structure, not the
						-- centre of mass (which is usually the most fortified spot).
						local target = FindWeakestEnemyTarget(teamID)
								or SimpleEnemyBasePos[teamID]
								or {
									x = mapsizeX / 2 + math.random(-500, 500),
									z = mapsizeZ / 2 + math.random(-500, 500),
									y = Spring.GetGroundHeight(mapsizeX / 2, mapsizeZ / 2),
								}
						SimpleAttackWave[teamID] = target
						-- Issue FIGHT to all healthy ground units simultaneously
						for k = 1, #units do
							local uid    = units[k]
							local uDefID = Spring.GetUnitDefID(uid)
							if uDefID and IsCombat[uDefID] and not IsAir[uDefID] then
								local uhp, umhp = Spring.GetUnitHealth(uid)
								if uhp and umhp and (uhp / umhp) >= RETREAT_HP then
									Spring.GiveOrderToUnit(uid, CMD.FIGHT,
									                       { target.x + math.random(-200, 200),
									                         target.y,
									                         target.z + math.random(-200, 200) },
									                       { "shift", "alt", "ctrl" })
								end
							end
						end
					end

					-- While pushing, periodically re-scan for the softest target so
					-- the wave rolls onto fresh weak points as defences collapse.
					if SimpleSquadState[teamID] == "attacking"
							and (n - SimpleLastTargetScan[teamID]) >= ATTACK_RETARGET then
						SimpleLastTargetScan[teamID] = n
						local newTarget = FindWeakestEnemyTarget(teamID)
						if newTarget then SimpleAttackWave[teamID] = newTarget end
					end

					-- Return to mustering when army is spent
					if SimpleSquadState[teamID] == "attacking" and totalGround < 3 then
						SimpleSquadState[teamID] = "mustering"
						SimpleAttackWave[teamID]  = nil
					end

					-- Per-unit decisions
					for k = 1, #units do
						local unitID    = units[k]
						local unitDefID = Spring.GetUnitDefID(unitID)
						local unitHealth, unitMaxHealth = Spring.GetUnitHealth(unitID)

						if unitDefID and unitHealth then
							local hpRatio    = unitHealth / unitMaxHealth
							local ux, uy, uz = Spring.GetUnitPosition(unitID)
							local unitCmds   = Spring.GetCommandQueue(unitID, 0)

							-- ======== COMMANDERS ========
							if IsCommander[unitDefID] then

								local nearEnemy = Spring.GetUnitNearestEnemy(unitID, COMM_DANGER_R, true)

								if SimpleCommRetreating[teamID] then
									-- Already fleeing. Commit to the chosen haven; only re-issue
									-- an order when we genuinely need to, so the commander runs
									-- in one direction instead of re-rolling every time it's hit.
									if not nearEnemy then
										-- Threat gone: stop fleeing, resume normal duties next tick.
										SimpleCommRetreating[teamID] = false
										SimpleCommRetreatPos[teamID] = nil
									else
										local rp = SimpleCommRetreatPos[teamID]
										local needNew = (rp == nil)
										if rp then
											local dx, dz = ux - rp.x, uz - rp.z
											if (dx * dx + dz * dz) < (COMM_HAVEN_REACH * COMM_HAVEN_REACH) then
												-- Reached the haven but still in danger: pick a fresh one.
												needNew = true
											end
										end
										if needNew then
											rp = FindCommanderHaven(unitID, teamID, nearEnemy)
											SimpleCommRetreatPos[teamID] = rp
											if rp then
												Spring.GiveOrderToUnit(unitID, CMD.MOVE,
												                       { rp.x, rp.y, rp.z }, 0)
											end
										elseif unitCmds == 0 and rp then
											-- Order queue emptied unexpectedly: resume toward the
											-- SAME committed haven (do not pick a new direction).
											Spring.GiveOrderToUnit(unitID, CMD.MOVE,
											                       { rp.x, rp.y, rp.z }, 0)
										end
										-- Otherwise: leave the existing move order alone.
									end

								elseif nearEnemy and hpRatio <= COMM_RETREAT_HP then
									-- Drop into retreat: choose ONE haven and commit to it.
									local rp = FindCommanderHaven(unitID, teamID, nearEnemy)
									SimpleCommRetreating[teamID] = true
									SimpleCommRetreatPos[teamID] = rp
									if rp then
										Spring.GiveOrderToUnit(unitID, CMD.MOVE,
										                       { rp.x, rp.y, rp.z }, 0)
									end

								elseif nearEnemy and unitCmds == 0 then
									-- Healthy and enemy nearby: fight back
									local tx, ty, tz = Spring.GetUnitPosition(nearEnemy)
									Spring.GiveOrderToUnit(unitID, CMD.FIGHT, { tx, ty, tz }, 0)

								elseif unitCmds == 0 then
									-- Idle: build something
									SimpleConstructionProjectSelection(
											unitID, unitDefID, teamID, allyTeamID,
											units, allunits, "Commander")
								end

								-- ======== CONSTRUCTORS ========
							elseif IsConstructor[unitDefID] then

								local nearEnemy = Spring.GetUnitNearestEnemy(unitID, 600, true)

								if nearEnemy and hpRatio > 0.85 then
									Spring.GiveOrderToUnit(unitID, CMD.RECLAIM, { nearEnemy }, 0)

								elseif nearEnemy then
									local fled = false
									for x = 1, 50 do
										local candidate = units[math.random(1, #units)]
										local cDefID    = Spring.GetUnitDefID(candidate)
										if cDefID and UnitDefs[cDefID].isBuilding then
											local tx, ty, tz = Spring.GetUnitPosition(candidate)
											Spring.GiveOrderToUnit(unitID, CMD.MOVE,
											                       { tx + math.random(-100, 100), ty,
											                         tz + math.random(-100, 100) }, 0)
											fled = true
											break
										end
									end
									if fled then SimpleRepairNearest(unitID, teamID, 400) end

								elseif unitCmds == 0 then
									-- Check if we are very close to a factory (within its footprint).
									-- If so, walk away first before trying to build anything,
									-- otherwise SimpleBuildOrder will always fail.
									local tooClose = false
									for fi = 1, #units do
										local candidate = units[fi]
										if candidate ~= unitID then
											local cDefID = Spring.GetUnitDefID(candidate)
											if cDefID and IsFactory[cDefID] then
												local fx, _, fz = Spring.GetUnitPosition(candidate)
												local fdx, fdz = ux - fx, uz - fz
												local ffoot = math.max(
														UnitDefs[cDefID].xsize,
														UnitDefs[cDefID].zsize) * 8 + 200
												if fdx * fdx + fdz * fdz < ffoot * ffoot then
													tooClose = true
													-- Walk in a random direction away from the factory
													local angle = math.random() * 6.28
													local dist  = ffoot + math.random(200, 500)
													local wx = fx + math.cos(angle) * dist
													local wz = fz + math.sin(angle) * dist
													wx = math.max(256, math.min(mapsizeX - 256, wx))
													wz = math.max(256, math.min(mapsizeZ - 256, wz))
													local wy = Spring.GetGroundHeight(wx, wz)
													Spring.GiveOrderToUnit(unitID, CMD.MOVE, { wx, wy, wz }, 0)
													break
												end
											end
										end
									end

									if not tooClose then
										if not SimpleRepairNearest(unitID, teamID, 300) then
											SimpleConstructionProjectSelection(
													unitID, unitDefID, teamID, allyTeamID,
													units, allunits, "Builder")
										end
									end
								end

								-- ======== FACTORIES ========
							elseif IsFactory[unitDefID] then
								if unitCmds == 0 then
									SimpleConstructionProjectSelection(
											unitID, unitDefID, teamID, allyTeamID,
											units, allunits, "Factory")
								end

								-- ======== COMBAT UNITS ========
							elseif IsCombat[unitDefID] then

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
									-- Retreat if badly wounded, regardless of state
									if hpRatio < RETREAT_HP and unitCmds == 0 then
										if muster then
											Spring.GiveOrderToUnit(unitID, CMD.MOVE,
											                       { muster.x + math.random(-100, 100),
											                         muster.y,
											                         muster.z + math.random(-100, 100) }, 0)
										end

									elseif SimpleSquadState[teamID] == "attacking" then
										-- Attack mode: push to wave target or engage nearby foes
										if unitCmds == 0 then
											local wave = SimpleAttackWave[teamID]
											local nearEnemy = Spring.GetUnitNearestEnemy(
													unitID, 1500, false)
											if nearEnemy then
												local tx, ty, tz = Spring.GetUnitPosition(nearEnemy)
												Spring.GiveOrderToUnit(unitID, CMD.FIGHT,
												                       { tx + math.random(-60, 60), ty,
												                         tz + math.random(-60, 60) },
												                       { "shift", "alt", "ctrl" })
											elseif wave then
												Spring.GiveOrderToUnit(unitID, CMD.FIGHT,
												                       { wave.x + math.random(-150, 150),
												                         wave.y,
												                         wave.z + math.random(-150, 150) },
												                       { "shift", "alt", "ctrl" })
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

						end -- if unitDefID and unitHealth
					end -- for each unit

					SimpleUnderAttack[teamID] = false

				end
			end
		end -- n%15
	end

	-- ============================================================
	-- UNIT CREATED
	-- Detect faction from the first commander; populate build lists.
	-- ============================================================
	function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
		-- Only act on teams this gadget manages
		local isAITeam = false
		for i = 1, SimpleAITeamIDsCount do
			if SimpleAITeamIDs[i] == unitTeam then
				isAITeam = true
				break
			end
		end
		if not isAITeam then return end

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

	-- ============================================================
	-- UNIT DESTROYED
	-- ============================================================
	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam,
	                              attackerID, attackerDefID, attackerTeam)
		for i = 1, SimpleAITeamIDsCount do
			if SimpleAITeamIDs[i] == unitTeam then
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
				if IsCommander[unitDefID] then
					-- Commander died; allow faction re-detection on respawn
					TeamCommID[unitTeam] = nil
					SimpleCommRetreating[unitTeam] = false
					SimpleCommRetreatPos[unitTeam] = nil
				end
				break
			end
		end
	end

	-- ============================================================
	-- UNIT DAMAGED
	-- ============================================================
	function gadget:UnitDamaged(unitID, unitDefID, damage, direction,
	                            attackerID, attackerDefID, attackerTeam, isParalyzer)
		if not unitDefID then return end
		local teamID = Spring.GetUnitTeam(unitID)
		for i = 1, SimpleAITeamIDsCount do
			if SimpleAITeamIDs[i] == teamID then
				if UnitDefs[unitDefID] and UnitDefs[unitDefID].isBuilding then
					SimpleUnderAttack[teamID] = true
					-- Fast-track the next wave launch on base attack
					if SimpleLastLaunch[teamID] and (SimpleLastLaunch[teamID] + WAVE_COOLDOWN / 2) > 0 then
						SimpleLastLaunch[teamID] = math.min(SimpleLastLaunch[teamID],
						                                    SimpleLastLaunch[teamID] - WAVE_COOLDOWN / 2)
					end
				end
				break
			end
		end
	end

end -- IsSyncedCode
