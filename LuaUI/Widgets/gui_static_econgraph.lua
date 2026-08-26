function widget:GetInfo()
	return {
		name      = "Static Economy Graph",
		desc      = "Where is my metal/energy going? Stacked per-unit expense (or income) over time with the other side of the ledger drawn as a line, plus a live breakdown bar. Toggle via the Static Menu, WG.StaticEconGraph, or /econgraph.",
		author    = "Scary le Poo",
		date      = "2026-08-24",
		license   = "GNU GPL, v2 or later",
		layer     = 1003,
		enabled   = true,
	}
end

include("keysym.h.lua")

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
-- Config
--------------------------------------------------------------------------------

local bgcorner  = "LuaUI/Images/bgcorner.png"
local accentImg = ":n:LuaUI/Images/staticgui_accent.png"

local BASE_RESOLUTION     = 1080
local PANEL_WIDTH         = 1180
local PANEL_HEIGHT        = 700
local OUTER_CORNER        = 10
local INNER_CORNER        = 8.5
local INNER_INSET         = 2.25
local PANEL_ACCENT_HEIGHT = 5

local INNER_PAD     = 12
local TITLE_BAR_H   = 30
local SIDEBAR_W     = 230
local VALUE_STRIP_W = 56
local TIME_STRIP_H  = 20
local AXIS_STRIP_W  = 50
local BTN_H         = 24
local BTN_GAP       = 4
local SECTION_LBL_H = 14
local LEGEND_ROW_H  = 20
local SECTION_GAP   = 8
local BAR_BLOCK_H   = 88     -- the two live breakdown bars + their labels
local BAR_H         = 22

local GRID_DIVS     = 5
local LINE_WIDTH    = 2.5
local MAX_COLUMNS   = 360    -- samples are binned down to this many columns
local MAX_SAMPLES   = 3 * 3600   -- 3h at 1 Hz, then the oldest are dropped
local TOP_N         = 9      -- bands shown by name; the rest fold into "Everything else"

