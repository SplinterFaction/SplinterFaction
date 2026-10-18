--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Log window of the RmlUi HUD: the scrollback for chat and console output.
--
--  Opened from the game menu (Log). Three tabs: Chat, Console, All. It stays
--  on the newest line until you scroll up, and Esc or the X closes it.
--
--  The lines come from the chat widget (WG.Chatterbox), which keeps the last
--  thousand; this window shows the newest SHOWN_LINES of the chosen tab.
--
--  Replaces gui_static_chatlog.lua (kept in Widgets/disabled/) and keeps its
--  WG.StaticChatLog interface, which the game menu uses.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name    = "Bastion Log",
		previousNames = {"Log"},
		desc    = "Scrollback window for chat and console output: Chat / Console / All tabs (RmlUi)",
		author  = "SplinterFaction Team",
		date    = "2026-10-12",
		license = "GNU GPL, v2 or later",
		layer   = -500, -- before the game menu, so Esc closes this first
		enabled = true,
	}
end

local DOCUMENT_PATH = "LuaUI/rml/log.rml"

-- must match #log in log.rml
local PANEL_WIDTH  = 1100
local PANEL_HEIGHT = 660

local LAYOUT_NAME = "chatlog" -- same as the old widget, so a saved position carries over

local SHOWN_LINES     = 400  -- the newest this many of the tab's lines are shown
local UPDATE_INTERVAL = 0.25
local KEY_ESCAPE      = 27

local TABS = {"chat", "console", "all"}

local hud
local document
local view
local lastUpdate

local isOpen = false
local currentTab = 1
local shownMarkup        -- the lines' markup, as last set
local scrollPending = 0  -- refreshes left in which to go to the newest line
local stick = true       -- stay on the newest line until the player scrolls up

--------------------------------------------------------------------------------
-- the lines
--------------------------------------------------------------------------------

local function FormatGameTime(seconds)
	seconds = math.max(0, seconds or 0)
	return string.format("%d:%02d", math.floor(seconds / 60), math.floor(seconds % 60))
end

local function EntryMatchesTab(entry, tab, isChat)
	if tab == "all" then
		return true
	end
	local chat
	if isChat then
		chat = isChat(entry)
	else
		chat = entry.channel ~= "system"
	end
	if tab == "chat" then
		return chat and true or false
	end
	return not chat
end

local function Color(color, fallback)
	if type(color) == "table" then
		return hud.ReadableColor(color[1], color[2], color[3])
	end
	return fallback
end

local function EntryRML(entry)
	local time = '<div class="time">' .. FormatGameTime(entry.gtime) .. '</div>'
	if entry.player then
		return string.format('<div class="line">%s<div class="said" style="color: %s;"><span style="color: %s;">%s</span>: %s</div></div>',
			time, Color(entry.bodyColor, "#f0f4f8"), Color(entry.nameColor, "#f0f4f8"),
			hud.Escape(entry.player), hud.Escape(entry.body or ""))
	end
	return string.format('<div class="line">%s<div class="said" style="color: %s;">%s</div></div>',
		time, Color(entry.bodyColor, "#8593a1"), hud.Escape(entry.body or entry.raw or ""))
end

local function LinesRML()
	local chat = WG.Chatterbox
	if not chat or not chat.GetLog then
		return '<div class="none">Chat log source not loaded (enable the Chat widget).</div>'
	end
	local log = chat.GetLog()
	local tab = TABS[currentTab]
	local shown = {}
	for i = #log, 1, -1 do
		if #shown >= SHOWN_LINES then
			break
		end
		if EntryMatchesTab(log[i], tab, chat.IsChat) then
			shown[#shown + 1] = EntryRML(log[i])
		end
	end
	if #shown == 0 then
		return '<div class="none">(no messages)</div>'
	end
	-- collected newest first; shown oldest first
	local ordered = {}
	for i = #shown, 1, -1 do
		ordered[#ordered + 1] = shown[i]
	end
	return table.concat(ordered)
end

-- true while the view is at (or within a line of) the newest line
local function AtNewest(lines)
	local ok, result = pcall(function()
		return lines.scroll_top + lines.client_height >= lines.scroll_height - 20
	end)
	return (not ok) or result
end

local function Refresh()
	view.SetClass("log", "hidden", not isOpen)
	if not isOpen then
		return
	end
	for i = 1, #TABS do
		view.SetClass("tab-" .. i, "active", currentTab == i)
	end

	local lines = view.Element("lines")
	if not lines then
		return
	end
	-- the player scrolling up lets go of the newest line; scrolling back takes it again
	if scrollPending == 0 then
		stick = AtNewest(lines)
	end

	local markup = LinesRML()
	if markup ~= shownMarkup then
		shownMarkup = markup
		lines.inner_rml = markup
		if stick then
			scrollPending = 2
		end
	end
	-- The new height is only known after the document has been laid out
	-- again, so going to the newest line is repeated on the next refresh.
	if scrollPending > 0 then
		scrollPending = scrollPending - 1
		pcall(function() lines.scroll_top = lines.scroll_height end)
	end
end

--------------------------------------------------------------------------------
-- open and close
--------------------------------------------------------------------------------

local function DefaultOrigin(vsx, vsy, w, h, scale)
	return (vsx - w) * 0.5, (vsy - h) * 0.5
end

local function Place()
	hud.PlacePanel(view.Element("log"), LAYOUT_NAME, PANEL_WIDTH, PANEL_HEIGHT, DefaultOrigin)
end

local function Open()
	if isOpen or not document then
		return
	end
	isOpen = true
	stick = true
	scrollPending = 2
	shownMarkup = nil
	pcall(function() document:PullToFront() end)
	Spring.PlaySoundFile("leftclick", 1.0, "ui")
	Refresh()
end

local function Close()
	if not isOpen then
		return
	end
	isOpen = false
	Spring.PlaySoundFile("leftclick", 1.0, "ui")
	Refresh()
end

local function Toggle()
	if isOpen then
		Close()
	else
		Open()
	end
end

--------------------------------------------------------------------------------
-- widget api
--------------------------------------------------------------------------------

function widget:Initialize()
	local helpers = include("rml/hud.lua")
	local result, reason = helpers.LoadDocument(DOCUMENT_PATH, widget)
	if not result then
		Spring.Echo("[Log] " .. tostring(reason))
		widgetHandler:RemoveWidget()
		return
	end
	hud = helpers
	document = result

	view = hud.NewView(document)
	view.Assume("log", "hidden", true) -- set in the markup

	hud.OnClick(view, "close", Close)
	view.Element("tabs"):AddEventListener("mousedown", function(event)
		local tab = hud.EventAttribute(event, "data-tab")
		if tab and TABS[tab] and tab ~= currentTab and event.parameters and event.parameters.button == 0 then
			currentTab = tab
			stick = true
			scrollPending = 2
			Spring.PlaySoundFile("leftclick", 1.0, "ui")
			Refresh()
		end
	end)

	WG.StaticChatLog = {
		Toggle = Toggle,
		Show   = Open,
		Hide   = Close,
	}

	hud.RegisterPanel(LAYOUT_NAME, "Chat Log", Place, function() return isOpen end)
	Place()

	hud.ShowPassive(document)
	lastUpdate = Spring.GetTimer()
end

function widget:Shutdown()
	WG.StaticChatLog = nil
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
	if document and isOpen and key == KEY_ESCAPE and not isRepeat then
		Close()
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
	if scrollPending > 0 or Spring.DiffTimers(now, lastUpdate) >= UPDATE_INTERVAL then
		lastUpdate = now
		Refresh()
	end
end
