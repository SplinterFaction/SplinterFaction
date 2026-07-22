function widget:GetInfo()
	return {
		name      = "Static Widget Selector",
		desc      = "Widget selection panel: enable/disable, reorder, reload LuaUI",
		author    = "trepan, jK, Bluestone (original); restyled",
		date      = "2026-07-22",
		license   = "GNU GPL, v2 or later",
		layer     = -math.huge,
		handler   = true,
		enabled   = true,
	}
end

-- relies on a gadget to implement "luarules reloadluaui"
-- relies on custom stuff in widgetHandler to implement blankOutConfig and allowUserWidgets

include("keysym.h.lua")

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

local bgcorner  = "LuaUI/Images/bgcorner.png"
local accentImg = ":n:LuaUI/Images/staticgui_accent.png"

local BASE_RESOLUTION     = 1080
local PANEL_WIDTH         = 460
local PANEL_HEIGHT        = 620
local OUTER_CORNER        = 10
local INNER_CORNER        = 8.5
local INNER_INSET         = 2.25
local PANEL_ACCENT_HEIGHT = 5

local INNER_PAD     = 12
local TITLE_BAR_H   = 30
local FOOTER_H      = 30
local SECTION_GAP   = 8
local ROW_H         = 22
local SCROLLBAR_W   = 8
local TEXT_PAD      = 10
local BADGE_W       = 34
local BADGE_H       = 15

--------------------------------------------------------------------------------
-- Theme config
--------------------------------------------------------------------------------

local BORDER_COLOR       = {0.15, 0.15, 0.15, 0.90}
local BORDER_COLOR_GUI   = {0.15, 0.15, 0.15, 0.90}
local PANEL_BG_COLOR     = {0.05, 0.05, 0.06, 0.92}
local PANEL_BG_COLOR_GUI = {0.00, 0.00, 0.00, 0.28}
local CATEGORY_BG        = {0.20, 0.20, 0.21, 0.55}
local VIEW_BG            = {0.02, 0.02, 0.03, 0.55}
local HOVER_OVERLAY      = {0.90, 0.90, 0.90, 0.08}
local SCROLLBAR_BG_C     = {1.0, 1.0, 1.0, 0.06}
local SCROLLBAR_THUMB_C  = {1.0, 1.0, 1.0, 0.22}
local SCROLLBAR_THUMBH_C = {1.0, 1.0, 1.0, 0.35}
local BADGE_BG           = {0.20, 0.20, 0.24, 0.70}

local ACCENT_PANEL  = {0.18, 0.52, 0.98, 1}  -- blue
local ACCENT_CLOSE  = {0.90, 0.22, 0.22, 1}  -- red

local TEXT_COLOR = "\255\244\244\244"
local TEXT_DIM   = "\255\160\162\166"

-- Row state colors (RGB tables for font:SetTextColor, and \255 strings for tooltip text)
local STATE_ACTIVE   = {0.35, 0.85, 0.45, 1}
local STATE_ENABLED  = {0.95, 0.85, 0.25, 1}
local STATE_DISABLED = {0.90, 0.40, 0.40, 1}
local STATE_HOT      = {1.00, 1.00, 1.00, 1}   -- pending-click highlight

local STR_GREEN  = "\255\090\220\115"
local STR_YELLOW = "\255\240\215\065"
local STR_RED    = "\255\230\100\100"
local STR_WHITE  = "\255\244\244\244"
local STR_DIM    = "\255\160\162\166"
local STR_BLUE   = "\255\070\140\230"

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
local spGetModKeyState  = Spring.GetModKeyState
local spGetModOptions   = Spring.GetModOptions
local spSendCommands    = Spring.SendCommands

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
local uiScale        = 1.0
local fontfile       = LUAUI_DIRNAME .. "fonts/" .. Spring.GetConfigString("ui_font", "Saira_SemiCondensed-SemiBold.ttf")
local fontfileScale  = (0.5 + (vsx * vsy / 5700000))
local font

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local isOpen      = false
local panelRect   = {x1=0, y1=0, x2=0, y2=0}
local geom        = {}

local fullList    = {}     -- sorted {name, data} pairs, excludes self
local contentH    = 0
local scroll      = 0
local listDirty   = true

local barDrag     = false
local barDragOff  = 0

local lastGuiShader  = nil
local chobbyInterface = false

local allowUserWidgetsOption = true
local FOOTER_BUTTONS = {}   -- built in Initialize (depends on mod option)

