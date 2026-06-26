function widget:GetInfo()
	return {
		name      = "Static Log",
		desc      = "Scrollback panel for chat and console output (Chat / Console / All tabs)",
		author    = "",
		date      = "2026-06-26",
		license   = "GNU GPL, v2 or later",
		layer     = 1002,
		enabled   = true,
	}
end

include("keysym.h.lua")

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

local bgcorner  = "LuaUI/Images/bgcorner.png"
local accentImg = ":n:LuaUI/Images/staticgui_accent.png"

local BASE_RESOLUTION     = 1080
local PANEL_WIDTH         = 1100   -- matches the end graph panel
local PANEL_HEIGHT        = 660
local OUTER_CORNER        = 10
local INNER_CORNER        = 8.5
local INNER_INSET         = 2.25
local PANEL_ACCENT_HEIGHT = 5

local INNER_PAD     = 12
local TITLE_BAR_H   = 30
local TAB_H         = 26
local TAB_GAP       = 6
local SECTION_GAP   = 8
local TEXT_PAD      = 10
local SCROLLBAR_W   = 8

local LOG_FONT_SIZE = 14   -- render size (pre-uiScale)
local LINE_H        = 19   -- per visual line (pre-uiScale)

-- Colors -----------------------------------------------------------------------
local BORDER_COLOR        = {0.15, 0.15, 0.15, 0.90}
local BORDER_COLOR_GUI    = {0.15, 0.15, 0.15, 0.90}
local PANEL_BG_COLOR      = {0.05, 0.05, 0.06, 0.92}
local PANEL_BG_COLOR_GUI  = {0.00, 0.00, 0.00, 0.28}
local CATEGORY_BG         = {0.20, 0.20, 0.21, 0.55}
local VIEW_BG             = {0.02, 0.02, 0.03, 0.55}
local TAB_BG              = {0.12, 0.12, 0.13, 0.85}
local TAB_BG_ACTIVE       = {0.20, 0.21, 0.23, 0.95}
local HOVER_OVERLAY       = {0.90, 0.90, 0.90, 0.09}
local SCROLLBAR_BG_C      = {1.0, 1.0, 1.0, 0.06}
local SCROLLBAR_THUMB_C   = {1.0, 1.0, 1.0, 0.22}
local SCROLLBAR_THUMBH_C  = {1.0, 1.0, 1.0, 0.35}

local ACCENT_PANEL  = {0.18, 0.52, 0.98, 1}
local ACCENT_CLOSE  = {0.90, 0.22, 0.22, 1}

local TEXT_COLOR    = "\255\244\244\244"

-- Per-segment draw colors (RGB tables)
local COL_DIM    = {0.62, 0.64, 0.67}
local COL_WHITE  = {1.00, 1.00, 1.00}
local COL_SYSTEM = {0.75, 0.75, 0.75}

-- Tabs: id, label, accent
local TABS = {
	{ id = "chat",    label = "Chat",    accent = {0.22, 0.78, 0.35, 1} },
	{ id = "console", label = "Console", accent = {0.95, 0.65, 0.18, 1} },
	{ id = "all",     label = "All",     accent = {0.18, 0.52, 0.98, 1} },
}

--------------------------------------------------------------------------------
-- Speedups
--------------------------------------------------------------------------------

local glColor    = gl.Color
local glRect     = gl.Rect
local glTexture  = gl.Texture
local glTexRect  = gl.TexRect
local glScissor  = gl.Scissor

local spGetViewGeometry = Spring.GetViewGeometry
local spGetMouseState   = Spring.GetMouseState
local spPlaySoundFile   = Spring.PlaySoundFile
local spIsGUIHidden     = Spring.IsGUIHidden

local math_floor = math.floor
local math_max   = math.max
local math_min   = math.min

local function Clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

--------------------------------------------------------------------------------
-- Font
--------------------------------------------------------------------------------

local vsx, vsy      = spGetViewGeometry()
local uiScale       = 1.0
local fontfile      = LUAUI_DIRNAME .. "fonts/" .. Spring.GetConfigString("ui_font", "Saira_SemiCondensed-SemiBold.ttf")
local fontfileScale = (0.5 + (vsx * vsy / 5700000))
local font

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local isOpen      = false
local panelRect   = {x1=0, y1=0, x2=0, y2=0}
local geom        = {}

