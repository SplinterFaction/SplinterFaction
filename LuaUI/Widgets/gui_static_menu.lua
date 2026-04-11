function widget:GetInfo()
	return {
		name      = "Static Menu",
		desc      = "Top-right menu with Settings, Resign, and Quit buttons",
		author    = "",
		date      = "2026-03-22",
		license   = "GNU GPL, v2 or later",
		layer     = 1000,
		enabled   = true,
	}
end

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

local bgcorner   = "LuaUI/Images/bgcorner.png"
local accentImg  = ":n:LuaUI/Images/staticgui_accent.png"

local PANEL_WIDTH        = 100
local PANEL_MARGIN_TOP   = 10
local PANEL_MARGIN_RIGHT = 10
local PANEL_PADDING      = 8
local BUTTON_HEIGHT      = 34
local BUTTON_GAP         = 8

local OUTER_CORNER       = 5
local INNER_CORNER       = 4.3
local INNER_INSET        = 2.25
local PANEL_ACCENT_HEIGHT = 5

--------------------------------------------------------------------------------
-- Theme config
--------------------------------------------------------------------------------

-- Outer border/shell color
local BORDER_COLOR       = {0.15, 0.15, 0.15, 0.90}
local BORDER_COLOR_GUI   = {0.15, 0.15, 0.15, 0.90} -- when guishader is active

-- Inner panel background
local PANEL_BG_COLOR     = {0.05, 0.05, 0.06, 0.88}
local PANEL_BG_COLOR_GUI = {0.00, 0.00, 0.00, 0.22}

-- Hovered inner panel background
local PANEL_HOVER_COLOR     = {0.08, 0.08, 0.10, 0.95}
local PANEL_HOVER_COLOR_GUI = {0.02, 0.02, 0.02, 0.30}

-- Text color
local TEXT_COLOR = "\255\244\244\244"

local BUTTONS = {
	{
		label = "Settings",
		accent = {0.18, 0.52, 0.98, 1}, -- blue
		onClick = function()
			if WG.crude and WG.crude.OpenPath then
				WG.crude.OpenPath("Settings")
				return
			end
			if WG.options and WG.options.toggle then
				WG.options.toggle()
				return
			end
			if WG.showSettings and type(WG.showSettings) == "function" then
				WG.showSettings()
				return
			end
			if WG.menu and WG.menu.showSettings then
				WG.menu.showSettings()
				return
			end
			Spring.Echo("Menu widget: hook Settings button to your preferred settings opener")
		end
	},
	{
		label = "Resign",
		accent = {0.95, 0.65, 0.18, 1}, -- amber
		onClick = function()
			Spring.SendCommands("spectator")
		end
	},
	{
		label = "Quit",
		accent = {0.90, 0.22, 0.22, 1}, -- red
		onClick = function()
			Spring.SendCommands("quitforce")
		end
	},
}

--------------------------------------------------------------------------------
-- Speedups
--------------------------------------------------------------------------------

local glColor           = gl.Color
local glRect            = gl.Rect
local glTexture         = gl.Texture
local glTexRect         = gl.TexRect

local spGetMouseState   = Spring.GetMouseState
local spGetViewGeometry = Spring.GetViewGeometry
local spPlaySoundFile   = Spring.PlaySoundFile

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local vsx, vsy = spGetViewGeometry()
local widgetScale = 1
local buttons = {}
local lastHoveredIndex = nil   -- tracks which button was hovered last frame for dedup

--------------------------------------------------------------------------------
-- Sound
--------------------------------------------------------------------------------

local function PlayHoverSound()
	spPlaySoundFile("hover", 1.0, "ui")
end

local function PlayLeftClickSound()
	spPlaySoundFile("leftclick", 1.0, "ui")
end

local fontfile = LUAUI_DIRNAME .. "fonts/" .. Spring.GetConfigString("ui_font", "Saira_SemiCondensed-SemiBold.ttf")
local fontfileScale = (0.5 + (vsx * vsy / 5700000))
local fontfileSize = 25
local fontfileOutlineSize = 4.5
local fontfileOutlineStrength = 1.8
local font = gl.LoadFont(fontfile, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength)

-- Display list cache
local staticList    = nil   -- panel chrome + labels for all buttons (no hover state)
local lastGuiShader = nil   -- track guishader to detect color-scheme changes

local function FreeStaticList()
	if staticList then gl.DeleteList(staticList) ; staticList = nil end
end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function RectRound(px, py, sx, sy, cs)
	px, py, sx, sy, cs = math.floor(px), math.floor(py), math.floor(sx), math.floor(sy), math.floor(cs)

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
	if WG.guishader then
		return BORDER_COLOR_GUI
	end
	return BORDER_COLOR
end

local function GetPanelBGColor(hovered)
	if hovered then
		if WG.guishader then
			return PANEL_HOVER_COLOR_GUI
		end
		return PANEL_HOVER_COLOR
	end

	if WG.guishader then
		return PANEL_BG_COLOR_GUI
	end
	return PANEL_BG_COLOR
end

