function widget:GetInfo()
	return {
		name      = "Static EndGame Graph",
		desc      = "Static-style end-of-game stats graph. Toggleable mid-game (data is engine-gated: non-spectators only see their own/allied lines).",
		author    = "",
		date      = "2026-03-22",
		license   = "GNU GPL, v2 or later",
		layer     = 1002,
		enabled   = true,
	}
end

include("keysym.h.lua")

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
-- Config
--------------------------------------------------------------------------------

local bgcorner  = "LuaUI/Images/bgcorner.png"
local accentImg = ":n:LuaUI/Images/staticgui_accent.png"

local BASE_RESOLUTION     = 1080
local PANEL_WIDTH         = 1100
local PANEL_HEIGHT        = 660
local OUTER_CORNER        = 10
local INNER_CORNER        = 8.5
local INNER_INSET         = 2.25
local PANEL_ACCENT_HEIGHT = 5

local INNER_PAD     = 12
local TITLE_BAR_H   = 30
local SIDEBAR_W     = 180
local VALUE_STRIP_W = 50
local TIME_STRIP_H  = 20
local AXIS_STRIP_W  = 46    -- left gutter for Y-axis value labels
local STAT_BTN_H    = 26
local STAT_BTN_GAP  = 4
local LEGEND_ROW_H  = 22
local DELTA_ROW_H   = 24
local SECTION_GAP   = 8

local GRID_DIVS     = 5     -- number of cells across/up (lines drawn at 1..GRID_DIVS-1)
local LINE_WIDTH    = 2.5

-- Colors -----------------------------------------------------------------------
local BORDER_COLOR        = {0.15, 0.15, 0.15, 0.90}
local BORDER_COLOR_GUI    = {0.15, 0.15, 0.15, 0.90}
local PANEL_BG_COLOR      = {0.05, 0.05, 0.06, 0.92}
local PANEL_BG_COLOR_GUI  = {0.00, 0.00, 0.00, 0.28}
local SECTION_BG          = {0.12, 0.12, 0.13, 0.85}
local CATEGORY_BG         = {0.20, 0.20, 0.21, 0.55}
local PLOT_BG             = {0.02, 0.02, 0.03, 0.55}
local GRID_COLOR          = {1.0, 1.0, 1.0, 0.07}
local HOVER_OVERLAY       = {0.90, 0.90, 0.90, 0.09}
local SELECTED_OVERLAY    = {0.18, 0.52, 0.98, 0.18}

local ACCENT_PANEL  = {0.18, 0.52, 0.98, 1}
local ACCENT_STAT   = {0.18, 0.52, 0.98, 1}
local ACCENT_DELTA  = {0.55, 0.35, 0.95, 1}
local ACCENT_CLOSE  = {0.90, 0.22, 0.22, 1}

local TEXT_COLOR    = "\255\244\244\244"
local TEXT_DIM      = "\255\160\162\168"
local TEXT_ACCENT   = "\255\120\180\255"

--------------------------------------------------------------------------------
-- Speedups
--------------------------------------------------------------------------------

-- Raw engine entry points. Only the legacy fallback path below uses these
-- directly; everything else goes through the shim locals so that drawing is
-- batched by the shapes module when it is available.
local rawColor     = gl.Color
local rawRect      = gl.Rect
local rawTexture   = gl.Texture
local rawTexRect   = gl.TexRect
local rawScissor   = gl.Scissor
local rawLineWidth = gl.LineWidth
local rawBeginEnd  = gl.BeginEnd
local rawVertex    = gl.Vertex
local GL_LINE_STRIP = GL.LINE_STRIP

local spGetViewGeometry      = Spring.GetViewGeometry
local spGetMouseState        = Spring.GetMouseState
local spPlaySoundFile        = Spring.PlaySoundFile
local spGetTeamStatsHistory  = Spring.GetTeamStatsHistory
local spGetTeamList          = Spring.GetTeamList
local spGetTeamInfo          = Spring.GetTeamInfo
local spGetTeamColor         = Spring.GetTeamColor
local spGetPlayerInfo        = Spring.GetPlayerInfo
local spGetAIInfo            = Spring.GetAIInfo
local spGetGaiaTeamID        = Spring.GetGaiaTeamID
local spIsGUIHidden          = Spring.IsGUIHidden

local math_floor = math.floor
local math_max   = math.max
local math_min   = math.min

local function Clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

