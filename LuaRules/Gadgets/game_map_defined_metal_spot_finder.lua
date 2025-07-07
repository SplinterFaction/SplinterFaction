--[[
Relevant widgets for this gadget:

game_map_metal_spot_loader.lua
game_map_metal_spot_drawer.lua
]]--

function gadget:GetInfo()
	return {
		name      = "Map Defined Metal Spot Finder",
		desc      = "Finds all the metal spots defined by the map maker and stores them in GG and modRulesParams",
		author    = "",
		date      = "2025-07-06",
		license   = "GPLv2",
		layer     = 0,
		enabled   = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local mapWidth = Game.mapSizeX
local mapHeight = Game.mapSizeZ

local metalThreshold = 0.1 -- Minimum metal value for a spot
local spotSpacing = 32     -- How often to scan (in map units)
local minDistance = 48     -- Minimum distance between spots

local metalSpots = {}

local function isFarEnough(x, z, minDist)
	for _, spot in ipairs(metalSpots) do
		local dx = x - spot.x
		local dz = z - spot.z
		if (dx * dx + dz * dz) < (minDist * minDist) then
			return false
		end
	end
	return true
end

local claimed = {}

local function isClaimed(x, z, minDist)
	for _, entry in ipairs(claimed) do
		local dx = x - entry.x
		local dz = z - entry.z
		if (dx * dx + dz * dz) < (minDist * minDist) then
			return true
		end
	end
	return false
end

function gadget:Initialize()
	local mapSquaresX = Game.mapSizeX / 16
	local mapSquaresZ = Game.mapSizeZ / 16
	local clusterRadius = 9  -- In map squares (5 * 16 = 80 elmos)
	local clusterRadiusSq = clusterRadius * clusterRadius

	for x = 1, mapSquaresX - 2, 1 do
		for z = 1, mapSquaresZ - 2, 1 do
			-- Only evaluate if center tile isn't too close to an existing cluster
			if not isClaimed(x + 1, z + 1, clusterRadius) then
				local sum = 0
				for dx = 0, 2 do
					for dz = 0, 2 do
						local mx = x + dx
						local mz = z + dz
						sum = sum + (Spring.GetMetalAmount(mx, mz) or 0)
					end
				end

				local average = sum / 9
				if average >= metalThreshold then
					local centerX = (x + 1)
					local centerZ = (z + 1)
					local worldX = centerX * 16
					local worldZ = centerZ * 16

					table.insert(metalSpots, { x = worldX, z = worldZ, metal = average })
					table.insert(claimed, { x = centerX, z = centerZ })
				end
			end
		end
	end

	GG.mapmetalspots = metalSpots

	for i, spot in ipairs(metalSpots) do
		Spring.SetGameRulesParam("mapmetalspots_" .. i .. "_x", spot.x)
		Spring.SetGameRulesParam("mapmetalspots_" .. i .. "_z", spot.z)
		Spring.SetGameRulesParam("mapmetalspots_" .. i .. "_metal", spot.metal)
	end
	Spring.SetGameRulesParam("mapmetalspots_count", #metalSpots)

	Spring.Echo("[MapMetalSpotFinder] Found " .. #metalSpots .. " clustered metal spots.")
end



