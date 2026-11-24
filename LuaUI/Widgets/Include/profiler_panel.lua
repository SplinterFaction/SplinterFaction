--------------------------------------------------------------------------------
--
--  The profiler panel, shared by gui_bastion_widget_profiler.lua and
--  gui_bastion_gadget_profiler.lua. Each of them measures in its own way and
--  feeds the numbers here; this file turns them into figures a person can read
--  and draws the panel (LuaUI/rml/profiler.rml).
--
--    local Panel = VFS.Include("LuaUI/Widgets/Include/profiler_panel.lua")
--    local panel, reason = Panel.New({
--        hud = hud, widget = widget,
--        layout = "widgetprofiler",      -- name for the layout editor
--        label = "Widget profiler",      -- what the layout editor calls it
--        title = "Widgets", noun = "widget",
--        side = -1,                      -- default spot: -1 left of centre, 1 right
--    })
--    panel:Feed(seconds, rows)   once a second or so. rows is an array of
--                                {name, prefix, part, time, kb, calls, peak, hot, hotTime}
--                                (seconds and KB spent in that time; peak is the
--                                longest single call; hot the busiest call-in)
--    panel:Tick()                every Update: follows F5
--    panel:Place()               after a resize
--    panel:Close()
--
--  The four figures of a row:
--    load    Lua time per drawn frame, in milliseconds, averaged over a few
--            seconds. At 60 fps a whole frame is 16.7 ms.
--    spike   the longest single call in the last few seconds. A long one is a
--            visible hitch even when the average is small.
--    memory  how fast it makes garbage, in KB a second. A lot of it makes the
--            garbage collector work, which shows up as stutter elsewhere.
--    busiest call-in, and its share of the row's time.
--
--------------------------------------------------------------------------------

local Panel = {}
Panel.__index = Panel

local PANEL_WIDTH  = 500  -- must match #prof in profiler.rml
local PANEL_HEIGHT = 492
local PANEL_TOP    = 90   -- under the resource bar
local PANEL_GAP    = 6    -- between the two panels when side by side
local MAX_ROWS     = 20   -- 360dp of rows at 18dp each

local DOCUMENT_PATH = "LuaUI/rml/profiler.rml"

-- where a figure turns amber and where it turns red
Panel.limits = {
	load = { warn = 0.30, bad = 1.00 },   -- ms per frame
	peak = { warn = 4.0,  bad = 12.0 },   -- ms, one call
	mem  = { warn = 150,  bad = 600 },    -- KB per second
}
local LOAD_BAR_FULL = 2.0   -- ms per frame that fills a row's bar
local SMOOTH        = 0.35  -- share of the newest second in the running average
local PEAK_HOLD     = 5     -- feeds a spike stays on show
local FORGET_AFTER  = 12    -- feeds without a call before a row is dropped
local SHOW_ABOVE    = 0.005 -- ms per frame below which a quiet row is not listed

local function Level(value, limit)
	if value >= limit.bad then
		return 2
	elseif value >= limit.warn then
		return 1
	end
	return 0
end

local LEVEL_CLASS = { [0] = "", "v-warn", "v-bad" }
local ROW_CLASS   = { [0] = "", "warn", "bad" }

function Panel.New(opts)
	local hud = opts.hud
	local document, reason = hud.LoadDocument(DOCUMENT_PATH, opts.widget)
	if not document then
		return nil, reason
	end
	local self = setmetatable({}, Panel)
	self.hud = hud
	self.document = document
	self.view = hud.NewView(document)
	self.layout = opts.layout
	self.side = opts.side or -1
	self.noun = opts.noun or "widget"
	self.entries = {}
	self.feeds = 0
	self.view.Assume("prof", "hidden", true)
	self.view.SetText("title", hud.Escape(opts.title or "Profiler"))
	self.view.SetText("col-name", hud.Escape(self.noun))
	hud.RegisterPanel(self.layout, opts.label or "Profiler", function() self:Place() end)
	self:Place()
	self.view.SetClass("prof", "hidden", false)
	hud.ShowPassive(document)
	return self
end

