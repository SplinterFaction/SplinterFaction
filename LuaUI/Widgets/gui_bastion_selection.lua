--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Selected units of the RmlUi HUD.
--
--  A row at the bottom center with one card for each type of unit in the
--  selection and how many of it are selected.
--
--    left click          select only that type
--    Alt + left click    select a single unit of that type
--    Ctrl + left click   select every unit of that type you own
--                        (with Shift: add them to the selection)
--    middle click        look at that type (Ctrl: at the whole selection)
--    right click         take that type out of the selection
--                        (Ctrl: take out a single unit)
--
--  Replaces gui_static_selected_units_buttons.lua (kept in Widgets/disabled/).
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name    = "Bastion Selected Units",
		previousNames = {"Selected Units"},
		desc    = "Cards for the types of unit in the current selection (RmlUi)",
		author  = "SplinterFaction Team",
		date    = "2026-10-12",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true,
	}
end

local DOCUMENT_PATH = "LuaUI/rml/selection.rml"

-- must match #selection in selection.rml
local STRIP_WIDTH  = 864
local STRIP_HEIGHT = 66
local MAX_TYPES    = 14 -- as many cards as the strip holds

local LAYOUT_NAME = "selectedunits" -- same as the old widget, so a saved position carries over

-- for keeping clear of the tooltip panel (see RowShift), in dp
local CARD_PITCH    = 61  -- a card and the gap after it (.unit in selection.rml: 58 + 3)
local ROW_EXTRA     = 5   -- the row's left padding and its borders
local TOOLTIP_RIGHT = 648 -- right edge of the tooltip panel in its default place
local CLEARANCE     = 16

local REFRESH_DELAY = 0.1 -- a drag-select changes the selection many times a second

local SOUND_LEFT   = "LuaUI/Sounds/buildbar_add.wav"
local SOUND_MIDDLE = "LuaUI/Sounds/buildbar_click.wav"
local SOUND_RIGHT  = "LuaUI/Sounds/buildbar_rem.wav"

local spGetSelectedUnits       = Spring.GetSelectedUnits
local spGetSelectedUnitsSorted = Spring.GetSelectedUnitsSorted
local spSelectUnitArray        = Spring.SelectUnitArray

local hud
local document
local view

local shownTypes = {}  -- unitDefIDs in the order their cards are shown; card i has the id "u<i>"
local shownKey         -- what the row's markup was made from
local dirty = true
local dirtyFor = 0

--------------------------------------------------------------------------------
-- refreshing
--------------------------------------------------------------------------------

