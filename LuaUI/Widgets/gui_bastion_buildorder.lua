--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Build and order menus of the RmlUi HUD.
--
--  Two panels at the bottom left. The order panel holds the selected units'
--  commands, five to a row; a command with states (fire at will, hold fire...)
--  names the state it is in. The build panel lists what the selection can
--  build, sorted the way the unit defs ask for (customParams.buildmenucategory)
--  under "Factory Units" and "Structures".
--
--  Left click gives the command, right click on a build card takes one off the
--  queue, and the modifier keys work as they do everywhere else.
--
--  Replaces gui_static_buildordermenu.lua (kept in Widgets/disabled/). It
--  keeps that widget's WG.StaticBuildOrderMenu interface, which the hotbind
--  widget and the tooltip panel use.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name    = "Bastion Build/Order Menu",
		previousNames = {"Build/Order Menu"},
		desc    = "Build and order menus with categorized build sections (RmlUi)",
		author  = "SplinterFaction Team",
		date    = "2026-10-12",
		license = "GNU GPL, v2 or later",
		layer   = 1,
		enabled = true,
		handler = true, -- the real widgetHandler: this widget takes over the command layout
	}
end

--------------------------------------------------------------------------------
-- config
--------------------------------------------------------------------------------

local DOCUMENT_PATH   = "LuaUI/rml/buildorder.rml"
local UPDATE_INTERVAL = 0.1

-- must match #orders and #build in buildorder.rml
local PANEL_WIDTH  = 320
local ORDER_HEIGHT = 212
local BUILD_HEIGHT = 534
local MARGIN       = 8
local PANEL_GAP    = 10

local MAX_ORDERS = 25 -- five rows of five

-- same names as the old widget, so positions saved in tweak mode carry over
local LAYOUT_ORDER = "buildorder_order"
local LAYOUT_BUILD = "buildorder_build"

local SHOW_HOTKEYS_CONFIG = "evo_showhotkeys"
local SHOW_COST_CONFIG    = "evo_showcost"
local SHOW_TECHREQ_CONFIG = "evo_showtechreq"

local HOTKEY_WIDGET = "SplinterFaction Build Hotkeys"

local FAMILY_CATEGORY_ORDER = {
	Factory = {"Scout", "Skirmish", "Support", "Utility", "Unsorted"},
	Builder = {"Economy", "Geothermal", "Production", "Combat", "Utility", "Unsorted"},
}

local FAMILY_SECTION_TITLES = {
	Factory = "Factory Units",
	Builder = "Structures",
}

local hiddenCMDs = {
	timewait = true,
	deathwait = true,
	squadwait = true,
	gatherwait = true,
	loadonto = true,
	settargetnoground = true,
}

--------------------------------------------------------------------------------
-- locals
--------------------------------------------------------------------------------

local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitDefID     = Spring.GetUnitDefID
local spGetActiveCommand = Spring.GetActiveCommand
local spGetConfigInt     = Spring.GetConfigInt
local spGetMouseState    = Spring.GetMouseState
local spPlaySoundFile    = Spring.PlaySoundFile

local floor = math.floor
local concat = table.concat

local hud
local document
local view
local lastUpdate

local showHotkeys, showCost, showTechReq = true, true, true

local commandsDirty = true
local buildCards = {}   -- build commands in the order they are shown; card i has the id "b<i>"
local orderCards = {}   -- the same for orders, with the id "o<i>"
local buildSignature    -- what the build list's markup was made from
local orderSignature
local showBuild, showOrders = false, false
local activeCmdID

local lastHoverSound    -- id of the command the hover sound last played for
local hovered           -- {cards = buildCards or orderCards, index = n} while the mouse is on a card
local orderRect         -- {x1, y1, x2, y2} in screen pixels, y up
local buildRect

--------------------------------------------------------------------------------
-- hotkeys, from the build hotkeys widget's config
--------------------------------------------------------------------------------

VFS.Include("luaui/configs/evo_buildHotkeysConfig.lua")

local function GetKeySymbol(k)
	if k >= 97 and k <= 122 then
		return string.char(k):upper()
	end
	local keySymbol = Spring.GetKeySymbol(k)
	return keySymbol:sub(1, 1):upper() .. keySymbol:sub(2)
end

