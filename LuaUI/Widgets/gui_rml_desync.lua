--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Desync alert of the RmlUi HUD.
--
--  A desync is when a player's game stops matching the host's: from then on
--  they see, and send orders into, a different game from everyone else, and
--  it does not mend by itself. The engine notices it within seconds and tells
--  every client (and the replay); this widget makes sure nobody misses it.
--
--  On the first report a red alert comes up in the upper middle of the screen
--  with a sound: who is out of sync, since when (game time and frame), and
--  what it means for them. If it is this player's own game, it says so and
--  says what to do. It stays until put away ("HIDE"), and then a red chip
--  stays under the resource bar for as long as the game runs, which opens it
--  again. A new player falling out of sync brings it back up.
--
--  The engine repeats its report about every 13 seconds while the desync
--  lasts; the alert counts those and says when the last one came. When they
--  stop (the player left, or the game ended) it says that too, and keeps the
--  record.
--
--  Every desync also goes to chat as its own red line, once per player (see
--  gui_rml_chat.lua), and to the Log window.
--
--  Interface: WG.Desync = { IsActive(), GetPlayers() } for other widgets.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name    = "Desync Alert",
		desc    = "Tells every player at once when someone's game goes out of sync, and whose (RmlUi)",
		author  = "SplinterFaction Team",
		date    = "2026-10-14",
		license = "GNU GPL, v2 or later",
		layer   = -3000, -- before the chat, so its console line handling runs first
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- config
--------------------------------------------------------------------------------

local DOCUMENT_PATH = "LuaUI/rml/desync.rml"

-- must match #desync and #desync-chip in desync.rml
local PANEL_WIDTH  = 620
local PANEL_HEIGHT = 118
local PANEL_TOP    = 300 -- clear of the vote window and game messages under the resource bar
local CHIP_WIDTH   = 300
local CHIP_HEIGHT  = 22
local CHIP_TOP     = 70  -- just under the resource bar

local LAYOUT_PANEL = "desync"
local LAYOUT_CHIP  = "desyncchip"

local ALERT_SOUND = "Sounds/ui/Notification_sound_3.wav"

-- The engine repeats its report every 400 frames while a desync lasts
-- (SYNCCHECK_MSG_TIMEOUT in rts/Net/GameServer.cpp). When none has come for
-- this many frames, the reports have stopped.
local REPORT_GAP_FRAMES = 1000

local FLASH_SECONDS = 8 -- the alert blinks this long when it comes up
local FLASH_PERIOD  = 0.5

local UPDATE_INTERVAL = 0.25

--------------------------------------------------------------------------------
-- state
--------------------------------------------------------------------------------

local hud
local sync
local document
local view

-- desynced[name] = { first = frame, last = frame, reports = n, spectator = bool }
local desynced = {}
local order = {}        -- names, in the order they fell out of sync
local dumpFile = nil    -- where this client saved the game state, if it did
local open = false      -- the alert is up (rather than put away as the chip)
local flashUntil = 0
local lastUpdate = 0

local myName = nil

--------------------------------------------------------------------------------
-- who is who
--------------------------------------------------------------------------------

local function RefreshMyName()
	local name = Spring.GetPlayerInfo(Spring.GetMyPlayerID(), false)
	myName = name
end

-- true when the player of this name is a spectator (nil when unknown)
local function IsSpectator(name)
	for _, playerID in ipairs(Spring.GetPlayerList() or {}) do
		local playerName, _, spectator = Spring.GetPlayerInfo(playerID, false)
		if playerName == name then
			return spectator and true or false
		end
	end
	return nil
end

--------------------------------------------------------------------------------
-- showing
--------------------------------------------------------------------------------

local function Active()
	return #order > 0
end