local currentTab  = 1        -- index into TABS
local rows        = {}       -- built visual lines for the active tab
local contentH    = 0
local scroll      = 0        -- pixels of content scrolled above the view top
local stick       = true     -- keep pinned to newest unless the user scrolls up
local rowsDirty   = true
local lastLogLen  = -1
local lastTabId   = nil

local barDrag     = false
local barDragOff  = 0

local lastGuiShader = nil

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function PlayHoverSound()  spPlaySoundFile("hover",     1.0, "ui") end
local function PlayClickSound()  spPlaySoundFile("leftclick", 1.0, "ui") end

local function IsOnPanel(x, y)
	return x >= panelRect.x1 and x <= panelRect.x2
			and y >= panelRect.y1 and y <= panelRect.y2
end

local function InRect(x, y, r)
	return r and x >= r.x1 and x <= r.x2 and y >= r.y1 and y <= r.y2
end

local function GetBorderColor()
	if WG.guishader then return BORDER_COLOR_GUI end
	return BORDER_COLOR
end

local function GetPanelBGColor()
	if WG.guishader then return PANEL_BG_COLOR_GUI end
	return PANEL_BG_COLOR
end

local function RectRound(px, py, sx, sy, cs)
	px, py, sx, sy, cs = math_floor(px), math_floor(py), math_floor(sx), math_floor(sy), math_floor(cs)
	glRect(px+cs, py, sx-cs, sy)
	glRect(sx-cs, py+cs, sx, sy-cs)
	glRect(px, py+cs, px+cs, sy-cs)
	glTexture(bgcorner)
	glTexRect(px,    py+cs, px+cs, py)
	glTexRect(sx,    py+cs, sx-cs, py)
	glTexRect(px,    sy-cs, px+cs, sy)
	glTexRect(sx,    sy-cs, sx-cs, sy)
	glTexture(false)
end

local function DrawAccentStrip(x1, x2, yTop, accent)
	local ah = PANEL_ACCENT_HEIGHT * uiScale
	glColor(accent[1], accent[2], accent[3], 1)
	glTexture(accentImg)
	glTexRect(x1, yTop - ah, x2, yTop)
	glTexture(false)
end

local function DrawPanelChrome()
	local bc  = GetBorderColor()
	local pc  = GetPanelBGColor()
	local oc  = OUTER_CORNER * uiScale
	local ic  = INNER_CORNER * uiScale
	local ins = INNER_INSET  * uiScale
	glColor(bc[1], bc[2], bc[3], bc[4])
	RectRound(panelRect.x1, panelRect.y1, panelRect.x2, panelRect.y2, oc)
	glColor(pc[1], pc[2], pc[3], pc[4])
	RectRound(panelRect.x1+ins, panelRect.y1+ins, panelRect.x2-ins, panelRect.y2-ins, ic)
	DrawAccentStrip(panelRect.x1+ins, panelRect.x2-ins, panelRect.y2-ins, ACCENT_PANEL)
end

local function DrawBox(x1, y1, x2, y2, c, cs)
	glColor(c[1], c[2], c[3], c[4])
	RectRound(x1, y1, x2, y2, (cs or 4) * uiScale)
end

local function MeasureText(text, size)
	return font:GetTextWidth(text) * size
end

local function FormatGameTime(s)
	s = s or 0
	if s < 0 then s = 0 end
	local m   = math_floor(s / 60)
	local sec = math_floor(s % 60)
	return string.format("%d:%02d", m, sec)
end

