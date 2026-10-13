--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Game menu of the RmlUi HUD.
--
--  A small MENU handle sits in the top right corner. Clicking it, or pressing
--  Esc, opens the menu: resume, the windows that used to have a button each
--  (settings, keybinds, widgets, sharing, economy, graph, log), and resign and quit,
--  which both ask first. Esc or a click outside the menu closes it. The menu
--  does not pause the game.
--
--  Replaces gui_static_menu.lua (kept in Widgets/disabled/), which showed all
--  eight buttons on screen all the time.
--
--  The windows belong to their own widgets; a window's button is left out of
--  the menu while its widget is not running. Those widgets get Esc first (to
--  close themselves), and Esc is left alone while a chat message is typed.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name    = "Game Menu",
		desc    = "Esc menu: settings, keybinds, widgets, sharing, graphs, log, resign, quit (RmlUi)",
		author  = "SplinterFaction Team",
		date    = "2026-10-12",
		license = "GNU GPL, v2 or later",
		layer   = 1000, -- after the windows, so they see Esc first
		enabled = true,
	}
end

local DOCUMENT_PATH   = "LuaUI/rml/menu.rml"
local UPDATE_INTERVAL = 0.25
local KEY_ESCAPE      = 27

-- must match #menu-button in menu.rml
local BUTTON_WIDTH  = 84
local BUTTON_HEIGHT = 30
local MARGIN        = 10

local LAYOUT_NAME = "menubutton"

local hud
local document
local view
local lastUpdate
local open = false
local confirming -- nil, "resign" or "quit"

--------------------------------------------------------------------------------
-- what the buttons do
--------------------------------------------------------------------------------

local function OpenSettings()
	if WG.options and WG.options.toggle then
		WG.options.toggle()
	end
end

-- Buttons that open another widget's window. available() says whether that
-- widget is running; the button is hidden while it is not.
local WINDOWS = {
	{id = "m-settings", available = function() return WG.options and WG.options.toggle end, action = OpenSettings},
	{id = "m-keybinds", available = function() return WG.StaticKeybinds and WG.StaticKeybinds.Toggle end,
		action = function() WG.StaticKeybinds.Toggle() end},
	{id = "m-widgets", available = function() return WG.StaticWidgetSelector and WG.StaticWidgetSelector.Toggle end,
		action = function() WG.StaticWidgetSelector.Toggle() end},
	{id = "m-sharing", available = function() return WG.StaticShareMenu and WG.StaticShareMenu.Toggle end,
		action = function() WG.StaticShareMenu.Toggle() end},
	{id = "m-economy", available = function() return WG.StaticEconGraph and WG.StaticEconGraph.Toggle end,
		action = function() WG.StaticEconGraph.Toggle() end},
	{id = "m-graph", available = function() return WG.StaticEndGraph and WG.StaticEndGraph.Toggle end,
		action = function() WG.StaticEndGraph.Toggle() end},
	{id = "m-log", available = function() return WG.StaticChatLog and WG.StaticChatLog.Toggle end,
		action = function() WG.StaticChatLog.Toggle() end},
}

-- Things that cannot be taken back ask first.
local CONFIRM = {
	resign = {text = "Resign and watch as a spectator?", yes = "Yes, resign", command = "spectator"},
	quit   = {text = "Quit the game?", yes = "Yes, quit", command = "quitforce"},
}

--------------------------------------------------------------------------------

local function PlayHoverSound()
	Spring.PlaySoundFile("hover", 1.0, "ui")
end

local function PlayClickSound()
	Spring.PlaySoundFile("leftclick", 1.0, "ui")
end

