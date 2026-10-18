--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Keybinds window of the RmlUi HUD: rebind keys in game.
--
--  Opened from the game menu (Keybinds) or with /keybinds; Esc or the X closes
--  it. Left click a row and press a key to rebind it (Esc cancels); right
--  click a row to unbind it. If the key is already taken, the window says by
--  what and asks first.
--
--  Changes are written to sf_uikeys.txt in the write dir, which is loaded
--  after the game's own key files; uikeys.txt is never touched.
--
--  The Custom Binds tab holds the player's own named binds. Its editor builds
--  an action line from chips (command, selection source, filters, result;
--  vocabulary in LuaUI/Configs/keybind_actions.lua) or takes one typed by
--  hand, and every row in every tab has an EDIT button that opens the same
--  editor on that bind. Names are kept as "// name:" comments in
--  sf_uikeys.txt, right above the bind they belong to.
--
--  Replaces gui_static_keybinds.lua (kept in Widgets/disabled/). Reading the
--  key files, the edit list and the rebinding itself are carried over
--  unchanged, and so is the WG.StaticKeybinds interface, which the hotbind
--  widget and the game menu use.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name    = "Keybinds",
		desc    = "Rebind keys in-game and build custom named binds (selection filters, unit roles...). Writes changes to sf_uikeys.txt in the write dir; never touches uikeys.txt. (RmlUi)",
		author  = "SplinterFaction Team",
		date    = "2026-10-18",
		license = "GNU GPL, v2 or later",
		layer   = -100, -- before the game menu, so Esc closes this first
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- config
--------------------------------------------------------------------------------

local DOCUMENT_PATH = "LuaUI/rml/keybinds.rml"

-- Overridden from WG.SFKeybindings when the loader widget is present
local GAME_KEYS_FILE = "luaui/configs/sf_keys.txt"
local USER_KEYS_FILE = "sf_uikeys.txt"

-- must match #keybinds in keybinds.rml
local PANEL_WIDTH  = 720
local PANEL_HEIGHT = 700

-- chip vocabulary and selection-line parser, shared with gui_sf_select.lua
local ACTIONS_FILE = "LuaUI/Configs/keybind_actions.lua"

local PICKER_MAX = 200 -- options listed at once in the value picker

local LAYOUT_NAME = "keybinds" -- same as the old widget, so a saved position carries over

local STATUS_TIME = 6 -- seconds a status message stays up
local CONFIRM_MAX = 6 -- max conflict lines listed in the dialog

local UPDATE_INTERVAL = 0.25

-- The carried-over code names the color of a status message; here those are
-- the classes of the status line.
local COL = {text = "text", textDim = "", ok = "ok", warn = "warn", err = "err"}

--------------------------------------------------------------------------------
-- locals
--------------------------------------------------------------------------------

local spGetKeySymbol     = Spring.GetKeySymbol
local spGetKeyBindings   = Spring.GetKeyBindings
local spGetActionHotKeys = Spring.GetActionHotKeys
local spSendCommands     = Spring.SendCommands
local spPlaySoundFile    = Spring.PlaySoundFile

local math_min = math.min

local hud
local document
local view
local lastUpdate
local Refresh -- defined under "showing"; the editor's handlers call it

--------------------------------------------------------------------------------
-- state
--------------------------------------------------------------------------------

local isOpen = false

local tab  = "sf" -- "sf" | "all" | "custom"
local TABS = {"sf", "all", "custom"}

local sfSections = {}  -- ordered {title = , actions = {line, ...}}
local sfKnown    = {}  -- line -> true
local items      = {}  -- flat display list: {kind = "header" | "row", ...}; item i has the id "k<i>"
local listDirty  = true

local edits      = {}  -- ordered {op = "bind" | "unbind", keyset = , action = }
local editedLine = {}  -- action line -> true, for highlighting
local names      = {}  -- action line -> the player's name for it

local actions          -- the keybind_actions module
local editor           -- the bind editor's state while it is open (see OpenEditor)
local picker           -- the value picker's state while it is open (see OpenPicker)
local focus            -- which text field takes typing: "name" | "key" | "line" | "pick"
local unitOptions      -- cached picker options: every unit def
local paramOptions = {}-- cached picker options per customParams key

local capture          -- row currently awaiting a keypress
local confirm          -- {title, lines, onConfirm}
local status           -- {text, color, expires}
local listMarkup       -- the list's markup, as last set

local MOD_KEYS = {
	alt = true, ctrl = true, meta = true, shift = true,
	lalt = true, ralt = true, lctrl = true, rctrl = true,
	lshift = true, rshift = true, lmeta = true, rmeta = true,
	super = true, lsuper = true, rsuper = true,
}

--------------------------------------------------------------------------------
-- small helpers
--------------------------------------------------------------------------------

local function PlayClickSound() spPlaySoundFile("leftclick", 1.0, "ui") end

local function SetStatus(text, color)
	status = {text = text, color = color or COL.textDim, expires = os.clock() + STATUS_TIME}
end