local function WrapTextToWidth(text, maxWidth, size)
	if not text or text == "" then return {""} end
	local lines = {}
	local current = ""
	for word in text:gmatch("%S+") do
		local testLine = (current == "") and word or (current .. " " .. word)
		if MeasureText(testLine, size) <= maxWidth then
			current = testLine
		else
			if current ~= "" then
				lines[#lines + 1] = current
				current = word
			else
				lines[#lines + 1] = word   -- single over-long word fallback
				current = ""
			end
		end
	end
	if current ~= "" then lines[#lines + 1] = current end
	if #lines == 0 then lines[1] = "" end
	return lines
end

--------------------------------------------------------------------------------
-- Row construction
--------------------------------------------------------------------------------
-- Each row is a list of segments {text, color={r,g,b}, x} drawn left-aligned at
-- an absolute x offset from the text origin. Rebuilt only when the log grows,
-- the tab changes, or geometry/guishader changes.

local function EntryMatchesTab(entry, tabId, isChatFn)
	if tabId == "all" then return true end
	local chat = isChatFn and isChatFn(entry) or (entry.channel ~= "system")
	if tabId == "chat"    then return chat end
	if tabId == "console" then return not chat end
	return true
end

local function BuildRows()
	rows = {}
	contentH = 0

	local fsBody = LOG_FONT_SIZE * uiScale
	local lineH  = LINE_H * uiScale
	local viewW  = geom.viewTextW or 100

	local cb = WG.Chatterbox
	if not cb or not cb.GetLog then
		rows[1] = { segs = { { text = "Chat log source not loaded (enable ChatterboxChat).", color = COL_SYSTEM, x = 0 } } }
		contentH = lineH
		rowsDirty = false
		return
	end

	local log    = cb.GetLog()
	local isChat = cb.IsChat
	local tabId  = TABS[currentTab].id

	for li = 1, #log do
		local e = log[li]
		if EntryMatchesTab(e, tabId, isChat) then
			local tstr = "[" .. FormatGameTime(e.gtime) .. "] "
			local tw   = MeasureText(tstr, fsBody)

			if e.player then
				local nameText = e.player or ""
				local nameW    = MeasureText(nameText, fsBody)
				local sep      = ": "
				local sepW     = MeasureText(sep, fsBody)
				local bodyX    = tw + nameW + sepW
				local wrapW    = math_max(40, viewW - bodyX)
				local wrapped  = WrapTextToWidth(e.body or "", wrapW, fsBody)
				local nameCol  = e.nameColor or COL_WHITE
				local bodyCol  = e.bodyColor or COL_WHITE

				rows[#rows + 1] = { segs = {
					{ text = tstr,         color = COL_DIM,  x = 0 },
					{ text = nameText,     color = nameCol,  x = tw },
					{ text = sep,          color = COL_WHITE, x = tw + nameW },
					{ text = wrapped[1] or "", color = bodyCol, x = bodyX },
				} }
				for i = 2, #wrapped do
					rows[#rows + 1] = { segs = { { text = wrapped[i], color = bodyCol, x = bodyX } } }
				end
			else
				local bodyCol = e.bodyColor or COL_SYSTEM
				local wrapW   = math_max(40, viewW - tw)
				local wrapped = WrapTextToWidth(e.body or e.raw or "", wrapW, fsBody)
				rows[#rows + 1] = { segs = {
					{ text = tstr,             color = COL_DIM, x = 0 },
					{ text = wrapped[1] or "", color = bodyCol, x = tw },
				} }
				for i = 2, #wrapped do
					rows[#rows + 1] = { segs = { { text = wrapped[i], color = bodyCol, x = tw } } }
				end
			end
		end
	end

	if #rows == 0 then
		rows[1] = { segs = { { text = "(no messages)", color = COL_DIM, x = 0 } } }
	end

	contentH = #rows * lineH
	lastLogLen = #log
	lastTabId  = tabId
	rowsDirty  = false
end

local function MaxScroll(viewH)
	return math_max(0, contentH - viewH)
end

local function ApplyStick()
	if not geom.view then return end
	local viewH = geom.view.y2 - geom.view.y1
	local maxS  = MaxScroll(viewH)
	if stick then
		scroll = maxS
	else
		scroll = Clamp(scroll, 0, maxS)
	end
end

--------------------------------------------------------------------------------
-- Geometry
--------------------------------------------------------------------------------

local function BuildGeometry()
	uiScale = vsy / BASE_RESOLUTION

	local pw  = PANEL_WIDTH  * uiScale
	local ph  = PANEL_HEIGHT * uiScale
	local pad = INNER_PAD    * uiScale
	local acc = PANEL_ACCENT_HEIGHT * uiScale

	local x1 = math_floor(vsx * 0.5 - pw * 0.5)
	local y1 = math_floor(vsy * 0.5 - ph * 0.5)
	local x2 = x1 + math_floor(pw)
	local y2 = y1 + math_floor(ph)
	panelRect = { x1=x1, y1=y1, x2=x2, y2=y2 }

	local cx1 = x1 + pad
	local cx2 = x2 - pad
	local cy1 = y1 + pad
	local cy2 = y2 - pad - acc   -- leave room for top accent strip

	-- Title bar
	local titleH  = TITLE_BAR_H * uiScale
	local titleY2 = cy2
	local titleY1 = titleY2 - titleH
	geom.titleBar = { x1=cx1, y1=titleY1, x2=cx2, y2=titleY2 }

	local closeSz = titleH
	geom.closeRect = { x1=cx2-closeSz, y1=titleY1, x2=cx2, y2=titleY2 }

	-- Tab row
	local tabsY2 = titleY1 - SECTION_GAP * uiScale
	local tabsY1 = tabsY2 - TAB_H * uiScale
	local tabGap = TAB_GAP * uiScale
	local tabW   = (cx2 - cx1 - tabGap * (#TABS - 1)) / #TABS
	geom.tabs = {}
	for i = 1, #TABS do
		local tx1 = cx1 + (i - 1) * (tabW + tabGap)
		geom.tabs[i] = { x1=tx1, y1=tabsY1, x2=tx1+tabW, y2=tabsY2 }
	end

	-- Log view + scrollbar
	local viewY2 = tabsY1 - SECTION_GAP * uiScale
	local viewY1 = cy1
	local barW   = SCROLLBAR_W * uiScale
	local viewX1 = cx1
	local viewX2 = cx2 - barW - 4 * uiScale
	geom.view = { x1=viewX1, y1=viewY1, x2=viewX2, y2=viewY2 }
	geom.bar  = { x1=cx2-barW, y1=viewY1, x2=cx2, y2=viewY2 }

	geom.textX     = viewX1 + TEXT_PAD * uiScale
	geom.viewTextW = (viewX2 - TEXT_PAD * uiScale) - geom.textX

	rowsDirty = true
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------

local function DrawTitle()
	local tb = geom.titleBar
	DrawBox(tb.x1, tb.y1, tb.x2, tb.y2, CATEGORY_BG, 4)
	font:Begin()
	font:Print(TEXT_COLOR .. "Log", tb.x1 + 8*uiScale, tb.y1 + (tb.y2-tb.y1)*0.5 - 6*uiScale, 16*uiScale, "lo")
	font:End()

	-- Close button
	local cr = geom.closeRect
	DrawBox(cr.x1, cr.y1, cr.x2, cr.y2, CATEGORY_BG, 4)
	DrawAccentStrip(cr.x1, cr.x2, cr.y2, ACCENT_CLOSE)
	font:Begin()
	font:Print(TEXT_COLOR .. "x", cr.x1+(cr.x2-cr.x1)*0.5, cr.y1+(cr.y2-cr.y1)*0.5-6*uiScale, 15*uiScale, "co")
	font:End()
end

local function DrawTabs(mx, my)
	for i = 1, #TABS do
		local r      = geom.tabs[i]
		local active = (i == currentTab)
		local accent = TABS[i].accent
		DrawBox(r.x1, r.y1, r.x2, r.y2, active and TAB_BG_ACTIVE or TAB_BG, 4)
		if active then
			DrawAccentStrip(r.x1, r.x2, r.y2, accent)
		end
		if not active and InRect(mx, my, r) then
			glColor(HOVER_OVERLAY[1], HOVER_OVERLAY[2], HOVER_OVERLAY[3], HOVER_OVERLAY[4])
			RectRound(r.x1, r.y1, r.x2, r.y2, 4*uiScale)
		end
		local label = (active and TEXT_COLOR or "\255\170\172\176") .. TABS[i].label
		font:Begin()
		font:Print(label, r.x1+(r.x2-r.x1)*0.5, r.y1+(r.y2-r.y1)*0.5-5*uiScale, 12*uiScale, "co")
		font:End()
	end
end

local function DrawScrollbar(mx, my)
	local bar   = geom.bar
	local viewH = geom.view.y2 - geom.view.y1
	glColor(SCROLLBAR_BG_C[1], SCROLLBAR_BG_C[2], SCROLLBAR_BG_C[3], SCROLLBAR_BG_C[4])
	glRect(bar.x1, bar.y1, bar.x2, bar.y2)
	if contentH <= viewH then return end

	local trackH = bar.y2 - bar.y1
	local thumbH = math_max(24*uiScale, trackH * (viewH / contentH))
	local range  = trackH - thumbH
	local frac   = Clamp(scroll / math_max(1, contentH - viewH), 0, 1)
	local ty2    = bar.y2 - range * frac
	local ty1    = ty2 - thumbH
	local hov    = InRect(mx, my, bar) or barDrag
	local tc     = hov and SCROLLBAR_THUMBH_C or SCROLLBAR_THUMB_C
	glColor(tc[1], tc[2], tc[3], tc[4])
	glRect(bar.x1, ty1, bar.x2, ty2)
end

local function DrawLog()
	local v      = geom.view
	local lineH  = LINE_H * uiScale
	local fsBody = LOG_FONT_SIZE * uiScale
	local textX  = geom.textX

	DrawBox(v.x1, v.y1, v.x2, v.y2, VIEW_BG, 4)

	local viewTop = v.y2
	local viewBot = v.y1

	glScissor(math_floor(v.x1), math_floor(v.y1), math_floor(v.x2 - v.x1), math_floor(v.y2 - v.y1))
	font:Begin()
	for i = 1, #rows do
		local rowTop = viewTop + scroll - (i - 1) * lineH
		if rowTop <= viewTop + lineH and (rowTop - lineH) >= viewBot - lineH then
			local baseY = rowTop - lineH + (lineH - fsBody) * 0.5
			local segs  = rows[i].segs
			for s = 1, #segs do
				local seg = segs[s]
				if seg.text ~= "" then
					font:SetTextColor(seg.color[1], seg.color[2], seg.color[3], 1)
					font:Print(seg.text, textX + seg.x, baseY, fsBody, "o")
				end
			end
		end
	end
	font:End()
	glScissor(false)
	font:SetTextColor(1, 1, 1, 1)
end

--------------------------------------------------------------------------------
-- Open / Close
--------------------------------------------------------------------------------

local function Open()
	if isOpen then return end
	isOpen = true
	BuildGeometry()
	stick     = true
	rowsDirty = true
	PlayClickSound()
end

local function Close()
	if not isOpen then return end
	isOpen  = false
	barDrag = false
	PlayClickSound()
end

local function Toggle()
	if isOpen then Close() else Open() end
end

--------------------------------------------------------------------------------
-- Input
--------------------------------------------------------------------------------

function widget:KeyPress(key, mods, isRepeat)
	if isRepeat then return false end
	if isOpen and key == KEYSYMS.ESCAPE then
		Close()
		return true
	end
	return false
end

function widget:IsAbove(x, y)
	return isOpen and IsOnPanel(x, y)
end

function widget:MousePress(x, y, button)
	if not isOpen then return false end
	if not IsOnPanel(x, y) then return false end
	if button ~= 1 then return true end

	-- Scrollbar thumb drag
	local bar   = geom.bar
	local viewH = geom.view.y2 - geom.view.y1
	if InRect(x, y, bar) and contentH > viewH then
		local trackH = bar.y2 - bar.y1
		local thumbH = math_max(24*uiScale, trackH * (viewH / contentH))
		local range  = trackH - thumbH
		local frac   = Clamp(scroll / math_max(1, contentH - viewH), 0, 1)
		local ty2    = bar.y2 - range * frac
		barDrag    = true
		barDragOff = ty2 - y
		return true
	end

	return true
end

function widget:MouseRelease(x, y, button)
	if not isOpen then return false end
	if barDrag then barDrag = false ; return true end
	if button ~= 1 then return IsOnPanel(x, y) end
	if not IsOnPanel(x, y) then return false end

	-- Close
	if InRect(x, y, geom.closeRect) then
		PlayClickSound()
		Close()
		return true
	end

	-- Tabs
	for i = 1, #TABS do
		if InRect(x, y, geom.tabs[i]) then
			if i ~= currentTab then
				currentTab = i
				stick      = true
				rowsDirty  = true
				PlayClickSound()
			end
			return true
		end
	end

	return true
end

function widget:MouseMove(x, y, dx, dy, button)
	if not isOpen then return false end
	if not barDrag then return false end

	local bar    = geom.bar
	local viewH  = geom.view.y2 - geom.view.y1
	if contentH <= viewH then return true end
	local trackH = bar.y2 - bar.y1
	local thumbH = math_max(24*uiScale, trackH * (viewH / contentH))
	local range  = trackH - thumbH
	if range > 0 then
		local ty2  = Clamp(y + barDragOff, bar.y1 + thumbH, bar.y2)
		local frac = (bar.y2 - ty2) / range
		scroll = Clamp(frac * (contentH - viewH), 0, contentH - viewH)
		stick  = scroll >= (contentH - viewH) - 1
	end
	return true
end

function widget:MouseWheel(up, value)
	if not isOpen then return false end
	local mx, my = spGetMouseState()
	if not InRect(mx, my, geom.view) and not InRect(mx, my, geom.bar) then
		return false
	end
	local viewH = geom.view.y2 - geom.view.y1
	if contentH <= viewH then return true end
	local step = math_floor(LINE_H * uiScale * 3)
	scroll = Clamp(scroll + (up and -step or step), 0, contentH - viewH)
	stick  = scroll >= (contentH - viewH) - 1
	return true
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function widget:Update(dt)
	if not isOpen then return end
	-- Rebuild when new lines have arrived (or after a tab/geometry change).
	local cb  = WG.Chatterbox
	local len = (cb and cb.GetLog) and #cb.GetLog() or 0
	if rowsDirty or len ~= lastLogLen or TABS[currentTab].id ~= lastTabId then
		BuildRows()
		ApplyStick()
	end
end

function widget:DrawScreen()
	if spIsGUIHidden() then return end
	if not isOpen then return end
	if not font then return end

	local guiShaderActive = (WG.guishader ~= nil)
	if guiShaderActive ~= lastGuiShader then
		lastGuiShader = guiShaderActive
	end

	if rowsDirty then
		BuildRows()
		ApplyStick()
	end

	local mx, my = spGetMouseState()

	DrawPanelChrome()
	DrawTitle()
	DrawTabs(mx, my)
	DrawLog()
	DrawScrollbar(mx, my)

	-- Close-button hover tint
	if InRect(mx, my, geom.closeRect) then
		glColor(HOVER_OVERLAY[1], HOVER_OVERLAY[2], HOVER_OVERLAY[3], HOVER_OVERLAY[4])
		RectRound(geom.closeRect.x1, geom.closeRect.y1, geom.closeRect.x2, geom.closeRect.y2, 4*uiScale)
	end

	glColor(1, 1, 1, 1)
end

function widget:Initialize()
	vsx, vsy = spGetViewGeometry()
	fontfileScale = (0.5 + (vsx * vsy / 5700000))
	font = gl.LoadFont(fontfile, 23*fontfileScale, 5*fontfileScale, 1.8)
	BuildGeometry()
	WG.StaticChatLog = {
		Toggle = Toggle,
		Show   = Open,
		Hide   = Close,
	}
end

function widget:Shutdown()
	if font then gl.DeleteFont(font) end
	WG.StaticChatLog = nil
end

function widget:ViewResize(nx, ny)
	vsx, vsy = nx, ny
	local newScale = (0.5 + (vsx * vsy / 5700000))
	if newScale ~= fontfileScale then
		fontfileScale = newScale
		if font then gl.DeleteFont(font) end
		font = gl.LoadFont(fontfile, 23*fontfileScale, 5*fontfileScale, 1.8)
	end
	BuildGeometry()
end
