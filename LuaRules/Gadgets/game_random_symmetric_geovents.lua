--[[
Files that are related and helpers for this Gadget

Gadgets:
game_random_symmetric_geovents

Widgets:
game_geovent_spot_loader
game_geovent_spot_drawer

Tangentially related Gadgets:
game_metal_maker_spot_generator

]]--

function gadget:GetInfo()
	return {
		name      = "Random Symmetric Geovents",
		desc      = "Places 0–8 geovents randomly and symmetrically",
		author    = "",
		date      = "2025",
		license   = "GPLv2 or later",
		layer     = 0,
		enabled   = true,
	}
end

if not gadgetHandler:IsSyncedCode() then return end

local maxGeos = 8
local geoFeatureDef = FeatureDefNames["geovent"]
local mapX = Game.mapSizeX
local mapZ = Game.mapSizeZ
local minDistanceFromEdge = 256
local maxElevationDiff = 25
local geoMetalMinDist = 128 -- Minimum distance from any metal spot
local geoPairs = {}  -- table to hold pairs of geo positions
local geoSpots = {}

local function biasedGeoCount()
	local r = math.random()
	if r < 0.2 then return 0 end
	if r < 0.6 then return 2 end
	if r < 0.88 then return 4 end
	if r < 0.97 then return 6 end
	return 8
end

local function isFlatEnough(x, z, radius)
	local minY, maxY
	for dx = -radius, radius, radius do
		for dz = -radius, radius, radius do
			local y = Spring.GetGroundHeight(x + dx, z + dz)
			minY = not minY and y or math.min(minY, y)
			maxY = not maxY and y or math.max(maxY, y)
		end
	end
	return (maxY - minY) <= maxElevationDiff
end

local function tooCloseToMetalSpot(x, z)
	if not GG.metalMakerSpots then return false end
	for _, spot in ipairs(GG.metalMakerSpots) do
		local dx = x - spot.x
		local dz = z - spot.z
		local distSq = dx * dx + dz * dz
		if distSq < geoMetalMinDist * geoMetalMinDist then
			return true
		end
	end
	return false
end

local function getSymmetricPos(x, z)
	return mapX - x, mapZ - z
end

function gadget:Initialize()
	if not geoFeatureDef then
		Spring.Echo("[RandomSymmetricGeos] Missing geovent featuredef.")
		return
	end

	math.random(); math.random(); math.random()

	local totalGeos = biasedGeoCount()
	Spring.Echo("[RandomSymmetricGeos] Spawning " .. totalGeos .. " geovents.")

	local attempts = 0
	local maxTries = 100
	while #geoPairs < totalGeos / 2 and attempts < maxTries do
		local x = math.random(minDistanceFromEdge, mapX / 2 - minDistanceFromEdge)
		local z = math.random(minDistanceFromEdge, mapZ - minDistanceFromEdge)
		local sx, sz = getSymmetricPos(x, z)

		if isFlatEnough(x, z, 32) and isFlatEnough(sx, sz, 32)
				and not tooCloseToMetalSpot(x, z)
				and not tooCloseToMetalSpot(sx, sz) then
			table.insert(geoPairs, {x = x, z = z})
		end
		attempts = attempts + 1
	end

	for _, pos in ipairs(geoPairs) do
		local x, z = pos.x, pos.z
		local y1 = Spring.GetGroundHeight(x, z)
		local sx, sz = getSymmetricPos(x, z)
		local y2 = Spring.GetGroundHeight(sx, sz)

		local featureID1 = Spring.CreateFeature("geovent", x, y1, z)
		Spring.SetFeatureRulesParam(featureID1, "customGeovent", 1, { public = true })

		local featureID2 = Spring.CreateFeature("geovent", sx, y2, sz)
		Spring.SetFeatureRulesParam(featureID2, "customGeovent", 1, { public = true })

		table.insert(geoSpots, {x = x, z = z})
		table.insert(geoSpots, {x = sx, z = sz})
	end

	-- After all spots are determined:
	GG.customGeoventSpots = geoSpots

	for i, spot in ipairs(geoSpots) do
		Spring.SetGameRulesParam("customGeovent_" .. i .. "_x", spot.x)
		Spring.SetGameRulesParam("customGeovent_" .. i .. "_z", spot.z)
	end
	Spring.SetGameRulesParam("customGeovent_count", #geoSpots)
end