--------------------------------------------------------------------------------
-- Drawing shim
--
-- Panel chrome used to be drawn with gl.Rect / gl.TexRect / gl.BeginEnd, which
-- is OpenGL 1.1 immediate mode. That path does not exist in core profile,
-- which is the only way to get past GL 2.1 on macOS, and it is what tanks
-- frame rate on any driver that translates GL to Metal or Vulkan.
--
-- All of it now goes through WG.StaticGUI (api_staticgui_shapes.lua), which
-- batches every shape into one instanced draw call and rounds corners in a
-- fragment shader.
--
-- If that module failed to load - unsupported driver, shader compile error -
-- these shims fall back to the original immediate-mode code so the widget
-- still renders. It will be slow, but it will not be blank.
--------------------------------------------------------------------------------

-- Corner texture, used only by the legacy fallback. The shapes module rounds
-- corners analytically and never binds it.
local bgcornerLegacy = bgcorner

local glColor, glRect, glTexture, glTexRect, glScissor
local RectRound, LineStrip, AccentStrip, Flush
local TexCache, DrawCache, FreeCache
local usingShapes = false

local function LegacyRectRound(px, py, sx, sy, cs)
	px, py, sx, sy, cs = math_floor(px), math_floor(py), math_floor(sx), math_floor(sy), math_floor(cs)
	rawRect(px+cs, py, sx-cs, sy)
	rawRect(sx-cs, py+cs, sx, sy-cs)
	rawRect(px, py+cs, px+cs, sy-cs)
	rawTexture(bgcornerLegacy)
	rawTexRect(px, py+cs, px+cs, py)
	rawTexRect(sx, py+cs, sx-cs, py)
	rawTexRect(px, sy-cs, px+cs, sy)
	rawTexRect(sx, sy-cs, sx-cs, sy)
	rawTexture(false)
end

local function LegacyLineStrip(points, width, color)
	local n = #points
	if n < 4 then return end
	if color then rawColor(color[1], color[2], color[3], color[4] or 1) end
	rawLineWidth(width or 1)
	rawBeginEnd(GL_LINE_STRIP, function()
		for i = 1, n - 1, 2 do
			rawVertex(points[i], points[i + 1])
		end
	end)
	rawLineWidth(1)
end

local function LegacyAccentStrip(x1, y1, x2, y2)
	rawTexture(accentImg)
	rawTexRect(x1, y1, x2, y2)
	rawTexture(false)
end

local function NoOp() end

local function BindDrawing()
	local SG = WG.StaticGUI
	if SG then
		glColor   = SG.Color
		glRect    = SG.Rect
		glTexture = SG.Texture
		glTexRect = SG.TexRect
		glScissor = SG.Scissor
		RectRound = SG.RectRound
		AccentStrip = SG.AccentStrip
		LineStrip = SG.LineStrip
		Flush     = SG.Flush
		TexCache      = SG.TexCache
		DrawCache     = SG.DrawCache
		FreeCache     = SG.FreeCache
		usingShapes = true
	else
		glColor   = rawColor
		glRect    = rawRect
		glTexture = rawTexture
		glTexRect = rawTexRect
		glScissor = rawScissor
		RectRound = LegacyRectRound
		AccentStrip = LegacyAccentStrip
		LineStrip = LegacyLineStrip
		Flush     = NoOp
		-- No recorder without the shape module, so fall back to real display
		-- lists: exactly what this widget did before the port.
		-- No FBO textures without the shape module: a legacy cache handle is
		-- a real display list id, exactly what this widget used originally.
		TexCache      = function(cache, _, _, _, _, fn)
			if cache then gl.DeleteList(cache) end
			return gl.CreateList(fn)
		end
		DrawCache     = function(cache) if cache then gl.CallList(cache) end end
		FreeCache     = function(cache) if cache then gl.DeleteList(cache) end end
		usingShapes = false
	end
end

BindDrawing()

--------------------------------------------------------------------------------
-- Font
--------------------------------------------------------------------------------

local vsx, vsy      = spGetViewGeometry()
local uiScale       = 1.0
local fontfile      = LUAUI_DIRNAME .. "fonts/" .. Spring.GetConfigString("ui_font", "Saira_SemiCondensed-SemiBold.ttf")
local fontfileScale = (0.5 + (vsx * vsy / 5700000))
local font

-- The shapes module batches, so text drawn between two shape calls would land
-- underneath them. Wrapping the font makes font:Begin() flush the pending
-- batch first, which keeps every existing font:Print call site correct without
-- having to audit draw order by hand.
local function ReloadFont()
	local SG = WG.StaticGUI

	if font then
		if SG and SG.DeleteFont then
			SG.DeleteFont(font)
		else
			gl.DeleteFont(font)
		end
		font = nil
	end

	local f = gl.LoadFont(fontfile, 23*fontfileScale, 5*fontfileScale, 1.8)
	if f and SG and SG.WrapFont then
		f = SG.WrapFont(f)
	end
	font = f
