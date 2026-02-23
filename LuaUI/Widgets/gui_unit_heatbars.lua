function widget:GetInfo()
	return {
		name      = "Unit Heat Bars",
		desc      = "Draws a heat bar on the screen-left edge of each unit's projected selection box (UnitRulesParam 'heat')",
		author    = "",
		date      = "2026-02-22",
		license   = "GNU GPL, v2 or later",
		layer     = 10,
		enabled   = true,
	}
end

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

local HEAT_RULESPARAM = "heat"     -- gadget sets 0..100

-- Bar styling (screen-space pixels)
local BAR_W        = 5            -- bar width in pixels
local BAR_PADDING  = 3            -- extra pixels to the left of the box edge
local MIN_HEAT_DRAW = 0.5         -- don't draw <= this (%)

local OUTLINE      = true
local OUTLINE_PX   = 1

-- Performance
local UPDATE_FRAMES = 5           -- cache heat values this often

local HEIGHT_MULT = 2.5  -- 1.0 = exact model height

--------------------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------------------

local spGetVisibleUnits       = Spring.GetVisibleUnits
local spGetUnitRulesParam     = Spring.GetUnitRulesParam
local spGetGameFrame          = Spring.GetGameFrame
local spGetUnitPosition       = Spring.GetUnitPosition
local spGetUnitHeading        = Spring.GetUnitHeading
local spGetUnitDefID          = Spring.GetUnitDefID
local spGetUnitDefDimensions  = Spring.GetUnitDefDimensions
local WorldToScreenCoords     = Spring.WorldToScreenCoords
local spGetCameraVectors      = Spring.GetCameraVectors

local glColor = gl.Color
local glRect  = gl.Rect

local cachedHeat = {}  -- [unitID] = heat 0..100
local lastUpdateFrame = -1

-- Cache AABB dims per unitDefID:
-- dimsCache[udid] = {minx,maxx,miny,maxy,minz,maxz}
local dimsCache = {}

local function clamp(x, a, b)
	if x < a then return a end
	if x > b then return b end
	return x
end

-- Green -> Yellow -> Red gradient for t in [0..1]
local function HeatColor(t)
	t = clamp(t, 0, 1)
	if t <= 0.5 then
		local k = t / 0.5
		return k, 1, 0, 1
	else
		local k = (t - 0.5) / 0.5
		return 1, 1 - k, 0, 1
	end
end

local function DrawOutline(x1, y1, x2, y2)
	if not OUTLINE then return end
	glColor(0, 0, 0, 0.85)
	-- left
	glRect(x1 - OUTLINE_PX, y1 - OUTLINE_PX, x1, y2 + OUTLINE_PX)
	-- right
	glRect(x2, y1 - OUTLINE_PX, x2 + OUTLINE_PX, y2 + OUTLINE_PX)
	-- bottom
	glRect(x1 - OUTLINE_PX, y1 - OUTLINE_PX, x2 + OUTLINE_PX, y1)
	-- top
	glRect(x1 - OUTLINE_PX, y2, x2 + OUTLINE_PX, y2 + OUTLINE_PX)
end

local function UpdateCache(frame)
	if frame == lastUpdateFrame then return end
	lastUpdateFrame = frame

	local units = spGetVisibleUnits(nil, nil, false)
	if not units then return end

	for i = 1, #units do
		local unitID = units[i]
		local heat = spGetUnitRulesParam(unitID, HEAT_RULESPARAM)
		if heat then
			cachedHeat[unitID] = heat
		else
			cachedHeat[unitID] = nil
		end
	end
end

local function GetDims(udid)
	local d = dimsCache[udid]
	if d then return d end

	-- Spring.GetUnitDefDimensions returns model-space extents in elmos
	local dims = spGetUnitDefDimensions(udid)
	if dims and dims.minx then
		d = {
			dims.minx, dims.maxx,
			dims.miny, dims.maxy,
			dims.minz, dims.maxz
		}
	else
		-- Fallback: approximate with radius/height if dims unavailable
		local ud = UnitDefs[udid]
		local r = (ud and ud.radius) or 20
		local h = (ud and ud.height) or 40
		d = { -r, r, 0, h, -r, r }
	end

	dimsCache[udid] = d
	return d
