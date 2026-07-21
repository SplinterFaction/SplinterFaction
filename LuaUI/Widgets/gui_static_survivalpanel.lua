function widget:GetInfo()
	return {
		name      = "Static Survival Panel",
		desc      = "Wave countdown, threat type, beacons, surge/rage warnings for Survival AI games. Drag to move.",
		author    = "",
		date      = "2026",
		license   = "GNU GPL, v2 or later",
		layer     = 1000,
		enabled   = true,
	}
end

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

local bgcorner  = "LuaUI/Images/bgcorner.png"
local accentImg = ":n:LuaUI/Images/staticgui_accent.png"

local PANEL_WIDTH         = 190
local PANEL_PADDING       = 8
local TITLE_HEIGHT        = 20
local COUNTDOWN_HEIGHT    = 34
local LINE_HEIGHT         = 18
local STATUS_HEIGHT       = 20

local OUTER_CORNER        = 5
local INNER_CORNER        = 4.3
local INNER_INSET         = 2.25
local PANEL_ACCENT_HEIGHT = 5

-- How often (frames) to re-read the gadget's rules params
local POLL_PERIOD  = 15
-- Give up and self-remove if the Survival gadget never announces itself
local GIVEUP_FRAME = 450

--------------------------------------------------------------------------------
-- Theme config
--------------------------------------------------------------------------------

local BORDER_COLOR       = {0.15, 0.15, 0.15, 0.90}
local BORDER_COLOR_GUI   = {0.15, 0.15, 0.15, 0.90}

local PANEL_BG_COLOR     = {0.05, 0.05, 0.06, 0.88}
local PANEL_BG_COLOR_GUI = {0.00, 0.00, 0.00, 0.22}

local PANEL_ACCENT       = {0.90, 0.22, 0.22, 1}   -- survival red

local LABEL_COLOR  = {0.62, 0.62, 0.65, 1}
local VALUE_COLOR  = {0.96, 0.96, 0.96, 1}
local URGENT_COLOR = {0.95, 0.65, 0.18, 1}         -- countdown under 10s
local SURGE_COLOR  = {0.90, 0.22, 0.22, 1}
local RAGE_COLOR   = {0.95, 0.25, 0.45, 1}
local PREP_COLOR   = {0.45, 0.75, 0.45, 1}

local TYPE_COLORS = {
	assault = {0.95, 0.45, 0.18, 1},
	raid    = {0.95, 0.85, 0.20, 1},
	siege   = {0.55, 0.35, 0.95, 1},
	air     = {0.20, 0.75, 0.80, 1},
	drop    = {0.18, 0.52, 0.98, 1},
	horde   = {0.65, 0.65, 0.65, 1},
}
local TYPE_FALLBACK = {0.80, 0.80, 0.80, 1}

--------------------------------------------------------------------------------
-- Speedups
--------------------------------------------------------------------------------

local glColor      = gl.Color
local glRect       = gl.Rect
local glTexture    = gl.Texture
local glTexRect    = gl.TexRect
local glPushMatrix = gl.PushMatrix
local glPopMatrix  = gl.PopMatrix
local glTranslate  = gl.Translate

local spGetViewGeometry   = Spring.GetViewGeometry
local spGetGameRulesParam = Spring.GetGameRulesParam
local spGetGameFrame      = Spring.GetGameFrame

local floor, max, min, sin = math.floor, math.max, math.min, math.sin

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local vsx, vsy = spGetViewGeometry()
local widgetScale = 1

local panelX, panelY = nil, nil    -- absolute bottom-left; nil until placed
local panelW, panelH = 0, 0
local pendingConfig  = nil         -- restored position fractions, applied on layout
local layout         = {}          -- panel-local row coordinates

local visible  = true
local active   = false             -- survival_active seen?
local dragging = false
local dragDX, dragDY = 0, 0

-- Cached rules params (polled, not read per-draw)
local waveNumber    = 0
local waveType      = nil
local nextWaveFrame = nil
local nextSurge     = false
local beaconCount   = 0
local rageCount     = 0

local staticList    = nil
local lastGuiShader = nil

