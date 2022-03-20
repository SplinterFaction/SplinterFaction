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
	}

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	
		if math.random(1,2) == 1 then
			_, _, _, _, buildProgress = Spring.GetUnitHealth(unitID)
			if buildProgress == 1 then
				local unitName = UnitDefs[unitDefID].name
				local unitCostMetal = UnitDefs[unitDefID].metalCost
				local unitCostEnergy = UnitDefs[unitDefID].energyCost
				posx, posy, posz = Spring.GetUnitPosition(unitID)
				-- Spring.Echo("[Death Spawns] Unit Name is " .. unitName)
				local featureID = Spring.CreateFeature (partsList[math.random(1,#partsList)], posx, posy, posz, 0, unitTeam)
				if featureID then
					-- Spring.Echo("[Death Spawns] Unit Cost is " .. unitCostMetal)
					Spring.SetFeatureResources(featureID, unitCostMetal * 0.25, unitCostEnergy * 0.25)
					Spring.SetFeaturePosition(featureID, posx, posy, posz,  false)
					
					dirx = math.random(1,100000)
					diry = math.random(1,50000)
					dirz = math.random(1,100000)
					Spring.SetFeatureDirection(featureID, dirx, diry , dirz)
					
					rotx = math.random(1,50)
					roty = math.random(1,100)
					rotz = math.random(1,50)
					Spring.SetFeatureRotation(featureID, rotx, roty , rotz)
				end
			end
		end
	end
	
end