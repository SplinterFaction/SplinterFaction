--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Survival panel of the RmlUi HUD.
--
--  In a Survival AI game: the countdown to the next wave, the wave number and
--  the kind of wave it is and of the one coming, the beacon network and its
--  regrowth, the survival teams' upgrades (a row for each team when there are
--  several), how full the field is, and a line for rage, an incoming surge or
--  preparation. Everything is read from the game rules params the Survival
--  gadget publishes; in any other game the widget removes itself.
--
--  Drag the panel to move it.
--
--  Replaces gui_static_survivalpanel.lua (kept in Widgets/disabled/).
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name    = "Survival Panel",
		desc    = "Wave countdown, threat type, beacons, surge/rage warnings for Survival AI games. Drag to move. (RmlUi)",
		author  = "SplinterFaction Team",
		date    = "2026-10-12",
		license = "GNU GPL, v2 or later",
		layer   = 1000,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- config
--------------------------------------------------------------------------------

local DOCUMENT_PATH   = "LuaUI/rml/survival.rml"
local UPDATE_INTERVAL = 0.1

-- must match survival.rml (all in dp)
local PANEL_WIDTH = 190
local CHROME      = 18  -- borders and padding, top and bottom
local TITLE       = 20
local COUNTDOWN   = 34
local LINE        = 18
local STATUS      = 20
local FIXED_LINES = 5   -- wave, next, beacons, regrowth, pressure

local EDGE_MARGIN = 12

local LAYOUT_NAME = "survivalpanel" -- same as the old widget, so a saved position carries over

local POLL_PERIOD  = 15   -- frames between reads of the gadget's rules params
local GIVEUP_FRAME = 450  -- no survival gadget by now: this is not a survival game
local GAME_SPEED   = 30

local KINDS = {assault = true, raid = true, siege = true, air = true, drop = true, horde = true}

-- pressure bar: from an empty field to a field at its cap
local BAR_LOW  = {0.45, 0.75, 0.45}
local BAR_HIGH = {0.90, 0.22, 0.22}

--------------------------------------------------------------------------------
-- locals
--------------------------------------------------------------------------------

local spGetGameRulesParam = Spring.GetGameRulesParam
local spGetGameFrame      = Spring.GetGameFrame
local spGetMouseState     = Spring.GetMouseState

local floor, max, min, sin = math.floor, math.max, math.min, math.sin

local hud
local document
local view
local lastUpdate

local visible = true   -- the player's choice (WG.StaticSurvivalPanel.Toggle), kept across sessions
local active  = false  -- has the Survival gadget announced itself?

-- what the gadget last said
local waveNumber    = 0
local waveType
local nextWaveFrame
local nextSurge     = false
local beaconCount   = 0
local beaconMax     = 0
local rageCount     = 0
local nextType            -- kind of the wave the countdown is for
local respawnFrame  = 0   -- 0 = network at full strength (no regrowth pending)
local pressure      = 0   -- 0..100, live wave metal against the field cap
local weaponsLevel  = 0   -- survival team upgrade levels (highest across
local armorLevel    = 0   -- survival teams when there are several)

local teamCount = 0
local teams     = {}      -- [slot] = {id, beacons, beaconsMax, weapons, armor, state, r, g, b}

local teamsMarkup         -- the team rows' markup, as last set
local shownHeight
local panelRect           -- {x, y, w, h} in screen pixels, y up
local drag                -- {dx, dy} while the panel is being dragged
local draggedTo           -- where it was dropped, when there is no layout module to remember it

--------------------------------------------------------------------------------
-- placement: the panel is as tall as its rows
--------------------------------------------------------------------------------

local function TeamRows()
	return (teamCount >= 2) and teamCount or 1
end

local function PanelHeight()
	return CHROME + TITLE + COUNTDOWN + LINE * (FIXED_LINES + TeamRows()) + STATUS
end

local function DefaultOrigin(vsx, vsy, w, h, scale)
	if draggedTo then
		return draggedTo[1], draggedTo[2]
	end
	return vsx - w - EDGE_MARGIN * scale, vsy * 0.55
end

local function Place()
	local height = PanelHeight()
	if height ~= shownHeight then
		shownHeight = height
		view.Element("survival").style["height"] = height .. "dp"
	end
	local x, y, w, h = hud.PlacePanel(view.Element("survival"), LAYOUT_NAME, PANEL_WIDTH, height, DefaultOrigin)
	panelRect = x and {x, y, w, h}
end

--------------------------------------------------------------------------------
-- refreshing
--------------------------------------------------------------------------------

local function FormatTime(seconds)
	seconds = max(0, floor(seconds))
	return string.format("%d:%02d", floor(seconds / 60), seconds % 60)
end

local function ShowKind(id, kind)
	view.SetText(id, kind and hud.Escape(string.upper(kind)) or "")
	for name in pairs(KINDS) do
		view.SetClass(id, name, kind == name)
	end
end

