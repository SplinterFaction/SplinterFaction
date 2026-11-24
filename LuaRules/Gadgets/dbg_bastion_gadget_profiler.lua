--------------------------------------------------------------------------------
--
--  Bastion Gadget Profiler (the measuring half)
--
--  Times every call-in of every gadget, synced and unsynced, and hands the
--  numbers to LuaUI once a second, where gui_bastion_gadget_profiler.lua shows
--  them. It measures nothing until a player's panel asks for it and stops when
--  the last one closes.
--
--  How it is switched:
--    the panel sends the LuaRules message "bastionprof:on" / "bastionprof:off".
--    Synced keeps the set of players who asked. While that set is not empty the
--    synced call-ins are hooked (for everyone: synced code has to do the same on
--    every machine); the unsynced call-ins are hooked only on the machines of
--    the players who asked.
--
--  How synced time is measured:
--    synced code may not read a clock, so the synced hook tells unsynced when a
--    call starts and when it ends and unsynced reads the clock (as the old
--    dbg_gadget_profiler.lua does). That costs two SendToUnsynced per call
--    while profiling is on, and nothing while it is off.
--
--  What LuaUI gets (Script.LuaUI.BastionGadgetProfile(text)), once a second:
--    line 1:  seconds covered
--    then one line per gadget part that ran, tab separated:
--      name, file prefix, S or U (synced / unsynced), seconds, KB allocated,
--      calls, longest single call in seconds, busiest call-in, its seconds
--
--  Not the same thing as dbg_gadget_profiler.lua ("/luarules profile"), which
--  is left as it is. Do not run both at once.
--
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name    = "Bastion Gadget Profiler",
		desc    = "Measures gadget call-ins for the gadget profiler panel",
		author  = "ForbodingAngel, Claude",
		date    = "2026-11-23",
		license = "GNU GPL, v2 or later",
		layer   = math.huge,
		handler = true,
		enabled = true,
	}
end

local MSG_ON  = "bastionprof:on"
local MSG_OFF = "bastionprof:off"
local OLD_KEY = "_bprofOld"      -- where a gadget's real call-in is kept while hooked
local SELF    = "Bastion Gadget Profiler"

local IS_SYNCED = gadgetHandler:IsSyncedCode()

--------------------------------------------------------------------------------
-- hooking, shared by both halves. MakeHook(g, name, realFunc) differs.
--------------------------------------------------------------------------------

local hooked = false
local isHook = setmetatable({}, { __mode = "k" })
local MakeHook
local oldUpdateGadgetCallIn

