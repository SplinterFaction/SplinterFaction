--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Build and order menus of the RmlUi HUD.
--
--  Two panels at the bottom left. The order panel holds the selected units'
--  commands, five to a row; a command with states (fire at will, hold fire...)
--  names the state it is in. The build panel lists what the selection can
--  build, sorted the way the unit defs ask for (customParams.buildmenucategory)
--  under "Factory Units" and "Structures". A row of tabs at the top of the
--  build panel, "All" and one per category on offer, narrows the list to one
--  category; the list scrolls, it is never paged. A checkbox under the list
--  hides what cannot be built right now (the cards that would be greyed out).
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
local buildTabs = {}    -- the tabs above the build list: [1] is "All" (false), the rest category titles
local tabsSignature     -- what the tabs' markup was made from
local tabsCategories    -- the categories on offer, joined: the filter goes back to "All" when this changes
local buildFilter       -- the category the list is narrowed to, or nil for all
local lastSections      -- the sections ShowBuildList was last given
local sharedItems = {}  -- the shared queue strip's items, in the order shown (linked factories)
local hideUnavailable = false -- leave out the cards that cannot be built right now (saved with the widget)
local hasBuilderMenu = false  -- the build list holds a builder's buildings (not only a factory's units)
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

-- The tabs above the list: "All", then every category on offer in the order
-- the list shows them (a category both families have is one tab). With fewer
-- than two categories there is nothing to choose between and the row is hidden.
-- `sections` is everything the selection can build, `visible` what is left of
-- it to show: a category with nothing left to show gets no tab.
-- Returns the category to narrow the list to, or nil for all of it.
local function ShowBuildTabs(sections, visible)
	local function Titles(list)
		local titles, seen = {false}, {}
		for _, section in ipairs(list) do
			for _, category in ipairs(section.categories) do
				if category.title and not seen[category.title] then
					seen[category.title] = true
					titles[#titles + 1] = category.title
				end
			end
		end
		return titles, seen
	end
	-- A different set of categories is a different kind of builder: start on
	-- "All" again. Nothing on offer (nothing selected, or a list without
	-- categories) is not a different set: coming back to the same kind of
	-- builder finds the list as it was left. This goes by everything the
	-- builder can build, so a category coming into reach changes nothing.
	local categories = concat(Titles(sections), "\n", 2)
	if categories ~= "" and categories ~= tabsCategories then
		tabsCategories = categories
		buildFilter = nil
	end
	local tabs, seen = Titles(visible)
	buildTabs = tabs
	local filter = (buildFilter and seen[buildFilter]) and buildFilter or nil

	local signature = concat(tabs, "\n", 2) .. "\n=" .. tostring(filter)
	if signature == tabsSignature then
		return filter
	end
	tabsSignature = signature

	local parts = {}
	if #tabs > 2 then
		for i, title in ipairs(tabs) do
			local active = (title or nil) == filter
			parts[i] = string.format('<div class="tab%s" data-tab="%d">%s</div>',
				active and " active" or "", i, hud.Escape(title or "All"))
		end
	end
	local row = view.Element("build-tabs")
	if row then
		row.inner_rml = concat(parts)
	end
	view.SetClass("build-tabs", "hidden", #parts == 0)
	return filter
end

-- Rebuilds the build list's markup, but only when what it is made from has
-- changed; queue counts and the like are restated by RefreshCards instead.
local function ShowBuildList(sections)
	lastSections = sections

	-- without what cannot be built right now, if the player asked for that
	local visible = sections
	if hideUnavailable then
		visible = {}
		for _, section in ipairs(sections) do
			local categories = {}
			for _, category in ipairs(section.categories) do
				local cmds = {}
				for _, cmd in ipairs(category.cmds) do
					if not cmd.disabled then
						cmds[#cmds + 1] = cmd
					end
				end
				if #cmds > 0 then
					categories[#categories + 1] = {title = category.title, cmds = cmds}
				end
			end
			if #categories > 0 then
				visible[#visible + 1] = {title = section.title, categories = categories}
			end
		end
	end

	local filter = ShowBuildTabs(sections, visible)
	sections = visible

	-- narrowed to one category: only its cards, and no heading the tab already gives
	if filter then
		local narrowed = {}
		for _, section in ipairs(sections) do
			for _, category in ipairs(section.categories) do
				if category.title == filter then
					narrowed[#narrowed + 1] = {title = section.title, categories = {{cmds = category.cmds}}}
				end
			end
		end
		if #narrowed == 1 then
			narrowed[1].title = nil -- one family: the tab says it all
		end
		sections = narrowed
	end

	local hotkeys = HotkeysActive()
	local cards = {}
	local signature = {showCost and "c" or "-", showTechReq and "t" or "-", hotkeys and "h" or "-", hideUnavailable and "u" or "-"}
	for _, section in ipairs(sections) do
		signature[#signature + 1] = "|" .. (section.title or "")
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
		if section.title then
			parts[#parts + 1] = string.format('<div class="section%s">%s</div>', s > 1 and " next" or "", hud.Escape(section.title))
		end
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

	if index == 0 and hideUnavailable then
		parts[#parts + 1] = '<div class="empty label">Nothing here can be built yet</div>'
	end

	local scroll = view.Element("build-scroll")
	if scroll then
		scroll.inner_rml = concat(parts)
	end
	view.Forget() -- the cards are new elements
	hovered = nil
end

-- Narrows the build list to one category (by its title), or shows all of it
-- (nil). A category that is not on offer shows all. Returns what it was set to.
local function SetBuildCategory(title)
	local filter = nil
	for i = 2, #buildTabs do
		if buildTabs[i] == title then
			filter = title
		end
	end
	if filter ~= buildFilter then
		buildFilter = filter
		if lastSections then
			ShowBuildList(lastSections)
		end
		commandsDirty = true -- queue counts and the active card, on the new cards
	end
	return buildFilter
end

-- Shows or hides the cards that cannot be built right now. Returns the setting.
local function SetHideUnavailable(hide)
	hide = hide and true or false
	if hide ~= hideUnavailable then
		hideUnavailable = hide
		if lastSections then
			ShowBuildList(lastSections)
		end
		commandsDirty = true
	end
	if view then
		view.SetClass("build-hide", "on", hideUnavailable)
	end
	return hideUnavailable
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
-- the shared queue of linked factories, above the build list
--------------------------------------------------------------------------------

local SHARED_MAX = 8 -- as many as the row holds

-- pool: what WG.factoryLink.Counts() returns second, or nil to hide the strip
local function ShowSharedQueue(pool)
	view.SetClass("build-link", "hidden", pool == nil)
	if not pool then
		sharedItems = {}
		return
	end
	sharedItems = pool.items
	view.SetText("build-link-head", string.format('Shared queue <span class="dim">&#183; %d factories%s</span>',
		pool.factories, pool.rep and " &#183; repeat" or ""))
	local parts = {}
	for i = 1, math.min(#pool.items, SHARED_MAX) do
		local item = pool.items[i]
		parts[#parts + 1] = string.format('<div class="lq%s" data-l="%d">%s<div class="lqn">%d</div></div>',
			item.building and " now" or "", i, hud.UnitPictureRML(item.def, "lqpic"), item.count)
	end
	if #pool.items > SHARED_MAX then
		parts[#parts + 1] = string.format('<div class="lqmore">+%d</div>', #pool.items - SHARED_MAX)
	elseif #pool.items == 0 then
		parts[#parts + 1] = '<div class="lqmore">Nothing queued</div>'
	end
	view.SetText("build-link-row", concat(parts))
end

--------------------------------------------------------------------------------
-- refreshing
--------------------------------------------------------------------------------

-- everything about a card that changes without the list changing
local function RefreshCards()
	local hotkeys = HotkeysActive()
	-- linked factories share a queue (cmd_factory_link.lua): the cards count
	-- what the group has queued, not what the one factory holds
	local link = WG.factoryLink
	local shared, pool
	if link and showBuild then
		shared, pool = link.Counts()
	end
	ShowSharedQueue(pool)
	-- Global Build's board mode: the switch, the orange frame, and the cards no
	-- builder on the board can build
	local board = WG.globalBuild
	local canSwitch = board ~= nil and board.GetMode ~= nil and hasBuilderMenu
	local boardMode = canSwitch and board.GetMode() or false
	view.SetClass("build-head", "hidden", not canSwitch)
	view.SetClass("build", "global", boardMode)
	view.SetClass("build-global", "on", boardMode)
	view.SetText("build-title", boardMode and "Global build: to the board" or "Build")
	for i = 1, #buildCards do
		local cmd = buildCards[i]
		local id = "b" .. i
		local ud = boardMode and cmd.id < 0 and UnitDefs[-cmd.id]
		cmd.noboard = (ud and not ud.canMove and board.Capable(-cmd.id) == 0) or false
		view.SetClass(id, "noboard", cmd.noboard)
		local queued = tonumber(cmd.params and cmd.params[1]) or 0
		if shared then
			queued = shared[-cmd.id] or 0
		end
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

	-- the engine's commands, then the ones widgets add (Link and Unlink)
	local all = {}
	for _, cmd in ipairs(widgetHandler.commands or {}) do
		all[#all + 1] = cmd
	end
	for _, cmd in ipairs(widgetHandler.customCommands or {}) do
		if cmd.id and cmd.name then
			cmd.params = cmd.params or {}
			all[#all + 1] = cmd
		end
	end
	-- repeat on linked factories belongs to their group, not to the factory
	local link = WG.factoryLink
	local pool = link and link.SelectionPool()

	local states, orders, builds = {}, {}, {}
	for _, cmd in ipairs(all) do
		if pool and cmd.id == CMD.REPEAT and #cmd.params > 1 then
			local copy = {}
			for key, value in pairs(cmd) do copy[key] = value end
			copy.params = {}
			for i = 1, #cmd.params do copy.params[i] = cmd.params[i] end
			copy.params[1] = pool.rep and 1 or 0
			cmd = copy
		end
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
	hasBuilderMenu = families.Builder.present
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
	-- Global Build. Board mode (the GLOBAL switch) sends every building placed to
	-- the board, and Alt + click then orders the selected builder itself, that
	-- once. Out of board mode it is the other way round: Alt + click places for
	-- the board.
	local board = WG.globalBuild
	local ud = cmd.id < 0 and UnitDefs[-cmd.id]
	if board and button == 1 and ud and not ud.canMove then
		if board.GetMode and board.GetMode() then
			if alt then
				board.DirectOnce(-cmd.id)
			elseif cmd.noboard then
				Spring.Echo("[Global Build] no builder on the board can build " .. (ud.humanName or ud.name))
				return
			end
			alt = false
		elseif alt then
			local x, z
			local first = (spGetSelectedUnits() or {})[1]
			if first then
				local ux, _, uz = Spring.GetUnitPosition(first)
				x, z = ux, uz
			end
			if board.StartSession(-cmd.id, x, z) then
				return
			end
		end
	end
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
	view.Assume("build-link", "hidden", true)

	Listen("build-scroll", "data-b", function() return buildCards end)

	local tabRow = view.Element("build-tabs")
	if tabRow then
		tabRow:AddEventListener("mousedown", function(event)
			local index = hud.EventAttribute(event, "data-tab")
			if index and buildTabs[index] ~= nil and event.parameters and event.parameters.button == 0 then
				spPlaySoundFile("leftclick", 1.0, "ui")
				SetBuildCategory(buildTabs[index] or nil)
			end
		end)
	end
	Listen("order-grid", "data-o", function() return orderCards end)

	-- right click on the shared queue takes one away (Shift 5, Ctrl 20)
	local linkRow = view.Element("build-link-row")
	if linkRow then
		linkRow:AddEventListener("mousedown", function(event)
			local index = hud.EventAttribute(event, "data-l")
			local item = index and sharedItems[index]
			if item and WG.factoryLink and event.parameters and event.parameters.button == 1 then
				local _, ctrl, _, shift = Spring.GetModKeyState()
				spPlaySoundFile("rightclick", 1.0, "ui")
				WG.factoryLink.Remove(item.def, (shift and 5 or 1) * (ctrl and 20 or 1))
				lastUpdate = nil
			end
		end)
	end

	local hideBox = view.Element("build-hide")
	if hideBox then
		hideBox:AddEventListener("mousedown", function(event)
			if event.parameters and event.parameters.button == 0 then
				spPlaySoundFile("leftclick", 1.0, "ui")
				SetHideUnavailable(not hideUnavailable)
			end
		end)
	end
	view.SetClass("build-hide", "on", hideUnavailable)

	-- the GLOBAL switch: Global Build's board mode
	view.Assume("build-head", "hidden", true)
	local globalSwitch = view.Element("build-global")
	if globalSwitch then
		globalSwitch:AddEventListener("mousedown", function(event)
			local board = WG.globalBuild
			if board and board.SetMode and event.parameters and event.parameters.button == 0 then
				spPlaySoundFile("leftclick", 1.0, "ui")
				board.SetMode(not board.GetMode())
				lastUpdate = nil
			end
		end)
	end

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
		-- the build list's category tabs: the titles on offer (without "All"),
		-- the one it is narrowed to (nil for all), and a way to set it
		GetBuildCategories = function()
			local titles = {}
			for i = 2, #buildTabs do
				titles[#titles + 1] = buildTabs[i]
			end
			return titles, buildFilter
		end,
		SetBuildCategory = SetBuildCategory,
		-- whether the cards that cannot be built right now are left out
		GetHideUnavailable = function() return hideUnavailable end,
		SetHideUnavailable = SetHideUnavailable,
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
			local text = string.gsub(cmd.tooltip or "", "Metal cost %d*\nEnergy cost %d*\n", "")
			if cmd.noboard then
				text = text .. "\nNo builder on the board can build this (commanders and builders kept off the board do not count). Alt+click orders the selected builder."
			end
			return text
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

function widget:GetConfigData()
	return { hideUnavailable = hideUnavailable }
end

function widget:SetConfigData(data)
	if type(data) == "table" and data.hideUnavailable ~= nil then
		hideUnavailable = data.hideUnavailable and true or false
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
	elseif cmdID ~= activeCmdID or not lastUpdate or Spring.DiffTimers(now, lastUpdate) >= UPDATE_INTERVAL then
		activeCmdID = cmdID
		lastUpdate = now
		RefreshCards()
	end
end