local function Refresh()
	view.SetClass("menu", "hidden", not open)
	view.SetClass("backdrop", "hidden", not open)
	view.SetClass("main-items", "hidden", confirming ~= nil)
	view.SetClass("confirm-items", "hidden", confirming == nil)

	for _, window in ipairs(WINDOWS) do
		view.SetClass(window.id, "hidden", not window.available())
	end
	-- a spectator has nothing to resign from
	view.SetClass("m-resign", "hidden", Spring.GetSpectatingState())

	local confirm = confirming and CONFIRM[confirming]
	if confirm then
		view.SetText("confirm-text", confirm.text)
		view.SetText("m-confirm-yes", confirm.yes)
	end
end

local function SetOpen(state)
	open = state
	confirming = nil
	if open then
		pcall(function() document:PullToFront() end) -- above the other HUD panels
	end
	Refresh()
end

local function OnButton(id, handler)
	hud.OnClick(view, id, function()
		PlayClickSound()
		handler()
	end)
	local element = view.Element(id)
	if element then
		element:AddEventListener("mouseover", PlayHoverSound)
	end
end

--------------------------------------------------------------------------------
-- placement of the handle
--------------------------------------------------------------------------------

local function DefaultOrigin(vsx, vsy, w, h, scale)
	return vsx - w - MARGIN * scale, vsy - h - MARGIN * scale
end

local function Place()
	hud.PlacePanel(view.Element("menu-button"), LAYOUT_NAME, BUTTON_WIDTH, BUTTON_HEIGHT, DefaultOrigin)
end

--------------------------------------------------------------------------------

function widget:Initialize()
	local helpers = include("rml/hud.lua")
	local result, reason = helpers.LoadDocument(DOCUMENT_PATH, widget)
	if not result then
		Spring.Echo("[Game Menu] " .. tostring(reason))
		widgetHandler:RemoveWidget()
		return
	end
	hud = helpers
	hud.showInPregame = true -- a window the player opens; usable during faction choice and placement
	document = result

	view = hud.NewView(document)
	view.Assume("menu", "hidden", true)
	view.Assume("backdrop", "hidden", true)
	view.Assume("confirm-items", "hidden", true)
	view.Assume("main-items", "hidden", false)

	OnButton("menu-button", function() SetOpen(not open) end)
	hud.OnClick(view, "backdrop", function() SetOpen(false) end)
	OnButton("m-resume", function() SetOpen(false) end)
	for _, window in ipairs(WINDOWS) do
		OnButton(window.id, function()
			SetOpen(false)
			if window.available() then
				window.action()
			end
		end)
	end
	OnButton("m-resign", function()
		confirming = "resign"
		Refresh()
	end)
	OnButton("m-quit", function()
		confirming = "quit"
		Refresh()
	end)
	OnButton("m-confirm-no", function()
		confirming = nil
		Refresh()
	end)
	OnButton("m-confirm-yes", function()
		local confirm = confirming and CONFIRM[confirming]
		SetOpen(false)
		if confirm then
			Spring.SendCommands(confirm.command)
		end
	end)

	hud.RegisterPanel(LAYOUT_NAME, "Menu", Place)
	Place()

	Refresh()
	hud.ShowPassive(document)
	lastUpdate = Spring.GetTimer()

	-- other widgets can open or close the menu
	WG.GameMenu = {
		Toggle = function() SetOpen(not open) end,
		IsOpen = function() return open end,
	}
end

function widget:Shutdown()
	WG.GameMenu = nil
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
	if not document or key ~= KEY_ESCAPE or isRepeat then
		return false
	end
	if Spring.IsUserWriting and Spring.IsUserWriting() then
		return false -- Esc cancels the chat message being typed
	end
	if Spring.IsGUIHidden() then
		return false
	end
	if confirming then
		confirming = nil
		Refresh()
	else
		SetOpen(not open)
	end
	return true
end

function widget:Update()
	if not document then
		return
	end
	if hud.FollowGuiHidden(document) then
		if open then
			SetOpen(false)
		end
		return
	end
	if not open then
		return
	end
	local now = Spring.GetTimer()
	if Spring.DiffTimers(now, lastUpdate) >= UPDATE_INTERVAL then
		lastUpdate = now
		Refresh()
	end
end
