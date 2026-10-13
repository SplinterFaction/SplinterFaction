--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Start placement of the RmlUi HUD: after the faction choice, each player
--  picks a start spot and confirms it.
--
--  The map's spots are shown as numbered markers over the ground and again on
--  the minimap; both can be clicked. A panel at the bottom says what to do,
--  counts down, and holds the confirm button. The markers over the ground and
--  the panel are RmlUi; the minimap markers are drawn with gl inside the
--  engine's minimap, where RmlUi cannot draw.
--
--  This widget also hides the rest of the interface for the whole pregame flow
--  (the faction phase included); see "pregame UI hiding" below.
--
--  Phase protocol (game rules params written by game_spawn.lua):
--    "phase"                  "faction" | "placement" | "done"
--    "placementDeadlineFrame"  frame number of the placement deadline
--    "spotCount"               total number of spots
--    "isFFA"                   1 = all spots open to all, 0 = sided
--    "spot_N_x"                world X for spot N (1-based)
--    "spot_N_z"                world Z for spot N
--    "spot_N_at"               allyteam owner (-1 = all in FFA)
--    "spotclaim_N"             teamID that claimed spot N, or -1
--
--  Messages sent to the game_spawn gadget with SendLuaRulesMsg:
--    "\139" .. spotIdx         tentative spot selection
--    "\140"                    confirm placement
--
--  Replaces gui_static_placement.lua (kept in Widgets/disabled/). The reading
--  of the game's state and the minimap picking are carried over unchanged.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name    = "Start Placement",
		desc    = "Pregame start position choice (RmlUi)",
		author  = "SplinterFaction Team",
		date    = "2026-10-13",
		license = "GNU GPL, v2 or later",
		layer   = 1900, -- below the faction chooser (2000), above everything else
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- config
--------------------------------------------------------------------------------

local DOCUMENT_PATH = "LuaUI/rml/placement.rml"

-- must match game_spawn.lua
local SELECT_BYTE  = "\139"
local CONFIRM_BYTE = "\140"

-- must match #placement in placement.rml
local PANEL_WIDTH  = 560
local PANEL_HEIGHT = 96
local PANEL_BOTTOM = 28 -- gap to the bottom of the screen

local MARKER_SIZE = 56 -- must match .spot in placement.rml

local MMARK_SIZE     = 8    -- half-size of a minimap marker, in dp
local MMARK_PICK_PAD = 1.75 -- click and hover reach on the minimap, as a multiple of that

local COUNTDOWN_BEEP_AT = 10
local PLACEMENT_SECONDS = 30 -- seconds the full bar stands for

local LAYOUT_ID = "placement" -- same as the old widget, so a saved position carries over

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
--
-- That covers what is drawn with gl. The RmlUi panels are not drawn from a
-- call-in, so they are told through WG.HudPregame instead: each hides its
-- document while that is set (hud.FollowGuiHidden). The windows a player
-- opens on purpose (game menu, options, keybinds, widget list) stay usable.
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
-- minimap marker colors, by the same states as the markers over the ground
--------------------------------------------------------------------------------

local MINIMAP_COLOR = {
	free = {0.31, 0.74, 0.42, 0.95},
	hot  = {0.61, 0.94, 0.69, 1.00},
	mine = {0.37, 0.82, 0.91, 1.00},
	done = {0.44, 0.86, 0.55, 1.00},
	mate = {0.52, 0.58, 0.63, 0.80},
	foe  = {1.00, 0.35, 0.31, 0.45},
}
local MINIMAP_INNER = {0.02, 0.03, 0.04, 0.80}

--------------------------------------------------------------------------------
-- speedups and state
--------------------------------------------------------------------------------

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

local hud
local document
local view

local vsx, vsy    = spGetViewGeometry()
local widgetScale = 1             -- pixels per dp
local active      = false         -- true once the placement phase has begun
local gameStarted = false

local myTeamID     = Spring.GetMyTeamID()
local myAllyTeamID = Spring.GetMyAllyTeamID()
local isSpectator  = false
local isFFA        = false

local spots     = {}   -- i -> {x, z, allyteam}
local spotCount = 0

local claimCount   = {}   -- i -> number of allied teams claiming spot i (0/nil = none visible)
local claimMine    = {}   -- i -> true if my own team claims spot i
local hoveredSpot  = nil  -- index or nil; under the mouse over the ground or on the minimap
local markerHover  = nil  -- index of the ground marker under the mouse (told by RmlUi)
local lastHoveredSpot = nil
local mySelected   = nil  -- server-acknowledged selected spot index
local myConfirmed  = nil  -- server-acknowledged confirmed spot index
local localPending = nil  -- local pending index (waiting for server ack)
local shareMode    = false -- true when no free same-side spots remain (overflow)
local confirmed    = false -- the player has confirmed a spot

