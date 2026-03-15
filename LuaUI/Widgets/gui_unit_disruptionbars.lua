function widget:GetInfo()
	return {
		name      = "Unit Disruption Bars",
		desc      = "Draws a disruption bar on the screen-right edge of each unit's projected selection box (UnitRulesParam 'disruption')",
		author    = "",
		date      = "2026-03-14",
		license   = "GNU GPL, v2 or later",
		layer     = 10,
		enabled   = true,
	}
end

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

local DISRUPTION_RULESPARAM           = "disruption"             -- gadget sets 0..100
local DISRUPTED_RULESPARAM            = "disruption_disrupted"   -- gadget sets 0/1

-- Bar styling (screen-space pixels)
local BAR_W         = 5
local BAR_PADDING   = 3
local MIN_DRAW      = 0.5 -- don't draw <= this (%)

local OUTLINE       = true
local OUTLINE_PX    = 1

-- Performance
local UPDATE_FRAMES = 5

local HEIGHT_MULT   = 2.5 -- 1.0 = exact model height

-- Pulse effect when fully disrupted
local PULSE_SPEED   = 0.18
local PULSE_MIN     = 0.65
local PULSE_MAX     = 1.00

--------------------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------------------

local spGetVisibleUnits       = Spring.GetVisibleUnits
local spGetUnitRulesParam     = Spring.GetUnitRulesParam
local spGetGameFrame          = Spring.GetGameFrame
local spGetUnitPosition       = Spring.GetUnitPosition
local spGetUnitDefID          = Spring.GetUnitDefID
local spGetUnitDefDimensions  = Spring.GetUnitDefDimensions
local WorldToScreenCoords     = Spring.WorldToScreenCoords
local spGetCameraVectors      = Spring.GetCameraVectors

local glColor = gl.Color
local glRect  = gl.Rect

local mathMin  = math.min
local mathMax  = math.max
local mathSin  = math.sin

local cachedDisruption = {} -- [unitID] = disruption 0..100
local cachedDisrupted  = {} -- [unitID] = 0/1
local lastUpdateFrame = -1

-- dimsCache[udid] = {minx,maxx,miny,maxy,minz,maxz}
local dimsCache = {}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function clamp(x, a, b)
	if x < a then return a end
	if x > b then return b end
	return x
end

-- White -> cyan-blue gradient for t in [0..1]
-- Low disruption = white
-- High disruption = bright electric cyan/blue
local function DisruptionColor(t)
	t = clamp(t, 0, 1)

	-- Blend toward a bright cyan-blue rather than deep pure blue
	local r = 1.0 - (0.55 * t)
	local g = 1.0 - (0.20 * t)
	local b = 1.0

	return r, g, b, 1
end

local function DrawOutline(x1, y1, x2, y2, alphaMult)
	if not OUTLINE then return end
	alphaMult = alphaMult or 1
	glColor(0, 0, 0, 0.85 * alphaMult)
	glRect(x1 - OUTLINE_PX, y1 - OUTLINE_PX, x1, y2 + OUTLINE_PX) -- left
	glRect(x2, y1 - OUTLINE_PX, x2 + OUTLINE_PX, y2 + OUTLINE_PX) -- right
	glRect(x1 - OUTLINE_PX, y1 - OUTLINE_PX, x2 + OUTLINE_PX, y1) -- bottom
	glRect(x1 - OUTLINE_PX, y2, x2 + OUTLINE_PX, y2 + OUTLINE_PX) -- top
end

local function UpdateCache(frame)
	if frame == lastUpdateFrame then return end
	lastUpdateFrame = frame

	local units = spGetVisibleUnits(nil, nil, false)
	if not units then return end

	for i = 1, #units do
		local unitID = units[i]

		local disruption = spGetUnitRulesParam(unitID, DISRUPTION_RULESPARAM)
		if disruption then
			cachedDisruption[unitID] = disruption
		else
			cachedDisruption[unitID] = nil
		end

		local disrupted = spGetUnitRulesParam(unitID, DISRUPTED_RULESPARAM)
		if disrupted then
			cachedDisrupted[unitID] = disrupted
		else
			cachedDisrupted[unitID] = 0
		end
	end
end

local function GetDims(udid)
	local d = dimsCache[udid]
	if d then return d end

	local dims = spGetUnitDefDimensions(udid)
	if dims and dims.minx then
		d = {
			dims.minx, dims.maxx,
			dims.miny, dims.maxy,
			dims.minz, dims.maxz
		}
	else
		local ud = UnitDefs[udid]
		local r = (ud and ud.radius) or 20
		local h = (ud and ud.height) or 40
		d = { -r, r, 0, h, -r, r }
	end

	dimsCache[udid] = d
	return d
