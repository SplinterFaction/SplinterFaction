function widget:GetInfo()
	return {
		name    = "Static Abilities",
		desc    = "Player-cast support powers (Scanner Sweep) - bottom-center ability strip",
		author  = "",
		date    = "2026",
		license = "GNU GPL, v2 or later",
		layer   = 1000,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

local bgcorner  = "LuaUI/Images/bgcorner.png"
local accentImg = ":n:LuaUI/Images/staticgui_accent.png"

-- UI scaling: suite standard. uiScale == 1.0 at BASE_RESOLUTION height.
local BASE_RESOLUTION = 1080

-- Base (1080p) geometry. The panel sits directly ABOVE the players list,
-- matching its width and right edge (rect published via
-- WG.StaticPlayersList.GetRect), so the two read as one column. If that
-- widget is disabled, we fall back to the same bottom-right corner using
-- its margins.
local PANEL_WIDTH         = 300    -- matches players list PANEL_WIDTH
local PANEL_PAD           = 10
local HEADER_HEIGHT       = 24     -- "Abilities" title row
local BUTTON_HEIGHT       = 40
local BUTTON_GAP          = 8
local ANCHOR_GAP          = 8      -- vertical gap between players list and panel
local FALLBACK_MARGIN_X   = 14     -- players list MARGIN_X / MARGIN_Y
local FALLBACK_MARGIN_Y   = 14
local OUTER_CORNER        = 5
local INNER_CORNER        = 4.3
local INNER_INSET         = 2.25
local PANEL_ACCENT_HEIGHT = 5

--------------------------------------------------------------------------------
-- Theme (matches gui_static_menu.lua)
--------------------------------------------------------------------------------

local BORDER_COLOR        = {0.15, 0.15, 0.15, 0.90}
local BORDER_COLOR_GUI    = {0.15, 0.15, 0.15, 0.90}
local PANEL_BG_COLOR      = {0.05, 0.05, 0.06, 0.88}
local PANEL_BG_COLOR_GUI  = {0.00, 0.00, 0.00, 0.22}

local PANEL_ACCENT        = {0.745, 0.470, 1.0, 1}   -- container accent (Violet)
local COL_HEADER          = "\255\244\244\244"

local COOLDOWN_FILL_COLOR = {0.0, 0.0, 0.0, 0.55}   -- sweeps away as cd expires
local FLASH_DENY_COLOR    = {0.90, 0.20, 0.20, 0.35}
local TARGETING_TINT      = {0.20, 0.75, 0.80, 0.20}

local COL_LABEL     = "\255\244\244\244"
local COL_COST_OK   = "\255\150\220\255"
local COL_COST_BAD  = "\255\255\110\110"
local COL_COOLDOWN  = "\255\255\210\120"

--------------------------------------------------------------------------------
-- Abilities. Adding a second ability = adding a table entry.
--   costRP     : read for the affordability grey-out (authoritative check is synced)
--   radius     : targeting circle radius in elmos
--   msg        : LuaRules message name; "<msg> <x> <z>" is sent on target click
--------------------------------------------------------------------------------

local ABILITIES = {
	{
		label   = "Scanner Sweep",
		accent  = {1, 0.5, 0.0, 1},   -- teal, same family as the Log button
		costRP  = 100,
		cooldownSeconds = 20,          -- mirror of the gadget value, for the fill/countdown only
		radius  = 800,
		msg     = "scanner_sweep",
		tooltip = "Reveal an area of the map for 5 seconds",
	},
}

local RP_RULES_PARAM = "researchPoints"

--------------------------------------------------------------------------------
-- Speedups
--------------------------------------------------------------------------------

local glColor            = gl.Color
local glRect             = gl.Rect
local glTexture          = gl.Texture
local glTexRect          = gl.TexRect
local glLineWidth        = gl.LineWidth
local glDrawGroundCircle = gl.DrawGroundCircle

local spGetMouseState      = Spring.GetMouseState
local spGetViewGeometry    = Spring.GetViewGeometry
local spPlaySoundFile      = Spring.PlaySoundFile
local spGetSpectatingState = Spring.GetSpectatingState
local spGetMyTeamID        = Spring.GetMyTeamID
local spGetTeamRulesParam  = Spring.GetTeamRulesParam
local spGetGameFrame       = Spring.GetGameFrame
local spTraceScreenRay     = Spring.TraceScreenRay
local spSendLuaRulesMsg    = Spring.SendLuaRulesMsg
local spIsGUIHidden        = Spring.IsGUIHidden

local math_floor = math.floor
local math_ceil  = math.ceil

local KEYSYMS_ESC = 27

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local vsx, vsy = spGetViewGeometry()
local uiScale  = 1.0
local buttons   = {}           -- geometry + per-ability runtime state
local panelRect = {x1 = 0, y1 = 0, x2 = 0, y2 = 0}
local isSpec   = spGetSpectatingState()
local myTeamID = spGetMyTeamID()

local targetingIndex   = nil   -- ability index currently placing a target, or nil
local lastHoveredIndex = nil

-- Per-ability runtime (parallel to ABILITIES)
local cdEndFrame = {}          -- [i] = game frame the cooldown ends (0 = ready)
local flashUntil = {}          -- [i] = os.clock() until which the deny flash shows

for i = 1, #ABILITIES do
	cdEndFrame[i] = 0
	flashUntil[i] = 0
end

--------------------------------------------------------------------------------
-- Font & sound (suite standard)
--------------------------------------------------------------------------------

local fontfile = LUAUI_DIRNAME .. "fonts/" .. Spring.GetConfigString("ui_font", "Saira_SemiCondensed-SemiBold.ttf")
local fontfileScale = (0.5 + (vsx * vsy / 5700000))
local fontfileSize = 25
local fontfileOutlineSize = 4.5
local fontfileOutlineStrength = 1.8
local font = gl.LoadFont(fontfile, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength)

local function PlayHoverSound()     spPlaySoundFile("hover", 1.0, "ui") end
local function PlayLeftClickSound() spPlaySoundFile("leftclick", 1.0, "ui") end

--------------------------------------------------------------------------------
-- Display list (static chrome layer)
--------------------------------------------------------------------------------

local staticList    = nil
local lastGuiShader = nil

local function FreeStaticList()
	if staticList then gl.DeleteList(staticList) ; staticList = nil end
end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function RectRound(px, py, sx, sy, cs)
	px, py, sx, sy, cs = math_floor(px), math_floor(py), math_floor(sx), math_floor(sy), math_floor(cs)

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

local function Clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

-- One-line hover popup, same look and cursor anchoring as the players list's
-- DrawMiniTooltip: black box to the LEFT of the cursor (this panel hugs the
-- right screen edge), accent strip on top.
local function DrawMiniTooltip(text, mx, my, accent)
	local fsize = 11 * uiScale
	local boxW = font:GetTextWidth(text) * fsize + 14 * uiScale
	local boxH = 20 * uiScale
	local bx2 = mx - 8 * uiScale
	local bx1 = bx2 - boxW
	if bx1 < 4 * uiScale then bx1 = 4 * uiScale ; bx2 = bx1 + boxW end
	local by2 = Clamp(my + 18 * uiScale, boxH + 4 * uiScale, vsy - 4 * uiScale)
	local by1 = by2 - boxH
	glColor(0, 0, 0, 0.88)
	RectRound(bx1, by1, bx2, by2, 4 * uiScale)
	if accent then
		glColor(accent[1], accent[2], accent[3], 1)
		glTexture(accentImg)
		glTexRect(bx1, by2 - 3 * uiScale, bx2, by2)
		glTexture(false)
	end
	font:Begin()
	font:Print(COL_LABEL .. text, bx1 + 7 * uiScale, by1 + boxH * 0.5, fsize, "vo")
	font:End()
end

local function GetBorderColor()
	if WG.guishader then return BORDER_COLOR_GUI end
	return BORDER_COLOR
end

local function GetPanelBGColor()
	if WG.guishader then return PANEL_BG_COLOR_GUI end
	return PANEL_BG_COLOR
end

local function GetMyRP()
	return tonumber(spGetTeamRulesParam(myTeamID, RP_RULES_PARAM)) or 0
end

local function CooldownRemaining(i)
	local rem = (cdEndFrame[i] or 0) - spGetGameFrame()
	if rem <= 0 then return 0 end
	return rem
end

local function AbilityReady(i)
	return CooldownRemaining(i) == 0 and GetMyRP() >= ABILITIES[i].costRP
end

-- Anchor: right edge and top of the players list panel (or fallback corner).
local function GetAnchor()
	if WG.StaticPlayersList and WG.StaticPlayersList.GetRect then
		local _, _, px2, py2 = WG.StaticPlayersList.GetRect()
		if px2 and py2 then
			return px2, py2 + math_floor(ANCHOR_GAP * uiScale)
		end
	end
	return vsx - math_floor(FALLBACK_MARGIN_X * uiScale),
	       math_floor(FALLBACK_MARGIN_Y * uiScale)
end

local lastAnchorX2, lastAnchorY1 = nil, nil

local function RecalculateGeometry()
	vsx, vsy = spGetViewGeometry()
	uiScale  = vsy / BASE_RESOLUTION

	local pw      = math_floor(PANEL_WIDTH    * uiScale)
	local pad     = math_floor(PANEL_PAD      * uiScale)
	local headerH = math_floor(HEADER_HEIGHT  * uiScale)
	local bh      = math_floor(BUTTON_HEIGHT  * uiScale)
	local gap     = math_floor(BUTTON_GAP     * uiScale)
	local accH    = math_floor(PANEL_ACCENT_HEIGHT * uiScale)
	local n       = #ABILITIES

	-- Panel height: accent + header + buttons + gaps + padding.
	local ph = accH + headerH + pad + n * bh + (n - 1) * gap + pad

	local ax2, ay1 = GetAnchor()
	lastAnchorX2, lastAnchorY1 = ax2, ay1

	panelRect.x2 = ax2
	panelRect.x1 = ax2 - pw
	panelRect.y1 = ay1
	panelRect.y2 = ay1 + ph

	-- Buttons stack top-down under the header (accent strip is at the panel's
	-- top edge, suite convention; header sits just below it).
	local bx1 = panelRect.x1 + pad
	local bx2 = panelRect.x2 - pad
	local cursor = panelRect.y2 - accH - headerH - pad

	buttons = {}
	for i = 1, n do
		buttons[i] = {
			x1 = bx1,
			y1 = cursor - bh,
			x2 = bx2,
			y2 = cursor,
		}
		cursor = cursor - bh - gap
	end
end

-- The players list resizes at runtime (specs expand, players resign): follow it.
local function FollowAnchor()
	local ax2, ay1 = GetAnchor()
	if ax2 ~= lastAnchorX2 or ay1 ~= lastAnchorY1 then
		RecalculateGeometry()
		FreeStaticList()
	end
end

--------------------------------------------------------------------------------
-- Draw
--------------------------------------------------------------------------------

local function DrawButtonStatic(i)
	local a = ABILITIES[i]
	local b = buttons[i]
	local x1, y1, x2, y2 = b.x1, b.y1, b.x2, b.y2
	local outerCorner = OUTER_CORNER * uiScale
	local innerCorner = INNER_CORNER * uiScale
	local inset       = INNER_INSET  * uiScale
	local accentH     = PANEL_ACCENT_HEIGHT * uiScale

	local borderColor = GetBorderColor()
	local panelColor  = GetPanelBGColor()

	glColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
	RectRound(x1, y1, x2, y2, outerCorner)

	glColor(panelColor[1], panelColor[2], panelColor[3], panelColor[4])
	RectRound(x1 + inset, y1 + inset, x2 - inset, y2 - inset - 0.06, innerCorner)

	glColor(a.accent[1], a.accent[2], a.accent[3], a.accent[4])
	glTexture(accentImg)
	glTexRect(x1 + inset, y2 - inset - accentH, x2 - inset, y2 - inset - 0.06)
	glTexture(false)

	-- Label: left-aligned, vertically centered (row style, like players list).
	-- Cost/countdown is dynamic (affordability colour), drawn per frame at right.
	font:Begin()
	font:Print(
		COL_LABEL .. a.label,
		x1 + (10 * uiScale),
		y1 + ((y2 - y1) * 0.5) - (5 * uiScale),
		13 * uiScale,
		"on"
	)
	font:End()
end

local function DrawContainerStatic()
	local x1, y1, x2, y2 = panelRect.x1, panelRect.y1, panelRect.x2, panelRect.y2
	local outerCorner = OUTER_CORNER * uiScale
	local innerCorner = INNER_CORNER * uiScale
	local inset       = INNER_INSET  * uiScale
	local accentH     = PANEL_ACCENT_HEIGHT * uiScale
	local headerH     = HEADER_HEIGHT * uiScale

	local borderColor = GetBorderColor()
	local panelColor  = GetPanelBGColor()

	-- Suite panel chrome: border shell, inner fill, accent strip at the top edge
	glColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
	RectRound(x1, y1, x2, y2, outerCorner)

	glColor(panelColor[1], panelColor[2], panelColor[3], panelColor[4])
	RectRound(x1 + inset, y1 + inset, x2 - inset, y2 - inset, innerCorner)

	glColor(PANEL_ACCENT[1], PANEL_ACCENT[2], PANEL_ACCENT[3], 1)
	glTexture(accentImg)
	glTexRect(x1 + inset, y2 - inset - accentH, x2 - inset, y2 - inset)
	glTexture(false)

	-- "Abilities" title, centered in the header row under the accent
	font:Begin()
	font:Print(
		COL_HEADER .. "Abilities",
		x1 + ((x2 - x1) * 0.5),
		y2 - accentH - (headerH * 0.5) - (5 * uiScale),
		13 * uiScale,
		"con"
	)
	font:End()
end

local function BuildStaticList()
	FreeStaticList()
	staticList = gl.CreateList(function()
		DrawContainerStatic()
		for i = 1, #buttons do
			DrawButtonStatic(i)
		end
	end)
	lastGuiShader = (WG.guishader ~= nil)
end

local function DrawButtonDynamic(i, mx, my)
	local a = ABILITIES[i]
	local b = buttons[i]
	local inset       = INNER_INSET  * uiScale
	local innerCorner = INNER_CORNER * uiScale
	local x1, y1, x2, y2 = b.x1 + inset, b.y1 + inset, b.x2 - inset, b.y2 - inset

	local cdRem  = CooldownRemaining(i)
	local rp     = GetMyRP()
	local afford = rp >= a.costRP

	-- Right side: cost, or countdown while cooling
	font:Begin()
	if cdRem > 0 then
		font:Print(
			COL_COOLDOWN .. math_ceil(cdRem / 30) .. "s",
			b.x2 - (10 * uiScale),
			b.y1 + ((b.y2 - b.y1) * 0.5) - (4 * uiScale),
			11 * uiScale,
			"ron"
		)
	else
		font:Print(
			(afford and COL_COST_OK or COL_COST_BAD) .. a.costRP .. " RP",
			b.x2 - (10 * uiScale),
			b.y1 + ((b.y2 - b.y1) * 0.5) - (4 * uiScale),
			11 * uiScale,
			"ron"
		)
	end
	font:End()

	-- Cooldown fill: dark curtain that retreats left-to-right as cd expires
	if cdRem > 0 then
		local a2 = ABILITIES[i]
		local totalFrames = ((a2.cooldownSeconds or 20) * 30)
		local frac = cdRem / totalFrames
		if frac > 1 then frac = 1 end
		glColor(COOLDOWN_FILL_COLOR[1], COOLDOWN_FILL_COLOR[2], COOLDOWN_FILL_COLOR[3], COOLDOWN_FILL_COLOR[4])
		RectRound(x1, y1, x1 + (x2 - x1) * frac, y2, innerCorner)
	elseif not afford then
		glColor(0, 0, 0, 0.45)
		RectRound(x1, y1, x2, y2, innerCorner)
	end

	-- Targeting tint
	if targetingIndex == i then
		glColor(TARGETING_TINT[1], TARGETING_TINT[2], TARGETING_TINT[3], TARGETING_TINT[4])
		RectRound(x1, y1, x2, y2, innerCorner)
	end

	-- Deny flash
	if flashUntil[i] > os.clock() then
		glColor(FLASH_DENY_COLOR[1], FLASH_DENY_COLOR[2], FLASH_DENY_COLOR[3], FLASH_DENY_COLOR[4])
		RectRound(x1, y1, x2, y2, innerCorner)
	end

	-- Hover
	if AbilityReady(i) and IsOnRect(mx, my, b.x1, b.y1, b.x2, b.y2) then
		glColor(a.accent[1], a.accent[2], a.accent[3], 0.10)
		RectRound(x1 + 1, y1 + 1, x2 - 1, y2 - 1, innerCorner)
		return true
	end
	return false
end

--------------------------------------------------------------------------------
-- Targeting
--------------------------------------------------------------------------------

local function CancelTargeting()
	targetingIndex = nil
end

local function TryStartTargeting(i)
	if AbilityReady(i) then
		targetingIndex = i
		Spring.SetActiveCommand(0)      -- drop any pending build/order ghost
		return true
	end
	flashUntil[i] = os.clock() + 0.35   -- visibly "no"
	return true                          -- still consume the click
end

local function FireAt(i, wx, wz)
	local a = ABILITIES[i]
	spSendLuaRulesMsg(a.msg .. " " .. string.format("%.1f %.1f", wx, wz))
	-- Optimistic local cooldown so the button reacts instantly; the gadget's
	-- ScannerCooldownEvent will overwrite this with the authoritative value
	-- (or reset it to the old value plus a deny flash if the cast was refused).
	cdEndFrame[i] = spGetGameFrame() + ((a.cooldownSeconds or 20) * 30)
end

--------------------------------------------------------------------------------
-- Gadget -> widget events
--------------------------------------------------------------------------------

local function OnScannerCooldown(endFrame)
	-- Single-ability protocol for now: index 1. If a second targeted ability
	-- gets its own gadget, give it its own event name and map it here.
	cdEndFrame[1] = endFrame or 0
end

local function OnScannerDeny(reason)
	flashUntil[1] = os.clock() + 0.35
	-- The optimistic cooldown was wrong -- ask synced for the real one.
	spSendLuaRulesMsg("scanner_query")
end

--------------------------------------------------------------------------------
-- Widget lifecycle
--------------------------------------------------------------------------------

function widget:Initialize()
	if spGetSpectatingState() and Spring.GetGameFrame() > 0 then
		-- Keep running (player may rejoin control), just don't draw; handled below.
	end
	isSpec   = spGetSpectatingState()
	myTeamID = spGetMyTeamID()

	widgetHandler:RegisterGlobal("ScannerCooldownEvent", OnScannerCooldown)
	widgetHandler:RegisterGlobal("ScannerDenyEvent",     OnScannerDeny)

	RecalculateGeometry()

	-- Re-sync cooldown after a LuaUI/widget reload.
	spSendLuaRulesMsg("scanner_query")
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal("ScannerCooldownEvent")
	widgetHandler:DeregisterGlobal("ScannerDenyEvent")
	FreeStaticList()
	if font then gl.DeleteFont(font) end
end

function widget:PlayerChanged(playerID)
	isSpec   = spGetSpectatingState()
	myTeamID = spGetMyTeamID()
	if isSpec then CancelTargeting() end
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
	FreeStaticList()
end

--------------------------------------------------------------------------------
-- Input
--------------------------------------------------------------------------------

function widget:IsAbove(x, y)
	if isSpec then return false end
	return IsOnRect(x, y, panelRect.x1, panelRect.y1, panelRect.x2, panelRect.y2)
end

function widget:MousePress(x, y, button)
	if isSpec then return false end

	-- Targeting mode consumes the click wherever it lands.
	if targetingIndex then
		if button == 1 then
			local kind, pos = spTraceScreenRay(x, y, true)   -- coorsOnly=true: always {x,y,z}
			if kind == "ground" and pos then
				PlayLeftClickSound()
				FireAt(targetingIndex, pos[1], pos[3])
			end
			CancelTargeting()
			return true
		elseif button == 3 then
			CancelTargeting()
			return true
		end
		return true
	end

	if button ~= 1 then return false end
	for i = 1, #buttons do
		local b = buttons[i]
		if IsOnRect(x, y, b.x1, b.y1, b.x2, b.y2) then
			PlayLeftClickSound()
			return TryStartTargeting(i)
		end
	end

	-- Click on the panel body (header, padding): swallow it.
	if IsOnRect(x, y, panelRect.x1, panelRect.y1, panelRect.x2, panelRect.y2) then
		return true
	end
	return false
end

function widget:KeyPress(key)
	if targetingIndex and key == KEYSYMS_ESC then
		CancelTargeting()
		return true
	end
	return false
end

--------------------------------------------------------------------------------
-- Draw
--------------------------------------------------------------------------------

function widget:DrawWorld()
	if not targetingIndex then return end

	local mx, my = spGetMouseState()
	local kind, pos = spTraceScreenRay(mx, my, true)
	if kind ~= "ground" or not pos then return end

	local a = ABILITIES[targetingIndex]
	glLineWidth(2.5)
	glColor(a.accent[1], a.accent[2], a.accent[3], 0.85)
	glDrawGroundCircle(pos[1], pos[2], pos[3], a.radius, 48)
	glLineWidth(1.0)
	glColor(1, 1, 1, 1)
end

function widget:DrawScreen()
	if isSpec or spIsGUIHidden() then return end

	FollowAnchor()

	local guiShaderActive = (WG.guishader ~= nil)
	if not staticList or guiShaderActive ~= lastGuiShader then
		BuildStaticList()
	end

	gl.CallList(staticList)

	local mx, my = spGetMouseState()
	local currentHoveredIndex = nil
	local tooltipIndex = nil
	for i = 1, #buttons do
		if DrawButtonDynamic(i, mx, my) then
			currentHoveredIndex = i
		end
		-- Tooltip hover is looser than glow hover: it also fires on greyed /
		-- cooling buttons, where "what does this do" matters most.
		local b = buttons[i]
		if IsOnRect(mx, my, b.x1, b.y1, b.x2, b.y2) then
			tooltipIndex = i
		end
	end

	if currentHoveredIndex ~= lastHoveredIndex then
		if currentHoveredIndex then PlayHoverSound() end
		lastHoveredIndex = currentHoveredIndex
	end

	-- Mini tooltip popup, drawn last so it sits above the panel. Suppressed
	-- while targeting -- the player is mid-cast, not browsing.
	if tooltipIndex and not targetingIndex and ABILITIES[tooltipIndex].tooltip then
		DrawMiniTooltip(ABILITIES[tooltipIndex].tooltip, mx, my, ABILITIES[tooltipIndex].accent)
	end

	glColor(1, 1, 1, 1)
end