--------------------------------------------------------------------------------
-- Sound
--------------------------------------------------------------------------------

local function PlayHoverSound() spPlaySoundFile("hover",     1.0, "ui") end
local function PlayClickSound() spPlaySoundFile("leftclick", 1.0, "ui") end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function InRect(x, y, r)
	return r and x >= r.x1 and x <= r.x2 and y >= r.y1 and y <= r.y2
end

local function IsOnPanel(x, y)
	return x >= panelRect.x1 and x <= panelRect.x2 and y >= panelRect.y1 and y <= panelRect.y2
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

local function TruncateToWidth(text, maxWidth, size)
	if font:GetTextWidth(text) * size <= maxWidth then return text end
	local lo, hi = 0, #text
	while lo < hi do
		local mid = math_floor((lo + hi + 1) / 2)
		local candidate = text:sub(1, mid) .. "..."
		if font:GetTextWidth(candidate) * size <= maxWidth then
			lo = mid
		else
			hi = mid - 1
		end
	end
	if lo <= 0 then return "" end
	return text:sub(1, lo) .. "..."
end

--------------------------------------------------------------------------------
-- Widget list
--------------------------------------------------------------------------------

local function SortListFunc(a, b)
	if a[1] == "Widget Profiler" then return true end
	if b[1] == "Widget Profiler" then return false end
	if a[2].fromZip ~= b[2].fromZip then return a[2].fromZip end
	return a[1] < b[1]
end

local function MaxScroll(viewH)
	return math_max(0, contentH - viewH)
end

