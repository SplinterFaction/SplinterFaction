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

-- Does the map set voidwater?  On such maps (asteroids, floating islands) the
-- engine draws nothing where the ground is at or below the waterline, so that
-- area is landmass that does not exist.  The engine exposes the flag to
-- unsynced code only, so synced reads it from mapinfo.lua.  The engine's own
-- parser is case-insensitive; the raw table from VFS.Include is not, so every
-- spelling of the key is accepted.  Cached after the first call.
local voidWaterCached = nil
function H.MapHasVoidWater()
	if voidWaterCached == nil then
		voidWaterCached = false
		local ok, mi = pcall(VFS.Include, "mapinfo.lua", nil, VFS.MAP)
		if ok and type(mi) == "table" then
			for k, v in pairs(mi) do
				if type(k) == "string" and string.lower(k) == "voidwater" then
					voidWaterCached = (v == true or v == 1 or v == "1" or v == "true")
					break
				end
			end
		end
	end
	return voidWaterCached
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

	-- Voidwater maps: algorithms place spots as if the void were ordinary
	-- land (so the water modoption is ignored here), and the spots that end
	-- up in the void are removed afterwards by helpers.DropVoidSpots().  The
	-- land that does exist keeps the density it would have had on a full map.
	local voidWater = H.MapHasVoidWater()

	local helpers = {}

	helpers.voidWater = voidWater

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

				if not allowWaterSpots and not voidWater and wy < 0 then
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

		-- One square of margin past the footprint. The engine rounds a build
		-- position to 16 units and adds half a square for an odd footprint, and
		-- not every check it runs rounds the same way, so a block sized exactly
		-- to the footprint can miss by 8 units and leave a row of the building
		-- on unmasked ground. The margin absorbs that.
		local radius = math.floor(cfg.FOOTPRINT / 2) + 1
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

	-- Does any part of the spot's footprint (plus the same one-square margin
	-- MarkSpot masks) sit at or below the waterline?
	function helpers.IsSpotInVoid(sx, sz)
		local radius = math.floor(cfg.FOOTPRINT / 2) + 1
		for dx = -radius, radius do
			for dz = -radius, radius do
				if GetGroundHeight((sx + dx) * 16, (sz + dz) * 16) <= 0 then
					return true
				end
			end
		end
		return false
	end

	-- Voidwater maps only: remove every placed spot that sits in the void and
	-- hand its squares back to the default building mask.  Edits ctx.spots in
	-- place and returns the number removed.  A no-op on ordinary maps.
	function helpers.DropVoidSpots()
		if not voidWater then return 0 end
		local radius = math.floor(cfg.FOOTPRINT / 2) + 1

		local function Mask(spot, value)
			local sx, sz = math.floor(spot.x / 16 + 0.5), math.floor(spot.z / 16 + 0.5)
			for dx = -radius, radius do
				for dz = -radius, radius do
					local mx, mz = sx + dx, sz + dz
					if mx >= 0 and mx < slopeMapX and mz >= 0 and mz < slopeMapZ then
						SetSquareBuildingMask(mx, mz, value)
					end
				end
			end
		end

		local keptCount, dropped = 0, 0
		local total = #placed
		for i = 1, total do
			local spot = placed[i]
			if helpers.IsSpotInVoid(math.floor(spot.x / 16 + 0.5), math.floor(spot.z / 16 + 0.5)) then
				Mask(spot, 1)   -- 1 = the engine's default "normal tile" mask
				dropped = dropped + 1
			else
				keptCount = keptCount + 1
				placed[keptCount] = spot
			end
		end
		for i = keptCount + 1, total do placed[i] = nil end

		-- A dropped spot's block can overlap a surviving neighbor's; restore.
		if dropped > 0 then
			for i = 1, keptCount do Mask(placed[i], 4) end
		end
		return dropped
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