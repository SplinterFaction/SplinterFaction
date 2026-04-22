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

-- ============================================================
-- CONSTANTS
-- ============================================================

local WAVE_INTERVAL     = 3600   -- frames between attack wave launches
local WAVE_MIN_ARMY     = 6      -- minimum combat units before attacking
local WAVE_MUSTER_SIZE  = 5      -- units that must be at muster point to trigger launch
local MUSTER_RADIUS     = 600    -- how close a unit must be to count as "at muster"
local RETREAT_HP        = 0.75   -- retreat threshold
local CONSTRUCTOR_MAX   = 3     -- max constructors per team
local MEX_TARGET_EARLY  = 2      -- grab this many mexes before anything else
local MEX_TARGET_MID    = 8      -- expand to this many once economy is running
local MEX_RANGE_EARLY   = 2000   -- mex search radius before base established
local MEX_RANGE_MID     = 5000   -- mex search radius once we have 2+ factories
local CONVERTER_MAX     = 3      -- max energy converters per team
local FACTORY_MAX       = 12      -- max factories per team
local LAND_FAC_MIN      = 3      -- build at least this many land factories before any air/sea
local TURRET_CAP        = 20     -- absolute max turrets to build per team
local WAVE_COOLDOWN     = 2700   -- minimum frames between launches (~45s)

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
-- UTILITY HELPERS
-- ============================================================

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

	local supplyUsed = math.round(Spring.GetTeamRulesParam(unitTeam, "supplyUsed") or 0)
	local supplyMax  = math.round(Spring.GetTeamRulesParam(unitTeam, "supplyMax")  or 0)
	local mcurrent, mstorage, _, mincome = Spring.GetTeamResources(unitTeam, "metal")
	local ecurrent, estorage, _, eincome = Spring.GetTeamResources(unitTeam, "energy")
	local unitposx, unitposy, unitposz   = Spring.GetUnitPosition(unitID)
	local buildOptions = UnitDefs[unitDefID].buildOptions
	local techLevel    = TeamTechLevel[unitTeam] or 1

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
	local factories    = GetBuildable(unitTeam, "factory")
	local constructors = GetBuildable(unitTeam, "constructor")
	local combats      = GetBuildable(unitTeam, "combat")
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
				success = true
			end

			-- PRIORITY 6: mid-game mex expansion (factory exists, energy healthy)
		elseif mexspot and SimpleT1Mexes[unitTeam] < MEX_TARGET_MID
				and SimpleFactoriesCount[unitTeam] > 0
				and ecurrent > estorage * 0.30 then
			success = TryBuild(extractors, function(p) AtMex(p, mexspot) end)

			-- PRIORITY 7: econ-biased generator building (to hit tech income target)
		elseif econPressure > 0.3 and goal and eincome < goal.e then
			success = TryBuild(generators, function(p) SimpleBuildOrder(unitID, p) end)

			-- PRIORITY 8: expand constructors
		elseif ecurrent > estorage * 0.50 and mcurrent > mstorage * 0.45
				and SimpleConstructorDelay[unitTeam] <= 0
				and SimpleConstructorCount[unitTeam] < CONSTRUCTOR_MAX
				and supplyUsed < supplyMax - 5 then

			SimpleConstructorDelay[unitTeam] = 15
			if buildType == "Commander" and math.random(0, 2) == 0 then
				success = TryBuild(SimpleCommanderDefs, function(p) NearMe(p) end)
			end
			if not success then
				success = TryBuild(constructors, function(p) NearMe(p) end)
			end

			-- PRIORITY 9: more factories
		elseif ecurrent > estorage * 0.55 and mcurrent > mstorage * 0.55
				and SimpleFactoriesCount[unitTeam] < FACTORY_MAX
				and SimpleFactoryDelay[unitTeam] <= 0 then
			if TryBuild(factories, function(p) SimpleBuildOrder(unitID, p) end) then
				SimpleFactoryDelay[unitTeam] = 60 * math.max(1, SimpleFactoriesCount[unitTeam])
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

			-- PRIORITY 13: turrets — only build if below the cap, and only a modest
			-- random chance (r == 5 or 6: 2/21 ~ 10%) so they don't dominate spending.
		elseif (r == 5 or r == 6) and belowTurretCap then
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
			local wantConstructor = math.random(0, 5) == 0
					or string.sub(luaAI, 1, 19) == 'SimpleConstructorAI'
					or supplyUsed > supplyMax * 0.85
					or (econPressure > 0.4 and SimpleConstructorCount[unitTeam] < CONSTRUCTOR_MAX)

			if wantConstructor then
				success = TryBuild(constructors, function(p)
					local x, y, z = Spring.GetUnitPosition(unitID)
					Spring.GiveOrderToUnit(unitID, -p, { x, y, z, 0 }, 0)
				end)
			end
			if not success then
				success = TryBuild(combats, function(p)
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

					-- Squad state transitions
					local readyToLaunch = atMuster >= WAVE_MUSTER_SIZE
							and (n - SimpleLastLaunch[teamID] >= WAVE_COOLDOWN)
					local forceAttack   = SimpleUnderAttack[teamID]
							and totalGround >= 3
							and (n - SimpleLastLaunch[teamID] >= WAVE_COOLDOWN / 2)

					if (readyToLaunch or forceAttack)
							and SimpleSquadState[teamID] == "mustering" then
						SimpleSquadState[teamID] = "attacking"
						SimpleLastLaunch[teamID] = n
						local target = SimpleEnemyBasePos[teamID] or {
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

								local nearEnemy = Spring.GetUnitNearestEnemy(unitID, 500, true)

								if nearEnemy and hpRatio <= RETREAT_HP then
									-- Low health: retreat to nearest friendly building
									local retreated = false
									for x = 1, 15 do
										local candidate = units[math.random(1, #units)]
										local cDefID    = Spring.GetUnitDefID(candidate)
										if cDefID and UnitDefs[cDefID].isBuilding
												and candidate ~= unitID then
											local tx, ty, tz = Spring.GetUnitPosition(candidate)
											Spring.GiveOrderToUnit(unitID, CMD.MOVE,
											                       { tx + math.random(-150, 150), ty,
											                         tz + math.random(-150, 150) }, 0)
											retreated = true
											break
										end
									end
									if not retreated then
										local ex2, _, ez2 = Spring.GetUnitPosition(nearEnemy)
										Spring.GiveOrderToUnit(unitID, CMD.MOVE,
										                       { ux + (ux - ex2), uy, uz + (uz - ez2) }, 0)
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
										-- Muster mode: walk to staging area.
										-- Fight back only if enemy is right on top of us.
										local nearEnemy = Spring.GetUnitNearestEnemy(
												unitID, 500, true)
										if nearEnemy and unitCmds == 0 then
											local tx, ty, tz = Spring.GetUnitPosition(nearEnemy)
											Spring.GiveOrderToUnit(unitID, CMD.FIGHT,
											                       { tx, ty, tz }, { "shift", "alt", "ctrl" })
											-- Queue return to muster after fight
											if muster then
												Spring.GiveOrderToUnit(unitID, CMD.MOVE,
												                       { muster.x + math.random(-150, 150),
												                         muster.y,
												                         muster.z + math.random(-150, 150) },
												                       { "shift" })
											end
										elseif unitCmds == 0 and muster then
											Spring.GiveOrderToUnit(unitID, CMD.MOVE,
											                       { muster.x + math.random(-200, 200),
											                         muster.y,
											                         muster.z + math.random(-200, 200) }, 0)
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
