--------------------------------------------------------------------------------
--  file:    gui_static_placement.lua
--  brief:   Start position selection widget.  Activates after faction choice,
--           shows map spots as on-screen markers, handles selection + confirm.
--           Also mirrors the spots onto the minimap (hover + clickable there
--           too) and hides the rest of the widget UI for the duration of the
--           pregame flow (faction phase included).
--
--  Phase protocol (via game rules params written by game_spawn.lua):
--    "phase"                  "faction" | "placement" | "done"
--    "placementDeadlineFrame"  frame number of the placement deadline
--    "spotCount"               total number of spots
--    "isFFA"                   1 = all spots open to all, 0 = sided
--    "spot_N_x"                world X for spot N (1-based)
--    "spot_N_z"                world Z for spot N
--    "spot_N_at"               allyteam owner (-1 = all in FFA)
--    "spotclaim_N"             teamID that claimed spot N, or -1
--
--  Messages sent to game_spawn gadget via SendLuaRulesMsg:
--    "\139" .. spotIdx         tentative spot selection
--    "\140"                    confirm placement
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name    = "Static Placement",
		desc    = "Start position selection screen",
		author  = "",
		date    = "2026",
		license = "GNU GPL, v2 or later",
		layer   = 1900,   -- below faction chooser (2000) but above normal widgets
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- Assets
--------------------------------------------------------------------------------

local bgcorner  = "LuaUI/Images/bgcorner.png"
local accentImg = ":n:LuaUI/Images/staticgui_accent.png"

--------------------------------------------------------------------------------
-- Message bytes (must match game_spawn.lua)
--------------------------------------------------------------------------------

local SELECT_BYTE  = "\139"
local CONFIRM_BYTE = "\140"

--------------------------------------------------------------------------------
-- Layout constants (base px at 1080p)
--------------------------------------------------------------------------------

local PANEL_W        = 540
local PANEL_H        = 96
local PANEL_PAD      = 14
local PANEL_BOTTOM   = 28    -- gap from screen bottom
local ACCENT_H       = 5
local OUTER_CORNER   = 5
local INNER_CORNER   = 4.3
local INNER_INSET    = 2.25

local BTN_W          = 180
local BTN_H          = 44
local BTN_CORNER     = 4

local MARKER_SIZE    = 28    -- half-size of the square spot marker in base px
local LABEL_SIZE     = 14    -- spot index font size in base px
local TIMER_BAR_H    = 5

local MMARK_SIZE     = 8     -- half-size of the minimap spot marker in base px
local MMARK_PICK_PAD = 1.75  -- click/hover pick radius multiplier on the minimap

local COUNTDOWN_BEEP_AT  = 10
local PLACEMENT_SECONDS  = 30   -- nominal total for progress bar reference

--------------------------------------------------------------------------------
-- Pregame UI hiding
--
-- While the pregame flow runs (phase "faction" or "placement") every other
-- widget's draw + mouse callins are stashed and stripped, leaving only the
-- faction chooser, this widget, the api/service widgets and the engine
-- minimap on screen.  Everything is restored the moment the phase ends, and
-- again from Shutdown as a safety net.
--
-- Callin-stripping is used instead of widgetHandler:DisableWidget on purpose:
-- Disable/Enable persists to the widget order config, so a crash mid-pregame
-- would leave the whole UI disabled on the next launch.  Stripped callins
-- live only in this widget's memory and reset with any luaui reload.
--------------------------------------------------------------------------------

local HIDE_REST_OF_UI  = true
local KEEP_LAYER_ABOVE = 1800   -- keeps the faction chooser (2000) and this (1900)

-- Widgets whose name matches any of these Lua patterns are never hidden.
local KEEP_NAME_PATTERNS = {
	"^API", "^api",                -- api_* service widgets (shapes, layout, trackers)
	"GUI Shader", "[Gg]uishader",  -- panel blur must keep running
	"[Cc]hat", "[Cc]onsole",       -- pregame chat still matters in multiplayer
	"[Ff]action",                  -- faction chooser, whatever its exact name
}

-- Callins removed from hidden widgets.  The draw set makes them invisible;
-- the mouse/IsAbove/GetTooltip set stops invisible panels from eating clicks.
local STRIP_CALLINS = {
	"DrawScreen", "DrawScreenEffects", "DrawScreenPost",
	"DrawWorld", "DrawWorldPreUnit", "DrawInMiniMap", "DrawInMiniMapBackground",
	"MousePress", "MouseMove", "MouseWheel", "IsAbove", "GetTooltip",
}

--------------------------------------------------------------------------------
-- Theme (matches faction chooser / Static GUI suite)
--------------------------------------------------------------------------------

local BORDER_COLOR       = {0.15, 0.15, 0.15, 0.90}
local BORDER_COLOR_GUI   = {0.15, 0.15, 0.15, 0.90}
local PANEL_BG_COLOR     = {0.05, 0.05, 0.06, 0.88}
local PANEL_BG_COLOR_GUI = {0.00, 0.00, 0.00, 0.22}

local TEXT_COLOR         = "\255\244\244\244"
local SUBTEXT_COLOR      = "\255\190\190\200"
local URGENT_COLOR       = "\255\240\80\80"
local NORMAL_COLOR       = "\255\244\244\244"

