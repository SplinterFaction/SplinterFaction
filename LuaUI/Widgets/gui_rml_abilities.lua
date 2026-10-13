--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Abilities panel of the RmlUi HUD: the player-cast support powers.
--
--  A column of buttons above the players list. Each shows what it costs in
--  research points, or its cooldown, or MAX once fully researched; a button
--  that cannot be used right now is dimmed and flashes red when clicked.
--  Hovering a button says what it does, beside the panel.
--
--  Scanner Sweep is targeted: click the button, then the map (right click or
--  Esc cancels). The circle on the ground is still drawn with GL, in the
--  world, where RmlUi does not reach.
--
--  Replaces gui_static_abilities.lua (kept in Widgets/disabled/).
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name    = "Abilities",
		desc    = "Player-cast support powers: scanner sweep, team upgrades, production boost (RmlUi)",
		author  = "SplinterFaction Team",
		date    = "2026-10-12",
		license = "GNU GPL, v2 or later",
		layer   = 999, -- before the game menu, so Esc cancels targeting first
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- config
--------------------------------------------------------------------------------

local DOCUMENT_PATH   = "LuaUI/rml/abilities.rml"
local UPDATE_INTERVAL = 0.1

-- must match #abilities in abilities.rml
local PANEL_WIDTH    = 300
local CHROME_HEIGHT  = 34   -- borders, padding and title
local ABILITY_HEIGHT = 46   -- one button and the gap under it

local ANCHOR_GAP      = 8   -- between the players list and this panel
local FALLBACK_MARGIN = 14  -- the players list's own margins, used when it is not running
local TIP_GAP         = 8

local LAYOUT_NAME = "abilities"

local FLASH_SECONDS = 0.35
local GAME_SPEED    = 30
local KEY_ESCAPE    = 27

--------------------------------------------------------------------------------
-- Abilities. Adding an ability = adding a table entry.
--   kind    : "target"    = click button, then click the map (msg gets " <x> <z>")
--             "instant"   = click button, fires immediately (msg sent as-is)
--             "selection" = acts on the current selection; the button only lights
--                           up while eligible units are selected, and issues
--                           `cmdID` to them via GiveOrderToUnitArray
--   costRP  : flat cost (non-levelled abilities)
--   levels  : levelled abilities -- { {cost=, mult=}, ... }; the button shows
--             "<baseLabel> <nextLevel>" until maxed. Current level is read from
--             the team rules param in levelParam (set by game_team_upgrades.lua).
--   radius  : targeting circle radius in elmos (kind == "target" only)
--   accent  : the ability's own color: the stripe on its button and, for a
--             targeted ability, the circle drawn on the ground
--------------------------------------------------------------------------------

local ABILITIES = {
	{
		kind    = "target",
		label   = "Scanner Sweep",
		accent  = {1, 0.5, 0.0, 1},   -- orange
		costRP  = 100,
		cooldownSeconds = 20,          -- mirror of the gadget value, for the fill/countdown only
		radius  = 800,
		msg     = "scanner_sweep",
		tooltip = "Reveal an area of the map for 5 seconds",
	},
	{
		kind       = "instant",
		baseLabel  = "Weapons Upgrade",
		accent     = {0.90, 0.22, 0.22, 1},   -- red
		levelParam = "upgrade_weapons_level",
		levels     = {
			{ cost = 250,  mult = 1.15 },
			{ cost = 400,  mult = 1.30 },
			{ cost = 650,  mult = 1.50 },
			{ cost = 1000, mult = 1.65 },
			{ cost = 1600, mult = 1.80 },
			{ cost = 2500, mult = 2.00 },
		},
		msg        = "team_upgrade weapons",
		track      = "weapons",
		tooltipFmt = "All your units deal +%d%% weapon damage",
		sound       = "upgrade_weapons",  -- nil to disable
		soundVolume = 1,
	},
	{
		kind       = "instant",
		baseLabel  = "Armor Upgrade",
		accent     = {0.18, 0.52, 0.98, 1},   -- blue
		levelParam = "upgrade_armor_level",
		levels     = {
			{ cost = 250,  mult = 1.15 },
			{ cost = 400,  mult = 1.30 },
			{ cost = 650,  mult = 1.50 },
			{ cost = 1000, mult = 1.65 },
			{ cost = 1600, mult = 1.80 },
			{ cost = 2500, mult = 2.00 },
		},
		msg        = "team_upgrade armor",
		track      = "armor",
		tooltipFmt = "All your units gain +%d%% hull and shields",
		sound       = "upgrade_armor",  -- nil to disable
		soundVolume = 1,
	},
	{
		kind    = "selection",
		label   = "Production Boost (x5)",
		accent  = {0.25, 0.82, 0.35, 1},   -- green
		cmdID   = 35410,                   -- CMD_BUILD_BOOST (unit_research_buildboost.lua)
		tooltip = "Select builders to boost their production by x5 for 20 seconds",
		sound       = "production_boost",                 -- e.g. "upgrade_weapons"; nil to disable
		soundVolume = 1,
	},
}

