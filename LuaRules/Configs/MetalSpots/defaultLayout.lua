--math.randomseed(Game.GameID) -- This only works in 104+
math.random(); math.random(); math.random()
local mapx, mapz = Game.mapSizeX * 0.5, Game.mapSizeZ * 0.5

-- Lets sq root the map size into a digestable number for later. We're doing some math here to account for the fact that spring does not work with add numbers. Only even ones. So, for that reason we cant to get the square root in numbers that comport to how we normally thing about maps. For example, a 16 x 16 map sqrt is 256, so that is our basis.

local mapWidthX = (Game.mapSizeX * 2) / 1024
local mapLengthZ = (Game.mapSizeZ * 2) / 1024
local mapSQRT = mapWidthX * mapLengthZ

-- Params
local size = math.max(mapx, mapz)

--
Spring.Echo("[Default Mex Layout] Map size is: " .. size)
Spring.Echo("[Default Mex Layout] Map square root size is: " .. mapSQRT)
local count = #Spring.GetTeamList() - 1
local allycount = #Spring.GetAllyTeamList() - 1
-- for i = 1, #players do
-- local playerID = players[i]
-- if not select(3, Spring.GetPlayerInfo(playerID)) then
-- count = count + 1
-- end
-- end
Spring.SetGameRulesParam("peopleCount", count)

teamIDCount = Spring.GetGameRulesParam("peopleCount")

Spring.Echo("[Default Mex Layout] Number of teamIDs in this match: " .. teamIDCount)
--

local placeMexesInWater = Spring.GetModOptions().allowmexesinwater or "disabled"
local maxMexElevationDiff = tonumber(Spring.GetModOptions().maximummexelevationdifference) or 50
local mexSpotsPerPlayerOverride = tonumber(Spring.GetModOptions().mexSpotsPerPlayerOverride) or 10
local mexRandomLayout = "standard"
local dynamicMexOutput = Spring.GetModOptions().dynamicmexoutput or "disabled"

if placeMexesInWater == "enabled" or placeMexesInWater == "" or placeMexesInWater == nil then -- This is just an oshitifukedup protection
	allowMexesInWater = true
elseif placeMexesInWater == "disabled" then
	allowMexesInWater = false
end

if maxMexElevationDiff == nil then -- This is just an oshitifukedup protection
	maxMexElevationDiff = 50
end

if dynamicMexOutput == "" or dynamicMexOutput == nil then -- This is just an oshitifukedup protection
	dynamicMexOutput = "disabled"
end

Spring.Echo("[Default Mex Layout] Can we put mexes in water?")
Spring.Echo(allowMexesInWater)

local sGetGroundHeight = Spring.GetGroundHeight
local mexSideHalved = 70 -- mex is a square of side 140 units
local slopeCheckMinDistance = 35
local function checkSlope(x, z, tolerance, allowWater)
	local heightMap = {}
	local leng = 0
	for i = -mexSideHalved, mexSideHalved, slopeCheckMinDistance do
		for j = -mexSideHalved, mexSideHalved, slopeCheckMinDistance do
			leng = leng + 1
			heightMap[leng] = sGetGroundHeight(x + i, z + j)
		end
	end
	local highest = math.max(unpack(heightMap))
	local lowest = math.min(unpack(heightMap))
	local result = highest - lowest
	return result <= tolerance and (allowWater or lowest > 0)
end

local function mathRound(x)
	return math.floor(x + 0.5)
end
local function f(x)
	result = 0
	if x < 0.6 then result = 0.5 + math.pow((0.6 - x) / 0.6, 2) * 1.5
	elseif x < 0.8 then result = (x - 0.6) / 0.4 + 0.5
	elseif x <= 1 then result = 1 end
	if dynamicMexOutput == "disabled" then
		return 1
	else
		return mathRound(result / 0.05) * 0.05
	end
