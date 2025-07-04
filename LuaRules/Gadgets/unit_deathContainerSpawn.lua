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

	local sinkingFeatures = {}
	function gadget:GameFrame(n)
		for featureID, sinkData in pairs(sinkingFeatures) do
			local x, y, z = Spring.GetFeaturePosition(featureID)
			if x and y and z then
				if n % 30 == 0 then
					Spring.SpawnCEG("bubblesunderwater", x, y, z, 0, 1, 0)
				end
			else
				sinkingFeatures[featureID] = nil  -- clean up if feature no longer exists
			end
		end
	end

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
		local unitDef = UnitDefs[unitDefID]
		local tech = unitDef.customParams.requiretech
		local unitRole = unitDef.customParams.unitrole
		local unitType = unitDef.customParams.unittype
		local spawnWreck = false

		-- Tech-based spawn chance
		-- Commander exception
		if unitRole == "Commander" then
			spawnWreck = false
		end

		-- Ship Exception
		if unitType == "ship" then
			spawnWreck = true
		end

		if tech == "tech0" and math.random(1, 4) == 1 then
			spawnWreck = true
		elseif tech == "tech1" and math.random(1, 2) == 1 then
			spawnWreck = true
		elseif tech == "tech2" or tech == "tech3" or tech == "tech4" then
			spawnWreck = true
		end



		if spawnWreck then
			local _, _, _, _, buildProgress = Spring.GetUnitHealth(unitID)
			if buildProgress == 1 then
				local corpseFeature = unitDef.customParams.corpse
				local posx, posy, posz = Spring.GetUnitPosition(unitID)
				local featureName = corpseFeature or partsList[math.random(1, #partsList)]
				local isCorpse = (corpseFeature ~= nil)
				local teamID = isCorpse and -1 or unitTeam
				local featureID = Spring.CreateFeature(featureName, posx, posy, posz, 0, teamID)


				if featureID then
					local featureValueMetal = unitDef.metalCost * 0.75
					local featureValueEnergy = unitDef.energyCost * 0.75
					local reclaimTime = featureValueMetal * 0.75

					Spring.SetFeatureResources(featureID, featureValueMetal, featureValueEnergy, reclaimTime, 1.0, featureValueMetal, featureValueEnergy)
					Spring.SetFeaturePosition(featureID, posx, posy, posz, false)


					local isCorpse = corpseFeature ~= nil
					local isShip = unitType == "ship"

					if isCorpse and isShip then
						sinkingFeatures[featureID] = {}
					end



					if corpseFeature and corpseFeature ~= "" then
						-- Spring.Echo("[Death Spawns] Spawning a corpse feature: ".. "| " .. corpseFeature .. " |")
						-- Use original unit velocity and heading
						local vx, vy, vz = Spring.GetUnitVelocity(unitID)
						-- Spring.Echo("[Death Spawns] Unit Velocity is: vx " .. vx .. " | vy " ..  vy .. " | vz ".. vz)
						local heading = Spring.GetUnitHeading(unitID)
						-- Convert heading to direction vector
						local radians = (heading / 32768.0) * math.pi
						local dirx = math.sin(radians)
						local dirz = math.cos(radians)

						---------------------------------------------
						--This Block Exists only for testing purposes
						---------------------------------------------
						--vx = vx * 100
						--vy = vy * 100
						--vz = vz * 100
						--Spring.Echo("[Death Spawns] Unit Velocity is modified to: vx " .. vx .. " | vy " ..  vy .. " | vz ".. vz)
						-----
						-----

						Spring.SetFeatureMoveCtrl(featureID,false,1,1,1,1,1,1,1,1,1)
						Spring.SetFeatureVelocity(featureID, vx, vy, vz) -- Does not work
						Spring.SetFeatureDirection(featureID, dirx, 0, dirz)
					else
						-- Spring.Echo("[Death Spawns] Spawning a part feature")
						local vx, vy, vz = Spring.GetUnitVelocity(unitID)
						-- Spring.Echo("Unit Velocity is: vx " .. vx .. " | vy " ..  vy .. " | vz ".. vz)
						-- Random junk parts with random spin direction
						local dx = math.random(-100, 100)
						local dy = math.random(-100, 100)
						local dz = math.random(-100, 100)
						local norm = math.sqrt(dx * dx + dy * dy + dz * dz)
						Spring.SetFeatureMoveCtrl(featureID,false,1,1,1,1,1,1,1,1,1)
						Spring.SetFeatureVelocity(featureID, vx, vy, vz) -- Does not work
						Spring.SetFeatureDirection(featureID, dx / norm, dy / norm, dz / norm)
					end
				end
			end
		end
	end
end

