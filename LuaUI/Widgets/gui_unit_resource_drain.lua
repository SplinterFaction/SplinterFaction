function widget:GetInfo()
	return {
		name      = "Unit Resource Drain Numbers",
		desc      = "Displays your units' metal/energy values flat on the ground beneath them",
		author    = "",
		date      = "2026-03-20",
		license   = "GPL v2 or later",
		layer     = 0,
		enabled   = true,
	}
end

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

local UPDATE_FRAMES      = 8
local MIN_VALUE_TO_SHOW  = 0.05
local TEXT_SIZE          = 16
local MAX_DIST           = 5000
local GROUND_Y_OFFSET    = 1.2   -- lift slightly above terrain to reduce z-fighting

-- "energy", "metal", "both"
local DISPLAY_MODE       = "both"

local ENERGY_COLOR = {1.00, 1.00, 0.00, 1.00}
local METAL_COLOR  = {0.40, 0.95, 1.00, 1.00}
local BOTH_COLOR   = {1.00, 1.00, 1.00, 1.00}

local METAL_POS_COLOR   = {0.40, 0.95, 1.00, 1.00}
local METAL_NEG_COLOR  = {0.85, 0.35, 0.35, 1.00}

local ENERGY_POS_COLOR  = {1.00, 1.00, 0.00, 1.00}
local ENERGY_NEG_COLOR = {1.00, 0.45, 0.00, 1.00}

local OFFSET_FORWARD = 20    -- forward/back relative to text direction
local OFFSET_RIGHT   = 0    -- left/right relative to text
local OFFSET_UP      = 1.2  -- already using this as GROUND_Y_OFFSET

local EDGE_PADDING       = 10    -- extra space beyond the unit edge
local BOTTOM_DIR_X       = 0     -- fixed map direction for "bottom"
local BOTTOM_DIR_Z       = 1     -- 0,1 means toward +Z; use 0,-1 for opposite

local LINE_SPACING = 20

--------------------------------------------------------------------------------
-- Speedups
--------------------------------------------------------------------------------

local spGetGameFrame        = Spring.GetGameFrame
local spGetVisibleUnits     = Spring.GetVisibleUnits
local spGetUnitResources    = Spring.GetUnitResources
local spGetUnitPosition     = Spring.GetUnitPosition
local spGetUnitTeam         = Spring.GetUnitTeam
local spGetMyTeamID         = Spring.GetMyTeamID
local spGetCameraPosition   = Spring.GetCameraPosition
local spIsGUIHidden         = Spring.IsGUIHidden
local spGetUnitRulesParam   = Spring.GetUnitRulesParam
local spGetGroundHeight     = Spring.GetGroundHeight
local spGetGroundNormal     = Spring.GetGroundNormal

local glPushMatrix          = gl.PushMatrix
local glPopMatrix           = gl.PopMatrix
local glTranslate           = gl.Translate
local glText                = gl.Text
local glColor               = gl.Color
local glDepthTest           = gl.DepthTest
local glPolygonOffset       = gl.PolygonOffset
local glMultMatrix          = gl.MultMatrix

local math_abs              = math.abs
local math_floor            = math.floor
local math_sqrt             = math.sqrt

--------------------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------------------

local unitTextCache = {}
local lastUpdateFrame = -math.huge
local myTeamID = spGetMyTeamID()

--------------------------------------------------------------------------------
-- Vector helpers
--------------------------------------------------------------------------------

local function Dot(ax, ay, az, bx, by, bz)
	return ax * bx + ay * by + az * bz
end

local function Cross(ax, ay, az, bx, by, bz)
	return ay * bz - az * by,
	az * bx - ax * bz,
	ax * by - ay * bx
end

local function Normalize(x, y, z)
	local len = math_sqrt(x*x + y*y + z*z)
	if len <= 0.00001 then
		return 0, 1, 0, 0
	end
	return x / len, y / len, z / len, len
end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local math_max  = math.max
local math_abs  = math.abs
local math_sqrt = math.sqrt

local function Normalize2D(x, z)
	local len = math_sqrt(x*x + z*z)
	if len <= 0.00001 then
		return 0, 1
	end
	return x / len, z / len
end

local function GetUnitTopDownExtents(unitID)
	local udid = Spring.GetUnitDefID(unitID)
	if not udid then
		return 20, 20
	end

	local ud = UnitDefs[udid]
	if not ud then
		return 20, 20
	end

	if ud.isBuilding then
		-- xsize/zsize are in build squares; half-extent in elmos is * 4
		local halfX = (ud.xsize or 4) * 4
		local halfZ = (ud.zsize or 4) * 4
		return halfX, halfZ
	end

	-- Mobile fallback
	local r = ud.radius or 20
	return r, r
end