local function BuildList()
	local myName = widget:GetInfo().name
	fullList = {}
	for name, data in pairs(widgetHandler.knownWidgets) do
		if name ~= myName then
			fullList[#fullList + 1] = { name, data }
		end
	end
	table.sort(fullList, SortListFunc)
	contentH = ROW_H * uiScale * #fullList
	if geom.view then
		scroll = Clamp(scroll, 0, MaxScroll(geom.view.y2 - geom.view.y1))
	end
	listDirty = false
	widgetHandler.knownChanged = false
end

local function RowAt(x, y)
	local v = geom.view
	if not InRect(x, y, v) then return nil end
	local rowH  = ROW_H * uiScale
	local relTop = (v.y2 + scroll) - y
	if relTop < 0 then return nil end
	local index = math_floor(relTop / rowH) + 1
	if index < 1 or index > #fullList then return nil end
	return fullList[index], index
end

--------------------------------------------------------------------------------
-- Geometry
--------------------------------------------------------------------------------

local function BuildFooterRects()
	local n = #FOOTER_BUTTONS
	if n == 0 then return end
	local fb   = geom.footer
	local gap  = 6 * uiScale
	local btnW = (fb.x2 - fb.x1 - gap * (n - 1)) / n
	for i = 1, n do
		local bx1 = fb.x1 + (i - 1) * (btnW + gap)
		FOOTER_BUTTONS[i].rect = { x1 = bx1, y1 = fb.y1, x2 = bx1 + btnW, y2 = fb.y2 }
	end
end

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
	local cy2 = y2 - pad - acc

	-- Title bar
	local titleH  = TITLE_BAR_H * uiScale
	local titleY2 = cy2
	local titleY1 = titleY2 - titleH
	geom.titleBar = { x1=cx1, y1=titleY1, x2=cx2, y2=titleY2 }

	local closeSz = titleH
	geom.closeRect = { x1=cx2-closeSz, y1=titleY1, x2=cx2, y2=titleY2 }

	-- Footer buttons
	local footerH = FOOTER_H * uiScale
	local footerY1 = cy1
	local footerY2 = footerY1 + footerH
	geom.footer = { x1=cx1, y1=footerY1, x2=cx2, y2=footerY2 }
	BuildFooterRects()

	-- List view + scrollbar
	local viewY2 = titleY1 - SECTION_GAP * uiScale
	local viewY1 = footerY2 + SECTION_GAP * uiScale
	local barW   = SCROLLBAR_W * uiScale
	local viewX1 = cx1
	local viewX2 = cx2 - barW - 4 * uiScale
	geom.view = { x1=viewX1, y1=viewY1, x2=viewX2, y2=viewY2 }
	geom.bar  = { x1=cx2-barW, y1=viewY1, x2=cx2, y2=viewY2 }

	geom.textX  = viewX1 + TEXT_PAD * uiScale
	geom.badgeX = viewX2 - TEXT_PAD * uiScale - BADGE_W * uiScale

	if contentH > 0 then
		scroll = Clamp(scroll, 0, MaxScroll(viewY2 - viewY1))
	end
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------

local function DrawTitle()
	local tb = geom.titleBar
	DrawBox(tb.x1, tb.y1, tb.x2, tb.y2, CATEGORY_BG, 4)
	font:Begin()
	font:SetTextColor(1, 1, 1, 1)
	font:Print(TEXT_COLOR .. "Widget Selector", tb.x1 + 8*uiScale, tb.y1 + (tb.y2-tb.y1)*0.5 - 6*uiScale, 16*uiScale, "lo")
	font:End()

	local cr = geom.closeRect
	DrawBox(cr.x1, cr.y1, cr.x2, cr.y2, CATEGORY_BG, 4)
	DrawAccentStrip(cr.x1, cr.x2, cr.y2, ACCENT_CLOSE)
	font:Begin()
	font:Print(TEXT_COLOR .. "x", cr.x1+(cr.x2-cr.x1)*0.5, cr.y1+(cr.y2-cr.y1)*0.5-6*uiScale, 15*uiScale, "co")
	font:End()
end

local function DrawFooterButtons(mx, my)
	for i = 1, #FOOTER_BUTTONS do
		local b = FOOTER_BUTTONS[i]
		local r = b.rect
		DrawBox(r.x1, r.y1, r.x2, r.y2, CATEGORY_BG, 4)
		DrawAccentStrip(r.x1, r.x2, r.y2, b.accent)
		if InRect(mx, my, r) then
			glColor(HOVER_OVERLAY[1], HOVER_OVERLAY[2], HOVER_OVERLAY[3], HOVER_OVERLAY[4])
			RectRound(r.x1, r.y1, r.x2, r.y2, 4*uiScale)
		end
		font:Begin()
		font:Print(TEXT_COLOR .. b.label, r.x1+(r.x2-r.x1)*0.5, r.y1+(r.y2-r.y1)*0.5-5*uiScale, 12*uiScale, "co")
		font:End()
	end
end

local function DrawList(mx, my)
	local v = geom.view
	DrawBox(v.x1, v.y1, v.x2, v.y2, VIEW_BG, 4)

	if #fullList == 0 then
		font:Begin()
		font:SetTextColor(0.62, 0.64, 0.67, 1)
		font:Print("(no widgets found)", (v.x1+v.x2)*0.5, (v.y1+v.y2)*0.5-5*uiScale, 12*uiScale, "co")
		font:End()
		return
	end

	local rowH  = ROW_H * uiScale
	local hoverEntry, hoverIndex = RowAt(mx, my)

	glScissor(math_floor(v.x1), math_floor(v.y1), math_floor(v.x2 - v.x1), math_floor(v.y2 - v.y1))

	-- Hover highlight (behind text)
	if hoverEntry and not barDrag then
		local rowY2 = v.y2 + scroll - (hoverIndex - 1) * rowH
		local rowY1 = rowY2 - rowH
		glColor(HOVER_OVERLAY[1], HOVER_OVERLAY[2], HOVER_OVERLAY[3], HOVER_OVERLAY[4])
		glRect(v.x1, math_max(rowY1, v.y1), v.x2, math_min(rowY2, v.y2))
	end

	local badgeW = BADGE_W * uiScale
	local badgeH = BADGE_H * uiScale
	local fs = 12 * uiScale

	font:Begin()
	for i = 1, #fullList do
		local rowY2 = v.y2 + scroll - (i - 1) * rowH
		local rowY1 = rowY2 - rowH
		if rowY2 >= v.y1 - rowH and rowY1 <= v.y2 + rowH then
			local name = fullList[i][1]
			local data = fullList[i][2]
			local order = widgetHandler.orderList[name]
			local enabled = order and (order > 0)
			local active = data.active

			local sc
			if active then sc = STATE_ACTIVE
			elseif enabled then sc = STATE_ENABLED
			else sc = STATE_DISABLED end

			local maxTextW = (geom.badgeX - 6*uiScale) - geom.textX
			local label = TruncateToWidth(name, maxTextW, fs)

			font:SetTextColor(sc[1], sc[2], sc[3], sc[4])
			font:Print(label, geom.textX, rowY1 + (rowH - fs) * 0.5 + 1*uiScale, fs, "o")

			if data.fromZip then
				font:SetTextColor(0.75, 0.78, 0.82, 0.9)
				font:Print("MOD", geom.badgeX + badgeW*0.5, rowY1 + (rowH - 9*uiScale)*0.5 + 1*uiScale, 8.5*uiScale, "co")
			end
		end
	end
	font:End()

	-- Badge backgrounds (drawn as quads, need to be outside font:Begin/End)
	for i = 1, #fullList do
		local rowY2 = v.y2 + scroll - (i - 1) * rowH
		local rowY1 = rowY2 - rowH
		if fullList[i][2].fromZip and rowY2 >= v.y1 - rowH and rowY1 <= v.y2 + rowH then
			glColor(BADGE_BG[1], BADGE_BG[2], BADGE_BG[3], BADGE_BG[4])
			local by = rowY1 + (rowH - badgeH) * 0.5
			glRect(geom.badgeX, by, geom.badgeX + badgeW, by + badgeH)
		end
	end

	glScissor(false)
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

--------------------------------------------------------------------------------
-- Footer button actions
--------------------------------------------------------------------------------

local function ActionReload()
	spSendCommands("luarules reloadluaui")
end

local function ActionToggleAllowUser()
	if widgetHandler.allowUserWidgets then
		widgetHandler.__allowUserWidgets = false
		Spring.Echo("Disallowed user widgets, reloading...")
	else
		widgetHandler.__allowUserWidgets = true
		Spring.Echo("Allowed user widgets, reloading...")
	end
	spSendCommands("luarules reloadluaui")
end

local function BuildFooterButtons()
	FOOTER_BUTTONS = {
		{ label = "Reload LuaUI", accent = {0.18, 0.52, 0.98, 1}, onClick = ActionReload },
	}
	if allowUserWidgetsOption then
		local label = widgetHandler.allowUserWidgets and "Disallow User Widgets" or "Allow User Widgets"
		FOOTER_BUTTONS[#FOOTER_BUTTONS + 1] = { label = label, accent = {0.95, 0.65, 0.18, 1}, onClick = ActionToggleAllowUser }
	end
end

--------------------------------------------------------------------------------
-- Open / Close
--------------------------------------------------------------------------------

local function Open()
	if isOpen then return end
	isOpen = true
	BuildFooterButtons()
	BuildGeometry()
	listDirty = true
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
	if key == KEYSYMS.F11 and not isRepeat and not (mods.alt or mods.ctrl or mods.meta or mods.shift) then
		Toggle()
		return true
	end
	if isOpen and key == KEYSYMS.ESCAPE then
		Close()
		return true
	end
	if isOpen and key == KEYSYMS.PAGEUP then
		local viewH = geom.view.y2 - geom.view.y1
		scroll = Clamp(scroll - viewH, 0, MaxScroll(viewH))
		return true
	end
	if isOpen and key == KEYSYMS.PAGEDOWN then
		local viewH = geom.view.y2 - geom.view.y1
		scroll = Clamp(scroll + viewH, 0, MaxScroll(viewH))
		return true
	end
	return false
end

function widget:IsAbove(x, y)
	return isOpen and IsOnPanel(x, y)
end

function widget:MousePress(x, y, button)
	if chobbyInterface or spIsGUIHidden() or not isOpen then return false end
	if not IsOnPanel(x, y) then
		Close()
		return false
	end

	if button == 1 then
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
	end

	return true
end

function widget:MouseRelease(x, y, button)
	if not isOpen then return false end
	if barDrag then barDrag = false ; return true end
	if not IsOnPanel(x, y) then return false end

	if button == 1 then
		if InRect(x, y, geom.closeRect) then
			PlayClickSound()
			Close()
			return true
		end
		for i = 1, #FOOTER_BUTTONS do
			local b = FOOTER_BUTTONS[i]
			if InRect(x, y, b.rect) then
				PlayClickSound()
				b.onClick()
				return true
			end
		end
	end

	local entry = RowAt(x, y)
	if entry then
		local name = entry[1]
		if button == 1 then
			PlayClickSound()
			widgetHandler:ToggleWidget(name)
			listDirty = true
		elseif button == 2 or button == 3 then
			local w = widgetHandler:FindWidget(name)
			if w then
				if button == 2 then
					widgetHandler:LowerWidget(w)
				else
					widgetHandler:RaiseWidget(w)
				end
				widgetHandler:SaveConfigData()
			end
		end
		return true
	end

	return true
end

function widget:MouseMove(x, y, dx, dy, button)
	if not isOpen or not barDrag then return false end

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
	end
	return true
end

function widget:MouseWheel(up, value)
	if not isOpen then return false end
	local a, c, m, s = spGetModKeyState()
	if a or m then return false end   -- alt/meta pass through to normal control

	local mx, my = spGetMouseState()
	if not InRect(mx, my, geom.view) and not InRect(mx, my, geom.bar) then return false end

	local viewH = geom.view.y2 - geom.view.y1
	if contentH <= viewH then return true end
	local step = (s and 4 or (c and 1 or 2)) * ROW_H * uiScale
	scroll = Clamp(scroll + (up and -step or step), 0, contentH - viewH)
	return true
end

function widget:GetTooltip(x, y)
	if not isOpen then return nil end
	local entry = RowAt(x, y)
	if not entry then
		return STR_WHITE .. "Widget Selector\n" ..
			STR_DIM .. "LMB: toggle widget\n" ..
			STR_DIM .. "MMB: lower widget\n" ..
			STR_DIM .. "RMB: raise widget"
	end

	local name = entry[1]
	local data = entry[2]
	local order = widgetHandler.orderList[name]
	local enabled = order and (order > 0)

	local stateStr = (data.active and STR_GREEN) or (enabled and STR_YELLOW) or STR_RED
	local tt = stateStr .. name .. "\n"
	if data.desc then tt = tt .. STR_WHITE .. data.desc .. "\n" end
	if data.author then tt = tt .. STR_BLUE .. "Author: " .. STR_DIM .. data.author .. "\n" end
	if data.basename then tt = tt .. STR_DIM .. data.basename end
	if data.fromZip then tt = tt .. STR_RED .. " (mod widget)" end
	return tt
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function widget:Update(dt)
	if not isOpen then return end
	if listDirty or widgetHandler.knownChanged then
		BuildList()
	end
end

function widget:DrawScreen()
	if chobbyInterface or spIsGUIHidden() or not isOpen or not font then return end

	local guiShaderActive = (WG.guishader ~= nil)
	lastGuiShader = guiShaderActive

	if listDirty or widgetHandler.knownChanged then
		BuildList()
	end

	local mx, my = spGetMouseState()

	DrawPanelChrome()
	DrawTitle()
	DrawFooterButtons(mx, my)
	DrawList(mx, my)
	DrawScrollbar(mx, my)

	glColor(1, 1, 1, 1)
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1, 19) == 'LobbyOverlayActive1')
	end