end

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local isOpen      = false
local panelRect   = {x1=0, y1=0, x2=0, y2=0}
local geom        = {}

local team         = {}     -- {id, color={r,g,b,1}, name, show, array, hasData}
local visibleTeams = {}     -- indices into team[] that are currently readable, packed
local selectedStat = 1
local isDelta      = false

local rpHistory      = {}   -- rpHistory[teamID][sampleIndex] = RP value (from ledger broadcast)

local graphLength  = 0
local graphMax     = 0
local gameTime     = 0
local enoughData   = false

-- Texture cache (see api_staticgui_shapes.lua) and its invalidation flag,
-- replacing first the gl.CreateList display list and then an SG.Record list.
-- The recorded list still replayed ~1500 line-segment ops in Lua every frame,
-- which kept this the most expensive widget in the suite; the cache renders
-- the whole graph into one texture on contentDirty and draws one quad.
local contentList  = nil
local contentDirty = true

local refreshTimer = 0

local hoveredKey   = nil    -- dedup for hover sound across interactive elements

--------------------------------------------------------------------------------
-- Sound
--------------------------------------------------------------------------------

local function PlayHoverSound() spPlaySoundFile("hover",     1.0, "ui") end
local function PlayClickSound() spPlaySoundFile("leftclick", 1.0, "ui") end