local fontfile = LUAUI_DIRNAME .. "fonts/" .. Spring.GetConfigString("ui_font", "Saira_SemiCondensed-SemiBold.ttf")
local fontfileScale = (0.5 + (vsx * vsy / 5700000))
local fontfileSize = 25
local fontfileOutlineSize = 4.5
local fontfileOutlineStrength = 1.8
local font = gl.LoadFont(fontfile, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength)

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function RectRound(px, py, sx, sy, cs)
	px, py, sx, sy, cs = floor(px), floor(py), floor(sx), floor(sy), floor(cs)

	glRect(px + cs, py, sx - cs, sy)
	glRect(sx - cs, py + cs, sx, sy - cs)
	glRect(px, py + cs, px + cs, sy - cs)

	glTexture(bgcorner)
	glTexRect(px, py + cs, px + cs, py)
	glTexRect(sx, py + cs, sx - cs, py)
	glTexRect(px, sy - cs, px + cs, sy)
	glTexRect(sx, sy - cs, sx - cs, sy)
	glTexture(false)
end

local function IsOnRect(x, y, x1, y1, x2, y2)
	return x >= x1 and x <= x2 and y >= y1 and y <= y2
end

local function GetBorderColor()
	if WG.guishader then return BORDER_COLOR_GUI end
	return BORDER_COLOR
end

local function GetPanelBGColor()
	if WG.guishader then return PANEL_BG_COLOR_GUI end
	return PANEL_BG_COLOR
end

local function FormatTime(secs)
	secs = max(0, floor(secs))
	return string.format("%d:%02d", floor(secs / 60), secs % 60)
end

local function FreeStaticList()
	if staticList then gl.DeleteList(staticList) ; staticList = nil end
end

local function ClampPanel()
	if not panelX then return end
	panelX = max(0, min(panelX, vsx - panelW))
	panelY = max(0, min(panelY, vsy - panelH))
end

--------------------------------------------------------------------------------
-- Geometry (panel-local; the panel is drawn translated to panelX/panelY, so
-- dragging never rebuilds the display list)
--------------------------------------------------------------------------------

local function RecalculateGeometry()
	vsx, vsy = spGetViewGeometry()
	widgetScale = (0.60 + (vsx * vsy / 5000000))

	local pad   = PANEL_PADDING * widgetScale
	panelW      = PANEL_WIDTH * widgetScale

	local title     = TITLE_HEIGHT * widgetScale
	local countdown = COUNTDOWN_HEIGHT * widgetScale
	local line      = LINE_HEIGHT * widgetScale
	local status    = STATUS_HEIGHT * widgetScale

	panelH = pad + title + countdown + line + line + status + pad

	-- Rows, top-down, in panel-local coords (0,0 = bottom-left)
	local y = panelH - pad
	layout.pad      = pad
	layout.titleY   = y - title      ; y = y - title
	layout.countY   = y - countdown  ; y = y - countdown
	layout.waveY    = y - line       ; y = y - line
	layout.beaconY  = y - line       ; y = y - line
	layout.statusY  = y - status
	layout.textL    = pad + 2 * widgetScale
	layout.textR    = panelW - pad - 2 * widgetScale

	-- First placement / restored position
	if pendingConfig then
		panelX = pendingConfig.relX * vsx
		panelY = pendingConfig.relY * vsy
		pendingConfig = nil
	elseif not panelX then
		panelX = vsx - panelW - 12 * widgetScale
		panelY = vsy * 0.55
	end
	ClampPanel()
end

--------------------------------------------------------------------------------
-- Static chrome (panel-local coordinates)
--------------------------------------------------------------------------------

