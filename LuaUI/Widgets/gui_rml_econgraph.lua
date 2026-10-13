--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Economy graph of the RmlUi HUD: where is my metal or energy going?
--
--  Stacked per-unit expense (or income) over time, with the other side of the
--  ledger drawn as a line over it, and two bars showing the breakdown of this
--  very second. Open it from the game menu, with /econgraph, or through
--  WG.StaticEconGraph.
--
--  The window is RmlUi. The plot itself (up to 360 columns of up to 11 bands,
--  and the line) is drawn with gl: the engine draws gl under RmlUi, so the
--  window leaves a hole where the plot goes (see econgraph.rml) and
--  DrawScreen fills it. The gl drawing goes through WG.StaticGUI
--  (api_staticgui_shapes.lua) when that is running, which batches it and
--  keeps it in a texture between the once-a-second refreshes.
--
--  Replaces gui_static_econgraph.lua (kept in Widgets/disabled/). The
--  sampling and the building of the view are carried over unchanged.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name    = "Economy Graph",
		desc    = "Where is my metal/energy going? Stacked per-unit expense (or income) over time with the other side of the ledger drawn as a line, plus a live breakdown bar. Open from the game menu, WG.StaticEconGraph, or /econgraph. (RmlUi)",
		author  = "Scary le Poo",
		date    = "2026-10-13",
		license = "GNU GPL, v2 or later",
		layer   = -500,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- HOW THE NUMBERS ARE OBTAINED