-- Marker colours
local COL_AVAILABLE      = {0.22, 0.85, 0.30, 0.90}   -- unclaimed, my side
local COL_AVAILABLE_H    = {0.30, 1.00, 0.38, 1.00}   -- hovered
local COL_SELECTED       = {0.28, 0.62, 1.00, 1.00}   -- my tentative pick
local COL_CONFIRMED      = {0.18, 0.90, 0.28, 1.00}   -- my confirmed pick
local COL_TEAMMATE       = {0.55, 0.55, 0.60, 0.70}   -- claimed by ally
local COL_ENEMY          = {0.55, 0.20, 0.20, 0.40}   -- other side (informational)
local COL_INNER          = {0.02, 0.02, 0.04, 0.80}   -- inner fill of marker

-- Button colours
local BTN_DISABLED       = {0.18, 0.18, 0.20, 0.80}
local BTN_READY          = {0.18, 0.52, 0.98, 0.95}
local BTN_DONE           = {0.14, 0.68, 0.24, 0.95}
local BTN_HOVER          = {0.30, 0.68, 1.00, 1.00}

--------------------------------------------------------------------------------
-- GL / Spring locals
--------------------------------------------------------------------------------

-- Raw engine entry points. Only the legacy fallback further down calls these
-- directly; everything else goes through the shim locals so that drawing is
-- batched by the shapes module when it is available.
local rawColor    = gl.Color
local rawRect     = gl.Rect
local rawTexture  = gl.Texture
local rawTexRect  = gl.TexRect

-- Drawing shim. Forward-declared here so every function below closes over the
-- same upvalues; bound for real by BindDrawing() in widget:Initialize.
local glColor, glRect, glTexture, glTexRect
local RectRound, AccentStrip, Flush
local usingShapes = false

-- The shapes module batches, so text drawn between two shape calls would land
-- on the wrong side of them. Wrapping the font handle makes font:Begin() and
-- font:End() flush at the right moments, which keeps every existing
-- font:Print call site correct without auditing draw order by hand.
local function WrapFont(f)
	local SG = WG.StaticGUI
	if f and SG and SG.WrapFont then
		return SG.WrapFont(f)
	end
	return f
end

local function ReleaseFont(f)
	if not f then return end
	local SG = WG.StaticGUI
	if SG and SG.DeleteFont then
		SG.DeleteFont(f)
	else
		gl.DeleteFont(f)
	end
end
local spGetViewGeometry   = Spring.GetViewGeometry
local spGetMouseState     = Spring.GetMouseState
local spPlaySoundFile     = Spring.PlaySoundFile
local spSendLuaRulesMsg   = Spring.SendLuaRulesMsg
local spGetGameRulesParam = Spring.GetGameRulesParam
local spGetTeamRulesParam = Spring.GetTeamRulesParam
local spWorldToScreenCoords = Spring.WorldToScreenCoords
local spGetGroundHeight   = Spring.GetGroundHeight
local spTraceScreenRay    = Spring.TraceScreenRay
local spIsAboveMiniMap     = Spring.IsAboveMiniMap
local spGetMiniMapGeometry = Spring.GetMiniMapGeometry
local spGetMiniMapRotation = Spring.GetMiniMapRotation   -- nil on older engines

local mapSizeX = Game.mapSizeX
local mapSizeZ = Game.mapSizeZ

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local vsx, vsy    = spGetViewGeometry()
local widgetScale = 1

local phase       = "faction"     -- local copy; polled each Update
local active      = false         -- true once we enter placement phase
local gameStarted = false

local myTeamID    = Spring.GetMyTeamID()
local myAllyTeamID = Spring.GetMyAllyTeamID()
local isSpectator = false
local isFFA       = false

local spots       = {}   -- i → {x, z, allyteam}
local spotCount   = 0

-- Per-frame derived data (updated in Update)
local spotScreen    = {}   -- i → {sx, sy, visible}
local claimCount    = {}   -- i → number of allied teams claiming spot i (0/nil = none visible)
local claimMine     = {}   -- i → true if my own team claims spot i
local hoveredSpot   = nil  -- index or nil
local mySelected    = nil  -- server-acknowledged selected spot index
local myConfirmed   = nil  -- server-acknowledged confirmed spot index
local localPending  = nil  -- local pending index (waiting for server ack)
local shareMode     = false -- true when no free same-side spots remain (overflow)

local confirmed     = false   -- local flag: player has confirmed their spot
local secondsLeft   = PLACEMENT_SECONDS
local lastBeepSecond = nil

-- Panel + button geometry (recomputed in RecalculateGeometry)
local panelX1, panelY1, panelX2, panelY2 = 0, 0, 0, 0
local btnX1,   btnY1,   btnX2,   btnY2   = 0, 0, 0, 0
local btnHovered = false

--------------------------------------------------------------------------------
-- Font
--------------------------------------------------------------------------------

local fontfile = LUAUI_DIRNAME .. "fonts/" ..
		Spring.GetConfigString("ui_font", "Saira_SemiCondensed-SemiBold.ttf")
local font