local function RecalculateGeometry()
	vsx, vsy = spGetViewGeometry()
	widgetScale = (0.60 + (vsx * vsy / 5000000))

	local width       = PANEL_WIDTH * widgetScale
	local marginTop   = PANEL_MARGIN_TOP * widgetScale
	local marginRight = PANEL_MARGIN_RIGHT * widgetScale
	local gap         = BUTTON_GAP * widgetScale
	local height      = BUTTON_HEIGHT * widgetScale

	local x2 = vsx - marginRight
	local x1 = x2 - width
	local y2 = vsy - marginTop

	buttons = {}

	for i = 1, #BUTTONS do
		local by2 = y2 - ((i - 1) * (height + gap))
		local by1 = by2 - height

		buttons[i] = {
			label   = BUTTONS[i].label,
			accent  = BUTTONS[i].accent,
			onClick = BUTTONS[i].onClick,
			x1 = x1,
			y1 = by1,
			x2 = x2,
			y2 = by2,
		}
	end
end

local function DrawButtonStatic(button)
	local x1, y1, x2, y2 = button.x1, button.y1, button.x2, button.y2
	local outerCorner = OUTER_CORNER  * widgetScale
	local innerCorner = INNER_CORNER  * widgetScale
	local inset       = INNER_INSET   * widgetScale
	local accentH     = PANEL_ACCENT_HEIGHT * widgetScale

	local borderColor = GetBorderColor()
	local panelColor  = GetPanelBGColor(false)

	glColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
	RectRound(x1, y1, x2, y2, outerCorner)

	glColor(panelColor[1], panelColor[2], panelColor[3], panelColor[4])
	RectRound(x1 + inset, y1 + inset, x2 - inset, y2 - inset - 0.06, innerCorner)

	glColor(button.accent[1], button.accent[2], button.accent[3], button.accent[4])
	glTexture(accentImg)
	glTexRect(x1 + inset, y2 - inset - accentH, x2 - inset, y2 - inset - 0.06)
	glTexture(false)

	font:Begin()
	font:Print(
			TEXT_COLOR .. button.label,
			x1 + ((x2 - x1) * 0.5),
			y1 + ((y2 - y1) * 0.5) - (6 * widgetScale),
			14 * widgetScale,
			"con"
	)
	font:End()
end

local function DrawButtonHover(button)
	local x1, y1, x2, y2 = button.x1, button.y1, button.x2, button.y2
	local innerCorner = INNER_CORNER * widgetScale
	local inset       = INNER_INSET  * widgetScale
	glColor(button.accent[1], button.accent[2], button.accent[3], 0.10)
	RectRound(x1 + inset + 1, y1 + inset + 1, x2 - inset - 1, y2 - inset - 1, innerCorner)
end

local function BuildStaticList()
	FreeStaticList()
	staticList = gl.CreateList(function()
		for i = 1, #buttons do
			DrawButtonStatic(buttons[i])
		end
	end)
	lastGuiShader = (WG.guishader ~= nil)
end

--------------------------------------------------------------------------------
-- Widget lifecycle
--------------------------------------------------------------------------------

function widget:Initialize()
	RecalculateGeometry()
end

function widget:Shutdown()
	FreeStaticList()
	if font then gl.DeleteFont(font) end
end

function widget:ViewResize()
	vsx, vsy = spGetViewGeometry()

	local newFontfileScale = (0.5 + (vsx * vsy / 5700000))
	if fontfileScale ~= newFontfileScale then
		fontfileScale = newFontfileScale
		if font then gl.DeleteFont(font) end
		font = gl.LoadFont(fontfile, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength)
	end

	RecalculateGeometry()
	FreeStaticList()  -- geometry changed, rebuild next DrawScreen
end

--------------------------------------------------------------------------------
-- Input
--------------------------------------------------------------------------------

function widget:MousePress(x, y, button)
	if button ~= 1 then return false end
	for i = 1, #buttons do
		local b = buttons[i]
		if IsOnRect(x, y, b.x1, b.y1, b.x2, b.y2) then return true end
	end
	return false
end

function widget:MouseRelease(x, y, button)
	if button ~= 1 then return false end
	for i = 1, #buttons do
		local b = buttons[i]
		if IsOnRect(x, y, b.x1, b.y1, b.x2, b.y2) then
			PlayLeftClickSound()
			if b.onClick then b.onClick() end
			return true
		end
	end
	return false
end

--------------------------------------------------------------------------------
-- Draw
--------------------------------------------------------------------------------

function widget:DrawScreen()
	-- Rebuild static list if not yet built or guishader state changed
	local guiShaderActive = (WG.guishader ~= nil)
	if not staticList or guiShaderActive ~= lastGuiShader then
		BuildStaticList()
	end

	gl.CallList(staticList)

	-- Hover tint — cheap immediate-mode on top, no list needed
	local mx, my = spGetMouseState()
	local currentHoveredIndex = nil
	for i = 1, #buttons do
		local b = buttons[i]
		if IsOnRect(mx, my, b.x1, b.y1, b.x2, b.y2) then
			DrawButtonHover(b)
			currentHoveredIndex = i
		end
	end
	if currentHoveredIndex ~= lastHoveredIndex then
		if currentHoveredIndex then
			PlayHoverSound()
		end
		lastHoveredIndex = currentHoveredIndex
	end
end