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
--  after the game's own key file; uikeys.txt is never touched.
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
		desc    = "Rebind keys in-game. Writes changes to sf_uikeys.txt in the write dir; never touches uikeys.txt. (RmlUi)",
		author  = "SplinterFaction Team",
		date    = "2026-10-13",
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
local PANEL_WIDTH  = 580
local PANEL_HEIGHT = 640

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

--------------------------------------------------------------------------------
-- state
--------------------------------------------------------------------------------

local isOpen = false

local tab  = "sf" -- "sf" | "all"
local TABS = {"sf", "all"}

local sfSections = {}  -- ordered {title = , actions = {line, ...}}
local sfKnown    = {}  -- line -> true
local items      = {}  -- flat display list: {kind = "header" | "row", ...}; item i has the id "k<i>"
local listDirty  = true

local edits      = {}  -- ordered {op = "bind" | "unbind", keyset = , action = }
local editedLine = {}  -- action line -> true, for highlighting

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
-- showing
--------------------------------------------------------------------------------

local function ItemRML(i, item)
	if item.kind == "header" then
		return '<div class="khead label">' .. hud.Escape(item.label) .. '</div>'
	end
	return string.format('<div id="k%d" class="krow%s" data-k="%d"><div class="kname">%s</div><div id="k%d-b" class="badge"/></div>',
		i, editedLine[item.line] and " edited" or "", i, hud.Escape(item.label), i)
end

local function Refresh()
	view.SetClass("keybinds", "hidden", not isOpen)
	if not isOpen then
		return
	end
	view.SetClass("tab-sf", "active", tab == "sf")
	view.SetClass("tab-all", "active", tab == "all")

	if listDirty then
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
		if item.kind == "row" then
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
	else
		status = nil
		text, class = "Left click to rebind, right click to unbind. Written to " .. USER_KEYS_FILE, ""
	end
	view.SetText("status", hud.Escape(text))
	for _, name in ipairs({"text", "ok", "warn", "err"}) do
		view.SetClass("status", name, class == name)
	end

	-- the question, over the window
	view.SetClass("confirm", "hidden", confirm == nil)
	view.SetClass("confirm-dim", "hidden", confirm == nil)
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
	if confirm then
		return
	end
	local button = event.parameters and event.parameters.button
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

	view = hud.NewView(document)
	view.Assume("keybinds", "hidden", true) -- set in the markup
	view.Assume("confirm", "hidden", true)
	view.Assume("confirm-dim", "hidden", true)

	LoadEdits()
	ParseGameKeysFile()

	-- a click anywhere in the window gives up on a key being waited for; a
	-- click on a row then starts waiting for that row's key instead
	view.Element("keybinds"):AddEventListener("mousedown", function(event)
		-- (a click on a row has just been dealt with by the list, below)
		if capture and not hud.EventAttribute(event, "data-k") then
			capture = nil
			SetStatus("rebind cancelled", COL.textDim)
			Refresh()
		end
	end)
	view.Element("list"):AddEventListener("mousedown", OnListMouseDown)
	view.Element("tabs"):AddEventListener("mousedown", function(event)
		local index = hud.EventAttribute(event, "data-tab")
		if index and TABS[index] and not confirm and event.parameters and event.parameters.button == 0 then
			PlayClickSound()
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
		if not confirm then ReapplyKeys() end
	end)
	Button("reset", function()
		if not confirm then AskReset() end
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
	}

	hud.RegisterPanel(LAYOUT_NAME, "Keybinds", Place, function() return isOpen end)
	Place()

	hud.ShowPassive(document)
	lastUpdate = Spring.GetTimer()
end

function widget:Shutdown()
	WG.StaticKeybinds = nil
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

	if sym == "esc" or sym == "escape" then
		if confirm then
			confirm = nil
			Refresh()
		else
			Close()
		end
		return true
	end

	if confirm then return true end

	if sym == "pageup" or sym == "pagedown" then
		local list = view.Element("list")
		pcall(function()
			local page = list.client_height
			list.scroll_top = list.scroll_top + ((sym == "pageup") and -page or page)
		end)
		return true
	end

	return false
end

function widget:TextCommand(cmd)
	if cmd == "keybinds" then
		Toggle()
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
	if data and (data.tab == "sf" or data.tab == "all") then
		tab = data.tab
	end
end