local function TeamsRML()
	if teamCount < 2 then
		return '<div class="line"><div class="label">Upgrades</div><div class="grow"/><div id="upgrades" class="fig"/></div>'
	end
	-- a row for each survival team, named in its team color
	local parts = {}
	for i = 1, teamCount do
		local t = teams[i] or {}
		parts[i] = string.format(
			'<div class="line"><div id="team%d-name" class="label" style="color: %s;">Team %s</div><div class="grow"/><div id="team%d" class="fig"/></div>',
			i, hud.ReadableColor(t.r, t.g, t.b), hud.Escape(tostring(t.id)), i)
	end
	return table.concat(parts)
end

local function Refresh()
	local show = visible and active
	view.SetClass("survival", "hidden", not show)
	if not show then
		return
	end
	local frame = spGetGameFrame()
	-- surges and rage pulse
	local pulse = string.format("%.2f", floor((0.55 + 0.45 * sin(os.clock() * 5)) * 20 + 0.5) / 20)

	-- countdown
	local seconds = nextWaveFrame and ((nextWaveFrame - frame) / GAME_SPEED)
	view.SetText("count", seconds and FormatTime(seconds) or "--:--")
	view.SetClass("count", "none", not seconds)
	view.SetClass("count", "surge", seconds ~= nil and nextSurge)
	view.SetClass("count", "urgent", seconds ~= nil and not nextSurge and seconds <= 10)
	view.SetStyle("count", "opacity", (seconds and nextSurge) and pulse or "1")

	view.SetText("wave-number", tostring(waveNumber))
	ShowKind("wave-kind", waveType)
	ShowKind("next-kind", nextType)
	view.SetStyle("next-kind", "opacity", nextSurge and pulse or "1")

	-- beacons: live / full network
	view.SetText("beacons", (beaconMax > 0) and (beaconCount .. " / " .. beaconMax) or tostring(beaconCount))

	-- regrowth, only while the network is below full strength
	local regrowing = respawnFrame > 0
	view.SetText("regrow", regrowing and FormatTime((respawnFrame - frame) / GAME_SPEED) or "--")
	view.SetClass("regrow", "running", regrowing)
	view.SetClass("regrow", "off", not regrowing)

	-- upgrades, or the teams
	local markup = TeamsRML()
	if markup ~= teamsMarkup then
		teamsMarkup = markup
		view.Element("teams").inner_rml = markup
		view.Forget()
	end
	if teamCount < 2 then
		view.SetText("upgrades", "W" .. weaponsLevel .. "  A" .. armorLevel)
		view.SetClass("upgrades", "off", weaponsLevel <= 0 and armorLevel <= 0)
	else
		for i = 1, teamCount do
			local t = teams[i]
			if t then
				local id = "team" .. i
				local defeated, raging = t.state == 2, t.state == 1
				view.SetText(id, defeated and "DEFEATED"
					or (t.beacons .. "/" .. t.beaconsMax .. "  W" .. t.weapons .. "  A" .. t.armor))
				view.SetClass(id, "defeated", defeated)
				view.SetClass(id .. "-name", "defeated", defeated)
				view.SetClass(id, "rage", raging)
				view.SetStyle(id, "opacity", raging and pulse or "1")
			end
		end
	end

	-- pressure: how full the field is against its cap
	local fraction = max(0, min(1, pressure / 100))
	view.SetStyle("pressure-fill", "width", string.format("%d%%", floor(fraction * 100 + 0.5)))
	view.SetStyle("pressure-fill", "background-color", hud.Rgb(
		BAR_LOW[1] + (BAR_HIGH[1] - BAR_LOW[1]) * fraction,
		BAR_LOW[2] + (BAR_HIGH[2] - BAR_LOW[2]) * fraction,
		BAR_LOW[3] + (BAR_HIGH[3] - BAR_LOW[3]) * fraction))

	-- status line: rage > surge > preparing
	local status = (rageCount > 0 and "rage") or (nextSurge and "surge") or (not nextWaveFrame and "prep") or nil
	view.SetText("status", (status == "rage" and "RAGE MODE") or (status == "surge" and "SURGE INCOMING")
		or (status == "prep" and "PREPARING") or "")
	view.SetClass("status", "rage", status == "rage")
	view.SetClass("status", "surge", status == "surge")
	view.SetClass("status", "prep", status == "prep")
	view.SetStyle("status", "opacity", (status == "rage" or status == "surge") and pulse or "1")
end

--------------------------------------------------------------------------------
-- reading the gadget
--------------------------------------------------------------------------------