local RP_RULES_PARAM = "researchPoints"

--------------------------------------------------------------------------------
-- locals
--------------------------------------------------------------------------------

local spGetSpectatingState   = Spring.GetSpectatingState
local spGetMyTeamID          = Spring.GetMyTeamID
local spGetTeamRulesParam    = Spring.GetTeamRulesParam
local spGetUnitRulesParam    = Spring.GetUnitRulesParam
local spGetUnitDefID         = Spring.GetUnitDefID
local spGetSelectedUnits     = Spring.GetSelectedUnits
local spGetGameFrame         = Spring.GetGameFrame
local spGetMouseState        = Spring.GetMouseState
local spTraceScreenRay       = Spring.TraceScreenRay
local spSendLuaRulesMsg      = Spring.SendLuaRulesMsg
local spPlaySoundFile        = Spring.PlaySoundFile

local floor = math.floor
local ceil = math.ceil

local hud
local document
local view
local lastUpdate

local isSpec   = spGetSpectatingState()
local myTeamID = spGetMyTeamID()

local targetingIndex   -- ability whose target is being placed, or nil
local hoverIndex       -- ability under the mouse, or nil
local panelRect        -- {x1, y1, x2, y2} in screen pixels, y up
local lastAnchorX, lastAnchorY

-- per ability, parallel to ABILITIES
local cdEndFrame = {}  -- game frame the cooldown ends (0 = ready)
local flashUntil = {}  -- os.clock() until which the "no" flash shows
for i = 1, #ABILITIES do
	cdEndFrame[i] = 0
	flashUntil[i] = 0
end

--------------------------------------------------------------------------------
-- Production Boost: selection tracking
--
-- Mirrors the config parsing in unit_research_buildboost.lua so the button can
-- show eligibility and cost without a synced round trip. Defaults below MUST
-- match DEF_COST / DEF_MULT / DEF_DURATION in that gadget.
--------------------------------------------------------------------------------

local BOOST_DEF_COST     = 100
local BOOST_DEF_MULT     = 5.0
local BOOST_DEF_DURATION = 20 -- seconds

local boostCfg     = {} -- [unitDefID] = {cost, mult, duration} for boostable builders
local boostCapable = {} -- selected unitIDs that CAN be boosted (rebuilt on SelectionChanged)

-- Recomputed on every refresh, because "already boosted" changes with the
-- game clock rather than with the selection.
local boostSel = {
	eligible     = {}, -- unitIDs to actually order (capable and not already boosted)
	count        = 0,
	cost         = 0,  -- total RP for those
	activeCount  = 0,  -- selected builders currently mid-boost
	remainFrames = 0,  -- longest remaining boost in the selection
	totalFrames  = 1,  -- that unit's full duration, for the curtain
	mult         = BOOST_DEF_MULT,
	duration     = BOOST_DEF_DURATION,
}

local function BuildBoostConfig()
	for udid, ud in pairs(UnitDefs) do
		if (ud.buildSpeed or 0) > 0 then
			local cp = ud.customParams or {}
			if cp.buildboost ~= "false" then
				boostCfg[udid] = {
					cost     = tonumber(cp.buildboost_cost)     or BOOST_DEF_COST,
					mult     = tonumber(cp.buildboost_mult)     or BOOST_DEF_MULT,
					duration = tonumber(cp.buildboost_duration) or BOOST_DEF_DURATION,
				}
			end
		end
	end
end

