--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Information window of the RmlUi HUD, in three tabs:
--
--    Game      the game, engine and map, and the mod options of this match
--              (those that differ from their defaults first, and marked)
--    Controls  what the mouse and the keys do (LuaUI/Configs/EVO_HotkeyInfo.lua)
--    Commands  the engine's console commands (commandlist.txt)
--
--  The "i" key opens it; so does the game menu. Esc closes it.
--
--  Replaces three widgets by Floris, each of which was a window of its own:
--  gui_gameinfo.lua, gui_keybind_info.lua and gui_commands_info.lua (kept in
--  Widgets/disabled/). Their interfaces are still offered: WG['gameinfo'],
--  WG['keybinds'] and WG['commands'], each with toggle(state), open this
--  window on the matching tab.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name    = "Game info",
		desc    = "Game, map and mod option facts, the controls, and the console commands, in one window (RmlUi)",
		author  = "Floris; SplinterFaction Team",
		date    = "2026-10-13",
		license = "GNU GPL, v2 or later",
		layer   = 2,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- config
--------------------------------------------------------------------------------

local DOCUMENT_PATH = "LuaUI/rml/info.rml"

-- must match #info in info.rml
local PANEL_WIDTH  = 1000
local PANEL_HEIGHT = 640

local LAYOUT_NAME = "gameinfo"

local HOTKEY_FILE  = "LuaUI/Configs/EVO_HotkeyInfo.lua"
local COMMAND_FILE = "commandlist.txt"
local HOTKEY_COLUMNS = { "General", "Units_I_II", "Units_III" } -- tables in HOTKEY_FILE

local TAB_COUNT = 3

-- engine mod options that modoptions.lua does not list
local ENGINE_DEFAULTS = {
	maxspeed = "3",
	minspeed = "0.3",
	startmetal = "1000",
	startenergy = "1000",
	fixedallies = "1",
	maxunits = "2000",
	disablemapdamage = "0",
}

local hud
local document
local view

local isOpen = false
local tab = 1
local pages = {}   -- tab -> RML, built the first time the tab is shown
local shownTab = nil
local toggleGame, actionHandler

--------------------------------------------------------------------------------
-- the pages
--------------------------------------------------------------------------------

local function Row(name, value, changed)
	return string.format('<div class="row%s"><div class="k">%s</div><div class="v">%s</div></div>',
		changed and " changed" or "", hud.Escape(tostring(name)), hud.Escape(tostring(value)))
end

local function Head(text)
	return '<div class="head label">' .. hud.Escape(text) .. '</div>'
end

