function widget:GetInfo()
	return {
		name      = "Static Options",
		desc      = "Options panel in the Static GUI style. Options are declared as data in LuaUI/configs/options/*.lua; this widget only renders and applies them.",
		author    = "Scary le Poo",
		date      = "2026-09-27",
		license   = "GNU GPL, v2 or later",
		layer     = -10000,   -- DrawScreen runs in reverse layer order: this must be lower than every panel it should cover (widget selector stays on top at -math.huge)
		handler   = true,     -- needs widgetHandler for widget toggles and configData
		enabled   = true,
	}
end

--------------------------------------------------------------------------------
--
-- HOW OPTIONS ARE DEFINED
--
-- Every file in LuaUI/configs/options/ is one tab. A file returns:
--
--     return {
--         id = "gfx", name = "Graphics", order = 10,
--         options = { ... },
--     }
--
-- Each entry in `options` is ONE table that fully describes an option: what
-- it is called, what control it uses, and how its value is read and written.
-- Nothing else in this widget needs to change when an option is added.
--
--   Control types
--     "bool"       on/off toggle
--     "slider"     numeric; give min/max/step, or steps={...} for a fixed list
--     "select"     dropdown; give options={"a","b",...} and optionally
--                  values={...} for the underlying value each choice maps to
--                  (defaults to the 1-based index)
--     "action"     a button; give set=function() end
--     "separator"  a heading line; no value. Give name="..."
--
--   Value plumbing (use whichever fit; several may be combined)
--     config="Key"          engine config var. configType="int"|"float"|"string"
--                           is inferred when omitted (bool -> int, slider -> int
--                           unless min/max/step has a fraction, select -> int)
--     cmd="vsync %d"        engine command sent after a change, formatted with
--                           the underlying value. May be a table of strings.
--     widget="Name"         (bool) enables/disables that widget
--     api={"ns","get","set"} calls WG.ns.get() / WG.ns.set(v) when present;
--                           either name may be nil
--     configVar={"Widget Name","key"[,"subkey"]}
--                           reads/writes widgetHandler.configData so a widget
--                           picks the value up next load even if it is off now
--     store=true            the value lives in this widget's own config
--     get=function() end    fully custom read (returns the option's value)
--     set=function(v) end   fully custom write (replaces every writer above)
--     default=...           value used when nothing else can supply one
--
--   Misc
--     desc="..."            tooltip
--     restart=true          flags the footer "some changes need a restart"
--     reloadUI=true         reloads LuaUI after the change is applied
--     applyOnRelease=true   (slider) only write once the mouse is released
--     transient=true        (select) does not display a current value; used
--                           for one-shot choices like presets
--     requires="Name"       hidden unless that widget exists in knownWidgets
--     showIf=function() end hidden while it returns false
--     children={...}        nested options, indented and only shown while the
--                           parent is on (bool) / always (other types)
--     format="%d%%"         (slider) value display format
--     onSet=function(v) end hook run after the value has been applied
--
-- Definition files also get an `OPT` helper table:
--     OPT.get(id), OPT.set(id, v), OPT.widgetActive(name),
--     OPT.getConfigInt/Float/String(key, default)
--
-- Other widgets can register options at runtime with
--     WG.options.register(tabId, optionTable [, afterId])
--
--------------------------------------------------------------------------------

include("keysym.h.lua")

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

local OPTIONS_DIR = "LuaUI/configs/options/"

local bgcorner  = "LuaUI/Images/bgcorner.png"
local accentImg = ":n:LuaUI/Images/staticgui_accent.png"

local BASE_RESOLUTION     = 1080
local PANEL_WIDTH         = 780
local PANEL_HEIGHT        = 660
local OUTER_CORNER        = 10
local INNER_CORNER        = 8.5
local INNER_INSET         = 2.25
local PANEL_ACCENT_HEIGHT = 5

local INNER_PAD     = 12
local TITLE_BAR_H   = 30
local TAB_H         = 26
local FOOTER_H      = 22
local SECTION_GAP   = 8
local ROW_H         = 26
local SEP_H         = 32
local CHILD_INDENT  = 18
local SCROLLBAR_W   = 8
local TEXT_PAD      = 10
local LABEL_FRAC    = 0.46     -- label column share of the row width
local CONTROL_PAD   = 8

local TOGGLE_W      = 36
local TOGGLE_H      = 16
local SLIDER_H      = 4
local KNOB_R        = 6
local VALUE_W       = 58       -- width reserved for the slider value text
local SELECT_H      = 20
local DROP_ROW_H    = 22
local DROP_MAX_ROWS = 12

--------------------------------------------------------------------------------
-- Theme
--------------------------------------------------------------------------------

local COL = {
	border       = {0.15, 0.15, 0.15, 0.90},
	panelBg      = {0.05, 0.05, 0.06, 0.92},
	panelBgGui   = {0.00, 0.00, 0.00, 0.28},
	categoryBg   = {0.20, 0.20, 0.21, 0.55},
	viewBg       = {0.02, 0.02, 0.03, 0.55},
	hover        = {0.90, 0.90, 0.90, 0.08},
	scrollBg     = {1.00, 1.00, 1.00, 0.06},
	scrollThumb  = {1.00, 1.00, 1.00, 0.22},
	scrollThumbH = {1.00, 1.00, 1.00, 0.35},
	sepLine      = {1.00, 1.00, 1.00, 0.10},
	childLine    = {1.00, 1.00, 1.00, 0.07},
	dropBg       = {0.07, 0.07, 0.09, 0.98},

	toggleOff    = {0.30, 0.31, 0.34, 0.90},
	toggleOn     = {0.22, 0.78, 0.35, 0.95},
	toggleHalf   = {0.95, 0.65, 0.18, 0.95},   -- enabled but not active
	knob         = {0.96, 0.96, 0.96, 1.00},
	track        = {1.00, 1.00, 1.00, 0.14},
	trackFill    = {0.18, 0.52, 0.98, 0.95},
	selectBg     = {0.12, 0.12, 0.14, 0.90},
	selectBgHot  = {0.18, 0.18, 0.21, 0.95},
	buttonBg     = {0.20, 0.20, 0.24, 0.85},

	accentPanel  = {0.18, 0.52, 0.98, 1},
	accentClose  = {0.90, 0.22, 0.22, 1},
	accentTab    = {0.20, 0.75, 0.80, 1},
	accentWarn   = {0.95, 0.65, 0.18, 1},

	text         = {0.96, 0.96, 0.96, 1},
	textDim      = {0.62, 0.64, 0.67, 1},
	textHeader   = {0.55, 0.72, 0.95, 1},
	textDisabled = {0.45, 0.46, 0.48, 1},
	warn         = {0.95, 0.65, 0.18, 1},
}

local STR_WHITE = "\255\244\244\244"
local STR_DIM   = "\255\160\162\166"
local STR_WARN  = "\255\240\165\045"

--------------------------------------------------------------------------------
-- Speedups
--------------------------------------------------------------------------------

local rawColor    = gl.Color
local rawRect     = gl.Rect
local rawTexture  = gl.Texture
local rawTexRect  = gl.TexRect
local rawScissor  = gl.Scissor

local glColor, glRect, glTexture, glTexRect, glScissor
local RectRound, AccentStrip, Flush, LineSegment
local usingShapes = false

local spGetViewGeometry = Spring.GetViewGeometry
local spGetMouseState   = Spring.GetMouseState
local spPlaySoundFile   = Spring.PlaySoundFile
local spIsGUIHidden     = Spring.IsGUIHidden
local spGetModKeyState  = Spring.GetModKeyState
local spSendCommands    = Spring.SendCommands
local spEcho            = Spring.Echo
local spGetConfigInt    = Spring.GetConfigInt
local spGetConfigFloat  = Spring.GetConfigFloat
local spGetConfigString = Spring.GetConfigString
local spSetConfigInt    = Spring.SetConfigInt
local spSetConfigFloat  = Spring.SetConfigFloat
local spSetConfigString = Spring.SetConfigString

local math_floor = math.floor
local math_max   = math.max
local math_min   = math.min
local math_abs   = math.abs

local BuildTabRects   -- defined in the Geometry section, used by the registry above it

local function Clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

local function InRect(x, y, r)
	return r and x >= r.x1 and x <= r.x2 and y >= r.y1 and y <= r.y2
end

local function Round(v, step)
	if not step or step <= 0 then return v end
	local r = math_floor(v / step + 0.5) * step
	-- kill float noise like 0.30000000000000004
	local decimals = 0
	local s = step
	while s < 1 and decimals < 6 do s = s * 10; decimals = decimals + 1 end
	local mult = 10 ^ decimals
	return math_floor(r * mult + 0.5) / mult
end

--------------------------------------------------------------------------------
-- Font
--------------------------------------------------------------------------------

local vsx, vsy      = spGetViewGeometry()
local uiScale       = 1.0
local fontfile      = LUAUI_DIRNAME .. "fonts/" .. spGetConfigString("ui_font", "Saira_SemiCondensed-SemiBold.ttf")
local fontfileScale = (0.5 + (vsx * vsy / 5700000))
local font

local function WrapFont(f)
	local SG = WG.StaticGUI
	if f and SG and SG.WrapFont then return SG.WrapFont(f) end
	return f
end

local function ReleaseFont(f)
	if not f then return end
	local SG = WG.StaticGUI
	if SG and SG.DeleteFont then SG.DeleteFont(f) else gl.DeleteFont(f) end
end

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local isOpen     = false
local panelRect  = {x1=0, y1=0, x2=0, y2=0}
local geom       = {}

local tabs       = {}      -- ordered list of {id, name, order, options}
local tabById    = {}
local optById    = {}      -- id -> option table (all tabs)
local currentTab = nil

local rows       = {}      -- flat, visible rows of the current tab
local rowsDirty  = true
local contentH   = 0
local scroll     = 0

local barDrag    = false
local barDragOff = 0

local dragOpt    = nil     -- slider being dragged
local dragRect   = nil
local dragChanged = false

local dropOpt    = nil     -- select whose dropdown is open
local dropRect   = nil
local dropRows   = nil     -- {rect, index} for each dropdown row

local store      = {}      -- own persisted values (store=true options)
local changesRequireRestart = false
local chobbyInterface = false
local pendingReload = false

local lastKnownWidgets = 0

--------------------------------------------------------------------------------
-- Sound
--------------------------------------------------------------------------------

local function PlayClickSound()  spPlaySoundFile("leftclick", 0.8, "ui") end
local function PlayToggleSound() spPlaySoundFile("leftclick", 0.6, "ui") end

--------------------------------------------------------------------------------
-- Drawing shim (see api_staticgui_shapes.lua)
--------------------------------------------------------------------------------

local function LegacyRectRound(px, py, sx, sy, cs)
	px, py, sx, sy, cs = math_floor(px), math_floor(py), math_floor(sx), math_floor(sy), math_floor(cs)
	rawRect(px+cs, py, sx-cs, sy)
	rawRect(sx-cs, py+cs, sx, sy-cs)
	rawRect(px, py+cs, px+cs, sy-cs)
	rawTexture(bgcorner)
	rawTexRect(px,    py+cs, px+cs, py)
	rawTexRect(sx,    py+cs, sx-cs, py)
	rawTexRect(px,    sy-cs, px+cs, sy)
	rawTexRect(sx,    sy-cs, sx-cs, sy)
	rawTexture(false)
end

local function LegacyAccentStrip(x1, y1, x2, y2)
	rawTexture(accentImg)
	rawTexRect(x1, y1, x2, y2)
	rawTexture(false)
end

local function LegacyLineSegment(x1, y1, x2, y2, width)
	-- horizontal lines only in the fallback; good enough for separators
	rawRect(x1, y1 - width * 0.5, x2, y1 + width * 0.5)
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
		LineSegment = SG.LineSegment
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
		LineSegment = LegacyLineSegment
		Flush       = NoOp
		usingShapes = false
	end
end

BindDrawing()

local function SetColor(c, aMul)
	glColor(c[1], c[2], c[3], c[4] * (aMul or 1))
end

local function DrawBox(x1, y1, x2, y2, c, cs)
	SetColor(c)
	RectRound(x1, y1, x2, y2, (cs or 4) * uiScale)
end

local function DrawAccent(x1, x2, yTop, accent)
	local ah = PANEL_ACCENT_HEIGHT * uiScale
	glColor(accent[1], accent[2], accent[3], 1)
	AccentStrip(x1, yTop - ah, x2, yTop)
end

local function GetPanelBGColor()
	if WG.guishader then return COL.panelBgGui end
	return COL.panelBg
end

local function TruncateToWidth(text, maxWidth, size)
	if font:GetTextWidth(text) * size <= maxWidth then return text end
	local lo, hi = 0, #text
	while lo < hi do
		local mid = math_floor((lo + hi + 1) / 2)
		if font:GetTextWidth(text:sub(1, mid) .. "...") * size <= maxWidth then lo = mid else hi = mid - 1 end
	end
	if lo <= 0 then return "" end
	return text:sub(1, lo) .. "..."
end

--------------------------------------------------------------------------------
-- Widget handler helpers
--------------------------------------------------------------------------------

local function WidgetKnown(name)
	return widgetHandler.knownWidgets and widgetHandler.knownWidgets[name] ~= nil
end

-- true: enabled and active. 0.5: enabled in the order list but not running
-- (crashed or still loading). false: off.
local function WidgetToggleValue(name)
	local order = widgetHandler.orderList and widgetHandler.orderList[name]
	if not order or order == 0 then return false end
	local known = widgetHandler.knownWidgets and widgetHandler.knownWidgets[name]
	if known and known.active then return true end
	return 0.5
end

local function SetWidgetEnabled(name, on)
	if on then
		widgetHandler:EnableWidget(name)
	else
		widgetHandler:DisableWidget(name)
	end
	widgetHandler:SaveConfigData()
end

-- configVar = {"Widget Name", "key" [, "subkey" [, "subsubkey"]]}
local function ReadConfigVar(cv)
	local t = widgetHandler.configData and widgetHandler.configData[cv[1]]
	for i = 2, #cv do
		if type(t) ~= "table" then return nil end
		t = t[cv[i]]
	end
	return t
end

local function WriteConfigVar(cv, value)
	if not widgetHandler.configData then return end
	local t = widgetHandler.configData[cv[1]]
	if type(t) ~= "table" then
		t = {}
		widgetHandler.configData[cv[1]] = t
	end
	for i = 2, #cv - 1 do
		if type(t[cv[i]]) ~= "table" then t[cv[i]] = {} end
		t = t[cv[i]]
	end
	t[cv[#cv]] = value
end

--------------------------------------------------------------------------------
-- Value plumbing
--------------------------------------------------------------------------------

local function HasFraction(n)
	return n and n ~= math_floor(n)
end

local function ConfigType(opt)
	if opt.configType then return opt.configType end
	if opt.type == "slider" then
		if HasFraction(opt.min) or HasFraction(opt.max) or HasFraction(opt.step) then return "float" end
		if opt.steps then
			for i = 1, #opt.steps do if HasFraction(opt.steps[i]) then return "float" end end
		end
		return "int"
	end
	if opt.type == "select" and opt.values and type(opt.values[1]) == "string" then return "string" end
	return "int"
end

local function ReadConfig(opt)
	local ct = ConfigType(opt)
	local key = opt.config
	local v
	if ct == "float" then v = spGetConfigFloat(key, opt.default or 0)
	elseif ct == "string" then v = spGetConfigString(key, opt.default or "")
	else v = spGetConfigInt(key, opt.default or 0) end
	return v
end

local function WriteConfig(opt, raw)
	local ct = ConfigType(opt)
	if ct == "float" then spSetConfigFloat(opt.config, raw)
	elseif ct == "string" then spSetConfigString(opt.config, tostring(raw))
	else spSetConfigInt(opt.config, math_floor(tonumber(raw) or 0)) end
end

-- underlying (stored) value -> option-domain value
local function FromRaw(opt, raw)
	if raw == nil then return nil end
	if opt.type == "bool" then
		if type(raw) == "boolean" then return raw end
		if type(raw) == "number" then return raw ~= 0 end
		if type(raw) == "string" then return raw == "1" or raw == "true" end
		return raw and true or false
	elseif opt.type == "select" then
		if opt.values then
			for i = 1, #opt.values do
				if opt.values[i] == raw or tostring(opt.values[i]) == tostring(raw) then return i end
			end
			return nil
		end
		local n = tonumber(raw)
		if n and opt.options[n] then return n end
		-- allow the option label itself as the stored value
		for i = 1, #opt.options do if opt.options[i] == raw then return i end end
		return nil
	elseif opt.type == "slider" then
		return tonumber(raw)
	end
	return raw
end

-- option-domain value -> underlying (stored) value
local function ToRaw(opt, v)
	if opt.type == "bool" then
		if opt.config or opt.cmd then return v and 1 or 0 end
		return v and true or false
	elseif opt.type == "select" then
		if opt.values then return opt.values[v] end
		return v
	end
	return v
end

local function Get(opt)
	if opt.type == "separator" or opt.type == "action" then return nil end
	local v
	if opt.get then
		v = FromRaw(opt, opt.get())
		if v ~= nil then return v end
	end
	if opt.widget and opt.type == "bool" then
		local w = WidgetToggleValue(opt.widget)
		return w ~= false, w   -- second value flags "enabled but not active"
	end
	if opt.config then
		v = FromRaw(opt, ReadConfig(opt))
		if v ~= nil then return v end
	end
	if opt.api then
		local ns = WG[opt.api[1]]
		local getter = opt.api[2]
		if ns and getter and ns[getter] then
			v = FromRaw(opt, ns[getter]())
			if v ~= nil then return v end
		end
	end
	if opt.configVar then
		v = FromRaw(opt, ReadConfigVar(opt.configVar))
		if v ~= nil then return v end
	end
	if opt.store then
		v = FromRaw(opt, store[opt.id])
		if v ~= nil then return v end
	end
	v = FromRaw(opt, opt.default)
	if v ~= nil then return v end
	if opt.type == "bool" then return false end
	if opt.type == "slider" then return opt.min or (opt.steps and opt.steps[1]) or 0 end
	if opt.type == "select" then return 1 end
	return nil
end

local function SendCmd(cmd, raw)
	if type(cmd) == "table" then
		for i = 1, #cmd do SendCmd(cmd[i], raw) end
		return
	end
	local ok, s = pcall(string.format, cmd, raw)
	if not ok then s = cmd end
	spSendCommands(s)
end

local Set
Set = function(opt, v, fromDrag)
	if opt.type == "separator" then return end

	if opt.type == "action" then
		if opt.set then opt.set() end
		if opt.onSet then opt.onSet() end
		if opt.reloadUI then pendingReload = true end
		return
	end

	if opt.type == "slider" then
		if opt.steps then
			-- snap to nearest listed step
			local best, bestD = opt.steps[1], math.huge
			for i = 1, #opt.steps do
				local d = math_abs(opt.steps[i] - v)
				if d < bestD then best, bestD = opt.steps[i], d end
			end
			v = best
		else
			v = Round(Clamp(v, opt.min, opt.max), opt.step)
		end
	end

	local raw = ToRaw(opt, v)

	if opt.set then
		opt.set(v, raw)
	else
		if opt.widget and opt.type == "bool" then
			SetWidgetEnabled(opt.widget, v)
		end
		if opt.config then
			WriteConfig(opt, raw)
		end
		if opt.api then
			local ns = WG[opt.api[1]]
			local setter = opt.api[3]
			if ns and setter and ns[setter] then ns[setter](raw) end
		end
		if opt.configVar then
			WriteConfigVar(opt.configVar, raw)
		end
		if opt.store then
			store[opt.id] = raw
		end
		if not (opt.widget or opt.config or opt.api or opt.configVar or opt.store) then
			-- nothing else owns this value; keep it here so the UI stays consistent
			opt.store = true
			store[opt.id] = raw
		end
	end

	if opt.cmd then SendCmd(opt.cmd, raw) end
	if opt.onSet then opt.onSet(v, raw) end
	if opt.restart then changesRequireRestart = true end
	if opt.reloadUI and not fromDrag then pendingReload = true end

	rowsDirty = true
end

--------------------------------------------------------------------------------
-- Option registry
--------------------------------------------------------------------------------

local function IndexOption(opt)
	if opt.id then
		if optById[opt.id] and optById[opt.id] ~= opt then
			spEcho("[Options] duplicate option id '" .. opt.id .. "' (keeping the first)")
		else
			optById[opt.id] = opt
		end
	end
	if opt.children then
		for i = 1, #opt.children do
			opt.children[i].parent = opt
			IndexOption(opt.children[i])
		end
	end
end

local function SortTabs()
	table.sort(tabs, function(a, b)
		if (a.order or 100) ~= (b.order or 100) then return (a.order or 100) < (b.order or 100) end
		return (a.name or "") < (b.name or "")
	end)
end

local OPT = {}   -- helper table handed to definition files

function OPT.get(id)
	local opt = optById[id]
	if not opt then return nil end
	return (Get(opt))
end

function OPT.set(id, v)
	local opt = optById[id]
	if not opt then return false end
	Set(opt, v)
	return true
end

function OPT.widgetActive(name)
	return WidgetToggleValue(name) == true
end

function OPT.widgetKnown(name)
	return WidgetKnown(name)
end

function OPT.getConfigInt(key, default)    return tonumber(spGetConfigInt(key, default or 0)) or default end
function OPT.getConfigFloat(key, default)  return tonumber(spGetConfigFloat(key, default or 0)) or default end
function OPT.getConfigString(key, default) return spGetConfigString(key, default or "") end

function OPT.reloadUI()
	pendingReload = true
end

local function AddTab(def, source)
	if type(def) ~= "table" or not def.id then
		spEcho("[Options] " .. tostring(source) .. " did not return a tab table with an id")
		return
	end
	def.options = def.options or {}
	if tabById[def.id] then
		-- merge: same tab id declared twice (e.g. a widget registering into an existing tab)
		local existing = tabById[def.id]
		for i = 1, #def.options do existing.options[#existing.options + 1] = def.options[i] end
		for i = 1, #def.options do IndexOption(def.options[i]) end
		return
	end
	tabById[def.id] = def
	tabs[#tabs + 1] = def
	for i = 1, #def.options do IndexOption(def.options[i]) end
end

local function LoadDefinitions()
	tabs, tabById, optById = {}, {}, {}

	local files = VFS.DirList(OPTIONS_DIR, "*.lua", VFS.RAW_FIRST) or {}
	table.sort(files)
	local env = setmetatable({ OPT = OPT }, { __index = getfenv(1) })
	for i = 1, #files do
		local ok, def = pcall(VFS.Include, files[i], env, VFS.RAW_FIRST)
		if ok then
			AddTab(def, files[i])
		else
			spEcho("[Options] failed to load " .. files[i] .. ": " .. tostring(def))
		end
	end
	SortTabs()

	if not currentTab or not tabById[currentTab] then
		currentTab = tabs[1] and tabs[1].id
	end
	if geom.tabs then BuildTabRects() end
	rowsDirty = true
end

-- Runtime registration for widgets that ship their own options.
local function RegisterOption(tabId, opt, afterId)
	local tab = tabById[tabId]
	if not tab then
		AddTab({ id = tabId, name = tabId, order = 900, options = {} }, "register")
		tab = tabById[tabId]
		SortTabs()
		if geom.tabs then BuildTabRects() end
	end
	local list = tab.options
	local pos = #list + 1
	if afterId then
		for i = 1, #list do
			if list[i].id == afterId then pos = i + 1; break end
		end
	end
	table.insert(list, pos, opt)
	IndexOption(opt)
	rowsDirty = true
end

--------------------------------------------------------------------------------
-- Row list (flattened view of the current tab)
--------------------------------------------------------------------------------

local function OptionVisible(opt)
	if opt.requires and not WidgetKnown(opt.requires) then return false end
	if opt.showIf and not opt.showIf() then return false end
	return true
end

local function AppendRows(list, depth)
	for i = 1, #list do
		local opt = list[i]
		if OptionVisible(opt) then
			local h = (opt.type == "separator") and SEP_H or ROW_H
			rows[#rows + 1] = { opt = opt, depth = depth, h = h * uiScale }
			if opt.children then
				local open = true
				if opt.type == "bool" then open = (Get(opt) == true) end
				if open then AppendRows(opt.children, depth + 1) end
			end
		end
	end
end

local function BuildRows()
	rows = {}
	local tab = tabById[currentTab]
	if tab then AppendRows(tab.options, 0) end
	contentH = 0
	for i = 1, #rows do
		rows[i].y2 = contentH          -- distance from the top of the content
		contentH = contentH + rows[i].h
		rows[i].y1 = contentH
	end
	rowsDirty = false
	if geom.view then
		scroll = Clamp(scroll, 0, math_max(0, contentH - (geom.view.y2 - geom.view.y1)))
	end
end

-- screen rect of a row given the current scroll
local function RowRect(row)
	local v = geom.view
	local top = v.y2 + scroll - row.y2
	return v.x1, top - row.h, v.x2, top
end

local function RowAt(x, y)
	local v = geom.view
	if not InRect(x, y, v) then return nil end
	for i = 1, #rows do
		local x1, y1, x2, y2 = RowRect(rows[i])
		if y >= y1 and y <= y2 then return rows[i], i end
	end
	return nil
end

--------------------------------------------------------------------------------
-- Geometry
--------------------------------------------------------------------------------

local LAYOUT_ID = "options"

local function LayoutPlace(x1, y1, w, h)
	local L = WG.StaticLayout
	if L then return L.Place(LAYOUT_ID, x1, y1, w, h) end
	return x1, y1
end

BuildTabRects = function()
	local tr  = geom.tabs
	local n   = math_max(1, #tabs)
	local gap = 6 * uiScale
	local w   = (tr.x2 - tr.x1 - gap * (n - 1)) / n
	for i = 1, #tabs do
		local bx1 = tr.x1 + (i - 1) * (w + gap)
		tabs[i].rect = { x1 = bx1, y1 = tr.y1, x2 = bx1 + w, y2 = tr.y2 }
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
	x1, y1 = LayoutPlace(x1, y1, math_floor(pw), math_floor(ph))
	local x2 = x1 + math_floor(pw)
	local y2 = y1 + math_floor(ph)
	panelRect = { x1=x1, y1=y1, x2=x2, y2=y2 }

	local cx1 = x1 + pad
	local cx2 = x2 - pad
	local cy1 = y1 + pad
	local cy2 = y2 - pad - acc

	local titleH  = TITLE_BAR_H * uiScale
	local titleY2 = cy2
	local titleY1 = titleY2 - titleH
	geom.titleBar  = { x1=cx1, y1=titleY1, x2=cx2, y2=titleY2 }
	geom.closeRect = { x1=cx2-titleH, y1=titleY1, x2=cx2, y2=titleY2 }

	local tabsY2 = titleY1 - SECTION_GAP * uiScale * 0.5
	local tabsY1 = tabsY2 - TAB_H * uiScale
	geom.tabs = { x1=cx1, y1=tabsY1, x2=cx2, y2=tabsY2 }
	BuildTabRects()

	local footerH = FOOTER_H * uiScale
	geom.footer = { x1=cx1, y1=cy1, x2=cx2, y2=cy1 + footerH }

	local viewY2 = tabsY1 - SECTION_GAP * uiScale
	local viewY1 = geom.footer.y2 + SECTION_GAP * uiScale * 0.5
	local barW   = SCROLLBAR_W * uiScale
	geom.view = { x1=cx1, y1=viewY1, x2=cx2 - barW - 4 * uiScale, y2=viewY2 }
	geom.bar  = { x1=cx2-barW, y1=viewY1, x2=cx2, y2=viewY2 }

	rowsDirty = true
end

--------------------------------------------------------------------------------
-- Control geometry (shared by draw and input)
--------------------------------------------------------------------------------

-- Returns the rect the interactive control occupies inside a row.
local function ControlRect(row, x1, y1, x2, y2)
	local opt = row.opt
	local labelW = (x2 - x1) * LABEL_FRAC
	local cx1 = x1 + labelW + CONTROL_PAD * uiScale
	local cx2 = x2 - TEXT_PAD * uiScale
	local cy  = (y1 + y2) * 0.5
	if opt.type == "bool" then
		local w, h = TOGGLE_W * uiScale, TOGGLE_H * uiScale
		return { x1 = cx1, y1 = cy - h * 0.5, x2 = cx1 + w, y2 = cy + h * 0.5 }
	elseif opt.type == "slider" then
		local kr = KNOB_R * uiScale
		return { x1 = cx1 + kr, y1 = cy - kr, x2 = cx2 - VALUE_W * uiScale - kr, y2 = cy + kr }
	elseif opt.type == "select" or opt.type == "action" then
		local h = SELECT_H * uiScale
		return { x1 = cx1, y1 = cy - h * 0.5, x2 = cx2, y2 = cy + h * 0.5 }
	end
	return nil
end

local function SliderFraction(opt, v)
	if opt.steps then
		for i = 1, #opt.steps do
			if opt.steps[i] == v then return (i - 1) / math_max(1, #opt.steps - 1) end
		end
		return 0
	end
	if opt.max == opt.min then return 0 end
	return Clamp((v - opt.min) / (opt.max - opt.min), 0, 1)
end

local function SliderValueFromX(opt, r, x)
	local f = Clamp((x - r.x1) / math_max(1, r.x2 - r.x1), 0, 1)
	if opt.steps then
		local idx = math_floor(f * (#opt.steps - 1) + 0.5) + 1
		return opt.steps[idx]
	end
	return Round(opt.min + f * (opt.max - opt.min), opt.step)
end

local function FormatValue(opt, v)
	if opt.format then
		local ok, s = pcall(string.format, opt.format, v)
		if ok then return s end
	end
	if opt.type == "slider" then
		if HasFraction(opt.step) or HasFraction(v) then
			local s = string.format("%.3f", v):gsub("0+$", ""):gsub("%.$", "")
			return s
		end
		return tostring(math_floor(v + 0.5))
	end
	return tostring(v)
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------

local function DrawPanelChrome()
	local pc  = GetPanelBGColor()
	local oc  = OUTER_CORNER * uiScale
	local ic  = INNER_CORNER * uiScale
	local ins = INNER_INSET  * uiScale
	SetColor(COL.border)
	RectRound(panelRect.x1, panelRect.y1, panelRect.x2, panelRect.y2, oc)
	SetColor(pc)
	RectRound(panelRect.x1+ins, panelRect.y1+ins, panelRect.x2-ins, panelRect.y2-ins, ic)
	DrawAccent(panelRect.x1+ins, panelRect.x2-ins, panelRect.y2-ins, COL.accentPanel)
end

local function DrawTitle()
	local tb = geom.titleBar
	DrawBox(tb.x1, tb.y1, tb.x2, tb.y2, COL.categoryBg, 4)
	font:Begin()
	font:SetTextColor(1, 1, 1, 1)
	font:Print(STR_WHITE .. "Options", tb.x1 + 8*uiScale, tb.y1 + (tb.y2-tb.y1)*0.5 - 6*uiScale, 16*uiScale, "lo")
	font:End()

	local cr = geom.closeRect
	DrawBox(cr.x1, cr.y1, cr.x2, cr.y2, COL.categoryBg, 4)
	DrawAccent(cr.x1, cr.x2, cr.y2, COL.accentClose)
	font:Begin()
	font:Print(STR_WHITE .. "x", cr.x1+(cr.x2-cr.x1)*0.5, cr.y1+(cr.y2-cr.y1)*0.5-6*uiScale, 15*uiScale, "co")
	font:End()
end

local function DrawTabs(mx, my)
	for i = 1, #tabs do
		local t = tabs[i]
		local r = t.rect
		DrawBox(r.x1, r.y1, r.x2, r.y2, COL.categoryBg, 4)
		if currentTab == t.id then DrawAccent(r.x1, r.x2, r.y2, COL.accentTab) end
		if InRect(mx, my, r) then
			SetColor(COL.hover)
			RectRound(r.x1, r.y1, r.x2, r.y2, 4*uiScale)
		end
		font:Begin()
		local c = (currentTab == t.id) and COL.text or COL.textDim
		font:SetTextColor(c[1], c[2], c[3], c[4])
		font:Print(t.name or t.id, r.x1+(r.x2-r.x1)*0.5, r.y1+(r.y2-r.y1)*0.5-4.5*uiScale, 12*uiScale, "co")
		font:End()
	end
end

local function DrawFooter()
	local f = geom.footer
	font:Begin()
	if pendingReload then
		font:SetTextColor(COL.warn[1], COL.warn[2], COL.warn[3], 1)
		font:Print("Reloading interface...", f.x1 + 4*uiScale, f.y1 + (f.y2-f.y1)*0.5 - 4*uiScale, 11*uiScale, "lo")
	elseif changesRequireRestart then
		font:SetTextColor(COL.warn[1], COL.warn[2], COL.warn[3], 1)
		font:Print("Some changes take effect next game", f.x1 + 4*uiScale, f.y1 + (f.y2-f.y1)*0.5 - 4*uiScale, 11*uiScale, "lo")
	else
		font:SetTextColor(COL.textDim[1], COL.textDim[2], COL.textDim[3], 1)
		font:Print("Hover an option for details", f.x1 + 4*uiScale, f.y1 + (f.y2-f.y1)*0.5 - 4*uiScale, 11*uiScale, "lo")
	end
	font:End()
end

local function DrawToggle(r, on, half, hot)
	local h = r.y2 - r.y1
	local c = on and (half and COL.toggleHalf or COL.toggleOn) or COL.toggleOff
	SetColor(c, hot and 1.15 or 1)
	RectRound(r.x1, r.y1, r.x2, r.y2, h * 0.5)
	local kr = h * 0.5 - 2 * uiScale
	local kx = on and (r.x2 - kr - 2 * uiScale) or (r.x1 + kr + 2 * uiScale)
	local ky = (r.y1 + r.y2) * 0.5
	SetColor(COL.knob)
	RectRound(kx - kr, ky - kr, kx + kr, ky + kr, kr)
end

local function DrawSlider(opt, r, v, hot)
	local cy = (r.y1 + r.y2) * 0.5
	local th = SLIDER_H * uiScale
	local f  = SliderFraction(opt, v)
	local kx = r.x1 + (r.x2 - r.x1) * f
	SetColor(COL.track)
	RectRound(r.x1, cy - th * 0.5, r.x2, cy + th * 0.5, th * 0.5)
	if kx > r.x1 then
		SetColor(COL.trackFill)
		RectRound(r.x1, cy - th * 0.5, kx, cy + th * 0.5, th * 0.5)
	end
	local kr = KNOB_R * uiScale * (hot and 1.15 or 1)
	SetColor(COL.knob)
	RectRound(kx - kr, cy - kr, kx + kr, cy + kr, kr)
end

local function DrawSelectBox(opt, r, v, hot)
	DrawBox(r.x1, r.y1, r.x2, r.y2, hot and COL.selectBgHot or COL.selectBg, 4)
	local label
	if opt.transient then
		label = opt.placeholder or "Choose..."
	else
		label = opt.options[v] or "?"
	end
	local fs = 11 * uiScale
	label = TruncateToWidth(label, (r.x2 - r.x1) - 24 * uiScale, fs)
	font:Begin()
	if opt.transient then font:SetTextColor(COL.textDim[1], COL.textDim[2], COL.textDim[3], 1)
	else font:SetTextColor(COL.text[1], COL.text[2], COL.text[3], 1) end
	font:Print(label, r.x1 + 6*uiScale, (r.y1 + r.y2)*0.5 - 4*uiScale, fs, "lo")
	font:SetTextColor(COL.textDim[1], COL.textDim[2], COL.textDim[3], 1)
	font:Print("v", r.x2 - 8*uiScale, (r.y1 + r.y2)*0.5 - 4*uiScale, fs, "co")
	font:End()
end

local function DrawActionButton(opt, r, hot)
	DrawBox(r.x1, r.y1, r.x2, r.y2, hot and COL.selectBgHot or COL.buttonBg, 4)
	local fs = 11 * uiScale
	font:Begin()
	font:SetTextColor(COL.text[1], COL.text[2], COL.text[3], 1)
	font:Print(opt.label or opt.name or "Apply", (r.x1 + r.x2)*0.5, (r.y1 + r.y2)*0.5 - 4*uiScale, fs, "co")
	font:End()
end

local function DrawRow(row, mx, my, hovered)
	local opt = row.opt
	local x1, y1, x2, y2 = RowRect(row)
	local v = geom.view

	if opt.type == "separator" then
		local fs = 11 * uiScale
		local tx = x1 + TEXT_PAD * uiScale
		local ty = y1 + (row.h - fs) * 0.5 + 2 * uiScale
		font:Begin()
		font:SetTextColor(COL.textHeader[1], COL.textHeader[2], COL.textHeader[3], 1)
		font:Print(string.upper(opt.name or ""), tx, ty, fs, "o")
		font:End()
		local tw = font:GetTextWidth(string.upper(opt.name or "")) * fs
		local ly = y1 + row.h * 0.5
		LineSegment(tx + tw + 8 * uiScale, ly, x2 - TEXT_PAD * uiScale, ly, 1, COL.sepLine)
		return
	end

	local indent = row.depth * CHILD_INDENT * uiScale
	if hovered and dragOpt == nil then
		SetColor(COL.hover)
		glRect(x1, math_max(y1, v.y1), x2, math_min(y2, v.y2))
	end

	-- child guide line
	if row.depth > 0 then
		local lx = x1 + TEXT_PAD * uiScale + indent - CHILD_INDENT * uiScale * 0.5
		LineSegment(lx, y1 + 4 * uiScale, lx, y2 - 4 * uiScale, 1, COL.childLine)
	end

	local value, half = Get(opt)
	local cr = ControlRect(row, x1, y1, x2, y2)
	local hot = hovered and cr and InRect(mx, my, cr)
	if dragOpt == opt then hot = true end

	-- label
	local fs = 12 * uiScale
	local labelMax = (x2 - x1) * LABEL_FRAC - TEXT_PAD * uiScale - indent
	local label = TruncateToWidth(opt.name or opt.id or "", labelMax, fs)
	font:Begin()
	if opt.type == "action" then
		font:SetTextColor(COL.textDim[1], COL.textDim[2], COL.textDim[3], 1)
	else
		font:SetTextColor(COL.text[1], COL.text[2], COL.text[3], 1)
	end
	font:Print(label, x1 + TEXT_PAD * uiScale + indent, y1 + (row.h - fs) * 0.5 + 1 * uiScale, fs, "o")
	if opt.restart then
		font:SetTextColor(COL.warn[1], COL.warn[2], COL.warn[3], 0.9)
		local lw = font:GetTextWidth(label) * fs
		font:Print("*", x1 + TEXT_PAD * uiScale + indent + lw + 2 * uiScale, y1 + (row.h - fs) * 0.5 + 1 * uiScale, fs, "o")
	end
	font:End()

	if opt.type == "bool" then
		DrawToggle(cr, value == true, half == 0.5, hot)
	elseif opt.type == "slider" then
		DrawSlider(opt, cr, value, hot)
		font:Begin()
		font:SetTextColor(COL.textDim[1], COL.textDim[2], COL.textDim[3], 1)
		font:Print(FormatValue(opt, value), x2 - TEXT_PAD * uiScale, (y1 + y2) * 0.5 - 4 * uiScale, 11 * uiScale, "ro")
		font:End()
	elseif opt.type == "select" then
		DrawSelectBox(opt, cr, value, hot or dropOpt == opt)
	elseif opt.type == "action" then
		DrawActionButton(opt, cr, hot)
	end
end

local function DrawList(mx, my)
	local v = geom.view
	DrawBox(v.x1, v.y1, v.x2, v.y2, COL.viewBg, 4)

	if #rows == 0 then
		font:Begin()
		font:SetTextColor(COL.textDim[1], COL.textDim[2], COL.textDim[3], 1)
		font:Print("(no options defined for this tab)", (v.x1+v.x2)*0.5, (v.y1+v.y2)*0.5-5*uiScale, 12*uiScale, "co")
		font:End()
		return
	end

	local hoverRow = (dropOpt == nil) and RowAt(mx, my) or nil

	glScissor(math_floor(v.x1), math_floor(v.y1), math_floor(v.x2 - v.x1), math_floor(v.y2 - v.y1))
	for i = 1, #rows do
		local row = rows[i]
		local _, y1, _, y2 = RowRect(row)
		if y2 >= v.y1 - row.h and y1 <= v.y2 + row.h then
			DrawRow(row, mx, my, hoverRow == row)
		end
	end
	glScissor(false)
end

local function DrawScrollbar(mx, my)
	local bar   = geom.bar
	local viewH = geom.view.y2 - geom.view.y1
	SetColor(COL.scrollBg)
	glRect(bar.x1, bar.y1, bar.x2, bar.y2)
	if contentH <= viewH then return end
	local trackH = bar.y2 - bar.y1
	local thumbH = math_max(24*uiScale, trackH * (viewH / contentH))
	local range  = trackH - thumbH
	local frac   = Clamp(scroll / math_max(1, contentH - viewH), 0, 1)
	local ty2    = bar.y2 - range * frac
	local ty1    = ty2 - thumbH
	local hov    = InRect(mx, my, bar) or barDrag
	SetColor(hov and COL.scrollThumbH or COL.scrollThumb)
	glRect(bar.x1, ty1, bar.x2, ty2)
end

-- Dropdown for the open select. Drawn last so it sits above everything.
local function DrawDropdown(mx, my)
	if not dropOpt or not dropRect then return end
	local opt  = dropOpt
	local n    = #opt.options
	local rowH = DROP_ROW_H * uiScale
	local shown = math_min(n, DROP_MAX_ROWS)
	local h    = shown * rowH + 4 * uiScale
	local x1, x2 = dropRect.x1, dropRect.x2
	local y2   = dropRect.y1 - 2 * uiScale
	local y1   = y2 - h
	if y1 < panelRect.y1 then
		-- open upward instead
		y1 = dropRect.y2 + 2 * uiScale
		y2 = y1 + h
	end
	DrawBox(x1, y1, x2, y2, COL.border, 4)
	DrawBox(x1 + 1, y1 + 1, x2 - 1, y2 - 1, COL.dropBg, 4)

	dropRows = {}
	local cur = Get(opt)
	local fs = 11 * uiScale
	local top = y2 - 2 * uiScale
	for i = 1, shown do
		local ry2 = top - (i - 1) * rowH
		local ry1 = ry2 - rowH
		local r = { x1 = x1 + 2, y1 = ry1, x2 = x2 - 2, y2 = ry2 }
		dropRows[i] = { rect = r, index = i }
		if InRect(mx, my, r) then
			SetColor(COL.hover)
			glRect(r.x1, r.y1, r.x2, r.y2)
		end
		font:Begin()
		if i == cur and not opt.transient then
			font:SetTextColor(COL.accentTab[1], COL.accentTab[2], COL.accentTab[3], 1)
		else
			font:SetTextColor(COL.text[1], COL.text[2], COL.text[3], 1)
		end
		font:Print(TruncateToWidth(opt.options[i], (x2 - x1) - 16 * uiScale, fs), x1 + 8 * uiScale, (ry1 + ry2) * 0.5 - 4 * uiScale, fs, "lo")
		font:End()
	end
	dropRect.listY1, dropRect.listY2 = y1, y2
end

--------------------------------------------------------------------------------
-- Open / close
--------------------------------------------------------------------------------

local function Open()
	if isOpen then return end
	isOpen = true
	BuildGeometry()
	rowsDirty = true
	PlayClickSound()
end

local function Close()
	if not isOpen then return end
	isOpen  = false
	barDrag = false
	dragOpt = nil
	dropOpt = nil
	PlayClickSound()
end

local function Toggle(state)
	if state == nil then
		if isOpen then Close() else Open() end
	elseif state then Open() else Close() end
end

--------------------------------------------------------------------------------
-- Input
--------------------------------------------------------------------------------

local function IsOnPanel(x, y)
	return x >= panelRect.x1 and x <= panelRect.x2 and y >= panelRect.y1 and y <= panelRect.y2
end

local function DropdownHit(x, y)
	if not dropOpt or not dropRows then return nil end
	for i = 1, #dropRows do
		if InRect(x, y, dropRows[i].rect) then return dropRows[i].index end
	end
	return nil
end

function widget:KeyPress(key, mods, isRepeat)
	if key == KEYSYMS.F10 and not isRepeat and not (mods.alt or mods.ctrl or mods.meta or mods.shift) then
		Toggle()
		return true
	end
	if not isOpen then return false end
	if key == KEYSYMS.ESCAPE then
		if dropOpt then dropOpt = nil else Close() end
		return true
	end
	if key == KEYSYMS.PAGEUP or key == KEYSYMS.PAGEDOWN then
		local viewH = geom.view.y2 - geom.view.y1
		local d = (key == KEYSYMS.PAGEUP) and -viewH or viewH
		scroll = Clamp(scroll + d, 0, math_max(0, contentH - viewH))
		return true
	end
	return false
end

function widget:IsAbove(x, y)
	return isOpen and IsOnPanel(x, y)
end

function widget:MousePress(x, y, button)
	if chobbyInterface or spIsGUIHidden() or not isOpen then return false end

	-- an open dropdown captures the click first
	if dropOpt then
		local idx = DropdownHit(x, y)
		if idx then
			PlayClickSound()
			Set(dropOpt, idx)
		end
		dropOpt, dropRect, dropRows = nil, nil, nil
		return true
	end

	if not IsOnPanel(x, y) then
		Close()
		return false
	end

	if button ~= 1 then return true end

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

	-- sliders start dragging on press; everything else fires on release
	local row = RowAt(x, y)
	if row and row.opt.type == "slider" then
		local x1, y1, x2, y2 = RowRect(row)
		local cr = ControlRect(row, x1, y1, x2, y2)
		if cr and x >= cr.x1 - KNOB_R * uiScale and x <= cr.x2 + KNOB_R * uiScale then
			dragOpt, dragRect, dragChanged = row.opt, cr, false
			local nv = SliderValueFromX(row.opt, cr, x)
			if nv ~= Get(row.opt) then
				dragChanged = true
				if not row.opt.applyOnRelease then Set(row.opt, nv, true) else store["__drag"] = nv end
			end
			return true
		end
	end

	return true
end

function widget:MouseMove(x, y, dx, dy, button)
	if not isOpen then return false end
	if barDrag then
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
	if dragOpt then
		local nv = SliderValueFromX(dragOpt, dragRect, x)
		if dragOpt.applyOnRelease then
			if nv ~= store["__drag"] then store["__drag"] = nv; dragChanged = true end
		elseif nv ~= Get(dragOpt) then
			dragChanged = true
			Set(dragOpt, nv, true)
		end
		return true
	end
	return false
end

function widget:MouseRelease(x, y, button)
	if not isOpen then return false end
	if barDrag then barDrag = false; return true end

	if dragOpt then
		local opt = dragOpt
		dragOpt, dragRect = nil, nil
		if opt.applyOnRelease then
			local nv = store["__drag"]
			store["__drag"] = nil
			if nv ~= nil and nv ~= Get(opt) then Set(opt, nv) end
		elseif dragChanged then
			-- one final non-drag Set so reloadUI/restart flags fire once
			Set(opt, Get(opt))
		end
		return true
	end

	if not IsOnPanel(x, y) then return false end
	if button ~= 1 then return true end

	if InRect(x, y, geom.closeRect) then
		Close()
		return true
	end

	for i = 1, #tabs do
		if InRect(x, y, tabs[i].rect) then
			if currentTab ~= tabs[i].id then
				currentTab = tabs[i].id
				scroll = 0
				rowsDirty = true
				PlayClickSound()
			end
			return true
		end
	end

	local row = RowAt(x, y)
	if not row then return true end
	local opt = row.opt
	local x1, y1, x2, y2 = RowRect(row)
	local cr = ControlRect(row, x1, y1, x2, y2)

	if opt.type == "bool" then
		-- the whole row toggles, it is a much bigger target than the pill
		PlayToggleSound()
		Set(opt, not (Get(opt) == true))
	elseif opt.type == "select" then
		if cr and InRect(x, y, cr) then
			PlayClickSound()
			dropOpt, dropRect, dropRows = opt, { x1 = cr.x1, y1 = cr.y1, x2 = cr.x2, y2 = cr.y2 }, nil
		end
	elseif opt.type == "action" then
		if cr and InRect(x, y, cr) then
			PlayClickSound()
			Set(opt)
		end
	end
	return true
end

function widget:MouseWheel(up, value)
	if not isOpen then return false end
	local mx, my = spGetMouseState()
	-- while the panel is open, the wheel only ever scrolls the list. It never
	-- changes a value, and over the panel it is swallowed so the camera does
	-- not zoom underneath.
	if not IsOnPanel(mx, my) then return false end
	if not InRect(mx, my, geom.view) and not InRect(mx, my, geom.bar) then return true end
	local viewH = geom.view.y2 - geom.view.y1
	if contentH <= viewH then return true end
	local _, c, _, s = spGetModKeyState()
	local step = (s and 4 or (c and 1 or 2)) * ROW_H * uiScale
	scroll = Clamp(scroll + (up and -step or step), 0, contentH - viewH)
	return true
end

function widget:GetTooltip(x, y)
	if not isOpen or dropOpt then return nil end
	local row = RowAt(x, y)
	if not row or row.opt.type == "separator" then return nil end
	local opt = row.opt
	local tt = STR_WHITE .. (opt.name or opt.id or "")
	if opt.desc and opt.desc ~= "" then tt = tt .. "\n" .. STR_DIM .. opt.desc end
	if opt.restart then tt = tt .. "\n" .. STR_WARN .. "Takes effect next game" end
	if opt.widget then
		local w = WidgetToggleValue(opt.widget)
		if w == 0.5 then tt = tt .. "\n" .. STR_WARN .. "Widget is enabled but not running" end
	end
	return tt
end

--------------------------------------------------------------------------------
-- Text commands: /options, /option <id> [value]
--------------------------------------------------------------------------------

function widget:TextCommand(command)
	if command == "options" then
		Toggle()
		return true
	end
	if command:sub(1, 7) == "option " then
		local id, value = command:match("^option%s+(%S+)%s*(.*)$")
		local opt = id and optById[id]
		if not opt then
			spEcho("[Options] unknown option '" .. tostring(id) .. "'")
			return true
		end
		if value == nil or value == "" then
			if opt.type == "bool" then
				Set(opt, not (Get(opt) == true))
			elseif opt.type == "action" then
				Set(opt)
			else
				spEcho("[Options] " .. id .. " = " .. tostring(Get(opt)))
			end
			return true
		end
		if opt.type == "bool" then
			Set(opt, value == "1" or value == "true" or value == "on")
		elseif opt.type == "slider" then
			local n = tonumber(value)
			if n then Set(opt, n) end
		elseif opt.type == "select" then
			local n = tonumber(value)
			if not n then
				for i = 1, #opt.options do
					if opt.options[i]:lower() == value:lower() then n = i end
				end
			end
			if n and opt.options[n] then Set(opt, n) end
		end
		return true
	end
	return false
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function widget:Update(dt)
	if pendingReload then
		pendingReload = false
		spSendCommands("luarules reloadluaui")
		return
	end
	if not isOpen then return end
	-- a widget being enabled or crashing changes what rows exist
	local known = widgetHandler.knownWidgets and widgetHandler.knownChanged
	if known ~= lastKnownWidgets then
		lastKnownWidgets = known
		rowsDirty = true
	end
	if rowsDirty then BuildRows() end
end

function widget:DrawScreen()
	if chobbyInterface or spIsGUIHidden() or not isOpen or not font then return end
	if rowsDirty then BuildRows() end

	local mx, my = spGetMouseState()

	DrawPanelChrome()
	DrawTitle()
	DrawTabs(mx, my)
	DrawList(mx, my)
	DrawScrollbar(mx, my)
	DrawFooter()
	DrawDropdown(mx, my)

	glColor(1, 1, 1, 1)
	Flush()
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1, 19) == 'LobbyOverlayActive1')
	end
end

function widget:Initialize()
	BindDrawing()
	spSendCommands('unbindkeyset f10')

	vsx, vsy = spGetViewGeometry()
	fontfileScale = (0.5 + (vsx * vsy / 5700000))
	font = WrapFont(gl.LoadFont(fontfile, 23*fontfileScale, 5*fontfileScale, 1.8))

	LoadDefinitions()
	BuildGeometry()

	WG.options = {
		toggle    = Toggle,
		show      = Open,
		hide      = Close,
		isvisible = function() return isOpen end,
		get       = OPT.get,
		set       = OPT.set,
		register  = RegisterOption,
		reload    = LoadDefinitions,
		-- kept for camera_fov_changer.lua and any other consumer of the old api
		getCameraSmoothness = function() return OPT.get("camerasmoothness") or 0.2 end,
	}

	if WG.StaticLayout then
		WG.StaticLayout.Register(LAYOUT_ID, {
			label     = "Options",
			onMove    = function() widget:ViewResize(vsx, vsy) end,
			isVisible = function() return isOpen end,
		})
	end
end

function widget:Shutdown()
	if WG.StaticLayout then WG.StaticLayout.Unregister(LAYOUT_ID) end
	if font then ReleaseFont(font) end
	WG.options = nil
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
end

function widget:GetConfigData()
	store["__drag"] = nil
	return { show = isOpen, tab = currentTab, store = store }
end

function widget:SetConfigData(data)
	if not data then return end
	if data.store then store = data.store end
	if data.tab then currentTab = data.tab end
	if data.show then Open() end
end
