local M = {}

M.name = "mirrored_group_declumped"
M.defaults = {
	FOOTPRINT = 5,
	MIN_SPOT_SPACING = 150,
	ELEVATION_TOLERANCE = 15,
	EDGE_MARGIN = 100,
	MAX_FALLBACK_RADIUS = 24,
}

function M.Generate(ctx, helpers)
	local Echo = ctx.Echo

	local slopeMapX = helpers.slopeMapX
	local slopeMapZ = helpers.slopeMapZ

	local midX = math.floor(slopeMapX / 2)
	local midZ = math.floor(slopeMapZ / 2)

	-- Scan top-left quadrant for base candidates
	local scanMinX, scanMaxX = 1, math.floor(midX)
	local scanMinZ, scanMaxZ = 1, math.floor(midZ)

	local candidates = {}
	for sx = scanMinX, scanMaxX do
		for sz = scanMinZ, scanMaxZ do
			if helpers.IsSpotValid(sx, sz) then
				candidates[#candidates + 1] = { x = sx, z = sz }
			end
		end
	end

	Echo("[MetalSpotGen] " .. M.name .. " base candidates: " .. #candidates)

	math.random(); math.random(); math.random()
	helpers.shuffle(candidates)

	local function makeMirroredGroup(sx, sz)
		return helpers.GetMirrors4(sx, sz)
	end

	local clamp = { minX = scanMinX, maxX = scanMaxX, minZ = scanMinZ, maxZ = scanMaxZ }

	local placedGroups = 0
	for i = 1, #candidates do
		if placedGroups >= ctx.groupsTarget then break end

		local c = candidates[i]
		local _, _, group = helpers.FindNearbyValidGroup(
			makeMirroredGroup,
			c.x, c.z,
			ctx.cfg.MAX_FALLBACK_RADIUS,
			clamp
		)

		if group then
			for k = 1, #group do
				helpers.MarkSpot(group[k][1], group[k][2], 4)
			end
			placedGroups = placedGroups + 1
		end
	end

	return {
		placedGroups = placedGroups,
		candidateCount = #candidates,
	}
end

return M