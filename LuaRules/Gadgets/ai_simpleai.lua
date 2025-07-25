local enabled = false
local teams = Spring.GetTeamList()
local SimpleAITeamIDs = {}
local SimpleAITeamIDsCount = 0
local SimpleCheaterAITeamIDs = {}
local SimpleCheaterAITeamIDsCount = 0
local UDN = UnitDefNames
local wind = Game.windMax
local mapsizeX = Game.mapSizeX
local mapsizeZ = Game.mapSizeZ

local gameShortName = Game.gameShortName

-- team locals
SimpleFactoriesCount = {}
SimpleFactories = {}
SimpleT1Mexes = {}
SimpleConstructorCount = {}
SimpleFactoryDelay = {}
SimpleConstructorDelay = {}

for i = 1, #teams do
	local teamID = teams[i]
	local luaAI = Spring.GetTeamLuaAI(teamID)
	if luaAI and luaAI ~= "" and (string.sub(luaAI, 1, 8) == 'SimpleAI' or string.sub(luaAI, 1, 16) == 'SimpleDefenderAI' or string.sub(luaAI, 1, 19) == 'SimpleConstructorAI') then
		enabled = true
		SimpleAITeamIDsCount = SimpleAITeamIDsCount + 1
		SimpleAITeamIDs[SimpleAITeamIDsCount] = teamID

		SimpleFactoriesCount[teamID] = 0
		SimpleFactories[teamID] = {}
		SimpleT1Mexes[teamID] = 0
		SimpleConstructorCount[teamID] = 0
		SimpleFactoryDelay[teamID] = 0
		SimpleConstructorDelay[teamID] = 0
		SimpleCheaterAITeamIDsCount = SimpleCheaterAITeamIDsCount + 1
		SimpleCheaterAITeamIDs[SimpleCheaterAITeamIDsCount] = teamID
	end
end

function gadget:GetInfo()
	return {
		name = "SimpleAI",
		desc = "123",
		author = "Damgam",
		date = "2020",
		layer = -100,
		enabled = enabled,
	}
end

-------- lists
BadUnitsList = {}

if gameShortName == "SF" then
	BadUnitsList = {}
end

local BadUnitDefs = {}
local SimpleCommanderDefs = {}
local SimpleFactoriesDefs = {}
local SimpleConstructorDefs = {}
local SimpleExtractorDefs = {}
local SimpleGeneratorDefs = {}
local SimpleConverterDefs = {}
local SimpleTurretDefs = {}
local SimpleStorageDefs = {}
local SimpleSupplyDefs = {}
local SimpleUndefinedBuildingDefs = {}
local SimpleUndefinedUnitDefs = {}