local function LoadWidgetFont()
	local scale = 0.5 + (vsx * vsy / 5700000)
	font = WrapFont(gl.LoadFont(fontfile, 25 * scale, 4.5 * scale, 1.8))
end

--------------------------------------------------------------------------------
-- Sound
--------------------------------------------------------------------------------

local function PlayHoverSound()  spPlaySoundFile("hover",     1.0, "ui") end
local function PlayClickSound()  spPlaySoundFile("leftclick", 1.0, "ui") end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Drawing shim
--
-- Panel chrome used to be drawn with gl.Rect and gl.TexRect, which are OpenGL
-- 1.1 immediate mode: gl.Rect is glRectf and gl.TexRect is a raw
-- glBegin(GL_QUADS). One RectRound cost 7 glBegin/glEnd pairs and 2 texture
-- binds. None of that exists in OpenGL core profile, which is the only way
-- past GL 2.1 on macOS, and it is the worst case for any driver translating
-- GL to Metal or Vulkan.
--
-- Shapes now go through WG.StaticGUI (api_staticgui_shapes.lua), which batches
-- them into a single instanced draw call and rounds corners analytically in a
-- fragment shader rather than blitting a corner texture.
--
-- If that module is unavailable - old driver, shader compile failure - these
-- shims fall back to the original immediate-mode code. Slow, but not blank.
--------------------------------------------------------------------------------

local function LegacyRectRound(px, py, sx, sy, cs)
	px, py, sx, sy, cs = math.floor(px), math.floor(py),
	                      math.floor(sx), math.floor(sy), math.floor(cs)
	rawRect(px + cs, py, sx - cs, sy)
	rawRect(sx - cs, py + cs, sx,      sy - cs)
	rawRect(px,      py + cs, px + cs, sy - cs)
	rawTexture(bgcorner)
	rawTexRect(px,      py + cs, px + cs, py)
	rawTexRect(sx,      py + cs, sx - cs, py)
	rawTexRect(px,      sy - cs, px + cs, sy)
	rawTexRect(sx,      sy - cs, sx - cs, sy)
	rawTexture(false)
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
		glColor     = SG.Color
		glRect      = SG.Rect
		glTexture   = SG.Texture
		glTexRect   = SG.TexRect
		RectRound   = SG.RectRound
		AccentStrip = SG.AccentStrip
		Flush       = SG.Flush
		usingShapes = true
	else
		glColor     = rawColor
		glRect      = rawRect
		glTexture   = rawTexture
		glTexRect   = rawTexRect
		RectRound   = LegacyRectRound
		AccentStrip = LegacyAccentStrip
		Flush       = NoOp
		usingShapes = false
	end
end

BindDrawing()

local function IsOnRect(x, y, x1, y1, x2, y2)
	return x >= x1 and x <= x2 and y >= y1 and y <= y2
end

local function GetBorderColor()
	return WG.guishader and BORDER_COLOR_GUI or BORDER_COLOR
end

local function GetPanelBGColor()
	return WG.guishader and PANEL_BG_COLOR_GUI or PANEL_BG_COLOR
end

--------------------------------------------------------------------------------
-- Geometry
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Layout (api_staticgui_layout.lua). The layout module owns this panel's origin
-- once the user has dragged it in tweak mode (Ctrl+F11); until then, and when
-- the module is absent, the default computed below is used unchanged.
--------------------------------------------------------------------------------

local LAYOUT_ID = "placement"

local function LayoutPlace(x1, y1, w, h)
	local L = WG.StaticLayout
	if L then return L.Place(LAYOUT_ID, x1, y1, w, h) end
	return x1, y1
end

local function RecalculateGeometry()
	vsx, vsy    = spGetViewGeometry()
	widgetScale  = 0.60 + (vsx * vsy / 5000000)

	local pw  = math.floor(PANEL_W * widgetScale)
	local ph  = math.floor(PANEL_H * widgetScale)
	local pb  = math.floor(PANEL_BOTTOM * widgetScale)

	panelX1 = math.floor((vsx - pw) / 2)
	panelY1 = pb
	panelX1, panelY1 = LayoutPlace(panelX1, panelY1, pw, ph)
	panelX2 = panelX1 + pw
	panelY2 = panelY1 + ph

	local bw  = math.floor(BTN_W * widgetScale)
	local bh  = math.floor(BTN_H * widgetScale)
	local pad = math.floor(PANEL_PAD * widgetScale)
	btnX1 = panelX2 - pad - bw
	btnY1 = panelY1 + math.floor((ph - bh) / 2)
	btnX2 = btnX1 + bw
	btnY2 = btnY1 + bh
end

--------------------------------------------------------------------------------
-- Spot loading (from game rules params broadcast by the gadget)
--------------------------------------------------------------------------------

local function LoadSpots()
	spotCount = math.floor(spGetGameRulesParam("spotCount") or 0)
	isFFA     = (spGetGameRulesParam("isFFA") or 0) == 1

	spots = {}
	for i = 1, spotCount do
		local x  = spGetGameRulesParam("spot_" .. i .. "_x")
		local z  = spGetGameRulesParam("spot_" .. i .. "_z")
		local at = spGetGameRulesParam("spot_" .. i .. "_at")
		if x and z then
			spots[i] = { x = x, z = z, allyteam = at or -1 }
		end
	end

	Spring.Echo("[Placement] Loaded " .. spotCount .. " spots  isFFA=" .. tostring(isFFA))