local function GetBottomEdgePosition(unitID, x, z)
	local dirX, dirZ = Normalize2D(BOTTOM_DIR_X, BOTTOM_DIR_Z)

	local halfX, halfZ = GetUnitTopDownExtents(unitID)

	-- Project the unit half-extents onto the chosen bottom direction.
	-- This gives a good top-down "edge distance" for axis-aligned footprints.
	local edgeDist = math_abs(dirX) * halfX + math_abs(dirZ) * halfZ

	local dist = edgeDist + EDGE_PADDING
	return x + dirX * dist, z + dirZ * dist
end

local function Round2(x)
	return math_floor(x * 100 + 0.5) / 100
end

local function GetDisplayedResourceValues(unitID)
	local mMake, mUse, eMake, eUse = spGetUnitResources(unitID)

	local metalNet  = (mMake or 0) - (mUse or 0)
	local energyNet = (eMake or 0) - (eUse or 0)

	return metalNet, energyNet
end

local function FormatSignedValue(prefix, value)
	if value >= 0 then
		return string.format("+%s %.2f", prefix, Round2(value))
	else
		return string.format("-%s %.2f", prefix, Round2(math.abs(value)))
	end
end

local function FormatStackedTexts(metalValue, energyValue)
	local showEnergy = (DISPLAY_MODE == "energy" or DISPLAY_MODE == "both")
	local showMetal  = (DISPLAY_MODE == "metal"  or DISPLAY_MODE == "both")

	local hasMetal  = showMetal  and metalValue  and math.abs(metalValue)  > MIN_VALUE_TO_SHOW
	local hasEnergy = showEnergy and energyValue and math.abs(energyValue) > MIN_VALUE_TO_SHOW

	if not hasMetal and not hasEnergy then
		return nil, nil
	end

	local metalText, energyText

	if hasMetal then
		metalText = FormatSignedValue("M", metalValue)
	end
	if hasEnergy then
		energyText = FormatSignedValue("E", energyValue)
	end

	return metalText, energyText
end

local function GetColor(kind)
	if kind == "energy" then
		return ENERGY_COLOR
	elseif kind == "metal" then
		return METAL_COLOR
	else
		return BOTH_COLOR
	end
end

-- Build a stable terrain-aligned basis so the text lies on the ground and
-- keeps a fixed world orientation instead of turning toward the camera.
local function GetTerrainTextMatrix(x, z)
	local nx, ny, nz = spGetGroundNormal(x, z)
	if not nx then
		nx, ny, nz = 0, 1, 0
	end
	nx, ny, nz = Normalize(nx, ny, nz)

	-- Fixed world direction
	local fx, fy, fz = 0, 0, -1

	-- Project forward onto terrain plane
	local fdotn = Dot(fx, fy, fz, nx, ny, nz)
	fx = fx - nx * fdotn
	fy = fy - ny * fdotn
	fz = fz - nz * fdotn
	fx, fy, fz, flen = Normalize(fx, fy, fz)

	if flen <= 0.00001 then
		fx, fy, fz = 1, 0, 0
		fdotn = Dot(fx, fy, fz, nx, ny, nz)
		fx = fx - nx * fdotn
		fy = fy - ny * fdotn
		fz = fz - nz * fdotn
		fx, fy, fz = Normalize(fx, fy, fz)
	end

	-- Flip forward to un-mirror the text
	fx, fy, fz = -fx, -fy, -fz

	-- right = forward x normal
	local rx, ry, rz = Cross(fx, fy, fz, nx, ny, nz)
	rx, ry, rz = Normalize(rx, ry, rz)

	rx, ry, rz = -rx, -ry, -rz
	fx, fy, fz = -fx, -fy, -fz

	return {
		rx, ry, rz, 0,
		fx, fy, fz, 0,
		nx, ny, nz, 0,
		0,  0,  0,  1,
	}
end

local function ApplyAnchorOffsets(x, y, z)
	local nx, ny, nz = spGetGroundNormal(x, z)
	if not nx then
		nx, ny, nz = 0, 1, 0
	end
	nx, ny, nz = Normalize(nx, ny, nz)

	-- Same fixed world direction used by GetTerrainTextMatrix
	local fx, fy, fz = 0, 0, -1

	-- Project forward onto terrain plane
	local fdotn = Dot(fx, fy, fz, nx, ny, nz)
	fx = fx - nx * fdotn
	fy = fy - ny * fdotn
	fz = fz - nz * fdotn
	fx, fy, fz, flen = Normalize(fx, fy, fz)

	if flen <= 0.00001 then
		fx, fy, fz = 1, 0, 0
		fdotn = Dot(fx, fy, fz, nx, ny, nz)
		fx = fx - nx * fdotn
		fy = fy - ny * fdotn
		fz = fz - nz * fdotn
		fx, fy, fz = Normalize(fx, fy, fz)
	end

	-- Match the orientation used by your terrain text matrix
	fx, fy, fz = -fx, -fy, -fz

	-- right = forward x normal
	local rx, ry, rz = Cross(fx, fy, fz, nx, ny, nz)
	rx, ry, rz = Normalize(rx, ry, rz)

	local ox = rx * OFFSET_RIGHT + fx * OFFSET_FORWARD + nx * OFFSET_UP
	local oy = ry * OFFSET_RIGHT + fy * OFFSET_FORWARD + ny * OFFSET_UP
	local oz = rz * OFFSET_RIGHT + fz * OFFSET_FORWARD + nz * OFFSET_UP

	return x + ox, y + oy, z + oz