local function BuildStaticList()
	FreeStaticList()
	staticList = gl.CreateList(function()
		local outerCorner = OUTER_CORNER * widgetScale
		local innerCorner = INNER_CORNER * widgetScale
		local inset       = INNER_INSET * widgetScale
		local accentH     = PANEL_ACCENT_HEIGHT * widgetScale

		local borderColor = GetBorderColor()
		local panelColor  = GetPanelBGColor()

		glColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
		RectRound(0, 0, panelW, panelH, outerCorner)

		glColor(panelColor[1], panelColor[2], panelColor[3], panelColor[4])
		RectRound(inset, inset, panelW - inset, panelH - inset - 0.06, innerCorner)

		glColor(PANEL_ACCENT[1], PANEL_ACCENT[2], PANEL_ACCENT[3], PANEL_ACCENT[4])
		glTexture(accentImg)
		glTexRect(inset, panelH - inset - accentH, panelW - inset, panelH - inset - 0.06)
		glTexture(false)

		-- Static labels
		font:Begin()
		font:SetTextColor(VALUE_COLOR[1], VALUE_COLOR[2], VALUE_COLOR[3], VALUE_COLOR[4])
		font:Print("SURVIVAL THREAT", layout.textL, layout.titleY + 5 * widgetScale,
			11 * widgetScale, "o")

		font:SetTextColor(LABEL_COLOR[1], LABEL_COLOR[2], LABEL_COLOR[3], LABEL_COLOR[4])
		font:Print("NEXT WAVE", layout.textL, layout.countY + 11 * widgetScale,
			9 * widgetScale, "o")
		font:Print("WAVE", layout.textL, layout.waveY + 4 * widgetScale,
			9.5 * widgetScale, "o")
		font:Print("BEACONS", layout.textL, layout.beaconY + 4 * widgetScale,
			9.5 * widgetScale, "o")
		font:End()
	end)
	lastGuiShader = (WG.guishader ~= nil)
end

--------------------------------------------------------------------------------
-- Widget lifecycle
--------------------------------------------------------------------------------

function widget:Initialize()
	RecalculateGeometry()

	WG.StaticSurvivalPanel = {
		Toggle = function()
			visible = not visible
		end,
	}
end

function widget:Shutdown()
	FreeStaticList()
	if font then gl.DeleteFont(font) end
	WG.StaticSurvivalPanel = nil
end

function widget:ViewResize()
	vsx, vsy = spGetViewGeometry()

	local newFontfileScale = (0.5 + (vsx * vsy / 5700000))
	if fontfileScale ~= newFontfileScale then
		fontfileScale = newFontfileScale
		if font then gl.DeleteFont(font) end
		font = gl.LoadFont(fontfile, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength)
	end

	-- Keep the panel at the same screen fraction across resizes
	if panelX then
		pendingConfig = { relX = panelX / vsx, relY = panelY / vsy }
		panelX = nil
	end
	RecalculateGeometry()
	FreeStaticList()
end

--------------------------------------------------------------------------------
-- Position persistence
--------------------------------------------------------------------------------

function widget:GetConfigData()
	if panelX and vsx > 0 and vsy > 0 then
		return { relX = panelX / vsx, relY = panelY / vsy, visible = visible }
	end
end

function widget:SetConfigData(data)
	if data and data.relX and data.relY then
		pendingConfig = { relX = data.relX, relY = data.relY }
	end
	if data and data.visible ~= nil then
		visible = data.visible
	end
end

--------------------------------------------------------------------------------
-- Data polling
--------------------------------------------------------------------------------

function widget:GameFrame(n)
	if n % POLL_PERIOD ~= 0 then return end

	if not active then
		if (spGetGameRulesParam("survival_active")) == 1 then
			active = true
		elseif n > GIVEUP_FRAME then
			widgetHandler:RemoveWidget()   -- not a survival game
		end
		return
	end

	waveNumber    = (spGetGameRulesParam("survival_waveNumber")) or 0
	waveType      = (spGetGameRulesParam("survival_waveType"))
	nextWaveFrame = (spGetGameRulesParam("survival_nextWaveFrame"))
	nextSurge     = (spGetGameRulesParam("survival_nextWaveSurge")) == 1
	beaconCount   = (spGetGameRulesParam("survival_beacons")) or 0
	rageCount     = (spGetGameRulesParam("survival_rage")) or 0
end

--------------------------------------------------------------------------------
-- Input: click-drag anywhere on the panel
--------------------------------------------------------------------------------

