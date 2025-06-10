function gadget:GetInfo()
	return {
		name    = "Metal Maker Spot Generator",
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
local ELEVATION_TOLERANCE = 15
local allowWaterSpots = false
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
	CreateFeature("metal", wx, wy, wz, 0, -1)

	-- Add player-visible marker
	Spring.MarkerAddPoint(wx, wy, wz, "Metal Spot")
end

local function findNearbyValidSpot(startX, startZ, maxRadius)
	for radius = 1, maxRadius do
		for dx = -radius, radius do
			for dz = -radius, radius do
				local tx = startX + dx
				local tz = startZ + dz
				if tx >= 0 and tx < slopeMapX and tz >= 0 and tz < slopeMapZ then
					if isFlatEnough(tx, tz) then
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
			if isFlatEnough(mx, mz) then
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
	Echo("[MetalSpotGen] Starting scan")

	local midX = math.floor(slopeMapX / 2)
	local midZ = math.floor(slopeMapZ / 2)

	local scanMinX, scanMaxX = 1, math.floor(midX * 0.9)
	local scanMinZ, scanMaxZ = 1, math.floor(midZ * 0.9)

	local candidates = {}

	for x = scanMinX, scanMaxX do
		for z = scanMinZ, scanMaxZ do
			if isFlatEnough(x, z) then
				table.insert(candidates, {x = x, z = z})
			end
		end
	end

	Echo("[MetalSpotGen] Found " .. #candidates .. " flat candidates in top-left quadrant")

	-- Randomize to spread distribution (or use deterministic spacing logic later)
	math.randomseed(1234)
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

	-- This is fugly, but there are no good ways to get a table of data from gadgetland to widgetland
	for i, spot in ipairs(metalSpots) do
		Spring.SetGameRulesParam("metalSpot_" .. i .. "_x", spot.x)
		Spring.SetGameRulesParam("metalSpot_" .. i .. "_z", spot.z)
	end
	Spring.SetGameRulesParam("metalSpot_count", #metalSpots)

end
