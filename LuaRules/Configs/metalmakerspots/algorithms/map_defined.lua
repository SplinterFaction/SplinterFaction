local M = {}

M.name = "map_defined_metal_autocenter"

M.policy = {
	-- If true, generator will recompute metalSpot_value using actual placed count
	-- whenever placedCount ~= ctx.spotsTarget.
	recalcSpotValueOnActualCount = true,
}

M.defaults = {
	-- Core shared defaults (required by helpers.lua)
	FOOTPRINT = 5,
	MIN_SPOT_SPACING = 150,
	ELEVATION_TOLERANCE = 15,
	EDGE_MARGIN = 100,
	ALLOW_OVER_TARGET = true,

	-- Metal map scan settings (map squares are 16 elmos)
	METAL_THRESHOLD = 0.10,     -- average metal in 3x3 to count as a spot
	CLUSTER_RADIUS  = 9,        -- in map squares, used to avoid near-duplicates
	SAMPLE_STEP     = 1,        -- step in map squares for scanning

	-- NEW: auto-centering search around detected spot
	CENTER_SEARCH_RADIUS = 2,   -- in map squares (2 => check a 5x5 neighborhood)

	-- Selection behavior if there are more map spots than we want
	QUADRANT_BALANCE = false,
}

local function shuffle(t)
	for i = #t, 2, -1 do
		local j = math.random(i)
		t[i], t[j] = t[j], t[i]
	end
end

-- Average metal in a 3x3 around a center cell (map-square coords)
local function MetalAvg3x3(cx, cz)
	local sum = 0
	for dx = -1, 1 do
		for dz = -1, 1 do
			sum = sum + (Spring.GetMetalAmount(cx + dx, cz + dz) or 0)
		end
	end
	return sum / 9
end

-- Given an initial center (map-square coords), search nearby and pick best 3x3 avg
local function FindBestCenter(cx, cz, radius, mapSquaresX, mapSquaresZ)
	local bestX, bestZ = cx, cz
	local bestAvg = MetalAvg3x3(cx, cz)

	for ox = -radius, radius do
		for oz = -radius, radius do
			local x = cx + ox
			local z = cz + oz

			-- keep 3x3 window within map bounds
			if x >= 1 and x <= (mapSquaresX - 2) and z >= 1 and z <= (mapSquaresZ - 2) then
				local avg = MetalAvg3x3(x, z)
				if avg > bestAvg then
					bestAvg = avg
					bestX, bestZ = x, z
				end
			end
		end
	end

	return bestX, bestZ, bestAvg
end