local secondsLeft    = PLACEMENT_SECONDS
local lastBeepSecond = nil

-- a plain gl font for the numbers on the minimap markers
local minimapFont

local function PlayHoverSound()  spPlaySoundFile("hover",     1.0, "ui") end
local function PlayClickSound()  spPlaySoundFile("leftclick", 1.0, "ui") end

--------------------------------------------------------------------------------
-- the game's state (carried over)
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
-- minimap (carried over)
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
-- pregame UI hiding (carried over, plus the WG.HudPregame flag)
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
	-- the RmlUi panels have no draw call-in to strip: they hide themselves
	-- while this is set (hud.FollowGuiHidden)
	WG.HudPregame = hide or nil
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
-- showing
--------------------------------------------------------------------------------

-- What a spot is to the local player: "done", "mine", "mate", "free" or
-- "foe", and whether it is lit by the mouse. Shared by the markers over the
-- ground and the ones on the minimap.
local function SpotState(i)
	local spot   = spots[i]
	local count  = claimCount[i] or 0
	local mySide = isFFA or spot.allyteam == myAllyTeamID
	local hot    = (hoveredSpot == i)
	if myConfirmed and myConfirmed == i then
		return "done", false
	elseif claimMine[i] then
		return "mine", false
	elseif count > 0 then
		-- Taken by a teammate. In share mode it is still a valid target
		-- (overflow players may stack onto it), so it lights up.
		return "mate", hot and mySide and shareMode
	elseif mySide then
		return "free", hot
	end
	-- the other side's: shown for reference, no claim state revealed
	return "foe", false
end

local STATES = {"done", "mine", "mate", "free", "foe"}

local function SpotsRML()
	local parts = {}
	for i = 1, spotCount do
		if spots[i] then
			parts[#parts + 1] = string.format(
				'<div id="s%d" class="spot hidden" data-spot="%d">%d<div id="s%d-ring" class="ring hidden"/><div id="s%d-n" class="count hidden"/></div>',
				i, i, i, i, i)
		end
	end
	return table.concat(parts)
end

local function RefreshSpots()
	local canPick = not confirmed and not isSpectator
	local margin = MARKER_SIZE * widgetScale
	for i, spot in pairs(spots) do
		local id = "s" .. i
		local gy = spGetGroundHeight(spot.x, spot.z) or 0
		local sx, sy = spWorldToScreenCoords(spot.x, gy + 8, spot.z)
		local visible = sx and sx > -margin and sx < vsx + margin and sy > -margin and sy < vsy + margin
		view.SetClass(id, "hidden", not visible)
		if visible then
			view.SetStyle(id, "left", math.floor(sx) .. "px")
			view.SetStyle(id, "top", math.floor(vsy - sy) .. "px")
			local state, hot = SpotState(i)
			for _, name in ipairs(STATES) do
				view.SetClass(id, name, state == name)
			end
			view.SetClass(id, "hot", hot)
			view.SetClass(id, "can", canPick and SpotSelectable(i))
			view.SetClass(id .. "-ring", "hidden", state ~= "done")
			local count = claimCount[i] or 0
			view.SetClass(id .. "-n", "hidden", count < 2)
			if count >= 2 then
				view.SetText(id .. "-n", "x" .. count)
			end
		end
	end
end

local function RefreshPanel()
	local title, quiet
	if isSpectator then
		title = "Players are choosing start positions"
	elseif confirmed then
		title = "Waiting for others..."
	elseif mySelected then
		title = "Spot " .. mySelected .. " selected. Confirm when ready."
	elseif shareMode then
		-- more players than spots on this side: all are taken, so one may
		-- be shared
		title = "All spots on your side are taken. Click one to share it."
	else
		title, quiet = "Click a highlighted spot to select it", true
	end
	view.SetText("title", title)
	view.SetClass("title", "quiet", quiet)

	local urgent = secondsLeft <= COUNTDOWN_BEEP_AT
	view.SetText("timer", secondsLeft .. "s")
	view.SetClass("timer", "urgent", urgent)
	view.SetClass("timer-fill", "urgent", urgent)
	local fraction = math.max(0, math.min(1, secondsLeft / PLACEMENT_SECONDS))
	view.SetStyle("timer-fill", "width", string.format("%.1f%%", fraction * 100))

	view.SetClass("confirm", "hidden", isSpectator)
	view.SetClass("confirm", "done", confirmed)
	view.SetClass("confirm", "disabled", not confirmed and not mySelected)
	view.SetText("confirm", confirmed and "Confirmed" or "Confirm")