local nameToKeySymbols = {}
for unitDefID = 1, #UnitDefs do
	local ud = UnitDefs[unitDefID]
	local trimmedName = ud.name
	if trimmedName:find("_up", -5) then
		trimmedName = trimmedName:sub(1, -5)
	end
	if nameToKeyCode and nameToKeyCode[trimmedName] then
		local symbols = {}
		for i = 1, #nameToKeyCode[trimmedName] do
			symbols[i] = GetKeySymbol(nameToKeyCode[trimmedName][i])
		end
		nameToKeySymbols[ud.name] = symbols
	end
end

local function HotkeysActive()
	if not showHotkeys then
		return false
	end
	local order = widgetHandler.orderList and widgetHandler.orderList[HOTKEY_WIDGET]
	return order ~= nil and order ~= 0
end

-- the keys that build this, and whether the keys held so far lead to it
local function GetHotkey(cmd)
	local keys = nameToKeySymbols[cmd.name]
	if not keys then
		return nil, false
	end
	local pressed = WG.buildHotkeys and WG.buildHotkeys.keysPressed
	local matching = false
	if pressed then
		matching = true
		for i = 1, #keys do
			if i <= #pressed and keys[i] ~= pressed[i] then
				matching = false
				break
			end
		end
	end
	return concat(keys, "+"), matching
end

--------------------------------------------------------------------------------
-- what a build card says
--------------------------------------------------------------------------------

local function FormatCost(value)
	local n = tonumber(value)
	if not n then
		return tostring(value)
	end
	if n >= 1000 then
		return string.format("%.1fk", n / 1000)
	end
	return tostring(floor(n))
end

local function FormatSupply(value)
	if value == floor(value) then
		return tostring(floor(value))
	end
	return tostring(value)
end

-- returns metal, energy, supply, tech: each a string or nil
local function CardFigures(cmd)
	local metal, energy, supply, tech
	local tooltip = cmd.tooltip or ""

	if showCost then
		local ud = UnitDefs[-cmd.id]
		local cp = ud and ud.customParams
		if cp then
			local granted = tonumber(cp.supply_granted or cp.supplyGranted)
			local cost = tonumber(cp.supply_cost or cp.supplyCost)
			if granted and granted ~= 0 then
				supply = "+" .. FormatSupply(granted)
			elseif cost and cost ~= 0 then
				supply = "-" .. FormatSupply(cost)
			end
		end
		-- the costs come from the tooltip, which carries what the unit
		-- costs this player right now
		local value = tooltip:match("Metal cost (%d+)")
		if value then
			metal = FormatCost(value)
		end
		value = tooltip:match("Energy cost (%d+)")
		if value then
			energy = FormatCost(value)
		end
	end

	if showTechReq and (tooltip:find("Requires") or tooltip:find("Provides")) then
		local level = tooltip:match("tech(%d+)")
		if level then
			tech = "T" .. level
		end
	end

	return metal, energy, supply, tech
end

--------------------------------------------------------------------------------
-- sorting the commands
--------------------------------------------------------------------------------

local function ProducerFamily(unitRole)
	if unitRole == "Commander" or unitRole == "Builder" then
		return "Builder"
	elseif unitRole == "Factory" then
		return "Factory"
	end
	return nil
end