--------------------------------------------------------------------------------
-- everything from here to "showing" is carried over unchanged
--------------------------------------------------------------------------------

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

	-- archive only, like the loader: a loose copy must not change what is listed
	local text = VFS.FileExists(GAME_KEYS_FILE, VFS.ZIP) and VFS.LoadFile(GAME_KEYS_FILE, VFS.ZIP)
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
	"//  Loaded after the game's key files, so unbind lines below can remove",
	"//  SF and engine defaults and bind lines can replace them.",
	"//",
	"//  Hand edits survive as long as they use plain bind / unbind lines. A",
	"//  \"// name: ...\" comment right above a bind line names it in the",
	"//  Keybinds window's Custom Binds tab.",
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
	names = {}

	local f = io.open(USER_KEYS_FILE, "r")
	if not f then
		RebuildEditedIndex()
		return
	end

	local pendingName
	for raw in f:lines() do
		raw = raw:gsub("\r", "")
		local name = raw:match("^%s*//%s*name:%s*(.-)%s*$")
		if name then
			pendingName = (name ~= "") and name or nil
		else
			local body = Trim(StripComment(raw))
			if body ~= "" then
				local verb, rest = body:match("^(%a+)%s+(.+)$")
				if verb then
					verb = verb:lower()
					if verb == "bind" or verb == "unbind" then
						local keyset, action = rest:match("^(%S+)%s+(.+)$")
						if keyset and action then
							action = Trim(action)
							edits[#edits + 1] = { op = verb, keyset = keyset, action = action }
							if verb == "bind" and pendingName then
								names[action] = pendingName
							end
						end
					end
				end
				pendingName = nil
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
		if e.op == "bind" and names[e.action] then
			f:write("// name: " .. names[e.action] .. "\n")
		end
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
	elseif tab == "custom" then
		items[#items + 1] = { kind = "new", label = "+   New custom bind" }

		-- named binds, plus unnamed selection binds the player made
		local rows, seen = {}, {}
		for i = 1, #edits do
			local e = edits[i]
			local a = e.action
			if e.op == "bind" and not seen[a]
				and (names[a] or a:match("^sfselect") or (a:match("^select ") and not sfKnown[a])) then
				seen[a] = true
				rows[#rows + 1] = a
			end
		end
		table.sort(rows, function(x, y)
			return (names[x] or x):lower() < (names[y] or y):lower()
		end)
		if #rows > 0 then
			items[#items + 1] = { kind = "header", label = "Custom binds" }
			for i = 1, #rows do
				AddRow(rows[i], names[rows[i]] or PrettyLabel(rows[i]))
			end
		else
			items[#items + 1] = { kind = "header", label = "No custom binds yet. EDIT on any row in the other tabs opens the same editor." }
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

	listDirty = false
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
	confirm = {title = title, lines = lines, onConfirm = onConfirm}
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

	if row.editorKey then
		if editor then
			editor.keyset = keyset
			SetStatus("key set to " .. keyset, COL.ok)
		end
		return
	end

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
	-- The loader owns the bind table (it drops uikeys.txt and rebuilds from
	-- the game file, engine defaults and sf_uikeys.txt). Without it there is
	-- no safe way to rebuild here: keyload only appends, keyreload brings back
	-- the shared uikeys.txt.
	if not (WG.SFKeybindings and WG.SFKeybindings.Apply) then
		SetStatus("SF Keybindings widget is not running; cannot reload binds", COL.err)
		return false
	end
	WG.SFKeybindings.Apply()
	listDirty = true
	SetStatus("keybind files reloaded", COL.ok)
	return true
end

local function ResetAll()
	edits = {}
	editedLine = {}
	SaveEdits()

	-- sf_uikeys.txt is now empty, so a rebuild leaves SF binds + engine defaults
	if ReapplyKeys() then
		SetStatus("all rebinds cleared", COL.warn)
	end
	listDirty = true
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
-- Bind editor
--
-- editor = {
--   name     = "",            -- display name (optional)
--   keyset   = "",            -- "Ctrl+c"
--   verb     = "select",      -- key from actions.verbs; "" is free text
--   verbArg  = nil,           -- text after a non-builder verb (or joined to it)
--   spec     = {...},         -- parsed selection, for the builder verbs
--   manual   = false,         -- the action line was typed and does not parse
--   line     = "",            -- the action line as shown
--   original = {line=, keys=} -- when editing an existing bind
--   isUser   = bool,          -- the original is one of the player's own binds
-- }
--------------------------------------------------------------------------------

-- like hud.EventAttribute, for a string attribute
local function EventString(event, attribute)
	local element = event.target_element
	for _ = 1, 10 do
		if not element then return nil end
		if element:HasAttribute(attribute) then
			return element:GetAttribute(attribute)
		end
		element = element.parent_node
	end
	return nil
end

-- drops the last UTF-8 code point
local function Utf8Backspace(s)
	local i = #s
	while i > 1 and s:byte(i) >= 0x80 and s:byte(i) < 0xC0 do
		i = i - 1
	end
	return s:sub(1, i - 1)
end

local function NewSpec()
	return { source = { key = "AllMap" }, filters = {}, clear = true, result = { key = "SelectAll" } }
end

local function IsUserBind(line)
	for i = 1, #edits do
		if edits[i].op == "bind" and edits[i].action == line then
			return true
		end
	end
	return false
end

local function IsBuilderVerb(key)
	local v = actions.verbByKey[key]
	return v and v.builder or false
end

-- the action line for the editor's current chips
local function ComposeLine()
	local e = editor
	if e.manual then return e.line end
	local verb = actions.verbByKey[e.verb]
	if verb and verb.builder then
		return actions.Format(e.spec) or ""
	end
	if verb and verb.joined then
		return e.verb .. (e.verbArg or "")
	end
	if e.verb == "" then
		return e.verbArg or ""
	end
	if e.verbArg and e.verbArg ~= "" then
		return e.verb .. " " .. e.verbArg
	end
	return e.verb
end

local function SyncLineFromChips()
	editor.line = ComposeLine()
end

-- the chips from the action line, when it parses
local function SyncChipsFromLine()
	local e = editor
	local line = Trim(e.line)
	local _, spec = actions.Parse(line)
	if spec then
		e.verb, e.spec, e.manual, e.verbArg = "select", spec, false, nil
		return
	end
	local word, rest = line:match("^(%S+)%s*(.*)$")
	if word then
		local lower = word:lower()
		if lower == "select" or lower == "sfselect" then
			e.manual = true -- a selection that does not parse: keep as typed
			return
		end
		for _, v in ipairs(actions.verbs) do
			if v.joined and lower:sub(1, #v.key) == v.key then
				e.verb, e.verbArg, e.manual = v.key, word:sub(#v.key + 1), false
				return
			end
		end
		local v = actions.verbByKey[lower]
		if v and not v.builder then
			e.verb, e.verbArg, e.manual = v.key, rest, false
			return
		end
	end
	e.verb, e.verbArg, e.manual = "", line, false
end

local function OpenEditor(row)
	picker, focus, capture, confirm = nil, nil, nil, nil
	editor = {
		name = "", keyset = "", verb = "select", spec = NewSpec(),
		verbArg = nil, manual = false, line = "", original = nil, isUser = false,
	}
	if row then
		editor.original = { line = row.line, keys = row.keys }
		editor.keyset   = row.keys[1] or ""
		editor.name     = names[row.line] or ""
		editor.line     = row.line
		editor.isUser   = IsUserBind(row.line)
		SyncChipsFromLine()
	else
		SyncLineFromChips()
		focus = "name"
	end
	listMarkup = nil -- the list is rebuilt when the editor closes
end

local function CloseEditor()
	editor, picker, focus, capture = nil, nil, nil, nil
	listDirty = true
end

--------------------------------------------------------------------------------
-- value picker: a list to choose from, or a value to type
-- picker = { title, kind = "list" | "value", options = { {label, sub, value} },
--            query, onPick(value), visible = {options shown} }
--------------------------------------------------------------------------------

local function OpenPicker(title, kind, options, current, onPick)
	picker = { title = title, kind = kind, options = options or {}, query = current or "", onPick = onPick, visible = {} }
	focus = "pick"
end

local function ClosePicker()
	picker = nil
	if focus == "pick" then focus = nil end
end

local function PickValue(value)
	local onPick = picker and picker.onPick
	ClosePicker()
	if onPick and value and value ~= "" then
		onPick(value)
	end
end

-- Enter / OK: the first listed match, else what was typed
local function PickerAccept()
	if not picker then return end
	if picker.kind == "list" and picker.visible[1] and Trim(picker.query) ~= "" then
		PickValue(picker.visible[1].value)
	elseif picker.kind == "list" and Trim(picker.query) == "" then
		SetStatus("type to search, or click an entry", COL.textDim)
	else
		PickValue(Trim(picker.query))
	end
end

local function UnitOptions()
	if unitOptions then return unitOptions end
	unitOptions = {}
	for udid, ud in pairs(UnitDefs) do
		local human = ud.translatedHumanName or ud.humanName or ud.name
		unitOptions[#unitOptions + 1] = { label = human, sub = ud.name, value = ud.name }
	end
	table.sort(unitOptions, function(a, b) return a.label:lower() < b.label:lower() end)
	return unitOptions
end

local function ParamOptions(param)
	if paramOptions[param] then return paramOptions[param] end
	local seen, out = {}, {}
	for _, ud in pairs(UnitDefs) do
		local v = ud.customParams and ud.customParams[param]
		if v ~= nil then
			v = tostring(v)
			if not seen[v] then
				seen[v] = true
				out[#out + 1] = { label = v, value = v }
			end
		end
	end
	table.sort(out, function(a, b) return a.label:lower() < b.label:lower() end)
	paramOptions[param] = out
	return out
end

-- picker for a chip's value (filter, source, result or verb argument)
local function OpenArgPicker(def, current, onPick)
	local title = def.label .. ": " .. (def.argLabel or def.arg or "value")
	if def.arg == "unit" then
		OpenPicker(def.label .. ": which unit?", "list", UnitOptions(), current, onPick)
	elseif def.arg == "param" then
		OpenPicker(def.label .. ": which value?", "list", ParamOptions(def.param), current, onPick)
	else
		OpenPicker(title, "value", nil, current, onPick)
	end
end

--------------------------------------------------------------------------------
-- chip clicks
--------------------------------------------------------------------------------

local function FindFilter(key)
	for i, f in ipairs(editor.spec.filters) do
		if f.key == key then return f, i end
	end
	return nil
end

-- a chip pressed while the typed line does not parse starts a fresh selection
local function EnsureSpec()
	if editor.manual or not editor.spec then
		editor.manual = false
		editor.spec = NewSpec()
	end
end

local function ChipClick(kind, index, button)
	local e = editor
	if kind == "verb" then
		local v = actions.verbs[index]
		if not v or v.hidden then return end
		e.verb, e.manual = v.key, false
		if v.builder then
			e.spec = e.spec or NewSpec()
			SyncLineFromChips()
		elseif v.arg == "unit" then
			OpenArgPicker(v, e.verbArg, function(value)
				e.verbArg = value
				SyncLineFromChips()
			end)
			e.verbArg = e.verbArg or ""
			SyncLineFromChips()
		elseif v.arg == "text" then
			e.verbArg = e.verbArg or ""
			SyncLineFromChips()
			focus = "line"
		else
			e.verbArg = nil
			SyncLineFromChips()
		end
		return
	end

	EnsureSpec()
	local spec = e.spec

	if kind == "src" then
		local src = actions.sources[index]
		if not src then return end
		if src.arg then
			OpenArgPicker(src, spec.source.key == src.key and spec.source.arg or nil, function(value)
				spec.source = { key = src.key, arg = value }
				SyncLineFromChips()
			end)
		else
			spec.source = { key = src.key }
			SyncLineFromChips()
		end
	elseif kind == "flt" then
		local def = actions.filters[index]
		if not def then return end
		local existing, at = FindFilter(def.key)
		if existing and button == 1 and def.arg then
			-- right click: change the value
			OpenArgPicker(def, existing.arg, function(value)
				existing.arg = value
				SyncLineFromChips()
			end)
		elseif not existing then
			if def.arg then
				OpenArgPicker(def, nil, function(value)
					spec.filters[#spec.filters + 1] = { key = def.key, isNot = false, arg = value }
					SyncLineFromChips()
				end)
			else
				spec.filters[#spec.filters + 1] = { key = def.key, isNot = false }
				SyncLineFromChips()
			end
		elseif not existing.isNot then
			existing.isNot = true
			SyncLineFromChips()
		else
			table.remove(spec.filters, at)
			SyncLineFromChips()
		end
	elseif kind == "res" then
		local def = actions.results[index]
		if not def then return end
		if def.arg then
			OpenArgPicker(def, spec.result and spec.result.key == def.key and spec.result.arg or nil, function(value)
				spec.result = { key = def.key, arg = value }
				SyncLineFromChips()
			end)
		else
			spec.result = { key = def.key }
			SyncLineFromChips()
		end
	elseif kind == "clear" then
		spec.clear = not spec.clear
		SyncLineFromChips()
	end
end

--------------------------------------------------------------------------------
-- typing into a field
--------------------------------------------------------------------------------

local function FieldGet()
	if focus == "pick" then return picker and picker.query or "" end
	if not editor then return "" end
	if focus == "name" then return editor.name end
	if focus == "key" then return editor.keyset end
	if focus == "line" then return editor.line end
	return ""
end

local function FieldSet(text)
	if focus == "pick" then
		if picker then picker.query = text end
	elseif editor then
		if focus == "name" then
			editor.name = text
		elseif focus == "key" then
			editor.keyset = text
		elseif focus == "line" then
			editor.line = text
			SyncChipsFromLine()
		end
	end
end

local function FieldAppend(utf8)
	if utf8 == "\n" or utf8 == "\r" then return end
	FieldSet(FieldGet() .. utf8)
end

local function FieldBackspace()
	FieldSet(Utf8Backspace(FieldGet()))
end

--------------------------------------------------------------------------------
-- save / delete
--------------------------------------------------------------------------------

local function SaveEditor()
	local e = editor
	local keyset = Trim(e.keyset)
	local line   = Trim(e.line)
	local name   = Trim(e.name)
	if line == "" then
		SetStatus("the action line is empty", COL.err)
		return
	end
	if keyset == "" then
		SetStatus("set a key first", COL.err)
		return
	end
	local verb, spec = actions.Parse(line)
	if (verb == "select" or verb == "sfselect") and not spec then
		SetStatus("that selection line does not parse; check the filters", COL.err)
		return
	end
	if spec then
		line = actions.Format(spec) -- normalized; picks select or sfselect
	end

	local orig = e.original
	local sameBind = orig and orig.line == line and #orig.keys == 1 and orig.keys[1]:lower() == keyset:lower()

	local conflicts = {}
	for _, c in ipairs(GetConflicts(keyset, line)) do
		if not (orig and c.line == orig.line) then
			conflicts[#conflicts + 1] = c
		end
	end

	local function Commit()
		if not sameBind then
			if orig then
				for i = 1, #orig.keys do
					AddEdit("unbind", orig.keys[i], orig.line)
				end
				if orig.line ~= line then
					names[orig.line] = nil
				end
			end
			for i = 1, #conflicts do
				AddEdit("unbind", conflicts[i].boundWith, conflicts[i].line)
			end
			AddEdit("bind", keyset, line)
		end
		names[line] = (name ~= "") and name or nil
		SaveEdits()
		SetStatus(keyset .. "  ->  " .. ((name ~= "") and name or line), COL.ok)
		CloseEditor()
		if spec and not actions.IsEngineNative(spec) and not WG.SFSelect then
			SetStatus("saved, but the SF Select widget is not running, so this bind will do nothing", COL.warn)
		end
	end

	if #conflicts == 0 then
		Commit()
		return
	end
	local lines = {}
	for i = 1, math_min(#conflicts, CONFIRM_MAX) do
		lines[#lines + 1] = conflicts[i].boundWith .. "   " .. conflicts[i].line
	end
	if #conflicts > CONFIRM_MAX then
		lines[#lines + 1] = "... and " .. (#conflicts - CONFIRM_MAX) .. " more"
	end
	OpenConfirm(keyset .. " is already bound to:", lines, Commit)
end

-- Removes the bind being edited: its keys are unbound (recorded, so an SF or
-- engine bind stays unbound) and its own bind lines leave the file.
local function DeleteEditor()
	local orig = editor and editor.original
	if not orig then return end
	for i = #edits, 1, -1 do
		if edits[i].action == orig.line then
			table.remove(edits, i)
		end
	end
	RebuildEditedIndex()
	for i = 1, #orig.keys do
		AddEdit("unbind", orig.keys[i], orig.line)
	end
	names[orig.line] = nil
	SaveEdits()
	SetStatus("removed " .. (orig.line), COL.warn)
	CloseEditor()
end

--------------------------------------------------------------------------------
-- editor and picker markup
--------------------------------------------------------------------------------

local function SetField(id, text, placeholder, focused)
	local shown = (text ~= "") and text or placeholder
	view.SetText(id, hud.Escape(shown) .. (focused and "|" or ""))
	view.SetClass(id, "placeholder", text == "")
	view.SetClass(id, "focused", focused)
end

local function ChipRML(kind, index, label, state, custom)
	return string.format('<div class="chip %s%s" data-act="chip:%s:%d">%s</div>',
		state, custom and " custom" or "", kind, index, hud.Escape(label))
end

local function RenderEditor()
	view.SetClass("list", "hidden", editor ~= nil)
	view.SetClass("editor", "hidden", editor == nil)
	if not editor then return end
	local e = editor

	SetField("ed-name", e.name, "name (optional)", focus == "name")
	local waiting = capture and capture.editorKey
	view.SetText("ed-key", hud.Escape(waiting and "press a key..." or ((e.keyset ~= "") and e.keyset or "click to set")))
	view.SetClass("ed-key", "capturing", waiting and true or false)
	view.SetClass("ed-key", "unbound", not waiting and e.keyset == "")
	SetField("ed-keytext", e.keyset, "or type a keyset, e.g. Ctrl+Shift+q", focus == "key")

	local parts = {}
	for i, v in ipairs(actions.verbs) do
		if not v.hidden then
			local on = (e.verb == v.key) or (v.builder and IsBuilderVerb(e.verb))
			parts[#parts + 1] = ChipRML("verb", i, v.label, on and "on" or "off", false)
		end
	end
	view.SetText("ed-verbs", table.concat(parts))

	local builder = IsBuilderVerb(e.verb) or e.manual
	view.SetClass("ed-select", "hidden", not builder)
	if builder then
		local spec = e.spec or NewSpec()
		local disabled = e.manual
		parts = {}
		for i, src in ipairs(actions.sources) do
			local on = not disabled and spec.source and spec.source.key == src.key
			local label = src.label
			if on and src.arg and spec.source.arg then label = label .. " = " .. spec.source.arg end
			parts[#parts + 1] = ChipRML("src", i, label, on and "on" or "off", not src.engine)
		end
		view.SetText("ed-sources", table.concat(parts))
		view.SetClass("ed-sources", "disabled", disabled)

		parts = {}
		for i, def in ipairs(actions.filters) do
			local state, label = "off", def.label
			if not disabled then
				for _, f in ipairs(spec.filters) do
					if f.key == def.key then
						state = f.isNot and "not" or "on"
						if f.arg then label = (f.isNot and "NOT " or "") .. label .. " = " .. f.arg
						elseif f.isNot then label = "NOT " .. label end
						break
					end
				end
			end
			parts[#parts + 1] = ChipRML("flt", i, label, state, not def.engine)
		end
		view.SetText("ed-filters", table.concat(parts))
		view.SetClass("ed-filters", "disabled", disabled)

		parts = { ChipRML("clear", 0, "Clear selection first", (not disabled and spec.clear) and "on" or "off", false) }
		for i, r in ipairs(actions.results) do
			local on = not disabled and spec.result and spec.result.key == r.key
			local label = r.label
			if on and r.arg and spec.result.arg then label = label .. " = " .. spec.result.arg end
			parts[#parts + 1] = ChipRML("res", i, label, on and "on" or "off", not r.engine)
		end
		view.SetText("ed-results", table.concat(parts))
		view.SetClass("ed-results", "disabled", disabled)
	end

	SetField("ed-line", e.line, "the action the key runs", focus == "line")
	view.SetClass("ed-line", "bad", e.manual)
	local hint
	if e.manual then
		hint = "This selection line does not parse. It is saved as typed; fix it or click a chip to start over."
	elseif builder and e.spec then
		hint = actions.IsEngineNative(e.spec) and "Runs through the engine's own select."
			or "Uses SF filters, so it runs through sfselect (the SF Select widget)."
	elseif e.verb == "" then
		hint = "Any console action, e.g. luaui showhealthbars, or a unit's buildunit_<name>."
	else
		hint = ""
	end
	view.SetText("ed-hint", hud.Escape(hint))

	view.SetClass("ed-delete", "hidden", e.original == nil)
	view.SetText("ed-save", e.original and "Save" or "Add bind")
end

local function RenderPicker()
	view.SetClass("picker", "hidden", picker == nil)
	if not picker then return end
	view.SetText("picker-title", hud.Escape(picker.title))
	SetField("picker-search", picker.query, picker.kind == "list" and "type to search" or "type a value", focus == "pick")
	view.SetClass("picker-list", "hidden", picker.kind ~= "list")
	if picker.kind ~= "list" then return end

	local q = picker.query:lower()
	local visible, parts = {}, {}
	for _, opt in ipairs(picker.options) do
		if q == "" or opt.label:lower():find(q, 1, true) or (opt.sub and opt.sub:lower():find(q, 1, true)) then
			visible[#visible + 1] = opt
			if #visible <= PICKER_MAX then
				parts[#parts + 1] = string.format('<div class="popt" data-act="opt:%d">%s%s</div>',
					#visible, hud.Escape(opt.label),
					(opt.sub and opt.sub ~= opt.label) and ('   <span class="sub">' .. hud.Escape(opt.sub) .. '</span>') or "")
			end
		end
	end
	if #visible > PICKER_MAX then
		parts[#parts + 1] = '<div class="popt sub">... and ' .. (#visible - PICKER_MAX) .. ' more, keep typing</div>'
	elseif #visible == 0 then
		parts[#parts + 1] = '<div class="popt sub">nothing matches; Enter uses what you typed</div>'
	end
	picker.visible = visible
	view.SetText("picker-list", table.concat(parts))
end

--------------------------------------------------------------------------------
-- editor and picker clicks (one listener each; data-act says what was hit)
--------------------------------------------------------------------------------

local function OnEditorMouseDown(event)
	if not editor or confirm or picker then return end
	local button = event.parameters and event.parameters.button
	local act = EventString(event, "data-act")
	if capture and capture.editorKey and act ~= "capture" then
		capture = nil
	end
	if not act then
		focus = nil
		Refresh()
		return
	end
	local kind, rest = act:match("^(%a+):?(.*)$")
	if kind == "field" then
		focus = rest
		capture = nil
	elseif act == "capture" and button == 0 then
		PlayClickSound()
		focus = nil
		capture = { editorKey = true }
		SetStatus("press a key for this bind  (Esc cancels)", COL.text)
	elseif kind == "chip" then
		local ck, ci = rest:match("^(%a+):(%d+)$")
		if ck then
			PlayClickSound()
			focus = nil
			ChipClick(ck, tonumber(ci), button)
		end
	elseif act == "save" and button == 0 then
		PlayClickSound()
		SaveEditor()
	elseif act == "delete" and button == 0 then
		PlayClickSound()
		focus = nil
		OpenConfirm("Remove this bind?", { editor.keyset .. "   " .. editor.line }, DeleteEditor)
		confirm.note = "Its key is unbound and the bind leaves " .. USER_KEYS_FILE .. "."
	elseif act == "cancel" and button == 0 then
		PlayClickSound()
		CloseEditor()
		SetStatus("edit cancelled", COL.textDim)
	end
	Refresh()
end

local function OnPickerMouseDown(event)
	if not picker then return end
	local button = event.parameters and event.parameters.button
	local act = EventString(event, "data-act")
	if act == "field:pick" then
		focus = "pick"
	elseif act == "pick-ok" and button == 0 then
		PlayClickSound()
		PickerAccept()
	elseif act == "pick-cancel" and button == 0 then
		PlayClickSound()
		ClosePicker()
	elseif act and act:match("^opt:%d+$") and button == 0 then
		local opt = picker.visible[tonumber(act:match("%d+"))]
		if opt then
			PlayClickSound()
			PickValue(opt.value)
		end
	end
	Refresh()
end

--------------------------------------------------------------------------------
-- showing
--------------------------------------------------------------------------------

local function ItemRML(i, item)
	if item.kind == "header" then
		return '<div class="khead label">' .. hud.Escape(item.label) .. '</div>'
	end
	if item.kind == "new" then
		return '<div class="krow new" data-new="1"><div class="kname">' .. hud.Escape(item.label) .. '</div></div>'
	end
	return string.format('<div id="k%d" class="krow%s" data-k="%d"><div class="kname">%s</div><div class="rowedit" data-edit="%d">edit</div><div id="k%d-b" class="badge"/></div>',
		i, editedLine[item.line] and " edited" or "", i, hud.Escape(item.label), i, i)
end

Refresh = function()
	view.SetClass("keybinds", "hidden", not isOpen)
	if not isOpen then
		return
	end
	view.SetClass("tab-sf", "active", tab == "sf")
	view.SetClass("tab-all", "active", tab == "all")
	view.SetClass("tab-custom", "active", tab == "custom")

	RenderEditor()
	RenderPicker()

	if listDirty and not editor then
		BuildList()
		-- the row waiting for a key is one of the old rows: find it again
		if capture then
			local line = capture.line
			capture = nil
			for i = 1, #items do
				if items[i].line == line then
					capture = items[i]
					break
				end
			end
		end
	end
	local parts = {}
	for i, item in ipairs(items) do
		parts[i] = ItemRML(i, item)
	end
	local markup = table.concat(parts)
	if markup ~= listMarkup then
		listMarkup = markup
		view.Element("list").inner_rml = markup
		view.Forget()
	end

	-- what each row is bound to
	for i, item in ipairs(items) do
		if item.kind == "row" and not editor then
			local waiting = (capture == item)
			local text
			if waiting then
				text = "press a key..."
			elseif #item.keys == 0 then
				text = "unbound"
			else
				text = table.concat(item.keys, ", ")
			end
			view.SetText("k" .. i .. "-b", hud.Escape(text))
			view.SetClass("k" .. i .. "-b", "unbound", not waiting and #item.keys == 0)
			view.SetClass("k" .. i, "capturing", waiting)
		end
	end

	-- status line
	local text, class
	if status and os.clock() < status.expires then
		text, class = status.text, status.color
	elseif editor then
		status = nil
		text, class = "Chips build the action line, or type it. Right click a value chip to change its value.", ""
	else
		status = nil
		text, class = "Left click to rebind, right click to unbind, EDIT for the full editor. Written to " .. USER_KEYS_FILE, ""
	end
	view.SetText("status", hud.Escape(text))
	for _, name in ipairs({"text", "ok", "warn", "err"}) do
		view.SetClass("status", name, class == name)
	end

	-- the question, over the window
	view.SetClass("confirm", "hidden", confirm == nil)
	view.SetClass("confirm-dim", "hidden", confirm == nil and picker == nil)
	if confirm then
		view.SetText("confirm-title", hud.Escape(confirm.title))
		local lines = {}
		for i, line in ipairs(confirm.lines) do
			lines[i] = "<div>" .. hud.Escape(line) .. "</div>"
		end
		view.SetText("confirm-lines", table.concat(lines))
		view.SetText("confirm-note", confirm.note or "Confirming will unbind the actions listed above.")
	end
end

--------------------------------------------------------------------------------
-- open and close
--------------------------------------------------------------------------------

local function DefaultOrigin(vsx, vsy, w, h, scale)
	return (vsx - w) * 0.5, (vsy - h) * 0.5
end

local function Place()
	hud.PlacePanel(view.Element("keybinds"), LAYOUT_NAME, PANEL_WIDTH, PANEL_HEIGHT, DefaultOrigin)
end

local function Open()
	if isOpen or not document then return end
	isOpen  = true
	capture = nil
	confirm = nil
	editor, picker, focus = nil, nil, nil
	-- every key is ours while the window is open: typing a name must not open
	-- the share window on "h", and capturing a key must not run what that key
	-- is bound to
	if widgetHandler.TakeKeyboard then
		widgetHandler:TakeKeyboard()
	end
	LoadEdits()
	ParseGameKeysFile()
	listDirty = true
	pcall(function() document:PullToFront() end)
	PlayClickSound()
	Refresh()
end

local function Close()
	if not isOpen then return end
	isOpen  = false
	capture = nil
	confirm = nil
	editor, picker, focus = nil, nil, nil
	if widgetHandler.ReleaseKeyboard then
		widgetHandler:ReleaseKeyboard()
	end
	PlayClickSound()
	Refresh()
end

local function Toggle()
	if isOpen then Close() else Open() end
end

--------------------------------------------------------------------------------
-- input
--------------------------------------------------------------------------------

-- RmlUi numbers the buttons left 0, right 1
local function OnListMouseDown(event)
	if confirm or editor or picker then
		return
	end
	local button = event.parameters and event.parameters.button

	if button == 0 and hud.EventAttribute(event, "data-new") then
		PlayClickSound()
		capture = nil
		OpenEditor(nil)
		Refresh()
		return
	end
	local editIndex = hud.EventAttribute(event, "data-edit")
	if button == 0 and editIndex and items[editIndex] and items[editIndex].kind == "row" then
		PlayClickSound()
		capture = nil
		OpenEditor(items[editIndex])
		Refresh()
		return
	end

	local index = hud.EventAttribute(event, "data-k")
	local row = index and items[index]
	if not row or row.kind ~= "row" then
		return
	end
	if button == 0 then
		PlayClickSound()
		BeginCapture(row)
	elseif button == 1 then
		PlayClickSound()
		capture = nil
		ClearBinding(row)
	end
	Refresh()
end

local function AskReset()
	if #edits == 0 then
		SetStatus("no rebinds to clear", COL.textDim)
		return
	end
	OpenConfirm("Clear all " .. #edits .. " rebinds from " .. USER_KEYS_FILE .. "?", {
		"Keys return to SF defaults plus your uikeys.txt.",
	}, ResetAll)
	confirm.note = "This cannot be undone."
end

--------------------------------------------------------------------------------
-- widget api
--------------------------------------------------------------------------------

function widget:Initialize()
	local helpers = include("rml/hud.lua")
	local result, reason = helpers.LoadDocument(DOCUMENT_PATH, widget)
	if not result then
		Spring.Echo("[Keybinds] " .. tostring(reason))
		widgetHandler:RemoveWidget()
		return
	end
	hud = helpers
	hud.showInPregame = true -- a window the player opens; usable during faction choice and placement
	document = result

	if WG.SFKeybindings then
		GAME_KEYS_FILE = WG.SFKeybindings.gameFile or GAME_KEYS_FILE
		USER_KEYS_FILE = WG.SFKeybindings.userFile or USER_KEYS_FILE
	end

	actions = VFS.Include(ACTIONS_FILE, nil, VFS.ZIP)
	if type(actions) ~= "table" or not actions.Parse then
		Spring.Echo("[Keybinds] could not load " .. ACTIONS_FILE)
		widgetHandler:RemoveWidget()
		return
	end

	view = hud.NewView(document)
	view.Assume("keybinds", "hidden", true) -- set in the markup
	view.Assume("confirm", "hidden", true)
	view.Assume("confirm-dim", "hidden", true)
	view.Assume("editor", "hidden", true)
	view.Assume("picker", "hidden", true)

	LoadEdits()
	ParseGameKeysFile()

	-- a click anywhere in the window gives up on a key being waited for; a
	-- click on a row then starts waiting for that row's key instead
	view.Element("keybinds"):AddEventListener("mousedown", function(event)
		-- (a click on a row has just been dealt with by the list, below; the
		-- editor's own key badge keeps its capture)
		if capture and capture.editorKey then
			if EventString(event, "data-act") ~= "capture" then
				capture = nil
				SetStatus("key capture cancelled", COL.textDim)
				Refresh()
			end
		elseif capture and not hud.EventAttribute(event, "data-k") then
			capture = nil
			SetStatus("rebind cancelled", COL.textDim)
			Refresh()
		end
	end)
	view.Element("list"):AddEventListener("mousedown", OnListMouseDown)
	view.Element("editor"):AddEventListener("mousedown", OnEditorMouseDown)
	view.Element("picker"):AddEventListener("mousedown", OnPickerMouseDown)
	view.Element("tabs"):AddEventListener("mousedown", function(event)
		local index = hud.EventAttribute(event, "data-tab")
		if index and TABS[index] and not confirm and not picker and event.parameters and event.parameters.button == 0 then
			PlayClickSound()
			if editor then
				CloseEditor()
			end
			if tab ~= TABS[index] then
				tab = TABS[index]
				listDirty = true
				Refresh()
				pcall(function() view.Element("list").scroll_top = 0 end)
			end
		end
	end)
	local function Button(id, action)
		hud.OnClick(view, id, function()
			PlayClickSound()
			action()
			Refresh()
		end)
	end
	hud.OnClick(view, "close", Close)
	Button("reapply", function()
		if not confirm and not editor then ReapplyKeys() end
	end)
	Button("reset", function()
		if not confirm and not editor then AskReset() end
	end)
	Button("confirm-yes", function()
		local onConfirm = confirm and confirm.onConfirm
		confirm = nil
		if onConfirm then onConfirm() end
	end)
	Button("confirm-no", function()
		confirm = nil
		SetStatus("cancelled", COL.textDim)
	end)

	WG.StaticKeybinds = {
		Toggle     = Toggle,
		Show       = Open,
		Hide       = Close,
		IsOpen     = function() return isOpen end,

		Bind       = API_Bind,
		Unbind     = API_Unbind,
		GetHotKeys = HotKeysFor,
		UserFile   = function() return USER_KEYS_FILE end,
		GetName    = function(line) return names[line] end,
		NewBind    = function() Open(); OpenEditor(nil); Refresh() end,
	}

	hud.RegisterPanel(LAYOUT_NAME, "Keybinds", Place, function() return isOpen end)
	Place()

	hud.ShowPassive(document)
	lastUpdate = Spring.GetTimer()
end

function widget:Shutdown()
	WG.StaticKeybinds = nil
	if widgetHandler.ReleaseKeyboard then
		widgetHandler:ReleaseKeyboard()
	end
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
	end
end

function widget:KeyPress(key, mods, isRepeat)
	if not document or not isOpen then return false end

	local sym = spGetKeySymbol(key)

	if capture then
		if sym == "esc" or sym == "escape" then
			capture = nil
			SetStatus("rebind cancelled", COL.textDim)
			Refresh()
			return true
		end
		if isRepeat then return true end

		local keyset = KeysetFromKey(key, mods)
		if keyset then
			FinishCapture(keyset)
			Refresh()
		end
		return true -- swallow everything while capturing
	end

	-- a text field is taking the keys
	if focus and (editor or picker) then
		if sym == "esc" or sym == "escape" then
			if focus == "pick" then ClosePicker() else focus = nil end
			Refresh()
			return true
		end
		if sym == "backspace" then
			FieldBackspace()
			Refresh()
			return true
		end
		if sym == "return" or sym == "enter" or sym == "numpad_enter" or sym == "kp_enter" then
			if focus == "pick" then PickerAccept() else focus = nil end
			Refresh()
			return true
		end
		if sym == "tab" then
			if focus == "name" then focus = "key" elseif focus == "key" then focus = "line" else focus = nil end
			Refresh()
			return true
		end
		return true -- the character itself arrives through TextInput
	end

	if sym == "esc" or sym == "escape" then
		if confirm then
			confirm = nil
		elseif picker then
			ClosePicker()
		elseif editor then
			CloseEditor()
			SetStatus("edit cancelled", COL.textDim)
		else
			Close()
			return true
		end
		Refresh()
		return true
	end

	if confirm or picker then return true end
	if editor then
		if sym == "return" or sym == "enter" then
			SaveEditor()
			Refresh()
		end
		return true
	end

	if sym == "pageup" or sym == "pagedown" then
		local list = view.Element("list")
		pcall(function()
			local page = list.client_height
			list.scroll_top = list.scroll_top + ((sym == "pageup") and -page or page)
		end)
		return true
	end

	-- the window owns the keyboard while open (widgetHandler:TakeKeyboard), so
	-- anything else pressed here goes nowhere; the game is a Close away
	return true
end

function widget:TextInput(utf8)
	if not document or not isOpen or not focus or not (editor or picker) then
		return false
	end
	FieldAppend(utf8)
	Refresh()
	return true
end

function widget:TextCommand(cmd)
	if cmd == "keybinds" then
		Toggle()
		return true
	end
	if cmd == "keybinds new" then
		Open()
		OpenEditor(nil)
		Refresh()
		return true
	end
	return false
end

function widget:Update()
	if not document then
		return
	end
	if hud.FollowGuiHidden(document) or not isOpen then
		return
	end
	local now = Spring.GetTimer()
	if listDirty or Spring.DiffTimers(now, lastUpdate) >= UPDATE_INTERVAL then
		lastUpdate = now
		Refresh()
	end
end

function widget:GetConfigData()
	return {tab = tab}
end

function widget:SetConfigData(data)
	if data and (data.tab == "sf" or data.tab == "all" or data.tab == "custom") then
		tab = data.tab
	end
end
