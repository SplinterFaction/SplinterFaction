--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Options window of the RmlUi HUD.
--
--  F10 opens and closes it (so does Settings in the game menu); Esc or the X
--  closes it. Options are declared as data in LuaUI/configs/options/*.lua;
--  this widget only shows and applies them.
--
--  Replaces gui_static_options.lua (kept in Widgets/disabled/). Everything
--  about what an option is and how its value is read and written is carried
--  over unchanged, including the WG.options interface, the OPT helper table
--  and the /options and /option text commands. What is new is the window.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name    = "Options",
		desc    = "Options window. Options are declared as data in LuaUI/configs/options/*.lua; this widget only shows and applies them. (RmlUi)",
		author  = "Scary le Poo",
		date    = "2026-10-12",
		license = "GNU GPL, v2 or later",
		layer   = -10000, -- before every other window, so Esc and F10 reach this first
		handler = true,   -- needs widgetHandler for widget toggles and configData
		enabled = true,
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
--     desc="..."            shown in the window's footer while the mouse is on
--                           the option
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

--------------------------------------------------------------------------------
-- config
--------------------------------------------------------------------------------

local OPTIONS_DIR   = "LuaUI/configs/options/"
local DOCUMENT_PATH = "LuaUI/rml/options.rml"

-- must match #options in options.rml
local PANEL_WIDTH  = 780
local PANEL_HEIGHT = 660

local CHILD_INDENT = 18 -- dp an option under another one is set in by

local LAYOUT_NAME = "options" -- same as the old widget, so a saved position carries over
local OLD_WIDGET  = "Static Options" -- whose saved values this widget takes over

local UPDATE_INTERVAL = 0.2

local KEY_ESCAPE, KEY_F10, KEY_PAGEUP, KEY_PAGEDOWN = 27, 291, 280, 281

--------------------------------------------------------------------------------
-- locals
--------------------------------------------------------------------------------

local spGetConfigInt    = Spring.GetConfigInt
local spGetConfigFloat  = Spring.GetConfigFloat
local spGetConfigString = Spring.GetConfigString
local spSetConfigInt    = Spring.SetConfigInt
local spSetConfigFloat  = Spring.SetConfigFloat
local spSetConfigString = Spring.SetConfigString
local spSendCommands    = Spring.SendCommands
local spPlaySoundFile   = Spring.PlaySoundFile
local spEcho            = Spring.Echo

local math_floor = math.floor
local math_max   = math.max
local math_min   = math.min
local math_abs   = math.abs

local hud
local document
local view
local lastUpdate

--------------------------------------------------------------------------------
-- state
--------------------------------------------------------------------------------

local isOpen     = false
local openOnLoad = false   -- it was open when the interface was last saved

local tabs       = {}      -- ordered list of {id, name, order, options}
local tabById    = {}
local optById    = {}      -- id -> option table (all tabs)
local currentTab = nil

local rows       = {}      -- flat, visible rows of the current tab; row i has the id "row<i>"
local rowsDirty  = true    -- set by the plumbing below whenever a value changes

local store      = {}      -- own persisted values (store=true options)
local changesRequireRestart = false
local pendingReload = false
local lastKnownWidgets = 0

local tabsMarkup, listMarkup  -- the markup as last set
local drag       -- {row = n, value = v} while a slider is held
local dropRow    -- the row whose list of choices is open
local hoverRow   -- the row under the mouse

-- The carried-over plumbing below mentions these two; in this widget the tabs
-- are laid out by RmlUi, so there is nothing for them to do.
local geom = {}
local BuildTabRects

--------------------------------------------------------------------------------
-- helpers (carried over unchanged)
--------------------------------------------------------------------------------

local function Clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
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
-- widgets, config vars, value plumbing, the option registry (carried over unchanged)
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
-- rows: the current tab's options, flattened, with the hidden ones left out
--------------------------------------------------------------------------------

local function OptionVisible(opt)
	if opt.requires and not WidgetKnown(opt.requires) then return false end
	if opt.showIf and not opt.showIf() then return false end
	return true
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

local function AppendRows(list, depth)
	for i = 1, #list do
		local opt = list[i]
		if OptionVisible(opt) then
			rows[#rows + 1] = {opt = opt, depth = depth}
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
	rowsDirty = false
end

--------------------------------------------------------------------------------
-- markup
--------------------------------------------------------------------------------

local function PlayClickSound()  spPlaySoundFile("leftclick", 0.8, "ui") end
local function PlayToggleSound() spPlaySoundFile("leftclick", 0.6, "ui") end

local function RowRML(i, row)
	local opt = row.opt
	if opt.type == "separator" then
		return '<div class="sep"><div class="label">' .. hud.Escape(opt.name or "") .. '</div><div class="rule"/></div>'
	end

	local control
	if opt.type == "bool" then
		control = string.format('<div id="t%d" class="toggle"><div class="knob"/></div>', i)
	elseif opt.type == "slider" then
		control = string.format(
			'<div id="s%d" class="slider" data-slider="%d"><div class="track"><div id="f%d" class="fill"/><div id="h%d" class="handle"/></div></div><div id="v%d" class="val"/>',
			i, i, i, i, i)
	elseif opt.type == "select" then
		control = string.format('<div id="c%d" class="select" data-select="%d"><div id="l%d"/><div class="grow"/><div class="arrow">v</div></div>', i, i, i)
	elseif opt.type == "action" then
		control = string.format('<div class="act" data-action="%d">%s</div>', i, hud.Escape(opt.label or opt.name or "Apply"))
	else
		control = ""
	end

	local indent = row.depth * CHILD_INDENT
	return string.format(
		'<div id="row%d" class="orow%s%s" data-row="%d"><div class="oname" style="margin-left: %ddp; padding-left: %ddp;">%s%s</div><div class="control">%s</div></div>',
		i, (opt.type == "action") and " action" or "", (row.depth > 0) and " child" or "", i,
		math_max(0, indent - CHILD_INDENT / 2), (row.depth > 0) and (CHILD_INDENT / 2) or 0,
		hud.Escape(opt.name or opt.id or ""), opt.restart and '<span class="star"> *</span>' or "", control)
end

local function SelectLabel(opt, value)
	if opt.transient then
		return opt.placeholder or "Choose..."
	end
	return opt.options[value] or "?"
end

-- everything about a row that changes without the list changing
local function ShowValues()
	for i, row in ipairs(rows) do
		local opt = row.opt
		if opt.type == "bool" then
			local value, half = Get(opt)
			view.SetClass("t" .. i, "on", value == true and half ~= 0.5)
			view.SetClass("t" .. i, "half", half == 0.5)
		elseif opt.type == "slider" then
			local value = Get(opt)
			if drag and drag.row == i then
				value = drag.value -- what the mouse says, even if it is only written on release
			end
			local position = string.format("%.1f%%", math_floor(SliderFraction(opt, value) * 1000 + 0.5) / 10)
			view.SetStyle("f" .. i, "width", position)
			view.SetStyle("h" .. i, "left", position)
			view.SetText("v" .. i, hud.Escape(FormatValue(opt, value)))
		elseif opt.type == "select" then
			view.SetText("l" .. i, hud.Escape(SelectLabel(opt, Get(opt))))
			view.SetClass("c" .. i, "none", opt.transient)
			view.SetClass("c" .. i, "open", dropRow == i)
		end
	end
end

-- what the footer says: about the option under the mouse, or how things stand
local function ShowFooter()
	local text, warn
	local opt = hoverRow and rows[hoverRow] and rows[hoverRow].opt
	if pendingReload then
		text, warn = "Reloading interface...", true
	elseif opt and opt.type ~= "separator" and not dropRow then
		local parts = {}
		if opt.desc and opt.desc ~= "" then
			parts[#parts + 1] = opt.desc
		end
		if opt.restart then
			parts[#parts + 1] = "Takes effect next game."
		end
		if opt.widget and WidgetToggleValue(opt.widget) == 0.5 then
			parts[#parts + 1] = "Widget is enabled but not running."
		end
		text = table.concat(parts, " ")
	end
	if not text or text == "" then
		if changesRequireRestart then
			text, warn = "Some changes take effect next game", true
		else
			text = "Hover an option for details"
		end
	end
	view.SetText("footer", hud.Escape(text))
	view.SetClass("footer", "warn", warn)
end

local function CloseDrop()
	if dropRow then
		dropRow = nil
		view.SetClass("drop", "hidden", true)
		view.SetClass("drop-catch", "hidden", true)
	end
end

local function Refresh()
	view.SetClass("options", "hidden", not isOpen)
	if not isOpen then
		CloseDrop()
		return
	end

	-- tabs
	local parts = {}
	for i, tab in ipairs(tabs) do
		parts[i] = string.format('<div class="tab%s" data-tab="%d">%s</div>',
			(tab.id == currentTab) and " active" or "", i, hud.Escape(tab.name or tab.id))
	end
	local markup = table.concat(parts)
	if markup ~= tabsMarkup then
		tabsMarkup = markup
		view.Element("tabs").inner_rml = markup
	end

	-- rows: rebuilt only when the rows themselves have changed
	if rowsDirty then
		BuildRows()
	end
	parts = {}
	for i, row in ipairs(rows) do
		parts[i] = RowRML(i, row)
	end
	markup = table.concat(parts)
	if markup ~= listMarkup then
		listMarkup = markup
		view.Element("list").inner_rml = markup
		view.Forget()
		hoverRow = nil
		CloseDrop()
	end

	ShowValues()
	ShowFooter()
end

--------------------------------------------------------------------------------
-- the open list of a select
--------------------------------------------------------------------------------

local function OpenDrop(i)
	local opt = rows[i] and rows[i].opt
	local box = view.Element("c" .. i)
	local drop = view.Element("drop")
	if not (opt and box and drop) then
		return
	end
	local current = (not opt.transient) and Get(opt) or nil
	local parts = {}
	for n, label in ipairs(opt.options) do
		parts[n] = string.format('<div class="choice%s" data-choice="%d">%s</div>',
			(n == current) and " current" or "", n, hud.Escape(label))
	end
	drop.inner_rml = table.concat(parts)

	-- under its box, as wide as it; above it instead when it would run off the screen
	local _, vsy = Spring.GetViewGeometry()
	local scale = hud.GetScale()
	local left, top = box.absolute_left or 0, box.absolute_top or 0
	local height = math_min(#opt.options * 22, 264) * scale + 2
	drop.style["left"] = string.format("%dpx", left)
	drop.style["width"] = string.format("%dpx", box.offset_width or 200)
	if top + (box.offset_height or 0) + height > vsy then
		drop.style["top"] = string.format("%dpx", math_max(0, top - height))
	else
		drop.style["top"] = string.format("%dpx", top + (box.offset_height or 0))
	end

	dropRow = i
	view.SetClass("drop", "hidden", false)
	view.SetClass("drop-catch", "hidden", false)
	pcall(function() drop.scroll_top = 0 end)
end

--------------------------------------------------------------------------------
-- open and close
--------------------------------------------------------------------------------

local function DefaultOrigin(vsx, vsy, w, h, scale)
	return (vsx - w) * 0.5, (vsy - h) * 0.5
end

local function Place()
	hud.PlacePanel(view.Element("options"), LAYOUT_NAME, PANEL_WIDTH, PANEL_HEIGHT, DefaultOrigin)
end

local function Open()
	if isOpen then return end
	if not document then
		openOnLoad = true
		return
	end
	isOpen = true
	rowsDirty = true
	pcall(function() document:PullToFront() end)
	PlayClickSound()
	Refresh()
end

local function Close()
	if not isOpen then return end
	isOpen = false
	drag = nil
	PlayClickSound()
	Refresh()
end

local function Toggle(state)
	if state == nil then
		if isOpen then Close() else Open() end
	elseif state then Open() else Close() end
end

--------------------------------------------------------------------------------
-- input
--------------------------------------------------------------------------------

local function SliderValueAtMouse(i)
	local opt = rows[i] and rows[i].opt
	local fraction = hud.MouseFraction(view.Element("s" .. i))
	if not opt or not fraction then
		return nil
	end
	if opt.steps then
		return opt.steps[math_floor(fraction * (#opt.steps - 1) + 0.5) + 1]
	end
	return Round(opt.min + fraction * (opt.max - opt.min), opt.step)
end

local function OnListMouseDown(event)
	if not (event.parameters and event.parameters.button == 0) then
		return
	end
	-- a slider: take hold of it
	local i = hud.EventAttribute(event, "data-slider")
	local opt = i and rows[i] and rows[i].opt
	if opt then
		local value = SliderValueAtMouse(i)
		if value ~= nil then
			drag = {row = i, value = value, changed = false}
			if not opt.applyOnRelease and value ~= Get(opt) then
				drag.changed = true
				Set(opt, value, true)
			end
			Refresh()
		end
		return
	end
	-- a select: open its list
	i = hud.EventAttribute(event, "data-select")
	if i and rows[i] then
		PlayClickSound()
		OpenDrop(i)
		ShowValues()
		return
	end
	-- an action: do it
	i = hud.EventAttribute(event, "data-action")
	if i and rows[i] then
		PlayClickSound()
		Set(rows[i].opt)
		Refresh()
		return
	end
	-- an on/off option: the whole row switches it, a much bigger target than the pill
	i = hud.EventAttribute(event, "data-row")
	opt = i and rows[i] and rows[i].opt
	if opt and opt.type == "bool" then
		PlayToggleSound()
		Set(opt, not (Get(opt) == true))
		Refresh()
	end
end

-- called every frame while a slider is held
local function FollowDrag()
	local opt = rows[drag.row] and rows[drag.row].opt
	if not opt then
		drag = nil
		return
	end
	local value = SliderValueAtMouse(drag.row)
	if value ~= nil and value ~= drag.value then
		drag.value = value
		drag.changed = true
		if not opt.applyOnRelease then
			Set(opt, value, true)
		end
		Refresh()
	end
end

-- The button came back up. RmlUi says so (see hud.OnDrag): the engine cannot,
-- once RmlUi has taken the press.
local function EndDrag()
	if not drag then
		return
	end
	local opt = rows[drag.row] and rows[drag.row].opt
	local final, changed = drag.value, drag.changed
	drag = nil
	if opt then
		if opt.applyOnRelease then
			if final ~= Get(opt) then Set(opt, final) end
		elseif changed then
			-- one final non-drag Set so reloadUI/restart flags fire once
			Set(opt, Get(opt))
		end
	end
	Refresh()
end

--------------------------------------------------------------------------------
-- text commands: /options, /option <id> [value]  (carried over unchanged)
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
-- widget api
--------------------------------------------------------------------------------

function widget:Initialize()
	local helpers = include("rml/hud.lua")
	local result, reason = helpers.LoadDocument(DOCUMENT_PATH, widget)
	if not result then
		spEcho("[Options] " .. tostring(reason))
		widgetHandler:RemoveWidget(self)
		return
	end
	hud = helpers
	hud.showInPregame = true -- a window the player opens; usable during faction choice and placement
	document = result

	view = hud.NewView(document)
	view.Assume("options", "hidden", true) -- set in the markup
	view.Assume("drop", "hidden", true)
	view.Assume("drop-catch", "hidden", true)

	-- F10 is this window's key
	spSendCommands('unbindkeyset f10')

	-- The values the old options widget kept for itself are taken over once,
	-- so nothing set there is lost.
	if next(store) == nil then
		local old = widgetHandler.configData and widgetHandler.configData[OLD_WIDGET]
		if type(old) == "table" and type(old.store) == "table" then
			for key, value in pairs(old.store) do
				store[key] = value
			end
			store["__drag"] = nil
			currentTab = currentTab or old.tab
		end
	end

	LoadDefinitions()

	hud.OnClick(view, "close", Close)
	view.Element("tabs"):AddEventListener("mousedown", function(event)
		local i = hud.EventAttribute(event, "data-tab")
		local tab = i and tabs[i]
		if tab and tab.id ~= currentTab and event.parameters and event.parameters.button == 0 then
			currentTab = tab.id
			rowsDirty = true
			PlayClickSound()
			Refresh()
			pcall(function() view.Element("list").scroll_top = 0 end)
		end
	end)
	local list = view.Element("list")
	list:AddEventListener("mousedown", OnListMouseDown)
	-- a slider's release; the rows are made on the fly, so these are heard
	-- here and the sliders get "drag: drag" from options.rml
	list:AddEventListener("mouseup", EndDrag)
	list:AddEventListener("dragend", EndDrag)
	list:AddEventListener("mouseover", function(event)
		hoverRow = hud.EventAttribute(event, "data-row")
		ShowFooter()
	end)
	list:AddEventListener("mouseout", function()
		hoverRow = nil
		ShowFooter()
	end)
	view.Element("drop"):AddEventListener("mousedown", function(event)
		local choice = hud.EventAttribute(event, "data-choice")
		local opt = dropRow and rows[dropRow] and rows[dropRow].opt
		CloseDrop()
		if opt and choice and opt.options[choice] then
			PlayClickSound()
			Set(opt, choice)
		end
		Refresh()
	end)
	hud.OnClick(view, "drop-catch", function()
		CloseDrop()
		ShowValues()
	end)

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

	hud.RegisterPanel(LAYOUT_NAME, "Options", Place, function() return isOpen end)
	Place()

	hud.ShowPassive(document)
	lastUpdate = Spring.GetTimer()
	if openOnLoad then
		openOnLoad = false
		Open()
	end
end

function widget:Shutdown()
	WG.options = nil
	if hud then
		hud.UnregisterPanel(LAYOUT_NAME)
	end
	if document then
		document:Close()
		document = nil
	end
end

function widget:ViewResize()
	if hud and document then
		hud.UpdateScale()
		Place()
		CloseDrop()
	end
end

function widget:KeyPress(key, mods, isRepeat)
	if not document then
		return false
	end
	if key == KEY_F10 and not isRepeat and not (mods.alt or mods.ctrl or mods.meta or mods.shift) then
		Toggle()
		return true
	end
	if not isOpen then
		return false
	end
	if key == KEY_ESCAPE then
		if dropRow then
			CloseDrop()
			ShowValues()
		else
			Close()
		end
		return true
	end
	if key == KEY_PAGEUP or key == KEY_PAGEDOWN then
		local list = view.Element("list")
		pcall(function()
			local page = list.client_height
			list.scroll_top = list.scroll_top + ((key == KEY_PAGEUP) and -page or page)
		end)
		return true
	end
	return false
end

function widget:Update()
	if pendingReload then
		pendingReload = false
		spSendCommands("luarules reloadluaui")
		return
	end
	if not document then
		return
	end
	if hud.FollowGuiHidden(document) or not isOpen then
		drag = nil
		return
	end
	if drag then
		FollowDrag()
		return
	end
	-- a widget being enabled or crashing changes what rows exist
	local known = widgetHandler.knownWidgets and widgetHandler.knownChanged
	if known ~= lastKnownWidgets then
		lastKnownWidgets = known
		rowsDirty = true
	end
	local now = Spring.GetTimer()
	if rowsDirty or Spring.DiffTimers(now, lastUpdate) >= UPDATE_INTERVAL then
		lastUpdate = now
		Refresh()
	end
end

function widget:GetConfigData()
	store["__drag"] = nil
	return {show = isOpen, tab = currentTab, store = store}
end

function widget:SetConfigData(data)
	if not data then return end
	if data.store then store = data.store end
	if data.tab then currentTab = data.tab end
	if data.show then Open() end
end