local function RescanSelection(sel)
	boostCapable = {}
	for i = 1, #sel do
		local udid = spGetUnitDefID(sel[i])
		if udid and boostCfg[udid] then
			boostCapable[#boostCapable + 1] = sel[i]
		end
	end
end

local function RefreshBoostSummary()
	local frame = spGetGameFrame()
	local eligible, cost = {}, 0
	local activeCount, remain, total = 0, 0, 1
	local mult, duration = BOOST_DEF_MULT, BOOST_DEF_DURATION

	for i = 1, #boostCapable do
		local unitID = boostCapable[i]
		local udid = spGetUnitDefID(unitID) -- nil once the unit is gone
		local cfg = udid and boostCfg[udid]
		if cfg then
			mult, duration = cfg.mult, cfg.duration
			local endFrame = tonumber((spGetUnitRulesParam(unitID, "buildboost_end"))) or 0
			if endFrame > frame then
				activeCount = activeCount + 1
				if endFrame - frame > remain then
					remain = endFrame - frame
					total = math.max(1, floor(cfg.duration * GAME_SPEED))
				end
			else
				eligible[#eligible + 1] = unitID
				cost = cost + cfg.cost
			end
		end
	end

	boostSel.eligible     = eligible
	boostSel.count        = #eligible
	boostSel.cost         = cost
	boostSel.activeCount  = activeCount
	boostSel.remainFrames = remain
	boostSel.totalFrames  = total
	boostSel.mult         = mult
	boostSel.duration     = duration
end

--------------------------------------------------------------------------------
-- what each ability is doing
--------------------------------------------------------------------------------

local function GetMyRP()
	-- GetTeamRulesParam returns NO values (not nil) for an unset param; the
	-- extra parentheses force exactly one value so tonumber never errors.
	return tonumber((spGetTeamRulesParam(myTeamID, RP_RULES_PARAM))) or 0
end

local function CooldownRemaining(i)
	return math.max(0, (cdEndFrame[i] or 0) - spGetGameFrame())
end

-- Levelled abilities read their level from the team rules param, so a button
-- moves on to the next tier the moment the gadget confirms.
local function CurLevel(i)
	local a = ABILITIES[i]
	if not a.levels then
		return 0
	end
	return tonumber((spGetTeamRulesParam(myTeamID, a.levelParam))) or 0
end

local function IsMaxed(i)
	local a = ABILITIES[i]
	return a.levels ~= nil and CurLevel(i) >= #a.levels
end

local function AbilityCost(i)
	local a = ABILITIES[i]
	if a.kind == "selection" then
		return boostSel.cost
	end
	if not a.levels then
		return a.costRP or 0
	end
	local nextLevel = a.levels[CurLevel(i) + 1]
	return nextLevel and nextLevel.cost or 0
end

local function AbilityLabel(i)
	local a = ABILITIES[i]
	if not a.levels then
		return a.label
	end
	if IsMaxed(i) then
		return a.baseLabel
	end
	return a.baseLabel .. " " .. (CurLevel(i) + 1)
end

local function AbilityTooltip(i)
	local a = ABILITIES[i]
	if a.kind == "selection" then
		if #boostCapable == 0 then
			return a.tooltip
		end
		if boostSel.count == 0 then
			return "All selected builders are already boosted"
		end
		return string.format("Boost %d builder%s: x%.1f build speed for %ds",
			boostSel.count, (boostSel.count == 1) and "" or "s", boostSel.mult, boostSel.duration)
	end
	if not a.levels then
		return a.tooltip
	end
	if IsMaxed(i) then
		return a.baseLabel .. " fully researched"
	end
	local nextLevel = a.levels[CurLevel(i) + 1]
	return string.format(a.tooltipFmt, floor((nextLevel.mult - 1) * 100 + 0.5))
end

local function AbilityReady(i)
	local a = ABILITIES[i]
	if a.kind == "selection" then
		return boostSel.count > 0 and GetMyRP() >= boostSel.cost
	end
	if IsMaxed(i) then
		return false
	end
	return CooldownRemaining(i) == 0 and GetMyRP() >= AbilityCost(i)
end

--------------------------------------------------------------------------------
-- placement
--------------------------------------------------------------------------------

local function PanelHeight()
	return CHROME_HEIGHT + #ABILITIES * ABILITY_HEIGHT
end

-- The panel hangs off the top of the players list, sharing its right edge.
-- Returns the right edge and the bottom of where this panel goes.
local function GetAnchor(scale)
	local list = WG.StaticPlayersList
	if list and list.GetRect then
		local _, _, right, top = list.GetRect()
		if right and top then
			return right, top + floor(ANCHOR_GAP * scale)
		end
	end
	local vsx = Spring.GetViewGeometry()
	return vsx - floor(FALLBACK_MARGIN * scale), floor(FALLBACK_MARGIN * scale)
end

local function DefaultOrigin(vsx, vsy, w, h, scale)
	local right, bottom = GetAnchor(scale)
	lastAnchorX, lastAnchorY = right, bottom
	return right - w, bottom
end

local function Place()
	local x, y, w, h = hud.PlacePanel(view.Element("abilities"), LAYOUT_NAME, PANEL_WIDTH, PanelHeight(), DefaultOrigin)
	panelRect = x and {x, y, x + w, y + h}
end

-- the players list resizes while the game runs (specs expand, players resign)
local function FollowAnchor()
	local right, bottom = GetAnchor(hud.GetScale())
	if right ~= lastAnchorX or bottom ~= lastAnchorY then
		Place()
	end
end

--------------------------------------------------------------------------------
-- refreshing
--------------------------------------------------------------------------------

local function Rgb(color)
	return string.format("rgb(%d,%d,%d)", floor(color[1] * 255 + 0.5), floor(color[2] * 255 + 0.5), floor(color[3] * 255 + 0.5))
end

local function Percent(fraction)
	return string.format("%d%%", floor(math.max(0, math.min(1, fraction)) * 100 + 0.5))
end

local function RefreshAbility(i)
	local a = ABILITIES[i]
	local id = "a" .. i
	local rp = GetMyRP()

	-- right: what it costs, how long until it is back, or why not
	local right, rightClass = "", nil
	local curtain = 0     -- how much of the button the cooldown curtain covers
	local dim = false

	if a.kind == "selection" then
		if boostSel.count > 0 then
			right = boostSel.cost .. " RP"
			rightClass = (rp >= boostSel.cost) and "ok" or "short"
			dim = rp < boostSel.cost
		elseif boostSel.activeCount > 0 then
			right = ceil(boostSel.remainFrames / GAME_SPEED) .. "s"
			rightClass = "wait"
			curtain = boostSel.remainFrames / boostSel.totalFrames
		else
			right = "--"
			dim = true
		end
	elseif IsMaxed(i) then
		right = "MAX"
		dim = true
	else
		local remaining = CooldownRemaining(i)
		if remaining > 0 then
			right = ceil(remaining / GAME_SPEED) .. "s"
			rightClass = "wait"
			curtain = remaining / ((a.cooldownSeconds or 20) * GAME_SPEED)
		else
			local cost = AbilityCost(i)
			right = cost .. " RP"
			rightClass = (rp >= cost) and "ok" or "short"
			dim = rp < cost
		end
	end

	view.SetText(id .. "-name", hud.Escape(AbilityLabel(i)))
	view.SetText(id .. "-right", right)
	view.SetClass(id .. "-right", "ok", rightClass == "ok")
	view.SetClass(id .. "-right", "short", rightClass == "short")
	view.SetClass(id .. "-right", "wait", rightClass == "wait")
	view.SetStyle(id .. "-curtain", "width", Percent(curtain))

	view.SetClass(id, "ready", AbilityReady(i))
	view.SetClass(id, "dim", dim)
	view.SetClass(id, "targeting", targetingIndex == i)
	view.SetClass(id, "deny", flashUntil[i] > os.clock())
end

-- the line beside the panel that says what the hovered ability does
local function RefreshTip()
	local show = hoverIndex ~= nil and not targetingIndex and panelRect ~= nil
	local button = show and view.Element("a" .. hoverIndex)
	if not button then
		view.SetClass("tip", "hidden", true)
		return
	end
	local vsx = Spring.GetViewGeometry()
	local gap = floor(TIP_GAP * hud.GetScale())
	view.SetText("tip", hud.Escape(AbilityTooltip(hoverIndex)))
	view.SetStyle("tip", "top", string.format("%dpx", floor(button.absolute_top or 0)))
	-- on whichever side of the panel has the room
	if (panelRect[1] + panelRect[3]) * 0.5 >= vsx * 0.5 then
		view.SetStyle("tip", "left", "auto")
		view.SetStyle("tip", "right", string.format("%dpx", vsx - panelRect[1] + gap))
	else
		view.SetStyle("tip", "right", "auto")
		view.SetStyle("tip", "left", string.format("%dpx", panelRect[3] + gap))
	end
	view.SetClass("tip", "hidden", false)
end

local function Refresh()
	view.SetClass("abilities", "hidden", isSpec)
	if isSpec then
		view.SetClass("tip", "hidden", true)
		return
	end
	FollowAnchor()
	RefreshBoostSummary()
	for i = 1, #ABILITIES do
		RefreshAbility(i)
	end
	RefreshTip()
end

local function BuildList()
	local parts = {}
	for i, a in ipairs(ABILITIES) do
		parts[i] = string.format(
			'<div id="a%d" class="ability" data-a="%d">'
			.. '<div class="stripe" style="background-color: %s;"/>'
			.. '<div id="a%d-name" class="name"/><div class="grow"/><div id="a%d-right" class="right"/>'
			.. '<div id="a%d-curtain" class="curtain"/></div>',
			i, i, Rgb(a.accent), i, i, i)
	end
	view.Element("list").inner_rml = table.concat(parts)
	view.Element("abilities").style["height"] = PanelHeight() .. "dp"
end

--------------------------------------------------------------------------------
-- using an ability
--------------------------------------------------------------------------------

local function CancelTargeting()
	targetingIndex = nil
end

local function TryActivate(i)
	local a = ABILITIES[i]
	if not AbilityReady(i) then
		flashUntil[i] = os.clock() + FLASH_SECONDS -- visibly "no" (maxed / broke / cooling)
		return
	end

	if a.kind == "selection" then
		-- Order only the eligible units; the gadget re-validates cost and state.
		Spring.GiveOrderToUnitArray(boostSel.eligible, a.cmdID, {}, 0)
	elseif a.kind == "instant" then
		-- Fires at once; the level rules param moves when the gadget confirms,
		-- and UpgradeDenyEvent flashes the button if it refuses.
		spSendLuaRulesMsg(a.msg)
	else
		-- "target": the next click on the map places it
		targetingIndex = i
		Spring.SetActiveCommand(0) -- drop any pending build/order ghost
		return
	end
	if a.sound then
		spPlaySoundFile(a.sound, a.soundVolume or 1.0, "ui")
	end
end

local function FireAt(i, wx, wz)
	local a = ABILITIES[i]
	spSendLuaRulesMsg(a.msg .. " " .. string.format("%.1f %.1f", wx, wz))
	-- An optimistic cooldown so the button reacts at once; the gadget's
	-- ScannerCooldownEvent overwrites it with the real value (or the old one
	-- plus a deny flash if the cast was refused).
	cdEndFrame[i] = spGetGameFrame() + ((a.cooldownSeconds or 20) * GAME_SPEED)
end

--------------------------------------------------------------------------------
-- gadget -> widget events
--------------------------------------------------------------------------------

local function OnScannerCooldown(endFrame)
	-- Single-ability protocol for now: index 1. If a second targeted ability
	-- gets its own gadget, give it its own event name and map it here.
	cdEndFrame[1] = endFrame or 0
end

local function OnScannerDeny(reason)
	flashUntil[1] = os.clock() + FLASH_SECONDS
	-- the optimistic cooldown was wrong: ask synced for the real one
	spSendLuaRulesMsg("scanner_query")
end

local function OnUpgradeDeny(track, reason)
	for i = 1, #ABILITIES do
		if ABILITIES[i].track == track then
			flashUntil[i] = os.clock() + FLASH_SECONDS
			return
		end
	end
end

--------------------------------------------------------------------------------
-- widget api
--------------------------------------------------------------------------------

function widget:Initialize()
	local helpers = include("rml/hud.lua")
	local result, reason = helpers.LoadDocument(DOCUMENT_PATH, widget)
	if not result then
		Spring.Echo("[Abilities] " .. tostring(reason))
		widgetHandler:RemoveWidget()
		return
	end
	hud = helpers
	document = result

	view = hud.NewView(document)
	view.Assume("abilities", "hidden", true) -- set in the markup
	view.Assume("tip", "hidden", true)
	BuildList()

	local list = view.Element("list")
	list:AddEventListener("mousedown", function(event)
		local i = hud.EventAttribute(event, "data-a")
		if i and ABILITIES[i] and not isSpec and event.parameters and event.parameters.button == 0 then
			spPlaySoundFile("leftclick", 1.0, "ui")
			TryActivate(i)
			Refresh()
		end
	end)
	list:AddEventListener("mouseover", function(event)
		local i = hud.EventAttribute(event, "data-a")
		if i ~= hoverIndex and i and ABILITIES[i] and AbilityReady(i) then
			spPlaySoundFile("hover", 1.0, "ui")
		end
		hoverIndex = i
		RefreshTip()
	end)
	list:AddEventListener("mouseout", function()
		hoverIndex = nil
		RefreshTip()
	end)

	widgetHandler:RegisterGlobal("ScannerCooldownEvent", OnScannerCooldown)
	widgetHandler:RegisterGlobal("ScannerDenyEvent",     OnScannerDeny)
	widgetHandler:RegisterGlobal("UpgradeDenyEvent",     OnUpgradeDeny)

	-- Production Boost: parse the builder configs once, then pick up whatever
	-- is already selected (widget reload mid-game).
	BuildBoostConfig()
	RescanSelection(spGetSelectedUnits() or {})

	hud.RegisterPanel(LAYOUT_NAME, "Abilities", Place)
	Place()

	Refresh()
	hud.ShowPassive(document)
	lastUpdate = Spring.GetTimer()

	-- re-sync the cooldown after a LuaUI or widget reload
	spSendLuaRulesMsg("scanner_query")
end

function widget:Shutdown()
	if hud then
		hud.UnregisterPanel(LAYOUT_NAME)
	end
	if document then
		widgetHandler:DeregisterGlobal("ScannerCooldownEvent")
		widgetHandler:DeregisterGlobal("ScannerDenyEvent")
		widgetHandler:DeregisterGlobal("UpgradeDenyEvent")
		document:Close()
		document = nil
	end
end

function widget:PlayerChanged()
	isSpec   = spGetSpectatingState()
	myTeamID = spGetMyTeamID()
	if isSpec then
		CancelTargeting()
	end
	RescanSelection(spGetSelectedUnits() or {})
end

function widget:SelectionChanged(sel)
	RescanSelection(sel or {})
end

function widget:ViewResize()
	if hud and document then
		hud.UpdateScale()
		Place()
	end
end

-- While a target is being placed, the next click on the map is this widget's.
-- Clicks on the panels never get here: RmlUi takes those first.
function widget:MousePress(x, y, button)
	if not document or isSpec or not targetingIndex then
		return false
	end
	if button == 1 then
		local kind, pos = spTraceScreenRay(x, y, true) -- coordsOnly: always {x, y, z}
		if kind == "ground" and pos then
			spPlaySoundFile("leftclick", 1.0, "ui")
			FireAt(targetingIndex, pos[1], pos[3])
		end
	end
	CancelTargeting()
	Refresh()
	return true
end

function widget:KeyPress(key)
	if document and targetingIndex and key == KEY_ESCAPE then
		CancelTargeting()
		Refresh()
		return true
	end
	return false
end

-- the reach of the ability being placed, on the ground under the mouse
function widget:DrawWorld()
	if not targetingIndex then
		return
	end
	local mx, my = spGetMouseState()
	local kind, pos = spTraceScreenRay(mx, my, true)
	if kind ~= "ground" or not pos then
		return
	end
	local a = ABILITIES[targetingIndex]
	gl.LineWidth(2.5)
	gl.Color(a.accent[1], a.accent[2], a.accent[3], 0.85)
	gl.DrawGroundCircle(pos[1], pos[2], pos[3], a.radius, 48)
	gl.LineWidth(1.0)
	gl.Color(1, 1, 1, 1)
end

function widget:Update()
	if not document then
		return
	end
	if hud.FollowGuiHidden(document) then
		hoverIndex = nil
		return -- hidden with the rest of the GUI (F5)
	end
	local now = Spring.GetTimer()
	if Spring.DiffTimers(now, lastUpdate) >= UPDATE_INTERVAL then
		lastUpdate = now
		Refresh()
	end
end
