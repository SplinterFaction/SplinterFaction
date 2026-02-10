-- luarules/metalmakerspots/helpers.lua
-- Generic placement helpers shared by multiple algorithms.
-- Returns a factory: Helpers.New(ctx) -> helpers table

local H = {}

local function shuffle(t)
	for i = #t, 2, -1 do
		local j = math.random(i)
		t[i], t[j] = t[j], t[i]
	end
end

function H.New(ctx)
	-- Expect ctx to provide:
	-- Spring, Game
	-- SetSquareBuildingMask, GetGroundHeight, Echo
	-- cfg: { FOOTPRINT, MIN_SPOT_SPACING, ELEVATION_TOLERANCE, EDGE_MARGIN, ... }
	-- allowWaterSpots: bool

	local Game   = ctx.Game
	local GetGroundHeight = ctx.GetGroundHeight
	local SetSquareBuildingMask = ctx.SetSquareBuildingMask

	local mapSizeX  = Game.mapSizeX
	local mapSizeZ  = Game.mapSizeZ
	local slopeMapX = math.floor(mapSizeX / 16)
	local slopeMapZ = math.floor(mapSizeZ / 16)

	local cfg = ctx.cfg
	local allowWaterSpots = ctx.allowWaterSpots

	local helpers = {}

	helpers.shuffle = shuffle

	helpers.mapSizeX, helpers.mapSizeZ = mapSizeX, mapSizeZ
	helpers.slopeMapX, helpers.slopeMapZ = slopeMapX, slopeMapZ

	-- storage lives in ctx.spots so every algo shares the same placed list + spacing checks
	ctx.spots = ctx.spots or {}
	local placed = ctx.spots

	function helpers.IsWithinMapBounds(wx, wz)
		return wx > cfg.EDGE_MARGIN and wx < (mapSizeX - cfg.EDGE_MARGIN)
		   and wz > cfg.EDGE_MARGIN and wz < (mapSizeZ - cfg.EDGE_MARGIN)
	end

	function helpers.IsFlatEnough(sx, sz)
		-- slope coords (16 world units per cell)
		local minY, maxY = nil, nil
		local radius = math.floor(cfg.FOOTPRINT / 2) -- for 5 => 2

		for dx = -radius, radius do
			for dz = -radius, radius do
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

		return (maxY - minY) <= cfg.ELEVATION_TOLERANCE
	end

	function helpers.IsFarEnoughFromPlaced(wx, wz)
		local min2 = cfg.MIN_SPOT_SPACING * cfg.MIN_SPOT_SPACING
		for _, spot in ipairs(placed) do
			local dx = spot.x - wx
			local dz = spot.z - wz
			if (dx*dx + dz*dz) < min2 then
				return false
			end
		end
		return true
	end

	function helpers.MarkSpot(sx, sz, maskValue)
		maskValue = maskValue or 4

		local radius = math.floor(cfg.FOOTPRINT / 2)
		for dx = -radius, radius do
			for dz = -radius, radius do
				local mx = sx + dx
				local mz = sz + dz
				if mx >= 0 and mx < slopeMapX and mz >= 0 and mz < slopeMapZ then
					SetSquareBuildingMask(mx, mz, maskValue)
				end
			end
		end

		local wx = sx * 16
		local wz = sz * 16
		local wy = GetGroundHeight(wx, wz)

		placed[#placed + 1] = { x = wx, y = wy, z = wz }
		return placed[#placed]
	end

	function helpers.IsSpotValid(sx, sz)
		if sx < 0 or sx >= slopeMapX or sz < 0 or sz >= slopeMapZ then
			return false
		end
		local wx = sx * 16
		local wz = sz * 16
		if not helpers.IsWithinMapBounds(wx, wz) then
			return false
		end
		if not helpers.IsFlatEnough(sx, sz) then
			return false
		end
		return true
	end

	-- Mirrors are optional: not every algo uses them, but they’re available.
	function helpers.GetMirrors4(sx, sz)
		local midX = math.floor(slopeMapX / 2)
		local midZ = math.floor(slopeMapZ / 2)
		local dx = sx - midX
		local dz = sz - midZ
		return {
			{ midX + dx, midZ + dz },
			{ midX - dx, midZ + dz },
			{ midX + dx, midZ - dz },
			{ midX - dx, midZ - dz },
		}
	end

	function helpers.IsGroupValid(group)
		-- group is array of {sx,sz} pairs
		local min2 = cfg.MIN_SPOT_SPACING * cfg.MIN_SPOT_SPACING

		for i = 1, #group do
			local sx, sz = group[i][1], group[i][2]
			if not helpers.IsSpotValid(sx, sz) then
				return false
			end
			local wx, wz = sx * 16, sz * 16
			if not helpers.IsFarEnoughFromPlaced(wx, wz) then
				return false
			end
		end

		-- no self-collision inside group
		for i = 1, #group do
			local wx1, wz1 = group[i][1]*16, group[i][2]*16
			for j = i + 1, #group do
				local wx2, wz2 = group[j][1]*16, group[j][2]*16
				local dx, dz = wx1 - wx2, wz1 - wz2
				if (dx*dx + dz*dz) < min2 then
					return false
				end
			end
		end

		return true
	end

	function helpers.FindNearbyValidGroup(makeGroupFn, startX, startZ, maxRadius, clamp)
		-- makeGroupFn(sx,sz) -> group array
		-- clamp: {minX,maxX,minZ,maxZ} optional
		local function inClamp(sx, sz)
			if not clamp then return true end
			return sx >= clamp.minX and sx <= clamp.maxX and sz >= clamp.minZ and sz <= clamp.maxZ
		end

		do
			local g = makeGroupFn(startX, startZ)
			if g and helpers.IsGroupValid(g) then
				return startX, startZ, g
			end
		end

		for r = 1, maxRadius do
			for dx = -r, r do
				for dz = -r, r do
					if (math.abs(dx) == r) or (math.abs(dz) == r) then
						local sx = startX + dx
						local sz = startZ + dz
						if inClamp(sx, sz) then
							local g = makeGroupFn(sx, sz)
							if g and helpers.IsGroupValid(g) then
								return sx, sz, g
							end
						end
					end
				end
			end
		end

		return nil
	end

	return helpers
end

return H