--
-- Spring.GetUnitResources(unitID) returns metalMake, metalUse, energyMake,
-- energyUse. In Recoil, CUnit::UpdateResources() (run from SlowUpdate, every
-- UNIT_SLOWUPDATE_RATE = 15 frames) sets
--
--     resourcesUse = resourcesUseI + resourcesUseOld
--
-- i.e. the sum of the last two 15-frame windows: a true per-second figure.
-- resourcesUseI is fed by CUnit::UseResources / UseMetal / UseEnergy, which is
-- the path taken by
--   - construction (CUnit::AddBuildPower charges the BUILDER),
--   - weapon fire cost (CWeapon: owner->UseResources(weaponDef->cost)),
--   - unit_morph.lua (Spring.UseUnitResource),
--   - cloak, seismic, shields and any other unitdef upkeep.
-- So one loop over my own units gives an exact attribution of everything the
-- engine charged through a unit. The only spend that bypasses it is
-- Spring.UseTeamResource, which is charged to the team with no unit attached;
-- that shows up here as the difference between Spring.GetTeamResources expense
-- and the per-unit sum, and is drawn as its own "Unattributed" band so the
-- stack always adds up to the real team number.
--
-- Construction spend is charged to the builder but the question the player is
-- asking is "what am I spending it ON", so a builder's use is re-keyed to the
-- unitDef of whatever Spring.GetUnitIsBuilding says it is building. SF has no
-- build assist, so every target has exactly one builder and this is exact.
-- Morphs are re-keyed to the target def via the unit_morph MorphUpdate
-- broadcast when this widget can claim that global (another widget may own
-- it; then a morphing unit's spend simply stays on the unit itself).
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- config
--------------------------------------------------------------------------------

local DOCUMENT_PATH = "LuaUI/rml/econgraph.rml"

-- must match #econgraph in econgraph.rml
local PANEL_WIDTH  = 1180
local PANEL_HEIGHT = 700
-- sizes in econgraph.rml that the widget reckons with, in dp
local PLOT_HEIGHT  = 520 -- #plotrow
local BAR_WIDTH    = 898 -- inside of a .live bar
local END_LABEL_GAP = 13 -- least distance between the two labels right of the plot

local LAYOUT_ID = "econgraph" -- same as the old widget, so a saved position carries over

local GRID_DIVS     = 5
local LINE_WIDTH    = 2.5
local MAX_COLUMNS   = 360    -- samples are binned down to this many columns
local MAX_SAMPLES   = 3 * 3600   -- 3h at 1 Hz, then the oldest are dropped
local TOP_N         = 9      -- bands shown by name; the rest fold into "Everything else"

-- Selector definitions. Order = button order; the buttons themselves are in
-- econgraph.rml as res1.., mode1.., group1.., win1..
local RESOURCES = {
	{ key = "m", label = "Metal"  },
	{ key = "e", label = "Energy" },
}
local MODES = {
	{ key = "use",  label = "Expense", line = "Income"  },
	{ key = "make", label = "Income",  line = "Expense" },
}
local GROUPINGS = {
	{ key = "unit", label = "By unit" },
	{ key = "cat",  label = "By category" },
}
local WINDOWS = {
	{ secs = 120,  label = "2m"  },
	{ secs = 300,  label = "5m"  },
	{ secs = 600,  label = "10m" },
	{ secs = 0,    label = "All" },
}
local GROUP_DEFS = { res = RESOURCES, mode = MODES, group = GROUPINGS, win = WINDOWS }

-- Sentinel bucket keys (never collide with a unitDefID)
local KEY_OTHER  = "__other"     -- team-level spend the engine attaches to no unit
local KEY_REST   = "__rest"      -- fold of everything outside the top N
local MORPH_PREFIX = "morph:"    -- morph:<targetDefID>

-- Category palette (fixed, so a category keeps its colour across games)
local CATEGORIES = {
	{ key = "extract", label = "Extractors",    color = {0.25, 0.75, 0.95, 1} },
	{ key = "power",   label = "Power",         color = {0.95, 0.80, 0.25, 1} },
	{ key = "factory", label = "Factories",     color = {0.85, 0.45, 0.20, 1} },
	{ key = "builder", label = "Constructors",  color = {0.60, 0.85, 0.35, 1} },
	{ key = "army",    label = "Army units",    color = {0.90, 0.30, 0.35, 1} },
	{ key = "defense", label = "Defenses",      color = {0.65, 0.40, 0.90, 1} },
	{ key = "struct",  label = "Other buildings", color = {0.40, 0.70, 0.70, 1} },
	{ key = "upgrade", label = "Upgrades",      color = {0.95, 0.55, 0.85, 1} },
	{ key = "other",   label = "Unattributed",  color = {0.55, 0.55, 0.58, 1} },
}
local COLOR_OTHER = {0.55, 0.55, 0.58, 1}
local COLOR_REST  = {0.38, 0.38, 0.42, 1}

-- gl colors of the plot
local HOLE_BG    = {0.043, 0.055, 0.071, 0.92} -- the panel color, as in theme.rcss
local PLOT_BG    = {0.02, 0.03, 0.04, 0.55}
local GRID_COLOR = {1.0, 1.0, 1.0, 0.07}
local LINE_COLOR = {1.0, 1.0, 1.0, 0.95}       -- the "other side" overlay line

--------------------------------------------------------------------------------
-- speedups
--------------------------------------------------------------------------------

local spGetMouseState     = Spring.GetMouseState
local spPlaySoundFile     = Spring.PlaySoundFile
local spGetMyTeamID       = Spring.GetMyTeamID
local spGetTeamUnits      = Spring.GetTeamUnits
local spGetUnitResources  = Spring.GetUnitResources
local spGetUnitDefID      = Spring.GetUnitDefID
local spGetUnitIsBuilding = Spring.GetUnitIsBuilding
local spGetTeamResources  = Spring.GetTeamResources
local spGetGameSeconds    = Spring.GetGameSeconds
local spEcho              = Spring.Echo

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
local page          -- the hud view of the document ("view" is the data view below)

local isOpen  = false
local uiScale = 1.0 -- pixels per dp
local plot    = nil -- {x1, y1, x2, y2}: #plot on screen, y up; nil until laid out

-- Which selector is active in each group (index into the def tables above)
local sel = { res = 1, mode = 1, group = 1, win = 2 }

-- Hidden buckets, keyed per grouping so toggling in one view does not leak.
local hidden = { unit = {}, cat = {} }

-- Sampler ---------------------------------------------------------------------
-- samples[i] = { t = gameSeconds,
--                use  = { m = {key=v}, e = {key=v} },
--                make = { m = {key=v}, e = {key=v} },
--                tot  = { mUse, mMake, eUse, eMake } }
local samples    = {}
local sampleN    = 0
local morphing   = {}       -- [unitID] = "morph:<targetDefID>" from MorphUpdate
local ownsMorphGlobal = false

-- View ------------------------------------------------------------------------
-- Rebuilt by RefreshView(): the binned series for the current selectors.
local view = {
	buckets  = {},   -- ordered list: { key, label, color, cols = {v1..vn}, total, cur, pct }
	byKey    = {},   -- key -> bucket
	lineCols = {},   -- overlay line, binned
	stackCols = {},  -- top of the visible stack per column
	nCols    = 0,
	colSpan  = 1,    -- samples per column
	t0       = 0,    -- game time at the left edge
	t1       = 0,    -- game time at the right edge
	yMax     = 1,
	curTotal = 0,    -- current-second total of the stacked side
	curLine  = 0,    -- current-second total of the overlay side
	live     = {},   -- live bar segments for the stacked side, ordered
	liveLine = {},   -- live bar segments for the overlay side, ordered
	enough   = false,
}

local plotCache   = nil   -- the baked plot (TexCache)
local plotDirty   = true
local pageDirty   = true  -- the RmlUi side needs restating
local legendMarkup
local plotHover   = false -- the mouse is on #plot (told by RmlUi)
local hoverCol    = nil   -- column of the plot under the mouse
local hoverSeg    = nil   -- {bar = 1 | 2, index = } segment of a bar under the mouse
local tipText     = nil

--------------------------------------------------------------------------------
-- sound, formatting
--------------------------------------------------------------------------------

local function PlayHoverSound() spPlaySoundFile("hover",     1.0, "ui") end
local function PlayClickSound() spPlaySoundFile("leftclick", 1.0, "ui") end

local function numFormat(value)
	value = value or 0
	if value >= 1000000 then
		return string.format("%.1fM", value / 1000000)
	elseif value >= 10000 then
		return string.format("%.1fk", value / 1000)
	elseif value >= 100 then
		return string.format("%d", math_floor(value + 0.5))
	elseif value >= 10 then
		return string.format("%.1f", value)
	else
		return string.format("%.2f", value)
	end
end

local function formatTime(seconds)
	seconds = math_floor(seconds or 0)
	local minutes = math_floor(seconds/60)
	seconds = seconds % 60
	if seconds < 10 then seconds = '0' .. seconds end
	return minutes..':'..seconds
end

--------------------------------------------------------------------------------
-- Bucket identity: labels, colours, categories
--------------------------------------------------------------------------------

-- Deterministic, well-spread colour per unitDef. Golden-ratio hue stepping on
-- the def id keeps neighbouring ids visually distinct and stable across games.
local colorCache = {}
local function HSVtoRGB(h, s, v)
	local i = math_floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v*(1-s), v*(1-f*s), v*(1-(1-f)*s)
	i = i % 6
	if i == 0 then return v, t, p end
	if i == 1 then return q, v, p end
	if i == 2 then return p, v, t end
	if i == 3 then return p, q, v end
	if i == 4 then return t, p, v end
	return v, p, q
end

local function DefColor(udid)
	local c = colorCache[udid]
	if c then return c end
	local h = (udid * 0.618033988749895) % 1
	local r, g, b = HSVtoRGB(h, 0.62, 0.92)
	c = {r, g, b, 1}
	colorCache[udid] = c
	return c
end

local function DefName(udid)
	local ud = UnitDefs[udid]
	if not ud then return "Unit " .. tostring(udid) end
	return ud.translatedHumanName or ud.humanName or ud.name
end

local catByDef = {}
local function CategoryOf(udid)
	local c = catByDef[udid]
	if c then return c end
	local ud = UnitDefs[udid]
	if not ud then c = "other"
	elseif (ud.extractsMetal or 0) > 0 then c = "extract"
	elseif ud.isFactory then c = "factory"
	elseif ud.isBuilder and ud.canMove then c = "builder"
	elseif (ud.energyMake or 0) > 0 or ud.windGenerator and ud.windGenerator > 0
	    or ud.tidalGenerator and ud.tidalGenerator > 0 or (ud.customParams and ud.customParams.rp_income) then
		c = "power"
	elseif ud.isBuilding or ud.isImmobile then
		c = (ud.weapons and #ud.weapons > 0) and "defense" or "struct"
	else
		c = "army"
	end
	catByDef[udid] = c
	return c
end

local catDef = {}
for i = 1, #CATEGORIES do catDef[CATEGORIES[i].key] = CATEGORIES[i] end

-- Resolves a raw sample key to the bucket it belongs to under the current
-- grouping. Returns bucketKey, label, color.
local function Resolve(rawKey)
	local grouping = GROUPINGS[sel.group].key
	if rawKey == KEY_OTHER then
		return KEY_OTHER, "Unattributed", COLOR_OTHER
	end
	local isMorph = (type(rawKey) == "string")
	local udid = isMorph and tonumber(rawKey:sub(#MORPH_PREFIX + 1)) or rawKey
	if grouping == "cat" then
		local ck = isMorph and "upgrade" or CategoryOf(udid)
		local cd = catDef[ck] or catDef.other
		return "cat:" .. ck, cd.label, cd.color
	end
	if isMorph then
		return rawKey, "Upgrade to " .. DefName(udid), DefColor(udid)
	end
	return udid, DefName(udid), DefColor(udid)
end

--------------------------------------------------------------------------------
-- Sampling (1 Hz, own team)
--------------------------------------------------------------------------------

local function TakeSample()
	local teamID = spGetMyTeamID()
	local units  = spGetTeamUnits(teamID)
	if not units then return end

	local useM, useE, makeM, makeE = {}, {}, {}, {}
	local sumUM, sumUE, sumMM, sumME = 0, 0, 0, 0

	for i = 1, #units do
		local u = units[i]
		local mM, mU, eM, eU = spGetUnitResources(u)
		if mM then
			local udid = spGetUnitDefID(u)
			if udid then
				-- What is this unit spending ON?
				local useKey = udid
				local target = spGetUnitIsBuilding(u)
				if target then
					local tdid = spGetUnitDefID(target)
					if tdid then useKey = tdid end
				elseif morphing[u] then
					useKey = morphing[u]
				end
				if mU > 0 then useM[useKey] = (useM[useKey] or 0) + mU ; sumUM = sumUM + mU end
				if eU > 0 then useE[useKey] = (useE[useKey] or 0) + eU ; sumUE = sumUE + eU end
				-- Income is always the unit's own doing (mex, solar, reclaim by a builder)
				if mM > 0 then makeM[udid] = (makeM[udid] or 0) + mM ; sumMM = sumMM + mM end
				if eM > 0 then makeE[udid] = (makeE[udid] or 0) + eM ; sumME = sumME + eM end
			end
		end
	end

	-- Team totals are ground truth; whatever the per-unit walk did not see is
	-- team-level (Spring.UseTeamResource / AddTeamResource) and gets its own band.
	local _, _, _, incM, expM = spGetTeamResources(teamID, "metal")
	local _, _, _, incE, expE = spGetTeamResources(teamID, "energy")
	incM, expM, incE, expE = incM or 0, expM or 0, incE or 0, expE or 0

	-- Unit windows are staggered relative to the team window, so tiny negative
	-- residues are normal noise; only a real gap becomes a band.
	local r
	r = expM - sumUM ; if r > 0.5 then useM[KEY_OTHER]  = r end
	r = expE - sumUE ; if r > 0.5 then useE[KEY_OTHER]  = r end
	r = incM - sumMM ; if r > 0.5 then makeM[KEY_OTHER] = r end
	r = incE - sumME ; if r > 0.5 then makeE[KEY_OTHER] = r end

	sampleN = sampleN + 1
	samples[sampleN] = {
		t    = spGetGameSeconds(),
		use  = { m = useM,  e = useE  },
		make = { m = makeM, e = makeE },
		tot  = { mUse = expM, mMake = incM, eUse = expE, eMake = incE },
	}

	if sampleN > MAX_SAMPLES then
		-- Drop the oldest quarter in one go rather than shifting every second.
		local drop = math_floor(MAX_SAMPLES / 4)
		local keep = {}
		for i = drop + 1, sampleN do keep[#keep + 1] = samples[i] end
		samples = keep
		sampleN = #keep
	end
end

--------------------------------------------------------------------------------
-- View building: bin the window, rank buckets, fold the tail, scale the axis
--------------------------------------------------------------------------------

local function RefreshView()
	local resKey  = RESOURCES[sel.res].key
	local modeKey = MODES[sel.mode].key
	local lineKey = (modeKey == "use") and "make" or "use"
	local winSecs = WINDOWS[sel.win].secs
	local grouping = GROUPINGS[sel.group].key
	local hiddenSet = hidden[grouping]

	-- Window: last winSecs of samples (or everything)
	local first = 1
	if winSecs > 0 and sampleN > 0 then
		local tEnd = samples[sampleN].t
		first = sampleN
		while first > 1 and samples[first - 1].t >= tEnd - winSecs do first = first - 1 end
	end
	local n = sampleN - first + 1
	view.enough = (n >= 3)
	if not view.enough then
		view.buckets, view.byKey, view.live, view.liveLine = {}, {}, {}, {}
		view.nCols = 0
		return
	end

	local colSpan = math_max(1, math.ceil(n / MAX_COLUMNS))
	local nCols   = math.ceil(n / colSpan)
	view.colSpan, view.nCols = colSpan, nCols
	view.t0, view.t1 = samples[first].t, samples[sampleN].t

	-- Aggregate stacked side per bucket per column, and the line side per column
	local byKey, buckets = {}, {}
	local lineCols = {}
	for c = 1, nCols do lineCols[c] = 0 end

	local totField = ((resKey == "m") and "m" or "e") .. ((lineKey == "use") and "Use" or "Make")

	for i = first, sampleN do
		local s   = samples[i]
		local col = math_floor((i - first) / colSpan) + 1
		local src = s[modeKey][resKey]
		for rawKey, v in pairs(src) do
			local bk, label, color = Resolve(rawKey)
			local b = byKey[bk]
			if not b then
				b = { key = bk, label = label, color = color, cols = {}, total = 0, cur = 0 }
				byKey[bk] = b
				buckets[#buckets + 1] = b
			end
			b.cols[col] = (b.cols[col] or 0) + v
			b.total = b.total + v
			if i == sampleN then b.cur = b.cur + v end
		end
		lineCols[col] = lineCols[col] + s.tot[totField]
	end

	-- Per-column values are sums over colSpan samples; normalise to per-second
	-- so the axis reads as a rate. The last column may be partial.
	local function ColCount(col)
		local a = first + (col - 1) * colSpan
		local b = math_min(sampleN, a + colSpan - 1)
		return b - a + 1
	end
	for c = 1, nCols do lineCols[c] = lineCols[c] / ColCount(c) end
	for bi = 1, #buckets do
		local cols = buckets[bi].cols
		for c = 1, nCols do
			if cols[c] then cols[c] = cols[c] / ColCount(c) else cols[c] = 0 end
		end
	end

	-- Rank by total over the window (stable stacking; the current second alone
	-- would reshuffle the bands every refresh). Sentinels always go last.
	table.sort(buckets, function(a, b)
		local sa, sb = (a.key == KEY_OTHER), (b.key == KEY_OTHER)
		if sa ~= sb then return sb end
		return a.total > b.total
	end)

	-- Fold the tail beyond TOP_N into one band
	if #buckets > TOP_N + 1 then
		local rest = { key = KEY_REST, label = "Everything else", color = COLOR_REST, cols = {}, total = 0, cur = 0, folded = 0 }
		for c = 1, nCols do rest.cols[c] = 0 end
		local kept = {}
		for bi = 1, #buckets do
			local b = buckets[bi]
			if bi <= TOP_N or b.key == KEY_OTHER then
				kept[#kept + 1] = b
			else
				for c = 1, nCols do rest.cols[c] = rest.cols[c] + b.cols[c] end
				rest.total = rest.total + b.total
				rest.cur   = rest.cur + b.cur
				rest.folded = rest.folded + 1
			end
		end
		-- Keep Unattributed as the very last row
		local last = kept[#kept]
		if last and last.key == KEY_OTHER then
			kept[#kept] = rest ; kept[#kept + 1] = last
		else
			kept[#kept + 1] = rest
		end
		buckets = kept
		byKey = {}
		for bi = 1, #buckets do byKey[buckets[bi].key] = buckets[bi] end
	end

	-- Visible stack top per column and axis maximum (line included so it never
	-- leaves the plot)
	local stackCols = {}
	local yMax = 0
	for c = 1, nCols do
		local top = 0
		for bi = 1, #buckets do
			local b = buckets[bi]
			if not hiddenSet[b.key] then top = top + b.cols[c] end
		end
		stackCols[c] = top
		if top > yMax then yMax = top end
		if lineCols[c] > yMax then yMax = lineCols[c] end
	end
	if yMax <= 0 then yMax = 1 end
	view.yMax = yMax * 1.06

	-- Current-second totals and live bar segments (hidden buckets still count
	-- in the bar: the bar is "what is happening", the plot is "what I chose to
	-- look at")
	local last = samples[sampleN]
	view.curTotal = 0
	for bi = 1, #buckets do view.curTotal = view.curTotal + buckets[bi].cur end
	view.live = {}
	for bi = 1, #buckets do
		local b = buckets[bi]
		b.pct = (view.curTotal > 0) and (b.cur / view.curTotal) or 0
		if b.cur > 0 then view.live[#view.live + 1] = b end
	end
	table.sort(view.live, function(a, b) return a.cur > b.cur end)

	-- The overlay side's live breakdown, built ad hoc (it has no bucket list)
	view.curLine = last.tot[totField]
	local liveLine, lbk = {}, {}
	for rawKey, v in pairs(last[lineKey][resKey]) do
		local bk, label, color = Resolve(rawKey)
		local b = lbk[bk]
		if not b then
			b = { key = bk, label = label, color = color, cur = 0 }
			lbk[bk] = b ; liveLine[#liveLine + 1] = b
		end
		b.cur = b.cur + v
	end
	table.sort(liveLine, function(a, b) return a.cur > b.cur end)
	for i = 1, #liveLine do
		liveLine[i].pct = (view.curLine > 0) and (liveLine[i].cur / view.curLine) or 0
	end
	view.liveLine = liveLine

	view.buckets, view.byKey, view.lineCols, view.stackCols = buckets, byKey, lineCols, stackCols
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

local function BakeGrid()
	local p = plot
	glColor(HOLE_BG[1], HOLE_BG[2], HOLE_BG[3], HOLE_BG[4])
	glRect(p.x1, p.y1, p.x2, p.y2)
	glColor(PLOT_BG[1], PLOT_BG[2], PLOT_BG[3], PLOT_BG[4])
	glRect(p.x1, p.y1, p.x2, p.y2)
	if not view.enough then return end
	glColor(GRID_COLOR[1], GRID_COLOR[2], GRID_COLOR[3], GRID_COLOR[4])
	for i = 0, GRID_DIVS do
		local fy = p.y1 + (p.y2-p.y1) * (i/GRID_DIVS)
		glRect(p.x1, math_min(fy, p.y2 - 1), p.x2, math_min(fy, p.y2 - 1) + 1)
		local fx = p.x1 + (p.x2-p.x1) * (i/GRID_DIVS)
		glRect(math_min(fx, p.x2 - 1), p.y1, math_min(fx, p.x2 - 1) + 1, p.y2)
	end
end

-- Stacked columns: one rect per (column, band). With MAX_COLUMNS = 360 and at
-- most TOP_N + 2 bands this is well under 4k instances, baked once per refresh.
local function BakeStack()
	local p = plot
	local hiddenSet = hidden[GROUPINGS[sel.group].key]
	local n = view.nCols
	local colW = (p.x2 - p.x1) / n
	local scaleY = (p.y2 - p.y1) / view.yMax
	local buckets = view.buckets
	-- Draw largest first so it sits at the bottom of the stack
	for c = 1, n do
		local cx1 = p.x1 + (c-1) * colW
		local cx2 = math_min(cx1 + colW + 0.5, p.x2)   -- slight overlap hides seams between columns
		local base = p.y1
		for bi = 1, #buckets do
			local b = buckets[bi]
			if not hiddenSet[b.key] then
				local v = b.cols[c]
				if v > 0 then
					local h = v * scaleY
					glColor(b.color[1], b.color[2], b.color[3], 0.85)
					glRect(cx1, base, cx2, base + h)
					base = base + h
				end
			end
		end
	end
end

local linePoints = {}
local function BakeLine()
	local p = plot
	local n = view.nCols
	if n < 2 then return end
	local colW = (p.x2 - p.x1) / n
	local scaleY = (p.y2 - p.y1) / view.yMax
	local k = 0
	for c = 1, n do
		linePoints[k+1] = p.x1 + (c-0.5) * colW
		linePoints[k+2] = p.y1 + view.lineCols[c] * scaleY
		k = k + 2
	end
	for i = #linePoints, k + 1, -1 do linePoints[i] = nil end
	-- Dark halo under the bright line so it reads over any band colour
	LineStrip(linePoints, LINE_WIDTH*uiScale + 2*uiScale, {0, 0, 0, 0.55})
	LineStrip(linePoints, LINE_WIDTH*uiScale, LINE_COLOR)
end

local function BuildPlotCache()
	plotCache = TexCache(plotCache, plot.x1, plot.y1, plot.x2, plot.y2, function()
		BakeGrid()
		if view.enough then
			BakeStack()
			BakeLine()
		end
	end)
	plotDirty = false
end

--------------------------------------------------------------------------------
-- the window (RmlUi)
--------------------------------------------------------------------------------

local function Hex(c)
	return hud.Rgb(c[1], c[2], c[3])
end

local function Percent(fraction)
	return math_floor(fraction * 100 + 0.5)
end

local function LegendRML()
	local hiddenSet = hidden[GROUPINGS[sel.group].key]
	local parts = {}
	for slot = 1, math_min(#view.buckets, TOP_N + 2) do
		local b = view.buckets[slot]
		local name = b.label
		if b.folded then name = name .. " (" .. b.folded .. ")" end
		local c = b.color
		parts[slot] = string.format(
			'<div id="l%d" class="lrow%s" data-l="%d"><div class="sw" style="background-color: %s;"/>'
			.. '<div class="lname" style="color: %s;">%s</div><div id="l%d-v" class="lval"/><div id="l%d-p" class="lpct"/></div>',
			slot, hiddenSet[b.key] and " off" or "", slot, Hex(c), hud.ReadableColor(c[1], c[2], c[3]), hud.Escape(name), slot, slot)
	end
	return table.concat(parts)
end

-- One 100% bar: segments left to right, largest first, named when the name
-- fits (reckoned from the length of the text: RmlUi does not say how wide a
-- text is before it is laid out).
local function BarRML(segs, total)
	if total <= 0 or #segs == 0 then
		return '<div class="nothing">nothing</div>'
	end
	local parts = {}
	for i = 1, #segs do
		local s = segs[i]
		local share = s.cur / total
		local widthDp = BAR_WIDTH * share
		if widthDp >= 1 then
			local pct = Percent(s.pct)
			local text = s.label .. "  " .. pct .. "%"
			if #text * 6.2 + 10 > widthDp then
				text = (widthDp > 26) and (pct .. "%") or ""
			end
			parts[#parts + 1] = string.format('<div class="seg" data-s="%d" style="width: %.2f%%; background-color: %s;">%s</div>',
				i, share * 100, Hex(s.color), hud.Escape(text))
		end
	end
	return table.concat(parts)
end

local function CaptionRML(label, modeKey, total)
	return string.format('<span class="%s">%s</span>  now  <span class="n">%s</span> /s', modeKey, label, numFormat(total))
end

-- the lines of the box at the mouse
local function TipRML()
	if hoverSeg then
		local segs = (hoverSeg.bar == 1) and view.live or view.liveLine
		local s = segs[hoverSeg.index]
		if not s then return nil end
		return string.format('<span style="color: %s;">%s</span>  <span class="n">%s</span><span class="d"> /s   %d%%</span>',
			hud.ReadableColor(s.color[1], s.color[2], s.color[3]), hud.Escape(s.label), numFormat(s.cur), Percent(s.pct))
	end
	local col = hoverCol
	if not col or not view.enough or col > view.nCols then return nil end
	local hiddenSet = hidden[GROUPINGS[sel.group].key]
	local n = view.nCols
	local t = view.t0 + (view.t1 - view.t0) * ((col-0.5) / n)
	local lines = {}
	lines[1] = string.format('<div><span class="d">Time </span><span class="n">%s</span><span class="d">   %s </span><span class="n">%s</span><span class="d">   %s </span><span class="n">%s</span></div>',
		formatTime(t), MODES[sel.mode].line, numFormat(view.lineCols[col]), MODES[sel.mode].label, numFormat(view.stackCols[col]))
	-- bands, top of the stack first, so the box reads like the plot
	local total = view.stackCols[col]
	for bi = #view.buckets, 1, -1 do
		local b = view.buckets[bi]
		if not hiddenSet[b.key] and b.cols[col] > 0 then
			local pct = (total > 0) and Percent(b.cols[col] / total) or 0
			lines[#lines+1] = string.format('<div><span style="color: %s;">%s</span>  <span class="n">%s</span><span class="d">  %d%%</span></div>',
				hud.ReadableColor(b.color[1], b.color[2], b.color[3]), hud.Escape(b.label), numFormat(b.cols[col]), pct)
		end
	end
	return table.concat(lines)
end

-- Puts the box next to the mouse: right of and below it, or left of and above
-- it in the right and lower parts of the window, so it never leaves the window.
local function PlaceTip()
	local window = page.Element("econgraph")
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
	page.SetClass("econgraph", "hidden", not isOpen)
	if not isOpen then
		return
	end
	pageDirty = false
	local res, mode = RESOURCES[sel.res], MODES[sel.mode]
	local other = MODES[(sel.mode == 1) and 2 or 1]

	page.SetText("title", res.label .. " " .. mode.label)
	page.SetText("subtitle", "by " .. ((GROUPINGS[sel.group].key == "unit") and "unit" or "category") .. "  |  " .. mode.line .. " drawn as line")
	page.SetText("window", view.enough and ("Window  " .. formatTime(view.t0) .. " - " .. formatTime(view.t1)) or "")
	for gname, defs in pairs(GROUP_DEFS) do
		for i = 1, #defs do
			page.SetClass(gname .. i, "active", sel[gname] == i)
		end
	end

	page.SetClass("nodata", "hidden", view.enough)
	page.SetClass("now", "hidden", not view.enough)
	page.SetClass("legend", "hidden", not view.enough)
	page.SetClass("end-stack", "hidden", not view.enough or view.nCols < 2)
	page.SetClass("end-line", "hidden", not view.enough or view.nCols < 2)
	for i = 0, GRID_DIVS do
		page.SetText("ax" .. i, view.enough and numFormat(view.yMax * (i/GRID_DIVS)) or "")
		page.SetText("tm" .. i, view.enough and formatTime(view.t0 + (view.t1 - view.t0) * (i/GRID_DIVS)) or "")
	end

	page.SetText("cap1", CaptionRML(res.label .. " " .. mode.label, mode.key, view.enough and view.curTotal or 0))
	page.SetText("cap2", CaptionRML(res.label .. " " .. other.label, other.key, view.enough and view.curLine or 0))
	page.SetText("bar1", BarRML(view.enough and view.live or {}, view.curTotal))
	page.SetText("bar2", BarRML(view.enough and view.liveLine or {}, view.curLine))
	if not view.enough then
		RefreshTip()
		return
	end

	-- legend: the rows are rebuilt only when the bands change, their figures restated
	page.SetText("now-value", numFormat(view.curTotal))
	local markup = LegendRML()
	if markup ~= legendMarkup then
		legendMarkup = markup
		page.Element("legend").inner_rml = markup
		page.Forget() -- the new rows start empty; everything else is simply restated next time
	end
	for slot = 1, math_min(#view.buckets, TOP_N + 2) do
		local b = view.buckets[slot]
		page.SetText("l" .. slot .. "-v", numFormat(b.cur))
		page.SetText("l" .. slot .. "-p", Percent(b.pct) .. "%")
	end

	-- the two figures right of the plot: top of the stack and the line, kept apart
	if view.nCols >= 2 then
		local n = view.nCols
		local a = { id = "end-stack", y = view.stackCols[n] / view.yMax, text = numFormat(view.stackCols[n]) }
		local b = { id = "end-line",  y = view.lineCols[n] / view.yMax,  text = numFormat(view.lineCols[n]) }
		if b.y < a.y then a, b = b, a end
		local minGap = END_LABEL_GAP / PLOT_HEIGHT
		if b.y < a.y + minGap then b.y = a.y + minGap end
		for _, l in ipairs({a, b}) do
			page.SetText(l.id, l.text)
			page.SetStyle(l.id, "bottom", string.format("%.1f%%", Clamp(l.y, 0.02, 0.98) * 100))
		end
		page.SetClass("end-stack", "use", mode.key == "use")
		page.SetClass("end-stack", "make", mode.key == "make")
	end

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
	hud.PlacePanel(page.Element("econgraph"), LAYOUT_ID, PANEL_WIDTH, PANEL_HEIGHT, DefaultOrigin)
	plot = nil -- read again once RmlUi has laid the window out
	plotDirty = true
end

local function Changed()
	RefreshView()
	plotDirty = true
	Refresh()
end

local function Open()
	if isOpen or not document then return end
	isOpen = true
	hoverCol, hoverSeg, plot = nil, nil, nil
	pcall(function() document:PullToFront() end)
	PlayClickSound()
	Changed()
end

local function Close()
	if not isOpen then return end
	isOpen = false
	hoverCol, hoverSeg = nil, nil
	PlayClickSound()
	Refresh()
end

local function Toggle()
	if isOpen then Close() else Open() end
end

--------------------------------------------------------------------------------
-- widget api
--------------------------------------------------------------------------------

-- unit_morph.lua (unsynced) calls this every frame with every visible morphing
-- unit when a widget owns the MorphUpdate global. Keyed by unitID, value is
-- the bucket key for the morph target.
local function MorphUpdate(morphTable)
	local m = {}
	for unitID, data in pairs(morphTable) do
		local ud = data.into and UnitDefNames[data.into]
		if ud then m[unitID] = MORPH_PREFIX .. ud.id end
	end
	morphing = m
end

function widget:Initialize()
	local helpers = include("rml/hud.lua")
	local result, reason = helpers.LoadDocument(DOCUMENT_PATH, widget)
	if not result then
		spEcho("[Economy Graph] " .. tostring(reason))
		widgetHandler:RemoveWidget(self)
		return
	end
	hud = helpers
	document = result
	BindDrawing()

	page = hud.NewView(document)
	page.Assume("econgraph", "hidden", true) -- set in the markup
	page.Assume("tip", "hidden", true)

	hud.OnClick(page, "close", Close)
	for gname, defs in pairs(GROUP_DEFS) do
		for i = 1, #defs do
			hud.OnClick(page, gname .. i, function()
				if sel[gname] ~= i then
					sel[gname] = i
					PlayClickSound()
					Changed()
				end
			end)
		end
	end
	-- a click on a legend row hides or shows its band in the plot
	page.Element("legend"):AddEventListener("mousedown", function(event)
		local slot = hud.EventAttribute(event, "data-l")
		local b = slot and view.enough and view.buckets[slot]
		if b and event.parameters and event.parameters.button == 0 then
			local hiddenSet = hidden[GROUPINGS[sel.group].key]
			hiddenSet[b.key] = (not hiddenSet[b.key]) or nil
			PlayClickSound()
			Changed()
		end
	end)
	-- what the mouse is on: the plot, or a segment of one of the bars
	local plotElement = page.Element("plot")
	plotElement:AddEventListener("mouseover", function() plotHover = true end)
	plotElement:AddEventListener("mouseout", function() plotHover = false end)
	for bar = 1, 2 do
		local element = page.Element("bar" .. bar)
		element:AddEventListener("mouseover", function(event)
			local index = hud.EventAttribute(event, "data-s")
			hoverSeg = index and { bar = bar, index = index } or nil
			RefreshTip()
		end)
		element:AddEventListener("mouseout", function()
			hoverSeg = nil
			RefreshTip()
		end)
	end

	-- Claim the morph broadcast if nobody else has. RegisterGlobal returns
	-- false when the name is taken; then morphs stay attributed to the unit.
	ownsMorphGlobal = widgetHandler:RegisterGlobal('MorphUpdate', MorphUpdate) and true or false
	if not ownsMorphGlobal then
		spEcho("[EconGraph] MorphUpdate global already owned; upgrade spend will show on the upgrading unit")
	end

	WG.StaticEconGraph = {
		Toggle = Toggle,
		Show   = Open,
		Hide   = Close,
		IsOpen = function() return isOpen end,
	}

	hud.RegisterPanel(LAYOUT_ID, "Economy Graph", Place, function() return isOpen end)
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
	if ownsMorphGlobal then widgetHandler:DeregisterGlobal('MorphUpdate') end
	WG.StaticEconGraph = nil
	if document then
		document:Close()
		document = nil
	end
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

function widget:TextCommand(command)
	if command == "econgraph" then
		Toggle()
		return true
	end
	return false
end

function widget:GameFrame(n)
	if n % 30 ~= 0 then return end
	TakeSample()
	if isOpen then
		RefreshView()
		plotDirty = true
		pageDirty = true
	end
end

local guiHidden = false

function widget:Update()
	if not document then
		return
	end
	guiHidden = hud.FollowGuiHidden(document)
	if guiHidden or not isOpen then
		return
	end
	if pageDirty then
		Refresh()
	end

	-- the column of the plot under the mouse
	local col = nil
	if plotHover and plot and view.enough then
		local mx, my = spGetMouseState()
		if mx >= plot.x1 and mx <= plot.x2 and my >= plot.y1 and my <= plot.y2 then
			local n = view.nCols
			col = Clamp(math_floor((mx - plot.x1) / (plot.x2 - plot.x1) * n) + 1, 1, n)
		end
	end
	if col ~= hoverCol then
		hoverCol = col
		RefreshTip()
	elseif col or hoverSeg then
		PlaceTip() -- the box follows the mouse
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

	-- the column under the mouse, and a line across at the mouse's height
	if hoverCol and view.enough and hoverCol <= view.nCols then
		local p = plot
		local colW = (p.x2 - p.x1) / view.nCols
		local _, my = spGetMouseState()
		glColor(1, 1, 1, 0.10)
		glRect(p.x1 + (hoverCol-1)*colW, p.y1, p.x1 + hoverCol*colW, p.y2)
		glColor(1, 1, 1, 0.15)
		glRect(p.x1, my, p.x2, my+1)
	end
	glColor(1, 1, 1, 1)
	Flush()
end
