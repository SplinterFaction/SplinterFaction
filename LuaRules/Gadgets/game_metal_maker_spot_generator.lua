--[[
<<<<<<< Updated upstream
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
=======
Metal Maker Spot Generator (Building Mask 4) - de-clumped version
>>>>>>> Stashed changes

Key fixes:
- Places mirrored spots as a single "group" (all 4 mirrors must be valid together)
- Fallback search is group-based (finds an offset that works for all mirrors)
- Candidate list no longer pretends to be spaced (spacing is enforced on acceptance)
]]--

function gadget:GetInfo()
	return {
		name    = "Metal Maker Spot Generator (Building Mask 4)",
		desc    = "Places symmetrical metal maker spots using building masks (group-based, less clumping)",
		author  = "",
		date    = "2026-01-18",
		license = "GPLv2",
		layer   = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then return end

local SetSquareBuildingMask = Spring.SetSquareBuildingMask
local GetGroundHeight       = Spring.GetGroundHeight
local Echo                  = Spring.Echo

-- Config
local FOOTPRINT          = 5
local MIN_SPOT_SPACING   = 150  -- world units between centers
local ELEVATION_TOLERANCE= 15
local EDGE_MARGIN        = 100  -- world units

local allowWaterSpots = true
do
	local opt = Spring.GetModOptions() and Spring.GetModOptions().allowmexesinwater
	if opt == "disabled" then
		allowWaterSpots = false
	elseif opt == "enabled" then
		allowWaterSpots = true
	end
end

-- People/team count logic (kept compatible with your original)
local count = #Spring.GetTeamList() - 1
Spring.SetGameRulesParam("peopleCount", count)
local teamIDCount = Spring.GetGameRulesParam("peopleCount") or count

local spotsPerQuadrant = math.floor(5 * teamIDCount / 2 + 0.5)

-- Map resolution
local mapSizeX  = Game.mapSizeX
local mapSizeZ  = Game.mapSizeZ
local slopeMapX = math.floor(mapSizeX / 16)
local slopeMapZ = math.floor(mapSizeZ / 16)

-- Data store (world coords)
local metalSpots = {}

-- -------------------------
-- Helpers
-- -------------------------

local function isWithinMapBounds(wx, wz)
	return wx > EDGE_MARGIN and wx < (mapSizeX - EDGE_MARGIN)
			and wz > EDGE_MARGIN and wz < (mapSizeZ - EDGE_MARGIN)
end

local function isFlatEnough(sx, sz)
	-- sx/sz are in slope map coords (16 world units per cell)
	local minY, maxY = nil, nil
	local size = 2 -- radius for 5x5 footprint

	for dx = -size, size do
		for dz = -size, size do
			local wx = (sx + dx) * 16
			local wz = (sz + dz) * 16
			local wy = GetGroundHeight(wx, wz)

			if not allowWaterSpots and wy < 0 then
				return false
			end

			minY = minY and math.min(minY, wy) or wy
			maxY = maxY and math.max(maxY, wy) or wy
		end
	end

	return (maxY - minY) <= ELEVATION_TOLERANCE
end

local function isFarEnoughFromPlaced(wx, wz)
	local min2 = MIN_SPOT_SPACING * MIN_SPOT_SPACING
	for _, spot in ipairs(metalSpots) do
		local dx = spot.x - wx
		local dz = spot.z - wz
		if (dx*dx + dz*dz) < min2 then
			return false
		end
	end
	return true
end

local function markSpot(sx, sz)
	-- mark 5x5 footprint squares with mask=4
	local size = 2
	for dx = -size, size do
		for dz = -size, size do
			local mx = sx + dx
			local mz = sz + dz
			if mx >= 0 and mx < slopeMapX and mz >= 0 and mz < slopeMapZ then
				SetSquareBuildingMask(mx, mz, 4)
			end
		end
	end

	local wx = sx * 16
	local wz = sz * 16
	local wy = GetGroundHeight(wx, wz)

	metalSpots[#metalSpots + 1] = { x = wx, y = wy, z = wz }
end

-- Compute 4-way mirrors around map center in slope coords
local function getMirrors(sx, sz)
	local midX = math.floor(slopeMapX / 2)
	local midZ = math.floor(slopeMapZ / 2)
	local dx = sx - midX
	local dz = sz - midZ

	return {
		{ midX + dx, midZ + dz }, -- original
		{ midX - dx, midZ + dz }, -- mirror X
		{ midX + dx, midZ - dz }, -- mirror Z
		{ midX - dx, midZ - dz }, -- mirror both
	}
end

local function isSpotValid(sx, sz)
	if sx < 0 or sx >= slopeMapX or sz < 0 or sz >= slopeMapZ then
		return false
	end
	local wx = sx * 16
	local wz = sz * 16
	if not isWithinMapBounds(wx, wz) then
		return false
	end
	if not isFlatEnough(sx, sz) then
		return false
	end
	return true
end

-- Check a whole mirror group:
-- - each member is valid (flat, bounds, etc.)
-- - each is far enough from already placed spots
-- - and far enough from other members of the group (avoids group self-collisions on small maps)
local function isGroupValid(group)
	-- validity + distance from placed
	for i = 1, 4 do
		local sx, sz = group[i][1], group[i][2]
		if not isSpotValid(sx, sz) then
			return false
		end
		local wx = sx * 16
		local wz = sz * 16
		if not isFarEnoughFromPlaced(wx, wz) then
			return false
		end
	end

	-- distance within group
	local min2 = MIN_SPOT_SPACING * MIN_SPOT_SPACING
	for i = 1, 4 do
		local wx1, wz1 = group[i][1] * 16, group[i][2] * 16
		for j = i + 1, 4 do
			local wx2, wz2 = group[j][1] * 16, group[j][2] * 16
			local dx = wx1 - wx2
			local dz = wz1 - wz2
			if (dx*dx + dz*dz) < min2 then
				return false
			end
		end
	end

	return true
end

-- Group-based fallback:
-- Search near the *source* coordinate in the scanned quadrant, but only accept if ALL mirrors work.
local function findNearbyValidGroup(startX, startZ, maxRadius, scanMinX, scanMaxX, scanMinZ, scanMaxZ)
	-- Try the exact point first
	do
		local g = getMirrors(startX, startZ)
		if isGroupValid(g) then
			return startX, startZ, g
		end
	end

	-- Spiral-ish expansion
	for r = 1, maxRadius do
		for dx = -r, r do
			for dz = -r, r do
				-- only check ring-ish perimeter to reduce repeats
				if (math.abs(dx) == r) or (math.abs(dz) == r) then
					local sx = startX + dx
					local sz = startZ + dz

					-- keep the search inside the scanned (top-left) quadrant window
					if sx >= scanMinX and sx <= scanMaxX and sz >= scanMinZ and sz <= scanMaxZ then
						local g = getMirrors(sx, sz)
						if isGroupValid(g) then
							return sx, sz, g
						end
					end
				end
			end
		end
	end

	return nil
end

local function shuffle(t)
	for i = #t, 2, -1 do
		local j = math.random(i)
		t[i], t[j] = t[j], t[i]
	end
end

-- -------------------------
-- Main
-- -------------------------

function gadget:Initialize()
	Echo("[MetalSpotGen] Initializing (group-based)")

	-- Restore from GameRulesParams if present
	local restoredCount = Spring.GetGameRulesParam("metalSpot_count")
	if restoredCount then
		Echo("[MetalSpotGen] Restoring from GameRulesParams")
		GG.metalMakerSpots = {}
		for i = 1, restoredCount do
			local x = Spring.GetGameRulesParam("metalSpot_" .. i .. "_x")
			local z = Spring.GetGameRulesParam("metalSpot_" .. i .. "_z")
			local y = GetGroundHeight(x, z)
			GG.metalMakerSpots[#GG.metalMakerSpots + 1] = { x = x, y = y, z = z }
		end
		return
	end

	-- Build candidates in top-left quadrant (no spacing enforced here; spacing is enforced on acceptance)
	Echo("[MetalSpotGen] Starting scan")

	local midX = math.floor(slopeMapX / 2)
	local midZ = math.floor(slopeMapZ / 2)

	local scanMinX, scanMaxX = 1, math.floor(midX)
	local scanMinZ, scanMaxZ = 1, math.floor(midZ)

	local candidates = {}
	for sx = scanMinX, scanMaxX do
		for sz = scanMinZ, scanMaxZ do
			-- Only require base-point validity here; group validity checked later
			if isSpotValid(sx, sz) then
				candidates[#candidates + 1] = { x = sx, z = sz }
			end
		end
	end

	Echo("[MetalSpotGen] Found " .. #candidates .. " base candidates in top-left quadrant")

	-- Shuffle candidates for variety
	math.random(); math.random(); math.random()
	shuffle(candidates)

	-- Accept groups until we hit spotsPerQuadrant (each accepted base candidate yields 4 mirrored spots)
	local placedGroups = 0
	local maxFallbackRadius = 24  -- slope cells (~384 world units)

	for i = 1, #candidates do
		if placedGroups >= spotsPerQuadrant then
			break
		end

		local c = candidates[i]
		local sx, sz, group = findNearbyValidGroup(c.x, c.z, maxFallbackRadius, scanMinX, scanMaxX, scanMinZ, scanMaxZ)

		if group then
			-- place the whole group
			for k = 1, 4 do
				markSpot(group[k][1], group[k][2])
			end
			placedGroups = placedGroups + 1
		end
	end

	Echo(string.format("[MetalSpotGen] Placed %d groups (target %d), total spots: %d",
	                   placedGroups, spotsPerQuadrant, #metalSpots))

	-- Export
	GG.metalMakerSpots = metalSpots

	for i, spot in ipairs(metalSpots) do
		Spring.SetGameRulesParam("metalSpot_" .. i .. "_x", spot.x)
		Spring.SetGameRulesParam("metalSpot_" .. i .. "_z", spot.z)
	end
	Spring.SetGameRulesParam("metalSpot_count", #metalSpots)
end