local function Poll()
	waveNumber    = (spGetGameRulesParam("survival_waveNumber")) or 0
	waveType      = (spGetGameRulesParam("survival_waveType"))
	nextWaveFrame = (spGetGameRulesParam("survival_nextWaveFrame"))
	nextSurge     = (spGetGameRulesParam("survival_nextWaveSurge")) == 1
	beaconCount   = (spGetGameRulesParam("survival_beacons")) or 0
	beaconMax     = (spGetGameRulesParam("survival_beaconsMax")) or 0
	rageCount     = (spGetGameRulesParam("survival_rage")) or 0
	nextType      = (spGetGameRulesParam("survival_nextWaveType"))
	respawnFrame  = (spGetGameRulesParam("survival_respawnFrame")) or 0
	pressure      = (spGetGameRulesParam("survival_pressure")) or 0
	weaponsLevel  = (spGetGameRulesParam("survival_weaponsLevel")) or 0
	armorLevel    = (spGetGameRulesParam("survival_armorLevel")) or 0

	local count = (spGetGameRulesParam("survival_teamCount")) or 0
	for i = 1, count do
		local t = teams[i]
		if not t then
			t = {}
			teams[i] = t
		end
		local key = "survival_team" .. i
		local id  = (spGetGameRulesParam(key .. "ID"))
		if id ~= t.id then
			t.id = id
			t.r, t.g, t.b = 1, 1, 1
			if id then
				local r, g, b = Spring.GetTeamColor(id)
				if r then
					t.r, t.g, t.b = r, g, b
				end
			end
		end
		t.beacons    = (spGetGameRulesParam(key .. "Beacons")) or 0
		t.beaconsMax = (spGetGameRulesParam(key .. "BeaconsMax")) or 0
		t.weapons    = (spGetGameRulesParam(key .. "Weapons")) or 0
		t.armor      = (spGetGameRulesParam(key .. "Armor")) or 0
		t.state      = (spGetGameRulesParam(key .. "State")) or 0
	end
	if count ~= teamCount then
		teamCount = count
		Place() -- the panel grows by one row for each extra team
	end
end

--------------------------------------------------------------------------------
-- dragging
--------------------------------------------------------------------------------

local function MoveToMouse()
	local mx, my = spGetMouseState()
	local vsx, vsy = Spring.GetViewGeometry()
	local x = max(0, min(mx - drag.dx, vsx - panelRect[3]))
	local y = max(0, min(my - drag.dy, vsy - panelRect[4]))
	panelRect[1], panelRect[2] = x, y
	local element = view.Element("survival")
	element.style["left"] = string.format("%dpx", x)
	element.style["top"] = string.format("%dpx", vsy - (y + panelRect[4]))
	return x, y
end

-- the button came back up (see hud.OnDrag): the panel stays where it is now
local function Drop()
	if not drag then
		return
	end
	local x, y = MoveToMouse()
	drag = nil
	-- The layout module keeps the position, so that it persists and is
	-- worked out per resolution alongside every other panel.
	local layout = WG.StaticLayout
	if layout and layout.Set then
		layout.Set(LAYOUT_NAME, x, y)
	else
		draggedTo = {x, y}
	end
	Place()
end

--------------------------------------------------------------------------------
-- widget api
--------------------------------------------------------------------------------

function widget:Initialize()
	local helpers = include("rml/hud.lua")
	local result, reason = helpers.LoadDocument(DOCUMENT_PATH, widget)
	if not result then
		Spring.Echo("[Survival Panel] " .. tostring(reason))
		widgetHandler:RemoveWidget()
		return
	end
	hud = helpers
	document = result

	view = hud.NewView(document)
	view.Assume("survival", "hidden", true) -- set in the markup

	hud.OnDrag(view, "survival", function()
		if panelRect then
			local mx, my = spGetMouseState()
			drag = {dx = mx - panelRect[1], dy = my - panelRect[2]}
		end
	end, Drop)

	WG.StaticSurvivalPanel = {
		Toggle = function()
			visible = not visible
			if document then
				Refresh()
			end
		end,
	}

	hud.RegisterPanel(LAYOUT_NAME, "Survival Panel", Place, function() return visible and active end)
	Place()

	-- after a LuaUI reload mid-game the gadget has long since announced itself
	if (spGetGameRulesParam("survival_active")) == 1 then
		active = true
		Poll()
	end
	Refresh()
	hud.ShowPassive(document)
	lastUpdate = Spring.GetTimer()
end

function widget:Shutdown()
	WG.StaticSurvivalPanel = nil
	if hud then
		hud.UnregisterPanel(LAYOUT_NAME)
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
	end
end

-- the position lives in the layout module; only the visibility is kept here
function widget:GetConfigData()
	return {visible = visible}
end

function widget:SetConfigData(data)
	if data and data.visible ~= nil then
		visible = data.visible
	end
end

function widget:GameFrame(n)
	if not document or n % POLL_PERIOD ~= 0 then
		return
	end
	if not active then
		if (spGetGameRulesParam("survival_active")) == 1 then
			active = true
		elseif n > GIVEUP_FRAME then
			widgetHandler:RemoveWidget() -- not a survival game
		end
		return
	end
	Poll()
end

function widget:Update()
	if not document then
		return
	end
	if hud.FollowGuiHidden(document) then
		drag = nil
		return -- hidden with the rest of the GUI (F5)
	end
	if drag then
		MoveToMouse()
		return
	end
	local now = Spring.GetTimer()
	if Spring.DiffTimers(now, lastUpdate) >= UPDATE_INTERVAL then
		lastUpdate = now
		Refresh()
	end
end
