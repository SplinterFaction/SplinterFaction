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
		local killedByHeat = Spring.GetUnitRulesParam(unitID, "killedByHeat")
		local spawnWreck = false

		-- Tech-based spawn chance
		-- Commander exception


		if unitRole == "Commander" then
			spawnWreck = false
		end

		if killedByHeat == 1 then
			spawnWreck = true
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
			if buildProgress ~= 1 then
				return
			end

			local corpseName = unitDef.customParams and unitDef.customParams.corpse
			local isShip     = (unitType == "ship")
			local heatKill   = (killedByHeat == 1)

			-- Decide what we WANT to spawn first
			-- Rule: spawn a if it matches these parameters and only if a corpse feature exists
			local wantCorpse = (isShip or heatKill) and (corpseName ~= nil)

			-- Choose feature def based on intent
			local featureName
			local featureTeam
			if wantCorpse then
				featureName = corpseName
				featureTeam = -1
			else
				featureName = partsList[math.random(1, #partsList)]
				featureTeam = unitTeam
			end

			local posx, posy, posz = Spring.GetUnitPosition(unitID)
			local featureID = Spring.CreateFeature(featureName, posx, posy, posz, 0, featureTeam)
			if not featureID then
				return
			end

			-- Shared: set value/health/resources/position
			local featureValueMetal  = unitDef.metalCost  * (heatKill and 1 or 0.75)
			local featureValueEnergy = unitDef.energyCost * (heatKill and 1 or 0.75)
			if heatKill then
				--Spring.Echo("[Death Spawns] Unit was killed by heat! Corpse value: " .. featureValueMetal .. "/" .. featureValueEnergy)
			end

			local reclaimTime  = featureValueMetal * 0.25
			local featureHealth = unitDef.health

			Spring.SetFeatureHealth(featureID, featureHealth)
			Spring.SetFeatureResources(featureID, featureValueMetal, featureValueEnergy, reclaimTime, 1, featureValueMetal, featureValueEnergy)
			Spring.SetFeaturePosition(featureID, posx, posy, posz, false)

			-- Movement setup (your calls kept)
			Spring.SetFeatureMoveCtrl(featureID, false, 1,1,1,1,1,1,1,1,1)

			-- Use original unit velocity for both cases (even if SetFeatureVelocity is flaky)
			local vx, vy, vz = Spring.GetUnitVelocity(unitID)

			if wantCorpse then
				--Spring.Echo("[Death Spawns] Spawning a corpse feature: " .. tostring(corpseName))

				-- Sink only for ship corpses (same logic as you intended)
				if isShip then
					sinkingFeatures[featureID] = {}
				end

				-- Heading-based direction for corpses
				local heading = Spring.GetUnitHeading(unitID)
				local radians = (heading / 32768.0) * math.pi
				local dirx = math.sin(radians)
				local dirz = math.cos(radians)

				Spring.SetFeatureVelocity(featureID, vx, vy, vz) -- may not work depending on engine
				Spring.SetFeatureDirection(featureID, dirx, 0, dirz)
				if heatKill then
					if tech == "tech0" or tech == "tech1" then
						Spring.SpawnCEG("genericunitexplosion-heatdeath-small", posx, posy, posz, 0, 0, 0)
						Spring.SpawnCEG("heatdeath-fire-t1", posx, posy+10, posz, 0, 0, 0)
					elseif tech == "tech2" then
						Spring.SpawnCEG("genericunitexplosion-heatdeath-medium", posx, posy, posz, 0, 0, 0)
						Spring.SpawnCEG("heatdeath-fire-t2", posx, posy+10, posz, 0, 0, 0)
					elseif tech == "tech3" then
						Spring.SpawnCEG("genericunitexplosion-heatdeath-large", posx, posy, posz, 0, 0, 0)
						Spring.SpawnCEG("heatdeath-fire-t3", posx, posy+10, posz, 0, 0, 0)
					elseif tech == "tech4" then
						Spring.SpawnCEG("genericunitexplosion-heatdeath-huge", posx, posy, posz, 0, 0, 0)
						Spring.SpawnCEG("heatdeath-fire-t4", posx, posy+10, posz, 0, 0, 0)
					end
				end
			else
				--Spring.Echo("[Death Spawns] Spawning a part feature")

				-- Random direction for junk parts
				local dx = math.random(-100, 100)
				local dy = math.random(-100, 100)
				local dz = math.random(-100, 100)
				local norm = math.sqrt(dx*dx + dy*dy + dz*dz)
				if norm == 0 then norm = 1 end

				Spring.SetFeatureVelocity(featureID, vx, vy, vz) -- may not work depending on engine
				Spring.SetFeatureDirection(featureID, dx / norm, dy / norm, dz / norm)
			end
		end
	end
end