end

-- Returns: rightEdgeX, bottomY, topY in screen space
local function ProjectStableDisruptionBarScreen(unitID, udid)
	local px, py, pz = spGetUnitPosition(unitID)
	if not px then return nil end

	local d = GetDims(udid)
	local miny, maxy = d[3], d[4]

	local centerY = (miny + maxy) * 0.5
	local halfHeight = (maxy - miny) * 0.5 * HEIGHT_MULT
	miny = centerY - halfHeight
	maxy = centerY + halfHeight

	local ud = UnitDefs[udid]
	local r = (ud and ud.radius) or 20

	local cam = spGetCameraVectors()
	if not cam or not cam.right then
		return nil
	end

	local rx, ry, rz = cam.right[1], cam.right[2], cam.right[3]

	local wx_bot, wy_bot, wz_bot = px, py + miny, pz
	local wx_top, wy_top, wz_top = px, py + maxy, pz

	local midy = py + (miny + maxy) * 0.5
	local wx_right = px + rx * r
	local wy_right = midy + ry * r
	local wz_right = pz + rz * r

	local sx_right, _, sz_right = WorldToScreenCoords(wx_right, wy_right, wz_right)
	local _, sy_bot, sz_bot     = WorldToScreenCoords(wx_bot,   wy_bot,   wz_bot)
	local _, sy_top, sz_top     = WorldToScreenCoords(wx_top,   wy_top,   wz_top)

	if not (sz_right and sz_bot and sz_top) then return nil end
	if sz_right <= 0 or sz_bot <= 0 or sz_top <= 0 then return nil end

	local bottomY = mathMin(sy_bot, sy_top)
	local topY    = mathMax(sy_bot, sy_top)

	local minPixelHeight = 18
	local height = topY - bottomY
	if height < minPixelHeight then
		local mid = (topY + bottomY) * 0.5
		bottomY = mid - minPixelHeight * 0.5
		topY    = mid + minPixelHeight * 0.5
	end

	return sx_right, bottomY, topY
end

local function GetPulseAlpha(frame)
	local s = (mathSin(frame * PULSE_SPEED) + 1) * 0.5
	return PULSE_MIN + (PULSE_MAX - PULSE_MIN) * s
end

--------------------------------------------------------------------------------
-- Draw
--------------------------------------------------------------------------------

function widget:DrawScreen()
	local frame = spGetGameFrame()
	if frame % UPDATE_FRAMES == 0 then
		UpdateCache(frame)
	end

	local units = spGetVisibleUnits(nil, nil, false)
	if not units then return end

	local pulseAlpha = GetPulseAlpha(frame)

	for i = 1, #units do
		local unitID = units[i]
		local disruption = cachedDisruption[unitID]

		if disruption and disruption > MIN_DRAW then
			local udid = spGetUnitDefID(unitID)
			if udid then
				local rightX, botY, topY = ProjectStableDisruptionBarScreen(unitID, udid)
				if rightX then
					local x1 = rightX + BAR_PADDING
					local x2 = x1 + BAR_W
					local y1 = botY
					local y2 = topY

					local h = y2 - y1
					if h > 4 then
						local t = clamp(disruption / 100, 0, 1)
						local fy2 = y1 + h * t

						local isDisrupted = (cachedDisrupted[unitID] == 1)
						local alphaMult = isDisrupted and pulseAlpha or 1

						DrawOutline(x1, y1, x2, y2, alphaMult)

						-- Background
						glColor(0, 0, 0, 0.35 * alphaMult)
						glRect(x1, y1, x2, y2)

						-- Fill
						local r, g, b, _ = DisruptionColor(t)
						glColor(r, g, b, 0.92 * alphaMult)
						glRect(x1, y1, x2, fy2)

						-- Add a brighter inner flash when fully disrupted
						if isDisrupted then
							local inset = 1
							if (x2 - x1) > 2 and (fy2 - y1) > 2 then
								glColor(1, 1, 1, 0.18 * pulseAlpha)
								glRect(x1 + inset, y1 + inset, x2 - inset, fy2 - inset)
							end
						end
					end
				end
			end
		end
	end

	glColor(1, 1, 1, 1)
end

function widget:Shutdown()
	cachedDisruption = {}
	cachedDisrupted = {}
end