for unitDefID, unitDef in pairs(UnitDefs) do
	BadUnitDef = false
	for a = 1,#BadUnitsList do
		if BadUnitsList[a] == unitDef.name then
			BadUnitDef = true
			break
		else
			BadUnitDef = false
		end
	end
	if BadUnitDef == false then
		if unitDef.customParams.unitrole and unitDef.customParams.unitrole == "Commander" then
			SimpleCommanderDefs[#SimpleCommanderDefs + 1] = unitDefID
		elseif unitDef.isFactory and #unitDef.buildOptions > 0 then
			SimpleFactoriesDefs[#SimpleFactoriesDefs + 1] = unitDefID
		elseif unitDef.canMove and unitDef.isBuilder and #unitDef.buildOptions > 0 or unitDef.customParams.unittype == "mobile" and unitDef.customParams.unitrole == "Builder" then
			SimpleConstructorDefs[#SimpleConstructorDefs + 1] = unitDefID
		elseif unitDef.extractsMetal > 0 or (unitDef.customParams and unitDef.customParams.metal_extractor) then
			SimpleExtractorDefs[#SimpleExtractorDefs + 1] = unitDefID
		elseif (unitDef.energyMake > 19 and (not unitDef.energyUpkeep or unitDef.energyUpkeep < 10)) or (unitDef.windGenerator > 0 and wind > 10) or unitDef.tidalGenerator > 0 or (unitDef.customParams and unitDef.customParams.solar) or unitDef.customParams.simpleaiunittype == "energygenerator" then
			SimpleGeneratorDefs[#SimpleGeneratorDefs + 1] = unitDefID
		elseif unitDef.customParams and unitDef.customParams.energyconv_capacity and unitDef.customParams.energyconv_efficiency then
			SimpleConverterDefs[#SimpleConverterDefs + 1] = unitDefID
		elseif unitDef.isBuilding and #unitDef.weapons > 0 then
			SimpleTurretDefs[#SimpleTurretDefs + 1] = unitDefID
		elseif unitDef.customParams.simpleaiunittype == "supplydepot" then
			SimpleSupplyDefs[#SimpleSupplyDefs + 1] = unitDefID
		elseif unitDef.customParams.simpleaiunittype == "storage" then
			SimpleStorageDefs[#SimpleStorageDefs + 1] = unitDefID



		elseif not unitDef.canMove then
			SimpleUndefinedBuildingDefs[#SimpleUndefinedBuildingDefs + 1] = unitDefID
		else
			SimpleUndefinedUnitDefs[#SimpleUndefinedUnitDefs + 1] = unitDefID
		end
	end
end

-------- functions

local function SimpleGetClosestMexSpot(x, z)
	local bestSpot
	local bestDist = math.huge
	local metalSpots = GG.metalMakerSpots
	if metalSpots then
		for i = 1, #metalSpots do
			local spot = metalSpots[i]
			local dx, dz = x - spot.x, z - spot.z
			local dist = dx * dx + dz * dz
			local units = Spring.GetUnitsInCylinder(spot.x, spot.z, 128)
			--local height = Spring.GetGroundHeight(spot.x, spot.z)
			if dist < bestDist and #units == 0 then
				--and height > 0 then
				bestSpot = spot
				bestDist = dist
			end
		end
	end
	return bestSpot
end

local function SimpleBuildOrder(cUnitID, building)
	searchRange = 0
	for b2 = 1,20 do
		searchRange = searchRange + 300
		local team = Spring.GetUnitTeam(cUnitID)
		local cunitposx, _, cunitposz = Spring.GetUnitPosition(cUnitID)
		local units = Spring.GetUnitsInCylinder(cunitposx, cunitposz, searchRange, team)
		if #units > 1 then
			local buildnear = units[math.random(1, #units)]
			local refDefID = Spring.GetUnitDefID(buildnear)
			local isBuilding = UnitDefs[refDefID].isBuilding
			local isCommander = (UnitDefs[refDefID].name == "armcom" or UnitDefs[refDefID].name == "corcom")
			local isExtractor = UnitDefs[refDefID].extractsMetal > 0
			if (isBuilding or isCommander) then-- and not isExtractor then
				local refx, refy, refz = Spring.GetUnitPosition(buildnear)
				local reffootx = UnitDefs[refDefID].xsize * 8
				local reffootz = UnitDefs[refDefID].zsize * 8
				local spacing = math.random(32, 256)
				local testspacing = spacing * 0.75
				local buildingDefID = building
				local r = math.random(0, 3)
				if r == 0 then
					local bposx = refx
					local bposz = refz + reffootz + spacing
					local bposy = Spring.GetGroundHeight(bposx, bposz)--+100
					local testpos = Spring.TestBuildOrder(buildingDefID, bposx, bposy, bposz, r)
					local nearbyunits = Spring.GetUnitsInRectangle(bposx - testspacing, bposz - testspacing, bposx + testspacing, bposz + testspacing)
					if testpos == 2 and #nearbyunits <= 0 then
						Spring.GiveOrderToUnit(cUnitID, -buildingDefID, { bposx, bposy, bposz, r }, { "shift" })
						break
					end
				elseif r == 1 then
					local bposx = refx + reffootx + spacing
					local bposz = refz
					local bposy = Spring.GetGroundHeight(bposx, bposz)--+100
					local testpos = Spring.TestBuildOrder(buildingDefID, bposx, bposy, bposz, r)
					local nearbyunits = Spring.GetUnitsInRectangle(bposx - testspacing, bposz - testspacing, bposx + testspacing, bposz + testspacing)
					if testpos == 2 and #nearbyunits <= 0 then
						Spring.GiveOrderToUnit(cUnitID, -buildingDefID, { bposx, bposy, bposz, r }, { "shift" })
						break
					end
				elseif r == 2 then
					local bposx = refx
					local bposz = refz - reffootz - spacing
					local bposy = Spring.GetGroundHeight(bposx, bposz)--+100
					local testpos = Spring.TestBuildOrder(buildingDefID, bposx, bposy, bposz, r)
					local nearbyunits = Spring.GetUnitsInRectangle(bposx - testspacing, bposz - testspacing, bposx + testspacing, bposz + testspacing)
					if testpos == 2 and #nearbyunits <= 0 then
						Spring.GiveOrderToUnit(cUnitID, -buildingDefID, { bposx, bposy, bposz, r }, { "shift" })
						break
					end
				elseif r == 3 then
					local bposx = refx - reffootx - spacing
					local bposz = refz
					local bposy = Spring.GetGroundHeight(bposx, bposz)--+100
					local testpos = Spring.TestBuildOrder(buildingDefID, bposx, bposy, bposz, r)
					local nearbyunits = Spring.GetUnitsInRectangle(bposx - testspacing, bposz - testspacing, bposx + testspacing, bposz + testspacing)
					if testpos == 2 and #nearbyunits <= 0 then
						Spring.GiveOrderToUnit(cUnitID, -buildingDefID, { bposx, bposy, bposz, r }, { "shift" })
						break
					end
				end
			end
			--local buildingDefID = UnitDefNames.building.id
			--local testpos = Spring.TestBuildOrder(buildingDefID, bposx, bposy, bposz, facing)
		end
	end
end

local function SimpleConstructionProjectSelection(unitID, unitDefID, unitName, unitTeam, allyTeamID, units, allunits, type)
	success = false

	local supplyUsed, supplyMax = math.round(Spring.GetTeamRulesParam(unitTeam, "supplyUsed") or 0), math.round(Spring.GetTeamRulesParam(unitTeam, "supplyMax") or 0)
	local mcurrent, mstorage, _, mincome, mexpense = Spring.GetTeamResources(unitTeam, "metal")
	local ecurrent, estorage, _, eincome, eexpense = Spring.GetTeamResources(unitTeam, "energy")
	local unitposx, unitposy, unitposz = Spring.GetUnitPosition(unitID)

	local unitCommands = Spring.GetCommandQueue(unitID, 0)
	local buildOptions = UnitDefs[unitDefID].buildOptions
	-- Builders
	for b1 = 1,10 do
		if type == "Builder" or type == "Commander" then
			SimpleFactoryDelay[unitTeam] = SimpleFactoryDelay[unitTeam]-1
			SimpleConstructorDelay[unitTeam] = SimpleConstructorDelay[unitTeam]-1
			local r = math.random(0, 20) -- Used: 8
			local mexspotpos = SimpleGetClosestMexSpot(unitposx, unitposz)
			if SimpleConstructorCount[unitTeam] < 2 then
				local project = SimpleConstructorDefs[math.random(1, #SimpleConstructorDefs)]
				for i2 = 1,#buildOptions do
					if buildOptions[i2] == project then
						local x, y, z = Spring.GetUnitPosition(unitID)
						Spring.GiveOrderToUnit(unitID, -project, { x+math.random(-64,64), y, z+math.random(-64,64), 0 }, 0)
						Spring.Echo("Success! Project Type: Constructor.")
						success = true
						break
					end
				end
			elseif mexspotpos and (SimpleT1Mexes[unitTeam] < 6) then
				local project = SimpleExtractorDefs[math.random(1, #SimpleExtractorDefs)]
				for i2 = 1,#buildOptions do
					if buildOptions[i2] == project then
						Spring.GiveOrderToUnit(unitID, -project, { mexspotpos.x, mexspotpos.y, mexspotpos.z, 0 }, { "shift" })
						Spring.Echo("Success! Project Type: Extractor.")
						success = true
						break
					end
				end
			elseif ecurrent < estorage*0.50 or eincome <= 200 then
				local project = SimpleGeneratorDefs[math.random(1, #SimpleGeneratorDefs)]
				for i2 = 1,#buildOptions do
					if buildOptions[i2] == project then
						SimpleBuildOrder(unitID, project)
						Spring.Echo("Success! Project Type: Generator.")
						success = true
						break
					end
				end
			elseif SimpleFactoriesCount[unitTeam] > 0 and ((supplyUsed > supplyMax * 0.50 and supplyMax < 950) or supplyMax < 20) then
				local project = SimpleSupplyDefs[math.random(1, #SimpleSupplyDefs)]
				for i2 = 1,#buildOptions do
					if buildOptions[i2] == project then
						SimpleBuildOrder(unitID, project)
						Spring.Echo("Success! Project Type: Supply Depot.")
						success = true
						break
					end
				end
			elseif (ecurrent > estorage * 0.50 and mcurrent > mstorage * 0.50) and SimpleConstructorDelay[unitTeam] > 0 and SimpleFactoryDelay[unitTeam] <= 0 and eincome >= 200 then
				local project = SimpleFactoriesDefs[math.random(1, #SimpleFactoriesDefs)]
				for i2 = 1,#buildOptions do
					if buildOptions[i2] == project and (SimpleFactories[unitTeam][project] or 0 < 10) then
						SimpleFactoryDelay[unitTeam] = 60*SimpleFactoriesCount[unitTeam]
						SimpleBuildOrder(unitID, project)
						Spring.Echo("Success! Project Type: Factory.")
						success = true
						break
					end
				end
			elseif (ecurrent > estorage * 0.50 and mcurrent > mstorage * 0.50) and SimpleConstructorDelay[unitTeam] <= 0 then
				SimpleConstructorDelay[unitTeam] = 3
				if type == "Commander" then
					local project = SimpleCommanderDefs[math.random(1,#SimpleCommanderDefs)]
					for i2 = 1,#buildOptions do
						if buildOptions[i2] == project then
							SimpleConstructorDelay[unitTeam] = 60
							local x, y, z = Spring.GetUnitPosition(unitID)
							Spring.GiveOrderToUnit(unitID, -project, { x+math.random(-64,64), y, z+math.random(-64,64), 0 }, 0)
							Spring.Echo("Success! Project Type: Commander.")
							success = true
							break
						end
					end
				end
				if not success then
					if SimpleConstructorCount[unitTeam] < 10 and supplyUsed < supplyMax - 5 and math.random(0,1) == 0 then
						local project = SimpleConstructorDefs[math.random(1, #SimpleConstructorDefs)]
						for i2 = 1,#buildOptions do
							if buildOptions[i2] == project then
								SimpleConstructorDelay[unitTeam] = 10
								local x, y, z = Spring.GetUnitPosition(unitID)
								Spring.GiveOrderToUnit(unitID, -project, { x+math.random(-64,64), y, z+math.random(-64,64), 0 }, 0)
								Spring.Echo("Success! Project Type: Constructor.")
								success = true
								break
							end
						end
					end
				end
			elseif (ecurrent > estorage * 0.90 and mcurrent > mstorage * 0.90) then
				local project = SimpleStorageDefs[math.random(1, #SimpleStorageDefs)]
				for i2 = 1,#buildOptions do
					if buildOptions[i2] == project then
						SimpleBuildOrder(unitID, project)
						Spring.Echo("Success! Project Type: Storage.")
						success = true
						break
					end
				end
			elseif mcurrent < mstorage * 0.50 then
				if mexspotpos and type ~= "Commander" then
					local project = SimpleExtractorDefs[math.random(1, #SimpleExtractorDefs)]
					for i2 = 1,#buildOptions do
						if buildOptions[i2] == project then
							Spring.GiveOrderToUnit(unitID, -project, { mexspotpos.x, mexspotpos.y, mexspotpos.z, 0 }, { "shift" })
							Spring.Echo("Success! Project Type: Extractor.")
							for i3 = 1,50 do
								local projectturret = SimpleTurretDefs[math.random(1, #SimpleTurretDefs)]
								if buildOptions[i3] == projectturret then
									Spring.GiveOrderToUnit(unitID, -projectturret, { mexspotpos.x+100, mexspotpos.y, mexspotpos.z, math.random(0,3) }, { "shift" })
									break
								end
							end
							for i3 = 1,50 do
								local projectturret = SimpleTurretDefs[math.random(1, #SimpleTurretDefs)]
								if buildOptions[i3] == projectturret then
									Spring.GiveOrderToUnit(unitID, -projectturret, { mexspotpos.x-100, mexspotpos.y, mexspotpos.z, math.random(0,3) }, { "shift" })
									break
								end
							end
							for i3 = 1,50 do
								local projectturret = SimpleTurretDefs[math.random(1, #SimpleTurretDefs)]
								if buildOptions[i3] == projectturret then
									Spring.GiveOrderToUnit(unitID, -projectturret, { mexspotpos.x, mexspotpos.y, mexspotpos.z-100, math.random(0,3) }, { "shift" })
									break
								end
							end
							for i3 = 1,50 do
								local projectturret = SimpleTurretDefs[math.random(1, #SimpleTurretDefs)]
								if buildOptions[i3] == projectturret then
									Spring.GiveOrderToUnit(unitID, -projectturret, { mexspotpos.x, mexspotpos.y, mexspotpos.z-100, math.random(0,3) }, { "shift" })
									break
								end
							end
							for i3 = 1,50 do
								local projectturret = SimpleTurretDefs[math.random(1, #SimpleTurretDefs)]
								if buildOptions[i3] == projectturret then
									Spring.GiveOrderToUnit(unitID, -projectturret, { mexspotpos.x+100, mexspotpos.y, mexspotpos.z+100, math.random(0,3) }, { "shift" })
									break
								end
							end
							for i3 = 1,50 do
								local projectturret = SimpleTurretDefs[math.random(1, #SimpleTurretDefs)]
								if buildOptions[i3] == projectturret then
									Spring.GiveOrderToUnit(unitID, -projectturret, { mexspotpos.x-100, mexspotpos.y, mexspotpos.z+100, math.random(0,3) }, { "shift" })
									break
								end
							end
							for i3 = 1,50 do
								local projectturret = SimpleTurretDefs[math.random(1, #SimpleTurretDefs)]
								if buildOptions[i3] == projectturret then
									Spring.GiveOrderToUnit(unitID, -projectturret, { mexspotpos.x+100, mexspotpos.y, mexspotpos.z-100, math.random(0,3) }, { "shift" })
									break
								end
							end
							for i3 = 1,50 do
								local projectturret = SimpleTurretDefs[math.random(1, #SimpleTurretDefs)]
								if buildOptions[i3] == projectturret then
									Spring.GiveOrderToUnit(unitID, -projectturret, { mexspotpos.x-100, mexspotpos.y, mexspotpos.z-100, math.random(0,3) }, { "shift" })
									break
								end
							end
							success = true
							break
						end
					end

				end

			elseif r == 0 or r == 1 or r == 2 or r == 3 or r == 4 or r == 5 then
				local project = SimpleTurretDefs[math.random(1, #SimpleTurretDefs)]
				for i2 = 1,#buildOptions do
					if buildOptions[i2] == project then
						SimpleBuildOrder(unitID, project)
						Spring.Echo("Success! Project Type: Turret.")
						success = true
						break
					end
				end
			elseif (SimpleFactoriesCount[unitTeam] < 6 and SimpleFactoryDelay[unitTeam] <= 0) or ((mcurrent > mstorage * 0.75 and ecurrent > estorage * 0.75) and SimpleFactoryDelay[unitTeam] <= 0) then
				local project = SimpleFactoriesDefs[math.random(1, #SimpleFactoriesDefs)]
				SimpleFactoryDelay[unitTeam] = 10
				for i2 = 1,#buildOptions do
					if buildOptions[i2] == project and (SimpleFactories[unitTeam][project] or 0 < 2) then
						SimpleBuildOrder(unitID, project)
						SimpleFactoryDelay[unitTeam] = 60*SimpleFactoriesCount[unitTeam]
						Spring.Echo("Success! Project Type: Factory.")
						success = true
						break
					end
				end
			elseif r == 6 and type ~= "Commander" then
				local mapcenterX = mapsizeX/2
				local mapcenterZ = mapsizeZ/2
				local mapcenterY = Spring.GetGroundHeight(mapcenterX, mapcenterZ)
				local mapdiagonal = math.ceil(math.sqrt((mapsizeX*mapsizeX)+(mapsizeZ*mapsizeZ)))
				Spring.GiveOrderToUnit(unitID, CMD.RECLAIM,{mapcenterX+math.random(-100,100),mapcenterY,mapcenterZ+math.random(-100,100),mapdiagonal}, 0)
				success = true
			elseif r == 7 and type ~= "Commander" then
				local mapcenterX = mapsizeX/2
				local mapcenterZ = mapsizeZ/2
				local mapcenterY = Spring.GetGroundHeight(mapcenterX, mapcenterZ)
				local mapdiagonal = math.ceil(math.sqrt((mapsizeX*mapsizeX)+(mapsizeZ*mapsizeZ)))
				Spring.GiveOrderToUnit(unitID, CMD.REPAIR,{mapcenterX+math.random(-100,100),mapcenterY,mapcenterZ+math.random(-100,100),mapdiagonal}, 0)
				success = true
			elseif r == 8 and type == "Commander" then
				local project = SimpleCommanderDefs[math.random(1,#SimpleCommanderDefs)]
				for i2 = 1,#buildOptions do
					if buildOptions[i2] == project then
						SimpleBuildOrder(unitID, project)
						Spring.Echo("Success! Project Type: Commander.")
						success = true
						break
					end
				end
			else
				local r2 = math.random(0, 1)
				if r2 == 0 then
					local r3 = math.random(0, 1)
					if r3 == 0 then
						local project = SimpleUndefinedBuildingDefs[math.random(1, #SimpleUndefinedBuildingDefs)]
						for i2 = 1,#buildOptions do
							if buildOptions[i2] == project then
								SimpleBuildOrder(unitID, project)
								Spring.Echo("Success! Project Type: Other Building.")
								success = true
								break
							end
						end
					else
						local project = SimpleUndefinedUnitDefs[math.random(1, #SimpleUndefinedUnitDefs)]
						for i2 = 1,#buildOptions do
							if buildOptions[i2] == project then
								SimpleBuildOrder(unitID, project)
								Spring.Echo("Success! Project Type: Other Unit.")
								success = true
								break
							end
						end
					end
				else
					local project = SimpleTurretDefs[math.random(1, #SimpleTurretDefs)]
					for i2 = 1,#buildOptions do
						if buildOptions[i2] == project then
							SimpleBuildOrder(unitID, project)
							Spring.Echo("Success! Project Type: Turret.")
							success = true
							break
						end
					end
				end
			end
		elseif type == "Factory" then
			if #Spring.GetFullBuildQueue(unitID, 0) < 10 and supplyUsed < supplyMax*0.95 then
				local r = math.random(0, 5)
				local luaAI = Spring.GetTeamLuaAI(unitTeam)
				if r == 0 or string.sub(luaAI, 1, 19) == 'SimpleConstructorAI' or supplyUsed > supplyMax*0.85 then
					local project = SimpleConstructorDefs[math.random(1, #SimpleConstructorDefs)]
					for i2 = 1,#buildOptions do
						if buildOptions[i2] == project then
							local x, y, z = Spring.GetUnitPosition(unitID)
							Spring.GiveOrderToUnit(unitID, -project, { x, y, z, 0 }, 0)
							Spring.Echo("Success! Project Type: Constructor.")
							success = true
							break
						end
					end
				else
					local project = SimpleUndefinedUnitDefs[math.random(1, #SimpleUndefinedUnitDefs)]
					for i2 = 1,#buildOptions do
						if buildOptions[i2] == project then
							local x, y, z = Spring.GetUnitPosition(unitID)
							Spring.GiveOrderToUnit(unitID, -project, { x, y, z, 0 }, 0)
							Spring.Echo("Success! Project Type: Unit.")
							success = true
							break
						end
					end
				end
			else
				success = true
			end
		end
		if success == true then
			break
		end
	end
end

function gadget:GameOver()
	gadgetHandler:RemoveGadget(self)
end

if gadgetHandler:IsSyncedCode() then

	function gadget:GameFrame(n)
		if n%1800 == 0 then
			for j = 1, #SimpleCheaterAITeamIDs do
				local teamID = SimpleCheaterAITeamIDs[j]
				if teamID == SimpleCheaterAITeamIDs[j] then
					local mcurrent, mstorage, _, mincome, mexpense = Spring.GetTeamResources(teamID, "metal")
					local ecurrent, estorage, _, eincome, eexpense = Spring.GetTeamResources(teamID, "energy")
					-- --cheats
					if mcurrent < mstorage * 0.20 then
						Spring.SetTeamResource(teamID, "m", mstorage * 0.50)
					end
					if ecurrent < estorage * 0.20 then
						Spring.SetTeamResource(teamID, "e", estorage * 0.50)
					end
				end
			end
		end
		if n % 15 == 0 then
			for i = 1, SimpleAITeamIDsCount do
				if n%(15*SimpleAITeamIDsCount) == 15*(i-1) then
					local teamID = SimpleAITeamIDs[i]
					local _, _, isDead, _, faction, allyTeamID = Spring.GetTeamInfo(teamID)
					local mcurrent, mstorage, _, mincome, mexpense = Spring.GetTeamResources(teamID, "metal")
					local ecurrent, estorage, _, eincome, eexpense = Spring.GetTeamResources(teamID, "energy")
					local units = Spring.GetTeamUnits(teamID)
					local allunits = Spring.GetAllUnits()
					for k = 1, #units do
						local unitID = units[k]
						local unitDefID = Spring.GetUnitDefID(unitID)
						local unitName = UnitDefs[unitDefID].name
						local unitTeam = teamID
						local unitHealth, unitMaxHealth, _, _, unitBuildProgress = Spring.GetUnitHealth(unitID)
						local unitMaxRange = Spring.GetUnitMaxRange(unitID)
						local unitCommands = Spring.GetCommandQueue(unitID, 0)
						local unitposx, unitposy, unitposz = Spring.GetUnitPosition(unitID)
						--Spring.Echo(faction)

						--if faction == "arm" then

						-- builders
						for u = 1, #SimpleCommanderDefs do
							if unitDefID == SimpleCommanderDefs[u] then
								local nearestEnemyCloak = Spring.GetUnitNearestEnemy(unitID, 2000, false)
								if nearestEnemyCloak and ecurrent > 1000 then
									Spring.GiveOrderToUnit(unitID, 37382, {1}, 0)
								else
									Spring.GiveOrderToUnit(unitID, 37382, {0}, 0)
								end


								local nearestEnemy = Spring.GetUnitNearestEnemy(unitID, 250, true)
								local unitHealthPercentage = (unitHealth/unitMaxHealth)*100

								if nearestEnemy and unitHealthPercentage > 30 then
									if ecurrent < estorage*0.9 then
										Spring.SetTeamResource(teamID, "e", estorage*0.9)
									end
									Spring.GiveOrderToUnit(unitID, CMD.DGUN, {nearestEnemy}, 0)
									local nearestEnemies = Spring.GetUnitsInCylinder(unitposx, unitposz, 300)
									for x = 1,#nearestEnemies do
										local enemy = nearestEnemies[x]
										if Spring.GetUnitTeam(enemy) == Spring.GetUnitTeam(nearestEnemy) and enemy ~= nearestEnemy then
											Spring.GiveOrderToUnit(unitID, CMD.DGUN, {enemy}, {"shift"})
										end
									end
									Spring.GiveOrderToUnit(unitID, CMD.MOVE, {unitposx, unitposy, unitposz}, {"shift"})
								elseif nearestEnemy then
									for x = 1,10 do
										local targetUnit = units[math.random(1,#units)]
										if UnitDefs[Spring.GetUnitDefID(targetUnit)].isBuilding == true then
											local tUnitX, tUnitY, tUnitZ = Spring.GetUnitPosition(targetUnit)
											Spring.GiveOrderToUnit(unitID, CMD.MOVE, { tUnitX + math.random(-100, 100), tUnitY, tUnitZ + math.random(-100, 100) }, 0)
											break
										end
									end
								end
							end
						end

						for u = 1, #SimpleConstructorDefs do
							if unitDefID == SimpleConstructorDefs[u] then
								local unitHealthPercentage = (unitHealth/unitMaxHealth)*100
								local nearestEnemy = Spring.GetUnitNearestEnemy(unitID, 500, true)
								if nearestEnemy and unitHealthPercentage > 90 then
									Spring.GiveOrderToUnit(unitID, CMD.RECLAIM, {nearestEnemy}, 0)
								elseif nearestEnemy then
									for x = 1,100 do
										local targetUnit = units[math.random(1,#units)]
										if UnitDefs[Spring.GetUnitDefID(targetUnit)].isBuilding == true then
											local tUnitX, tUnitY, tUnitZ = Spring.GetUnitPosition(targetUnit)
											Spring.GiveOrderToUnit(unitID, CMD.MOVE, { tUnitX + math.random(-100, 100), tUnitY, tUnitZ + math.random(-100, 100) }, 0)
											break
										end
									end
								end
							end
						end

						if unitCommands == 0 then
							for u = 1, #SimpleConstructorDefs do
								if unitDefID == SimpleConstructorDefs[u] then
									SimpleConstructionProjectSelection(unitID, unitDefID, unitName, unitTeam, allyTeamID, units, allunits, "Builder")
									break
								end
							end
							for u = 1, #SimpleCommanderDefs do
								if unitDefID == SimpleCommanderDefs[u] then
									SimpleConstructionProjectSelection(unitID, unitDefID, unitName, unitTeam, allyTeamID, units, allunits, "Commander")
									break
								end
							end

							for u = 1, #SimpleFactoriesDefs do
								if unitDefID == SimpleFactoriesDefs[u] then
									SimpleConstructionProjectSelection(unitID, unitDefID, unitName, unitTeam, allyTeamID, units, allunits, "Factory")
									break
								end
							end

							-- army

							for u = 1, #SimpleUndefinedUnitDefs do

								if unitDefID == SimpleUndefinedUnitDefs[u] then
									local luaAI = Spring.GetTeamLuaAI(teamID)
									if string.sub(luaAI, 1, 16) == 'SimpleDefenderAI' then
										for t = 1,10 do
											local targetUnit = allunits[math.random(1,#allunits)]
											if Spring.GetUnitAllyTeam(targetUnit) == allyTeamID then
												local tUnitX, tUnitY, tUnitZ = Spring.GetUnitPosition(targetUnit)
												Spring.GiveOrderToUnit(unitID, CMD.FIGHT, { tUnitX + math.random(-100, 100), tUnitY, tUnitZ + math.random(-100, 100) }, { "shift", "alt", "ctrl" })
												break
											end
										end
									else
										local targetUnitNear = Spring.GetUnitNearestEnemy(unitID, 2000, false)
										if targetUnitNear then
											local tUnitX, tUnitY, tUnitZ = Spring.GetUnitPosition(targetUnitNear)
											Spring.GiveOrderToUnit(unitID, CMD.FIGHT, { tUnitX + math.random(-100, 100), tUnitY, tUnitZ + math.random(-100, 100) }, { "shift", "alt", "ctrl" })
										elseif n%3600 <= 15*SimpleAITeamIDsCount then
											local targetUnit = Spring.GetUnitNearestEnemy(unitID, 999999, false)
											local tUnitX, tUnitY, tUnitZ = Spring.GetUnitPosition(targetUnit)
											Spring.GiveOrderToUnit(unitID, CMD.FIGHT, { tUnitX + math.random(-100, 100), tUnitY, tUnitZ + math.random(-100, 100) }, { "shift", "alt", "ctrl" })
										end
										break
									end
								end
							end
						end
					end
				end
			end
		end
	end

	function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
		local unitName = UnitDefs[unitDefID].name
		for i = 1, SimpleAITeamIDsCount do
			if SimpleAITeamIDs[i] == unitTeam then
				for u = 1, #SimpleFactoriesDefs do
					if unitDefID == SimpleFactoriesDefs[u] then
						SimpleFactoriesCount[unitTeam] = SimpleFactoriesCount[unitTeam] + 1
						if SimpleFactories[unitTeam][unitDefID] then
							SimpleFactories[unitTeam][unitDefID] = SimpleFactories[unitTeam][unitDefID] + 1
						else
							SimpleFactories[unitTeam][unitDefID] = 1
						end
						break
					end
				end
				for u = 1, #SimpleExtractorDefs do
					if unitDefID == SimpleExtractorDefs[u] then
						SimpleT1Mexes[unitTeam] = SimpleT1Mexes[unitTeam] + 1
						break
					end
				end
				for u = 1, #SimpleConstructorDefs do
					if unitDefID == SimpleConstructorDefs[u] then
						SimpleConstructorCount[unitTeam] = SimpleConstructorCount[unitTeam] + 1
						break
					end
				end
			end
		end
	end

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
		local unitName = UnitDefs[unitDefID].name
		for i = 1, SimpleAITeamIDsCount do
			if SimpleAITeamIDs[i] == unitTeam then
				for u = 1, #SimpleFactoriesDefs do
					if unitDefID == SimpleFactoriesDefs[u] then
						SimpleFactoriesCount[unitTeam] = SimpleFactoriesCount[unitTeam] - 1
						if SimpleFactories[unitTeam][unitDefID] then
							SimpleFactories[unitTeam][unitDefID] = SimpleFactories[unitTeam][unitDefID] - 1
						else
							SimpleFactories[unitTeam][unitDefID] = 0
						end
						break
					end
				end
				for u = 1, #SimpleExtractorDefs do
					if unitDefID == SimpleExtractorDefs[u] then
						SimpleT1Mexes[unitTeam] = SimpleT1Mexes[unitTeam] - 1
						break
					end
				end
				for u = 1, #SimpleConstructorDefs do
					if unitDefID == SimpleConstructorDefs[u] then
						SimpleConstructorCount[unitTeam] = SimpleConstructorCount[unitTeam] - 1
						break
					end
				end
			end
		end
	end


end