end

--------------------------------------------------------------------------------
-- Per-frame state polling
--------------------------------------------------------------------------------

local function UpdateSpotScreenPositions()
	for i, spot in pairs(spots) do
		local gy = spGetGroundHeight(spot.x, spot.z) or 0
		local sx, sy = spWorldToScreenCoords(spot.x, gy + 8, spot.z)
		if sx then
			local vis = (sx > -MARKER_SIZE and sx < vsx + MARKER_SIZE and
			             sy > -MARKER_SIZE and sy < vsy + MARKER_SIZE)
			spotScreen[i] = { sx = math.floor(sx), sy = math.floor(sy), visible = vis }
		else
			spotScreen[i] = { sx = 0, sy = 0, visible = false }
		end
	end
end

local function UpdateClaimCache()
	-- Only read claims for teams on our own side.  Claim params are allied-only
	-- (SetTeamRulesParam with {allied=true}), so enemy claims are invisible here,
	-- which is the desired behaviour.  Spectators see all teams' params regardless.
	-- Because all sharers of a same-side spot are allied, the counts we build here
	-- are the true occupancy of every spot we care about.
	claimCount = {}
	claimMine  = {}
	local allyTeams = Spring.GetTeamList(myAllyTeamID) or {}
	for _, tID in ipairs(allyTeams) do
		local claimed = spGetTeamRulesParam(tID, "claimedSpot")
		if claimed and claimed ~= -1 then
			local si = math.floor(claimed)
			claimCount[si] = (claimCount[si] or 0) + 1
			if tID == myTeamID then claimMine[si] = true end
		end
	end

	-- Sharing becomes available once no same-side spot is free.  Spectators never
	-- place, so shareMode is irrelevant for them.
	if isSpectator then
		shareMode = false
	else
		local free = 0
		for i, spot in pairs(spots) do
			if (isFFA or spot.allyteam == myAllyTeamID) and not claimCount[i] then
				free = free + 1
			end
		end
		shareMode = (free == 0)
	end
end

local function UpdateServerState()
	mySelected  = spGetTeamRulesParam(myTeamID, "selectedSpot")
	myConfirmed = spGetTeamRulesParam(myTeamID, "confirmedSpot")
	if myConfirmed then
		confirmed = true
	end
end

--------------------------------------------------------------------------------
-- Selection helpers (shared by the world-view and minimap click paths)
--------------------------------------------------------------------------------

local function SpotOnMySide(i)
	local spot = spots[i]
	return spot ~= nil and (isFFA or spot.allyteam == myAllyTeamID)
end

local function SpotSelectable(i)
	if not SpotOnMySide(i) then return false end
	-- Selectable when: unclaimed, already mine, or (share mode) any same-side
	-- spot even if a teammate holds it.
	local occupied = (claimCount[i] or 0) > 0
	return (not occupied) or claimMine[i] or shareMode
end

local function TrySelectSpot(i)
	if SpotSelectable(i) then
		PlayClickSound()
		localPending = i
		spSendLuaRulesMsg(SELECT_BYTE .. i)
	end
end

--------------------------------------------------------------------------------
-- Minimap mapping
--------------------------------------------------------------------------------

-- World (x,z) -> minimap pixel coords (origin bottom-left) for use inside
-- DrawInMiniMap, whose default transform is minimap pixels.  Handles engine
-- minimap rotation when the query API exists: exact for 0 and 180 degrees;
-- 90/270 use the same rotate-around-center math and are best-effort until
-- verified in-game (clicks are unaffected either way, see MinimapPickSpot).
local function WorldToMinimapPx(wx, wz, sx, sy)
	local u = wx / mapSizeX
	local v = wz / mapSizeZ
	local rot = spGetMiniMapRotation and spGetMiniMapRotation() or 0
	if rot ~= 0 then
		local cu, cv = u - 0.5, v - 0.5
		local c, s   = math.cos(rot), math.sin(rot)
		u = 0.5 + c * cu - s * cv
		v = 0.5 + s * cu + c * cv
	end
	return math.floor(u * sx), math.floor(sy - v * sy)
end

-- Screen (x,y) -> nearest spot index when the mouse is over the minimap and
-- within pick range of a spot, else nil.  TraceScreenRay(useMinimap=true)
-- lets the engine do the minimap->world mapping, so rotation and dual-screen
-- minimap layouts are handled by the engine for the click path.
local function MinimapPickSpot(x, y)
	if not (spIsAboveMiniMap and spIsAboveMiniMap(x, y)) then return nil end
	local _, coords = spTraceScreenRay(x, y, true, true)
	if type(coords) ~= "table" then return nil end
	local wx, wz = coords[1], coords[3]

	-- Pick radius: the marker's on-minimap pixel size converted to world units.
	local _, _, mmW, mmH = spGetMiniMapGeometry()
	if not mmW or mmW <= 0 or not mmH or mmH <= 0 then return nil end
	local worldPerPx = math.max(mapSizeX / mmW, mapSizeZ / mmH)
	local radius     = math.floor(MMARK_SIZE * widgetScale) * MMARK_PICK_PAD * worldPerPx

	local best, bestD2 = nil, radius * radius
	for i, spot in pairs(spots) do
		local dx, dz = spot.x - wx, spot.z - wz
		local d2 = dx * dx + dz * dz
		if d2 <= bestD2 then best, bestD2 = i, d2 end
	end
	return best
