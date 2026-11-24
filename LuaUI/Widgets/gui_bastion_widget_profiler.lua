--------------------------------------------------------------------------------
--
--  Bastion Widget Profiler
--
--  Times every call-in of every widget and shows, once a second, which of them
--  cost the most: the load per frame, the longest single call, how much memory
--  they churn through, and which call-in it is. Widgets over a limit go amber
--  or red and are named at the top.
--
--  It measures only while it is enabled (Settings > Game > Debug, or the widget
--  list), and takes its hooks out again when it is switched off. The gadget
--  profiler is its twin and sits beside it.
--
--  The panel is LuaUI/rml/profiler.rml, drawn by Include/profiler_panel.lua.
--
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name    = "Bastion Widget Profiler",
		desc    = "Shows which widgets cost the most time and memory (RmlUi)",
		author  = "ForbodingAngel, Claude",
		date    = "2026-11-23",
		license = "GNU GPL, v2 or later",
		layer   = -math.huge,
		handler = true,
		enabled = false,
	}
end

local REPORT_PERIOD = 1.0  -- seconds between refreshes
local OLD_KEY = "_bprofOld" -- where a widget's real call-in is kept while hooked

-- Spring.GetTimer only counts whole milliseconds, and most call-ins take far
-- less: the microsecond timer is the one to use.
local spGetTimer = Spring.GetTimerMicros or Spring.GetTimer
local MICROS = Spring.GetTimerMicros ~= nil
local rawDiffTimers = Spring.DiffTimers
local function Diff(later, earlier)
	return rawDiffTimers(later, earlier, nil, MICROS) -- seconds
end
local spGetLuaMemUsage = Spring.GetLuaMemUsage or function() return 0 end

local hud, panel
local stats = {}     -- [widget name] = {name, prefix, perCallIn, time, kb, calls, peak}
local lastReport

--------------------------------------------------------------------------------
-- hooks
--------------------------------------------------------------------------------

local hooked = false
local isHook = setmetatable({}, { __mode = "k" })
local inHook = false
local oldUpdateWidgetCallIn, oldInsertWidget

local function Entry(w)
	local info = w.whInfo
	local e = stats[info.name]
	if not e then
		local base = info.basename or ""
		local cut = base:find("_", 1, true)
		e = { name = info.name, prefix = cut and base:sub(1, cut - 1) or "", perCallIn = {}, time = 0, kb = 0, calls = 0, peak = 0 }
		stats[info.name] = e
	end
	return e
end

local function MakeHook(w, name, realFunc)
	local e = Entry(w)
	local perCallIn = e.perCallIn
	local t0, m0
	local function Done(...)
		local dt = Diff(spGetTimer(), t0)
		local kb = (spGetLuaMemUsage() or 0) - m0
		e.time = e.time + dt
		e.calls = e.calls + 1
		if kb > 0 then
			e.kb = e.kb + kb
		end
		if dt > e.peak then
			e.peak = dt
		end
		perCallIn[name] = (perCallIn[name] or 0) + dt
		inHook = false
		return ...
	end
	return function(...)
		if inHook then
			-- a call-in running inside another one counts towards the outer
			return realFunc(...)
		end
		inHook = true
		m0 = spGetLuaMemUsage() or 0
		t0 = spGetTimer()
		return Done(realFunc(...))
	end
end

local function HookOne(w, name)
	local func = w[name]
	if type(func) ~= "function" or isHook[func] or not w.whInfo then
		return
	end
	w[OLD_KEY .. name] = func
	local hook = MakeHook(w, name, func)
	isHook[hook] = true
	w[name] = hook
end

local function CallInNames()
	local names = {}
	for key, value in pairs(widgetHandler) do
		if type(key) == "string" and type(value) == "table" then
			local name = key:match("^(%u%w*)List$")
			if name then
				names[#names + 1] = name
			end
		end
	end
	return names
end

local function StartHooks()
	if hooked then
		return
	end
	hooked = true
	local wh = widgetHandler
	local names = CallInNames()
	for _, name in ipairs(names) do
		local list = wh[name .. "List"]
		for i = 1, #list do
			if type(list[i]) == "table" then
				HookOne(list[i], name)
			end
		end
	end
	-- a widget that swaps one of its call-ins later gets the new one hooked too
	oldUpdateWidgetCallIn = wh.UpdateWidgetCallIn
	wh.UpdateWidgetCallIn = function(self, name, w)
		if type(w) == "table" then
			HookOne(w, name)
		end
		return oldUpdateWidgetCallIn(self, name, w)
	end
	-- and so does a widget that is switched on while this runs
	oldInsertWidget = wh.InsertWidget
	wh.InsertWidget = function(self, w)
		oldInsertWidget(self, w)
		if type(w) == "table" then
			for _, name in ipairs(names) do
				HookOne(w, name)
			end
		end
	end
end

local function StopHooks()
	if not hooked then
		return
	end
	hooked = false
	local wh = widgetHandler
	wh.UpdateWidgetCallIn = oldUpdateWidgetCallIn
	wh.InsertWidget = oldInsertWidget
	oldUpdateWidgetCallIn, oldInsertWidget = nil, nil
	for _, w in ipairs(wh.widgets) do
		for _, name in ipairs(CallInNames()) do
			local old = w[OLD_KEY .. name]
			if old then
				if isHook[w[name]] then
					w[name] = old
				end
				w[OLD_KEY .. name] = nil
			end
		end
	end
	inHook = false
end

--------------------------------------------------------------------------------
-- widget api
--------------------------------------------------------------------------------

function widget:Initialize()
	hud = include("rml/hud.lua")
	hud.showInPregame = true -- the choosing and placing screens are worth measuring too
	local Panel = VFS.Include("LuaUI/Widgets/Include/profiler_panel.lua")
	local result, reason = Panel.New({
		hud = hud, widget = widget,
		layout = "widgetprofiler", label = "Widget profiler",
		title = "Widgets", noun = "widget", side = -1,
	})
	if not result then
		Spring.Echo("[Bastion Widget Profiler] " .. tostring(reason))
		widgetHandler:RemoveWidget(self)
		return
	end
	panel = result
	lastReport = spGetTimer()
	StartHooks()
end

function widget:Shutdown()
	StopHooks()
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
	local now = spGetTimer()
	local seconds = Diff(now, lastReport)
	if seconds < REPORT_PERIOD then
		return
	end
	lastReport = now
	local rows = {}
	for _, e in pairs(stats) do
		if e.calls > 0 then
			local hot, hotTime = "", 0
			for callin, t in pairs(e.perCallIn) do
				if t > hotTime then
					hot, hotTime = callin, t
				end
				e.perCallIn[callin] = 0
			end
			rows[#rows + 1] = { name = e.name, prefix = e.prefix, time = e.time, kb = e.kb, calls = e.calls, peak = e.peak, hot = hot, hotTime = hotTime }
			e.time, e.kb, e.calls, e.peak = 0, 0, 0, 0
		end
	end
	panel:Feed(seconds, rows)
end