end

function widget:TextCommand(s)
	local token = {}
	local n = 0
	for w in string.gmatch(s, "%S+") do
		n = n + 1
		token[n] = w
	end
	if n == 1 and token[1] == "reset" then
		widgetHandler.blankOutConfig = true
		spSendCommands("luarules reloadluaui")
	end
	if n == 1 and token[1] == "factoryreset" then
		widgetHandler.__blankOutConfig = true
		widgetHandler.__allowUserWidgets = false
		spSendCommands("luarules reloadluaui")
	end
end

function widget:Initialize()
	widgetHandler.knownChanged = true
	spSendCommands('unbindkeyset f11')

	allowUserWidgetsOption = true
	if spGetModOptions and (tonumber(spGetModOptions().allowuserwidgets) or 1) == 0 then
		allowUserWidgetsOption = false
	end

	vsx, vsy = spGetViewGeometry()
	fontfileScale = (0.5 + (vsx * vsy / 5700000))
	font = gl.LoadFont(fontfile, 23*fontfileScale, 5*fontfileScale, 1.8)

	BuildFooterButtons()
	BuildGeometry()

	WG.StaticWidgetSelector = {
		Toggle = Toggle,
		Show   = Open,
		Hide   = Close,
	}
end

function widget:Shutdown()
	spSendCommands('bind f11 luaui selector')  -- fallback to the vanilla selector if this one is removed/crashes

	if font then gl.DeleteFont(font) end
	WG.StaticWidgetSelector = nil
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

--------------------------------------------------------------------------------
-- Position / open-state persistence
--------------------------------------------------------------------------------

function widget:GetConfigData()
	return { show = isOpen }
end

function widget:SetConfigData(data)
	if data and data.show then
		Open()
	end
end
