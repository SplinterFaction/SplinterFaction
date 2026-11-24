--------------------------------------------------------------------------------
--
--  Bastion Gadget Profiler (the panel)
--
--  Shows, once a second, which gadgets cost the most: the load per frame, the
--  longest single call, how much memory they churn through, and which call-in
--  it is. A gadget has a synced part and an unsynced part and they are listed
--  apart. Gadgets over a limit go amber or red and are named at the top.
--
--  The measuring is done in LuaRules by dbg_bastion_gadget_profiler.lua, which
--  this widget switches on when it is enabled and off when it is disabled
--  (Settings > Game > Debug, or the widget list). The widget profiler is its
--  twin and sits beside it.
--
--  While this is on, the synced gadgets are timed on every player's machine
--  (synced code has to run the same everywhere), at a small cost to all.
--  It cannot be switched on while watching a replay, which sends no messages.
--
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name    = "Bastion Gadget Profiler",
		desc    = "Shows which gadgets cost the most time and memory (RmlUi)",
		author  = "ForbodingAngel, Claude",
		date    = "2026-11-23",
		license = "GNU GPL, v2 or later",
		layer   = -math.huge + 1,
		enabled = false,
	}
end

local MSG_ON  = "bastionprof:on"
local MSG_OFF = "bastionprof:off"
local ASK_AGAIN = 4   -- seconds without numbers before asking LuaRules again

local hud, panel
local lastData = nil  -- os.clock() of the last numbers
local lastAsk = nil

local function Ask()
	lastAsk = os.clock()
	Spring.SendLuaRulesMsg(MSG_ON)
end

-- text, from the gadget: the seconds covered, then a line per gadget part
local function GadgetProfile(text)
	if not panel or type(text) ~= "string" then
		return
	end
	lastData = os.clock()
	local seconds
	local rows = {}
	for line in text:gmatch("[^\n]+") do
		if not seconds then
			seconds = tonumber(line)
		else
			local name, prefix, part, time, kb, calls, peak, hot, hotTime =
				line:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)$")
			if name then
				rows[#rows + 1] = {
					name = name, prefix = prefix, part = part,
					time = tonumber(time) or 0, kb = tonumber(kb) or 0, calls = tonumber(calls) or 0,
					peak = tonumber(peak) or 0, hot = hot, hotTime = tonumber(hotTime) or 0,
				}
			end
		end
	end
	if seconds then
		panel:Feed(seconds, rows)
	end
end

function widget:Initialize()
	hud = include("rml/hud.lua")
	hud.showInPregame = true
	local Panel = VFS.Include("LuaUI/Widgets/Include/profiler_panel.lua")
	local result, reason = Panel.New({
		hud = hud, widget = widget,
		layout = "gadgetprofiler", label = "Gadget profiler",
		title = "Gadgets", noun = "gadget", side = 1,
	})
	if not result then
		Spring.Echo("[Bastion Gadget Profiler] " .. tostring(reason))
		widgetHandler:RemoveWidget(self)
		return
	end
	panel = result
	if Spring.IsReplay() then
		panel:SetWaiting("Not available in a replay: it cannot message the game")
	else
		panel:SetWaiting("Asking the game for its numbers...")
	end
	widgetHandler:RegisterGlobal("BastionGadgetProfile", GadgetProfile)
	Ask()
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal("BastionGadgetProfile")
	Spring.SendLuaRulesMsg(MSG_OFF)
	if panel then
		panel:Close()
		panel = nil
	end
end

function widget:ViewResize()
	if panel then
		hud.UpdateScale()
		panel:Place()
	end
end

function widget:Update()
	if not panel then
		return
	end
	panel:Tick()
	-- LuaRules forgets who asked when it is reloaded: ask again if it goes quiet
	local now = os.clock()
	if now - (lastData or 0) > ASK_AGAIN and now - (lastAsk or 0) > ASK_AGAIN then
		Ask()
	end
end