-- the types in the selection: dearest first, so the row keeps a steady order
local function SelectedTypes()
	local sorted = spGetSelectedUnitsSorted() or {}
	local types = {}
	for unitDefID, units in pairs(sorted) do
		if type(unitDefID) == "number" and type(units) == "table" then
			types[#types + 1] = {id = unitDefID, count = #units}
		end
	end
	table.sort(types, function(a, b)
		local costA = (UnitDefs[a.id] and UnitDefs[a.id].metalCost) or 0
		local costB = (UnitDefs[b.id] and UnitDefs[b.id].metalCost) or 0
		if costA ~= costB then
			return costA > costB
		end
		return a.id < b.id
	end)
	while #types > MAX_TYPES do
		types[#types] = nil
	end
	return types
end

local RowShift -- defined with the placement, below

local function Refresh()
	dirty = false
	local types = SelectedTypes()

	local ids = {}
	for i, entry in ipairs(types) do
		ids[i] = entry.id
	end
	local key = table.concat(ids, ",")
	if key ~= shownKey then
		shownKey = key
		shownTypes = ids
		local parts = {}
		for i, unitDefID in ipairs(ids) do
			parts[i] = string.format('<div class="unit" data-u="%d">%s<div id="u%d-n" class="count"/></div>',
				i, hud.UnitPictureRML(unitDefID, "pic"), i)
		end
		view.Element("row").inner_rml = table.concat(parts)
		view.Forget() -- the cards are new elements
	end

	for i, entry in ipairs(types) do
		view.SetText("u" .. i .. "-n", tostring(entry.count))
		-- a lone unit needs no "1" on it
		view.SetClass("u" .. i .. "-n", "hidden", entry.count < 2 and #types == 1)
	end
	view.SetClass("row", "hidden", #types == 0)
	view.SetStyle("row", "left", RowShift(#types) .. "px")
end

--------------------------------------------------------------------------------
-- clicks
--------------------------------------------------------------------------------

local function LeftClick(unitDefID, units)
	local alt, ctrl, meta, shift = Spring.GetModKeyState()
	if ctrl then
		local mine = Spring.GetTeamUnitsSorted(Spring.GetMyTeamID())[unitDefID]
		if not mine then
			return
		end
		spSelectUnitArray(mine, shift)
	elseif alt or meta then
		spSelectUnitArray({units[1]})
	else
		spSelectUnitArray(units)
	end
	Spring.PlaySoundFile(SOUND_LEFT, 0.75, "ui")
end

local function MiddleClick(unitDefID, units)
	local _, ctrl = Spring.GetModKeyState()
	if ctrl then
		Spring.SendCommands({"viewselection"})
	else
		-- the camera goes to the selection, so select the type just long enough
		local selection = spGetSelectedUnits()
		spSelectUnitArray(units)
		Spring.SendCommands({"viewselection"})
		spSelectUnitArray(selection)
	end
	Spring.PlaySoundFile(SOUND_MIDDLE, 0.75, "ui")
end

local function RightClick(unitDefID, units)
	local _, ctrl = Spring.GetModKeyState()
	local keep = {}
	for _, unitID in ipairs(spGetSelectedUnits()) do
		keep[unitID] = true
	end
	for _, unitID in ipairs(units) do
		keep[unitID] = nil
		if ctrl then
			break
		end
	end
	Spring.SelectUnitMap(keep)
	Spring.PlaySoundFile(SOUND_RIGHT, 0.75, "ui")
end

-- RmlUi numbers the buttons left 0, right 1, middle 2
local CLICKS = {[0] = LeftClick, [1] = RightClick, [2] = MiddleClick}

local function OnMouseDown(event)
	local index = hud.EventAttribute(event, "data-u")
	local unitDefID = index and shownTypes[index]
	local click = CLICKS[event.parameters and event.parameters.button]
	if not unitDefID or not click then
		return
	end
	-- smart select is in the middle of changing the selection
	if WG.smartselect and not WG.smartselect.updateSelection then
		return
	end
	local units = (spGetSelectedUnitsSorted() or {})[unitDefID]
	if units and #units > 0 then
		click(unitDefID, units)
		dirty, dirtyFor = true, REFRESH_DELAY -- show the result at once
	end
end

--------------------------------------------------------------------------------
-- placement
--------------------------------------------------------------------------------

local function DefaultOrigin(vsx, vsy, w, h, scale)
	return (vsx - w) * 0.5, 0
end

local stripX, stripW = 0, 0 -- where the strip is, in pixels
local stripMoved = false    -- the player has dragged it somewhere else in tweak mode

local function Place()
	local vsx, vsy = Spring.GetViewGeometry()
	local x, _, w = hud.PlacePanel(view.Element("selection"), LAYOUT_NAME, STRIP_WIDTH, STRIP_HEIGHT, DefaultOrigin)
	stripX, stripW = x or 0, w or 0
	stripMoved = (x ~= math.floor((vsx - stripW) * 0.5))
	dirty = true
end

-- The row is centered in the strip and grows both ways, and with enough types
-- selected its left end would run under the tooltip panel, which stands in
-- the bottom left and reaches TOOLTIP_RIGHT dp into the screen. From there on
-- the row is pushed right instead: its left end stops at the tooltip and it
-- grows to the right only. (Not when the player has put the strip elsewhere.)
RowShift = function(cardCount)
	if stripMoved or cardCount == 0 then
		return 0
	end
	local vsx = Spring.GetViewGeometry()
	local scale = hud.GetScale()
	local rowW = (cardCount * CARD_PITCH + ROW_EXTRA) * scale
	local rowLeft = stripX + (stripW - rowW) * 0.5
	local shift = (TOOLTIP_RIGHT + CLEARANCE) * scale - rowLeft
	-- never off the right edge of the screen
	shift = math.min(shift, vsx - CLEARANCE * scale - (rowLeft + rowW))
	return math.max(0, math.floor(shift + 0.5))
end

--------------------------------------------------------------------------------
-- widget api
--------------------------------------------------------------------------------

function widget:Initialize()
	local helpers = include("rml/hud.lua")
	local result, reason = helpers.LoadDocument(DOCUMENT_PATH, widget)
	if not result then
		Spring.Echo("[Selected Units] " .. tostring(reason))
		widgetHandler:RemoveWidget()
		return
	end
	hud = helpers
	document = result

	view = hud.NewView(document)
	view.Assume("row", "hidden", true) -- set in the markup
	view.Element("row"):AddEventListener("mousedown", OnMouseDown)

	hud.RegisterPanel(LAYOUT_NAME, "Selected Units", Place)
	Place()

	Refresh()
	hud.ShowPassive(document)
end

function widget:Shutdown()
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

function widget:SelectionChanged()
	dirty = true
end

-- a selected unit that dies leaves the selection without SelectionChanged
function widget:UnitDestroyed()
	dirty = true
end

function widget:Update(dt)
	if not document then
		return
	end
	if hud.FollowGuiHidden(document) then
		return -- hidden with the rest of the GUI (F5)
	end
	if dirty then
		dirtyFor = dirtyFor + (dt or 0)
		if dirtyFor >= REFRESH_DELAY then
			dirtyFor = 0
			Refresh()
		end
	end
end
