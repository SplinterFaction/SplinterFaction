--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Share window of the RmlUi HUD: give metal, energy and units to another team.
--
--  H opens and closes it (so does Sharing in the game menu); Esc or the X
--  closes it. Click a team on the left, set how much metal and energy to send
--  with the sliders on the right, tick "Share selected units" to hand over the
--  selection as well, then Apply. The window stays open after Apply.
--
--  Units keep their orders: each unit's command queue is sent to the
--  order-preservation gadget before the transfer.
--
--  Replaces gui_static_sharemenu.lua (kept in Widgets/disabled/) and keeps its
--  WG.StaticShareMenu interface, which the game menu uses.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name    = "Share Menu",
		desc    = "Share resources and units via hotkey H (RmlUi)",
		author  = "SplinterFaction Team",
		date    = "2026-10-12",
		license = "GNU GPL, v2 or later",
		layer   = -500, -- before the game menu, so Esc closes this first
		enabled = true,
	}
end

local DOCUMENT_PATH = "LuaUI/rml/share.rml"

-- must match #share in share.rml
local PANEL_WIDTH  = 640
local PANEL_HEIGHT = 424
local RAISE        = 60 -- the window sits this far above the middle of the screen

local LAYOUT_NAME = "sharemenu" -- same as the old widget, so a saved position carries over

local UPDATE_INTERVAL = 0.25
local RESULT_SECONDS  = 4

local KEY_ESCAPE = 27
local KEY_H      = 104 -- 'h'; the engine reports the same code with shift held

local floor = math.floor

local hud
local document
local view
local lastUpdate

local isOpen = false

local allies  = {}   -- {teamID, name, r, g, b, selected}; row i has the id "ally<i>"
local enemies = {}   -- the same, with the id "enemy<i>"
local unitsMarkup    -- the selected units' markup, as last set

local amount   = {metal = 0, energy = 0}  -- what the sliders say to send
local storage  = {metal = 1, energy = 1}  -- the sliders' range: my storage
local dragging       -- "metal" or "energy" while a slider is held
local shareUnits = false
local result, resultUntil  -- a line saying what Apply did, and until when it shows

--------------------------------------------------------------------------------
-- reading the game
--------------------------------------------------------------------------------

local function GetTeamDisplayName(teamID)
	-- Spring.GetPlayerList(teamID) may not work in all engine versions.
	-- Instead iterate all players and match by team.
	for _, pid in ipairs(Spring.GetPlayerList() or {}) do
		local name, active, spectator, playerTeam = Spring.GetPlayerInfo(pid, false)
		if name and playerTeam == teamID then
			return name
		end
	end
	local _, _, _, isAI = Spring.GetTeamInfo(teamID, false)
	if isAI then
		local aiName = Spring.GetTeamLuaAI(teamID)
		if aiName and aiName ~= "" then
			return aiName
		end
	end
	return "Team " .. teamID
end