end

--------------------------------------------------------------------------------
-- Pregame UI hiding
--------------------------------------------------------------------------------

local uiHidden       = false
local stashedCallins = {}   -- widget object -> { callinName -> fn }

local function ShouldKeepWidget(w)
	if w == widget then return true end
	local info  = w.whInfo or {}
	local name  = info.name or ""
	local layer = info.layer or 0
	if layer >= KEEP_LAYER_ABOVE then return true end
	for _, pat in ipairs(KEEP_NAME_PATTERNS) do
		if name:find(pat) then return true end
	end
	return false
end

local function SetUIHidden(hide)
	if not HIDE_REST_OF_UI or hide == uiHidden then return end
	if not (widgetHandler.UpdateWidgetCallIn and widgetHandler.widgets) then
		-- Handler variant without per-callin control; leave the UI alone rather
		-- than touching persistent widget enabled state.
		return
	end
	uiHidden = hide

	if hide then
		for _, w in ipairs(widgetHandler.widgets) do
			if not ShouldKeepWidget(w) then
				local stash = nil
				for _, cname in ipairs(STRIP_CALLINS) do
					if w[cname] then
						stash = stash or {}
						stash[cname] = w[cname]
						w[cname] = nil
						widgetHandler:UpdateWidgetCallIn(cname, w)
					end
				end
				if stash then stashedCallins[w] = stash end
			end
		end
	else
		-- Only re-register callins for widgets that still exist; re-adding a
		-- callin for a widget that was removed while hidden would leave a
		-- zombie entry in the handler's callin lists.
		local present = {}
		for _, w in ipairs(widgetHandler.widgets) do present[w] = true end
		for w, stash in pairs(stashedCallins) do
			for cname, fn in pairs(stash) do
				-- Skip if the widget reassigned this callin itself meanwhile.
				if w[cname] == nil then
					w[cname] = fn
					if present[w] then
						widgetHandler:UpdateWidgetCallIn(cname, w)
					end
				end
			end
		end
		stashedCallins = {}
	end
end

--------------------------------------------------------------------------------
-- Drawing — spot markers
--------------------------------------------------------------------------------

local function DrawMarker(sx, sy, col, borderOnly)
	local ms  = math.floor(MARKER_SIZE * widgetScale)
	local x1  = sx - ms
	local y1  = sy - ms
	local x2  = sx + ms
	local y2  = sy + ms
	local in1 = math.floor(ms * 0.22)

	-- Outer (border color)
	glColor(col[1], col[2], col[3], col[4])
	glRect(x1, y1, x2, y2)

	-- Inner fill (dark, unless borderOnly flag set)
	if not borderOnly then
		glColor(COL_INNER[1], COL_INNER[2], COL_INNER[3], COL_INNER[4])
		glRect(x1 + in1, y1 + in1, x2 - in1, y2 - in1)
	end
end

local function DrawConfirmedRing(sx, sy)
	-- Extra outer ring to highlight the confirmed spot
	local ms   = math.floor(MARKER_SIZE * widgetScale)
	local ring  = math.floor(ms * 0.25)
	local x1   = sx - ms - ring
	local y1   = sy - ms - ring
	local x2   = sx + ms + ring
	local y2   = sy + ms + ring
	glColor(COL_CONFIRMED[1], COL_CONFIRMED[2], COL_CONFIRMED[3], 0.55)
	glRect(x1, y1, x2, y2)
	glColor(COL_INNER[1], COL_INNER[2], COL_INNER[3], COL_INNER[4])
	local brd = math.floor(ring * 0.45)
	glRect(x1 + brd, y1 + brd, x2 - brd, y2 - brd)
end