end

local function UpdateCache()
	unitTextCache = {}
	myTeamID = spGetMyTeamID()

	local visibleUnits = spGetVisibleUnits(-1, nil, false)
	if not visibleUnits then
		return
	end

	for i = 1, #visibleUnits do
		local unitID = visibleUnits[i]
		if spGetUnitTeam(unitID) == myTeamID then
			local x, _, z = spGetUnitPosition(unitID)
			if x and z then
				local metalValue, energyValue = GetDisplayedResourceValues(unitID)
				local metalText, energyText = FormatStackedTexts(metalValue, energyValue)

				if metalText or energyText then
					local drawX, drawZ = GetBottomEdgePosition(unitID, x, z)
					local groundY = spGetGroundHeight(drawX, drawZ)

					local finalX, finalY, finalZ = ApplyAnchorOffsets(
							drawX,
							groundY + GROUND_Y_OFFSET,
							drawZ
					)

					unitTextCache[unitID] = {
						metalText = metalText,
						energyText = energyText,
						metalValue = metalValue,
						energyValue = energyValue,
						x = finalX,
						y = finalY,
						z = finalZ,
					}
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Draw
--------------------------------------------------------------------------------

function widget:Update()
	local gameFrame = spGetGameFrame()
	if gameFrame >= lastUpdateFrame + UPDATE_FRAMES then
		lastUpdateFrame = gameFrame
		UpdateCache()
	end
end

function widget:PlayerChanged()
	myTeamID = spGetMyTeamID()
end

function widget:DrawWorldPreUnit()
	if spIsGUIHidden() then
		return
	end

	local camX, camY, camZ = spGetCameraPosition()
	if not camX then
		return
	end

	glDepthTest(true)
	glPolygonOffset(-2, -2)

	for unitID, data in pairs(unitTextCache) do
		local dx = data.x - camX
		local dy = data.y - camY
		local dz = data.z - camZ
		local distSq = dx*dx + dy*dy + dz*dz

		if distSq <= (MAX_DIST * MAX_DIST) then
			local matrix = GetTerrainTextMatrix(data.x, data.z)

			glPushMatrix()
			glTranslate(data.x, data.y, data.z)
			glMultMatrix(matrix)

			if data.metalText and data.energyText then
				local mc = (data.metalValue >= 0) and METAL_POS_COLOR or METAL_NEG_COLOR
				local ec = (data.energyValue >= 0) and ENERGY_POS_COLOR or ENERGY_NEG_COLOR

				glColor(mc[1], mc[2], mc[3], mc[4])
				glText(data.metalText, 0, LINE_SPACING * 0.5, TEXT_SIZE, "oc")

				glColor(ec[1], ec[2], ec[3], ec[4])
				glText(data.energyText, 0, -LINE_SPACING * 0.5, TEXT_SIZE, "oc")

			elseif data.metalText then
				local mc = (data.metalValue >= 0) and METAL_POS_COLOR or METAL_NEG_COLOR
				glColor(mc[1], mc[2], mc[3], mc[4])
				glText(data.metalText, 0, 0, TEXT_SIZE, "oc")

			elseif data.energyText then
				local ec = (data.energyValue >= 0) and ENERGY_POS_COLOR or ENERGY_NEG_COLOR
				glColor(ec[1], ec[2], ec[3], ec[4])
				glText(data.energyText, 0, 0, TEXT_SIZE, "oc")
			end
			glPopMatrix()
		end
	end

	glPolygonOffset(false)
	glColor(1, 1, 1, 1)
	glDepthTest(false)
end

--------------------------------------------------------------------------------
-- Commands
--------------------------------------------------------------------------------

function widget:TextCommand(command)
	if not command then return end
	command = command:lower()

	if command == "resdrain energy" then
		DISPLAY_MODE = "energy"
		Spring.Echo("[Unit Resource Drain Numbers] mode: energy")
	elseif command == "resdrain metal" then
		DISPLAY_MODE = "metal"
		Spring.Echo("[Unit Resource Drain Numbers] mode: metal")
	elseif command == "resdrain both" then
		DISPLAY_MODE = "both"
		Spring.Echo("[Unit Resource Drain Numbers] mode: both")
	end
end