-- Build candidate spots from the map metal data.
-- Returns list of { sx, sz, metal, quad }
-- where sx/sz are slope coords (16 elmos per cell)
local function GatherMapMetalSpots(ctx, helpers)
	local cfg = ctx.cfg

	local mapSquaresX = math.floor(Game.mapSizeX / 16)
	local mapSquaresZ = math.floor(Game.mapSizeZ / 16)

	local clusterRadius = cfg.CLUSTER_RADIUS or 9
	local clusterRadiusSq = clusterRadius * clusterRadius

	local threshold = cfg.METAL_THRESHOLD or 0.10
	local step = cfg.SAMPLE_STEP or 1
	if step < 1 then step = 1 end

	local centerRadius = cfg.CENTER_SEARCH_RADIUS or 0
	if centerRadius < 0 then centerRadius = 0 end

	local claimed = {} -- {x,z} in map-square coords

	local function isClaimed(cx, cz)
		for i = 1, #claimed do
			local e = claimed[i]
			local dx = cx - e.x
			local dz = cz - e.z
			if (dx*dx + dz*dz) < clusterRadiusSq then
				return true
			end
		end
		return false
	end

	local midSX = math.floor(helpers.slopeMapX / 2)
	local midSZ = math.floor(helpers.slopeMapZ / 2)

	local spots = {}

	-- Scan like your original: evaluate 3x3 blocks, claim near centers
	for x = 1, mapSquaresX - 2, step do
		for z = 1, mapSquaresZ - 2, step do
			local cx = x + 1
			local cz = z + 1

			if not isClaimed(cx, cz) then
				local avg = MetalAvg3x3(cx, cz)

				if avg >= threshold then
					-- NEW: refine the center by searching nearby for best 3x3 avg
					local bestX, bestZ, bestAvg = cx, cz, avg
					if centerRadius > 0 then
						bestX, bestZ, bestAvg = FindBestCenter(cx, cz, centerRadius, mapSquaresX, mapSquaresZ)
					end

					local sx = bestX
					local sz = bestZ

					local quad
					if sx < midSX then
						quad = (sz < midSZ) and 1 or 3
					else
						quad = (sz < midSZ) and 2 or 4
					end

					spots[#spots + 1] = { sx = sx, sz = sz, metal = bestAvg, quad = quad }
					claimed[#claimed + 1] = { x = cx, z = cz } -- keep original claim center to prevent duplicates
				end
			end
		end
	end

	return spots
end

local function SelectSubset(cands, targetTotal, quadrantBalance)
	if targetTotal <= 0 then return {} end
	if #cands <= targetTotal then return cands end

	shuffle(cands)

	if not quadrantBalance then
		local out = {}
		for i = 1, targetTotal do
			out[i] = cands[i]
		end
		return out
	end

	local basePerQuad = math.floor(targetTotal / 4)
	local rem = targetTotal - basePerQuad * 4
	local targetPerQuad = { basePerQuad, basePerQuad, basePerQuad, basePerQuad }
	for i = 1, rem do
		targetPerQuad[i] = targetPerQuad[i] + 1
	end

	local buckets = { {}, {}, {}, {} }
	for i = 1, #cands do
		local q = cands[i].quad or 1
		buckets[q][#buckets[q] + 1] = cands[i]
	end
	for q = 1, 4 do shuffle(buckets[q]) end

	local out = {}
	for q = 1, 4 do
		local want = targetPerQuad[q]
		local b = buckets[q]
		for i = 1, math.min(want, #b) do
			out[#out + 1] = b[i]
		end
	end

	-- Top up from anywhere if some quadrants ran short
	if #out < targetTotal then
		for i = 1, #cands do
			if #out >= targetTotal then break end
			local c = cands[i]
			local already = false
			for j = 1, #out do
				if out[j] == c then already = true break end
			end
			if not already then
				out[#out + 1] = c
			end
		end
	end

	return out
end

function M.Generate(ctx, helpers)
	local cfg = ctx.cfg
	local Echo = ctx.Echo

	math.random(); math.random(); math.random()

	local candidates = GatherMapMetalSpots(ctx, helpers)
	Echo(string.format(
			"[MetalSpotGen] %s found %d raw map metal candidates (centerRadius=%d)",
			M.name, #candidates, (cfg.CENTER_SEARCH_RADIUS or 0)
	))

	local targetTotal = ctx.spotsTarget or 0

	local selected
	if cfg.ALLOW_OVER_TARGET then
		selected = candidates
	else
		selected = SelectSubset(candidates, targetTotal, cfg.QUADRANT_BALANCE)
	end

	local placed = 0
	for i = 1, #selected do
		local s = selected[i]
		local sx, sz = s.sx, s.sz

		if helpers.IsSpotValid(sx, sz) then
			local wx, wz = sx * 16, sz * 16
			if helpers.IsFarEnoughFromPlaced(wx, wz) then
				helpers.MarkSpot(sx, sz, 4)
				placed = placed + 1
			end
		end
	end

	Echo(string.format(
			"[MetalSpotGen] %s candidates=%d selected=%d target=%d allowOver=%s recalcValue=%s",
			M.name, #candidates, #selected, targetTotal,
			tostring(cfg.ALLOW_OVER_TARGET),
			tostring((M.policy and M.policy.recalcSpotValueOnActualCount) == true)
	))

	return {
		placedSpots = placed,
		foundCandidates = #candidates,
		selectedCandidates = #selected,
	}
end

return M