--------------------------------------------------------------------------------
-- Formatting (ported from Funks' Chili version)
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

local function ColorEscape(r, g, b)
	return "\255" .. string.char(
			math_max(1, math_min(255, math_floor((r or 1)*255))),
			math_max(1, math_min(255, math_floor((g or 1)*255))),
			math_max(1, math_min(255, math_floor((b or 1)*255)))
	)
end

--------------------------------------------------------------------------------
-- Theme helpers
--------------------------------------------------------------------------------

local function GetBorderColor()
	if WG.guishader then return BORDER_COLOR_GUI end
	return BORDER_COLOR
end

local function GetPanelBGColor()
	if WG.guishader then return PANEL_BG_COLOR_GUI end
	return PANEL_BG_COLOR
end

-- RectRound now lives in the drawing shim above: either WG.StaticGUI.RectRound
-- (one instance, corner rounded in the fragment shader) or LegacyRectRound
-- (the original 3 quads + 4 corner blits) if the shapes module is unavailable.

local function DrawPanelChrome(x1, y1, x2, y2, accent)
	local bc  = GetBorderColor()
	local pc  = GetPanelBGColor()
	local oc  = OUTER_CORNER * uiScale
	local ic  = INNER_CORNER * uiScale
	local ins = INNER_INSET  * uiScale
	local ah  = PANEL_ACCENT_HEIGHT * uiScale
	glColor(bc[1], bc[2], bc[3], bc[4])
	RectRound(x1, y1, x2, y2, oc)
	glColor(pc[1], pc[2], pc[3], pc[4])
	RectRound(x1+ins, y1+ins, x2-ins, y2-ins, ic)
	if accent then
		glColor(accent[1], accent[2], accent[3], 1)
		AccentStrip(x1+ins, y2-ins-ah, x2-ins, y2-ins)
	end
end

local function DrawBox(x1, y1, x2, y2, col, cs)
	glColor(col[1], col[2], col[3], col[4])
	RectRound(x1, y1, x2, y2, (cs or 4)*uiScale)
end

local function DrawAccentStrip(x1, x2, y2, accent)
	local ah = PANEL_ACCENT_HEIGHT * uiScale
	glColor(accent[1], accent[2], accent[3], 1)
	AccentStrip(x1, y2-ah, x2, y2)
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
-- Geometry
--------------------------------------------------------------------------------

local function BuildGeometry()
	uiScale = vsy / BASE_RESOLUTION

	local pw  = PANEL_WIDTH  * uiScale
	local ph  = PANEL_HEIGHT * uiScale
	local pad = INNER_PAD    * uiScale
	local acc = PANEL_ACCENT_HEIGHT * uiScale

	local x1 = math_floor(vsx * 0.5 - pw * 0.5)
	local y1 = math_floor(vsy * 0.5 - ph * 0.5)
	local x2 = x1 + math_floor(pw)
	local y2 = y1 + math_floor(ph)
	panelRect = {x1=x1, y1=y1, x2=x2, y2=y2}

	local cx1 = x1 + pad
	local cx2 = x2 - pad
	local cy1 = y1 + pad
	local cy2 = y2 - pad - acc   -- leave room for the top accent strip

	-- Title bar across the top
	local titleH   = TITLE_BAR_H * uiScale
	local titleY2  = cy2
	local titleY1  = titleY2 - titleH

	-- Close button (square) at top-right of the title bar
	local closeSz  = titleH
	local closeRect = {x1=cx2-closeSz, y1=titleY1, x2=cx2, y2=titleY2}

	-- Sidebar (left) and plot (right) share the region below the title bar
	local bodyY2   = titleY1 - SECTION_GAP*uiScale
	local bodyY1   = cy1
	local sbW      = SIDEBAR_W * uiScale
	local sbX1     = cx1
	local sbX2     = sbX1 + sbW

	local plotOuterX1 = sbX2 + SECTION_GAP*uiScale
	local plotOuterX2 = cx2
	local plotOuterY1 = bodyY1
	local plotOuterY2 = bodyY2

	-- Within the plot region, reserve gutters for axis labels
	local axisW  = AXIS_STRIP_W  * uiScale
	local valW   = VALUE_STRIP_W * uiScale
	local timeH  = TIME_STRIP_H  * uiScale

	local plotX1 = plotOuterX1 + axisW
	local plotX2 = plotOuterX2 - valW
	local plotY1 = plotOuterY1 + timeH
	local plotY2 = plotOuterY2

	-- Sidebar internal: stat buttons (top), legend (middle), delta toggle (bottom)
	local statBtnH = STAT_BTN_H   * uiScale
	local statGap  = STAT_BTN_GAP * uiScale
	local legendH  = LEGEND_ROW_H * uiScale
	local deltaH   = DELTA_ROW_H  * uiScale

	local statBtns = {}
	local cursor = bodyY2
	for i = 1, #statName do
		local by2 = cursor
		local by1 = by2 - statBtnH
		statBtns[i] = {x1=sbX1, y1=by1, x2=sbX2, y2=by2}
		cursor = by1 - statGap
	end

	-- Delta toggle pinned to the very bottom of the sidebar
	local deltaRect = {x1=sbX1, y1=bodyY1, x2=sbX2, y2=bodyY1+deltaH}

	-- Legend fills the space between stat buttons and the delta toggle
	local legendTop = cursor - SECTION_GAP*uiScale
	local legendBot = deltaRect.y2 + SECTION_GAP*uiScale
	local legendRows = {}
	local ly2 = legendTop
	for i = 1, #team do
		local ry2 = ly2
		local ry1 = ry2 - legendH
		if ry1 < legendBot then break end   -- clipped; extra teams simply not shown
		legendRows[i] = {x1=sbX1, y1=ry1, x2=sbX2, y2=ry2}
		ly2 = ry1
	end

	geom = {
		pad        = pad,
		titleBar   = {x1=cx1, y1=titleY1, x2=cx2, y2=titleY2},
		closeRect  = closeRect,
		sidebar    = {x1=sbX1, y1=bodyY1, x2=sbX2, y2=bodyY2},
		legendTop  = legendTop,
		legendBot  = legendBot,
		statBtns   = statBtns,
		legendRows = legendRows,
		deltaRect  = deltaRect,
		plotOuter  = {x1=plotOuterX1, y1=plotOuterY1, x2=plotOuterX2, y2=plotOuterY2},
		plot       = {x1=plotX1, y1=plotY1, x2=plotX2, y2=plotY2},
		statBtnH   = statBtnH,
		legendH    = legendH,
	}
end

--------------------------------------------------------------------------------
-- Hit testing
--------------------------------------------------------------------------------

local function InRect(x, y, r)
	return r and x >= r.x1 and x <= r.x2 and y >= r.y1 and y <= r.y2
end

local function IsOnPanel(x, y)
	return x >= panelRect.x1 and x <= panelRect.x2 and y >= panelRect.y1 and y <= panelRect.y2
end

--------------------------------------------------------------------------------
-- Plot mapping
--------------------------------------------------------------------------------

local function PlotXY(p, i, n, v)
	local px = (n > 1) and (p.x1 + (i-1)/(n-1) * (p.x2-p.x1)) or p.x1
	local py = p.y1 + (v/graphMax) * (p.y2-p.y1)
	return px, py
end

--------------------------------------------------------------------------------
-- Baked content drawing
--------------------------------------------------------------------------------

local function BakeTitle()
	local tb = geom.titleBar
	local cap = statName[selectedStat][2]
	if isDelta then cap = cap .. "  (per-interval)" end
	font:Begin()
	font:Print(TEXT_COLOR .. cap, tb.x1 + 4*uiScale, tb.y1 + (tb.y2-tb.y1)*0.5 - 6*uiScale, 16*uiScale, "lo")
	local tStr = TEXT_DIM .. "Total Time  " .. TEXT_COLOR .. formatTime(gameTime, false)
	font:Print(tStr, geom.closeRect.x1 - 12*uiScale, tb.y1 + (tb.y2-tb.y1)*0.5 - 5*uiScale, 12*uiScale, "ro")
	font:End()

	-- Close button glyph
	local cr = geom.closeRect
	DrawBox(cr.x1, cr.y1, cr.x2, cr.y2, CATEGORY_BG, 4)
	DrawAccentStrip(cr.x1, cr.x2, cr.y2, ACCENT_CLOSE)
	font:Begin()
	font:Print(TEXT_COLOR .. "x", cr.x1+(cr.x2-cr.x1)*0.5, cr.y1+(cr.y2-cr.y1)*0.5-6*uiScale, 15*uiScale, "co")
	font:End()
end

local function BakeStatButtons()
	font:Begin()
	for i = 1, #statName do
		local r = geom.statBtns[i]
		local selected = (i == selectedStat)
		DrawBox(r.x1, r.y1, r.x2, r.y2, selected and CATEGORY_BG or SECTION_BG, 4)
		if selected then
			glColor(SELECTED_OVERLAY[1], SELECTED_OVERLAY[2], SELECTED_OVERLAY[3], SELECTED_OVERLAY[4])
			RectRound(r.x1, r.y1, r.x2, r.y2, 4*uiScale)
			DrawAccentStrip(r.x1, r.x2, r.y2, ACCENT_STAT)
		end
		local col = selected and TEXT_COLOR or TEXT_DIM
		font:Print(col .. statName[i][2], r.x1 + 8*uiScale, r.y1+(r.y2-r.y1)*0.5-5*uiScale, 11*uiScale, "lo")
	end
	font:End()
end

local function BakeLegend()
	font:Begin()
	for slot = 1, #visibleTeams do
		local r = geom.legendRows[slot]
		if not r then break end
		local tm = team[visibleTeams[slot]]
		local c  = tm.color
		local sw = 12*uiScale
		local sy = r.y1 + (r.y2-r.y1)*0.5

		if tm.show then
			-- filled swatch + team-colored name = line is ON
			glColor(c[1], c[2], c[3], 1)
			glRect(r.x1+4*uiScale, sy-sw*0.5, r.x1+4*uiScale+sw, sy+sw*0.5)
			font:Print(ColorEscape(c[1], c[2], c[3]) .. tm.name,
			           r.x1+4*uiScale+sw+6*uiScale, sy-5*uiScale, 10*uiScale, "lo")
		else
			-- hollow swatch + dim name = line is OFF (click to re-enable)
			glColor(c[1]*0.45, c[2]*0.45, c[3]*0.45, 1)
			glRect(r.x1+4*uiScale, sy-sw*0.5, r.x1+4*uiScale+sw, sy+sw*0.5)
			glColor(0.08, 0.08, 0.09, 1)
			glRect(r.x1+4*uiScale+1.5*uiScale, sy-sw*0.5+1.5*uiScale,
			       r.x1+4*uiScale+sw-1.5*uiScale, sy+sw*0.5-1.5*uiScale)
			font:Print(TEXT_DIM .. tm.name,
			           r.x1+4*uiScale+sw+6*uiScale, sy-5*uiScale, 10*uiScale, "lo")
		end
	end
	font:End()
end

local function BakeDelta()
	local r = geom.deltaRect
	DrawBox(r.x1, r.y1, r.x2, r.y2, SECTION_BG, 4)
	if isDelta then
		glColor(SELECTED_OVERLAY[1], SELECTED_OVERLAY[2], SELECTED_OVERLAY[3], SELECTED_OVERLAY[4])
		RectRound(r.x1, r.y1, r.x2, r.y2, 4*uiScale)
		DrawAccentStrip(r.x1, r.x2, r.y2, ACCENT_DELTA)
	end
	-- checkbox glyph
	local cs = 12*uiScale
	local cy = r.y1 + (r.y2-r.y1)*0.5
	glColor(0.08, 0.08, 0.09, 1)
	glRect(r.x1+6*uiScale, cy-cs*0.5, r.x1+6*uiScale+cs, cy+cs*0.5)
	if isDelta then
		glColor(ACCENT_DELTA[1], ACCENT_DELTA[2], ACCENT_DELTA[3], 1)
		glRect(r.x1+6*uiScale+2*uiScale, cy-cs*0.5+2*uiScale, r.x1+6*uiScale+cs-2*uiScale, cy+cs*0.5-2*uiScale)
	end
	font:Begin()
	font:Print((isDelta and TEXT_COLOR or TEXT_DIM) .. "Delta (rate)", r.x1+6*uiScale+cs+6*uiScale, cy-5*uiScale, 10*uiScale, "lo")
	font:End()
end

local function BakeGrid()
	local p = geom.plot
	-- plot background
	DrawBox(p.x1, p.y1, p.x2, p.y2, PLOT_BG, 3)

	glColor(GRID_COLOR[1], GRID_COLOR[2], GRID_COLOR[3], GRID_COLOR[4])
	-- horizontal grid + Y value labels
	for i = 0, GRID_DIVS do
		local fy = p.y1 + (p.y2-p.y1) * (i/GRID_DIVS)
		glRect(p.x1, fy, p.x2, fy+1)
	end
	-- vertical grid + X time labels
	for i = 0, GRID_DIVS do
		local fx = p.x1 + (p.x2-p.x1) * (i/GRID_DIVS)
		glRect(fx, p.y1, fx+1, p.y2)
	end

	font:Begin()
	for i = 0, GRID_DIVS do
		local fy = p.y1 + (p.y2-p.y1) * (i/GRID_DIVS)
		local val = graphMax * (i/GRID_DIVS)
		font:Print(TEXT_DIM .. numFormat(val), p.x1 - 5*uiScale, fy - 4*uiScale, 9*uiScale, "ro")
	end
	for i = 0, GRID_DIVS do
		local fx = p.x1 + (p.x2-p.x1) * (i/GRID_DIVS)
		local t  = gameTime * (i/GRID_DIVS)
		local align = (i == 0) and "lo" or ((i == GRID_DIVS) and "ro" or "co")
		font:Print(TEXT_DIM .. formatTime(t, true), fx, p.y1 - TIME_STRIP_H*uiScale*0.7, 9*uiScale, align)
	end
	font:End()
end

-- Reused across frames so plotting does not allocate a fresh point array for
-- every team on every draw.
local linePoints = {}

local function BakeLines()
	local p = geom.plot
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

local function BakeValueLabels()
	local p = geom.plot
	-- collect end-of-line labels for shown teams
	local labels = {}
	for t = 1, #team do
		local tm = team[t]
		if tm.show and tm.hasData and tm.array and #tm.array >= 1 then
			local v = tm.array[#tm.array]
			local _, py = PlotXY(p, #tm.array, #tm.array, v)
			labels[#labels+1] = {y = py, text = numFormat(v), color = tm.color}
		end
	end
	-- de-overlap (push upward), preserving order by y
	table.sort(labels, function(a, b) return a.y < b.y end)
	local minGap = 12 * uiScale
	for i = 2, #labels do
		if labels[i].y < labels[i-1].y + minGap then
			labels[i].y = labels[i-1].y + minGap
		end
	end
	font:Begin()
	for i = 1, #labels do
		local l = labels[i]
		local yy = Clamp(l.y, p.y1, panelRect.y2 - 8*uiScale)
		font:Print(ColorEscape(l.color[1], l.color[2], l.color[3]) .. l.text,
		           p.x2 + 5*uiScale, yy - 5*uiScale, 10*uiScale, "lo")
	end
	font:End()
end

local function BakeNoData()
	local p = geom.plot
	DrawBox(p.x1, p.y1, p.x2, p.y2, PLOT_BG, 3)
	font:Begin()
	font:Print(TEXT_DIM .. "Collecting stats data...",
	           p.x1+(p.x2-p.x1)*0.5, p.y1+(p.y2-p.y1)*0.5-6*uiScale, 13*uiScale, "co")
	font:End()
end

-- This used to be baked into a gl.CreateList display list. Display lists are
-- GL 1.x, removed from core profile alongside immediate mode, and the engine's
-- own font code has a documented workaround for glyph atlas uploads getting
-- recorded into them. With the shape work batched into a single instanced draw
-- and text already batched by the engine's font RenderBuffer, drawing straight
-- through every frame is both simpler and cheaper than maintaining the list.
--
-- Note that the expensive part was never the drawing: RefreshData() computes
-- graphMax, gameTime and visibleTeams on a 2 second timer from widget:Update,
-- and that is untouched.
local function BuildContentList()
	contentList = TexCache(contentList,
		panelRect.x1, panelRect.y1, panelRect.x2, panelRect.y2, function()
	DrawPanelChrome(panelRect.x1, panelRect.y1, panelRect.x2, panelRect.y2, ACCENT_PANEL)
	BakeTitle()
	BakeStatButtons()
	BakeLegend()
	BakeDelta()
	if enoughData then
		BakeGrid()
		BakeLines()
		BakeValueLabels()
	else
		BakeNoData()
	end
	end)
	contentDirty = false
end

--------------------------------------------------------------------------------
-- Hover tint + tooltip (immediate mode, on top of the baked list)
--------------------------------------------------------------------------------

local function DrawHoverAndTooltip(mx, my)
	local newHover = nil

	-- Close
	if InRect(mx, my, geom.closeRect) then
		glColor(HOVER_OVERLAY[1], HOVER_OVERLAY[2], HOVER_OVERLAY[3], HOVER_OVERLAY[4])
		RectRound(geom.closeRect.x1, geom.closeRect.y1, geom.closeRect.x2, geom.closeRect.y2, 4*uiScale)
		newHover = "close"
	end

	-- Stat buttons
	for i = 1, #geom.statBtns do
		local r = geom.statBtns[i]
		if InRect(mx, my, r) and i ~= selectedStat then
			glColor(HOVER_OVERLAY[1], HOVER_OVERLAY[2], HOVER_OVERLAY[3], HOVER_OVERLAY[4])
			RectRound(r.x1, r.y1, r.x2, r.y2, 4*uiScale)
			newHover = "stat"..i
		end
	end

	-- Legend rows (packed; every shown slot is interactive)
	for slot = 1, #visibleTeams do
		local r = geom.legendRows[slot]
		if not r then break end
		if InRect(mx, my, r) then
			glColor(HOVER_OVERLAY[1], HOVER_OVERLAY[2], HOVER_OVERLAY[3], HOVER_OVERLAY[4])
			RectRound(r.x1, r.y1, r.x2, r.y2, 4*uiScale)
			newHover = "team"..slot
		end
	end

	-- Delta
	if InRect(mx, my, geom.deltaRect) then
		glColor(HOVER_OVERLAY[1], HOVER_OVERLAY[2], HOVER_OVERLAY[3], HOVER_OVERLAY[4])
		RectRound(geom.deltaRect.x1, geom.deltaRect.y1, geom.deltaRect.x2, geom.deltaRect.y2, 4*uiScale)
		newHover = "delta"
	end

	-- Plot tooltip
	if enoughData then
		local p = geom.plot
		if mx >= p.x1 and mx <= p.x2 and my >= p.y1 and my <= p.y2 then
			-- crosshair
			glColor(1, 1, 1, 0.15)
			glRect(mx, p.y1, mx+1, p.y2)
			glRect(p.x1, my, p.x2, my+1)

			local t = (gameTime / math_max(1, p.x2-p.x1)) * (mx - p.x1)
			local s = (graphMax / math_max(1, p.y2-p.y1)) * (my - p.y1)
			local txt = TEXT_DIM.."Time "..TEXT_COLOR..formatTime(t, true)
					.. TEXT_DIM.."   Score "..TEXT_COLOR..numFormat(s)

			local boxW = font:GetTextWidth(txt) * 11*uiScale + 12*uiScale
			local boxH = 20*uiScale
			local bx1 = Clamp(mx + 10*uiScale, p.x1, p.x2 - boxW)
			local by2 = Clamp(my + 18*uiScale, p.y1 + boxH, p.y2)
			local bx2 = bx1 + boxW
			local by1 = by2 - boxH
			glColor(0, 0, 0, 0.82)
			RectRound(bx1, by1, bx2, by2, 3*uiScale)
			font:Begin()
			font:Print(txt, bx1 + 6*uiScale, by1 + boxH*0.5 - 5*uiScale, 11*uiScale, "lo")
			font:End()
		end
	end

	-- hover sound dedup
	if newHover ~= hoveredKey then
		if newHover then PlayHoverSound() end
		hoveredKey = newHover
	end
end

--------------------------------------------------------------------------------
-- Open / Close / Toggle  + WG hook
--------------------------------------------------------------------------------

local function EnsureTeams()
	if #team == 0 then getTeamInfo() end
end

local function Open()
	if isOpen then return end
	isOpen = true
	EnsureTeams()
	BuildGeometry()
	RefreshData()
	contentDirty = true
	refreshTimer = 0
	PlayClickSound()
end

local function Close()
	if not isOpen then return end
	isOpen = false
	PlayClickSound()
end

local function Toggle()
	if isOpen then Close() else Open() end
end

--------------------------------------------------------------------------------
-- Input
--------------------------------------------------------------------------------

function widget:KeyPress(key, mods, isRepeat)
	if isRepeat then return false end
	if isOpen and key == KEYSYMS.ESCAPE then
		Close()
		return true
	end
	return false
end

function widget:IsAbove(x, y)
	return isOpen and IsOnPanel(x, y)
end

function widget:MousePress(x, y, button)
	if not isOpen then return false end
	if not IsOnPanel(x, y) then return false end
	return true   -- consume so clicks don't leak to the world
end

function widget:MouseRelease(x, y, button)
	if not isOpen then return false end
	if button ~= 1 then return IsOnPanel(x, y) end
	if not IsOnPanel(x, y) then return false end

	-- Close
	if InRect(x, y, geom.closeRect) then
		PlayClickSound()
		Close()
		return true
	end

	-- Stat buttons
	for i = 1, #geom.statBtns do
		if InRect(x, y, geom.statBtns[i]) then
			if i ~= selectedStat then
				selectedStat = i
				RefreshData()
				contentDirty = true
				PlayClickSound()
			end
			return true
		end
	end

	-- Legend toggles: click a team to hide/show its line. Packed slot -> team.
	for slot = 1, #visibleTeams do
		local r = geom.legendRows[slot]
		if not r then break end
		if InRect(x, y, r) then
			local ti = visibleTeams[slot]
			team[ti].show = not team[ti].show
			RefreshData()   -- rescale graphMax over the still-shown teams
			contentDirty = true
			PlayClickSound()
			return true
		end
	end

	-- Delta toggle
	if InRect(x, y, geom.deltaRect) then
		isDelta = not isDelta
		RefreshData()
		contentDirty = true
		PlayClickSound()
		return true
	end

	return true
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

local gameOverHandled = false
local function HandleGameOver()
	if gameOverHandled then return end
	gameOverHandled = true
	-- Open FIRST so a helper error can never leave the panel shut.
	isOpen       = true
	contentDirty = true
	refreshTimer = 0
	-- Guarded: a throw in here must not propagate and disable the widget.
	pcall(function()
		getTeamInfo()   -- engine grants fullRead at game over; re-read teams
		BuildGeometry()
		RefreshData()
	end)
end

function widget:Update(dt)
	-- This engine does not deliver the GameOver callin to LuaUI, so poll for it.
	if not gameOverHandled and Spring.IsGameOver and Spring.IsGameOver() then
		HandleGameOver()
	end
	if not isOpen then return end
	refreshTimer = refreshTimer + dt
	if refreshTimer >= 2.0 then
		refreshTimer = 0
		RefreshData()
		contentDirty = true
	end
end

-- Receives RP samples from game_researchpoints_ledger (gadget). The gadget's
-- unsynced side has already gated which teams this client may receive, so we can
-- store whatever arrives. Refresh the view if it's open and RP is being shown.
function ResearchSampleEvent(teamID, index, value)
	local arr = rpHistory[teamID]
	if not arr then arr = {} ; rpHistory[teamID] = arr end
	arr[index] = value
	if isOpen and statName[selectedStat][1] == '__researchPoints' then
		contentDirty = true
	end
end

function widget:DrawScreen()
	if spIsGUIHidden() then return end
	if not isOpen then return end
	if not font then return end

	if contentDirty or not contentList then
		BuildContentList()
	end
	DrawCache(contentList, panelRect.x1, panelRect.y1)

	local mx, my = spGetMouseState()
	DrawHoverAndTooltip(mx, my)

	-- Hand the accumulated shape instances to the GPU. Without this the batch
	-- carries into the next frame and the shapes module will complain.
	Flush()
end

function widget:GameOver(winningAllyTeams)
	-- Kept in case a future engine build delivers this callin to LuaUI; the
	-- Update poll handles it today. gameOverHandled dedupes either way.
	HandleGameOver()
end

function widget:Initialize()
	Spring.SendCommands("endgraph 0")   -- suppress the engine's built-in graph
	vsx, vsy = spGetViewGeometry()
	fontfileScale = (0.5 + (vsx * vsy / 5700000))

	-- Resolve the shapes module now that every widget has been constructed.
	BindDrawing()
	ReloadFont()

	getTeamInfo()
	BuildGeometry()

	widgetHandler:RegisterGlobal('ResearchSampleEvent', ResearchSampleEvent)

	WG.StaticEndGraph = {
		Toggle = Toggle,
		Show   = Open,
		Hide   = Close,
	}
end

function widget:Shutdown()
	FreeCache(contentList)
	contentList = nil
	if font then
		local SG = WG.StaticGUI
		if SG and SG.DeleteFont then SG.DeleteFont(font) else gl.DeleteFont(font) end
		font = nil
	end
	widgetHandler:DeregisterGlobal('ResearchSampleEvent')
	WG.StaticEndGraph = nil
	Spring.SendCommands("endgraph 1")   -- restore engine graph for other widgets
end

function widget:ViewResize(nx, ny)
	vsx, vsy = nx, ny
	local newScale = (0.5 + (vsx * vsy / 5700000))
	if newScale ~= fontfileScale then
		fontfileScale = newScale
		ReloadFont()
	end
	BuildGeometry()
	contentDirty = true
end