local M = {}

M.name = "stratified_random_quadrant_balanced"
M.defaults = {
	FOOTPRINT = 5,
	MIN_SPOT_SPACING = 150,
	ELEVATION_TOLERANCE = 15,
	EDGE_MARGIN = 100,

	BUCKETS_X = 6,
	BUCKETS_Z = 6,
	TRIES_PER_BUCKET = 30,

	-- NEW: total number of bucket-attempts per quadrant before we give up
	MAX_BUCKET_VISITS_PER_QUADRANT = 2000,
}

local function randInt(a, b)
	return a + math.floor(math.random() * (b - a + 1))
end

function M.Generate(ctx, helpers)
	local cfg  = ctx.cfg
	local Echo = ctx.Echo

	local slopeMapX, slopeMapZ = helpers.slopeMapX, helpers.slopeMapZ

	local marginSlopeX = math.floor(cfg.EDGE_MARGIN / 16)
	local marginSlopeZ = math.floor(cfg.EDGE_MARGIN / 16)

	local minSX = marginSlopeX
	local maxSX = slopeMapX - 1 - marginSlopeX
	local minSZ = marginSlopeZ
	local maxSZ = slopeMapZ - 1 - marginSlopeZ

	local midSX = math.floor(slopeMapX / 2)
	local midSZ = math.floor(slopeMapZ / 2)

	local bucketsX = math.max(1, cfg.BUCKETS_X)
	local bucketsZ = math.max(1, cfg.BUCKETS_Z)

	local rangeX = (maxSX - minSX + 1)
	local rangeZ = (maxSZ - minSZ + 1)

	local bucketW = math.max(1, math.ceil(rangeX / bucketsX))
	local bucketH = math.max(1, math.ceil(rangeZ / bucketsZ))

	local targetTotal = ctx.spotsTarget or 0
	if targetTotal <= 0 then
		return { placedSpots = 0 }
	end

	local basePerQuad = math.floor(targetTotal / 4)
	local remainder   = targetTotal - (basePerQuad * 4)

	local targetPerQuad = { basePerQuad, basePerQuad, basePerQuad, basePerQuad }
	for i = 1, remainder do
		targetPerQuad[i] = targetPerQuad[i] + 1
	end

	local placedPerQuad = { 0, 0, 0, 0 }
	local placedTotal = 0

	local bucketsByQuad = { {}, {}, {}, {} }

	for bx = 0, bucketsX - 1 do
		for bz = 0, bucketsZ - 1 do
			local bMinX = minSX + bx * bucketW
			local bMaxX = math.min(maxSX, bMinX + bucketW - 1)
			local bMinZ = minSZ + bz * bucketH
			local bMaxZ = math.min(maxSZ, bMinZ + bucketH - 1)

			if bMinX <= bMaxX and bMinZ <= bMaxZ then
				local cx = math.floor((bMinX + bMaxX) / 2)
				local cz = math.floor((bMinZ + bMaxZ) / 2)

				local quad
				if cx < midSX then
					quad = (cz < midSZ) and 1 or 3
				else
					quad = (cz < midSZ) and 2 or 4
				end

				bucketsByQuad[quad][#bucketsByQuad[quad] + 1] = {
					bMinX = bMinX, bMaxX = bMaxX,
					bMinZ = bMinZ, bMaxZ = bMaxZ,
				}
			end
		end
	end

	math.random(); math.random(); math.random()
	for q = 1, 4 do
		helpers.shuffle(bucketsByQuad[q])
	end

	-- Try to place 1 spot in a given bucket (returns true if placed)
	local function tryPlaceInBucket(b)
		for t = 1, cfg.TRIES_PER_BUCKET do
			local sx = randInt(b.bMinX, b.bMaxX)
			local sz = randInt(b.bMinZ, b.bMaxZ)

			if helpers.IsSpotValid(sx, sz) then
				local wx, wz = sx * 16, sz * 16
				if helpers.IsFarEnoughFromPlaced(wx, wz) then
					helpers.MarkSpot(sx, sz, 4)
					return true
				end
			end
		end
		return false
	end

	-- Fill each quadrant up to its quota, cycling buckets repeatedly
	for q = 1, 4 do
		local bucketList = bucketsByQuad[q]
		local visits = 0
		local idx = 1

		while placedPerQuad[q] < targetPerQuad[q] and placedTotal < targetTotal do
			if #bucketList == 0 then
				break
			end
			if visits >= cfg.MAX_BUCKET_VISITS_PER_QUADRANT then
				break
			end

			local b = bucketList[idx]
			idx = idx + 1
			if idx > #bucketList then
				idx = 1
				helpers.shuffle(bucketList) -- reshuffle each full cycle
			end

			visits = visits + 1

			if tryPlaceInBucket(b) then
				placedPerQuad[q] = placedPerQuad[q] + 1
				placedTotal = placedTotal + 1
			end
		end
	end

	Echo(string.format(
			"[MetalSpotGen] %s placed=%d/%d (TL=%d TR=%d BL=%d BR=%d)",
			M.name, placedTotal, targetTotal,
			placedPerQuad[1], placedPerQuad[2], placedPerQuad[3], placedPerQuad[4]
	))

	return {
		placedSpots = placedTotal,
		perQuadrant = placedPerQuad,
		targetPerQuadrant = targetPerQuad,
	}
end

return M
