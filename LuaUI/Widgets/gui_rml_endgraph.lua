--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  End graph of the RmlUi HUD: the game's statistics per team over time. It
--  opens by itself when the game is over, and can be opened during the game
--  from the game menu or through WG.StaticEndGraph. (The data is gated by the
--  engine: during a game a player sees only their own and their allies'
--  lines.)
--
--  The window is RmlUi. The lines are drawn with gl: the engine draws gl
--  under RmlUi, so the window leaves a hole where the plot goes (see
--  endgraph.rml) and DrawScreen fills it. The gl drawing goes through
--  WG.StaticGUI (api_staticgui_shapes.lua) when that is running, which
--  batches it and keeps it in a texture between refreshes.
--
--  Replaces gui_static_endgraph.lua (kept in Widgets/disabled/). The
--  gathering of teams and data is carried over unchanged.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name    = "End Graph",
		desc    = "End-of-game statistics graph, also available during the game (non-spectators then see only their own and allied lines). (RmlUi)",
		author  = "SplinterFaction Team",
		date    = "2026-10-13",
		license = "GNU GPL, v2 or later",
		layer   = -500,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- Stat config  (comment out any you don't want; order = button order)
--   { engineName, 'Caption' }
--------------------------------------------------------------------------------

local statName = {
	{'metalUsed'       , 'Metal Used'},
	{'metalProduced'   , 'Metal Produced'},
	{'energyUsed'      , 'Energy Used'},
	{'energyProduced'  , 'Energy Produced'},
	{'damageDealt'     , 'Damage Dealt'},
	{'damageReceived'  , 'Damage Received'},
	{'unitsProduced'   , 'Units Built'},
	{'unitsKilled'     , 'Units Killed'},
	{'__researchPoints', 'Research Points'},   -- sampled by us (not in engine history)
}

--------------------------------------------------------------------------------
-- config
--------------------------------------------------------------------------------

local DOCUMENT_PATH = "LuaUI/rml/endgraph.rml"

-- must match #endgraph in endgraph.rml
local PANEL_WIDTH  = 1100
local PANEL_HEIGHT = 660
local PLOT_HEIGHT  = 576 -- #plotrow in endgraph.rml, in dp
local END_LABEL_GAP = 13 -- least distance between two labels right of the plot, in dp

local LAYOUT_ID = "endgraph" -- same as the old widget, so a saved position carries over

local GRID_DIVS  = 5     -- number of cells across and up
local LINE_WIDTH = 2.5

-- gl colors of the plot
local HOLE_BG    = {0.043, 0.055, 0.071, 0.92} -- the panel color, as in theme.rcss
local PLOT_BG    = {0.02, 0.03, 0.04, 0.55}
local GRID_COLOR = {1.0, 1.0, 1.0, 0.07}

--------------------------------------------------------------------------------
-- speedups
--------------------------------------------------------------------------------

local spGetMouseState        = Spring.GetMouseState
local spPlaySoundFile        = Spring.PlaySoundFile
local spGetTeamStatsHistory  = Spring.GetTeamStatsHistory
local spGetTeamList          = Spring.GetTeamList
local spGetTeamInfo          = Spring.GetTeamInfo
local spGetTeamColor         = Spring.GetTeamColor
local spGetPlayerInfo        = Spring.GetPlayerInfo
local spGetAIInfo            = Spring.GetAIInfo
local spGetGaiaTeamID        = Spring.GetGaiaTeamID

local math_floor = math.floor
local math_max   = math.max
local math_min   = math.min

local function Clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

--------------------------------------------------------------------------------
-- gl drawing: through WG.StaticGUI when it is there (batched, and cached in a
-- texture), plain gl with a display list otherwise
--------------------------------------------------------------------------------

local glColor, glRect, LineStrip, Flush
local TexCache, DrawCache, FreeCache

local function PlainLineStrip(points, width, color)
	local n = #points
	if n < 4 then return end
	if color then gl.Color(color[1], color[2], color[3], color[4] or 1) end
	gl.LineWidth(width or 1)
	gl.BeginEnd(GL.LINE_STRIP, function()
		for i = 1, n - 1, 2 do
			gl.Vertex(points[i], points[i + 1])
		end
	end)
	gl.LineWidth(1)
end

local function BindDrawing()
	local SG = WG.StaticGUI
	if SG then
		glColor   = SG.Color
		glRect    = SG.Rect
		LineStrip = SG.LineStrip
		Flush     = SG.Flush
		TexCache  = SG.TexCache
		DrawCache = SG.DrawCache
		FreeCache = SG.FreeCache
	else
		glColor   = gl.Color
		glRect    = gl.Rect
		LineStrip = PlainLineStrip
		Flush     = function() end
		TexCache  = function(cache, _, _, _, _, fn)
			if cache then gl.DeleteList(cache) end
			return gl.CreateList(fn)
		end
		DrawCache = function(cache) if cache then gl.CallList(cache) end end
		FreeCache = function(cache) if cache then gl.DeleteList(cache) end end
	end
end

--------------------------------------------------------------------------------
-- state
--------------------------------------------------------------------------------

local hud
local document
local page

local isOpen  = false
local uiScale = 1.0 -- pixels per dp
local plot    = nil -- {x1, y1, x2, y2}: #plot on screen, y up; nil until laid out

local team         = {}     -- {id, color={r,g,b,1}, name, show, array, hasData}
local visibleTeams = {}     -- indices into team[] that are currently readable, packed
local selectedStat = 1
local isDelta      = false

local rpHistory      = {}   -- rpHistory[teamID][sampleIndex] = RP value (from ledger broadcast)

local graphLength  = 0
local graphMax     = 0
local gameTime     = 0
local enoughData   = false

local plotCache    = nil
local plotDirty    = true
local pageDirty    = true
local refreshTimer = 0
local legendMarkup
local plotHover    = false -- the mouse is on #plot (told by RmlUi)
local hoverAt      = nil   -- {fx, fy}: where in the plot the mouse is, 0..1 each
local guiHidden    = false

local function PlayClickSound() spPlaySoundFile("leftclick", 1.0, "ui") end

--------------------------------------------------------------------------------
-- formatting (ported from Funks' Chili version)
--------------------------------------------------------------------------------

local function numFormat(value)
	value = math_floor(value or 0)
	local label
	if value/1000000000 >= 1 then
		label = string.sub(value/1000000000 .. '', 0, 4) .. 'B'
	elseif value/1000000 >= 1 then
		label = string.sub(value/1000000 .. '', 0, 4) .. 'M'
	elseif value/10000 >= 1 then
		label = string.sub(value/1000 .. '', 0, 4) .. 'k'
	else
		label = math_floor(value) .. ''
	end
	if label:find('%.') == 4 then
		label = label:gsub('%.', '')
	end
	return label
end

local function formatTime(seconds, short)
	seconds = math_floor(seconds or 0)
	local minutes = math_floor(seconds/60)
	seconds = seconds % 60
	if short then
		if seconds < 10 then seconds = '0' .. seconds end
		return minutes..':'..seconds
	else
		return minutes..' min '..seconds..' sec'
	end
end

--------------------------------------------------------------------------------
-- Team gathering (ported, with faithful AI-name logic preserved)
--------------------------------------------------------------------------------

local function getTeamInfo()
	team = {}
	local gaia = spGetGaiaTeamID and spGetGaiaTeamID() or -1
	for _, engineID in ipairs(spGetTeamList() or {}) do
		if engineID ~= gaia then
			local _, teamLeader, _, isAI = spGetTeamInfo(engineID, false)
			local name = spGetPlayerInfo(teamLeader, false)

			if isAI then
				local _, botID, _, shortName = spGetAIInfo(engineID)
				if botID then
					name = tostring(botID) .. ' (' .. tostring(shortName) .. ')'
				end
			end

			if name == nil or name == "" then
				name = "Team " .. engineID
			end

			-- Gather every non-Gaia team unconditionally. Resigned or eliminated
			-- teams still own a full stats history and belong in an end graph, so
			-- we no longer drop them on an "is the leader active" check. Whether a
			-- given team is actually drawn is decided later by hasData, which
			-- respects engine access gating: an enemy stays hidden for a live
			-- non-spectator, while a resigned ally (or anyone, post-game) appears.
			local r, g, b = spGetTeamColor(engineID)
			team[#team + 1] = {
				id      = engineID,
				color   = {r or 1, g or 1, b or 1, 1},
				name    = name,
				show    = true,
				array   = nil,
				hasData = false,
			}
		end
	end
end

--------------------------------------------------------------------------------
-- Data refresh
--   GetTeamStatsHistory is engine-access-gated: enemy teams return nothing for a
--   non-spectator mid-game, so every access here is guarded and no-data teams are
--   simply skipped (their line just doesn't draw).
--------------------------------------------------------------------------------

local function GetReadableCountTeam()
	for _, teamID in ipairs(spGetTeamList() or {}) do
		local count = spGetTeamStatsHistory(teamID)
		if count and count > 0 then
			return teamID, count
		end
	end
	return nil, 0
end

local function RefreshData()
	local countTeam, count = GetReadableCountTeam()
	graphLength = (count or 0) - 1   -- last index isn't complete
	if graphLength < 1 then graphLength = 0 end
	enoughData  = graphLength >= 4

	-- total game time from a readable team
	gameTime = 0
	if countTeam and graphLength >= 1 then
		local gs = spGetTeamStatsHistory(countTeam, 0, graphLength)
		if gs then
			local last = gs[graphLength-1] or gs[graphLength] or gs[#gs]
			if last then gameTime = last['time'] or 0 end
		end
	end

	local statKey = statName[selectedStat][1]
	local isRP = (statKey == '__researchPoints')
	graphMax = 0

	for t = 1, #team do
		local tm = team[t]
		tm.array   = nil
		tm.hasData = false

		if isRP then
			-- Research Points come from the ledger's broadcast (authoritative, access
			-- -gated per client), not GetTeamStatsHistory. The series has its own
			-- uniform cadence, so plot by its length rather than the engine's.
			local hist = rpHistory[tm.id]
			if hist then
				-- contiguous run from index 1 (guards gaps for a late-joining client)
				local total = 0
				while hist[total+1] ~= nil do total = total + 1 end
				if total >= 2 then
					local arr = {}
					local n   = 0
					local upto = isDelta and (total - 1) or total
					for i = 1, upto do
						local v = hist[i]
						if isDelta then v = (hist[i+1] or v) - v end
						n = n + 1
						arr[n] = v
						if tm.show and v > graphMax then graphMax = v end
					end
					if n > 0 then
						tm.array   = arr
						tm.hasData = true
					end
				end
			end
		else
			local stats = spGetTeamStatsHistory(tm.id, 0, graphLength)
			if stats and stats[1] then
				local arr = {}
				local n   = 0
				for i = 1, graphLength - 1 do
					local row = stats[i]
					if not row then break end
					local v = row[statKey] or 0
					if isDelta then
						local nrow = stats[i+1]
						v = ((nrow and (nrow[statKey] or 0)) or v) - v
					end
					n = n + 1
					arr[n] = v
					if tm.show and v > graphMax then graphMax = v end
				end
				if n > 0 then
					tm.array   = arr
					tm.hasData = true
				end
			end
		end
	end

	-- Pack the teams whose data is currently readable into contiguous legend
	-- slots. Recomputed here rather than in BuildGeometry because readability
	-- changes at game over (enemy teams become visible) without a resize.
	visibleTeams = {}
	for t = 1, #team do
		if team[t].hasData then
			visibleTeams[#visibleTeams + 1] = t
		end
	end

	if graphMax <= 0 then graphMax = 1 end
end

--------------------------------------------------------------------------------
-- the plot (gl)
--------------------------------------------------------------------------------

-- Where #plot is on screen. RmlUi lays the document out, so the element is
-- asked; y is turned to count up from the bottom, as gl wants it.
local function ReadPlotRect()
	local element = page.Element("plot")
	if not element then return nil end
	local ok, left, top, w, h = pcall(function()
		return element.absolute_left, element.absolute_top, element.offset_width, element.offset_height
	end)
	if not ok or not w or w < 8 or h < 8 then return nil end
	local _, vsy = Spring.GetViewGeometry()
	return { x1 = left, y1 = vsy - (top + h), x2 = left + w, y2 = vsy - top }
end

local function PlotXY(p, i, n, v)
	local px = (n > 1) and (p.x1 + (i-1)/(n-1) * (p.x2-p.x1)) or p.x1
	local py = p.y1 + (v/graphMax) * (p.y2-p.y1)
	return px, py
end

local function BakeGrid()
	local p = plot
	glColor(HOLE_BG[1], HOLE_BG[2], HOLE_BG[3], HOLE_BG[4])
	glRect(p.x1, p.y1, p.x2, p.y2)
	glColor(PLOT_BG[1], PLOT_BG[2], PLOT_BG[3], PLOT_BG[4])
	glRect(p.x1, p.y1, p.x2, p.y2)
	if not enoughData then return end
	glColor(GRID_COLOR[1], GRID_COLOR[2], GRID_COLOR[3], GRID_COLOR[4])
	for i = 0, GRID_DIVS do
		local fy = math_min(p.y1 + (p.y2-p.y1) * (i/GRID_DIVS), p.y2 - 1)
		glRect(p.x1, fy, p.x2, fy+1)
		local fx = math_min(p.x1 + (p.x2-p.x1) * (i/GRID_DIVS), p.x2 - 1)
		glRect(fx, p.y1, fx+1, p.y2)
	end
end

-- Reused across frames so plotting does not allocate a fresh point array for
-- every team on every draw.
local linePoints = {}

local function BakeLines()
	local p = plot
	local w = LINE_WIDTH * uiScale

	for t = 1, #team do
		local tm = team[t]
		if tm.show and tm.hasData and tm.array then
			local arr = tm.array
			local n   = #arr
			if n >= 2 then
				local k = 0
				for i = 1, n do
					local px, py = PlotXY(p, i, n, arr[i])
					linePoints[k + 1] = px
					linePoints[k + 2] = py
					k = k + 2
				end
				-- Trim any leftovers from a longer previous team.
				for i = #linePoints, k + 1, -1 do
					linePoints[i] = nil
				end

				-- One capsule per segment rather than a GL_LINE_STRIP. Beyond
				-- batching, this sidesteps glLineWidth: widths above 1.0 are
				-- not required to be supported in OpenGL core profile and are
				-- commonly clamped to 1.0 on macOS, so LINE_WIDTH was being
				-- silently ignored there. Capsule ends also give round joins
				-- for free, which line strips do not.
				LineStrip(linePoints, w, tm.color)
			end
		end
	end
end

local function BuildPlotCache()
	plotCache = TexCache(plotCache, plot.x1, plot.y1, plot.x2, plot.y2, function()
		BakeGrid()
		if enoughData then
			BakeLines()
		end
	end)
	plotDirty = false
end

--------------------------------------------------------------------------------
-- the window (RmlUi)
--------------------------------------------------------------------------------

local function StatsRML()
	local parts = {}
	for i = 1, #statName do
		parts[i] = string.format('<div id="st%d" class="pick" data-st="%d">%s</div>', i, i, hud.Escape(statName[i][2]))
	end
	return table.concat(parts)
end

local function LegendRML()
	local parts = {}
	for slot = 1, #visibleTeams do
		local tm = team[visibleTeams[slot]]
		local c = tm.color
		parts[slot] = string.format(
			'<div class="lrow%s" data-t="%d"><div class="sw" style="background-color: %s;"/><div class="lname" style="color: %s;">%s</div></div>',
			tm.show and "" or " off", slot, hud.Rgb(c[1], c[2], c[3]), hud.ReadableColor(c[1], c[2], c[3]), hud.Escape(tm.name))
	end
	return table.concat(parts)
end

-- Each shown line's last value, right of where the line ends, pushed apart
-- where two would overlap.
local function EndLabelsRML()
	local labels = {}
	for t = 1, #team do
		local tm = team[t]
		if tm.show and tm.hasData and tm.array and #tm.array >= 1 then
			local v = tm.array[#tm.array]
			labels[#labels+1] = { y = v / graphMax, text = numFormat(v), color = tm.color }
		end
	end
	table.sort(labels, function(a, b) return a.y < b.y end)
	local minGap = END_LABEL_GAP / PLOT_HEIGHT
	for i = 2, #labels do
		if labels[i].y < labels[i-1].y + minGap then
			labels[i].y = labels[i-1].y + minGap
		end
	end
	local parts = {}
	for i = 1, #labels do
		local l = labels[i]
		parts[i] = string.format('<div class="end" style="bottom: %.1f%%; color: %s;">%s</div>',
			Clamp(l.y, 0.012, 1.0) * 100, hud.ReadableColor(l.color[1], l.color[2], l.color[3]), l.text)
	end
	return table.concat(parts)
end

-- The box at the mouse: the time there, and each shown team's value then.
local function TipRML()
	if not hoverAt or not enoughData then return nil end
	local rows = {}
	for t = 1, #team do
		local tm = team[t]
		if tm.show and tm.hasData and tm.array and #tm.array >= 2 then
			local n = #tm.array
			local i = Clamp(math_floor(hoverAt.fx * (n - 1) + 0.5) + 1, 1, n)
			rows[#rows + 1] = { v = tm.array[i], tm = tm }
		end
	end
	table.sort(rows, function(a, b) return a.v > b.v end)
	local lines = {}
	lines[1] = string.format('<div><span class="d">Time </span><span class="n">%s</span><span class="d">   Score </span><span class="n">%s</span></div>',
		formatTime(gameTime * hoverAt.fx, true), numFormat(graphMax * hoverAt.fy))
	for i = 1, #rows do
		local c = rows[i].tm.color
		lines[#lines + 1] = string.format('<div><span style="color: %s;">%s</span>  <span class="n">%s</span></div>',
			hud.ReadableColor(c[1], c[2], c[3]), hud.Escape(rows[i].tm.name), numFormat(rows[i].v))
	end
	return table.concat(lines)
end

-- Puts the box next to the mouse: right of and below it, or left of and above
-- it in the right and lower parts of the window, so it never leaves the window.
local function PlaceTip()
	local window = page.Element("endgraph")
	local ok, left, top, w, h = pcall(function()
		return window.absolute_left, window.absolute_top, window.offset_width, window.offset_height
	end)
	if not ok or not w then return end
	local mx, my = spGetMouseState()
	local _, vsy = Spring.GetViewGeometry()
	local x, y = mx - left, (vsy - my) - top
	local gap = math_floor(14 * uiScale)
	if x > w * 0.6 then
		page.SetStyle("tip", "left", "auto")
		page.SetStyle("tip", "right", math_floor(w - x + gap) .. "px")
	else
		page.SetStyle("tip", "right", "auto")
		page.SetStyle("tip", "left", math_floor(x + gap) .. "px")
	end
	if y > h * 0.55 then
		page.SetStyle("tip", "top", "auto")
		page.SetStyle("tip", "bottom", math_floor(h - y + gap) .. "px")
	else
		page.SetStyle("tip", "bottom", "auto")
		page.SetStyle("tip", "top", math_floor(y + gap) .. "px")
	end
end

local function RefreshTip()
	local text = TipRML()
	page.SetClass("tip", "hidden", text == nil)
	if text then
		page.SetText("tip", text)
		PlaceTip()
	end
end

local function Refresh()
	page.SetClass("endgraph", "hidden", not isOpen)
	if not isOpen then
		return
	end
	pageDirty = false

	page.SetText("title", statName[selectedStat][2])
	page.SetText("subtitle", isDelta and "per interval" or "")
	page.SetText("total-value", formatTime(gameTime, false))
	for i = 1, #statName do
		page.SetClass("st" .. i, "active", i == selectedStat)
	end
	page.SetClass("delta", "active", isDelta)

	local markup = LegendRML()
	if markup ~= legendMarkup then
		legendMarkup = markup
		page.Element("legend").inner_rml = markup
	end

	page.SetClass("nodata", "hidden", enoughData)
	for i = 0, GRID_DIVS do
		page.SetText("ax" .. i, enoughData and numFormat(graphMax * (i/GRID_DIVS)) or "")
		page.SetText("tm" .. i, enoughData and formatTime(gameTime * (i/GRID_DIVS), true) or "")
	end
	page.SetText("values", enoughData and EndLabelsRML() or "")
	RefreshTip()
end

--------------------------------------------------------------------------------
-- open and close
--------------------------------------------------------------------------------

local function DefaultOrigin(vsx, vsy, w, h, scale)
	return (vsx - w) * 0.5, (vsy - h) * 0.5
end

local function Place()
	uiScale = hud.GetScale()
	hud.PlacePanel(page.Element("endgraph"), LAYOUT_ID, PANEL_WIDTH, PANEL_HEIGHT, DefaultOrigin)
	plot = nil -- read again once RmlUi has laid the window out
	plotDirty = true
end

local function Changed()
	RefreshData()
	plotDirty = true
	Refresh()
end

local function EnsureTeams()
	if #team == 0 then getTeamInfo() end
end

local function Open()
	if isOpen or not document then return end
	isOpen = true
	hoverAt, plot = nil, nil
	refreshTimer = 0
	EnsureTeams()
	pcall(function() document:PullToFront() end)
	PlayClickSound()
	Changed()
end

local function Close()
	if not isOpen then return end
	isOpen = false
	hoverAt = nil
	PlayClickSound()
	Refresh()
end

local function Toggle()
	if isOpen then Close() else Open() end
end

--------------------------------------------------------------------------------
-- widget api
--------------------------------------------------------------------------------

local gameOverHandled = false
local function HandleGameOver()
	if gameOverHandled then return end
	gameOverHandled = true
	-- Open FIRST so a helper error can never leave the window shut.
	isOpen       = true
	plotDirty    = true
	pageDirty    = true
	refreshTimer = 0
	-- Guarded: a throw in here must not propagate and disable the widget.
	pcall(function()
		getTeamInfo()   -- engine grants fullRead at game over; re-read teams
		RefreshData()
		document:PullToFront()
	end)
end

-- Receives RP samples from game_researchpoints_ledger (gadget). The gadget's
-- unsynced side has already gated which teams this client may receive, so we can
-- store whatever arrives. The open window picks it up at its next refresh.
local function ResearchSampleEvent(teamID, index, value)
	local arr = rpHistory[teamID]
	if not arr then arr = {} ; rpHistory[teamID] = arr end
	arr[index] = value
end

function widget:Initialize()
	local helpers = include("rml/hud.lua")
	local result, reason = helpers.LoadDocument(DOCUMENT_PATH, widget)
	if not result then
		Spring.Echo("[End Graph] " .. tostring(reason))
		widgetHandler:RemoveWidget(self)
		return
	end
	hud = helpers
	document = result
	BindDrawing()
	Spring.SendCommands("endgraph 0")   -- suppress the engine's built-in graph

	page = hud.NewView(document)
	page.Assume("endgraph", "hidden", true) -- set in the markup
	page.Assume("tip", "hidden", true)
	page.Element("stats").inner_rml = StatsRML()

	getTeamInfo()

	hud.OnClick(page, "close", Close)
	page.Element("stats"):AddEventListener("mousedown", function(event)
		local i = hud.EventAttribute(event, "data-st")
		if i and statName[i] and i ~= selectedStat and event.parameters and event.parameters.button == 0 then
			selectedStat = i
			PlayClickSound()
			Changed()
		end
	end)
	hud.OnClick(page, "delta", function()
		isDelta = not isDelta
		PlayClickSound()
		Changed()
	end)
	-- a click on a team hides or shows its line
	page.Element("legend"):AddEventListener("mousedown", function(event)
		local slot = hud.EventAttribute(event, "data-t")
		local ti = slot and visibleTeams[slot]
		if ti and event.parameters and event.parameters.button == 0 then
			team[ti].show = not team[ti].show
			PlayClickSound()
			Changed() -- rescales the plot over the lines still shown
		end
	end)
	local plotElement = page.Element("plot")
	plotElement:AddEventListener("mouseover", function() plotHover = true end)
	plotElement:AddEventListener("mouseout", function() plotHover = false end)

	widgetHandler:RegisterGlobal('ResearchSampleEvent', ResearchSampleEvent)

	WG.StaticEndGraph = {
		Toggle = Toggle,
		Show   = Open,
		Hide   = Close,
		-- Overlay widgets (world-anchored buttons, labels, etc.) poll this and
		-- stop drawing while the graph covers the screen.
		IsOpen = function() return isOpen end,
	}

	hud.RegisterPanel(LAYOUT_ID, "End Graph", Place, function() return isOpen end)
	Place()
	hud.ShowPassive(document)
end

function widget:Shutdown()
	if hud then
		hud.UnregisterPanel(LAYOUT_ID)
	end
	if FreeCache then
		FreeCache(plotCache)
		plotCache = nil
	end
	if document then
		widgetHandler:DeregisterGlobal('ResearchSampleEvent')
		Spring.SendCommands("endgraph 1")   -- restore engine graph for other widgets
		document:Close()
		document = nil
	end
	WG.StaticEndGraph = nil
end

function widget:ViewResize()
	if hud and document then
		hud.UpdateScale()
		Place()
		page.ForgetStyles()
		pageDirty = true
	end
end

function widget:KeyPress(key, mods, isRepeat)
	if isRepeat or not isOpen then return false end
	local sym = Spring.GetKeySymbol(key)
	if sym == "esc" or sym == "escape" then
		Close()
		return true
	end
	return false
end

function widget:GameOver(winningAllyTeams)
	-- Kept in case a future engine build delivers this callin to LuaUI; the
	-- Update poll handles it today. gameOverHandled dedupes either way.
	HandleGameOver()
end

function widget:Update(dt)
	if not document then
		return
	end
	-- This engine does not deliver the GameOver callin to LuaUI, so poll for it.
	if not gameOverHandled and Spring.IsGameOver and Spring.IsGameOver() then
		HandleGameOver()
	end
	guiHidden = hud.FollowGuiHidden(document)
	if guiHidden or not isOpen then
		return
	end

	refreshTimer = refreshTimer + (dt or 0)
	if refreshTimer >= 2.0 then
		refreshTimer = 0
		RefreshData()
		plotDirty = true
		pageDirty = true
	end
	if pageDirty then
		Refresh()
	end

	-- where in the plot the mouse is
	local at = nil
	if plotHover and plot and enoughData then
		local mx, my = spGetMouseState()
		if mx >= plot.x1 and mx <= plot.x2 and my >= plot.y1 and my <= plot.y2 then
			at = { fx = (mx - plot.x1) / math_max(1, plot.x2 - plot.x1), fy = (my - plot.y1) / math_max(1, plot.y2 - plot.y1) }
		end
	end
	if at or hoverAt then
		hoverAt = at
		RefreshTip()
	end
end

function widget:DrawScreen()
	if not document or not isOpen or guiHidden then return end

	-- #plot may have moved (the window was dragged, the view resized)
	local rect = ReadPlotRect()
	if not rect then return end
	if not plot or rect.x1 ~= plot.x1 or rect.y1 ~= plot.y1 or rect.x2 ~= plot.x2 or rect.y2 ~= plot.y2 then
		plot = rect
		plotDirty = true
	end
	if plotDirty or not plotCache then
		BuildPlotCache()
	end
	DrawCache(plotCache, plot.x1, plot.y1)

	-- crosshair at the mouse
	if hoverAt and enoughData then
		local p = plot
		local mx, my = spGetMouseState()
		glColor(1, 1, 1, 0.15)
		glRect(mx, p.y1, mx+1, p.y2)
		glRect(p.x1, my, p.x2, my+1)
	end
	glColor(1, 1, 1, 1)
	Flush()
end