-- Selector definitions. Order = button order.
local RESOURCES = {
	{ key = "m", label = "Metal",  accent = {0.20, 0.75, 0.95, 1} },
	{ key = "e", label = "Energy", accent = {0.95, 0.75, 0.20, 1} },
}
local MODES = {
	{ key = "use",  label = "Expense", line = "Income",  accent = {0.90, 0.35, 0.35, 1} },
	{ key = "make", label = "Income",  line = "Expense", accent = {0.35, 0.85, 0.45, 1} },
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

-- Colors ----------------------------------------------------------------------
local PANEL_OPACITY       = 1.0
local BORDER_COLOR        = {0, 0, 0, 0.90}
local BORDER_COLOR_GUI    = {0, 0, 0, 0.90}
local PANEL_BG_COLOR      = {0.07, 0.07, 0.08, 0.92}
local PANEL_BG_COLOR_GUI  = {0.07, 0.07, 0.08, 0.92}
local SECTION_BG          = {0.12, 0.12, 0.13, 0.92}
local CATEGORY_BG         = {0.20, 0.20, 0.21, 0.60}
do
	local function ApplyOpacity(c) c[4] = math.min(1, c[4] * PANEL_OPACITY) end
	ApplyOpacity(BORDER_COLOR)     ; ApplyOpacity(BORDER_COLOR_GUI)
	ApplyOpacity(PANEL_BG_COLOR)   ; ApplyOpacity(PANEL_BG_COLOR_GUI)
	ApplyOpacity(SECTION_BG)       ; ApplyOpacity(CATEGORY_BG)
end
local PLOT_BG             = {0.02, 0.02, 0.03, 0.55}
local GRID_COLOR          = {1.0, 1.0, 1.0, 0.07}
local HOVER_OVERLAY       = {0.90, 0.90, 0.90, 0.09}
local SELECTED_OVERLAY    = {0.18, 0.52, 0.98, 0.18}
local LINE_COLOR          = {1.0, 1.0, 1.0, 0.95}   -- the "other side" overlay line

local ACCENT_PANEL  = {0.18, 0.52, 0.98, 1}
local ACCENT_CLOSE  = {0.90, 0.22, 0.22, 1}

local TEXT_COLOR    = "\255\244\244\244"
local TEXT_DIM      = "\255\160\162\168"

--------------------------------------------------------------------------------
-- Speedups
--------------------------------------------------------------------------------

local rawColor     = gl.Color
local rawRect      = gl.Rect
local rawTexture   = gl.Texture
local rawTexRect   = gl.TexRect
local rawScissor   = gl.Scissor
local rawLineWidth = gl.LineWidth
local rawBeginEnd  = gl.BeginEnd
local rawVertex    = gl.Vertex
local GL_LINE_STRIP = GL.LINE_STRIP

local spGetViewGeometry   = Spring.GetViewGeometry
local spGetMouseState     = Spring.GetMouseState
local spPlaySoundFile     = Spring.PlaySoundFile
local spGetMyTeamID       = Spring.GetMyTeamID
local spGetTeamUnits      = Spring.GetTeamUnits
local spGetUnitResources  = Spring.GetUnitResources
local spGetUnitDefID      = Spring.GetUnitDefID
local spGetUnitIsBuilding = Spring.GetUnitIsBuilding
local spGetTeamResources  = Spring.GetTeamResources
local spGetGameSeconds    = Spring.GetGameSeconds
local spIsGUIHidden       = Spring.IsGUIHidden
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
-- Drawing shim (identical contract to gui_static_endgraph.lua)
--------------------------------------------------------------------------------

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
		TexCache  = SG.TexCache
		DrawCache = SG.DrawCache
		FreeCache = SG.FreeCache
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
		TexCache  = function(cache, _, _, _, _, fn)
			if cache then gl.DeleteList(cache) end
			return gl.CreateList(fn)
		end
		DrawCache = function(cache) if cache then gl.CallList(cache) end end
		FreeCache = function(cache) if cache then gl.DeleteList(cache) end end
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

local function ReloadFont()
	local SG = WG.StaticGUI
	if font then
		if SG and SG.DeleteFont then SG.DeleteFont(font) else gl.DeleteFont(font) end
		font = nil
	end
	local f = gl.LoadFont(fontfile, 23*fontfileScale, 5*fontfileScale, 1.8)
	if f and SG and SG.WrapFont then f = SG.WrapFont(f) end
	font = f
end

--------------------------------------------------------------------------------
-- State
--
-- Consolidated into tables: the sampler, the view and the geometry each own a
-- lot of fields, and Lua 5.1 caps a chunk at 200 locals.
--------------------------------------------------------------------------------

local isOpen      = false
local panelRect   = {x1=0, y1=0, x2=0, y2=0}
local geom        = {}

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

local contentList  = nil
local contentDirty = true
local hoveredKey   = nil

--------------------------------------------------------------------------------
-- Sound / formatting
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

local function ColorEscape(c)
	return "\255" .. string.char(
		math_max(1, math_min(255, math_floor((c[1] or 1)*255))),
		math_max(1, math_min(255, math_floor((c[2] or 1)*255))),
		math_max(1, math_min(255, math_floor((c[3] or 1)*255)))
	)
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
		return rawKey, "Upgrade \226\134\146 " .. DefName(udid), DefColor(udid)
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
-- Geometry
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Layout (api_staticgui_layout.lua). The layout module owns this panel's origin
-- once the user has dragged it in tweak mode (Ctrl+F11); until then, and when
-- the module is absent, the default computed below is used unchanged.
--------------------------------------------------------------------------------

local LAYOUT_ID = "econgraph"

local function LayoutPlace(x1, y1, w, h)
	local L = WG.StaticLayout
	if L then return L.Place(LAYOUT_ID, x1, y1, w, h) end
	return x1, y1
end

local function BuildGeometry()
	uiScale = vsy / BASE_RESOLUTION

	local pw  = PANEL_WIDTH  * uiScale
	local ph  = PANEL_HEIGHT * uiScale
	local pad = INNER_PAD    * uiScale
	local acc = PANEL_ACCENT_HEIGHT * uiScale
	local gap = SECTION_GAP  * uiScale

	local x1 = math_floor(vsx * 0.5 - pw * 0.5)
	local y1 = math_floor(vsy * 0.5 - ph * 0.5)
	x1, y1 = LayoutPlace(x1, y1, math_floor(pw), math_floor(ph))
	local x2 = x1 + math_floor(pw)
	local y2 = y1 + math_floor(ph)
	panelRect = {x1=x1, y1=y1, x2=x2, y2=y2}

	local cx1, cx2 = x1 + pad, x2 - pad
	local cy1, cy2 = y1 + pad, y2 - pad - acc

	local titleH  = TITLE_BAR_H * uiScale
	local titleY2 = cy2
	local titleY1 = titleY2 - titleH
	local closeSz = titleH
	local closeRect = {x1=cx2-closeSz, y1=titleY1, x2=cx2, y2=titleY2}

	local bodyY2 = titleY1 - gap
	local bodyY1 = cy1
	local sbX1, sbX2 = cx1, cx1 + SIDEBAR_W * uiScale

	-- Sidebar: four selector groups stacked from the top, legend below
	local btnH, btnGap, lblH = BTN_H*uiScale, BTN_GAP*uiScale, SECTION_LBL_H*uiScale
	local cursor = bodyY2

	local function Row(defs, splitCount)
		-- Section label then a row of splitCount equal buttons (wraps if more)
		cursor = cursor - lblH
		local labelY = cursor
		local rects = {}
		local perRow = splitCount
		local bw = (sbX2 - sbX1 - btnGap*(perRow-1)) / perRow
		for i = 1, #defs do
			local r = (i-1) % perRow
			if r == 0 then cursor = cursor - btnH end
			local bx1 = sbX1 + r*(bw + btnGap)
			rects[i] = {x1=bx1, y1=cursor, x2=bx1+bw, y2=cursor+btnH}
			if i < #defs and r == perRow-1 then cursor = cursor - btnGap end
		end
		cursor = cursor - gap
		return { labelY = labelY, rects = rects }
	end

	local resGrp   = Row(RESOURCES, 2)
	local modeGrp  = Row(MODES, 2)
	local groupGrp = Row(GROUPINGS, 2)
	local winGrp   = Row(WINDOWS, 4)

	-- "NOW <total>/s" caption sits above the legend rows
	cursor = cursor - lblH
	local legendLabelY = cursor
	local legendTop = cursor - 2*uiScale
	local legendBot = bodyY1
	local legendH   = LEGEND_ROW_H * uiScale
	local legendRows = {}
	local ly2 = legendTop
	for i = 1, TOP_N + 2 do
		local ry1 = ly2 - legendH
		if ry1 < legendBot then break end
		legendRows[i] = {x1=sbX1, y1=ry1, x2=sbX2, y2=ly2}
		ly2 = ry1
	end

	-- Right side: plot on top, live bars block at the bottom
	local rx1, rx2 = sbX2 + gap, cx2
	local barBlockH = BAR_BLOCK_H * uiScale
	local barsY1, barsY2 = bodyY1, bodyY1 + barBlockH
	local plotOuterY1 = barsY2 + gap
	local plotOuterY2 = bodyY2

	local plotX1 = rx1 + AXIS_STRIP_W  * uiScale
	local plotX2 = rx2 - VALUE_STRIP_W * uiScale
	local plotY1 = plotOuterY1 + TIME_STRIP_H * uiScale
	local plotY2 = plotOuterY2

	-- Two bars: stacked side (top) and overlay side (bottom), each with a label line
	local barH  = BAR_H * uiScale
	local lineH = 13 * uiScale
	local bar1 = {x1=rx1, y1=barsY2 - lineH - barH, x2=rx2, y2=barsY2 - lineH}
	local bar2 = {x1=rx1, y1=barsY1, x2=rx2, y2=barsY1 + barH}

	geom = {
		pad        = pad,
		titleBar   = {x1=cx1, y1=titleY1, x2=cx2, y2=titleY2},
		closeRect  = closeRect,
		sidebar    = {x1=sbX1, y1=bodyY1, x2=sbX2, y2=bodyY2},
		groups     = { res = resGrp, mode = modeGrp, group = groupGrp, win = winGrp },
		legendRows = legendRows,
		legendLabelY = legendLabelY,
		plotOuter  = {x1=rx1, y1=plotOuterY1, x2=rx2, y2=plotOuterY2},
		plot       = {x1=plotX1, y1=plotY1, x2=plotX2, y2=plotY2},
		bar1       = bar1,
		bar2       = bar2,
		lineH      = lineH,
	}
end

local function InRect(x, y, r)
	return r and x >= r.x1 and x <= r.x2 and y >= r.y1 and y <= r.y2
end

local function IsOnPanel(x, y)
	return x >= panelRect.x1 and x <= panelRect.x2 and y >= panelRect.y1 and y <= panelRect.y2
end

--------------------------------------------------------------------------------
-- Baked content
--------------------------------------------------------------------------------

local function BakeTitle()
	local tb = geom.titleBar
	local res, mode = RESOURCES[sel.res], MODES[sel.mode]
	local cap = res.label .. " " .. mode.label .. TEXT_DIM .. "   by " ..
		((GROUPINGS[sel.group].key == "unit") and "unit" or "category") ..
		"  \226\128\162  " .. mode.line .. " drawn as line"
	font:Begin()
	font:Print(TEXT_COLOR .. cap, tb.x1 + 4*uiScale, tb.y1 + (tb.y2-tb.y1)*0.5 - 6*uiScale, 16*uiScale, "lo")
	if view.enough then
		local tStr = TEXT_DIM .. "Window  " .. TEXT_COLOR .. formatTime(view.t0) .. " - " .. formatTime(view.t1)
		font:Print(tStr, geom.closeRect.x1 - 12*uiScale, tb.y1 + (tb.y2-tb.y1)*0.5 - 5*uiScale, 12*uiScale, "ro")
	end
	font:End()

	local cr = geom.closeRect
	DrawBox(cr.x1, cr.y1, cr.x2, cr.y2, CATEGORY_BG, 4)
	DrawAccentStrip(cr.x1, cr.x2, cr.y2, ACCENT_CLOSE)
	font:Begin()
	font:Print(TEXT_COLOR .. "x", cr.x1+(cr.x2-cr.x1)*0.5, cr.y1+(cr.y2-cr.y1)*0.5-6*uiScale, 15*uiScale, "co")
	font:End()
end

local function BakeSelectorGroup(grp, defs, selected, title, accentFn)
	font:Begin()
	font:Print(TEXT_DIM .. title, geom.sidebar.x1 + 2*uiScale, grp.labelY + 2*uiScale, 9*uiScale, "lo")
	font:End()
	for i = 1, #defs do
		local r = grp.rects[i]
		local isSel = (i == selected)
		DrawBox(r.x1, r.y1, r.x2, r.y2, isSel and CATEGORY_BG or SECTION_BG, 4)
		if isSel then
			glColor(SELECTED_OVERLAY[1], SELECTED_OVERLAY[2], SELECTED_OVERLAY[3], SELECTED_OVERLAY[4])
			RectRound(r.x1, r.y1, r.x2, r.y2, 4*uiScale)
			DrawAccentStrip(r.x1, r.x2, r.y2, (accentFn and accentFn(defs[i])) or ACCENT_PANEL)
		end
	end
	font:Begin()
	for i = 1, #defs do
		local r = grp.rects[i]
		font:Print(((i == selected) and TEXT_COLOR or TEXT_DIM) .. defs[i].label,
			r.x1 + (r.x2-r.x1)*0.5, r.y1+(r.y2-r.y1)*0.5-5*uiScale, 10*uiScale, "co")
	end
	font:End()
end

local function BakeSelectors()
	local g = geom.groups
	BakeSelectorGroup(g.res,   RESOURCES, sel.res,   "RESOURCE", function(d) return d.accent end)
	BakeSelectorGroup(g.mode,  MODES,     sel.mode,  "SHOW",     function(d) return d.accent end)
	BakeSelectorGroup(g.group, GROUPINGS, sel.group, "GROUP")
	BakeSelectorGroup(g.win,   WINDOWS,   sel.win,   "WINDOW")
end

local function BakeLegend()
	local hiddenSet = hidden[GROUPINGS[sel.group].key]
	local rows = geom.legendRows
	font:Begin()
	font:Print(TEXT_DIM .. "NOW  " .. TEXT_COLOR .. numFormat(view.curTotal) .. TEXT_DIM .. " /s",
		geom.sidebar.x1 + 2*uiScale, geom.legendLabelY + 2*uiScale, 9*uiScale, "lo")
	font:End()
	for slot = 1, #view.buckets do
		local r = rows[slot]
		if not r then break end
		local b  = view.buckets[slot]
		local c  = b.color
		local sw = 11*uiScale
		local sy = r.y1 + (r.y2-r.y1)*0.5
		local shown = not hiddenSet[b.key]
		if shown then
			glColor(c[1], c[2], c[3], 1)
			glRect(r.x1+4*uiScale, sy-sw*0.5, r.x1+4*uiScale+sw, sy+sw*0.5)
		else
			glColor(c[1]*0.45, c[2]*0.45, c[3]*0.45, 1)
			glRect(r.x1+4*uiScale, sy-sw*0.5, r.x1+4*uiScale+sw, sy+sw*0.5)
			glColor(0.08, 0.08, 0.09, 1)
			glRect(r.x1+5.5*uiScale, sy-sw*0.5+1.5*uiScale, r.x1+4*uiScale+sw-1.5*uiScale, sy+sw*0.5-1.5*uiScale)
		end
		local name = b.label
		if b.folded then name = name .. " (" .. b.folded .. ")" end
		local txtCol = shown and ColorEscape(c) or TEXT_DIM
		font:Begin()
		font:Print(txtCol .. name, r.x1+4*uiScale+sw+6*uiScale, sy-4.5*uiScale, 9.5*uiScale, "lo")
		font:Print((shown and TEXT_COLOR or TEXT_DIM) .. numFormat(b.cur) .. TEXT_DIM .. string.format(" %d%%", math_floor(b.pct*100 + 0.5)),
			r.x2 - 4*uiScale, sy-4.5*uiScale, 9*uiScale, "ro")
		font:End()
	end
end

local function BakeGrid()
	local p = geom.plot
	DrawBox(p.x1, p.y1, p.x2, p.y2, PLOT_BG, 3)
	glColor(GRID_COLOR[1], GRID_COLOR[2], GRID_COLOR[3], GRID_COLOR[4])
	for i = 0, GRID_DIVS do
		local fy = p.y1 + (p.y2-p.y1) * (i/GRID_DIVS)
		glRect(p.x1, fy, p.x2, fy+1)
		local fx = p.x1 + (p.x2-p.x1) * (i/GRID_DIVS)
		glRect(fx, p.y1, fx+1, p.y2)
	end
	font:Begin()
	for i = 0, GRID_DIVS do
		local fy = p.y1 + (p.y2-p.y1) * (i/GRID_DIVS)
		font:Print(TEXT_DIM .. numFormat(view.yMax * (i/GRID_DIVS)), p.x1 - 5*uiScale, fy - 4*uiScale, 9*uiScale, "ro")
		local fx = p.x1 + (p.x2-p.x1) * (i/GRID_DIVS)
		local t  = view.t0 + (view.t1 - view.t0) * (i/GRID_DIVS)
		local align = (i == 0) and "lo" or ((i == GRID_DIVS) and "ro" or "co")
		font:Print(TEXT_DIM .. formatTime(t), fx, p.y1 - TIME_STRIP_H*uiScale*0.7, 9*uiScale, align)
	end
	font:End()
end

-- Stacked columns: one rect per (column, band). With MAX_COLUMNS = 360 and at
-- most TOP_N + 2 bands this is well under 4k instances, baked once per refresh.
local function BakeStack()
	local p = geom.plot
	local hiddenSet = hidden[GROUPINGS[sel.group].key]
	local n = view.nCols
	local colW = (p.x2 - p.x1) / n
	local scaleY = (p.y2 - p.y1) / view.yMax
	local buckets = view.buckets
	-- Draw largest first so it sits at the bottom of the stack
	for c = 1, n do
		local cx1 = p.x1 + (c-1) * colW
		local cx2 = cx1 + colW + 0.5   -- slight overlap hides seams between columns
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
	local p = geom.plot
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

	-- End-of-line labels: stack top and line value
	font:Begin()
	local yLine  = p.y1 + view.lineCols[n] * scaleY
	local yStack = p.y1 + view.stackCols[n] * scaleY
	local lblLine  = { y = yLine,  text = numFormat(view.lineCols[n]),  color = LINE_COLOR }
	local lblStack = { y = yStack, text = numFormat(view.stackCols[n]), color = MODES[sel.mode].accent }
	local a, b = lblStack, lblLine
	if b.y < a.y then a, b = b, a end
	local minGap = 12*uiScale
	if b.y < a.y + minGap then b.y = a.y + minGap end
	for _, l in ipairs({a, b}) do
		local yy = Clamp(l.y, p.y1, p.y2)
		font:Print(ColorEscape(l.color) .. l.text, p.x2 + 5*uiScale, yy - 5*uiScale, 10*uiScale, "lo")
	end
	font:End()
end

-- One 100% bar: segments left to right, largest first, label inside when it fits
local function BakeBar(r, segs, total, caption, captionColor)
	local lineH = geom.lineH
	font:Begin()
	font:Print(ColorEscape(captionColor) .. caption .. TEXT_DIM .. "  now  " .. TEXT_COLOR .. numFormat(total) .. TEXT_DIM .. " /s",
		r.x1 + 2*uiScale, r.y2 + 2*uiScale, 9.5*uiScale, "lo")
	font:End()
	DrawBox(r.x1, r.y1, r.x2, r.y2, PLOT_BG, 3)
	if total <= 0 or #segs == 0 then
		font:Begin()
		font:Print(TEXT_DIM .. "nothing", r.x1 + (r.x2-r.x1)*0.5, r.y1 + (r.y2-r.y1)*0.5 - 4.5*uiScale, 9.5*uiScale, "co")
		font:End()
		return
	end
	local w = r.x2 - r.x1
	local x = r.x1
	local labels = {}
	for i = 1, #segs do
		local s = segs[i]
		local sw = w * (s.cur / total)
		if sw >= 1 then
			glColor(s.color[1], s.color[2], s.color[3], 0.9)
			RectRound(x, r.y1 + 1, x + sw, r.y2 - 1, 2*uiScale)
			local txt = s.label .. string.format("  %d%%", math_floor(s.pct*100 + 0.5))
			local tw = font:GetTextWidth(txt) * 9*uiScale + 8*uiScale
			if tw < sw then
				labels[#labels+1] = { x = x + sw*0.5, txt = txt }
			elseif sw > 22*uiScale then
				labels[#labels+1] = { x = x + sw*0.5, txt = string.format("%d%%", math_floor(s.pct*100 + 0.5)) }
			end
			x = x + sw
		end
	end
	font:Begin()
	for i = 1, #labels do
		font:Print("\255\020\020\020" .. labels[i].txt, labels[i].x + 0.7*uiScale, r.y1 + (r.y2-r.y1)*0.5 - 4.5*uiScale - 0.7*uiScale, 9*uiScale, "co")
		font:Print("\255\250\250\250" .. labels[i].txt, labels[i].x, r.y1 + (r.y2-r.y1)*0.5 - 4.5*uiScale, 9*uiScale, "co")
	end
	font:End()
end

local function BakeBars()
	local mode = MODES[sel.mode]
	local other = MODES[(sel.mode == 1) and 2 or 1]
	BakeBar(geom.bar1, view.live,     view.curTotal, RESOURCES[sel.res].label .. " " .. mode.label,  mode.accent)
	BakeBar(geom.bar2, view.liveLine, view.curLine,  RESOURCES[sel.res].label .. " " .. other.label, other.accent)
end

local function BakeNoData()
	local p = geom.plot
	DrawBox(p.x1, p.y1, p.x2, p.y2, PLOT_BG, 3)
	font:Begin()
	font:Print(TEXT_DIM .. "Collecting economy samples...",
		p.x1+(p.x2-p.x1)*0.5, p.y1+(p.y2-p.y1)*0.5-6*uiScale, 13*uiScale, "co")
	font:End()
end

local function BuildContentList()
	contentList = TexCache(contentList,
		panelRect.x1, panelRect.y1, panelRect.x2, panelRect.y2, function()
		DrawPanelChrome(panelRect.x1, panelRect.y1, panelRect.x2, panelRect.y2, ACCENT_PANEL)
		BakeTitle()
		BakeSelectors()
		if view.enough then
			BakeLegend()
			BakeGrid()
			BakeStack()
			BakeLine()
			BakeBars()
		else
			BakeNoData()
		end
	end)
	contentDirty = false
end

--------------------------------------------------------------------------------
-- Hover + tooltip (immediate, over the cache)
--------------------------------------------------------------------------------

local function HoverTint(r)
	glColor(HOVER_OVERLAY[1], HOVER_OVERLAY[2], HOVER_OVERLAY[3], HOVER_OVERLAY[4])
	RectRound(r.x1, r.y1, r.x2, r.y2, 4*uiScale)
end

local function DrawTooltipBox(lines, mx, my)
	-- lines = { {text, sizeMul}, ... } ; measures the widest line
	local size = 10*uiScale
	local boxW, boxH = 0, 8*uiScale
	for i = 1, #lines do
		local w = font:GetTextWidth(lines[i]) * size + 14*uiScale
		if w > boxW then boxW = w end
		boxH = boxH + 13*uiScale
	end
	local bx1 = Clamp(mx + 12*uiScale, panelRect.x1, panelRect.x2 - boxW)
	local by2 = Clamp(my + 14*uiScale, panelRect.y1 + boxH, panelRect.y2)
	local bx2, by1 = bx1 + boxW, by2 - boxH
	glColor(0, 0, 0, 0.86)
	RectRound(bx1, by1, bx2, by2, 3*uiScale)
	font:Begin()
	for i = 1, #lines do
		font:Print(lines[i], bx1 + 7*uiScale, by2 - 4*uiScale - i*13*uiScale + 3*uiScale, size, "lo")
	end
	font:End()
end

local function DrawHoverAndTooltip(mx, my)
	local newHover = nil

	if InRect(mx, my, geom.closeRect) then HoverTint(geom.closeRect) ; newHover = "close" end

	for gname, grp in pairs(geom.groups) do
		for i = 1, #grp.rects do
			if InRect(mx, my, grp.rects[i]) and sel[gname] ~= i then
				HoverTint(grp.rects[i]) ; newHover = gname .. i
			end
		end
	end

	if view.enough then
		for slot = 1, #view.buckets do
			local r = geom.legendRows[slot]
			if not r then break end
			if InRect(mx, my, r) then HoverTint(r) ; newHover = "legend" .. slot end
		end

		local p = geom.plot
		if InRect(mx, my, p) then
			local n = view.nCols
			local col = Clamp(math_floor((mx - p.x1) / (p.x2 - p.x1) * n) + 1, 1, n)
			local colW = (p.x2 - p.x1) / n
			-- Column highlight + crosshair
			glColor(1, 1, 1, 0.10)
			glRect(p.x1 + (col-1)*colW, p.y1, p.x1 + col*colW, p.y2)
			glColor(1, 1, 1, 0.15)
			glRect(p.x1, my, p.x2, my+1)

			local hiddenSet = hidden[GROUPINGS[sel.group].key]
			local t = view.t0 + (view.t1 - view.t0) * ((col-0.5) / n)
			local lines = {}
			lines[#lines+1] = TEXT_DIM .. "Time " .. TEXT_COLOR .. formatTime(t) ..
				TEXT_DIM .. "   " .. MODES[sel.mode].line .. " " .. TEXT_COLOR .. numFormat(view.lineCols[col]) ..
				TEXT_DIM .. "   " .. MODES[sel.mode].label .. " " .. TEXT_COLOR .. numFormat(view.stackCols[col])
			-- Bands, top of stack first so the tooltip reads like the plot
			local total = view.stackCols[col]
			for bi = #view.buckets, 1, -1 do
				local b = view.buckets[bi]
				if not hiddenSet[b.key] and b.cols[col] > 0 then
					local pct = (total > 0) and math_floor(b.cols[col] / total * 100 + 0.5) or 0
					lines[#lines+1] = ColorEscape(b.color) .. "\226\150\160 " .. b.label ..
						TEXT_COLOR .. "  " .. numFormat(b.cols[col]) .. TEXT_DIM .. string.format("  %d%%", pct)
				end
			end
			DrawTooltipBox(lines, mx, my)
			newHover = "plot"   -- no sound spam while sweeping the plot
			if hoveredKey == "plot" then newHover = hoveredKey end
		end

		-- Bar hover: name the segment under the cursor even when its label did not fit
		for _, pair in ipairs({ {geom.bar1, view.live, view.curTotal}, {geom.bar2, view.liveLine, view.curLine} }) do
			local r, segs, total = pair[1], pair[2], pair[3]
			if InRect(mx, my, r) and total > 0 then
				local x = r.x1
				local w = r.x2 - r.x1
				for i = 1, #segs do
					local s  = segs[i]
					local sw = w * (s.cur / total)
					if mx >= x and mx <= x + sw then
						DrawTooltipBox({ ColorEscape(s.color) .. s.label .. TEXT_COLOR .. "  " .. numFormat(s.cur) ..
							TEXT_DIM .. string.format(" /s   %d%%", math_floor(s.pct*100 + 0.5)) }, mx, my)
						break
					end
					x = x + sw
				end
				newHover = "bar"
				if hoveredKey == "bar" then newHover = hoveredKey end
			end
		end
	end

	if newHover ~= hoveredKey then
		if newHover and newHover ~= "plot" and newHover ~= "bar" then PlayHoverSound() end
		hoveredKey = newHover
	end
end

--------------------------------------------------------------------------------
-- Open / Close / Toggle + WG hook
--------------------------------------------------------------------------------

local function Open()
	if isOpen then return end
	isOpen = true
	BuildGeometry()
	RefreshView()
	contentDirty = true
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
	return IsOnPanel(x, y)
end

function widget:MouseRelease(x, y, button)
	if not isOpen then return false end
	if button ~= 1 then return IsOnPanel(x, y) end
	if not IsOnPanel(x, y) then return false end

	if InRect(x, y, geom.closeRect) then
		Close()
		return true
	end

	for gname, grp in pairs(geom.groups) do
		for i = 1, #grp.rects do
			if InRect(x, y, grp.rects[i]) then
				if sel[gname] ~= i then
					sel[gname] = i
					RefreshView()
					contentDirty = true
					PlayClickSound()
				end
				return true
			end
		end
	end

	if view.enough then
		local hiddenSet = hidden[GROUPINGS[sel.group].key]
		for slot = 1, #view.buckets do
			local r = geom.legendRows[slot]
			if not r then break end
			if InRect(x, y, r) then
				local k = view.buckets[slot].key
				hiddenSet[k] = (not hiddenSet[k]) or nil
				RefreshView()
				contentDirty = true
				PlayClickSound()
				return true
			end
		end
	end

	return true
end

function widget:TextCommand(command)
	if command == "econgraph" then
		Toggle()
		return true
	end
	return false
end

--------------------------------------------------------------------------------
-- Lifecycle
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

function widget:GameFrame(n)
	if n % 30 ~= 0 then return end
	TakeSample()
	if isOpen then
		RefreshView()
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
	Flush()
end

function widget:Initialize()
	vsx, vsy = spGetViewGeometry()
	fontfileScale = (0.5 + (vsx * vsy / 5700000))
	BindDrawing()
	ReloadFont()
	BuildGeometry()

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

	if WG.StaticLayout then
		WG.StaticLayout.Register(LAYOUT_ID, {
			label  = "Economy Graph",
			onMove = function() widget:ViewResize(vsx, vsy) end,
			isVisible = function() return isOpen end,
		})
	end
end

function widget:Shutdown()
	if WG.StaticLayout then WG.StaticLayout.Unregister(LAYOUT_ID) end
	FreeCache(contentList)
	contentList = nil
	if font then
		local SG = WG.StaticGUI
		if SG and SG.DeleteFont then SG.DeleteFont(font) else gl.DeleteFont(font) end
		font = nil
	end
	if ownsMorphGlobal then widgetHandler:DeregisterGlobal('MorphUpdate') end
	WG.StaticEconGraph = nil
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