local function GamePage()
	local left = {}
	left[#left + 1] = '<div class="big">' .. hud.Escape(Game.gameName or "") .. '</div>'
	left[#left + 1] = Row("Version", Game.gameVersion or "?")
	left[#left + 1] = Row("Engine", (Engine and Engine.version) or Game.version or "?")
	left[#left + 1] = '<div class="big">' .. hud.Escape(Game.mapName or "") .. '</div>'
	if Game.mapDescription and Game.mapDescription ~= "" then
		left[#left + 1] = '<div class="note">' .. hud.Escape(Game.mapDescription) .. '</div>'
	end
	left[#left + 1] = Row("Size", tostring(Game.mapX) .. " x " .. tostring(Game.mapY))
	left[#left + 1] = Row("Gravity", Game.gravity)
	left[#left + 1] = Row("Hardness", Game.mapHardness)
	local tidal = Game.tidal
	if Spring.GetTidal then
		tidal = Spring.GetTidal()
	end
	left[#left + 1] = Row("Tidal speed", tidal)
	if Game.windMin == Game.windMax then
		left[#left + 1] = Row("Wind speed", Game.windMin)
	else
		left[#left + 1] = Row("Wind speed", tostring(Game.windMin) .. " - " .. tostring(Game.windMax))
	end
	left[#left + 1] = Row("Water damage", Game.waterDamage, (Game.waterDamage or 0) ~= 0)

	-- Mod options: what this match was set up with. Those that are not at
	-- their default come first and are marked.
	local defaults, names = {}, {}
	for key, value in pairs(ENGINE_DEFAULTS) do
		defaults[key] = value
	end
	local ok, list = pcall(VFS.Include, "modoptions.lua")
	if ok and type(list) == "table" then
		for _, option in pairs(list) do
			if option.key then
				local def = option.def
				if def == false then def = 0 elseif def == true then def = 1 end
				defaults[tostring(option.key):lower()] = tostring(def)
				names[tostring(option.key):lower()] = option.name
			end
		end
	end
	local changed, unchanged = {}, {}
	for key, value in pairs(Spring.GetModOptions() or {}) do
		local entry = { name = names[key] or key, value = tostring(value) }
		if tostring(value) == defaults[key] then
			unchanged[#unchanged + 1] = entry
		else
			changed[#changed + 1] = entry
		end
	end
	local function ByName(a, b) return tostring(a.name):lower() < tostring(b.name):lower() end
	table.sort(changed, ByName)
	table.sort(unchanged, ByName)
	local right = { Head("Mod options") }
	for _, entry in ipairs(changed) do
		right[#right + 1] = Row(entry.name, entry.value, true)
	end
	for _, entry in ipairs(unchanged) do
		right[#right + 1] = Row(entry.name, entry.value)
	end
	if #changed + #unchanged == 0 then
		right[#right + 1] = '<div class="note">None set.</div>'
	end

	return '<div class="columns"><div class="column">' .. table.concat(left)
		.. '</div><div class="column last">' .. table.concat(right) .. '</div></div>'
end

local function ControlsPage()
	local tables = {}
	local ok, err = pcall(VFS.Include, HOTKEY_FILE, tables)
	if not ok then
		return '<div class="note">' .. hud.Escape(HOTKEY_FILE .. " could not be read: " .. tostring(err)) .. '</div>'
	end
	local columns = {}
	for c, name in ipairs(HOTKEY_COLUMNS) do
		local parts = {}
		for _, entry in ipairs(tables[name] or {}) do
			if entry.blankLine then
				parts[#parts + 1] = '<div class="gap"/>'
			elseif entry.title then
				parts[#parts + 1] = Head(entry[1] or "")
			else
				parts[#parts + 1] = string.format('<div class="row"><div class="key">%s</div><div class="does">%s</div></div>',
					hud.Escape(string.upper(entry[1] or "")), hud.Escape(entry[2] or ""))
			end
		end
		columns[c] = '<div class="column' .. ((c == #HOTKEY_COLUMNS) and " last" or "") .. '">' .. table.concat(parts) .. '</div>'
	end
	return '<div class="columns">' .. table.concat(columns) .. '</div>'
end

-- commandlist.txt: headings, and lines of "/Name   (synced)   what it does"
local function CommandsPage()
	local text = VFS.LoadFile(COMMAND_FILE)
	if not text then
		return '<div class="note">' .. hud.Escape(COMMAND_FILE .. " not found.") .. '</div>'
	end
	local parts = {}
	for line in (text .. "\n"):gmatch("(.-)\r?\n") do
		local name, sync, what = line:match("^%s*(/%S+)%s+%((%a+)%)%s*(.*)$")
		if name then
			parts[#parts + 1] = string.format('<div class="row"><div class="cmd">%s</div><div class="sync%s">%s</div><div class="does">%s</div></div>',
				hud.Escape(name), (sync == "synced") and " synced" or "", hud.Escape(sync), hud.Escape(what))
		elseif line:match("%S") then
			local plainName, plainWhat = line:match("^%s*(/%S+)%s+(.*)$")
			if plainName then
				parts[#parts + 1] = string.format('<div class="row"><div class="cmd">%s</div><div class="sync"/><div class="does">%s</div></div>',
					hud.Escape(plainName), hud.Escape(plainWhat))
			else
				parts[#parts + 1] = Head((line:gsub("^%s+", ""):gsub("[:%s]+$", "")))
			end
		end
	end
	return table.concat(parts)
end

local BUILDERS = { GamePage, ControlsPage, CommandsPage }

--------------------------------------------------------------------------------
-- showing
--------------------------------------------------------------------------------

local function PlayClickSound()
	Spring.PlaySoundFile("leftclick", 1.0, "ui")
end

local function Refresh()
	view.SetClass("info", "hidden", not isOpen)
	if not isOpen then
		return
	end
	for i = 1, TAB_COUNT do
		view.SetClass("tab" .. i, "active", tab == i)
	end
	if shownTab ~= tab then
		shownTab = tab
		if not pages[tab] then
			pages[tab] = BUILDERS[tab]()
		end
		local page = view.Element("page")
		page.inner_rml = pages[tab]
		pcall(function() page.scroll_top = 0 end)
	end
end

local function DefaultOrigin(vsx, vsy, w, h, scale)
	return (vsx - w) * 0.5, (vsy - h) * 0.5
end

local function Place()
	hud.PlacePanel(view.Element("info"), LAYOUT_NAME, PANEL_WIDTH, PANEL_HEIGHT, DefaultOrigin)
end

local function Open(onTab)
	if not document then return end
	if onTab then
		tab = onTab
	end
	if not isOpen then
		isOpen = true
		pcall(function() document:PullToFront() end)
		PlayClickSound()
	end
	Refresh()
end

local function Close()
	if not isOpen then return end
	isOpen = false
	PlayClickSound()
	Refresh()
end

-- toggle(state) as the old widgets offered it: true opens, false closes, nil
-- flips. A window open on another tab is switched, not closed.
local function Toggler(onTab)
	return function(state)
		if state == nil then
			state = not (isOpen and tab == onTab)
		end
		if state then
			Open(onTab)
		else
			Close()
		end
	end
end

--------------------------------------------------------------------------------
-- widget api
--------------------------------------------------------------------------------

function widget:Initialize()
	local helpers = include("rml/hud.lua")
	local result, reason = helpers.LoadDocument(DOCUMENT_PATH, widget)
	if not result then
		Spring.Echo("[Game info] " .. tostring(reason))
		widgetHandler:RemoveWidget(self)
		return
	end
	hud = helpers
	hud.showInPregame = true -- a window the player opens; usable during faction choice and placement
	document = result
	view = hud.NewView(document)
	view.Assume("info", "hidden", true) -- set in the markup

	hud.OnClick(view, "close", Close)
	view.Element("tabs"):AddEventListener("mousedown", function(event)
		local index = hud.EventAttribute(event, "data-tab")
		if index and BUILDERS[index] and index ~= tab and event.parameters and event.parameters.button == 0 then
			tab = index
			PlayClickSound()
			Refresh()
		end
	end)

	toggleGame = Toggler(1)
	actionHandler = function() toggleGame() end
	widgetHandler:AddAction("customgameinfo", actionHandler)
	Spring.SendCommands("unbind Any+i gameinfo")
	Spring.SendCommands("unbind i gameinfo")
	Spring.SendCommands("bind i customgameinfo")

	WG['gameinfo'] = { toggle = toggleGame }
	WG['keybinds'] = { toggle = Toggler(2) }
	WG['commands'] = { toggle = Toggler(3) }

	hud.RegisterPanel(LAYOUT_NAME, "Game Info", Place, function() return isOpen end)
	Place()
	hud.ShowPassive(document)
end

function widget:Shutdown()
	if document then
		Spring.SendCommands("unbind i customgameinfo")
		Spring.SendCommands("bind Any+i gameinfo")
		widgetHandler:RemoveAction("customgameinfo", actionHandler)
		WG['gameinfo'] = nil
		WG['keybinds'] = nil
		WG['commands'] = nil
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
	local sym = Spring.GetKeySymbol(key)
	if sym == "esc" or sym == "escape" then
		Close()
		return true
	end
	if sym == "pageup" or sym == "pagedown" then
		local page = view.Element("page")
		pcall(function()
			local height = page.client_height
			page.scroll_top = page.scroll_top + ((sym == "pageup") and -height or height)
		end)
		return true
	end
	return false
end

function widget:Update()
	if document then
		hud.FollowGuiHidden(document)
	end
end
