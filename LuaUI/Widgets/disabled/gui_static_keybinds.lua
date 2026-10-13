function widget:GetInfo()
	return {
		name      = "Static Keybinds",
		desc      = "Rebind keys in-game. Writes changes to sf_uikeys.txt in the write dir; never touches uikeys.txt.",
		author    = "",
		date      = "2026",
		license   = "GNU GPL, v2 or later",
		layer     = -100,
		enabled   = true,
	}
end

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

local bgcorner  = "LuaUI/Images/bgcorner.png"
local accentImg = ":n:LuaUI/Images/staticgui_accent.png"

-- Overridden from WG.SFKeybindings when the loader widget is present
local GAME_KEYS_FILE = "luaui/configs/sf_keys.txt"
local USER_KEYS_FILE = "sf_uikeys.txt"

local BASE_RESOLUTION     = 1080
local PANEL_WIDTH         = 580
local PANEL_HEIGHT        = 640
local OUTER_CORNER        = 10
local INNER_CORNER        = 8.5
local INNER_INSET         = 2.25
local PANEL_ACCENT_HEIGHT = 5

local INNER_PAD    = 12
local TITLE_BAR_H  = 30
local TAB_H        = 24
local STATUS_H     = 18
local FOOTER_H     = 30
local SECTION_GAP  = 8
local ROW_H        = 24
local SCROLLBAR_W  = 8
local TEXT_PAD     = 10
local BADGE_W      = 132
local BADGE_H      = 17

local STATUS_TIME  = 6      -- seconds a status message stays up
local CONFIRM_MAX  = 6      -- max conflict lines listed in the dialog

--------------------------------------------------------------------------------
-- Theme config
--------------------------------------------------------------------------------

local COL = {
	border       = {0.15, 0.15, 0.15, 0.90},
	borderGui    = {0.15, 0.15, 0.15, 0.90},
	panelBg      = {0.05, 0.05, 0.06, 0.92},
	panelBgGui   = {0.00, 0.00, 0.00, 0.28},
	categoryBg   = {0.20, 0.20, 0.21, 0.55},
	viewBg       = {0.02, 0.02, 0.03, 0.55},
	hover        = {0.90, 0.90, 0.90, 0.08},
	scrollBg     = {1.00, 1.00, 1.00, 0.06},
	scrollThumb  = {1.00, 1.00, 1.00, 0.22},
	scrollThumbH = {1.00, 1.00, 1.00, 0.35},
	badgeBg      = {0.20, 0.20, 0.24, 0.70},
	badgeBgHot   = {0.30, 0.32, 0.40, 0.85},
	dimmer       = {0.00, 0.00, 0.00, 0.62},
	dialogBg     = {0.07, 0.07, 0.09, 0.98},

	accentPanel  = {0.18, 0.52, 0.98, 1},   -- blue
	accentClose  = {0.90, 0.22, 0.22, 1},   -- red
	accentWarn   = {0.95, 0.65, 0.18, 1},   -- amber
	accentOk     = {0.22, 0.78, 0.35, 1},   -- green
	accentTab    = {0.20, 0.75, 0.80, 1},   -- teal

	text         = {0.96, 0.96, 0.96, 1},
	textDim      = {0.62, 0.64, 0.67, 1},
	textHeader   = {0.55, 0.72, 0.95, 1},
	keyBound     = {0.95, 0.85, 0.25, 1},
	keyUnbound   = {0.55, 0.56, 0.60, 1},
	keyEdited    = {0.35, 0.85, 0.45, 1},
	warn         = {0.95, 0.65, 0.18, 1},
	err          = {0.90, 0.40, 0.40, 1},
	ok           = {0.35, 0.85, 0.45, 1},
}

local TAG_TEXT = "\255\244\244\244"

--------------------------------------------------------------------------------
-- Speedups
--------------------------------------------------------------------------------

-- Raw engine entry points. Only the legacy fallback further down calls these
-- directly; everything else goes through the shim locals so that drawing is
-- batched by the shapes module when it is available.
local rawColor    = gl.Color
local rawRect     = gl.Rect
local rawTexture  = gl.Texture
local rawTexRect  = gl.TexRect
local rawScissor  = gl.Scissor

-- Drawing shim. Forward-declared here so every function below closes over the
-- same upvalues; bound for real by BindDrawing() in widget:Initialize.
local glColor, glRect, glTexture, glTexRect, glScissor
local RectRound, AccentStrip, Flush
local usingShapes = false

-- The shapes module batches, so text drawn between two shape calls would land
-- on the wrong side of them. Wrapping the font handle makes font:Begin() and
-- font:End() flush at the right moments, which keeps every existing
-- font:Print call site correct without auditing draw order by hand.
local function WrapFont(f)
	local SG = WG.StaticGUI
	if f and SG and SG.WrapFont then
		return SG.WrapFont(f)
	end
	return f
end

local function ReleaseFont(f)
	if not f then return end
	local SG = WG.StaticGUI
	if SG and SG.DeleteFont then
		SG.DeleteFont(f)
	else
		gl.DeleteFont(f)
	end
end
local spGetViewGeometry  = Spring.GetViewGeometry
local spGetMouseState    = Spring.GetMouseState
local spPlaySoundFile    = Spring.PlaySoundFile
local spIsGUIHidden      = Spring.IsGUIHidden
local spGetModKeyState   = Spring.GetModKeyState
local spSendCommands     = Spring.SendCommands
local spGetKeyBindings   = Spring.GetKeyBindings
local spGetActionHotKeys = Spring.GetActionHotKeys
local spGetKeySymbol     = Spring.GetKeySymbol

local math_floor = math.floor
local math_max   = math.max
local math_min   = math.min

--------------------------------------------------------------------------------
-- Font
--------------------------------------------------------------------------------

local vsx, vsy       = spGetViewGeometry()
local uiScale        = 1.0
local fontfile       = LUAUI_DIRNAME .. "fonts/" .. Spring.GetConfigString("ui_font", "Saira_SemiCondensed-SemiBold.ttf")
local fontfileScale  = (0.5 + (vsx * vsy / 5700000))
local font

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local isOpen    = false
local panelRect = {x1=0, y1=0, x2=0, y2=0}
local geom      = {}