function widget:MousePress(x, y, button)
	if button ~= 1 or not visible or not active or not panelX then return false end
	if IsOnRect(x, y, panelX, panelY, panelX + panelW, panelY + panelH) then
		dragging = true
		dragDX, dragDY = x - panelX, y - panelY
		return true
	end
	return false
end

function widget:MouseMove(x, y, dx, dy, button)
	if dragging then
		panelX = x - dragDX
		panelY = y - dragDY
		ClampPanel()
		return true
	end
	return false
end

function widget:MouseRelease(x, y, button)
	if dragging then
		dragging = false
		return true
	end
	return false
end

--------------------------------------------------------------------------------
-- Draw
--------------------------------------------------------------------------------

function widget:DrawScreen()
	if not visible or not active or Spring.IsGUIHidden() then return end

	local guiShaderActive = (WG.guishader ~= nil)
	if not staticList or guiShaderActive ~= lastGuiShader then
		BuildStaticList()
	end

	glPushMatrix()
	glTranslate(panelX, panelY, 0)

	gl.CallList(staticList)

	----------------------------------------------------------------------------
	-- Dynamic values (panel-local coords)
	----------------------------------------------------------------------------
	local pulse = 0.55 + 0.45 * sin(os.clock() * 5)

	font:Begin()

	-- Countdown
	local countText, cr, cg, cb, ca
	if nextWaveFrame then
		local secs = (nextWaveFrame - spGetGameFrame()) / 30
		countText = FormatTime(secs)
		if nextSurge then
			cr, cg, cb, ca = SURGE_COLOR[1], SURGE_COLOR[2], SURGE_COLOR[3], pulse
		elseif secs <= 10 then
			cr, cg, cb, ca = URGENT_COLOR[1], URGENT_COLOR[2], URGENT_COLOR[3], 1
		else
			cr, cg, cb, ca = VALUE_COLOR[1], VALUE_COLOR[2], VALUE_COLOR[3], 1
		end
	else
		countText = "--:--"
		cr, cg, cb, ca = LABEL_COLOR[1], LABEL_COLOR[2], LABEL_COLOR[3], 1
	end
	font:SetTextColor(cr, cg, cb, ca)
	font:Print(countText, layout.textR, layout.countY + 8 * widgetScale,
		19 * widgetScale, "ro")

	-- Wave number + type
	font:SetTextColor(VALUE_COLOR[1], VALUE_COLOR[2], VALUE_COLOR[3], VALUE_COLOR[4])
	font:Print(tostring(waveNumber), layout.textL + 34 * widgetScale,
		layout.waveY + 4 * widgetScale, 9.5 * widgetScale, "o")
	if waveType then
		local tc = TYPE_COLORS[waveType] or TYPE_FALLBACK
		font:SetTextColor(tc[1], tc[2], tc[3], tc[4])
		font:Print(string.upper(waveType), layout.textR,
			layout.waveY + 4 * widgetScale, 9.5 * widgetScale, "ro")
	end

	-- Beacons
	font:SetTextColor(VALUE_COLOR[1], VALUE_COLOR[2], VALUE_COLOR[3], VALUE_COLOR[4])
	font:Print(tostring(beaconCount), layout.textR,
		layout.beaconY + 4 * widgetScale, 9.5 * widgetScale, "ro")

	-- Status line: rage > surge > preparing
	if rageCount > 0 then
		font:SetTextColor(RAGE_COLOR[1], RAGE_COLOR[2], RAGE_COLOR[3], pulse)
		font:Print("RAGE MODE", panelW * 0.5, layout.statusY + 5 * widgetScale,
			11 * widgetScale, "co")
	elseif nextSurge then
		font:SetTextColor(SURGE_COLOR[1], SURGE_COLOR[2], SURGE_COLOR[3], pulse)
		font:Print("SURGE INCOMING", panelW * 0.5, layout.statusY + 5 * widgetScale,
			11 * widgetScale, "co")
	elseif not nextWaveFrame then
		font:SetTextColor(PREP_COLOR[1], PREP_COLOR[2], PREP_COLOR[3], 1)
		font:Print("PREPARING", panelW * 0.5, layout.statusY + 5 * widgetScale,
			11 * widgetScale, "co")
	end

	font:End()
	glPopMatrix()
end