end

-- Project unit AABB corners (rotated by heading around Y) and return:
-- leftEdgeX, bottomY, topY in screen space, or nil if offscreen
-- Returns: leftEdgeX, bottomY, topY in screen space, stable vs unit heading
local function ProjectStableHeatBarScreen(unitID, udid)
	local px, py, pz = spGetUnitPosition(unitID)
	if not px then return nil end

	local d = GetDims(udid)
	local miny, maxy = d[3], d[4]

	-- Expand vertically around center
	local centerY = (miny + maxy) * 0.5
	local halfHeight = (maxy - miny) * 0.5 * HEIGHT_MULT
	miny = centerY - halfHeight
	maxy = centerY + halfHeight

	-- Use unit radius to push to the camera-left side consistently.
	-- (camera "right" vector points to screen-right; subtract to go screen-left)
	local ud = UnitDefs[udid]
	local r = (ud and ud.radius) or 20

	local cam = spGetCameraVectors()
	if not cam or not cam.right then
		return nil
	end

	local rx, ry, rz = cam.right[1], cam.right[2], cam.right[3]

	-- World points:
	-- bottom/top at unit center (vertical span)
	local wx_bot, wy_bot, wz_bot = px, py + miny, pz
	local wx_top, wy_top, wz_top = px, py + maxy, pz

	-- left anchor point at mid height, offset in camera-left direction by radius
	local midy = py + (miny + maxy) * 0.5
	local wx_left = px - rx * r
	local wy_left = midy - ry * r
	local wz_left = pz - rz * r

	local sx_left, sy_left, sz_left = WorldToScreenCoords(wx_left, wy_left, wz_left)
	local sx_bot,  sy_bot,  sz_bot  = WorldToScreenCoords(wx_bot,  wy_bot,  wz_bot)
	local sx_top,  sy_top,  sz_top  = WorldToScreenCoords(wx_top,  wy_top,  wz_top)

	-- If any are behind the camera, bail out (simple + safe)
	if not (sz_left and sz_bot and sz_top) then return nil end
	if sz_left <= 0 or sz_bot <= 0 or sz_top <= 0 then return nil end

	local bottomY = math.min(sy_bot, sy_top)
	local topY    = math.max(sy_bot, sy_top)

	-- Minimum pixel height clamp (screen-space)
	local minPixelHeight = 18  -- tweak this
	local height = topY - bottomY

	if height < minPixelHeight then
		local mid = (topY + bottomY) * 0.5
		bottomY = mid - minPixelHeight * 0.5
		topY    = mid + minPixelHeight * 0.5
	end

	return sx_left, bottomY, topY
end

function widget:DrawScreen()
	local frame = spGetGameFrame()
	if frame % UPDATE_FRAMES == 0 then
		UpdateCache(frame)
	end

	local units = spGetVisibleUnits(nil, nil, false)
	if not units then return end

	for i = 1, #units do
		local unitID = units[i]
		local heat = cachedHeat[unitID]
		if heat and heat > MIN_HEAT_DRAW then
			local udid = spGetUnitDefID(unitID)
			if udid then
				local leftX, botY, topY = ProjectStableHeatBarScreen(unitID, udid)
				if leftX then
					-- Bar sits on the left edge in screen space
					local x2 = leftX - BAR_PADDING
					local x1 = x2 - BAR_W
					local y1 = botY
					local y2 = topY

					-- Avoid degenerate / tiny boxes
					local h = y2 - y1
					if h > 4 then
						-- Outline + background
						DrawOutline(x1, y1, x2, y2)

						glColor(0, 0, 0, 0.35)
						glRect(x1, y1, x2, y2)

						-- Fill bottom-up
						local t = clamp(heat / 100, 0, 1)
						local fy2 = y1 + h * t

						local r, g, b, a = HeatColor(t)
						glColor(r, g, b, 0.9)
						glRect(x1, y1, x2, fy2)
					end
				end
			end
		end
	end

	glColor(1, 1, 1, 1)
end

function widget:Shutdown()
	cachedHeat = {}
end