local tab       = "sf"        -- "sf" | "all"
local TABS      = {
	{ id = "sf",  label = "SF Keys" },
	{ id = "all", label = "All Bindings" },
}

local sfSections = {}         -- ordered { title = , actions = { line, ... } }
local sfKnown    = {}         -- line -> true
local items      = {}         -- flat display list: {kind="header"|"row", ...}
local contentH   = 0
local scroll     = 0
local listDirty  = true

local edits      = {}         -- ordered { op = "bind"|"unbind", keyset = , action = }
local editedLine = {}         -- action line -> true, for highlighting

local capture    = nil        -- row currently awaiting a keypress
local confirm    = nil        -- { title, lines, onConfirm }
local status     = nil        -- { text, color, expires }

local barDrag    = false
local barDragOff = 0
local chobbyInterface = false

local MOD_KEYS = {
	alt = true, ctrl = true, meta = true, shift = true,
	lalt = true, ralt = true, lctrl = true, rctrl = true,
	lshift = true, rshift = true, lmeta = true, rmeta = true,
	super = true, lsuper = true, rsuper = true,
}

--------------------------------------------------------------------------------
-- Small helpers
--------------------------------------------------------------------------------

local function Clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

local function PlayHoverSound() spPlaySoundFile("hover",     1.0, "ui") end
local function PlayClickSound() spPlaySoundFile("leftclick", 1.0, "ui") end

local function InRect(x, y, r)
	return r and x >= r.x1 and x <= r.x2 and y >= r.y1 and y <= r.y2
end

local function IsOnPanel(x, y)
	return x >= panelRect.x1 and x <= panelRect.x2 and y >= panelRect.y1 and y <= panelRect.y2
end

local function GetBorderColor()
	if WG.guishader then return COL.borderGui end
	return COL.border
end

local function GetPanelBGColor()
	if WG.guishader then return COL.panelBgGui end
	return COL.panelBg
end

local function SetStatus(text, color)
	status = { text = text, color = color or COL.textDim, expires = os.clock() + STATUS_TIME }
end