-- every living team but mine, split into allies and enemies
local function RefreshPlayerLists()
	allies, enemies = {}, {}
	local myTeam     = Spring.GetMyTeamID()
	local myAllyTeam = Spring.GetMyAllyTeamID()
	local gaiaTeam   = Spring.GetGaiaTeamID()
	for _, teamID in ipairs(Spring.GetTeamList() or {}) do
		if teamID ~= myTeam and teamID ~= gaiaTeam then
			local _, _, isDead, _, _, allyTeamID = Spring.GetTeamInfo(teamID, false)
			if not isDead then
				local r, g, b = Spring.GetTeamColor(teamID)
				local entry = {teamID = teamID, name = GetTeamDisplayName(teamID), r = r or 1, g = g or 1, b = b or 1, selected = false}
				local list = (allyTeamID == myAllyTeam) and allies or enemies
				list[#list + 1] = entry
			end
		end
	end
end

-- the selection as {name, count}, in the order the types were met
local function SelectedUnitTypes()
	local counts, order = {}, {}
	for _, unitID in ipairs(Spring.GetSelectedUnits() or {}) do
		local defID = Spring.GetUnitDefID(unitID)
		if defID then
			local ud = UnitDefs[defID]
			local name = (ud and ud.humanName) or ("Unit " .. defID)
			if not counts[name] then
				counts[name] = 0
				order[#order + 1] = name
			end
			counts[name] = counts[name] + 1
		end
	end
	local types = {}
	for i, name in ipairs(order) do
		types[i] = {name = name, count = counts[name]}
	end
	return types
end

local function ReadStorage()
	local myTeam = Spring.GetMyTeamID()
	local _, metal = Spring.GetTeamResources(myTeam, "metal")
	local _, energy = Spring.GetTeamResources(myTeam, "energy")
	storage.metal = math.max(1, floor(metal or 1))
	storage.energy = math.max(1, floor(energy or 1))
	amount.metal = math.max(0, math.min(amount.metal, storage.metal))
	amount.energy = math.max(0, math.min(amount.energy, storage.energy))
end

--------------------------------------------------------------------------------
-- showing
--------------------------------------------------------------------------------

local function PlayerListRML(list, prefix)
	if #list == 0 then
		return '<div class="empty">(none)</div>'
	end
	local parts = {}
	for i, entry in ipairs(list) do
		parts[i] = string.format(
			'<div id="%s%d" class="player" data-%s="%d"><div class="swatch" style="background-color: %s;"/><div>%s</div></div>',
			prefix, i, prefix, i, hud.Rgb(entry.r, entry.g, entry.b), hud.Escape(entry.name))
	end
	return table.concat(parts)
end

local function ShowPlayerLists()
	view.Element("allies").inner_rml = PlayerListRML(allies, "ally")
	view.Element("enemies").inner_rml = PlayerListRML(enemies, "enemy")
	view.Forget()
	unitsMarkup = nil
end

local function Percent(value, max)
	return string.format("%.1f%%", floor(math.max(0, math.min(1, value / math.max(1, max))) * 200 + 0.5) / 2)
end

local function Refresh()
	view.SetClass("share", "hidden", not isOpen)
	if not isOpen then
		return
	end
	ReadStorage()

	for i, entry in ipairs(allies) do
		view.SetClass("ally" .. i, "selected", entry.selected)
	end
	for i, entry in ipairs(enemies) do
		view.SetClass("enemy" .. i, "selected", entry.selected)
	end

	local types = SelectedUnitTypes()
	local parts = {}
	for i, entry in ipairs(types) do
		parts[i] = string.format('<div class="urow"><div>%s</div><div class="grow"/><div class="ucount">%s</div></div>',
			hud.Escape(entry.name), (entry.count > 1) and ("x" .. entry.count) or "")
	end
	local markup = (#parts > 0) and table.concat(parts) or '<div class="empty">(no units selected)</div>'
	if markup ~= unitsMarkup then
		unitsMarkup = markup
		view.Element("units").inner_rml = markup
	end
	view.SetClass("check", "on", shareUnits)

	for _, name in ipairs({"metal", "energy"}) do
		local position = Percent(amount[name], storage[name])
		view.SetStyle(name .. "-fill", "width", position)
		view.SetStyle(name .. "-handle", "left", position)
		view.SetClass(name .. "-handle", "dragging", dragging == name)
		view.SetText(name .. "-amount", tostring(amount[name]))
		view.SetText(name .. "-max", "/ " .. storage[name])
	end

	if result and os.clock() > resultUntil then
		result = nil
	end
	view.SetText("result", hud.Escape(result or ""))
end

--------------------------------------------------------------------------------
-- apply
--------------------------------------------------------------------------------

local function Say(text)
	result = text
	resultUntil = os.clock() + RESULT_SECONDS
end

local function DoApply()
	local targets = {}
	for _, entry in ipairs(allies) do
		if entry.selected then targets[#targets + 1] = entry.teamID end
	end
	for _, entry in ipairs(enemies) do
		if entry.selected then targets[#targets + 1] = entry.teamID end
	end
	if #targets == 0 then
		Say("Choose who to give to first.")
		return
	end

	local metalEach  = floor(amount.metal / #targets)
	local energyEach = floor(amount.energy / #targets)
	for _, teamID in ipairs(targets) do
		if metalEach > 0 then Spring.ShareResources(teamID, "metal", metalEach) end
		if energyEach > 0 then Spring.ShareResources(teamID, "energy", energyEach) end
	end

	local sharedUnits = 0
	if shareUnits then
		local targetTeam = targets[1]
		local unitIDs = Spring.GetSelectedUnits() or {}
		if #unitIDs > 0 then
			-- Snapshot command queues and send to the order-preservation gadget
			-- BEFORE the transfer, while we still own the units.
			for _, unitID in ipairs(unitIDs) do
				local tokens = {}
				for _, cmd in ipairs(Spring.GetUnitCommands(unitID, -1) or {}) do
					local fields = {tostring(cmd.id)}
					for _, p in ipairs(cmd.params or {}) do
						fields[#fields + 1] = tostring(p)
					end
					fields[#fields + 1] = "OPTS:" .. tostring(cmd.options or 0)
					tokens[#tokens + 1] = table.concat(fields, ",")
				end
				Spring.SendLuaRulesMsg("ShareOrders:" .. unitID .. ":" .. targetTeam .. ":" .. table.concat(tokens, "|"))
			end
			-- transfer all selected units to the target team in one call
			Spring.ShareResources(targetTeam, "units")
			sharedUnits = #unitIDs
			Spring.Echo(string.format("[ShareMenu] Shared %d unit(s) to team %d", sharedUnits, targetTeam))
		end
	end

	local sent = {}
	if metalEach > 0 then sent[#sent + 1] = metalEach .. " metal" end
	if energyEach > 0 then sent[#sent + 1] = energyEach .. " energy" end
	if sharedUnits > 0 then sent[#sent + 1] = sharedUnits .. ((sharedUnits == 1) and " unit" or " units") end
	Say((#sent > 0) and ("Sent " .. table.concat(sent, ", ") .. ".") or "Nothing to send.")

	amount.metal, amount.energy = 0, 0
end

--------------------------------------------------------------------------------
-- open and close
--------------------------------------------------------------------------------

local function DefaultOrigin(vsx, vsy, w, h, scale)
	return (vsx - w) * 0.5, vsy * 0.5 + RAISE * scale - h * 0.5
end

local function Place()
	hud.PlacePanel(view.Element("share"), LAYOUT_NAME, PANEL_WIDTH, PANEL_HEIGHT, DefaultOrigin)
end

local function Open()
	if isOpen or not document then
		return
	end
	isOpen = true
	amount.metal, amount.energy = 0, 0
	shareUnits = false
	dragging = nil
	result = nil
	RefreshPlayerLists()
	ShowPlayerLists()
	pcall(function() document:PullToFront() end)
	Spring.PlaySoundFile("leftclick", 1.0, "ui")
	Refresh()
end

local function Close()
	if not isOpen then
		return
	end
	isOpen = false
	dragging = nil
	Spring.PlaySoundFile("leftclick", 1.0, "ui")
	Refresh()
end

local function Toggle()
	if isOpen then
		Close()
	else
		Open()
	end
end

--------------------------------------------------------------------------------
-- input
--------------------------------------------------------------------------------

-- one team at a time: clicking a team picks it, clicking it again lets go
local function Pick(list, index)
	local entry = list[index]
	if not entry then
		return
	end
	local was = entry.selected
	for _, e in ipairs(allies) do e.selected = false end
	for _, e in ipairs(enemies) do e.selected = false end
	entry.selected = not was
	Spring.PlaySoundFile("leftclick", 1.0, "ui")
	Refresh()
end

local function ListenToList(id, attribute, list)
	view.Element(id):AddEventListener("mousedown", function(event)
		if event.parameters and event.parameters.button == 0 then
			Pick(list(), hud.EventAttribute(event, attribute))
		end
	end)
end

local function SlideTo(name)
	local fraction = hud.MouseFraction(view.Element(name .. "-slider"))
	if fraction then
		amount[name] = floor(fraction * storage[name] + 0.5)
	end
end

--------------------------------------------------------------------------------
-- widget api
--------------------------------------------------------------------------------

function widget:Initialize()
	local helpers = include("rml/hud.lua")
	local loaded, reason = helpers.LoadDocument(DOCUMENT_PATH, widget)
	if not loaded then
		Spring.Echo("[Share Menu] " .. tostring(reason))
		widgetHandler:RemoveWidget()
		return
	end
	hud = helpers
	document = loaded

	view = hud.NewView(document)
	view.Assume("share", "hidden", true) -- set in the markup

	-- H is this window's key, not the engine's share dialog
	Spring.SendCommands("unbindkeyset h")
	Spring.SendCommands("unbindkeyset H")

	hud.OnClick(view, "close", Close)
	hud.OnClick(view, "cancel", Close)
	hud.OnClick(view, "apply", function()
		Spring.PlaySoundFile("leftclick", 1.0, "ui")
		DoApply()
		Refresh()
	end)
	hud.OnClick(view, "check-row", function()
		shareUnits = not shareUnits
		Spring.PlaySoundFile("leftclick", 1.0, "ui")
		Refresh()
	end)
	ListenToList("allies", "data-ally", function() return allies end)
	ListenToList("enemies", "data-enemy", function() return enemies end)
	for _, name in ipairs({"metal", "energy"}) do
		hud.OnClick(view, name .. "-slider", function()
			dragging = name
			SlideTo(name)
			Refresh()
		end)
	end

	WG.StaticShareMenu = {Toggle = Toggle, Show = Open, Hide = Close}

	hud.RegisterPanel(LAYOUT_NAME, "Share Menu", Place, function() return isOpen end)
	Place()

	hud.ShowPassive(document)
	lastUpdate = Spring.GetTimer()
end

function widget:Shutdown()
	WG.StaticShareMenu = nil
	if hud then
		hud.UnregisterPanel(LAYOUT_NAME)
	end
	if document then
		document:Close()
		document = nil
		Spring.SendCommands("bind h sharedialog")
	end
end

function widget:ViewResize()
	if hud and document then
		hud.UpdateScale()
		Place()
	end
end

function widget:KeyPress(key, mods, isRepeat)
	if not document or isRepeat then
		return false
	end
	if key == KEY_H then
		Toggle()
		return true
	end
	if isOpen and key == KEY_ESCAPE then
		Close()
		return true
	end
	return false
end

function widget:Update()
	if not document then
		return
	end
	if hud.FollowGuiHidden(document) or not isOpen then
		dragging = nil
		return
	end
	if dragging then
		SlideTo(dragging)
		local _, _, leftDown = Spring.GetMouseState()
		if not leftDown then
			dragging = nil
		end
		Refresh()
		return
	end
	local now = Spring.GetTimer()
	if Spring.DiffTimers(now, lastUpdate) >= UPDATE_INTERVAL then
		lastUpdate = now
		Refresh()
	end
end