end
local function makePositionsRandomMirrored(sizeX, sizeY, padding, pointRadius, extraSeparationBetweenPoints, howManyTriesBeforeGiveUp, numPointsPerSide, includeCentre, method, allowWater)
	-- Delete vanilla geothermal positions
	-- This cannot be done here. It has to be done in luagaia. See geokiller gadget.
	--local featureList = Spring.GetAllFeatures()
	--for i = 1, #featureList do
	--	local fID = featureList[i]
	--	local fDefID = Spring.GetFeatureDefID(fID)
	--	local fDef = FeatureDefs[fDefID]
	--
	--	if fDef.geoThermal and (fDef.name == 'geovent') then
	--		Spring.DestroyFeature(fID)
	--	end
	--end

	local positions = {}
	--positions[1] = {x = padding, z = padding}
	--positions[2] = {x = sizeX - padding, z = sizeY - padding}
	if includeCentre then positions[#positions + 1] = {x = sizeX * 0.5, z = sizeY * 0.5} end
	for i = 1, numPointsPerSide do
		local newPoint = {0, 0}
		local done = false
		local numIterations = 0
		local minSeparation = pointRadius * 2 + extraSeparationBetweenPoints
		while not done and numIterations < howManyTriesBeforeGiveUp do
			numIterations = numIterations + 1
			done = true

			newPoint[1] = padding + math.random() * (sizeX *0.5 - padding * 2)
			newPoint[2] = padding + math.random() * (sizeY *0.5 - padding * 2)

			newPoint[3] = newPoint[1]
			newPoint[4] = sizeY - newPoint[2]

			newPoint[5] = sizeX - newPoint[1]
			newPoint[6] = newPoint[2]

			newPoint[7] = sizeX - newPoint[1]
			newPoint[8] = sizeY - newPoint[2]

			-- check slope of new point and mirror
			done = checkSlope(newPoint[1], newPoint[2], maxMexElevationDiff, allowWater)
			done = done and checkSlope(newPoint[3], newPoint[4], maxMexElevationDiff, allowWater)
			for j = 1, #positions do
				-- check new point vs existing points
				local dx = newPoint[1] - positions[j].x
				local dy = newPoint[2] - positions[j].z
				if dx * dx + dy * dy < minSeparation * minSeparation then
					done = false
					--positions[j][4], positions[j][5], logCollisions = positions[j][4] - 48, positions[j][5] - 48, logCollisions + 1
					break
				end
				-- check mirror of new point vs existing points
				dx = newPoint[3] - positions[j].x
				dy = newPoint[4] - positions[j].z
				if dx * dx + dy * dy < minSeparation * minSeparation then
					done = false
					--positions[j][4], positions[j][5], logCollisions = positions[j][4] - 48, positions[j][5] - 48, logCollisions + 1
					break
				end
			end
			-- check new point vs mirror of new point
			local dx = newPoint[1] - newPoint[3]
			local dy = newPoint[2] - newPoint[4]
			if dx * dx + dy * dy < minSeparation * minSeparation then
				done = false
				--logCollisions = logCollisions + 1
			end
		end
		if numIterations == howManyTriesBeforeGiveUp then logFailures = logFailures + 1 end

		positions[#positions + 1] = {x = newPoint[1], z = newPoint[2]}
		positions[#positions + 1] = {x = newPoint[3], z = newPoint[4]}
		if newPoint[5] then
			positions[#positions + 1] = {x = newPoint[5], z = newPoint[6]}
		end
		if newPoint[7] then
			positions[#positions + 1] = {x = newPoint[7], z = newPoint[8]}
		end
		if math.random() <= 0.2 then
			local featureID = Spring.CreateFeature('geovent', newPoint[1], Spring.GetGroundHeight(newPoint[1],newPoint[2])+5, newPoint[2], 1, Spring.GetGaiaTeamID())
			Spring.SetFeatureRulesParam(featureID, "customGeovent", 1, { public = true })
			-- Spring.MarkerAddPoint ( newPoint[1], Spring.GetGroundHeight(newPoint[1],newPoint[2])+5, newPoint[2], "GeoVent")
			local featureID = Spring.CreateFeature('geovent', newPoint[3], Spring.GetGroundHeight(newPoint[3],newPoint[4])+5, newPoint[4], 1, Spring.GetGaiaTeamID())
			Spring.SetFeatureRulesParam(featureID, "customGeovent", 1, { public = true })
			-- Spring.MarkerAddPoint ( newPoint[3], Spring.GetGroundHeight(newPoint[3],newPoint[4])+5, newPoint[4], "GeoVent")
			if newPoint[5] then
				local featureID = Spring.CreateFeature('geovent', newPoint[5], Spring.GetGroundHeight(newPoint[5],newPoint[6])+5, newPoint[6], 1, Spring.GetGaiaTeamID())
				Spring.SetFeatureRulesParam(featureID, "customGeovent", 1, { public = true })
				-- Spring.MarkerAddPoint ( newPoint[5], Spring.GetGroundHeight(newPoint[5],newPoint[6])+5, newPoint[6], "GeoVent")
			end
			if newPoint[7] then
				local featureID = Spring.CreateFeature('geovent', newPoint[7], Spring.GetGroundHeight(newPoint[7],newPoint[8])+5, newPoint[8], 1, Spring.GetGaiaTeamID())
				Spring.SetFeatureRulesParam(featureID, "customGeovent", 1, { public = true })
				-- Spring.MarkerAddPoint ( newPoint[7], Spring.GetGroundHeight(newPoint[7],newPoint[8])+5, newPoint[8], "GeoVent")
			end
		end
	end
	--table.remove(positions, 1)
	--table.remove(positions, 1)

	local ratioX, ratioY = 1, 1
	if sizeX > sizeY then ratioY = sizeX / sizeY
	elseif sizeY > sizeX then ratioX = sizeY / sizeX end
	local sizeMax = math.max(sizeX, sizeY)
	for i = 1, #positions do
		local dx = sizeMax * 0.5 - positions[i].x * ratioX
		local dy = sizeMax * 0.5 - positions[i].z * ratioY
		local r = math.sqrt(dx * dx + dy * dy)
		positions[i].metal = f(r / (sizeX * math.sqrt(2)))
	end

	return positions
end

if mexRandomLayout == "standard" then
	mexSpotsPerPlayer = 7 --mexSpotsPerPlayerOverride needs to always mirror this value, otherwise the override will ALWAYS take precedence
	if mexSpotsPerPlayer ~= mexSpotsPerPlayerOverride then
		mexSpotsPerPlayer = mexSpotsPerPlayerOverride
	end
	mexSpotsPerQuad = (mexSpotsPerPlayer * teamIDCount) / 4

	--if mapSQRT <= 144 then -- An exception for 12x12 and smaller maps
	--	mexSpotsPerQuad = 10
	--	Spring.Echo("[Default Mex Layout] Map Square Root size is " .. mapSQRT .. " with a teamIDCount of " .. teamIDCount.. ". Placing " .. mexSpotsPerQuad .. " mex points per quadrant (This is usually rounded up to the next whole number).")
	--end
	--
	--if mapSQRT > 144 and mapSQRT <= 196 then -- An exception for 14x14 maps
	--	mexSpotsPerQuad = 12
	--	Spring.Echo("[Default Mex Layout] Map Square Root size is " .. mapSQRT .. " with a teamIDCount of " .. teamIDCount.. ". Placing " .. mexSpotsPerQuad .. " mex points per quadrant (This is usually rounded up to the next whole number).")
	--end
	--
	--if mapSQRT > 196 and mapSQRT <= 256 then -- An exception for 16x16 maps
	--	mexSpotsPerQuad = 15
	--	Spring.Echo("[Default Mex Layout] Map Square Root size is " .. mapSQRT .. " with a teamIDCount of " .. teamIDCount.. ". Placing " .. mexSpotsPerQuad .. " mex points per quadrant (This is usually rounded up to the next whole number).")
	--end
	--
	--if mapSQRT > 256 and mapSQRT <= 400 then -- An exception for 20x20 maps
	--	mexSpotsPerQuad = 17
	--	Spring.Echo("[Default Mex Layout] Map Square Root size is " .. mapSQRT .. " with a teamIDCount of " .. teamIDCount.. ". Placing " .. mexSpotsPerQuad .. " mex points per quadrant (This is usually rounded up to the next whole number).")
	--end
	--
	--if mapSQRT > 400 and mapSQRT <= 576 then -- An exception for 24x24 maps
	--	mexSpotsPerQuad = 20
	--	Spring.Echo("[Default Mex Layout] Map Square Root size is " .. mapSQRT .. " with a teamIDCount of " .. teamIDCount.. ". Placing " .. mexSpotsPerQuad .. " mex points per quadrant (This is usually rounded up to the next whole number).")
	--end
	--
	--if mapSQRT > 576 then -- An exception for 28x28 maps
	--	mexSpotsPerQuad = 25
	--	Spring.Echo("[Default Mex Layout] Map Square Root size is " .. mapSQRT .. " with a teamIDCount of " .. teamIDCount.. ". Placing " .. mexSpotsPerQuad .. " mex points per quadrant (This is usually rounded up to the next whole number).")
	--end

	randomMirrored = true
	padding = 100
	pointRadius = 100 -- TODO: change this into how big a metal circle is
	extraSeparationBetweenPoints = 50
	howManyTriesBeforeGiveUp = 100
	numPointsPerSide = mexSpotsPerQuad
	numPointsPerSide = math.floor(numPointsPerSide + 0.5)
	includeCentre = false
	method = 6
	allowWater = allowMexesInWater
	--metalPerPoint = 1
end

if r and not m then
	m = {}
	for i = 1, #r do
		m[i] = f(r[i])
	end
end

--
local results = {}
if not randomMirrored then
	local lengResults = 1
	local ratioX, ratioZ = 1, 1
	if mapx > mapz then
		ratioZ = mapz / mapx
	elseif mapz > mapx then
		ratioX = mapx / mapz
	end
	for i = 1, #pointsPerLayer do

		local angle = angleOffset[i] + math.pi * 2 * 1 / pointsPerLayer[i]
		local currX, currZ = mapx + r[i] * math.cos(angle) * size * ratioX, mapz + r[i] * math.sin(angle) * size * ratioZ

		for j = 2, pointsPerLayer[i] + 1 do
			results[lengResults] = {x = currX, z = currZ, metal = m[i]}
			lengResults = lengResults + 1

			angle = angleOffset[i] + math.pi * 2 * j / pointsPerLayer[i]
			nextX, nextZ = mapx + r[i] * math.cos(angle) * size * ratioX, mapz + r[i] * math.sin(angle) * size * ratioZ

			local numParts = pointsBetweenVertices[i] + 1
			for k = 1, pointsBetweenVertices[i] do
				results[lengResults] = {
					x = currX * (numParts - k) / numParts + nextX * k / numParts,
					z = currZ * (numParts - k) / numParts + nextZ * k / numParts,
					metal = m[i]
				}
				lengResults = lengResults + 1
			end
			currX, currZ = nextX, nextZ
		end
	end
else
	results = makePositionsRandomMirrored(Game.mapSizeX, Game.mapSizeZ, padding, pointRadius, extraSeparationBetweenPoints, howManyTriesBeforeGiveUp, numPointsPerSide, includeCentre, method, allowWater)
end

return {
	spots = results,
}