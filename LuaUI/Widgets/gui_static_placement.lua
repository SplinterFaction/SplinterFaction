--------------------------------------------------------------------------------
--  file:    gui_static_placement.lua
--  brief:   Start position selection widget.  Activates after faction choice,
--           shows map spots as on-screen markers, handles selection + confirm.
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

local COUNTDOWN_BEEP_AT  = 10
local PLACEMENT_SECONDS  = 30   -- nominal total for progress bar reference

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

local glColor    = gl.Color
local glRect     = gl.Rect
local glTexture  = gl.Texture
local glTexRect  = gl.TexRect

local spGetViewGeometry   = Spring.GetViewGeometry
local spGetMouseState     = Spring.GetMouseState
local spPlaySoundFile     = Spring.PlaySoundFile
local spSendLuaRulesMsg   = Spring.SendLuaRulesMsg
local spGetGameRulesParam = Spring.GetGameRulesParam
local spGetTeamRulesParam = Spring.GetTeamRulesParam
local spWorldToScreenCoords = Spring.WorldToScreenCoords
local spGetGroundHeight   = Spring.GetGroundHeight
local spTraceScreenRay    = Spring.TraceScreenRay

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
local claimCache    = {}   -- i → teamID or -1  (from spotclaim_N rules params)
local hoveredSpot   = nil  -- index or nil
local mySelected    = nil  -- server-acknowledged selected spot index
local myConfirmed   = nil  -- server-acknowledged confirmed spot index
local localPending  = nil  -- local pending index (waiting for server ack)

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
	font = gl.LoadFont(fontfile, 25 * scale, 4.5 * scale, 1.8)
end

--------------------------------------------------------------------------------
-- Sound
--------------------------------------------------------------------------------

local function PlayHoverSound()  spPlaySoundFile("hover",     1.0, "ui") end
local function PlayClickSound()  spPlaySoundFile("leftclick", 1.0, "ui") end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function RectRound(px, py, sx, sy, cs)
	px, py, sx, sy, cs = math.floor(px), math.floor(py),
	                      math.floor(sx), math.floor(sy), math.floor(cs)
	glRect(px + cs, py, sx - cs, sy)
	glRect(sx - cs, py + cs, sx,      sy - cs)
	glRect(px,      py + cs, px + cs, sy - cs)
	glTexture(bgcorner)
	glTexRect(px,      py + cs, px + cs, py)
	glTexRect(sx,      py + cs, sx - cs, py)
	glTexRect(px,      sy - cs, px + cs, sy)
	glTexRect(sx,      sy - cs, sx - cs, sy)
	glTexture(false)
end

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

local function RecalculateGeometry()
	vsx, vsy    = spGetViewGeometry()
	widgetScale  = 0.60 + (vsx * vsy / 5000000)

	local pw  = math.floor(PANEL_W * widgetScale)
	local ph  = math.floor(PANEL_H * widgetScale)
	local pb  = math.floor(PANEL_BOTTOM * widgetScale)

	panelX1 = math.floor((vsx - pw) / 2)
	panelY1 = pb
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
	claimCache = {}
	local allyTeams = Spring.GetTeamList(myAllyTeamID) or {}
	for _, tID in ipairs(allyTeams) do
		local claimed = spGetTeamRulesParam(tID, "claimedSpot")
		if claimed and claimed ~= -1 then
			claimCache[math.floor(claimed)] = tID
		end
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
			local claim  = claimCache[i]   -- nil = unclaimed or enemy (both look the same to us)

			-- Determine marker state for this spot
			if myConfirmed and myConfirmed == i then
				DrawConfirmedRing(sx, sy)
				DrawMarker(sx, sy, COL_CONFIRMED, false)
			elseif claim == myTeamID then
				-- My tentative or confirmed selection
				DrawMarker(sx, sy, COL_SELECTED, false)
			elseif claim ~= nil then
				-- Claimed by a teammate (allied-only param, so enemies are never visible here)
				DrawMarker(sx, sy, COL_TEAMMATE, false)
			elseif isFFA or spot.allyteam == myAllyTeamID then
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
	glTexture(accentImg)
	glTexRect(panelX1 + inset, panelY2 - inset - accentH,
	          panelX2 - inset, panelY2 - inset)
	glTexture(false)

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
	isSpectator   = Spring.GetSpectatingState()
	myTeamID      = Spring.GetMyTeamID()
	myAllyTeamID  = Spring.GetMyAllyTeamID()
	LoadWidgetFont()
	RecalculateGeometry()
end

function widget:Shutdown()
	if font then gl.DeleteFont(font); font = nil end
end

function widget:ViewResize()
	vsx, vsy = spGetViewGeometry()
	if font then gl.DeleteFont(font) end
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
				local spot = spots[i]
				if spot and (isFFA or spot.allyteam == myAllyTeamID) then
					return true
				end
			end
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

	-- Spot marker click
	if not confirmed then
		local ms = math.floor(MARKER_SIZE * widgetScale)
		for i, sc in pairs(spotScreen) do
			if sc.visible and math.abs(x - sc.sx) <= ms and math.abs(y - sc.sy) <= ms then
				local spot = spots[i]
				if spot and (isFFA or spot.allyteam == myAllyTeamID) then
					-- Don't select an already-confirmed spot of another player
					local claim = claimCache[i] or -1
					if claim == -1 or claim == myTeamID then
						PlayClickSound()
						localPending = i
						spSendLuaRulesMsg(SELECT_BYTE .. i)
					end
					return true
				end
			end
		end
	end

	return false
end

--------------------------------------------------------------------------------
-- Draw
--------------------------------------------------------------------------------

function widget:DrawScreen()
	if not active or not gameStarted then return end

	DrawSpots()
	DrawPanel()
end
