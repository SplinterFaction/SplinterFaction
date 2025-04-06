--------------------------------------------------------------------------------
-- Gadget Information
--------------------------------------------------------------------------------
function gadget:GetInfo()
	return {
		name = "Enhanced Splinterfaction AI",
		desc = "Modular AI for Splinterfaction with improved economy, construction, and combat management.",
		author = "YourName",
		date = "2025",
		layer = -100,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- Global AI Table and Configuration
--------------------------------------------------------------------------------
local AI = {}

-- Unit definitions by role (using unit names, to be converted to unitDefIDs later)
AI.unitDefsByRole = {
	Commander = {
		"fedcommander", "fedcommander_up1", "fedcommander_up2", "fedcommander_up3", "fedcommander_up4",
		"lozcommander", "lozcommander_up1", "lozcommander_up2", "lozcommander_up3", "lozcommander_up4"
	},
	Factory = {
		"f1landfac", "fedairplant", "fedseaplant", "f2landfac", "lozairplant", "lozseaplant"
	},
	Constructor = {
		"fedengineer_up1", "lozengineer_up1"
	},
	Extractor = {
		"fedmetalextractor", "lozmetalextractor"
	},
	Generator = {
		"fissionpowerplant", "fusionpowerplant", "coldfusionpowerplant", "blackholepowerplant"
	},
	Supply = {
		"supplydepot", "mediumsupplydepot", "largestorage"
	},
	Turret = {
		"fedmenlo", "fedstinger", "fedimmolator", "fedjavelin",
		"lozjericho", "lozrazor", "lozinferno", "lozrattlesnake"
	},
	Storage = {
		"mediumstorage", "largestorage"
	},
}

-- Preset starting build order: 4 Constructors, then 3 Extractors, then 4 Generators
AI.startingBuildOrder = {
	{ role = "Constructor", count = 4 },
	{ role = "Extractor",   count = 3 },
	{ role = "Generator",   count = 4 },
}

--------------------------------------------------------------------------------
-- Team Data Initialization
--------------------------------------------------------------------------------
AI.teams = Spring.GetTeamList()
AI.teamData = {}
for i = 1, #AI.teams do
	local teamID = AI.teams[i]
	AI.teamData[teamID] = {
		state = "economic",  -- "economic" or "combat"
		factories = 0,
		mexes = 0,
		constructors = 0,
		factoryDelay = 0,
		constructorDelay = 0,
		-- Starting build order state:
		startingBuildOrderActive = true,
		startingBuildOrderIndex = 1,  -- current step in the starting order
		startingBuildOrderCount = 0,  -- count of orders issued for the current step
		energyProjectInProgress = false, -- tracks if an energy project (Generator) is underway
		basePosition = nil,  -- will be set when the first commander is created
	}
end

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

function AI:GetTeamFaction(teamID)
	-- Look for a commander on the team and check its name
	local units = Spring.GetTeamUnits(teamID)
	for _, unitID in ipairs(units) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		for _, commanderDefID in ipairs(self.unitDefsByRole.Commander or {}) do
			if unitDefID == commanderDefID then
				local name = UnitDefs[unitDefID].name or ""
				name = string.lower(name)
				if string.find(name, "fed") then
					return "fed"
				elseif string.find(name, "loz") then
					return "loz"
				end
			end
		end
	end
	return nil
end


function AI:IsStaticStructure(unitDefID)
	-- Consider these roles as static structures:
	local staticRoles = {"Extractor", "Generator", "Supply", "Storage", "Factory", "Turret"}
	for _, role in ipairs(staticRoles) do
		for _, id in ipairs(self.unitDefsByRole[role] or {}) do
			if id == unitDefID then
				return true
			end
		end
	end
	return false
end


-- Check if a given unitDefID corresponds to an extractor.
function AI:IsExtractor(unitDefID)
	for _, defID in ipairs(self.unitDefsByRole.Extractor or {}) do
		if unitDefID == defID then
			return true
		end
	end
	return false
end

-- Scan metal spots and return the first unoccupied metal spot (i.e. no friendly extractor within 128 units).
function AI:GetUnoccupiedMetalSpot(teamID)
	local metalSpots = GG.metalSpots
	if not metalSpots then
		return nil
	end
	local base = self.teamData[teamID].basePosition
	if not base then
		return nil
	end
	local bestSpot = nil
	local bestDistSq = math.huge
	for i = 1, #metalSpots do
		local spot = metalSpots[i]
		local units = Spring.GetUnitsInCylinder(spot.x, spot.z, 128)
		local occupied = false
		for _, unitID in ipairs(units) do
			if Spring.GetUnitTeam(unitID) == teamID then
				local unitDefID = Spring.GetUnitDefID(unitID)
				if self:IsExtractor(unitDefID) then
					occupied = true
					break
				end
			end
		end
		if not occupied then
			local dx = spot.x - base.x
			local dz = spot.z - base.z
			local distSq = dx * dx + dz * dz
			if distSq < bestDistSq then
				bestDistSq = distSq
				bestSpot = spot
			end
		end
	end
	return bestSpot
end

-- Build an extractor directly at the given metal spot.
function AI:BuildExtractorAtMetalSpot(teamID, metalSpot)
	local builder = self:FindAvailableBuilder(teamID)
	if builder then
		local extractorOptions = self.unitDefsByRole.Extractor
		local choice = extractorOptions[math.random(#extractorOptions)]
		local pos = {
			x = metalSpot.x,
			y = Spring.GetGroundHeight(metalSpot.x, metalSpot.z),
			z = metalSpot.z
		}
		Spring.GiveOrderToUnit(builder, -choice, { pos.x, pos.y, pos.z, math.random(0,3) }, {})
		local unitName = UnitDefs[choice] and UnitDefs[choice].name or "Unknown"
		Spring.Echo("Team " .. teamID .. " building extractor " .. tostring(choice) .. " (" .. unitName .. ") at metal spot")
	end
end

-- Convert unit names to unitDefIDs for all roles
function AI:ConvertUnitNamesToDefIDs()
	for role, unitList in pairs(self.unitDefsByRole) do
		for i, unitName in ipairs(unitList) do
			for unitDefID, unitDef in pairs(UnitDefs) do
				if unitDef.name == unitName then
					self.unitDefsByRole[role][i] = unitDefID
					break
				end
			end
		end
	end
end

-- Get the commander's tech level (using ProvideTech) for the given team
function AI:GetCommanderTechLevel(teamID)
	local units = Spring.GetTeamUnits(teamID)
	for _, unitID in ipairs(units) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		for _, commanderDefID in ipairs(self.unitDefsByRole.Commander or {}) do
			if unitDefID == commanderDefID then
				local provideTech = UnitDefs[unitDefID].customParams.providetech
				local techLevel = tonumber(provideTech:match("tech(%d)")) or 0
				return techLevel
			end
		end
	end
	return 0
end

-- Get a build position near the base for economic structures (Generator, Supply, Storage)
function AI:GetBaseBuildPosition(teamID, buildingDefID)
	local base = self.teamData[teamID].basePosition
	if not base then return nil end
	local radius = 300  -- Define the size of your base
	local offsetX = math.random(-radius, radius)
	local offsetZ = math.random(-radius, radius)
	local pos = {
		x = base.x + offsetX,
		y = Spring.GetGroundHeight(base.x + offsetX, base.z + offsetZ),
		z = base.z + offsetZ,
	}
	local facing = math.random(0, 3)
	if Spring.TestBuildOrder(buildingDefID, pos.x, pos.y, pos.z, facing) == 2 then
		return pos
	end
	return nil
end

-- Get a metal build position for extractors by finding the closest unoccupied metal spot
function AI:GetMetalBuildPosition(teamID, builderID)
	local bx, _, bz = Spring.GetUnitPosition(builderID)
	local base = self.teamData[teamID].basePosition
	if not base then return nil end
	local bestSpot = nil
	local bestComposite = math.huge
	local metalSpots = GG.metalSpots  -- Must be populated with spots having .x and .z
	if metalSpots then
		for i = 1, #metalSpots do
			local spot = metalSpots[i]
			-- Check occupancy (within 128 units)
			local unitsAtSpot = Spring.GetUnitsInCylinder(spot.x, spot.z, 128)
			local occupied = false
			for _, unitID in ipairs(unitsAtSpot) do
				if Spring.GetUnitTeam(unitID) == teamID then
					local unitDefID = Spring.GetUnitDefID(unitID)
					if self:IsExtractor(unitDefID) then
						occupied = true
						break
					end
				end
			end
			if not occupied then
				-- Calculate distance from base and builder
				local baseDist = math.sqrt((spot.x - base.x)^2 + (spot.z - base.z)^2)
				local builderDist = math.sqrt((spot.x - bx)^2 + (spot.z - bz)^2)
				local composite = baseDist + builderDist
				if composite < bestComposite then
					bestComposite = composite
					bestSpot = spot
				end
			end
		end
	end
	if bestSpot then
		return { x = bestSpot.x, y = Spring.GetGroundHeight(bestSpot.x, bestSpot.z), z = bestSpot.z }
	else
		return nil
	end
end



-- Get a generic build position near the builder using nearby friendly buildings as reference
function AI:GetBuildPosition(builderID, buildingDefID)
	-- Get builder position
	local bx, by, bz = Spring.GetUnitPosition(builderID)
	-- Get building footprint size
	local bd = UnitDefs[buildingDefID]
	local baseSearchRadius = math.max(100, bd.xsize * 16, bd.zsize * 16)
	local searchRadius = baseSearchRadius
	local maxRadius = baseSearchRadius * 3

	-- Loop through increasing radii
	for range = searchRadius, maxRadius, baseSearchRadius do
		local units = Spring.GetUnitsInCylinder(bx, bz, range, Spring.GetUnitTeam(builderID))
		if #units > 0 then
			-- Pick a random reference unit among nearby friendly units.
			local refUnit = units[math.random(#units)]
			local rx, ry, rz = Spring.GetUnitPosition(refUnit)
			-- Use spacing proportional to the building's size (random variation)
			local spacing = math.random(bd.xsize * 4, bd.xsize * 8)
			-- Pick a random facing
			local r = math.random(0, 3)
			-- Get reference unit's footprint
			local reffoot = UnitDefs[Spring.GetUnitDefID(refUnit)]
			-- Calculate offsets based on facing (you might need to adjust these multipliers)
			local offsetX = (r == 1 and reffoot.xsize * 8 or (r == 3 and -reffoot.xsize * 8 or 0))
			local offsetZ = (r == 0 and reffoot.zsize * 8 or (r == 2 and -reffoot.zsize * 8 or 0))
			local pos = {
				x = rx + offsetX + math.random(-spacing, spacing),
				y = Spring.GetGroundHeight(rx + offsetX, rz + offsetZ),
				z = rz + offsetZ + math.random(-spacing, spacing),
			}
			if Spring.TestBuildOrder(buildingDefID, pos.x, pos.y, pos.z, r) == 2 then
				return pos
			end
		end
	end

	-- Fallback: try near the builder directly, with an expanded random range based on building size.
	local fallbackRange = baseSearchRadius * 2
	local pos = {
		x = bx + math.random(-fallbackRange, fallbackRange),
		y = Spring.GetGroundHeight(bx, bz),
		z = bz + math.random(-fallbackRange, fallbackRange),
	}
	if Spring.TestBuildOrder(buildingDefID, pos.x, pos.y, pos.z, math.random(0, 3)) == 2 then
		return pos
	end

	return nil
end


function AI:BuildEdgeDefense(teamID)
	local base = self.teamData[teamID].basePosition
	local radius = self.teamData[teamID].baseRadius or 300
	if not base then return end

	-- Find the closest enemy unit (or average enemy position) relative to the base.
	local enemyPos = nil
	local enemyDist = math.huge
	local teams = Spring.GetTeamList()
	for _, t in ipairs(teams) do
		if t ~= teamID and not Spring.AreTeamsAllied(teamID, t) then
			local enemyUnits = Spring.GetTeamUnits(t)
			for _, enemyUnit in ipairs(enemyUnits) do
				local ex, ey, ez = Spring.GetUnitPosition(enemyUnit)
				local dx = ex - base.x
				local dz = ez - base.z
				local dSq = dx*dx + dz*dz
				if dSq < enemyDist then
					enemyDist = dSq
					enemyPos = { x = ex, y = ey, z = ez }
				end
			end
		end
	end

	if not enemyPos then return end

	-- Compute the normalized direction vector from base to enemy.
	local dx = enemyPos.x - base.x
	local dz = enemyPos.z - base.z
	local mag = math.sqrt(dx*dx + dz*dz)
	if mag == 0 then return end
	dx = dx / mag
	dz = dz / mag

	-- Determine a build position at the edge of the base in that direction.
	local pos = {
		x = base.x + dx * radius,
		y = Spring.GetGroundHeight(base.x + dx * radius, base.z + dz * radius),
		z = base.z + dz * radius,
	}

	-- Find any available builder and order a turret build at that position.
	local builder = self:FindAvailableBuilder(teamID)
	if builder then
		local turretOptions = self.unitDefsByRole.Turret
		if turretOptions and #turretOptions > 0 then
			local choice = turretOptions[math.random(#turretOptions)]
			if Spring.TestBuildOrder(choice, pos.x, pos.y, pos.z, math.random(0,3)) == 2 then
				Spring.GiveOrderToUnit(builder, -choice, { pos.x, pos.y, pos.z, math.random(0,3) }, {})
				Spring.Echo("Team " .. teamID .. " building edge defense turret " .. tostring(choice))
			end
		end
	end
end

function AI:GetRoleCount(teamID, role)
	local count = 0
	local units = Spring.GetTeamUnits(teamID)
	for _, unitID in ipairs(units) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		local match = false
		if role == "Constructor" then
			for _, defID in ipairs(self.unitDefsByRole.Constructor or {}) do
				if unitDefID == defID then
					match = true
					break
				end
			end
		elseif role == "Extractor" then
			for _, defID in ipairs(self.unitDefsByRole.Extractor or {}) do
				if unitDefID == defID then
					match = true
					break
				end
			end
		elseif role == "Generator" then
			for _, defID in ipairs(self.unitDefsByRole.Generator or {}) do
				if unitDefID == defID then
					match = true
					break
				end
			end
		end
		if match then
			count = count + 1
		end
	end
	return count
end


--------------------------------------------------------------------------------
-- Utility Functions for Builders & Combat
--------------------------------------------------------------------------------

-- Check if a unit is a builder (i.e. a Constructor)
function AI:IsBuilder(unitDefID)
	-- First, check if it's a true constructor.
	for _, defID in ipairs(self.unitDefsByRole.Constructor or {}) do
		if unitDefID == defID then
			return true
		end
	end
	-- Then, allow commanders to be builders as well.
	for _, defID in ipairs(self.unitDefsByRole.Commander or {}) do
		if unitDefID == defID then
			return true
		end
	end
	return false
end


function AI:FindAnyBuilder(teamID)
	local units = Spring.GetTeamUnits(teamID)
	for _, unitID in ipairs(units) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		if self:IsBuilder(unitDefID) then
			return unitID
		end
	end
	return nil
end

-- Find an available builder (idle constructor) for a given team
function AI:FindAvailableBuilder(teamID)
	local units = Spring.GetTeamUnits(teamID)
	for _, unitID in ipairs(units) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		if self:IsBuilder(unitDefID) then
			local cmdQueue = Spring.GetCommandQueue(unitID, 0)
			if cmdQueue == 0 then
				return unitID
			end
		end
	end
	return nil
end

function AI:FindAvailableConstructor(teamID)
	local units = Spring.GetTeamUnits(teamID)
	for _, unitID in ipairs(units) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		for _, defID in ipairs(self.unitDefsByRole.Constructor or {}) do
			if unitDefID == defID then
				local cmdQueue = Spring.GetCommandQueue(unitID, 0)
				if cmdQueue == 0 then
					return unitID
				end
			end
		end
	end
	return nil
end


-- Check if a unit is combat-relevant (not a builder or factory)
function AI:IsCombatUnit(unitDefID)
	for role, unitList in pairs(self.unitDefsByRole) do
		if role == "Factory" or role == "Constructor" or role == "Commander" then
			for _, defID in ipairs(unitList) do
				if defID == unitDefID then
					return false
				end
			end
		end
	end
	return true
end

--------------------------------------------------------------------------------
-- AI Build Functions
--------------------------------------------------------------------------------

-- Build unit: select a unit from a given role and order a nearby builder to construct it.
function AI:GetCommanderTechLevel(teamID)
	local units = Spring.GetTeamUnits(teamID)
	for _, unitID in ipairs(units) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		for _, commanderDefID in ipairs(self.unitDefsByRole.Commander or {}) do
			if unitDefID == commanderDefID then
				-- Use lowercase custom parameter key "providetech"
				local provideTech = UnitDefs[unitDefID].customParams.providetech or "tech0"
				local techLevel = tonumber(provideTech:match("tech(%d)")) or 0
				return techLevel
			end
		end
	end
	return 0
end

function AI:BuildUnit(teamID, role)
	local buildOptions = self.unitDefsByRole[role]
	if not buildOptions or #buildOptions == 0 then return end

	local commanderTech = self:GetCommanderTechLevel(teamID)
	Spring.Echo("Team " .. teamID .. " commander tech level (providetech): " .. commanderTech)

	-- Determine team's faction (e.g., "fed" or "loz")
	local faction = self:GetTeamFaction(teamID)

	local validOptions = {}
	for _, option in ipairs(buildOptions) do
		local skip = false
		if role == "Constructor" then
			-- Skip commander units when building constructors.
			for _, commanderOption in ipairs(self.unitDefsByRole.Commander or {}) do
				if commanderOption == option then
					skip = true
					Spring.Echo("Skipping commander unit " .. tostring(option) .. " in Constructor build options")
					break
				end
			end
		end

		if not skip then
			if UnitDefs[option] then
				-- Faction filtering: if team faction is fed, skip options with "loz" in their name and vice versa.
				local optionName = UnitDefs[option].name or ""
				optionName = string.lower(optionName)
				if faction == "fed" and string.find(optionName, "loz") then
					skip = true
					Spring.Echo("Skipping option " .. tostring(option) .. " (" .. UnitDefs[option].name .. ") for Federation team")
				elseif faction == "loz" and string.find(optionName, "fed") then
					skip = true
					Spring.Echo("Skipping option " .. tostring(option) .. " (" .. UnitDefs[option].name .. ") for Loz team")
				end

				if not skip then
					local reqTech = (UnitDefs[option].customParams and UnitDefs[option].customParams.requiretech) or "tech10"
					reqTech = string.lower(reqTech)
					local unitTech = tonumber(reqTech:match("tech(%d)")) or 0
					if unitTech <= commanderTech then
						table.insert(validOptions, option)
					else
						Spring.Echo("Skipping build option " .. tostring(option) .. " (" .. UnitDefs[option].name .. ") (requires tech" .. unitTech .. ")")
					end
				end
			else
				Spring.Echo("Warning: UnitDefs[" .. tostring(option) .. "] is nil")
			end
		end
	end

	if #validOptions == 0 then
		Spring.Echo("No valid build options available for role " .. role .. " for team " .. teamID)
		return
	end

	local builder = self:FindAvailableBuilder(teamID)
	if not builder then return end

	local found = false
	local failedCount = 0
	for i = 1, #validOptions do
		local choice = validOptions[i]
		local unitName = (UnitDefs[choice] and UnitDefs[choice].name) or "Unknown"
		local pos = nil
		if role == "Extractor" then
			pos = self:GetMetalBuildPosition(teamID, builder)
		elseif role == "Generator" or role == "Supply" or role == "Storage" then
			pos = self:GetBaseBuildPosition(teamID, choice)
		else
			pos = self:GetBuildPosition(builder, choice)
		end

		if pos then
			Spring.GiveOrderToUnit(builder, -choice, { pos.x, pos.y, pos.z, math.random(0,3) }, {})
			Spring.Echo("Team " .. teamID .. " building " .. tostring(choice) .. " (" .. unitName .. ") (" .. role .. ")")
			if role == "Generator" then
				self.teamData[teamID].energyProjectInProgress = true
			end
			found = true
			break
		else
			failedCount = failedCount + 1
		end
	end

	if not found then
		Spring.Echo("Team " .. teamID .. " could not find any valid build positions for role " .. role .. " (failed " .. failedCount .. " attempts)")
	end
end




-- Assign a building project to a newly created constructor based on economic needs.
function AI:AssignBuildingProject(unitID, teamID)
	local mcurrent, mstorage = Spring.GetTeamResources(teamID, "metal")
	local ecurrent, estorage = Spring.GetTeamResources(teamID, "energy")
	local ratioMetal = mcurrent / mstorage
	local ratioEnergy = ecurrent / estorage
	local roleToBuild = nil

	if ratioMetal < 0.3 then
		roleToBuild = "Extractor"
	elseif ratioEnergy < 0.3 then
		roleToBuild = "Generator"
	elseif (Spring.GetTeamRulesParam(teamID, "supplyUsed") or 0) > (Spring.GetTeamRulesParam(teamID, "supplyMax") or 0) * 0.8 then
		roleToBuild = "Supply"
	else
		roleToBuild = "Constructor"
	end

	local buildOptions = self.unitDefsByRole[roleToBuild]
	if not buildOptions or #buildOptions == 0 then return end

	local choice = buildOptions[math.random(#buildOptions)]
	local pos = self:GetBuildPosition(unitID, choice)
	if pos then
		Spring.GiveOrderToUnit(unitID, -choice, { pos.x, pos.y, pos.z, math.random(0,3) }, {})
		Spring.Echo("Constructor " .. unitID .. " assigned to build " .. tostring(choice) .. " (" .. roleToBuild .. ")")
	else
		Spring.Echo("Constructor " .. unitID .. " could not find a valid build position for " .. tostring(choice))
	end
end

-- Execute the preset starting build order for a team.
function AI:ExecuteStartingBuildOrder(teamID)
	local teamData = self.teamData[teamID]
	local orderTable = self.startingBuildOrder
	local index = teamData.startingBuildOrderIndex

	if not index or index > #orderTable then
		teamData.startingBuildOrderActive = false
		Spring.Echo("Team " .. teamID .. " completed the starting build order.")
		return
	end

	local currentOrder = orderTable[index]
	local builtCount = self:GetRoleCount(teamID, currentOrder.role)

	-- If we haven't built enough units for this order, try issuing an order.
	if builtCount < currentOrder.count then
		local builder = self:FindAnyBuilder(teamID)  -- For starting orders, use a relaxed criteria.
		if builder then
			Spring.Echo("Team " .. teamID .. " starting build order: issuing " .. currentOrder.role)
			self:BuildUnit(teamID, currentOrder.role)
		end
	else
		Spring.Echo("Team " .. teamID .. " completed starting order for " .. currentOrder.role)
		teamData.startingBuildOrderIndex = index + 1
	end
end




function AI:GetBaseBuildPosition(teamID, buildingDefID)
	local base = self.teamData[teamID].basePosition
	if not base then return nil end
	local radius = self.teamData[teamID].baseRadius or 300
	local offsetX = math.random(-radius, radius)
	local offsetZ = math.random(-radius, radius)
	local pos = {
		x = base.x + offsetX,
		y = Spring.GetGroundHeight(base.x + offsetX, base.z + offsetZ),
		z = base.z + offsetZ,
	}
	local facing = math.random(0, 3)
	if Spring.TestBuildOrder(buildingDefID, pos.x, pos.y, pos.z, facing) == 2 then
		return pos
	end
	return nil
end


--------------------------------------------------------------------------------
-- Economic and Combat Modules
--------------------------------------------------------------------------------

function AI:UpdateEconomy(teamID)
	local teamData = self.teamData[teamID]
	-- If the starting build order is still active, do nothing here.
	if teamData.startingBuildOrderActive then
		return
	end

	local mcurrent, mstorage = Spring.GetTeamResources(teamID, "metal")
	local ecurrent, estorage = Spring.GetTeamResources(teamID, "energy")
	local ratioMetal = mcurrent / mstorage
	local ratioEnergy = ecurrent / estorage
	local constructors = teamData.constructors or 0
	local mexes = teamData.mexes or 0

	-- If team has fewer than 7 extractors, try to build one at an unoccupied metal spot.
	if mexes < 7 then
		local metalSpot = self:GetUnoccupiedMetalSpot(teamID)
		if metalSpot then
			self:BuildExtractorAtMetalSpot(teamID, metalSpot)
			return  -- Wait for extractor to be built.
		end
	end

	-- Ensure at least one energy project (Generator) is active.
	if not teamData.energyProjectInProgress then
		self:BuildUnit(teamID, "Generator")
		return
	end

	if constructors < 4 then
		self:BuildUnit(teamID, "Constructor")
	else
		if ratioMetal < 0.4 then
			self:BuildUnit(teamID, "Extractor")
		elseif ratioEnergy < 0.4 then
			self:BuildUnit(teamID, "Generator")
		elseif (Spring.GetTeamRulesParam(teamID, "supplyUsed") or 0) >
				(Spring.GetTeamRulesParam(teamID, "supplyMax") or 0) * 0.8 then
			self:BuildUnit(teamID, "Supply")
		else
			self:BuildUnit(teamID, "Generator")
		end
	end
end


function AI:UpdateCombat(teamID)
	local units = Spring.GetTeamUnits(teamID)
	for _, unitID in ipairs(units) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		if self:IsCombatUnit(unitDefID) then
			local enemyID = Spring.GetUnitNearestEnemy(unitID, 500, false)
			if enemyID then
				local ex, ey, ez = Spring.GetUnitPosition(enemyID)
				Spring.GiveOrderToUnit(unitID, CMD.FIGHT, { ex + math.random(-50,50), ey, ez + math.random(-50,50) }, {"shift"})
			end
		end
	end
end

-- Keep commander units near the base.
function AI:KeepCommandersInBase(teamID)
	local base = self.teamData[teamID].basePosition
	if not base then return end
	local units = Spring.GetTeamUnits(teamID)
	for _, unitID in ipairs(units) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		for _, commanderDefID in ipairs(self.unitDefsByRole.Commander or {}) do
			if unitDefID == commanderDefID then
				local x, y, z = Spring.GetUnitPosition(unitID)
				local dx = x - base.x
				local dz = z - base.z
				local distSq = dx * dx + dz * dz
				if distSq > 250 * 250 then
					Spring.GiveOrderToUnit(unitID, CMD.MOVE, { base.x, base.y, base.z }, {})
					Spring.Echo("Commander " .. unitID .. " returning to base")
				end
				break
			end
		end
	end
end

function AI:UpdateBaseArea(teamID)
	local base = self.teamData[teamID].basePosition
	if not base then return end

	local defaultRadius = 300
	local newRadius = defaultRadius

	-- Gather all friendly buildings (using our helper function)
	local buildings = {}
	local units = Spring.GetTeamUnits(teamID)
	for _, unitID in ipairs(units) do
		local ud = UnitDefs[Spring.GetUnitDefID(unitID)]
		-- Use our helper instead of ud.isBuilding:
		if ud and AI:IsStaticStructure(ud.id) then
			table.insert(buildings, unitID)
		end
	end

	-- Compute maximum distance from the base among friendly buildings
	local maxDist = 0
	for _, unitID in ipairs(buildings) do
		local x, y, z = Spring.GetUnitPosition(unitID)
		local dx = x - base.x
		local dz = z - base.z
		local dist = math.sqrt(dx * dx + dz * dz)
		if dist > maxDist then
			maxDist = dist
		end
	end

	newRadius = math.max(defaultRadius, maxDist + 50)

	-- Expand further based on building density.
	local buildingCount = #buildings
	local extra = math.floor(buildingCount / 10) * 50
	newRadius = newRadius + extra

	self.teamData[teamID].baseRadius = newRadius
	Spring.Echo("Team " .. teamID .. " base radius updated to " .. newRadius)
end



--------------------------------------------------------------------------------
-- Gadget Event Hooks
--------------------------------------------------------------------------------

-- UnitCreated: record base position, update constructor count, and assign projects.
-- In addition to your existing logic, update the extractor count.
-- In UnitCreated:
function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	-- Commander logic remains the same...
	for _, commanderDefID in ipairs(AI.unitDefsByRole.Commander or {}) do
		if unitDefID == commanderDefID then
			if not AI.teamData[unitTeam].basePosition then
				local x, y, z = Spring.GetUnitPosition(unitID)
				AI.teamData[unitTeam].basePosition = { x = x, y = y, z = z }
				Spring.Echo("Team " .. unitTeam .. " base set at (" .. x .. ", " .. y .. ", " .. z .. ")")
			end
			break
		end
	end

	-- Constructor detection (engineers only)
	for _, defID in ipairs(AI.unitDefsByRole.Constructor or {}) do
		if unitDefID == defID then
			AI.teamData[unitTeam].constructors = (AI.teamData[unitTeam].constructors or 0) + 1
			AI:AssignBuildingProject(unitID, unitTeam)
			break
		end
	end

	-- Extractor detection: update extractor count.
	for _, defID in ipairs(AI.unitDefsByRole.Extractor or {}) do
		if unitDefID == defID then
			AI.teamData[unitTeam].mexes = (AI.teamData[unitTeam].mexes or 0) + 1
			break
		end
	end

	-- Generator detection: update generator count and mark energy project complete.
	for _, defID in ipairs(AI.unitDefsByRole.Generator or {}) do
		if unitDefID == defID then
			AI.teamData[unitTeam].generators = (AI.teamData[unitTeam].generators or 0) + 1
			AI.teamData[unitTeam].energyProjectInProgress = false
			break
		end
	end
end

-- In UnitDestroyed, update the counts:
function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	-- Constructors
	for _, defID in ipairs(AI.unitDefsByRole.Constructor or {}) do
		if unitDefID == defID then
			AI.teamData[unitTeam].constructors = math.max((AI.teamData[unitTeam].constructors or 0) - 1, 0)
			break
		end
	end

	-- Extractors
	for _, defID in ipairs(AI.unitDefsByRole.Extractor or {}) do
		if unitDefID == defID then
			AI.teamData[unitTeam].mexes = math.max((AI.teamData[unitTeam].mexes or 0) - 1, 0)
			break
		end
	end

	-- Generators
	for _, defID in ipairs(AI.unitDefsByRole.Generator or {}) do
		if unitDefID == defID then
			AI.teamData[unitTeam].generators = math.max((AI.teamData[unitTeam].generators or 0) - 1, 0)
			break
		end
	end
end


-- Initialize: convert unit names to unitDefIDs.
function gadget:Initialize()
	local teams = Spring.GetTeamList()
	for i = 1, #teams do
		local teamID = teams[i]
		local luaAI = Spring.GetTeamLuaAI(teamID)
		-- Check if the team's Lua AI starts with "Enhanced Splinterfaction AI"
		if luaAI and luaAI ~= "" and string.sub(luaAI, 1, 28) == "Enhanced Splinterfaction AI" then
			AI.teamData[teamID].enabled = true
			Spring.Echo("Enhanced Splinterfaction AI enabled for team " .. teamID)
		else
			AI.teamData[teamID].enabled = false
			Spring.Echo("Enhanced Splinterfaction AI disabled for team " .. teamID)
		end
	end

	if AI and AI.ConvertUnitNamesToDefIDs then
		AI:ConvertUnitNamesToDefIDs()
		Spring.Echo("Unit definitions have been converted to unitDefIDs.")
	else
		Spring.Echo("Error: AI table or ConvertUnitNamesToDefIDs function not found!")
	end
end


function gadget:GameFrame(n)
	if n % 30 == 0 then
		for teamID, data in pairs(AI.teamData) do
			if data.enabled then
				-- Update base area, etc., as before...
				if n % 300 == 0 then
					AI:UpdateBaseArea(teamID)
				end

				-- Process starting build order until complete.
				if data.startingBuildOrderActive then
					AI:ExecuteStartingBuildOrder(teamID)
				else
					-- Normal economic and combat behavior...
					local anyEnemy = false
					local units = Spring.GetTeamUnits(teamID)
					for _, unitID in ipairs(units) do
						if Spring.GetUnitNearestEnemy(unitID, 500, false) then
							anyEnemy = true
							break
						end
					end
					if anyEnemy then
						data.state = "combat"
						AI:UpdateCombat(teamID)
					else
						data.state = "economic"
						AI:UpdateEconomy(teamID)
					end
				end

				AI:KeepCommandersInBase(teamID)
				if n % 600 == 0 then
					AI:BuildEdgeDefense(teamID)
				end
			end
		end
	end
end