local function DrawSpots()
	for i, spot in pairs(spots) do
		local sc = spotScreen[i]
		if sc and sc.visible then
			local sx, sy = sc.sx, sc.sy
			local mine     = claimMine[i]           -- my team claims this spot
			local count    = claimCount[i] or 0     -- allied teams on this spot
			local mySide   = isFFA or spot.allyteam == myAllyTeamID

			-- Determine marker state for this spot
			if myConfirmed and myConfirmed == i then
				DrawConfirmedRing(sx, sy)
				DrawMarker(sx, sy, COL_CONFIRMED, false)
			elseif mine then
				-- My tentative or confirmed selection
				DrawMarker(sx, sy, COL_SELECTED, false)
			elseif count > 0 then
				-- Claimed by a teammate.  In share mode it's still a valid target
				-- (overflow players may stack onto it), so highlight on hover.
				if mySide and shareMode and hoveredSpot == i then
					DrawMarker(sx, sy, COL_AVAILABLE_H, false)
				else
					DrawMarker(sx, sy, COL_TEAMMATE, false)
				end
			elseif mySide then
				-- Available on my side (or FFA where all spots are fair game)
				local col = (hoveredSpot == i) and COL_AVAILABLE_H or COL_AVAILABLE
				DrawMarker(sx, sy, col, false)
			else
				-- Enemy-side spot — shown dimmed for reference, no claim state revealed
				DrawMarker(sx, sy, COL_ENEMY, false)
			end

			-- Spot index label centered on marker
			local ms      = math.floor(MARKER_SIZE * widgetScale)
			local labelSz = math.floor(LABEL_SIZE * widgetScale)
			local labelY  = sy - math.floor(labelSz * 0.35)
			font:Begin()
			font:Print(TEXT_COLOR .. i, sx, labelY, labelSz, "con")
			font:End()

			-- Share badge: when a spot is occupied by 2+ allied teams, show the
			-- occupancy count in the top-right corner of the marker.
			if count >= 2 then
				local badgeSz = math.floor(LABEL_SIZE * widgetScale * 0.9)
				local bx = sx + ms - math.floor(badgeSz * 0.3)
				local by = sy + ms - math.floor(badgeSz * 0.9)
				-- small dark chip behind the number
				glColor(0.02, 0.02, 0.04, 0.85)
				glRect(bx - badgeSz, by - math.floor(badgeSz * 0.15),
				       bx + badgeSz, by + badgeSz + math.floor(badgeSz * 0.15))
				font:Begin()
				font:SetTextColor(1, 0.85, 0.35, 1)
				font:Print("x" .. count, bx, by, badgeSz, "cn")
				font:End()
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Drawing — bottom panel
--------------------------------------------------------------------------------

local function DrawPanel()
	local pad        = math.floor(PANEL_PAD    * widgetScale)
	local accentH    = math.floor(ACCENT_H     * widgetScale)
	local outerCS    = math.floor(OUTER_CORNER * widgetScale)
	local innerCS    = math.floor(INNER_CORNER * widgetScale)
	local inset      = math.floor(INNER_INSET  * widgetScale)
	local timerBarH  = math.floor(TIMER_BAR_H  * widgetScale)
	local btnCorner  = math.floor(BTN_CORNER   * widgetScale)

	-- Outer shell
	local bc = GetBorderColor()
	glColor(bc[1], bc[2], bc[3], bc[4])
	RectRound(panelX1, panelY1, panelX2, panelY2, outerCS)

	-- Inner panel background
	local bg = GetPanelBGColor()
	glColor(bg[1], bg[2], bg[3], bg[4])
	RectRound(panelX1 + inset, panelY1 + inset,
	          panelX2 - inset, panelY2 - inset, innerCS)

	-- Accent strip at top
	local accent = {0.28, 0.62, 1.00, 1.00}
	if confirmed then accent = COL_CONFIRMED end
	glColor(accent[1], accent[2], accent[3], accent[4])
	AccentStrip(panelX1 + inset, panelY2 - inset - accentH, panelX2 - inset, panelY2 - inset)

	-- ── Left text content ────────────────────────────────────────────────────
	-- Text zone spans from inner left edge to just left of the button.
	-- "con" centers horizontally at X, so we pass the midpoint of the text zone.
	local textZoneX1 = panelX1 + inset + pad
	local textZoneX2 = btnX1   - pad
	local textCX     = math.floor((textZoneX1 + textZoneX2) / 2)
	local urgent     = secondsLeft <= COUNTDOWN_BEEP_AT

	-- Main instruction line
	local titleSz = math.floor(15 * widgetScale)
	local titleY  = panelY2 - inset - accentH - pad - math.floor(titleSz * 0.1)

	local titleStr
	if isSpectator then
		titleStr = TEXT_COLOR .. "Players Are Choosing Start Positions"
	elseif confirmed then
		titleStr = TEXT_COLOR .. "Waiting for others\226\128\166"   -- ellipsis
	elseif mySelected then
		titleStr = TEXT_COLOR .. "Spot " .. mySelected .. " selected \226\128\148 confirm when ready"
	elseif shareMode then
		-- More players than spots on this side — all spots are taken, so allow
		-- stacking onto an occupied one.
		titleStr = TEXT_COLOR .. "All spots on your side are taken \226\128\148 click one to share it"
	else
		titleStr = SUBTEXT_COLOR .. "Click a highlighted spot to select it"
	end

	font:Begin()
	font:Print(titleStr, textCX, titleY, titleSz, "con")
	font:End()

	-- Timer row
	local timerSz   = math.floor(13 * widgetScale)
	local timerY    = titleY - math.floor(titleSz * 1.5)
	local timeColor = urgent and URGENT_COLOR or NORMAL_COLOR

	font:Begin()
	font:Print(timeColor .. secondsLeft .. "s", textCX, timerY, timerSz, "con")
	font:End()

	-- Progress bar spans the full text zone width
	local barY2  = timerY - math.floor(timerSz * 0.25)
	local barY1  = barY2 - timerBarH
	local barX1  = textZoneX1
	local barX2  = textZoneX2
	local barW   = barX2 - barX1
	local frac   = math.max(0, math.min(1, secondsLeft / PLACEMENT_SECONDS))

	glColor(0.12, 0.12, 0.14, 0.9)
	glRect(barX1, barY1, barX2, barY2)
	if urgent then
		glColor(0.90, 0.22, 0.22, 1.0)
	else
		glColor(0.28, 0.62, 1.00, 0.9)
	end
	glRect(barX1, barY1, barX1 + math.floor(barW * frac), barY2)

	-- ── Confirm button ───────────────────────────────────────────────────────
	local btnCol
	if confirmed then
		btnCol = BTN_DONE
	elseif not mySelected then
		btnCol = BTN_DISABLED
	elseif btnHovered then
		btnCol = BTN_HOVER
	else
		btnCol = BTN_READY
	end

	glColor(btnCol[1], btnCol[2], btnCol[3], btnCol[4])
	RectRound(btnX1, btnY1, btnX2, btnY2, btnCorner)

	local btnLabelSz = math.floor(14 * widgetScale)
	local btnLabelY  = btnY1 + math.floor((btnY2 - btnY1 - btnLabelSz) * 0.5)
	local btnCx      = math.floor((btnX1 + btnX2) / 2)
	local btnLabel   = confirmed and "Confirmed!" or "Confirm Position"
	font:Begin()
	font:SetTextColor(1, 1, 1, (confirmed or mySelected) and 1.0 or 0.45)
	font:Print(btnLabel, btnCx, btnLabelY, btnLabelSz, "con")
	font:End()