local function Trim(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Action line as the engine stores it: command plus arguments
local function ActionLine(command, extra)
	if extra and extra ~= "" then
		return command .. " " .. extra
	end
	return command
end

--------------------------------------------------------------------------------
-- Drawing shim
--
-- Panel chrome used to be drawn with gl.Rect and gl.TexRect, which are OpenGL
-- 1.1 immediate mode: gl.Rect is glRectf and gl.TexRect is a raw
-- glBegin(GL_QUADS). One RectRound cost 7 glBegin/glEnd pairs and 2 texture
-- binds. None of that exists in OpenGL core profile, which is the only way
-- past GL 2.1 on macOS, and it is the worst case for any driver translating
-- GL to Metal or Vulkan.
--
-- Shapes now go through WG.StaticGUI (api_staticgui_shapes.lua), which batches
-- them into a single instanced draw call and rounds corners analytically in a
-- fragment shader rather than blitting a corner texture.
--
-- If that module is unavailable - old driver, shader compile failure - these
-- shims fall back to the original immediate-mode code. Slow, but not blank.
--------------------------------------------------------------------------------

local function LegacyRectRound(px, py, sx, sy, cs)
	px, py, sx, sy, cs = math_floor(px), math_floor(py), math_floor(sx), math_floor(sy), math_floor(cs)
	rawRect(px+cs, py, sx-cs, sy)
	rawRect(sx-cs, py+cs, sx, sy-cs)
	rawRect(px, py+cs, px+cs, sy-cs)
	rawTexture(bgcorner)
	rawTexRect(px, py+cs, px+cs, py)
	rawTexRect(sx, py+cs, sx-cs, py)
	rawTexRect(px, sy-cs, px+cs, sy)
	rawTexRect(sx, sy-cs, sx-cs, sy)
	rawTexture(false)
end

local function LegacyAccentStrip(x1, y1, x2, y2)
	rawTexture(accentImg)
	rawTexRect(x1, y1, x2, y2)
	rawTexture(false)
end

local function NoOp() end

local function BindDrawing()
	local SG = WG.StaticGUI
	if SG then
		glColor     = SG.Color
		glRect      = SG.Rect
		glTexture   = SG.Texture
		glTexRect   = SG.TexRect
		glScissor   = SG.Scissor
		RectRound   = SG.RectRound
		AccentStrip = SG.AccentStrip
		Flush       = SG.Flush
		usingShapes = true
	else
		glColor     = rawColor
		glRect      = rawRect
		glTexture   = rawTexture
		glTexRect   = rawTexRect
		glScissor   = rawScissor
		RectRound   = LegacyRectRound
		AccentStrip = LegacyAccentStrip
		Flush       = NoOp
		usingShapes = false
	end
end

BindDrawing()

local function DrawBox(x1, y1, x2, y2, c, cs)
	glColor(c[1], c[2], c[3], c[4])
	RectRound(x1, y1, x2, y2, (cs or 4) * uiScale)
end

local function DrawAccentStrip(x1, x2, yTop, accent)
	local ah = PANEL_ACCENT_HEIGHT * uiScale
	glColor(accent[1], accent[2], accent[3], 1)
	AccentStrip(x1, yTop - ah, x2, yTop)
end

local function TruncateToWidth(text, maxWidth, size)
	if font:GetTextWidth(text) * size <= maxWidth then return text end
	local lo, hi = 0, #text
	while lo < hi do
		local mid = math_floor((lo + hi + 1) / 2)
		if font:GetTextWidth(text:sub(1, mid) .. "...") * size <= maxWidth then
			lo = mid
		else
			hi = mid - 1
		end
	end
	if lo <= 0 then return "" end
	return text:sub(1, lo) .. "..."
end

--------------------------------------------------------------------------------
-- sf_keys.txt parsing (section titles + the action lines it binds)
--------------------------------------------------------------------------------

-- Strips "//" comments the same way the engine's line parser does
local function StripComment(line)
	local pos = line:find("//", 1, true)
	if pos then return line:sub(1, pos - 1) end
	return line
end

local function ParseGameKeysFile()
	sfSections = {}
	sfKnown    = {}

	local text = VFS.FileExists(GAME_KEYS_FILE) and VFS.LoadFile(GAME_KEYS_FILE)
	if not text then
		SetStatus("could not read " .. GAME_KEYS_FILE, COL.err)
		return
	end

	local sections   = {}
	local byTitle    = {}
	local current    = nil
	local prevText   = nil

	local function Section(title)
		if not byTitle[title] then
			byTitle[title] = { title = title, actions = {} }
			sections[#sections + 1] = byTitle[title]
		end
		return byTitle[title]
	end

	for raw in (text .. "\n"):gmatch("(.-)\r?\n") do
		local comment = raw:match("^%s*//%s*(.-)%s*$")
		if comment then
			-- "Title" followed by a "-----" rule marks a section header
			if comment:match("^%-%-%-+$") then
				if prevText and prevText ~= "" then
					current  = Section(prevText)
					prevText = nil
				end
			else
				prevText = comment
			end
		else
			local body = Trim(StripComment(raw))
			if body ~= "" then
				local verb, rest = body:match("^(%a+)%s+(.+)$")
				if verb and verb:lower() == "bind" then
					local keyset, action = rest:match("^(%S+)%s+(.+)$")
					if keyset and action then
						action = Trim(action)
						if not sfKnown[action] then
							sfKnown[action] = true
							local sec = current or Section("SF Keybinds")
							sec.actions[#sec.actions + 1] = action
						end
					end
				end
			end
		end
	end

	-- Drop headers that ended up with no bindings under them
	for i = 1, #sections do
		if #sections[i].actions > 0 then
			sfSections[#sfSections + 1] = sections[i]
		end
	end
end

--------------------------------------------------------------------------------
-- sf_uikeys.txt: the edit list is the file, the file is the edit list
--------------------------------------------------------------------------------

local FILE_HEADER = table.concat({
	"//",
	"//  Splinter Faction user keybindings",
	"//  Generated by the Static Keybinds widget -- edits made in-game land here.",
	"//",
	"//  Loaded after luaui/configs/sf_keys.txt, so unbind lines below can remove",
	"//  SF defaults and bind lines can replace them.",
	"//",
	"//  Hand edits survive as long as they use plain bind / unbind lines.",
	"//",
	"",
	"",
}, "\n")

local function RebuildEditedIndex()
	editedLine = {}
	for i = 1, #edits do
		editedLine[edits[i].action] = true
	end
end

local function LoadEdits()
	edits = {}

	local f = io.open(USER_KEYS_FILE, "r")
	if not f then
		RebuildEditedIndex()
		return
	end

	for raw in f:lines() do
		local body = Trim(StripComment(raw:gsub("\r", "")))
		if body ~= "" then
			local verb, rest = body:match("^(%a+)%s+(.+)$")
			if verb then
				verb = verb:lower()
				if verb == "bind" or verb == "unbind" then
					local keyset, action = rest:match("^(%S+)%s+(.+)$")
					if keyset and action then
						edits[#edits + 1] = { op = verb, keyset = keyset, action = Trim(action) }
					end
				end
			end
		end
	end
	f:close()

	RebuildEditedIndex()
end

local function SaveEdits()
	local f, err = io.open(USER_KEYS_FILE, "w")
	if not f then
		SetStatus("could not write " .. USER_KEYS_FILE .. (err and (": " .. tostring(err)) or ""), COL.err)
		return false
	end

	f:write(FILE_HEADER)
	for i = 1, #edits do
		local e = edits[i]
		f:write(string.format("%-7s %-20s %s\n", e.op, e.keyset, e.action))
	end
	f:close()
	return true
end

-- Records an edit and applies it live. Identical repeats are collapsed.
local function AddEdit(op, keyset, action)
	for i = 1, #edits do
		local e = edits[i]
		if e.op == op and e.keyset == keyset and e.action == action then
			table.remove(edits, i)
			break
		end
	end

	edits[#edits + 1] = { op = op, keyset = keyset, action = action }
	editedLine[action] = true
	spSendCommands(op .. " " .. keyset .. " " .. action)
end

--------------------------------------------------------------------------------
-- Live binding queries
--------------------------------------------------------------------------------

local function HotKeysFor(line)
	local keys = spGetActionHotKeys(line) or {}
	local out = {}
	for i = 1, #keys do out[i] = keys[i] end
	return out
end

-- Bindings already sitting on a keyset, excluding the action being rebound
local function GetConflicts(keyset, ownLine)
	local list = spGetKeyBindings(keyset)
	if not list then return {} end

	local out = {}
	for i = 1, #list do
		local b = list[i]
		if b.command then
			local line = ActionLine(b.command, b.extra)
			if line ~= ownLine then
				out[#out + 1] = { boundWith = b.boundWith or keyset, line = line }
			end
		end
	end
	return out
end

--------------------------------------------------------------------------------
-- Display list
--------------------------------------------------------------------------------

-- buildunit_kalfactory reads as noise in a list; show the unit's display name
-- alongside it so hotbound build buttons are recognisable.
local function PrettyLabel(line)
	local unitName = line:match("^buildunit_(.+)$")
	if unitName then
		local ud = UnitDefNames and UnitDefNames[unitName]
		local human = ud and (ud.translatedHumanName or ud.humanName)
		if human and human ~= "" then
			return human .. "   (" .. line .. ")"
		end
	end
	return line
end

local function AddRow(line, label)
	items[#items + 1] = {
		kind  = "row",
		line  = line,
		label = label or line,
		keys  = HotKeysFor(line),
	}
end

local function BuildList()
	items = {}

	if tab == "sf" then
		for i = 1, #sfSections do
			local sec = sfSections[i]
			items[#items + 1] = { kind = "header", label = sec.title }
			for j = 1, #sec.actions do
				AddRow(sec.actions[j])
			end
		end

		-- Runtime hotbinds live in sf_uikeys.txt but have no section in
		-- sf_keys.txt, so synthesize one for them. Walking the edit list is
		-- cheap and only happens when the panel is open and the list is dirty.
		local extra, seenExtra = {}, {}
		for i = 1, #edits do
			local e = edits[i]
			if e.op == "bind" and not sfKnown[e.action] and not seenExtra[e.action] then
				seenExtra[e.action] = true
				extra[#extra + 1] = e.action
			end
		end
		if #extra > 0 then
			table.sort(extra)
			items[#items + 1] = { kind = "header", label = "Hotbinds" }
			for i = 1, #extra do
				AddRow(extra[i], PrettyLabel(extra[i]))
			end
		end

		if #items == 0 then
			items[#items + 1] = { kind = "header", label = "no bindings found in sf_keys.txt" }
		end
	else
		local all = spGetKeyBindings() or {}
		local seen, rows = {}, {}
		for i = 1, #all do
			local b = all[i]
			if b.command then
				local line = ActionLine(b.command, b.extra)
				if not seen[line] then
					seen[line] = true
					rows[#rows + 1] = line
				end
			end
		end
		table.sort(rows)

		items[#items + 1] = { kind = "header", label = "All Bindings" }
		for i = 1, #rows do
			AddRow(rows[i])
		end
	end

	contentH  = ROW_H * uiScale * #items
	listDirty = false

	if geom.view then
		scroll = Clamp(scroll, 0, math_max(0, contentH - (geom.view.y2 - geom.view.y1)))
	end
end

local function RowAt(x, y)
	local v = geom.view
	if not InRect(x, y, v) then return nil end
	local rowH   = ROW_H * uiScale
	local relTop = (v.y2 + scroll) - y
	if relTop < 0 then return nil end
	local index = math_floor(relTop / rowH) + 1
	if index < 1 or index > #items then return nil end
	return items[index], index
end

--------------------------------------------------------------------------------
-- Geometry
--------------------------------------------------------------------------------

local FOOTER_BUTTONS = {}

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

local function BuildTabRects()
	local tr   = geom.tabs
	local gap  = 6 * uiScale
	local w    = (tr.x2 - tr.x1 - gap * (#TABS - 1)) / #TABS
	for i = 1, #TABS do
		local bx1 = tr.x1 + (i - 1) * (w + gap)
		TABS[i].rect = { x1 = bx1, y1 = tr.y1, x2 = bx1 + w, y2 = tr.y2 }
	end
end

local function BuildConfirmRects()
	if not confirm then return end

	local lines = #confirm.lines
	local bw = math_min(PANEL_WIDTH - 60, 460) * uiScale
	local bh = (74 + 16 * math_min(lines, CONFIRM_MAX) + 38) * uiScale

	local cx = (panelRect.x1 + panelRect.x2) * 0.5
	local cy = (panelRect.y1 + panelRect.y2) * 0.5
	local box = {
		x1 = math_floor(cx - bw * 0.5),
		y1 = math_floor(cy - bh * 0.5),
		x2 = math_floor(cx + bw * 0.5),
		y2 = math_floor(cy + bh * 0.5),
	}
	geom.confirmBox = box

	local pad  = 12 * uiScale
	local btnH = 26 * uiScale
	local btnW = (box.x2 - box.x1 - pad * 3) * 0.5
	geom.confirmOk = {
		x1 = box.x1 + pad, y1 = box.y1 + pad,
		x2 = box.x1 + pad + btnW, y2 = box.y1 + pad + btnH,
	}
	geom.confirmCancel = {
		x1 = box.x2 - pad - btnW, y1 = box.y1 + pad,
		x2 = box.x2 - pad, y2 = box.y1 + pad + btnH,
	}
end

--------------------------------------------------------------------------------
-- Layout (api_staticgui_layout.lua). The layout module owns this panel's origin
-- once the user has dragged it in tweak mode (Ctrl+F11); until then, and when
-- the module is absent, the default computed below is used unchanged.
--------------------------------------------------------------------------------

local LAYOUT_ID = "keybinds"

local function LayoutPlace(x1, y1, w, h)
	local L = WG.StaticLayout
	if L then return L.Place(LAYOUT_ID, x1, y1, w, h) end
	return x1, y1
end

local function BuildGeometry()
	uiScale = vsy / BASE_RESOLUTION

	local pw  = PANEL_WIDTH  * uiScale
	local ph  = PANEL_HEIGHT * uiScale
	local pad = INNER_PAD    * uiScale
	local acc = PANEL_ACCENT_HEIGHT * uiScale

	local x1 = math_floor(vsx * 0.5 - pw * 0.5)
	local y1 = math_floor(vsy * 0.5 - ph * 0.5)
	x1, y1 = LayoutPlace(x1, y1, math_floor(pw), math_floor(ph))
	panelRect = { x1 = x1, y1 = y1, x2 = x1 + math_floor(pw), y2 = y1 + math_floor(ph) }

	local cx1 = panelRect.x1 + pad
	local cx2 = panelRect.x2 - pad
	local cy1 = panelRect.y1 + pad
	local cy2 = panelRect.y2 - pad - acc

	local titleH  = TITLE_BAR_H * uiScale
	local titleY1 = cy2 - titleH
	geom.titleBar  = { x1 = cx1, y1 = titleY1, x2 = cx2, y2 = cy2 }
	geom.closeRect = { x1 = cx2 - titleH, y1 = titleY1, x2 = cx2, y2 = cy2 }

	local tabsY2 = titleY1 - SECTION_GAP * uiScale * 0.5
	local tabsY1 = tabsY2 - TAB_H * uiScale
	geom.tabs = { x1 = cx1, y1 = tabsY1, x2 = cx2, y2 = tabsY2 }
	BuildTabRects()

	local footerH  = FOOTER_H * uiScale
	geom.footer = { x1 = cx1, y1 = cy1, x2 = cx2, y2 = cy1 + footerH }
	BuildFooterRects()

	local statusY1 = geom.footer.y2 + SECTION_GAP * uiScale * 0.5
	geom.status = { x1 = cx1, y1 = statusY1, x2 = cx2, y2 = statusY1 + STATUS_H * uiScale }

	local viewY2 = tabsY1 - SECTION_GAP * uiScale
	local viewY1 = geom.status.y2 + SECTION_GAP * uiScale * 0.5
	local barW   = SCROLLBAR_W * uiScale
	geom.view = { x1 = cx1, y1 = viewY1, x2 = cx2 - barW - 4 * uiScale, y2 = viewY2 }
	geom.bar  = { x1 = cx2 - barW, y1 = viewY1, x2 = cx2, y2 = viewY2 }

	geom.textX  = geom.view.x1 + TEXT_PAD * uiScale
	geom.badgeX = geom.view.x2 - TEXT_PAD * uiScale - BADGE_W * uiScale

	BuildConfirmRects()

	if contentH > 0 then
		scroll = Clamp(scroll, 0, math_max(0, contentH - (viewY2 - viewY1)))
	end
end

--------------------------------------------------------------------------------
-- Rebinding
--------------------------------------------------------------------------------

local function KeysetFromKey(key, mods)
	local sym = spGetKeySymbol(key)
	if not sym or sym == "" or MOD_KEYS[sym] then return nil end

	local prefix = ""
	if mods.alt   then prefix = prefix .. "Alt+"   end
	if mods.ctrl  then prefix = prefix .. "Ctrl+"  end
	if mods.meta  then prefix = prefix .. "Meta+"  end
	if mods.shift then prefix = prefix .. "Shift+" end
	return prefix .. sym
end

local function ApplyRebind(row, keyset, conflicts)
	for i = 1, #row.keys do
		AddEdit("unbind", row.keys[i], row.line)
	end
	for i = 1, #conflicts do
		AddEdit("unbind", conflicts[i].boundWith, conflicts[i].line)
	end
	AddEdit("bind", keyset, row.line)

	SaveEdits()
	listDirty = true
	SetStatus(keyset .. "  ->  " .. row.line, COL.ok)
end

local function ClearBinding(row)
	if #row.keys == 0 then
		SetStatus(row.line .. " is not bound", COL.textDim)
		return
	end
	for i = 1, #row.keys do
		AddEdit("unbind", row.keys[i], row.line)
	end
	SaveEdits()
	listDirty = true
	SetStatus("unbound " .. row.line, COL.warn)
end

local function OpenConfirm(title, lines, onConfirm)
	confirm = { title = title, lines = lines, onConfirm = onConfirm }
	BuildConfirmRects()
end

local function BeginCapture(row)
	capture = row
	confirm = nil
	SetStatus("press a key for " .. row.line .. "  (Esc cancels)", COL.text)
end

local function FinishCapture(keyset)
	local row = capture
	capture = nil
	if not row then return end

	local conflicts = GetConflicts(keyset, row.line)
	if #conflicts == 0 then
		ApplyRebind(row, keyset, conflicts)
		return
	end

	local lines = {}
	for i = 1, math_min(#conflicts, CONFIRM_MAX) do
		lines[#lines + 1] = conflicts[i].boundWith .. "   " .. conflicts[i].line
	end
	if #conflicts > CONFIRM_MAX then
		lines[#lines + 1] = "... and " .. (#conflicts - CONFIRM_MAX) .. " more"
	end

	OpenConfirm(keyset .. " is already bound to:", lines, function()
		ApplyRebind(row, keyset, conflicts)
	end)
end

local function ReapplyKeys()
	if WG.SFKeybindings and WG.SFKeybindings.Apply then
		WG.SFKeybindings.Apply()
	else
		spSendCommands("keyload " .. GAME_KEYS_FILE)
		spSendCommands("keyload " .. USER_KEYS_FILE)
	end
	listDirty = true
	SetStatus("keybind files reloaded", COL.ok)
end

local function ResetAll()
	edits = {}
	editedLine = {}
	SaveEdits()

	-- Back to engine defaults + the user's uikeys.txt, then SF defaults on top
	spSendCommands("keyreload")
	ReapplyKeys()

	listDirty = true
	SetStatus("all rebinds cleared", COL.warn)
end

--------------------------------------------------------------------------------
-- Public API  (exported as WG.StaticKeybinds in Initialize)
--
-- sf_uikeys.txt has exactly one writer: this widget. Anything that wants to
-- change a binding at runtime -- the hotbind widget, for instance -- goes
-- through here rather than opening the file itself, so that every change lands
-- in the same in-memory edit list, gets the same conflict handling, shows up in
-- the panel, and is cleared correctly by Reset All Rebinds.
--------------------------------------------------------------------------------

-- Binds action to keyset, taking the key away from whatever already holds it.
-- Returns ok, displaced -- where displaced is an array of { boundWith, line }
-- describing what was unbound to make room.
local function API_Bind(action, keyset)
	if type(action) ~= "string" or type(keyset) ~= "string" then return false end
	action, keyset = Trim(action), Trim(keyset)
	if action == "" or keyset == "" then return false end

	local conflicts = GetConflicts(keyset, action)
	ApplyRebind({ line = action, keys = HotKeysFor(action) }, keyset, conflicts)
	return true, conflicts
end

-- Removes every key currently bound to action. Returns ok, removedKeysets.
local function API_Unbind(action)
	if type(action) ~= "string" then return false end
	action = Trim(action)
	if action == "" then return false end

	local keys = HotKeysFor(action)
	if #keys == 0 then return false end

	ClearBinding({ line = action, keys = keys })
	return true, keys
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------

local function DrawPanelChrome()
	local bc, pc = GetBorderColor(), GetPanelBGColor()
	local ins = INNER_INSET * uiScale
	glColor(bc[1], bc[2], bc[3], bc[4])
	RectRound(panelRect.x1, panelRect.y1, panelRect.x2, panelRect.y2, OUTER_CORNER * uiScale)
	glColor(pc[1], pc[2], pc[3], pc[4])
	RectRound(panelRect.x1+ins, panelRect.y1+ins, panelRect.x2-ins, panelRect.y2-ins, INNER_CORNER * uiScale)
	DrawAccentStrip(panelRect.x1+ins, panelRect.x2-ins, panelRect.y2-ins, COL.accentPanel)
end

local function DrawTitle()
	local tb = geom.titleBar
	DrawBox(tb.x1, tb.y1, tb.x2, tb.y2, COL.categoryBg, 4)
	font:Begin()
	font:SetTextColor(1, 1, 1, 1)
	font:Print(TAG_TEXT .. "Keybindings", tb.x1 + 8*uiScale, tb.y1 + (tb.y2-tb.y1)*0.5 - 6*uiScale, 16*uiScale, "lo")
	font:End()

	local cr = geom.closeRect
	DrawBox(cr.x1, cr.y1, cr.x2, cr.y2, COL.categoryBg, 4)
	DrawAccentStrip(cr.x1, cr.x2, cr.y2, COL.accentClose)
	font:Begin()
	font:SetTextColor(1, 1, 1, 1)
	font:Print(TAG_TEXT .. "x", cr.x1+(cr.x2-cr.x1)*0.5, cr.y1+(cr.y2-cr.y1)*0.5-6*uiScale, 15*uiScale, "co")
	font:End()
end

local function DrawTabs(mx, my)
	for i = 1, #TABS do
		local t = TABS[i]
		local r = t.rect
		DrawBox(r.x1, r.y1, r.x2, r.y2, COL.categoryBg, 4)
		if tab == t.id then
			DrawAccentStrip(r.x1, r.x2, r.y2, COL.accentTab)
		end
		if InRect(mx, my, r) then
			glColor(COL.hover[1], COL.hover[2], COL.hover[3], COL.hover[4])
			RectRound(r.x1, r.y1, r.x2, r.y2, 4*uiScale)
		end
		font:Begin()
		local c = (tab == t.id) and COL.text or COL.textDim
		font:SetTextColor(c[1], c[2], c[3], c[4])
		font:Print(t.label, r.x1+(r.x2-r.x1)*0.5, r.y1+(r.y2-r.y1)*0.5-4.5*uiScale, 12*uiScale, "co")
		font:End()
	end
end

local function DrawFooterButtons(mx, my)
	for i = 1, #FOOTER_BUTTONS do
		local b = FOOTER_BUTTONS[i]
		local r = b.rect
		DrawBox(r.x1, r.y1, r.x2, r.y2, COL.categoryBg, 4)
		DrawAccentStrip(r.x1, r.x2, r.y2, b.accent)
		if InRect(mx, my, r) then
			glColor(COL.hover[1], COL.hover[2], COL.hover[3], COL.hover[4])
			RectRound(r.x1, r.y1, r.x2, r.y2, 4*uiScale)
		end
		font:Begin()
		font:SetTextColor(1, 1, 1, 1)
		font:Print(TAG_TEXT .. b.label, r.x1+(r.x2-r.x1)*0.5, r.y1+(r.y2-r.y1)*0.5-5*uiScale, 12*uiScale, "co")
		font:End()
	end
end

local function DrawStatus()
	local s = geom.status
	local text, col

	if status and os.clock() < status.expires then
		text, col = status.text, status.color
	else
		status = nil
		text = "LMB rebind    RMB unbind    written to " .. USER_KEYS_FILE
		col  = COL.textDim
	end

	font:Begin()
	font:SetTextColor(col[1], col[2], col[3], col[4])
	font:Print(TruncateToWidth(text, s.x2 - s.x1, 11*uiScale), s.x1 + 2*uiScale,
		s.y1 + (s.y2 - s.y1)*0.5 - 4*uiScale, 11*uiScale, "o")
	font:End()
end

local function DrawList(mx, my)
	local v = geom.view
	DrawBox(v.x1, v.y1, v.x2, v.y2, COL.viewBg, 4)

	local rowH = ROW_H * uiScale
	local hoverEntry, hoverIndex = RowAt(mx, my)
	if capture or confirm then hoverEntry = nil end

	glScissor(math_floor(v.x1), math_floor(v.y1), math_floor(v.x2 - v.x1), math_floor(v.y2 - v.y1))

	if hoverEntry and hoverEntry.kind == "row" and not barDrag then
		local rowY2 = v.y2 + scroll - (hoverIndex - 1) * rowH
		glColor(COL.hover[1], COL.hover[2], COL.hover[3], COL.hover[4])
		glRect(v.x1, math_max(rowY2 - rowH, v.y1), v.x2, math_min(rowY2, v.y2))
	end

	-- Badge backgrounds first, so text lands on top
	local badgeW, badgeH = BADGE_W * uiScale, BADGE_H * uiScale
	for i = 1, #items do
		local it = items[i]
		local rowY2 = v.y2 + scroll - (i - 1) * rowH
		local rowY1 = rowY2 - rowH
		if it.kind == "row" and rowY2 >= v.y1 - rowH and rowY1 <= v.y2 + rowH then
			local hot = (capture == it)
			local c = hot and COL.badgeBgHot or COL.badgeBg
			glColor(c[1], c[2], c[3], c[4])
			local by = rowY1 + (rowH - badgeH) * 0.5
			glRect(geom.badgeX, by, geom.badgeX + badgeW, by + badgeH)
		end
	end

	local fs = 12 * uiScale
	font:Begin()
	for i = 1, #items do
		local it = items[i]
		local rowY2 = v.y2 + scroll - (i - 1) * rowH
		local rowY1 = rowY2 - rowH
		if rowY2 >= v.y1 - rowH and rowY1 <= v.y2 + rowH then
			if it.kind == "header" then
				font:SetTextColor(COL.textHeader[1], COL.textHeader[2], COL.textHeader[3], 1)
				font:Print(string.upper(it.label), geom.textX, rowY1 + (rowH - fs)*0.5 + 1*uiScale, fs*0.85, "o")
			else
				local maxTextW = (geom.badgeX - 8*uiScale) - geom.textX
				local tc = editedLine[it.line] and COL.keyEdited or COL.text
				font:SetTextColor(tc[1], tc[2], tc[3], tc[4])
				font:Print(TruncateToWidth(it.label, maxTextW, fs), geom.textX,
					rowY1 + (rowH - fs)*0.5 + 1*uiScale, fs, "o")

				local keyText, kc
				if capture == it then
					keyText, kc = "press a key...", COL.warn
				elseif #it.keys == 0 then
					keyText, kc = "unbound", COL.keyUnbound
				else
					keyText, kc = table.concat(it.keys, ", "), COL.keyBound
				end
				font:SetTextColor(kc[1], kc[2], kc[3], kc[4])
				font:Print(TruncateToWidth(keyText, badgeW - 8*uiScale, fs*0.92),
					geom.badgeX + badgeW*0.5, rowY1 + (rowH - fs*0.92)*0.5 + 1*uiScale, fs*0.92, "co")
			end
		end
	end
	font:End()

	glScissor(false)
end

local function DrawScrollbar(mx, my)
	local bar   = geom.bar
	local viewH = geom.view.y2 - geom.view.y1
	glColor(COL.scrollBg[1], COL.scrollBg[2], COL.scrollBg[3], COL.scrollBg[4])
	glRect(bar.x1, bar.y1, bar.x2, bar.y2)
	if contentH <= viewH then return end

	local trackH = bar.y2 - bar.y1
	local thumbH = math_max(24*uiScale, trackH * (viewH / contentH))
	local range  = trackH - thumbH
	local frac   = Clamp(scroll / math_max(1, contentH - viewH), 0, 1)
	local ty2    = bar.y2 - range * frac
	local hov    = InRect(mx, my, bar) or barDrag
	local tc     = hov and COL.scrollThumbH or COL.scrollThumb
	glColor(tc[1], tc[2], tc[3], tc[4])
	glRect(bar.x1, ty2 - thumbH, bar.x2, ty2)
end

local function DrawConfirm(mx, my)
	glColor(COL.dimmer[1], COL.dimmer[2], COL.dimmer[3], COL.dimmer[4])
	RectRound(panelRect.x1, panelRect.y1, panelRect.x2, panelRect.y2, OUTER_CORNER * uiScale)

	local box = geom.confirmBox
	DrawBox(box.x1, box.y1, box.x2, box.y2, COL.border, 6)
	DrawBox(box.x1+2*uiScale, box.y1+2*uiScale, box.x2-2*uiScale, box.y2-2*uiScale, COL.dialogBg, 5)
	DrawAccentStrip(box.x1+2*uiScale, box.x2-2*uiScale, box.y2-2*uiScale, COL.accentWarn)

	local pad = 12 * uiScale
	local y   = box.y2 - pad - 14*uiScale

	font:Begin()
	font:SetTextColor(COL.text[1], COL.text[2], COL.text[3], 1)
	font:Print(TruncateToWidth(confirm.title, box.x2-box.x1-pad*2, 13*uiScale),
		box.x1 + pad, y, 13*uiScale, "o")
	y = y - 18*uiScale

	font:SetTextColor(COL.warn[1], COL.warn[2], COL.warn[3], 1)
	for i = 1, #confirm.lines do
		font:Print(TruncateToWidth(confirm.lines[i], box.x2-box.x1-pad*2, 11.5*uiScale),
			box.x1 + pad + 6*uiScale, y, 11.5*uiScale, "o")
		y = y - 16*uiScale
	end

	font:SetTextColor(COL.textDim[1], COL.textDim[2], COL.textDim[3], 1)
	font:Print("Confirming will unbind the actions listed above.",
		box.x1 + pad, y - 4*uiScale, 11*uiScale, "o")
	font:End()

	local okR, caR = geom.confirmOk, geom.confirmCancel
	DrawBox(okR.x1, okR.y1, okR.x2, okR.y2, COL.categoryBg, 4)
	DrawAccentStrip(okR.x1, okR.x2, okR.y2, COL.accentOk)
	DrawBox(caR.x1, caR.y1, caR.x2, caR.y2, COL.categoryBg, 4)
	DrawAccentStrip(caR.x1, caR.x2, caR.y2, COL.accentClose)

	for _, r in ipairs({okR, caR}) do
		if InRect(mx, my, r) then
			glColor(COL.hover[1], COL.hover[2], COL.hover[3], COL.hover[4])
			RectRound(r.x1, r.y1, r.x2, r.y2, 4*uiScale)
		end
	end

	font:Begin()
	font:SetTextColor(1, 1, 1, 1)
	font:Print(TAG_TEXT .. "Confirm", okR.x1+(okR.x2-okR.x1)*0.5, okR.y1+(okR.y2-okR.y1)*0.5-5*uiScale, 12*uiScale, "co")
	font:Print(TAG_TEXT .. "Cancel",  caR.x1+(caR.x2-caR.x1)*0.5, caR.y1+(caR.y2-caR.y1)*0.5-5*uiScale, 12*uiScale, "co")
	font:End()
end

--------------------------------------------------------------------------------
-- Open / Close
--------------------------------------------------------------------------------

local function Open()
	if isOpen then return end
	isOpen  = true
	capture = nil
	confirm = nil
	LoadEdits()
	ParseGameKeysFile()
	BuildGeometry()
	listDirty = true
	PlayClickSound()
end

local function Close()
	if not isOpen then return end
	isOpen  = false
	capture = nil
	confirm = nil
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
	if not isOpen then return false end

	local sym = spGetKeySymbol(key)

	if capture then
		if sym == "esc" or sym == "escape" then
			capture = nil
			SetStatus("rebind cancelled", COL.textDim)
			return true
		end
		if isRepeat then return true end

		local keyset = KeysetFromKey(key, mods)
		if keyset then
			FinishCapture(keyset)
		end
		return true   -- swallow everything while capturing
	end

	if sym == "esc" or sym == "escape" then
		if confirm then
			confirm = nil
		else
			Close()
		end
		return true
	end

	if confirm then return true end

	if sym == "pageup" or sym == "pagedown" then
		local viewH = geom.view.y2 - geom.view.y1
		local dir   = (sym == "pageup") and -1 or 1
		scroll = Clamp(scroll + dir * viewH, 0, math_max(0, contentH - viewH))
		return true
	end

	return false
end

function widget:IsAbove(x, y)
	return isOpen and IsOnPanel(x, y)
end

function widget:MousePress(x, y, button)
	if chobbyInterface or spIsGUIHidden() or not isOpen then return false end

	if confirm then return true end

	if capture then
		capture = nil
		SetStatus("rebind cancelled", COL.textDim)
		return true
	end

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
			barDrag    = true
			barDragOff = (bar.y2 - range * frac) - y
			return true
		end
	end

	return true
end

function widget:MouseRelease(x, y, button)
	if not isOpen then return false end

	if confirm then
		if button == 1 then
			if InRect(x, y, geom.confirmOk) then
				PlayClickSound()
				local fn = confirm.onConfirm
				confirm = nil
				if fn then fn() end
				return true
			end
			if InRect(x, y, geom.confirmCancel) then
				PlayClickSound()
				confirm = nil
				SetStatus("cancelled", COL.textDim)
				return true
			end
		end
		return true
	end

	if barDrag then barDrag = false ; return true end
	if not IsOnPanel(x, y) then return false end

	if button == 1 then
		if InRect(x, y, geom.closeRect) then
			PlayClickSound()
			Close()
			return true
		end
		for i = 1, #TABS do
			if InRect(x, y, TABS[i].rect) then
				if tab ~= TABS[i].id then
					tab       = TABS[i].id
					scroll    = 0
					listDirty = true
				end
				PlayClickSound()
				return true
			end
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
	if entry and entry.kind == "row" then
		if button == 1 then
			PlayClickSound()
			BeginCapture(entry)
		elseif button == 3 then
			PlayClickSound()
			ClearBinding(entry)
		end
		return true
	end

	return true
end

function widget:MouseMove(x, y, dx, dy, button)
	if not isOpen or not barDrag then return false end

	local bar   = geom.bar
	local viewH = geom.view.y2 - geom.view.y1
	if contentH <= viewH then return true end

	local trackH = bar.y2 - bar.y1
	local thumbH = math_max(24*uiScale, trackH * (viewH / contentH))
	local range  = trackH - thumbH
	if range > 0 then
		local ty2  = Clamp(y + barDragOff, bar.y1 + thumbH, bar.y2)
		scroll = Clamp(((bar.y2 - ty2) / range) * (contentH - viewH), 0, contentH - viewH)
	end
	return true
end

function widget:MouseWheel(up, value)
	if not isOpen then return false end
	if capture or confirm then return true end

	local a, c, m, s = spGetModKeyState()
	if a or m then return false end

	local mx, my = spGetMouseState()
	if not InRect(mx, my, geom.view) and not InRect(mx, my, geom.bar) then return false end

	local viewH = geom.view.y2 - geom.view.y1
	if contentH <= viewH then return true end
	local step = (s and 4 or (c and 1 or 2)) * ROW_H * uiScale
	scroll = Clamp(scroll + (up and -step or step), 0, contentH - viewH)
	return true
end

function widget:TextCommand(cmd)
	if cmd == "keybinds" then
		Toggle()
		return true
	end
	return false
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1, 19) == 'LobbyOverlayActive1')
	end
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function widget:DrawScreen()
	if chobbyInterface or spIsGUIHidden() or not isOpen or not font then return end

	if listDirty then BuildList() end

	local mx, my = spGetMouseState()

	DrawPanelChrome()
	DrawTitle()
	DrawTabs(mx, my)
	DrawList(mx, my)
	DrawScrollbar(mx, my)
	DrawStatus()
	DrawFooterButtons(mx, my)

	if confirm then DrawConfirm(mx, my) end

	glColor(1, 1, 1, 1)

	-- Hand the accumulated shape instances to the GPU.
	Flush()
end

function widget:Initialize()
	-- Resolve the shapes module now that every widget has been constructed.
	BindDrawing()

	if WG.SFKeybindings then
		GAME_KEYS_FILE = WG.SFKeybindings.gameFile or GAME_KEYS_FILE
		USER_KEYS_FILE = WG.SFKeybindings.userFile or USER_KEYS_FILE
	end

	vsx, vsy = spGetViewGeometry()
	fontfileScale = (0.5 + (vsx * vsy / 5700000))
	font = WrapFont(gl.LoadFont(fontfile, 23*fontfileScale, 5*fontfileScale, 1.8))

	FOOTER_BUTTONS = {
		{ label = "Reapply Key Files", accent = COL.accentPanel, onClick = ReapplyKeys },
		{
			label = "Reset All Rebinds",
			accent = COL.accentWarn,
			onClick = function()
				if #edits == 0 then
					SetStatus("no rebinds to clear", COL.textDim)
					return
				end
				OpenConfirm("Clear all " .. #edits .. " rebinds from " .. USER_KEYS_FILE .. "?", {
					"Keys return to SF defaults plus your uikeys.txt.",
				}, ResetAll)
			end,
		},
	}

	LoadEdits()
	ParseGameKeysFile()
	BuildGeometry()

	WG.StaticKeybinds = {
		Toggle     = Toggle,
		Show       = Open,
		Hide       = Close,
		IsOpen     = function() return isOpen end,

		-- Runtime binding API. See the Public API section above.
		Bind       = API_Bind,
		Unbind     = API_Unbind,
		GetHotKeys = HotKeysFor,
		UserFile   = function() return USER_KEYS_FILE end,
	}

	if WG.StaticLayout then
		WG.StaticLayout.Register(LAYOUT_ID, {
			label  = "Keybinds",
			onMove = function() widget:ViewResize(vsx, vsy) end,
			isVisible = function() return isOpen end,
		})
	end
end

function widget:Shutdown()
	if WG.StaticLayout then WG.StaticLayout.Unregister(LAYOUT_ID) end
	if font then ReleaseFont(font) end
	WG.StaticKeybinds = nil
end

function widget:ViewResize(nx, ny)
	vsx, vsy = nx, ny
	local newScale = (0.5 + (vsx * vsy / 5700000))
	if newScale ~= fontfileScale then
		fontfileScale = newScale
		if font then ReleaseFont(font) end
		font = WrapFont(gl.LoadFont(fontfile, 23*fontfileScale, 5*fontfileScale, 1.8))
	end
	BuildGeometry()
	listDirty = true
end

function widget:GetConfigData()
	return { tab = tab }
end

function widget:SetConfigData(data)
	if data and data.tab then
		tab = data.tab
	end
end