local function CallInNames()
	local names = {}
	for key, value in pairs(gadgetHandler) do
		if type(key) == "string" and type(value) == "table" then
			local name = key:match("^(%u%w*)List$")
			if name then
				names[#names + 1] = name
			end
		end
	end
	return names
end

local function HookOne(g, name)
	local func = g[name]
	if type(func) ~= "function" or isHook[func] then
		return
	end
	if not g.ghInfo or g.ghInfo.name == SELF then
		return
	end
	g[OLD_KEY .. name] = func
	local hook = MakeHook(g, name, func)
	isHook[hook] = true
	g[name] = hook
end

local function StartHooks()
	if hooked then
		return
	end
	hooked = true
	local gh = gadgetHandler
	for _, name in ipairs(CallInNames()) do
		local list = gh[name .. "List"]
		for i = 1, #list do
			if type(list[i]) == "table" then
				HookOne(list[i], name)
			end
		end
	end
	-- a gadget that swaps one of its call-ins later gets the new one hooked too
	oldUpdateGadgetCallIn = gh.UpdateGadgetCallIn
	gh.UpdateGadgetCallIn = function(self, name, g)
		if type(g) == "table" then
			HookOne(g, name)
		end
		return oldUpdateGadgetCallIn(self, name, g)
	end
end

local function StopHooks()
	if not hooked then
		return
	end
	hooked = false
	local gh = gadgetHandler
	gh.UpdateGadgetCallIn = oldUpdateGadgetCallIn
	oldUpdateGadgetCallIn = nil
	for _, name in ipairs(CallInNames()) do
		local list = gh[name .. "List"]
		for i = 1, #list do
			local g = list[i]
			if type(g) == "table" then
				local old = g[OLD_KEY .. name]
				if old and isHook[g[name]] then
					g[name] = old
				end
				g[OLD_KEY .. name] = nil
			end
		end
	end
end

--------------------------------------------------------------------------------
if IS_SYNCED then
--------------------------------------------------------------------------------

local users = {}     -- [playerID] = true: players whose panel is open
local userCount = 0
local depth = 0      -- only the outermost hooked call is reported

MakeHook = function(g, name, realFunc)
	local gname = g.ghInfo.name
	local function Done(...)
		depth = depth - 1
		SendToUnsynced("bprof_e")
		return ...
	end
	return function(...)
		if depth > 0 then
			return realFunc(...)
		end
		depth = 1
		SendToUnsynced("bprof_s", gname, name)
		return Done(realFunc(...))
	end
end

local function SetUser(playerID, on)
	if on and not users[playerID] then
		users[playerID] = true
		userCount = userCount + 1
	elseif not on and users[playerID] then
		users[playerID] = nil
		userCount = userCount - 1
	end
	if userCount > 0 then
		StartHooks()
	else
		StopHooks()
		depth = 0
	end
	SendToUnsynced("bprof_user", playerID, on and 1 or 0)
end

function gadget:RecvLuaMsg(msg, playerID)
	if msg == MSG_ON then
		SetUser(playerID, true)
		return true
	elseif msg == MSG_OFF then
		SetUser(playerID, false)
		return true
	end
end

function gadget:PlayerRemoved(playerID)
	if users[playerID] then
		SetUser(playerID, false)
	end
end

function gadget:Shutdown()
	StopHooks()
end

--------------------------------------------------------------------------------
else -- unsynced
--------------------------------------------------------------------------------

-- Spring.GetTimer only counts whole milliseconds, and most call-ins take far
-- less: the microsecond timer is the one to use. Diff(later, earlier) is in seconds.
local spGetTimer = Spring.GetTimerMicros or Spring.GetTimer
local MICROS = Spring.GetTimerMicros ~= nil
local rawDiffTimers = Spring.DiffTimers
local function spDiffTimers(later, earlier)
	return rawDiffTimers(later, earlier, nil, MICROS)
end
local spGetLuaMemUsage = Spring.GetLuaMemUsage or function() return 0, 0, 0, 0, 0, 0, 0, 0 end

local REPORT_PERIOD = 1.0  -- seconds between reports to LuaUI

local active = false       -- this machine's player asked for the numbers

-- stats[key] = {name, part, perCallIn = {[callin] = seconds}, time, kb, calls, peak}
-- key is the gadget name with "\tS" or "\tU" after it
local stats = {}
local prefixOf = {}        -- [gadget name] = file prefix ("unit", "game", ...)

local function Entry(gname, part)
	local key = gname .. "\t" .. part
	local e = stats[key]
	if not e then
		e = { name = gname, part = part, perCallIn = {}, time = 0, kb = 0, calls = 0, peak = 0 }
		stats[key] = e
	end
	return e
end

local function Add(e, callin, dt, kb)
	e.time = e.time + dt
	e.calls = e.calls + 1
	if kb > 0 then
		e.kb = e.kb + kb
	end
	if dt > e.peak then
		e.peak = dt
	end
	e.perCallIn[callin] = (e.perCallIn[callin] or 0) + dt
end

-- unsynced call-ins: timed directly
local inHook = false
MakeHook = function(g, name, realFunc)
	local e = Entry(g.ghInfo.name, "U")
	local t0, m0
	local function Done(...)
		local dt = spDiffTimers(spGetTimer(), t0)
		local m1 = spGetLuaMemUsage()
		Add(e, name, dt, (m1 or 0) - m0)
		inHook = false
		return ...
	end
	return function(...)
		if inHook then
			return realFunc(...)
		end
		inHook = true
		m0 = spGetLuaMemUsage() or 0
		t0 = spGetTimer()
		return Done(realFunc(...))
	end
end

-- synced call-ins: synced says when one starts and ends
local sName, sCallIn, sTimer, sMem

local function SyncedMem()
	local _, _, _, _, _, _, syncedKB = spGetLuaMemUsage()
	return syncedKB or 0
end

local function SyncedStart(_, gname, callin)
	if not active then
		return
	end
	sName, sCallIn = gname, callin
	sMem = SyncedMem()
	sTimer = spGetTimer()
end

local function SyncedEnd()
	if not active or not sTimer then
		return
	end
	local dt = spDiffTimers(spGetTimer(), sTimer)
	Add(Entry(sName, "S"), sCallIn, dt, SyncedMem() - sMem)
	sTimer = nil
end

local lastReport

local function SetActive(on)
	if on == active then
		return
	end
	active = on
	stats = {}
	sTimer = nil
	if on then
		for _, g in ipairs(gadgetHandler.gadgets) do
			local info = g.ghInfo
			if info and info.name then
				local base = info.basename or ""
				local cut = base:find("_", 1, true)
				prefixOf[info.name] = cut and base:sub(1, cut - 1) or ""
			end
		end
		lastReport = spGetTimer()
		StartHooks()
	else
		StopHooks()
		inHook = false
	end
end

local function UserChanged(_, playerID, on)
	if playerID == Spring.GetMyPlayerID() then
		SetActive(on == 1)
	end
end

local function Report()
	local now = spGetTimer()
	local dt = spDiffTimers(now, lastReport)
	if dt < REPORT_PERIOD then
		return
	end
	lastReport = now
	local lines = { string.format("%.4f", dt) }
	for _, e in pairs(stats) do
		if e.calls > 0 then
			local hot, hotTime = "", 0
			for callin, seconds in pairs(e.perCallIn) do
				if seconds > hotTime then
					hot, hotTime = callin, seconds
				end
				e.perCallIn[callin] = 0
			end
			lines[#lines + 1] = string.format("%s\t%s\t%s\t%.6f\t%.2f\t%d\t%.6f\t%s\t%.6f",
				e.name, prefixOf[e.name] or "", e.part, e.time, e.kb, e.calls, e.peak, hot, hotTime)
			e.time, e.kb, e.calls, e.peak = 0, 0, 0, 0
		end
	end
	if Script.LuaUI("BastionGadgetProfile") then
		Script.LuaUI.BastionGadgetProfile(table.concat(lines, "\n"))
	end
end

function gadget:Initialize()
	gadgetHandler.actionHandler.AddSyncAction(gadget, "bprof_s", SyncedStart)
	gadgetHandler.actionHandler.AddSyncAction(gadget, "bprof_e", SyncedEnd)
	gadgetHandler.actionHandler.AddSyncAction(gadget, "bprof_user", UserChanged)
end

function gadget:Update()
	if active then
		Report()
	end
end

function gadget:Shutdown()
	StopHooks()
	gadgetHandler.actionHandler.RemoveSyncAction(gadget, "bprof_s")
	gadgetHandler.actionHandler.RemoveSyncAction(gadget, "bprof_e")
	gadgetHandler.actionHandler.RemoveSyncAction(gadget, "bprof_user")
end

--------------------------------------------------------------------------------
end
--------------------------------------------------------------------------------