end

local function Refresh()
	view.SetClass("root", "hidden", not active)
	if active then
		RefreshSpots()
		RefreshPanel()
	end
end

--------------------------------------------------------------------------------
-- widget api
--------------------------------------------------------------------------------

local function DefaultOrigin(sizeX, sizeY, w, h, scale)
	return (sizeX - w) * 0.5, PANEL_BOTTOM * scale
end

local function Place()
	vsx, vsy = spGetViewGeometry()
	widgetScale = hud.GetScale()
	hud.PlacePanel(view.Element("placement"), LAYOUT_ID, PANEL_WIDTH, PANEL_HEIGHT, DefaultOrigin)
end

local function LoadMinimapFont()
	if minimapFont then
		gl.DeleteFont(minimapFont)
	end
	local file = LUAUI_DIRNAME .. "fonts/" .. Spring.GetConfigString("ui_font", "Saira_SemiCondensed-SemiBold.ttf")
	local scale = 0.5 + (vsx * vsy / 5700000)
	minimapFont = gl.LoadFont(file, 25 * scale, 4.5 * scale, 1.8)
end

function widget:Initialize()
	local helpers = include("rml/hud.lua")
	local result, reason = helpers.LoadDocument(DOCUMENT_PATH, widget)
	if not result then
		Spring.Echo("[Start Placement] " .. tostring(reason))
		widgetHandler:RemoveWidget(self)
		return
	end
	hud = helpers
	document = result

	isSpectator  = Spring.GetSpectatingState()
	myTeamID     = Spring.GetMyTeamID()
	myAllyTeamID = Spring.GetMyAllyTeamID()

	view = hud.NewView(document)
	view.Assume("root", "hidden", true) -- set in the markup

	-- the markers over the ground
	local container = view.Element("spots")
	container:AddEventListener("mousedown", function(event)
		local i = hud.EventAttribute(event, "data-spot")
		if i and active and not confirmed and not isSpectator
			and event.parameters and event.parameters.button == 0 then
			TrySelectSpot(i)
		end
	end)
	container:AddEventListener("mouseover", function(event)
		markerHover = hud.EventAttribute(event, "data-spot")
	end)
	container:AddEventListener("mouseout", function()
		markerHover = nil
	end)

	hud.OnClick(view, "confirm", function()
		if active and not isSpectator and not confirmed and mySelected then
			PlayClickSound()
			spSendLuaRulesMsg(CONFIRM_BYTE)
			confirmed = true
			Refresh()
		end
	end)

	hud.RegisterPanel(LAYOUT_ID, "Placement Panel", Place, function() return active end)
	Place()
	LoadMinimapFont()
	hud.ShowPassive(document)
end

function widget:Shutdown()
	-- Safety net: whatever path removes this widget (phase end, deadline,
	-- luaui reload, manual disable), the rest of the UI must come back.
	SetUIHidden(false)
	WG.HudPregame = nil
	if hud then
		hud.UnregisterPanel(LAYOUT_ID)
	end
	if minimapFont then
		gl.DeleteFont(minimapFont)
		minimapFont = nil
	end
	if document then
		document:Close()
		document = nil
	end
end

function widget:ViewResize()
	if hud and document then
		hud.UpdateScale()
		Place()
		LoadMinimapFont()
		view.ForgetStyles()
	end
end

function widget:GameStart()
	isSpectator = Spring.GetSpectatingState()
end