function Panel:Place()
	local side = self.side
	self.hud.PlacePanel(self.view.Element("prof"), self.layout, PANEL_WIDTH, PANEL_HEIGHT,
		function(vsx, vsy, w, h, scale)
			local x
			if side < 0 then
				x = vsx * 0.5 - PANEL_GAP * 0.5 * scale - w
			else
				x = vsx * 0.5 + PANEL_GAP * 0.5 * scale
			end
			-- on a narrow screen keep both on it
			x = math.max(0, math.min(vsx - w, x))
			return x, vsy - PANEL_TOP * scale - h
		end)
	self.view.ForgetStyles()
end

function Panel:Tick()
	if self.document then
		self.hud.FollowGuiHidden(self.document)
	end
end

function Panel:Close()
	if self.layout then
		self.hud.UnregisterPanel(self.layout)
	end
	if self.document then
		self.document:Close()
		self.document = nil
	end
end

-- "waiting" text for before the first numbers arrive
function Panel:SetWaiting(text)
	self.view.SetText("verdict", self.hud.Escape(text))
	self.view.SetClass("verdict", "wait", true)
	self.view.SetClass("verdict", "warn", false)
	self.view.SetClass("verdict", "bad", false)
end

local function FormatLoad(v)
	if v < 0.005 then
		return "0"
	end
	return string.format("%.2f", v)
end

local function FormatPeak(v)
	if v < 0.05 then
		return "0"
	elseif v >= 100 then
		return string.format("%d", v)
	end
	return string.format("%.1f", v)
end

local function FormatMem(v)
	if v < 0.5 then
		return "0"
	elseif v >= 10000 then
		return string.format("%.1fM", v / 1024)
	end
	return string.format("%d", v + 0.5)
end

local function Figure(text, level)
	if text == "0" then
		return '<span class="v-zero">0</span>'
	end
	local class = LEVEL_CLASS[level]
	if class == "" then
		return text
	end
	return '<span class="' .. class .. '">' .. text .. '</span>'
end

