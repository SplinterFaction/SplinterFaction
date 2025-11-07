--[[
Files that are related and helpers for this Gadget

Gadgets:
game_metal_maker_spot_generator

Widgets:
game_metal_spot_loader
game_metal_spot_drawer
game_metal_spot_minimap_drawer
game_metal_maker_placement_snapping

Tangentially related Gadgets:
game_geovent_spot_generator
game_map_defined_metal_spot_finder.lua

]]--

function gadget:GetInfo()
	return {
		name    = "Metal Maker Spot Generator (Building Mask 4)",
		desc    = "Places symmetrical metal maker spots using building masks",
		author  = "",
		date    = "2025-06-09",
		license = "GPLv2",
		layer   = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then return end

local count = #Spring.GetTeamList() - 1
Spring.SetGameRulesParam("peopleCount", count)
teamIDCount = Spring.GetGameRulesParam("peopleCount")


local SetSquareBuildingMask = Spring.SetSquareBuildingMask
local GetGroundHeight = Spring.GetGroundHeight
local CreateFeature = Spring.CreateFeature
local Echo = Spring.Echo

-- Config
local FOOTPRINT = 5
local MIN_SPOT_SPACING = 150  -- Minimum spacing in world units between metal spots
local ELEVATION_TOLERANCE = 15
local EDGE_MARGIN = 100  -- in world units; adjust as needed (100 = ~6 map squares)
local allowWaterSpots = true
if Spring.GetModOptions().allowmexesinwater == "disabled" then
	allowWaterSpots = false
elseif Spring.GetModOptions().allowmexesinwater == "enabled" then
	allowWaterSpots = true
end

local spotsPerQuadrant = math.floor(5 * teamIDCount / 2 + 0.5)

-- Map resolution
local mapSizeX = Game.mapSizeX
local mapSizeZ = Game.mapSizeZ
local slopeMapX = math.floor(mapSizeX / 16)
local slopeMapZ = math.floor(mapSizeZ / 16)

-- Data store
metalSpots = {} -- world coordinates of center of each valid metal zone

local function isFlatEnough(x, z)
	local minY, maxY = nil, nil
	local size = 2  -- radius for 5x5

	for dx = -size, size do
		for dz = -size, size do
			local wx = (x + dx) * 16
			local wz = (z + dz) * 16
			local wy = GetGroundHeight(wx, wz)

			if not allowWaterSpots and wy < 0 then return false end

			minY = minY and math.min(minY, wy) or wy
			maxY = maxY and math.max(maxY, wy) or wy
		end
	end

	return (maxY - minY) <= ELEVATION_TOLERANCE
end

local function isFarEnoughFromOthers(x, z, MIN_SPOT_SPACING)
	local wx = x * 16
	local wz = z * 16
	for _, spot in ipairs(metalSpots) do
		local dx = spot.x - wx
		local dz = spot.z - wz
		if (dx * dx + dz * dz) < (MIN_SPOT_SPACING * MIN_SPOT_SPACING) then
			return false
		end
	end
	return true
end

local function markSpot(x, z)
	local size = 2  -- radius for 5x5
	for dx = -size, size do
		for dz = -size, size do
			local sx = x + dx
			local sz = z + dz
			if sx >= 0 and sx < slopeMapX and sz >= 0 and sz < slopeMapZ then
				SetSquareBuildingMask(sx, sz, 4) -- 0b100 = metal-only
			end
		end
	end

	local wx = x * 16
	local wz = z * 16
	local wy = GetGroundHeight(wx, wz)

	table.insert(metalSpots, {x = wx, y = wy, z = wz})

	-- Place visual feature (optional)
	--CreateFeature("metal", wx, wy, wz, 0, -1)

	-- Add player-visible marker
	--Spring.MarkerAddPoint(wx, wy, wz, "Metal Spot")
end

local function isWithinMapBounds(wx, wz)
	return wx > EDGE_MARGIN and wx < (mapSizeX - EDGE_MARGIN)
			and wz > EDGE_MARGIN and wz < (mapSizeZ - EDGE_MARGIN)
end

local function findNearbyValidSpot(startX, startZ, maxRadius)
	for radius = 1, maxRadius do
		for dx = -radius, radius do
			for dz = -radius, radius do
				local tx = startX + dx
				local tz = startZ + dz
				local wx = tx * 16
				local wz = tz * 16
				if tx >= 0 and tx < slopeMapX and tz >= 0 and tz < slopeMapZ then
					if isFlatEnough(tx, tz)
							and isFarEnoughFromOthers(tx, tz, MIN_SPOT_SPACING)
							and isWithinMapBounds(wx, wz)
					then
						return tx, tz
					end
				end
			end
		end
	end
	return nil -- nothing found
end


-- Mirror a slopeMap coordinate into all four quadrants
local function mirrorAndPlace(x, z)
	local midX = math.floor(slopeMapX / 2)
	local midZ = math.floor(slopeMapZ / 2)
	local dx = x - midX
	local dz = z - midZ

	local function tryPlace(mx, mz)
		if mx >= 0 and mx < slopeMapX and mz >= 0 and mz < slopeMapZ then
			if isFlatEnough(mx, mz) and isFarEnoughFromOthers(mx, mz, MIN_SPOT_SPACING) and isWithinMapBounds(mx * 16, mz * 16) then
				markSpot(mx, mz)
			else
				local fallbackX, fallbackZ = findNearbyValidSpot(mx, mz, 20)
				if fallbackX and fallbackZ then
					Spring.Echo("[MetalSpotGen] Adjusted spot to fallback location: " .. fallbackX .. ", " .. fallbackZ)
					markSpot(fallbackX, fallbackZ)
				else
					Spring.Echo("[MetalSpotGen] No valid fallback found for spot at " .. mx .. ", " .. mz)
				end
			end
		end
	end

	tryPlace(midX + dx, midZ + dz)     -- original
	tryPlace(midX - dx, midZ + dz)     -- mirror X
	tryPlace(midX + dx, midZ - dz)     -- mirror Z
	tryPlace(midX - dx, midZ - dz)     -- mirror both
end


function gadget:Initialize()
	Echo("[MetalSpotGen] Initializing")

	local count = Spring.GetGameRulesParam("metalSpot_count")
	if count then
		Echo("[MetalSpotGen] Restoring from GameRulesParams")
		GG.metalMakerSpots = {}
		for i = 1, count do
			local x = Spring.GetGameRulesParam("metalSpot_" .. i .. "_x")
			local z = Spring.GetGameRulesParam("metalSpot_" .. i .. "_z")
			local y = GetGroundHeight(x, z)
			table.insert(GG.metalMakerSpots, {x = x, y = y, z = z})
		end
		return
	end

	Echo("[MetalSpotGen] Starting scan")

	local midX = math.floor(slopeMapX / 2)
	local midZ = math.floor(slopeMapZ / 2)
	local scanMinX, scanMaxX = 1, math.floor(midX)
	local scanMinZ, scanMaxZ = 1, math.floor(midZ)
	local candidates = {}

	for x = scanMinX, scanMaxX do
		for z = scanMinZ, scanMaxZ do
			if isFlatEnough(x, z) and isFarEnoughFromOthers(x, z, MIN_SPOT_SPACING) and isWithinMapBounds(x * 16, z * 16) then
				table.insert(candidates, {x = x, z = z})
			end
		end
	end

	Echo("[MetalSpotGen] Found " .. #candidates .. " flat candidates in top-left quadrant")
	math.random(); math.random(); math.random()
	for i = #candidates, 2, -1 do
		local j = math.random(i)
		candidates[i], candidates[j] = candidates[j], candidates[i]
	end

	for i = 1, math.min(spotsPerQuadrant, #candidates) do
		local spot = candidates[i]
		mirrorAndPlace(spot.x, spot.z)
	end

	Echo("[MetalSpotGen] Total spots placed: " .. #metalSpots)
	GG.metalMakerSpots = metalSpots

	for i, spot in ipairs(metalSpots) do
		Spring.SetGameRulesParam("metalSpot_" .. i .. "_x", spot.x)
		Spring.SetGameRulesParam("metalSpot_" .. i .. "_z", spot.z)
	end
	Spring.SetGameRulesParam("metalSpot_count", #metalSpots)
end