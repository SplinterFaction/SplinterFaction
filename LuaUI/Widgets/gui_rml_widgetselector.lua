--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Widget selector of the RmlUi HUD (F11): every widget LuaUI knows about, to
--  switch on and off, move up and down in the call order, and reload.
--
--    left click     switch the widget on or off
--    middle click   lower the widget (called later)
--    right click    raise the widget (called earlier)
--
--  A row is muted while its widget is off, green while it runs, and amber when
--  it is switched on but not running. Pointing at a row shows what the widget
--  does, who wrote it and which file it is. Widgets from the user's own
--  Widgets folder carry a USER mark; everything else comes with the game.
--
--  "/luaui reset" and "/luaui factoryreset" are handled here too.
--
--  Relies on a gadget to implement "luarules reloadluaui", and on the widget
--  handler for blankOutConfig and allowUserWidgets.
--
--  Replaces gui_static_widgetselector.lua (kept in Widgets/disabled/).
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name    = "Widget Selector",
		desc    = "Widget list: switch on and off, reorder, reload LuaUI (RmlUi)",
		author  = "trepan, jK, Bluestone (original); SplinterFaction Team",
		date    = "2026-10-13",
		license = "GNU GPL, v2 or later",
		layer   = -math.huge,
		handler = true,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- config
--------------------------------------------------------------------------------

local DOCUMENT_PATH = "LuaUI/rml/widgetselector.rml"

-- must match #widgetselector in widgetselector.rml
local PANEL_WIDTH  = 460
local PANEL_HEIGHT = 660

local LAYOUT_NAME = "widgetselector" -- same as the old widget, so a saved position carries over

local UPDATE_INTERVAL = 0.25 -- seconds between looks at the widgets' states while open

local HINT_NAME = "Widget Selector"
local HINT_DESC = "Left click switches a widget on or off. Middle click lowers it, right click raises it."

local spSendCommands = Spring.SendCommands
local spGetKeySymbol = Spring.GetKeySymbol

local hud
local document
local view

local isOpen = false
local wantOpen = false -- saved as open: reopen after a LuaUI reload

local fullList = {}    -- sorted {name, data} pairs, without this widget
local listDirty = true
local listMarkup
local hovered          -- index into fullList of the row under the mouse
local lastUpdate

local allowUserWidgetsOption = true

--------------------------------------------------------------------------------
-- the list
--------------------------------------------------------------------------------

local function PlayClickSound()
	Spring.PlaySoundFile("leftclick", 1.0, "ui")
end

local function SortListFunc(a, b)
	if a[1] == "Widget Profiler" then return true end
	if b[1] == "Widget Profiler" then return false end
	if a[2].fromZip ~= b[2].fromZip then return a[2].fromZip end
	return a[1] < b[1]
end