function Panel:Feed(seconds, rows)
	if not self.document or seconds <= 0 then
		return
	end
	local hud, view, entries, limits = self.hud, self.view, self.entries, Panel.limits
	self.feeds = self.feeds + 1
	local fps = math.max(1, Spring.GetFPS())
	local frameMs = 1000 / fps

	-- fold the new second into the running figures
	local seen = {}
	for i = 1, #rows do
		local r = rows[i]
		local key = r.name .. "\t" .. (r.part or "")
		local e = entries[key]
		if not e then
			e = { name = r.name, prefix = r.prefix or "", part = r.part, load = nil, mem = nil, peaks = {}, quiet = 0, hot = "", hotShare = 0 }
			entries[key] = e
		end
		seen[key] = true
		local load = r.time / seconds * 1000 / fps       -- ms per drawn frame
		local mem = math.max(0, r.kb) / seconds          -- KB per second
		e.load = e.load and (e.load + (load - e.load) * SMOOTH) or load
		e.mem = e.mem and (e.mem + (mem - e.mem) * SMOOTH) or mem
		e.newPeak = r.peak * 1000
		e.quiet = 0
		if r.time > 0 and r.hot and r.hot ~= "" then
			e.hot = r.hot
			e.hotShare = r.hotTime / r.time
		end
	end
	local list = {}
	local totalLoad, totalMem = 0, 0
	for key, e in pairs(entries) do
		if not seen[key] then
			e.load = (e.load or 0) * (1 - SMOOTH)
			e.mem = (e.mem or 0) * (1 - SMOOTH)
			e.newPeak = 0
			e.quiet = e.quiet + 1
		end
		local peaks = e.peaks
		peaks[#peaks + 1] = e.newPeak
		if #peaks > PEAK_HOLD then
			table.remove(peaks, 1)
		end
		local peak = 0
		for i = 1, #peaks do
			if peaks[i] > peak then
				peak = peaks[i]
			end
		end
		e.peak = peak
		if e.quiet > FORGET_AFTER then
			entries[key] = nil
		else
			e.lLoad = Level(e.load, limits.load)
			e.lPeak = Level(e.peak, limits.peak)
			e.lMem = Level(e.mem, limits.mem)
			e.level = math.max(e.lLoad, e.lPeak, e.lMem)
			totalLoad = totalLoad + e.load
			totalMem = totalMem + e.mem
			list[#list + 1] = e
		end
	end

	-- the worst first; among equals, the heaviest
	table.sort(list, function(a, b)
		if a.level ~= b.level then
			return a.level > b.level
		end
		if a.load ~= b.load then
			return a.load > b.load
		end
		return a.name < b.name
	end)

	-- the total, and how much of a frame it is
	local share = totalLoad / frameMs
	view.SetText("total", string.format(
		'<span class="fig">%.2f</span> ms of each %.1f ms frame (%d%%)  ·  %s KB/s',
		totalLoad, frameMs, math.floor(share * 100 + 0.5), FormatMem(totalMem)))
	view.SetStyle("budget-fill", "width", string.format("%d%%", math.floor(math.min(1, share) * 100 + 0.5)))
	view.SetStyle("budget-fill", "background-color", share >= 0.5 and "#ff5c5c" or share >= 0.25 and "#ffcf5c" or "#5fd38d")

	-- the verdict: who needs looking at, in words
	local flagged, worst, words = 0, 0, {}
	for i = 1, #list do
		local e = list[i]
		if e.level > 0 then
			flagged = flagged + 1
			worst = math.max(worst, e.level)
			if #words < 3 then
				local why = {}
				if e.lLoad > 0 then why[#why + 1] = "heavy" end
				if e.lPeak > 0 then why[#why + 1] = "spikes" end
				if e.lMem > 0 then why[#why + 1] = "memory" end
				words[#words + 1] = e.name .. " (" .. table.concat(why, ", ") .. ")"
			end
		end
	end
	local verdict
	if flagged == 0 then
		verdict = "All quiet: no " .. self.noun .. " is over its limits"
	else
		verdict = flagged .. (flagged == 1 and " needs" or " need") .. " attention: " .. table.concat(words, ", ")
		if flagged > #words then
			verdict = verdict .. ", +" .. (flagged - #words)
		end
	end
	view.SetText("verdict", hud.Escape(verdict))
	view.SetClass("verdict", "wait", false)
	view.SetClass("verdict", "warn", worst == 1)
	view.SetClass("verdict", "bad", worst == 2)

	-- the rows
	local rml = {}
	local shown = 0
	for i = 1, #list do
		local e = list[i]
		if shown >= MAX_ROWS or (e.level == 0 and e.load < SHOW_ABOVE and e.peak < 0.05) then
			break
		end
		shown = shown + 1
		local class = ROW_CLASS[e.level]
		local bar = math.floor(math.min(1, e.load / LOAD_BAR_FULL) * 100 + 0.5)
		local name = hud.Escape(e.name)
		if e.prefix ~= "" then
			name = '<span class="pre">' .. hud.Escape(e.prefix) .. '</span> ' .. name
		end
		if e.part == "S" then
			name = name .. ' <span class="part">synced</span>'
		elseif e.part == "U" then
			name = name .. ' <span class="part">unsynced</span>'
		end
		local hot = ""
		if e.hot ~= "" then
			hot = hud.Escape(e.hot) .. string.format(" %d%%", math.floor(e.hotShare * 100 + 0.5))
		end
		rml[#rml + 1] = '<div class="row ' .. class .. '">'
			.. '<div class="c-name">' .. name .. '</div>'
			.. '<div class="c-bar"><div class="barbg"><div class="barfill" style="width: ' .. bar .. '%;"/></div></div>'
			.. '<div class="c-load">' .. Figure(FormatLoad(e.load), e.lLoad) .. '</div>'
			.. '<div class="c-peak">' .. Figure(FormatPeak(e.peak), e.lPeak) .. '</div>'
			.. '<div class="c-mem">' .. Figure(FormatMem(e.mem), e.lMem) .. '</div>'
			.. '<div class="c-hot">' .. hot .. '</div>'
			.. '</div>'
	end
	local rowsElement = view.Element("rows")
	if rowsElement then
		rowsElement.inner_rml = table.concat(rml)
	end

	local rest = #list - shown
	local foot = string.format("Amber / red at: load %.1f / %.1f ms, spike %d / %d ms, memory %d / %d KB/s",
		limits.load.warn, limits.load.bad, limits.peak.warn, limits.peak.bad, limits.mem.warn, limits.mem.bad)
	if rest > 0 then
		foot = string.format("+%d quieter not shown.  ", rest) .. foot
	end
	view.SetText("foot", hud.Escape(foot))
end

return Panel