end

--------------------------------------------------------------------------------
-- Widget lifecycle
--------------------------------------------------------------------------------

function widget:Initialize()
	-- Resolve the shapes module now that every widget has been constructed.
	BindDrawing()

	isSpectator   = Spring.GetSpectatingState()
	myTeamID      = Spring.GetMyTeamID()
	myAllyTeamID  = Spring.GetMyAllyTeamID()
	LoadWidgetFont()
	RecalculateGeometry()

	if WG.StaticLayout then
		WG.StaticLayout.Register(LAYOUT_ID, {
			label  = "Placement Panel",
			onMove = function() RecalculateGeometry() end,
			isVisible = function() return active end,
		})
	end
end

function widget:Shutdown()
	-- Safety net: whatever path removes this widget (phase end, deadline,
	-- luaui reload, manual disable), the rest of the UI must come back.
	SetUIHidden(false)
	if WG.StaticLayout then WG.StaticLayout.Unregister(LAYOUT_ID) end
	if font then ReleaseFont(font); font = nil end
end

function widget:ViewResize()
	vsx, vsy = spGetViewGeometry()
	if font then ReleaseFont(font) end
	LoadWidgetFont()
	RecalculateGeometry()
end

function widget:GameStart()
	isSpectator = Spring.GetSpectatingState()
end

--------------------------------------------------------------------------------
-- Update
--------------------------------------------------------------------------------

local lastHoveredSpot = nil

function widget:Update()
	if not gameStarted then
		if Spring.GetGameFrame() > 0 then gameStarted = true end
		return
	end

	-- Poll phase
	local newPhase = spGetGameRulesParam("phase")
	if newPhase == nil then return end  -- gadget not initialised yet

	-- Keep the rest of the UI hidden for the whole pregame flow (faction pick
	-- included) and bring it back the moment the flow is over.  This runs
	-- before the early-outs below so the "faction" phase is covered too.
	SetUIHidden(newPhase == "faction" or newPhase == "placement")

	if newPhase ~= "placement" then
		-- Once the placement phase has ended, remove this widget
		if active then
			widgetHandler:RemoveWidget(self)
		end
		phase = newPhase
		return
	end

	-- First frame of placement phase: load spot data
	if not active then
		active = true
		phase  = "placement"
		LoadSpots()
		RecalculateGeometry()
	end

	-- Deadline (may shrink when all confirm)
	local deadlineFrame = spGetGameRulesParam("placementDeadlineFrame") or 0
	local frame         = Spring.GetGameFrame()
	local framesLeft    = math.max(0, deadlineFrame - frame)
	local gameSpeed     = Spring.GetGameSpeed() or 1
	secondsLeft         = math.ceil(framesLeft / (30 * gameSpeed))

	-- Tick sound
	if secondsLeft <= COUNTDOWN_BEEP_AT and secondsLeft ~= lastBeepSecond and secondsLeft > 0 then
		spPlaySoundFile("hover", 0.6, "ui")
		lastBeepSecond = secondsLeft
	end

	-- Poll server state (server acknowledges our spot selection)
	UpdateServerState()
	UpdateClaimCache()
	UpdateSpotScreenPositions()

	-- Hovered spot (for hover sound dedup)
	local mx, my = spGetMouseState()
	local ms     = math.floor(MARKER_SIZE * widgetScale)
	hoveredSpot  = nil
	for i, sc in pairs(spotScreen) do
		if sc.visible then
			if math.abs(mx - sc.sx) <= ms and math.abs(my - sc.sy) <= ms then
				hoveredSpot = i
				break
			end
		end
	end
	-- Minimap hover: highlights the spot on both the minimap and world markers
	if not hoveredSpot then
		hoveredSpot = MinimapPickSpot(mx, my)
	end

	if hoveredSpot ~= lastHoveredSpot then
		if hoveredSpot then PlayHoverSound() end
		lastHoveredSpot = hoveredSpot
	end

	-- Button hover
	btnHovered = IsOnRect(mx, my, btnX1, btnY1, btnX2, btnY2)

	-- Remove once the phase is done
	if framesLeft == 0 then
		widgetHandler:RemoveWidget(self)
	end