local function Refresh()
	if not view then
		return
	end
	local any = Active()
	view.SetClass("desync", "hidden", not (any and open))
	view.SetClass("desync-chip", "hidden", not (any and not open))
	if not any then
		return
	end

	local frame = Spring.GetGameFrame()
	local mine, players, spectators = false, {}, {}
	local first, last, reports = math.huge, 0, 0
	for _, name in ipairs(order) do
		local d = desynced[name]
		if name == myName then
			mine = true
		elseif d.spectator then
			spectators[#spectators + 1] = name
		else
			players[#players + 1] = name
		end
		first = math.min(first, d.first)
		last = math.max(last, d.last)
		reports = reports + d.reports
	end
	local others = {}
	for _, name in ipairs(players) do others[#others + 1] = name end
	for _, name in ipairs(spectators) do others[#others + 1] = name .. " (spectator)" end

	-- the chip: who, in a few words
	local everyone = {}
	if mine then everyone[1] = "YOU" end
	for _, name in ipairs(others) do everyone[#everyone + 1] = name end
	view.SetText("desync-chip", hud.Escape("DESYNC: " .. table.concat(everyone, ", ")))

	if not open then
		return
	end

	-- whose game, and what it means
	local title, text
	if mine then
		title = "Your game is out of sync"
		if #others > 0 then
			title = title .. ", and so is " .. sync.JoinNames(others) .. "'s"
		end
		text = "What you see no longer matches the other players' game, and your orders may not do what you expect. Leaving and rejoining the game usually brings you back in sync."
	else
		title = sync.JoinNames(others) .. ((#others == 1) and " is" or " are") .. " out of sync"
		if #players > 0 then
			text = "Their game no longer matches the host's, so what they see and do differs from what everyone else sees. Pausing to let them rejoin usually fixes it."
		else
			text = "A spectator's view no longer matches the game. It does not affect the players."
		end
	end
	view.SetText("desync-title", hud.Escape(title))
	view.SetText("desync-text", hud.Escape(text))

	-- since when, and whether it is still going on
	local state = "since " .. sync.FrameTime(first) .. " (frame " .. first .. ")"
	local over = frame - last > REPORT_GAP_FRAMES
	if over then
		state = state .. ", no report since " .. sync.FrameTime(last)
	elseif reports > 1 then
		state = state .. ", still out of sync at " .. sync.FrameTime(last) .. " (" .. reports .. " reports)"
	end
	view.SetText("desync-state", hud.Escape(state))
	view.SetClass("desync-state", "over", over)

	view.SetText("desync-dump", dumpFile and hud.Escape("Game state saved for debugging: " .. dumpFile) or "")
	view.SetClass("desync", "flash", os.clock() < flashUntil and (math.floor(os.clock() / FLASH_PERIOD) % 2 == 0))
end

local function Raise()
	open = true
	flashUntil = os.clock() + FLASH_SECONDS
	Spring.PlaySoundFile(ALERT_SOUND, 1.0, "ui")
	if document then
		pcall(function() document:PullToFront() end)
	end
	Refresh()
end

--------------------------------------------------------------------------------
-- reports
--------------------------------------------------------------------------------

local function OnDesync(names, frame)
	local newcomer = false
	for _, name in ipairs(names) do
		local d = desynced[name]
		if d then
			-- the host may see the same report twice (its server's copy too)
			if frame > d.last then
				d.last = frame
				d.reports = d.reports + 1
			end
		else
			desynced[name] = { first = frame, last = frame, reports = 1, spectator = IsSpectator(name) }
			order[#order + 1] = name
			newcomer = true
			Spring.Echo("[Desync Alert] " .. name .. " is out of sync from frame " .. frame)
		end
	end
	if newcomer then
		Raise()
	else
		Refresh()
	end
end

function widget:AddConsoleLine(line)
	local report = sync.Parse(line)
	if report then
		if report.kind == "desync" then
			OnDesync(report.names, report.frame)
		end
		return
	end
	local file = sync.ParseDump(line)
	if file then
		dumpFile = file
		Refresh()
	end
end

--------------------------------------------------------------------------------
-- widget api
--------------------------------------------------------------------------------

local function PanelOrigin(vsx, vsy, w, h, scale)
	return (vsx - w) * 0.5, vsy - PANEL_TOP * scale - h
end

local function ChipOrigin(vsx, vsy, w, h, scale)
	return (vsx - w) * 0.5, vsy - CHIP_TOP * scale - h
end

local function Place()
	hud.PlacePanel(view.Element("desync"), LAYOUT_PANEL, PANEL_WIDTH, PANEL_HEIGHT, PanelOrigin)
	hud.PlacePanel(view.Element("desync-chip"), LAYOUT_CHIP, CHIP_WIDTH, CHIP_HEIGHT, ChipOrigin)
end

function widget:Initialize()
	sync = include("rml/syncmessages.lua")
	RefreshMyName()

	WG.Desync = {
		IsActive = Active,
		GetPlayers = function()
			local list = {}
			for i, name in ipairs(order) do list[i] = name end
			return list
		end,
	}

	local helpers = include("rml/hud.lua")
	local result, reason = helpers.LoadDocument(DOCUMENT_PATH, widget)
	if not result then
		-- the alert is lost, but the console line and chat still say it
		Spring.Echo("[Desync Alert] " .. tostring(reason))
		return
	end
	hud = helpers
	hud.showInPregame = true -- a desync matters at any time
	document = result
	view = hud.NewView(document)
	view.Assume("desync", "hidden", true) -- set in the markup
	view.Assume("desync-chip", "hidden", true)

	hud.OnClick(view, "desync-hide", function()
		Spring.PlaySoundFile("leftclick", 1.0, "ui")
		open = false
		Refresh()
	end)
	hud.OnClick(view, "desync-chip", function()
		Spring.PlaySoundFile("leftclick", 1.0, "ui")
		open = true
		pcall(function() document:PullToFront() end)
		Refresh()
	end)

	hud.RegisterPanel(LAYOUT_PANEL, "Desync Alert", Place, function() return Active() and open end)
	hud.RegisterPanel(LAYOUT_CHIP, "Desync Chip", Place, function() return Active() and not open end)
	Place()
	hud.ShowPassive(document)
end

function widget:Shutdown()
	WG.Desync = nil
	if hud then
		hud.UnregisterPanel(LAYOUT_PANEL)
		hud.UnregisterPanel(LAYOUT_CHIP)
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

function widget:PlayerChanged()
	RefreshMyName()
	for name, d in pairs(desynced) do
		local spectator = IsSpectator(name)
		if spectator ~= nil then
			d.spectator = spectator
		end
	end
end

function widget:Update()
	if not document then
		return
	end
	if hud.FollowGuiHidden(document) or not Active() then
		return -- idle cost stops here
	end
	local now = os.clock()
	if now - lastUpdate >= UPDATE_INTERVAL then
		lastUpdate = now
		Refresh()
	end
end
