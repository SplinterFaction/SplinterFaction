function widget:GetInfo()
	return {
		name      = "Unit Resource Drain Numbers",
		desc      = "Displays your units' metal/energy drain as screen-space labels",
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

local UPDATE_FRAMES     = 16
local MIN_VALUE_TO_SHOW = 0.05
local MAX_DIST          = 5000
local MAX_DIST_SQ       = MAX_DIST * MAX_DIST

-- Text is full size (TEXT_SIZE_MAX) up to CAM_HEIGHT_FULL, then scales linearly
-- down to TEXT_SIZE_MIN at CAM_HEIGHT_MAX, then hides entirely.
local TEXT_SIZE_MAX     = 20
local TEXT_SIZE_MIN     = 6
local CAM_HEIGHT_FULL   = 900    -- below this dist, full size
local CAM_HEIGHT_MAX    = 2500   -- above this dist, hidden entirely

-- "energy", "metal", "both"
local DISPLAY_MODE      = "both"

local METAL_LABEL_COLOR  = {0.40, 0.95, 1.00, 1.00}
local ENERGY_LABEL_COLOR = {1.00, 1.00, 0.00, 1.00}
local VALUE_POS_COLOR    = {0.0, 1.0, 0.0, 1.00}
local VALUE_NEG_COLOR    = {1, 0.0, 0.0, 1.00}

local EDGE_PADDING      = 10
local BOTTOM_DIR_X      = 0
local BOTTOM_DIR_Z      = 1

-- Moves geometry recompute threshold: only redo ground height etc if moved >10 elmos
local POS_DIRTY_THRESHOLD_SQ = 100

--------------------------------------------------------------------------------
-- Font
--------------------------------------------------------------------------------

local font                = nil
local FONT_PATH           = "fonts/Saira_SemiCondensed-SemiBold.ttf"
local FONT_SIZE_LOAD      = 40   -- must match TEXT_SIZE exactly
local FONT_OUTLINE_WIDTH  = 4
local FONT_OUTLINE_WEIGHT = 20.0

--------------------------------------------------------------------------------
-- Speedups
--------------------------------------------------------------------------------

local spGetGameFrame         = Spring.GetGameFrame
local spGetVisibleUnits      = Spring.GetVisibleUnits
local spGetUnitResources     = Spring.GetUnitResources
local spGetUnitPosition      = Spring.GetUnitPosition
local spGetUnitTeam          = Spring.GetUnitTeam
local spGetMyTeamID          = Spring.GetMyTeamID
local spGetCameraPosition    = Spring.GetCameraPosition
local spIsGUIHidden          = Spring.IsGUIHidden
local spGetGroundHeight      = Spring.GetGroundHeight
local spWorldToScreenCoords  = Spring.WorldToScreenCoords
local spGetUnitDefID         = Spring.GetUnitDefID

local math_abs      = math.abs
local math_floor    = math.floor
local math_sqrt     = math.sqrt
local math_max      = math.max
local math_min      = math.min
local string_format = string.format

--------------------------------------------------------------------------------
-- State
--
-- drawList  — rebuilt every UPDATE_FRAMES. Stores world-space anchor (wx,wy,wz)
--             plus pre-formatted strings and value signs. No screen coords here.
-- unitCache — persistent per-unit geometry; world anchor only recomputed on move.
--------------------------------------------------------------------------------

local drawList  = {}
local unitCache = {}

local lastUpdateFrame = -math.huge
local myTeamID        = spGetMyTeamID()

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function Normalize2D(x, z)
	local len = math_sqrt(x*x + z*z)
	if len <= 0.00001 then return 0, 1 end
	return x / len, z / len
end

local function GetUnitHalfExtents(unitID)
	local udid = spGetUnitDefID(unitID)
	if not udid then return 20, 20 end
	local ud = UnitDefs[udid]
	if not ud then return 20, 20 end
	if ud.isBuilding then
		return (ud.xsize or 4) * 4, (ud.zsize or 4) * 4
	end
	local r = ud.radius or 20
	return r, r
end

local function GetAnchorXZ(unitID, unitX, unitZ)
	local dirX, dirZ = Normalize2D(BOTTOM_DIR_X, BOTTOM_DIR_Z)
	local halfX, halfZ = GetUnitHalfExtents(unitID)
	local edgeDist = math_abs(dirX) * halfX + math_abs(dirZ) * halfZ
	return unitX + dirX * (edgeDist + EDGE_PADDING),
	unitZ + dirZ * (edgeDist + EDGE_PADDING)
end

local function Round2(x)
	return math_floor(x * 100 + 0.5) / 100
end

local function FormatValue(value)
	if value >= 0 then
		return string_format("+%.2f", Round2(value))
	else
		return string_format("-%.2f", Round2(math_abs(value)))
	end
end

local function ShouldShow(metalValue, energyValue)
	local showEnergy = (DISPLAY_MODE == "energy" or DISPLAY_MODE == "both")
	local showMetal  = (DISPLAY_MODE == "metal"  or DISPLAY_MODE == "both")
	return showMetal  and math_abs(metalValue)  > MIN_VALUE_TO_SHOW,
	showEnergy and math_abs(energyValue) > MIN_VALUE_TO_SHOW
end

--------------------------------------------------------------------------------
-- UpdateCache  (every UPDATE_FRAMES)
-- Expensive work: GetUnitResources, ground height, string formatting.
-- Stores world-space anchor per entry — no screen projection here.
--------------------------------------------------------------------------------

local function UpdateCache()
	myTeamID = spGetMyTeamID()

	local camX, camY, camZ = spGetCameraPosition()
	if not camX then drawList = {} return end

	local visibleUnits = spGetVisibleUnits(-1, nil, false)
	if not visibleUnits then drawList = {} return end

	local newDrawList = {}
	local seen = {}

	for i = 1, #visibleUnits do
		local unitID = visibleUnits[i]
		if spGetUnitTeam(unitID) == myTeamID then
			local ux, uy, uz = spGetUnitPosition(unitID)
			if ux then
				local dx = ux - camX
				local dy = uy - camY
				local dz = uz - camZ
				if dx*dx + dy*dy + dz*dz <= MAX_DIST_SQ then

					local mMake, mUse, eMake, eUse = spGetUnitResources(unitID)
					local metalValue  = (mMake or 0) - (mUse or 0)
					local energyValue = (eMake or 0) - (eUse or 0)
					local hasMetal, hasEnergy = ShouldShow(metalValue, energyValue)

					if hasMetal or hasEnergy then
						seen[unitID] = true

						local entry = unitCache[unitID]
						if not entry then
							entry = {}
							unitCache[unitID] = entry
						end

						-- Only redo ground height if unit moved enough
						local needsGeom = not entry.lastX
						if not needsGeom then
							local ddx = ux - entry.lastX
							local ddz = uz - entry.lastZ
							needsGeom = (ddx*ddx + ddz*ddz) > POS_DIRTY_THRESHOLD_SQ
						end

						if needsGeom then
							local ax, az = GetAnchorXZ(unitID, ux, uz)
							entry.lastX = ux
							entry.lastZ = uz
							entry.wx = ax
							entry.wy = spGetGroundHeight(ax, az)
							entry.wz = az
						end

						newDrawList[#newDrawList + 1] = {
							-- World anchor — projected to screen fresh each DrawScreen
							wx = entry.wx,
							wy = entry.wy,
							wz = entry.wz,
							-- Strings and sign info
							hasMetal    = hasMetal,
							hasEnergy   = hasEnergy,
							metalStr    = hasMetal  and FormatValue(metalValue)  or nil,
							energyStr   = hasEnergy and FormatValue(energyValue) or nil,
							metalPos    = metalValue  >= 0,
							energyPos   = energyValue >= 0,
						}
					end
				end
			end
		end
	end

	for unitID in pairs(unitCache) do
		if not seen[unitID] then unitCache[unitID] = nil end
	end

	drawList = newDrawList
end

--------------------------------------------------------------------------------
-- DrawScreen  (every frame)
-- Only work done here: WorldToScreenCoords + font calls.
-- No Spring game-state queries, no string ops.
--------------------------------------------------------------------------------

function widget:DrawScreenEffects()
	if spIsGUIHidden() then return end
	if not font then return end
	if #drawList == 0 then return end

	local camState = Spring.GetCameraState()
	if not camState then return end
	local camHeight = camState.dist or camState.py or 1000

	if camHeight >= CAM_HEIGHT_MAX then return end

	local textSize
	if camHeight <= CAM_HEIGHT_FULL then
		textSize = TEXT_SIZE_MAX
	else
		local t = (camHeight - CAM_HEIGHT_FULL) / (CAM_HEIGHT_MAX - CAM_HEIGHT_FULL)
		textSize = math_floor(TEXT_SIZE_MAX + (TEXT_SIZE_MIN - TEXT_SIZE_MAX) * t + 0.5)
	end
	if textSize < TEXT_SIZE_MIN then return end

	local lineSpacing = textSize + 2
	local colGap      = 4

	font:Begin()

	for i = 1, #drawList do
		local d = drawList[i]

		-- Project world anchor to screen this frame — always current, never stale
		local sx, sy, sz = spWorldToScreenCoords(d.wx, d.wy, d.wz)
		if sz and sz > 0 then
			local mc = d.metalPos  and VALUE_POS_COLOR or VALUE_NEG_COLOR
			local ec = d.energyPos and VALUE_POS_COLOR or VALUE_NEG_COLOR

			if d.hasMetal and d.hasEnergy then
				local my = sy + lineSpacing * 0.5
				local ey = sy - lineSpacing * 0.5

				font:SetTextColor(METAL_LABEL_COLOR[1],  METAL_LABEL_COLOR[2],  METAL_LABEL_COLOR[3],  1)
				font:Print("Metal:",    sx,            my, textSize, "or")
				font:SetTextColor(mc[1], mc[2], mc[3], 1)
				font:Print(d.metalStr,  sx + colGap,   my, textSize, "ol")

				font:SetTextColor(ENERGY_LABEL_COLOR[1], ENERGY_LABEL_COLOR[2], ENERGY_LABEL_COLOR[3], 1)
				font:Print("Energy:",   sx,            ey, textSize, "or")
				font:SetTextColor(ec[1], ec[2], ec[3], 1)
				font:Print(d.energyStr, sx + colGap,   ey, textSize, "ol")

			elseif d.hasMetal then
				font:SetTextColor(METAL_LABEL_COLOR[1], METAL_LABEL_COLOR[2], METAL_LABEL_COLOR[3], 1)
				font:Print("Metal:",   sx,          sy, textSize, "or")
				font:SetTextColor(mc[1], mc[2], mc[3], 1)
				font:Print(d.metalStr, sx + colGap, sy, textSize, "ol")

			elseif d.hasEnergy then
				font:SetTextColor(ENERGY_LABEL_COLOR[1], ENERGY_LABEL_COLOR[2], ENERGY_LABEL_COLOR[3], 1)
				font:Print("Energy:",   sx,          sy, textSize, "or")
				font:SetTextColor(ec[1], ec[2], ec[3], 1)
				font:Print(d.energyStr, sx + colGap, sy, textSize, "ol")
			end
		end
	end

	font:End()
end

--------------------------------------------------------------------------------
-- Widget callbacks
--------------------------------------------------------------------------------

function widget:Initialize()
	font = gl.LoadFont(FONT_PATH, FONT_SIZE_LOAD, FONT_OUTLINE_WIDTH, FONT_OUTLINE_WEIGHT)
	if not font then
		Spring.Echo("[Unit Resource Drain Numbers] could not load font, widget disabled.")
		widgetHandler:RemoveWidget()
	end
end

function widget:Shutdown()
	if font then gl.DeleteFont(font) font = nil end
end

function widget:FontsChanged()
	if font then gl.DeleteFont(font) end
	font = gl.LoadFont(FONT_PATH, FONT_SIZE_LOAD, FONT_OUTLINE_WIDTH, FONT_OUTLINE_WEIGHT)
end

function widget:Update()
	local gameFrame = spGetGameFrame()
	if gameFrame >= lastUpdateFrame + UPDATE_FRAMES then
		lastUpdateFrame = gameFrame
		UpdateCache()
	end
end

function widget:PlayerChanged()
	myTeamID = spGetMyTeamID()
	unitCache = {}
	drawList  = {}
end

function widget:UnitDestroyed(unitID)
	unitCache[unitID] = nil
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