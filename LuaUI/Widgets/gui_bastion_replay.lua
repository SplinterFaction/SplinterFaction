--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Replay controls of the RmlUi HUD: a strip under the resource bar with a
--  pause button and the replay speeds. Before the replay's game has begun the
--  first button skips the wait. The widget removes itself when no replay is
--  being watched.
--
--  Replaces gui_replaybuttons.lua (kept in Widgets/disabled/). Unlike the old
--  one it stays on screen while units are selected, and it shows the speed
--  the game is actually running at.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name    = "Bastion Replay Buttons",
		previousNames = {"replay buttons"},
		desc    = "Pause and speed buttons while watching a replay (RmlUi)",
		author  = "SplinterFaction Team",
		date    = "2026-10-13",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true,
	}
end

local DOCUMENT_PATH = "LuaUI/rml/replay.rml"

-- must match #replay in replay.rml
local PANEL_WIDTH  = 560
local PANEL_HEIGHT = 40
local PANEL_TOP    = 86 -- below the resource bar

local LAYOUT_NAME = "replaybuttons"

local SPEEDS = {0.5, 1, 2, 3, 4, 5, 10, 20}

local UPDATE_INTERVAL = 0.2 -- seconds between looks at the game's speed

local hud
local document
local view

local wantedSpeed = nil -- a lower speed being stepped down to
local chosen = 2        -- index into SPEEDS of the last speed asked for
local lastUpdate

local function SpeedsRML()
	local parts = {}
	for i, speed in ipairs(SPEEDS) do
		parts[i] = string.format('<div id="rs%d" class="rb" data-speed="%d">%sx</div>', i, i, tostring(speed))
	end
	return table.concat(parts)
end

local function Refresh()
	local _, speed, paused = Spring.GetGameSpeed()
	local started = Spring.GetGameFrame() > 1
	view.SetText("replay-pause", (not started) and "Skip" or (paused and "Play" or "Pause"))
	view.SetClass("replay-pause", "active", started and paused)
	for i = 1, #SPEEDS do
		view.SetClass("rs" .. i, "active", i == chosen)
	end
	view.SetText("replay-now", string.format("%.1fx", speed or 1))
end

-- The engine only steps the speed. Up: raising the minimum speed jumps
-- there at once (and the minimum is then put back). Down: "slowdown" is sent
-- again and again from Update until the speed is low enough.
local function SetReplaySpeed(speed)
	local current = Spring.GetGameSpeed() -- the speed asked for (the second value is the speed reached)
	if speed > (current or 1) then
		wantedSpeed = nil
		Spring.SendCommands("setminspeed " .. speed)
		Spring.SendCommands("setminspeed " .. 0.1)
	else
		wantedSpeed = speed
	end
end

local function DefaultOrigin(vsx, vsy, w, h, scale)
	return (vsx - w) * 0.5, vsy - PANEL_TOP * scale - h
end

local function Place()
	hud.PlacePanel(view.Element("replay"), LAYOUT_NAME, PANEL_WIDTH, PANEL_HEIGHT, DefaultOrigin)
end

function widget:Initialize()
	if not Spring.IsReplay() then
		widgetHandler:RemoveWidget(self)
		return
	end
	local helpers = include("rml/hud.lua")
	local result, reason = helpers.LoadDocument(DOCUMENT_PATH, widget)
	if not result then
		Spring.Echo("[replay buttons] " .. tostring(reason))
		widgetHandler:RemoveWidget(self)
		return
	end
	hud = helpers
	document = result
	view = hud.NewView(document)
	view.Element("replay-speeds").inner_rml = SpeedsRML()

	hud.OnClick(view, "replay-pause", function()
		Spring.PlaySoundFile("leftclick", 1.0, "ui")
		if Spring.GetGameFrame() > 1 then
			local _, _, paused = Spring.GetGameSpeed()
			Spring.SendCommands(paused and "pause 0" or "pause 1")
		else
			Spring.SendCommands("skip 1")
		end
		Refresh()
	end)
	view.Element("replay-speeds"):AddEventListener("mousedown", function(event)
		local i = hud.EventAttribute(event, "data-speed")
		if i and SPEEDS[i] and event.parameters and event.parameters.button == 0 then
			Spring.PlaySoundFile("leftclick", 1.0, "ui")
			chosen = i
			SetReplaySpeed(SPEEDS[i])
			Refresh()
		end
	end)

	hud.RegisterPanel(LAYOUT_NAME, "Replay Controls", Place)
	Place()
	hud.ShowPassive(document)
	lastUpdate = Spring.GetTimer()
	Refresh()
end

function widget:Shutdown()
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

function widget:Update()
	if not document then
		return
	end
	if wantedSpeed then
		local current = Spring.GetGameSpeed()
		if (current or 1) > wantedSpeed then
			Spring.SendCommands("slowdown")
		else
			wantedSpeed = nil
		end
	end
	if hud.FollowGuiHidden(document) then
		return
	end
	local now = Spring.GetTimer()
	if Spring.DiffTimers(now, lastUpdate) >= UPDATE_INTERVAL then
		lastUpdate = now
		Refresh()
	end
end