function widget:Update()
	if not document then
		return
	end
	if not gameStarted then
		if Spring.GetGameFrame() > 0 then gameStarted = true end
		return
	end

	local newPhase = spGetGameRulesParam("phase")
	if newPhase == nil then return end  -- gadget not initialised yet

	-- Keep the rest of the UI hidden for the whole pregame flow (faction pick
	-- included) and bring it back the moment the flow is over.  This runs
	-- before the early-outs below so the "faction" phase is covered too.
	SetUIHidden(newPhase == "faction" or newPhase == "placement")

	if newPhase ~= "placement" then
		-- once the placement phase has ended, this widget is done
		if active then
			widgetHandler:RemoveWidget(self)
		end
		return
	end

	-- first frame of the placement phase: load the spots and make a marker each
	if not active then
		active = true
		LoadSpots()
		view.Element("spots").inner_rml = SpotsRML()
		view.Forget()
		Place()
	end

	-- deadline (may shrink when all confirm)
	local deadlineFrame = spGetGameRulesParam("placementDeadlineFrame") or 0
	local frame         = Spring.GetGameFrame()
	local framesLeft    = math.max(0, deadlineFrame - frame)
	local gameSpeed     = Spring.GetGameSpeed() or 1
	secondsLeft         = math.ceil(framesLeft / (30 * gameSpeed))

	if secondsLeft <= COUNTDOWN_BEEP_AT and secondsLeft ~= lastBeepSecond and secondsLeft > 0 then
		spPlaySoundFile("hover", 0.6, "ui")
		lastBeepSecond = secondsLeft
	end

	-- the server acknowledges our selection; allies' claims change too
	UpdateServerState()
	UpdateClaimCache()

	-- The spot under the mouse: a marker over the ground (RmlUi says which),
	-- or else one on the minimap. Either lights up both.
	-- (a marker that stops taking the mouse while under it, because an ally
	-- claimed it or the player confirmed, sends no "mouseout")
	if markerHover and (confirmed or isSpectator or not spots[markerHover] or not SpotSelectable(markerHover)) then
		markerHover = nil
	end
	hoveredSpot = markerHover
	if not hoveredSpot then
		local mx, my = spGetMouseState()
		hoveredSpot = MinimapPickSpot(mx, my)
	end
	if hoveredSpot ~= lastHoveredSpot then
		if hoveredSpot then PlayHoverSound() end
		lastHoveredSpot = hoveredSpot
	end

	if framesLeft == 0 then
		widgetHandler:RemoveWidget(self)
		return
	end

	Refresh()
end

--------------------------------------------------------------------------------
-- input on the minimap. (Clicks on the markers over the ground and on the
-- panel go to RmlUi and are handled in Initialize.)
--------------------------------------------------------------------------------

-- Take the press on a minimap marker, so the minimap does not also treat it
-- as a camera move. Clicks elsewhere on the minimap fall through and pan the
-- camera as usual.
function widget:MousePress(x, y, button)
	if not active or not gameStarted then return false end
	if button ~= 1 or confirmed or isSpectator then return false end
	local mmSpot = MinimapPickSpot(x, y)
	return (mmSpot and SpotOnMySide(mmSpot)) and true or false
end

function widget:MouseRelease(x, y, button)
	if not active or not gameStarted then return false end
	if button ~= 1 or confirmed or isSpectator then return false end
	local mmSpot = MinimapPickSpot(x, y)
	if mmSpot and SpotOnMySide(mmSpot) then
		TrySelectSpot(mmSpot)
		return true
	end
	return false
end

--------------------------------------------------------------------------------
-- minimap markers
--
-- Plain gl, inside the engine's minimap: RmlUi cannot draw there. A dozen
-- quads a frame for the half minute this lasts.
--------------------------------------------------------------------------------

function widget:DrawInMiniMap(sx, sy)
	if not active or not gameStarted then return end

	local ms = math.max(4, math.floor(MMARK_SIZE * widgetScale))
	for i, spot in pairs(spots) do
		local px, py = WorldToMinimapPx(spot.x, spot.z, sx, sy)
		local state, hot = SpotState(i)
		local col = MINIMAP_COLOR[hot and "hot" or state]
		if state == "done" then
			-- outer ring, as on the marker over the ground
			local r = ms + math.max(2, math.floor(ms * 0.35))
			gl.Color(col[1], col[2], col[3], 0.55)
			gl.Rect(px - r, py - r, px + r, py + r)
		end
		gl.Color(col[1], col[2], col[3], col[4])
		gl.Rect(px - ms, py - ms, px + ms, py + ms)
		local inr = math.max(1, math.floor(ms * 0.3))
		gl.Color(MINIMAP_INNER[1], MINIMAP_INNER[2], MINIMAP_INNER[3], MINIMAP_INNER[4])
		gl.Rect(px - ms + inr, py - ms + inr, px + ms - inr, py + ms - inr)
	end
	gl.Color(1, 1, 1, 1)

	-- the numbers, so "Spot 3 selected" in the panel can be found here too
	if minimapFont and ms >= 7 then
		local lsz = math.floor(ms * 1.15)
		minimapFont:Begin()
		for i, spot in pairs(spots) do
			local px, py = WorldToMinimapPx(spot.x, spot.z, sx, sy)
			minimapFont:Print("\255\244\244\244" .. i, px, py - math.floor(lsz * 0.35), lsz, "con")
		end
		minimapFont:End()
	end
end
