function gadget:GetInfo()
	return {
		name 	= "Death Spawns",
		desc	= "Spawns a Container when a unit dies",
		author	= "",
		date	= "2022",
		license	= "Public domain",
		layer	= 0,
		enabled	= true	--	loaded by default?
	}
end

if gadgetHandler:IsSyncedCode() then

	local partsList = {
		"compressedtanks",
		"laserturret",
		"medtankturret",
		"nanopylon",
		"techdodad",
		"wheels",
		"backpack",
		"cloakhalfmast",
		"engine",
		"factoryarm",
		"factorypower",
		"gun",
		"leg",
		"levelerarm",
		"missilelauncher",
		"riotgun",
		"techpylon",
		"wheelassembly",
		"wings",
		"randomdeadtank1",
	}

	local function Norm(x, y, z)
		return math.sqrt(x*x + y*y + z*z)
	end

	local function Normalize(x, y, z)
		local N = Norm(x, y, z)
		return x/N, y/N, z/N
	end

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	
		if math.random(1,2) == 1 then
			_, _, _, _, buildProgress = Spring.GetUnitHealth(unitID)
			if buildProgress == 1 then
				local unitName = UnitDefs[unitDefID].name
				local unitCostMetal = UnitDefs[unitDefID].metalCost
				local unitCostEnergy = UnitDefs[unitDefID].energyCost
				local unit = UnitDefs[unitDefID]
				posx, posy, posz = Spring.GetUnitPosition(unitID)
				-- Spring.Echo("[Death Spawns] Unit Name is " .. unitName)
				local featureID = Spring.CreateFeature (partsList[math.random(1,#partsList)], posx, posy, posz, 0, unitTeam)
				if featureID then
					-- Spring.Echo("[Death Spawns] Unit Cost is " .. unitCostMetal)
					local featureValueMetal = unit.metalCost * 0.25
					local featureValueEnergy = unit.energyCost * 0.25
					local reclaimTime
					if featureValueMetal ~= nil then
						reclaimTime = featureValueMetal * 0.25
					else
						reclaimTime = featureValueEnergy * 0.25
					end
					-- Spring.Echo(featureValueMetal)
					-- Spring.Echo(featureValueEnergy)
					Spring.SetFeatureResources(featureID, featureValueMetal, featureValueEnergy, reclaimTime, 1.0, featureValueMetal, featureValueEnergy)
					Spring.SetFeaturePosition(featureID, posx, posy, posz,  false)

					-- local newx, newy, newz = Normalize(x,y,z)

					local dirx
					local diry
					local dirz

					dirx = math.random(-100,100)
					diry = math.random(-100,100)
					dirz = math.random(-100,100)
					-- Spring.Echo("[DeathContainer Spawn] Feature direction before normalization is: x: " .. dirx .. ", y: " .. diry .. ", z: " .. dirz)
					local dirx, diry, dirz = Normalize(dirx,diry,dirz)
					-- Spring.Echo("[DeathContainer Spawn] Feature direction after normalization is: x: " .. dirx .. ", y: " .. diry .. ", z: " .. dirz)
					Spring.SetFeatureDirection(featureID, dirx, diry , dirz)



					local rotx
					local roty
					local rotz

					-- Shitty attempt to put it in radians
					rotx = math.random(1,620)
					roty = math.random(1,620)
					rotz = math.random(1,620)
					rotx = rotx * 0.01
					roty = roty * 0.01
					rotz = rotz * 0.01
					-- Spring.Echo("[DeathContainer Spawn] Feature rotation is: x: " .. rotx .. ", y: " .. roty .. ", z: " .. rotz)
					Spring.SetFeatureRotation(featureID, rotx, roty , rotz)
				end
			end
		end
	end
	
end