local function BuildList()
	local myName = widget:GetInfo().name
	local hoveredName = hovered and fullList[hovered] and fullList[hovered][1]
	fullList = {}
	for name, data in pairs(widgetHandler.knownWidgets) do
		if name ~= myName then
			fullList[#fullList + 1] = {name, data}
		end
	end
	table.sort(fullList, SortListFunc)
	hovered = nil
	for i = 1, #fullList do
		if fullList[i][1] == hoveredName then
			hovered = i
			break
		end
	end
	listDirty = false
	widgetHandler.knownChanged = false
end

-- "on" (running), "idle" (switched on, not running) or nil (off)
local function StateOf(entry)
	if entry[2].active then
		return "on"
	end
	local order = widgetHandler.orderList[entry[1]]
	if order and order > 0 then
		return "idle"
	end
	return nil
end

local function RowRML(i, entry)
	return string.format('<div id="w%d" class="wrow" data-w="%d"><div class="dot"/><div class="wname">%s</div>%s</div>',
		i, i, hud.Escape(entry[1]), entry[2].fromZip and "" or '<div class="user">USER</div>')
end

--------------------------------------------------------------------------------
-- showing
--------------------------------------------------------------------------------

local function Refresh()
	view.SetClass("widgetselector", "hidden", not isOpen)
	if not isOpen then
		return
	end

	if listDirty or widgetHandler.knownChanged then
		BuildList()
	end
	local markup
	if #fullList == 0 then
		markup = '<div id="none">(no widgets found)</div>'
	else
		local parts = {}
		for i, entry in ipairs(fullList) do
			parts[i] = RowRML(i, entry)
		end
		markup = table.concat(parts)
	end
	if markup ~= listMarkup then
		listMarkup = markup
		local list = view.Element("list")
		local ok, top = pcall(function() return list.scroll_top end)
		list.inner_rml = markup
		view.Forget()
		if ok and top then
			pcall(function() list.scroll_top = top end)
		end
	end

	local running = 0
	for i, entry in ipairs(fullList) do
		local state = StateOf(entry)
		if state == "on" then
			running = running + 1
		end
		view.SetClass("w" .. i, "on", state == "on")
		view.SetClass("w" .. i, "idle", state == "idle")
	end
	view.SetText("count", running .. " of " .. #fullList .. " running")

	-- what the mouse is on
	local entry = hovered and fullList[hovered]
	if entry then
		local data = entry[2]
		local state = StateOf(entry)
		view.SetText("info-name", hud.Escape(entry[1]))
		view.SetClass("info-name", "on", state == "on")
		view.SetClass("info-name", "idle", state == "idle")
		view.SetText("info-desc", hud.Escape(data.desc or ""))
		local from = {}
		if data.author and data.author ~= "" then
			from[#from + 1] = "by " .. data.author
		end
		if data.basename then
			from[#from + 1] = data.basename .. (data.fromZip and "" or " (user widget)")
		end
		view.SetText("info-from", hud.Escape(table.concat(from, "  |  ")))
	else
		view.SetText("info-name", HINT_NAME)
		view.SetClass("info-name", "on", false)
		view.SetClass("info-name", "idle", false)
		view.SetText("info-desc", HINT_DESC)
		view.SetText("info-from", "")
	end

	view.SetClass("allow", "hidden", not allowUserWidgetsOption)
	view.SetText("allow", widgetHandler.allowUserWidgets and "Disallow user widgets" or "Allow user widgets")
end

--------------------------------------------------------------------------------
-- open and close
--------------------------------------------------------------------------------

local function DefaultOrigin(vsx, vsy, w, h, scale)
	return (vsx - w) * 0.5, (vsy - h) * 0.5
end

local function Place()
	hud.PlacePanel(view.Element("widgetselector"), LAYOUT_NAME, PANEL_WIDTH, PANEL_HEIGHT, DefaultOrigin)
end

local function Open()
	if isOpen or not document then return end
	isOpen = true
	listDirty = true
	hovered = nil
	pcall(function() document:PullToFront() end)
	PlayClickSound()
	Refresh()
end

local function Close()
	if not isOpen then return end
	isOpen = false
	hovered = nil
	PlayClickSound()
	Refresh()
end

local function Toggle()
	if isOpen then Close() else Open() end
end

--------------------------------------------------------------------------------
-- actions
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

-- RmlUi numbers the buttons left 0, right 1, middle 2
local function OnListMouseDown(event)
	local button = event.parameters and event.parameters.button
	local index = hud.EventAttribute(event, "data-w")
	local entry = index and fullList[index]
	if not entry then
		return
	end
	local name = entry[1]
	if button == 0 then
		PlayClickSound()
		widgetHandler:ToggleWidget(name)
		listDirty = true
	elseif button == 1 or button == 2 then
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
	Refresh()
end

--------------------------------------------------------------------------------
-- widget api
--------------------------------------------------------------------------------

function widget:Initialize()
	local helpers = include("rml/hud.lua")
	local result, reason = helpers.LoadDocument(DOCUMENT_PATH, widget)
	if not result then
		Spring.Echo("[Widget Selector] " .. tostring(reason))
		widgetHandler:RemoveWidget(widget)
		return
	end
	hud = helpers
	hud.showInPregame = true -- a window the player opens; usable during faction choice and placement
	document = result

	widgetHandler.knownChanged = true
	spSendCommands("unbindkeyset f11")

	allowUserWidgetsOption = true
	if Spring.GetModOptions and (tonumber(Spring.GetModOptions().allowuserwidgets) or 1) == 0 then
		allowUserWidgetsOption = false
	end

	view = hud.NewView(document)
	view.Assume("widgetselector", "hidden", true) -- set in the markup

	local list = view.Element("list")
	list:AddEventListener("mousedown", OnListMouseDown)
	list:AddEventListener("mouseover", function(event)
		local index = hud.EventAttribute(event, "data-w")
		if index ~= hovered then
			hovered = index
			Refresh()
		end
	end)
	list:AddEventListener("mouseout", function()
		if hovered then
			hovered = nil
			Refresh()
		end
	end)
	hud.OnClick(view, "close", Close)
	hud.OnClick(view, "reload", function()
		PlayClickSound()
		ActionReload()
	end)
	hud.OnClick(view, "allow", function()
		PlayClickSound()
		ActionToggleAllowUser()
	end)

	WG.StaticWidgetSelector = {
		Toggle = Toggle,
		Show   = Open,
		Hide   = Close,
		IsOpen = function() return isOpen end,
	}

	hud.RegisterPanel(LAYOUT_NAME, "Widget Selector", Place, function() return isOpen end)
	Place()

	hud.ShowPassive(document)
	lastUpdate = Spring.GetTimer()
	if wantOpen then
		wantOpen = false
		Open()
	end
end

function widget:Shutdown()
	if hud then
		hud.UnregisterPanel(LAYOUT_NAME)
	end
	-- back to the engine's own selector if this one is removed or crashes
	spSendCommands("bind f11 luaui selector")
	WG.StaticWidgetSelector = nil
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
	if not document then return false end
	local sym = spGetKeySymbol(key)

	if sym == "f11" and not isRepeat and not (mods.alt or mods.ctrl or mods.meta or mods.shift) then
		Toggle()
		return true
	end
	if not isOpen then return false end

	if sym == "esc" or sym == "escape" then
		Close()
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
	return false
end

-- A click that is not on the window closes it. (Clicks on the window go to
-- RmlUi and never arrive here.) The click still does what it would have done.
function widget:MousePress(x, y, button)
	if isOpen and not Spring.IsGUIHidden() then
		Close()
	end
	return false
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

function widget:Update()
	if not document then
		return
	end
	if hud.FollowGuiHidden(document) or not isOpen then
		return
	end
	local now = Spring.GetTimer()
	if listDirty or widgetHandler.knownChanged or Spring.DiffTimers(now, lastUpdate) >= UPDATE_INTERVAL then
		lastUpdate = now
		Refresh()
	end
end

--------------------------------------------------------------------------------
-- open state kept across a reload, so "Reload LuaUI" comes back to the list
--------------------------------------------------------------------------------

function widget:GetConfigData()
	return {show = isOpen}
end

function widget:SetConfigData(data)
	if data and data.show then
		wantOpen = true
	end
end