-- Reads the selection once: which families of producer are in it and what
-- each can build, and whether anything in it can build at all.
local function ReadSelection()
	local families = {
		Builder = {canBuild = {}, present = false},
		Factory = {canBuild = {}, present = false},
	}
	local selected = spGetSelectedUnits() or {}
	local hasProducer = false

	for i = 1, #selected do
		local unitDefID = spGetUnitDefID(selected[i])
		local ud = unitDefID and UnitDefs[unitDefID]
		if ud then
			local role = ud.customParams and ud.customParams.unitrole
			local family = ProducerFamily(role)
			if family then
				families[family].present = true
				if ud.buildOptions then
					for j = 1, #ud.buildOptions do
						families[family].canBuild[ud.buildOptions[j]] = true
					end
				end
			end
			if family or ud.isBuilder or (ud.buildOptions and #ud.buildOptions > 0) then
				hasProducer = true
			end
		end
	end

	return families, #selected > 0, hasProducer
end

local function BuildCategory(unitDefID)
	local ud = UnitDefs[unitDefID]
	return (ud and ud.customParams and ud.customParams.buildmenucategory) or "Unsorted"
end

-- Returns the sections of the build list: {title, categories = {{title, cmds}}}
local function SortBuildCommands(builds, families)
	local grouped = {Factory = {}, Builder = {}}
	local fallback = {}

	for i = 1, #builds do
		local cmd = builds[i]
		local unitDefID = -cmd.id
		local category = BuildCategory(unitDefID)
		local matched = false
		for _, family in ipairs({"Factory", "Builder"}) do
			if families[family].present and families[family].canBuild[unitDefID] then
				local known = false
				for _, name in ipairs(FAMILY_CATEGORY_ORDER[family]) do
					if name == category then
						known = true
						break
					end
				end
				local key = known and category or "Unsorted"
				grouped[family][key] = grouped[family][key] or {}
				table.insert(grouped[family][key], cmd)
				matched = true
			end
		end
		if not matched then
			fallback[#fallback + 1] = cmd
		end
	end

	local sections = {}
	for _, family in ipairs({"Factory", "Builder"}) do
		local categories = {}
		for _, name in ipairs(FAMILY_CATEGORY_ORDER[family]) do
			if grouped[family][name] then
				categories[#categories + 1] = {title = name, cmds = grouped[family][name]}
			end
		end
		if #categories > 0 then
			sections[#sections + 1] = {title = FAMILY_SECTION_TITLES[family], categories = categories}
		end
	end
	if #fallback > 0 then
		sections[#sections + 1] = {title = "Build List", categories = {{cmds = fallback}}}
	end
	return sections
end

--------------------------------------------------------------------------------
-- markup
--------------------------------------------------------------------------------

local function BuildCardRML(index, cmd, hotkeys)
	local metal, energy, supply, tech = CardFigures(cmd)
	local parts = {}
	parts[#parts + 1] = string.format('<div id="b%d" class="card" data-b="%d">', index, index)
	parts[#parts + 1] = hud.UnitPictureRML(-cmd.id, "pic")
	parts[#parts + 1] = string.format('<div id="b%d-q" class="queue hidden"/>', index)

	local key = hotkeys and GetHotkey(cmd)
	if metal or energy or supply or tech or key then
		parts[#parts + 1] = '<div class="info">'
		if metal or energy or supply then
			parts[#parts + 1] = '<div class="line">'
			if metal then
				parts[#parts + 1] = '<div class="metal">' .. metal .. '</div>'
			end
			if metal and energy then
				parts[#parts + 1] = '<div class="slash">/</div>'
			end
			if energy then
				parts[#parts + 1] = '<div class="energy">' .. energy .. '</div>'
			end
			parts[#parts + 1] = '<div class="grow"/>'
			if supply then
				parts[#parts + 1] = '<div class="supply">' .. supply .. '</div>'
			end
			parts[#parts + 1] = '</div>'
		end
		if key or tech then
			parts[#parts + 1] = '<div class="line">'
			if key then
				parts[#parts + 1] = string.format('<div id="b%d-k" class="key">%s</div>', index, hud.Escape(key))
			end
			parts[#parts + 1] = '<div class="grow"/>'
			if tech then
				parts[#parts + 1] = string.format('<div class="%s">%s</div>', tech:lower(), tech)
			end
			parts[#parts + 1] = '</div>'
		end
		parts[#parts + 1] = '</div>'
	end
	parts[#parts + 1] = '</div>'
	return concat(parts)
end

-- Rebuilds the build list's markup, but only when what it is made from has
-- changed; queue counts and the like are restated by RefreshCards instead.
local function ShowBuildList(sections)
	local hotkeys = HotkeysActive()
	local cards = {}
	local signature = {showCost and "c" or "-", showTechReq and "t" or "-", hotkeys and "h" or "-"}
	for _, section in ipairs(sections) do
		signature[#signature + 1] = "|" .. section.title
		for _, category in ipairs(section.categories) do
			signature[#signature + 1] = ":" .. (category.title or "")
			for _, cmd in ipairs(category.cmds) do
				cards[#cards + 1] = cmd
				-- the tooltip is part of it: that is where the costs come from
				signature[#signature + 1] = cmd.id .. "=" .. (cmd.tooltip or "")
			end
		end
	end
	buildCards = cards
	signature = concat(signature, "\n")
	if signature == buildSignature then
		return
	end
	buildSignature = signature

	local parts = {}
	local index = 0
	for s, section in ipairs(sections) do
		parts[#parts + 1] = string.format('<div class="section%s">%s</div>', s > 1 and " next" or "", hud.Escape(section.title))
		for _, category in ipairs(section.categories) do
			if category.title then
				parts[#parts + 1] = '<div class="category label">' .. hud.Escape(category.title) .. '</div>'
			end
			parts[#parts + 1] = '<div class="cards">'
			for _, cmd in ipairs(category.cmds) do
				index = index + 1
				parts[#parts + 1] = BuildCardRML(index, cmd, hotkeys)
			end
			parts[#parts + 1] = '</div>'
		end
	end

	local scroll = view.Element("build-scroll")
	if scroll then
		scroll.inner_rml = concat(parts)
	end
	view.Forget() -- the cards are new elements
	hovered = nil
end

-- red for the first state, through yellow, to green for the last
local function StateColor(position, count)
	local g = (count > 1) and ((position - 1) / (count - 1)) or 1
	local function Curve(c)
		return math.min(1, -0.5 * c * (c - 4))
	end
	return string.format("rgb(%d,%d,0)", floor(Curve(1 - g) * 255 + 0.5), floor(Curve(g) * 255 + 0.5))
end

local function OrderCardRML(index, cmd)
	local caption = cmd.name
	local states = ""
	local params = cmd.params or {}
	if #params > 1 then
		-- params: the state it is in (counted from 0), then every state's name
		local current = (tonumber(params[1]) or 0) + 1
		local count = #params - 1
		caption = params[current + 1] or cmd.name
		local bars = {}
		for i = 1, count do
			if i == current then
				bars[i] = string.format('<div class="st" style="background-color: %s;"/>', StateColor(i, count))
			else
				bars[i] = '<div class="st"/>'
			end
		end
		states = '<div class="states">' .. concat(bars) .. '</div>'
	elseif caption == "Repair" then
		caption = "Build" -- nothing is repaired in this game; the command helps build
	end
	return string.format('<div id="o%d" class="order%s" data-o="%d"><div class="cap">%s</div>%s</div>',
		index, cmd.disabled and " disabled" or "", index, hud.Escape(caption), states)
end

local function ShowOrders(cmds)
	orderCards = cmds
	local signature = {}
	for i, cmd in ipairs(cmds) do
		signature[i] = cmd.id .. "=" .. tostring(cmd.name) .. (cmd.disabled and "!" or "") .. concat(cmd.params or {}, ",")
	end
	signature = concat(signature, "\n")
	if signature == orderSignature then
		return
	end
	orderSignature = signature

	local parts = {}
	for i, cmd in ipairs(cmds) do
		parts[i] = OrderCardRML(i, cmd)
	end
	local grid = view.Element("order-grid")
	if grid then
		grid.inner_rml = concat(parts)
	end
	view.Forget()
	hovered = nil
end

--------------------------------------------------------------------------------
-- refreshing
--------------------------------------------------------------------------------

-- everything about a card that changes without the list changing
local function RefreshCards()
	local hotkeys = HotkeysActive()
	for i = 1, #buildCards do
		local cmd = buildCards[i]
		local id = "b" .. i
		local queued = tonumber(cmd.params and cmd.params[1]) or 0
		if queued > 0 then
			view.SetText(id .. "-q", tostring(floor(queued)))
		end
		view.SetClass(id .. "-q", "hidden", queued <= 0)
		view.SetClass(id, "disabled", cmd.disabled)
		view.SetClass(id, "active", cmd.id == activeCmdID)
		if hotkeys then
			local _, matching = GetHotkey(cmd)
			view.SetClass(id .. "-k", "match", matching)
		end
	end
	for i = 1, #orderCards do
		view.SetClass("o" .. i, "active", orderCards[i].id == activeCmdID)
	end
	view.SetClass("build", "hidden", not showBuild)
	view.SetClass("orders", "hidden", not showOrders)
end

local function ProcessCommands()
	commandsDirty = false
	showHotkeys = spGetConfigInt(SHOW_HOTKEYS_CONFIG, 1) == 1
	showCost    = spGetConfigInt(SHOW_COST_CONFIG, 1) == 1
	showTechReq = spGetConfigInt(SHOW_TECHREQ_CONFIG, 1) == 1

	local states, orders, builds = {}, {}, {}
	for _, cmd in ipairs(widgetHandler.commands or {}) do
		if cmd.name ~= "" and not (hiddenCMDs[cmd.name] or hiddenCMDs[cmd.action]) then
			if UnitDefNames[cmd.name] then
				builds[#builds + 1] = cmd
			elseif #cmd.params > 1 then
				states[#states + 1] = cmd
			else
				orders[#orders + 1] = cmd
			end
		end
	end

	-- states first, then orders, as many as the panel holds
	local merged = {}
	for _, list in ipairs({states, orders}) do
		for i = 1, #list do
			if #merged < MAX_ORDERS then
				merged[#merged + 1] = list[i]
			end
		end
	end

	local families, hasSelection, hasProducer = ReadSelection()
	if not hasSelection then
		showBuild, showOrders = false, false
	elseif hasProducer then
		showBuild, showOrders = #builds > 0, true
	else
		showBuild, showOrders = false, #merged > 0
	end

	ShowBuildList(SortBuildCommands(builds, families))
	ShowOrders(merged)
	if not showBuild and not showOrders then
		hovered = nil
	end
	RefreshCards()
end

--------------------------------------------------------------------------------
-- input
--------------------------------------------------------------------------------

local function HoveredCommand()
	local cmd = hovered and hovered.cards[hovered.index]
	if not cmd then
		return nil
	end
	local visible = (hovered.cards == buildCards and showBuild) or (hovered.cards == orderCards and showOrders)
	if not visible then
		return nil
	end
	return cmd
end

-- gives the command the way the engine's own menu would
local function ApplyCommand(cmd, button)
	local index = Spring.GetCmdDescIndex(cmd.id)
	if not index then
		return
	end
	local alt, ctrl, meta, shift = Spring.GetModKeyState()
	Spring.SetActiveCommand(index, button, button == 1, button == 3, alt, ctrl, meta, shift)
end

-- RmlUi numbers the buttons left 0, right 1, middle 2; the engine 1, 3, 2
local ENGINE_BUTTON = {[0] = 1, [1] = 3, [2] = 2}

local function Listen(containerId, attribute, cards)
	local container = view.Element(containerId)
	if not container then
		return
	end
	container:AddEventListener("mousedown", function(event)
		local index = hud.EventAttribute(event, attribute)
		local cmd = index and cards()[index]
		local button = ENGINE_BUTTON[event.parameters and event.parameters.button]
		if not cmd or cmd.disabled or not button then
			return
		end
		-- a click while the hotbind prompt is up cancels the prompt and does
		-- nothing else, so a mis-triggered capture never eats a build order
		local hotbind = WG.StaticHotbind
		if hotbind and hotbind.IsCapturing and hotbind.IsCapturing() then
			hotbind.Cancel()
			return
		end
		if button == 1 then
			spPlaySoundFile("leftclick", 1.0, "ui")
		elseif button == 3 then
			spPlaySoundFile("rightclick", 1.0, "ui")
		end
		ApplyCommand(cmd, button)
	end)
	container:AddEventListener("mouseover", function(event)
		local index = hud.EventAttribute(event, attribute)
		local list = cards()
		local cmd = index and list[index]
		if not cmd then
			hovered = nil
			return
		end
		hovered = {cards = list, index = index}
		-- moving within one card leaves and re-enters it: one sound per card
		if not cmd.disabled and cmd.id ~= lastHoverSound then
			spPlaySoundFile("hover", 1.0, "ui")
		end
		lastHoverSound = cmd.id
	end)
	container:AddEventListener("mouseout", function()
		hovered = nil
	end)
end

local function InRect(rect, x, y)
	return rect and x >= rect[1] and x <= rect[3] and y >= rect[2] and y <= rect[4]
end

--------------------------------------------------------------------------------
-- placement
--------------------------------------------------------------------------------

local function OrderOrigin(vsx, vsy, w, h, scale)
	return MARGIN * scale, MARGIN * scale
end

-- above the order panel's default spot, not its moved one, so that moving one
-- panel never drags the other along
local function BuildOrigin(vsx, vsy, w, h, scale)
	return MARGIN * scale, (MARGIN + ORDER_HEIGHT + PANEL_GAP) * scale
end

local function Place()
	local x, y, w, h = hud.PlacePanel(view.Element("orders"), LAYOUT_ORDER, PANEL_WIDTH, ORDER_HEIGHT, OrderOrigin)
	orderRect = x and {x, y, x + w, y + h}
	x, y, w, h = hud.PlacePanel(view.Element("build"), LAYOUT_BUILD, PANEL_WIDTH, BUILD_HEIGHT, BuildOrigin)
	buildRect = x and {x, y, x + w, y + h}
	-- the tooltip panel sits beside the order panel
	local tooltip = WG.StaticTooltip
	if tooltip and tooltip.Relayout then
		tooltip.Relayout()
	end
end

--------------------------------------------------------------------------------
-- the engine's own command menu is replaced by this one
--------------------------------------------------------------------------------

local function OverrideDefaultMenu()
	local function layoutHandler(xIcons, yIcons, cmdCount, commands)
		widgetHandler.commands = commands
		widgetHandler.commands.n = cmdCount
		widgetHandler:CommandsChanged()
		local customCmds = widgetHandler.customCommands
		return "", xIcons, yIcons, {}, customCmds, {}, {}, {}, {}, {}, {[1337] = 9001}
	end
	widgetHandler:ConfigLayoutHandler(layoutHandler)
	Spring.ForceLayoutUpdate()
end

--------------------------------------------------------------------------------
-- widget api
--------------------------------------------------------------------------------

function widget:Initialize()
	local helpers = include("rml/hud.lua")
	local result, reason = helpers.LoadDocument(DOCUMENT_PATH, widget)
	if not result then
		Spring.Echo("[Build/Order Menu] " .. tostring(reason))
		widgetHandler:RemoveWidget(self)
		return
	end
	hud = helpers
	document = result

	view = hud.NewView(document)
	view.Assume("build", "hidden", true) -- set in the markup
	view.Assume("orders", "hidden", true)

	Listen("build-scroll", "data-b", function() return buildCards end)
	Listen("order-grid", "data-o", function() return orderCards end)

	-- What the hotbind widget and the tooltip panel ask of this widget.
	WG.StaticBuildOrderMenu = {
		-- the command under the mouse and whether it is disabled, or nil
		GetHovered = function()
			local cmd = HoveredCommand()
			if not cmd then
				return nil
			end
			return cmd, (cmd.disabled and true or false)
		end,
		-- the order panel's rectangle in screen pixels (y up)
		GetOrderRect = function()
			if orderRect then
				return orderRect[1], orderRect[2], orderRect[3], orderRect[4]
			end
		end,
		-- nil while the mouse is off both panels; otherwise the tooltip of the
		-- command under it, or "" between the cards. The engine cannot supply
		-- this: it does not look at widgets while the mouse is on an RmlUi
		-- element.
		GetTooltip = function()
			if not document or Spring.IsGUIHidden() then
				return nil
			end
			local mx, my = spGetMouseState()
			if not ((showOrders and InRect(orderRect, mx, my)) or (showBuild and InRect(buildRect, mx, my))) then
				return nil
			end
			local cmd = HoveredCommand()
			if not cmd then
				return ""
			end
			return (string.gsub(cmd.tooltip or "", "Metal cost %d*\nEnergy cost %d*\n", ""))
		end,
	}

	hud.RegisterPanel(LAYOUT_ORDER, "Order Menu", Place)
	hud.RegisterPanel(LAYOUT_BUILD, "Build Menu", Place)
	Place()

	-- the options window sets this flag when one of the three card options
	-- (costs, tech requirement, hotkeys) is changed
	WG.buildOrderUI = WG.buildOrderUI or {}

	OverrideDefaultMenu()
	ProcessCommands()
	hud.ShowPassive(document)
	lastUpdate = Spring.GetTimer()
end

function widget:Shutdown()
	WG.StaticBuildOrderMenu = nil
	WG.buildOrderUI = nil
	if hud then
		hud.UnregisterPanel(LAYOUT_ORDER)
		hud.UnregisterPanel(LAYOUT_BUILD)
	end
	if document then
		document:Close()
		document = nil
		widgetHandler:ConfigLayoutHandler(nil)
		Spring.ForceLayoutUpdate()
	end
end

function widget:ViewResize()
	if hud and document then
		hud.UpdateScale()
		Place()
	end
end

function widget:CommandsChanged()  commandsDirty = true end
function widget:SelectionChanged() commandsDirty = true end
function widget:UnitCreated()      commandsDirty = true end
function widget:UnitDestroyed()    commandsDirty = true end
function widget:UnitGiven()        commandsDirty = true end
function widget:UnitTaken()        commandsDirty = true end

function widget:Update()
	if not document then
		return
	end
	if hud.FollowGuiHidden(document) then
		hovered = nil
		return -- hidden with the rest of the GUI (F5)
	end

	if not hovered then
		lastHoverSound = nil
	end
	if WG.buildOrderUI and WG.buildOrderUI.updateConfigInt then
		WG.buildOrderUI.updateConfigInt = nil
		commandsDirty = true
	end

	local _, cmdID = spGetActiveCommand()
	local now = Spring.GetTimer()
	if commandsDirty then
		activeCmdID = cmdID
		lastUpdate = now
		ProcessCommands()
	elseif cmdID ~= activeCmdID or Spring.DiffTimers(now, lastUpdate) >= UPDATE_INTERVAL then
		activeCmdID = cmdID
		lastUpdate = now
		RefreshCards()
	end
end