end

--------------------------------------------------------------------------------
-- Input
--------------------------------------------------------------------------------

function widget:MousePress(x, y, button)
	if not active or not gameStarted then return false end
	if button ~= 1 then return false end

	-- Consume clicks on the panel area
	if IsOnRect(x, y, panelX1, panelY1, panelX2, panelY2) then
		return true
	end

	-- Consume clicks on spot markers
	if not confirmed and not isSpectator then
		local ms = math.floor(MARKER_SIZE * widgetScale)
		for i, sc in pairs(spotScreen) do
			if sc.visible and math.abs(x - sc.sx) <= ms and math.abs(y - sc.sy) <= ms then
				if SpotOnMySide(i) then
					return true
				end
			end
		end

		-- Consume clicks on minimap spot markers (so the minimap doesn't also
		-- treat the click as a camera move).  Clicks elsewhere on the minimap
		-- fall through and pan the camera as usual.
		local mmSpot = MinimapPickSpot(x, y)
		if mmSpot and SpotOnMySide(mmSpot) then
			return true
		end
	end

	return false
end

function widget:MouseRelease(x, y, button)
	if not active or not gameStarted then return false end
	if isSpectator then return false end
	if button ~= 1 then return false end

	-- Confirm button
	if IsOnRect(x, y, btnX1, btnY1, btnX2, btnY2) then
		if not confirmed and mySelected then
			PlayClickSound()
			spSendLuaRulesMsg(CONFIRM_BYTE)
			confirmed = true
		end
		return true
	end

	-- Spot marker click (world view)
	if not confirmed then
		local ms = math.floor(MARKER_SIZE * widgetScale)
		for i, sc in pairs(spotScreen) do
			if sc.visible and math.abs(x - sc.sx) <= ms and math.abs(y - sc.sy) <= ms then
				if SpotOnMySide(i) then
					TrySelectSpot(i)
					return true
				end
			end
		end

		-- Spot marker click (minimap)
		local mmSpot = MinimapPickSpot(x, y)
		if mmSpot and SpotOnMySide(mmSpot) then
			TrySelectSpot(mmSpot)
			return true
		end
	end

	return false
end

--------------------------------------------------------------------------------
-- Draw
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Minimap markers
--
-- Raw immediate-mode gl on purpose: the shapes module batches into a
-- screen-space pass, and instances queued while the minimap transform is
-- active would flush in the wrong coordinate space.  A dozen quads is
-- nothing, so the legacy path is the correct one here.
--------------------------------------------------------------------------------

function widget:DrawInMiniMap(sx, sy)
	if not active or not gameStarted then return end

	local ms = math.max(4, math.floor(MMARK_SIZE * widgetScale))

	for i, spot in pairs(spots) do
		local px, py = WorldToMinimapPx(spot.x, spot.z, sx, sy)
		local mine   = claimMine[i]
		local count  = claimCount[i] or 0
		local mySide = isFFA or spot.allyteam == myAllyTeamID

		-- Same state logic as the world markers in DrawSpots()
		local col
		if myConfirmed and myConfirmed == i then
			col = COL_CONFIRMED
			-- Outer ring, same treatment as the world marker
			local r = ms + math.max(2, math.floor(ms * 0.35))
			rawColor(COL_CONFIRMED[1], COL_CONFIRMED[2], COL_CONFIRMED[3], 0.55)
			rawRect(px - r, py - r, px + r, py + r)
		elseif mine then
			col = COL_SELECTED
		elseif count > 0 then
			if mySide and shareMode and hoveredSpot == i then
				col = COL_AVAILABLE_H
			else
				col = COL_TEAMMATE
			end
		elseif mySide then
			col = (hoveredSpot == i) and COL_AVAILABLE_H or COL_AVAILABLE
		else
			col = COL_ENEMY
		end

		rawColor(col[1], col[2], col[3], col[4])
		rawRect(px - ms, py - ms, px + ms, py + ms)

		local inr = math.max(1, math.floor(ms * 0.3))
		rawColor(COL_INNER[1], COL_INNER[2], COL_INNER[3], COL_INNER[4])
		rawRect(px - ms + inr, py - ms + inr, px + ms - inr, py + ms - inr)
	end

	-- Index labels, so "Spot 3 selected" in the panel maps onto the minimap
	-- too.  Safe with the wrapped font: nothing is batched at this point in
	-- the frame, so the Begin/End flushes are no-ops.
	if font and ms >= 7 then
		local lsz = math.floor(ms * 1.15)
		font:Begin()
		for i, spot in pairs(spots) do
			local px, py = WorldToMinimapPx(spot.x, spot.z, sx, sy)
			font:Print(TEXT_COLOR .. i, px, py - math.floor(lsz * 0.35), lsz, "con")
		end
		font:End()
	end
end

function widget:DrawScreen()
	if not active or not gameStarted then return end

	DrawSpots()
	DrawPanel()

	-- Hand the accumulated shape instances to the GPU.
	Flush()
end
