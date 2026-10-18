--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Tooltip panel of the RmlUi HUD, and its Additional Info panel.
--
--  The tooltip sits beside the order menu and describes, in this order of
--  preference: the unit or wreck under the mouse, the build card or order
--  button under the mouse, or the selection. Health, shields, status and
--  income of a unit are live.
--
--  Spacebar toggles Additional Info, a second panel above the tooltip with
--  the unit's picture, build figures, weapons and guide text.
--
--  Replaces gui_static_tooltip_panel.lua and gui_static_additionalinfo.lua
--  (both kept in Widgets/disabled/). The functions that read the game (the
--  weapon cards and the panel data builders) are carried over from the old
--  tooltip unchanged; what is new is how the result is shown.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name    = "Bastion Tooltip Panel",
		previousNames = {"Tooltip Panel"},
		desc    = "Panel-style tooltip with a spacebar-toggled Additional Info panel (RmlUi)",
		author  = "SplinterFaction Team",
		date    = "2026-10-12",
		license = "GNU GPL, v2 or later",
		layer   = 2,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- config
--------------------------------------------------------------------------------

local DOCUMENT_PATH = "LuaUI/rml/tooltip.rml"

-- must match #tooltip and #additional in tooltip.rml
local PANEL_WIDTH       = 320
local TOOLTIP_HEIGHT    = 212
local ADDITIONAL_HEIGHT = 534
local PANEL_GAP         = 10
local MARGIN            = 8  -- the order menu's own margin, used when it is not running

-- same names as the old widgets, so positions saved in tweak mode carry over
local LAYOUT_TOOLTIP    = "tooltip"
local LAYOUT_ADDITIONAL = "additionalinfo"

local TOOLTIP_HINT_TEXT    = "Press Spacebar for Additional Info"
local ADDITIONAL_HINT_TEXT = "Press Spacebar to toggle off/on"

local KEY_SPACE = 32

--------------------------------------------------------------------------------
-- locals
--------------------------------------------------------------------------------

local spGetCurrentTooltip      = Spring.GetCurrentTooltip
local spGetMouseState          = Spring.GetMouseState
local spTraceScreenRay         = Spring.TraceScreenRay
local spGetSelectedUnits       = Spring.GetSelectedUnits
local spGetUnitDefID           = Spring.GetUnitDefID
local spGetUnitResources       = Spring.GetUnitResources
local spGetUnitHealth          = Spring.GetUnitHealth
local spGetUnitShieldState     = Spring.GetUnitShieldState
local spGetUnitRulesParam      = Spring.GetUnitRulesParam
local spGetUnitIsCloaked       = Spring.GetUnitIsCloaked
local spGetUnitIsStunned       = Spring.GetUnitIsStunned
local spGetFeatureDefID        = Spring.GetFeatureDefID
local spGetFeatureResources    = Spring.GetFeatureResources
local spGetFeatureHealth       = Spring.GetFeatureHealth
local spGetKeySymbol           = Spring.GetKeySymbol
local spPlaySoundFile          = Spring.PlaySoundFile

local math_floor    = math.floor
local math_min      = math.min
local math_abs      = math.abs
local string_format = string.format
local string_match  = string.match
local string_gsub   = string.gsub
local string_lower  = string.lower
local table_concat  = table.concat

local hud
local document
local view

local showAdditional = false -- the spacebar toggle

local shownKey        -- what the panels currently describe (see ResolvedKey)
local shownResolved
local panelData       -- built from it by the data builders below
local isOrder = false
local liveUnitID      -- the unit whose live values are restated every frame
local liveFeatureID
local shownShape           -- what the panels' markup was made from (see Show)
local tooltipSignature     -- the markup each panel currently has
local additionalSignature

local orderRect            -- rectangles in screen pixels, y up
local tooltipRect
local additionalRect
local lastOrderX, lastOrderY

--------------------------------------------------------------------------------
-- hotkeys, from the build hotkeys widget's config
--------------------------------------------------------------------------------

VFS.Include("luaui/configs/evo_buildHotkeysConfig.lua")

local function GetKeySymbol(k)
	if k >= 97 and k <= 122 then
		return string.char(k):upper()
	end
	local keySymbol = spGetKeySymbol(k)
	return keySymbol:sub(1, 1):upper() .. keySymbol:sub(2)
end

local humanNameToKeySymbols = {}
for unitDefID = 1, #UnitDefs do
	local ud = UnitDefs[unitDefID]
	local name = ud.name
	if name:find("_up", -5) then
		name = name:sub(1, -5)
	end
	if nameToKeyCode and nameToKeyCode[name] then
		local parts = {}
		for i = 1, #nameToKeyCode[name] do
			parts[#parts + 1] = GetKeySymbol(nameToKeyCode[name][i])
		end
		humanNameToKeySymbols[ud.humanName] = table_concat(parts, " + ")
	end
end

--------------------------------------------------------------------------------
-- reading the game: carried over from gui_static_tooltip_panel.lua
--------------------------------------------------------------------------------

local TECH_REQUIREMENT_MAP = {
	tech0 = "T0",
	tech1 = "T1",
	tech2 = "T2",
	tech3 = "T3",
	tech4 = "T4",
}

local function FormatNbr(x, digits)
	if x == nil then return "" end
	local ret = string_format("%." .. (digits or 0) .. "f", x)
	if digits and digits > 0 then
		while true do
			local last = ret:sub(#ret, #ret)
			if last == "0" or last == "." then
				ret = ret:sub(1, #ret - 1)
			end
			if last ~= "0" then
				break
			end
		end
	end
	return ret
end

local function GetTooltipRole(ud)
	local str = ud and ud.customParams and ud.customParams.buildmenucategory
	if not str or str == "" then
		return "Unsorted"
	end
	return str
end

local function GetTechTag(ud)
	if not ud or not ud.customParams then return nil end
	local req = ud.customParams.techlevel or ud.customParams.requiretech
	if not req then return nil end
	return TECH_REQUIREMENT_MAP[string_lower(tostring(req))]
end

local function GetBuildPowerTotal()
	local buildpower = 1
	local sel = spGetSelectedUnits()
	for i = 1, #sel do
		local unitDefID = spGetUnitDefID(sel[i])
		if unitDefID then
			local def = UnitDefs[unitDefID]
			if def then
				buildpower = buildpower + (def.buildSpeed or 0)
			end
		end
	end
	return buildpower
end

local function GetTooltipBuildPower(buildSpeed)
	if not buildSpeed or buildSpeed <= 0 then return nil end
	return FormatNbr(buildSpeed, 0)
end

local function FormatSupplyValue(v)
	if not v then return nil end
	if v == math_floor(v) then
		return tostring(math_floor(v))
	end
	return tostring(v)
end

local function BuildWeaponCards(ud)
	local cards = {}
	if not ud or not ud.weapons then
		return cards
	end

	local dedupe = {}

	for _, w in pairs(ud.weapons) do
		local weap = WeaponDefs[w.weaponDef]
		if weap and not weap.isShield and weap.description ~= "No Weapon" then
			local key = weap.description or weap.name or ("weapon_" .. tostring(w.weaponDef))
			local card = dedupe[key]

			if not card then
				local reloadTime = (weap.reload and weap.reload > 0) and weap.reload or 1
				local burst = (weap.projectiles or 1) * (weap.salvoSize or 1)
				local dpsConversion = burst / reloadTime
				local damage = (weap.damages and weap.damages[Game.armorTypes.default] or 0) * burst
				local dps = damage / reloadTime
				local energyPerSecond = (weap.energyCost or 0) * dpsConversion
				local isDisruptor = weap.damages and weap.damages.paralyzeDamageTime and weap.damages.paralyzeDamageTime > 0
				local isDisrupt   = weap.customParams and weap.customParams.disruptionweapon and weap.customParams.disruptionweapon ~= "0"
				local isHeat      = weap.customParams and weap.customParams.heatweapon      and weap.customParams.heatweapon      ~= "0"

				card = {
					title    = key,
					count    = 1,
					perShot  = damage,
					dps      = dps,
					aoe      = weap.damageAreaOfEffect or 0,
					range    = weap.range or 0,
					eps      = energyPerSecond,
					paralyze = isDisruptor,
					disrupt  = isDisrupt,
					heat     = isHeat,
					reload   = reloadTime,
					water    = weap.waterWeapon and true or false,
					guide    = (weap.customParams and weap.customParams.weaponguide) or nil,
				}
				dedupe[key] = card
				cards[#cards + 1] = card
			else
				card.count = card.count + 1
				if (not card.guide or card.guide == "") and weap.customParams and weap.customParams.weaponguide then
					card.guide = weap.customParams.weaponguide
				end
			end
		end
	end

	return cards
end

local function ResolveHoveredWorldObject()
	local mx, my = spGetMouseState()
	local kind, id = spTraceScreenRay(mx, my, false, true)
	if kind == "unit" then
		return "unit", id
	elseif kind == "feature" then
		return "feature", id
	end
	return nil, nil
end

local function ResolveHoveredBuildFromTooltip(currentTooltip)
	local unitname = string_match(currentTooltip, "Build: (.-) %- ")
	local unitdesc = string_match(currentTooltip, " %- (.+)\nHealth ")
	local unithealth = string_match(currentTooltip, "Health (.+)\nMetal") or string_match(currentTooltip, "Health (.+)\nBuild time ")
	local unitbuildtime = string_match(currentTooltip .. "\n", "Build time (.-)\n")
	local unitmetalcost = string_match(currentTooltip, "Metal cost (.-)\nEnergy cost ")
	local unitenergycost = string_match(currentTooltip, "\nEnergy cost (.-).Build time ")

	if not (unitname and unitdesc and unithealth and unitbuildtime) then
		return nil
	end

	local fud = nil
	for _, ud in pairs(UnitDefs) do
		if ud.humanName == unitname and ud.tooltip == unitdesc and math_abs((ud.health or 0) - tonumber(unithealth or 0)) <= 1 then
			fud = ud
			break
		end
	end

	return {
		type = "build",
		ud = fud,
		name = unitname,
		desc = unitdesc,
		health = tonumber(unithealth),
		buildTime = tonumber(unitbuildtime),
		metalCost = tonumber(unitmetalcost) or (fud and fud.metalCost or 0),
		energyCost = tonumber(unitenergycost) or (fud and fud.energyCost or 0),
	}
end

local function ResolveOrderFromTooltip(currentTooltip)
	if currentTooltip == "" then
		return nil
	end

	if currentTooltip:find("Build: ") then
		return nil
	end

	-- Suppress engine terrain/position tooltips — these change every pixel of
	-- mouse movement and should not trigger panel rendering or cache rebuilds.
	if currentTooltip:find("^Pos ") or currentTooltip:find("^Position") or
			currentTooltip:find("^Elevation") or currentTooltip:find("^Height") or
			currentTooltip:find("^%(") then
		return nil
	end

	-- Suppress engine unit-info tooltips (shown when hovering/selecting units).
	-- These contain "Health" and "Experience" lines and are not order commands.
	if currentTooltip:find("\nHealth ") or currentTooltip:find("\nExperience ") then
		return nil
	end

	local firstLine = string_match(currentTooltip, "([^\n]+)")
	if not firstLine then
		return nil
	end

	local title = firstLine
	local body = currentTooltip
	local action = string_match(firstLine, "^(.-):")
	if action then
		title = action
	end

	return {
		type = "order",
		title = title,
		body = body,
	}
end

-- Refresh only the live-changing fields on a unit panel (health, shield,
-- resources, status) without rebuilding weapons/guide/wrapped text.
-- Called every frame when the same unit stays hovered.
local function RefreshLiveUnitFields(panelData, unitID)
	local ud = UnitDefs[spGetUnitDefID(unitID)]
	if not ud then return end

	local metalMake, metalUse, energyMake, energyUse = spGetUnitResources(unitID)
	local health, maxHealth, _, _, buildProgress      = spGetUnitHealth(unitID)
	local _, stunned, beingBuilt                      = spGetUnitIsStunned(unitID)
	local hasShield, shieldPower                      = spGetUnitShieldState(unitID)
	local maxShieldPower = ud.shieldWeaponDef and WeaponDefs[ud.shieldWeaponDef]
			and WeaponDefs[ud.shieldWeaponDef].shieldPower or nil
	local overshieldStrength = spGetUnitRulesParam(unitID, "personalShield")
	-- Live, upgrade-aware max published by the shields gadget (armor upgrades
	-- raise it); the unitdef customparam is only the pre-upgrade fallback.
	local shieldMaxStrength  = spGetUnitRulesParam(unitID, "personalShieldMax")
			or tonumber(ud.customParams and ud.customParams.shield_max_strength)

	panelData.healthText = health and (FormatNbr(health, 0) .. "/" .. FormatNbr(maxHealth, 0)) or nil

	panelData.shieldText = (hasShield and maxShieldPower)
			and (FormatNbr(math_min(shieldPower, maxShieldPower), 0) .. "/" .. FormatNbr(maxShieldPower, 0))
			or nil

	panelData.overshieldText = (overshieldStrength and shieldMaxStrength)
			and (FormatNbr(math_min(overshieldStrength, shieldMaxStrength), 0) .. "/" .. FormatNbr(shieldMaxStrength, 0))
			or nil

	local status = {}
	if stunned then status[#status + 1] = "Paralyzed" end
	if beingBuilt or (buildProgress and buildProgress < 1) then status[#status + 1] = "Building" end
	if spGetUnitIsCloaked(unitID) then status[#status + 1] = "Cloaked" end
	panelData.statusText = (#status > 0) and table_concat(status, ", ") or nil

	if metalMake ~= nil then
		local netMetal  = metalMake  - metalUse
		local netEnergy = energyMake - energyUse
		panelData.metalFlowText  = (netMetal  >= 0 and "+" or "") .. FormatNbr(netMetal,  1)
		panelData.energyFlowText = (netEnergy >= 0 and "+" or "") .. FormatNbr(netEnergy, 1)
	end
end

local function RefreshLiveFeatureFields(panelData, featureID)
	local metal, _, energy, _, reclaimLeft = spGetFeatureResources(featureID)
	local health, maxHealth = spGetFeatureHealth(featureID)
	panelData.healthText    = health and maxHealth and (FormatNbr(health, 0) .. "/" .. FormatNbr(maxHealth, 0)) or nil
	panelData.metalCostText  = metal    and FormatNbr(metal,  0) or "-"
	panelData.energyCostText = energy   and FormatNbr(energy, 0) or "-"
end

local function BuildUnitPanelData(unitID)
	local ud = UnitDefs[spGetUnitDefID(unitID)]
	if not ud then return nil end

	local metalMake, metalUse, energyMake, energyUse = spGetUnitResources(unitID)
	local health, maxHealth, _, _, buildProgress = spGetUnitHealth(unitID)
	local _, stunned, beingBuilt = spGetUnitIsStunned(unitID)
	local hasShield, shieldPower = spGetUnitShieldState(unitID)
	local maxShieldPower = ud.shieldWeaponDef and WeaponDefs[ud.shieldWeaponDef] and WeaponDefs[ud.shieldWeaponDef].shieldPower or nil
	local overshieldStrength = spGetUnitRulesParam(unitID, "personalShield")
	local shieldMaxStrength = spGetUnitRulesParam(unitID, "personalShieldMax")
			or tonumber(ud.customParams and ud.customParams.shield_max_strength)

	local status = {}
	if stunned then status[#status + 1] = "Paralyzed" end
	if beingBuilt or (buildProgress and buildProgress < 1) then status[#status + 1] = "Building" end
	if spGetUnitIsCloaked(unitID) then status[#status + 1] = "Cloaked" end

	local supplyCost = ud.customParams and tonumber(ud.customParams.supply_cost or 0) or 0
	local supplyGive = ud.customParams and tonumber(ud.customParams.supply_granted or 0) or 0
	local supplyText = nil
	if supplyGive > 0 then
		supplyText = "+" .. FormatSupplyValue(supplyGive)
	elseif supplyCost > 0 then
		supplyText = "-" .. FormatSupplyValue(supplyCost)
	end

	local metalFlowText = nil
	local energyFlowText = nil
	if metalMake ~= nil then
		local netMetal = metalMake - metalUse
		local netEnergy = energyMake - energyUse
		metalFlowText = (netMetal >= 0 and "+" or "") .. FormatNbr(netMetal, 1)
		energyFlowText = (netEnergy >= 0 and "+" or "") .. FormatNbr(netEnergy, 1)
	end

	return {
		title = ud.humanName,
		subtitle = ud.tooltip or "",
		tech = GetTechTag(ud),
		unitName = ud.name,

		roleText = GetTooltipRole(ud),
		healthText = health and (FormatNbr(health, 0) .. "/" .. FormatNbr(maxHealth, 0)) or nil,
		shieldText = (hasShield and maxShieldPower) and (FormatNbr(math_min(shieldPower, maxShieldPower), 0) .. "/" .. FormatNbr(maxShieldPower, 0)) or nil,
		overshieldText = (overshieldStrength and shieldMaxStrength) and (FormatNbr(math_min(overshieldStrength, shieldMaxStrength), 0) .. "/" .. FormatNbr(shieldMaxStrength, 0)) or nil,
		statusText = (#status > 0) and table_concat(status, ", ") or nil,

		metalCostText = FormatNbr(ud.metalCost or 0, 0),
		energyCostText = FormatNbr(ud.energyCost or 0, 0),
		supplyText = supplyText,
		storageText = ((ud.metalStorage or 0) > 0 or (ud.energyStorage or 0) > 0)
				and { m = FormatNbr(ud.metalStorage or 0, 0), e = FormatNbr(ud.energyStorage or 0, 0) }
				or nil,
		metalFlowText = metalFlowText,
		energyFlowText = energyFlowText,

		buildTimeText = nil,
		buildPowerText = (ud.buildSpeed and ud.buildSpeed > 0) and GetTooltipBuildPower(ud.buildSpeed) or nil,

		weaponCards = BuildWeaponCards(ud),
		unitGuideText = ud.customParams and ud.customParams.unitguide or nil,
	}
end

local function BuildBuildPanelData(buildData)
	local ud = buildData.ud
	local supplyText = nil
	local buildPower = GetBuildPowerTotal()

	if ud and ud.customParams then
		local supplyCost = tonumber(ud.customParams.supply_cost or 0) or 0
		local supplyGive = tonumber(ud.customParams.supply_granted or 0) or 0
		if supplyGive > 0 then
			supplyText = "+" .. FormatSupplyValue(supplyGive)
		elseif supplyCost > 0 then
			supplyText = "-" .. FormatSupplyValue(supplyCost)
		end
	end

	local estBuildTime = nil
	if ud and ud.buildTime then
		estBuildTime = math_floor((29 + math_floor(31 + ud.buildTime / (buildPower / 32))) / 30)
	elseif buildData.buildTime then
		estBuildTime = math_floor((29 + math_floor(31 + buildData.buildTime / (buildPower / 32))) / 30)
	end

	return {
		title = ud and ud.humanName or buildData.name,
		subtitle = ud and (ud.tooltip or buildData.desc) or buildData.desc,
		tech = ud and GetTechTag(ud) or nil,
		unitName = ud and ud.name or nil,

		roleText = ud and GetTooltipRole(ud) or nil,
		healthText = ud and FormatNbr(ud.health, 0) or (buildData.health and FormatNbr(buildData.health, 0) or nil),
		shieldText = (ud and ud.shieldWeaponDef and WeaponDefs[ud.shieldWeaponDef]) and FormatNbr(WeaponDefs[ud.shieldWeaponDef].shieldPower, 0) or nil,
		overshieldText = (ud and ud.customParams and ud.customParams.isshieldedunit == "1" and ud.customParams.shield_max_strength) and FormatNbr(ud.customParams.shield_max_strength, 0) or nil,
		statusText = humanNameToKeySymbols[buildData.name] and ("Hotkey: " .. humanNameToKeySymbols[buildData.name]) or nil,

		metalCostText = FormatNbr(buildData.metalCost or (ud and ud.metalCost or 0), 0),
		energyCostText = FormatNbr(buildData.energyCost or (ud and ud.energyCost or 0), 0),
		supplyText = supplyText,
		storageText = (ud and ((ud.metalStorage or 0) > 0 or (ud.energyStorage or 0) > 0))
				and { m = FormatNbr(ud.metalStorage or 0, 0), e = FormatNbr(ud.energyStorage or 0, 0) }
				or nil,
		metalFlowText = nil,
		energyFlowText = nil,

		buildTimeText = estBuildTime and (tostring(estBuildTime) .. "s") or nil,
		buildPowerText = (ud and ud.buildSpeed and ud.buildSpeed > 0) and GetTooltipBuildPower(ud.buildSpeed) or nil,

		weaponCards = ud and BuildWeaponCards(ud) or {},
		unitGuideText = ud and ud.customParams and ud.customParams.unitguide or nil,
	}
end

local function BuildOrderPanelData(orderData)
	return {
		title = orderData.title or "Command",
		subtitle = "",
		body = orderData.body or "",
	}
end

local function BuildFeaturePanelData(featureID)
	local featureDefID = spGetFeatureDefID(featureID)
	local fd = featureDefID and FeatureDefs[featureDefID]
	if not fd then return nil end

	local metal, _, energy, _, reclaimLeft = spGetFeatureResources(featureID)
	local health, maxHealth = spGetFeatureHealth(featureID)

	return {
		title = fd.name or "Feature",
		subtitle = fd.tooltip or "Map Feature",
		tech = nil,

		roleText = "Feature",
		healthText = health and maxHealth and (FormatNbr(health, 0) .. "/" .. FormatNbr(maxHealth, 0)) or nil,
		shieldText = nil,
		overshieldText = nil,
		statusText = nil,

		metalCostText  = metal  and FormatNbr(metal,  0) or "-",
		energyCostText = energy and FormatNbr(energy, 0) or "-",
		supplyText = nil,
		storageText = nil,
		metalFlowText = nil,
		energyFlowText = nil,

		buildTimeText = nil,
		buildPowerText = nil,

		weaponCards = {},
		unitGuideText = nil,
		isLiveFeature = true,
		isFeature = true,
	}
end

local function BuildSelectionPanelData(units)
	-- Group units by defID, count them, accumulate economy
	local groups   = {}   -- defID -> { ud, count }
	local order    = {}   -- insertion order for stable display
	local totalMetal  = 0
	local totalEnergy = 0
	local totalSupply = 0

	for i = 1, #units do
		local unitID = units[i]
		local defID  = spGetUnitDefID(unitID)
		if defID then
			if not groups[defID] then
				groups[defID] = { ud = UnitDefs[defID], count = 0 }
				order[#order + 1] = defID
			end
			groups[defID].count = groups[defID].count + 1

			-- Accumulate economy drain
			local mMake, mUse, eMake, eUse = spGetUnitResources(unitID)
			totalMetal  = totalMetal  + ((mMake or 0) - (mUse  or 0))
			totalEnergy = totalEnergy + ((eMake or 0) - (eUse  or 0))
		end
	end

	-- Total supply used across selection
	for i = 1, #order do
		local g  = groups[order[i]]
		local ud = g.ud
		if ud and ud.customParams then
			local sc = tonumber(ud.customParams.supply_cost or 0) or 0
			totalSupply = totalSupply + sc * g.count
		end
	end

	-- Sort groups by count descending
	table.sort(order, function(a, b)
		return groups[a].count > groups[b].count
	end)

	-- Build row data
	local rows = {}
	for i = 1, #order do
		local g  = groups[order[i]]
		local ud = g.ud
		if ud then
			local tech = nil
			if ud.customParams then
				local TECH_MAP = { tech0="T0", tech1="T1", tech2="T2", tech3="T3", tech4="T4" }
				local req = ud.customParams.techlevel or ud.customParams.requiretech
				if req then
					tech = TECH_MAP[string_lower(tostring(req))]
				end
			end
			rows[#rows + 1] = {
				name  = ud.humanName or ud.name or "Unknown",
				count = g.count,
				tech  = tech,
			}
		end
	end

	-- Format economy summary
	local function SignedStr(v)
		if v >= 0 then return string_format("+%.1f", v) end
		return string_format("%.1f", v)
	end

	return {
		type          = "selection",
		title         = "Selection",
		subtitle      = #units .. " units",
		rows          = rows,
		metalFlowText  = SignedStr(totalMetal),
		energyFlowText = SignedStr(totalEnergy),
		supplyText     = totalSupply > 0 and tostring(math_floor(totalSupply)) or nil,
	}
end

local function BuildPanelDataFromResolved(resolved)
	if not resolved then return nil end
	if resolved.type == "unit" then
		return BuildUnitPanelData(resolved.id), false
	elseif resolved.type == "feature" then
		return BuildFeaturePanelData(resolved.id), false
	elseif resolved.type == "build" then
		return BuildBuildPanelData(resolved), false
	elseif resolved.type == "order" then
		return BuildOrderPanelData(resolved), true
	elseif resolved.type == "selection" then
		return BuildSelectionPanelData(resolved.units), false
	end
	return nil, false
end

local function CanShowAdditionalInfo(resolved)
	return resolved and (resolved.type == "unit" or resolved.type == "build")
end

local function ResolvedKey(resolved)
	if not resolved then return nil end
	if resolved.type == "unit"    then return "unit:"    .. tostring(resolved.id) end
	if resolved.type == "feature" then return "feature:" .. tostring(resolved.id) end
	if resolved.type == "build"   then return "build:"   .. tostring(resolved.name or "") end
	if resolved.type == "order"     then return "order:"     .. tostring(resolved.title or "") end
	if resolved.type == "selection" then
		-- Key on sorted unit IDs so composition changes trigger a rebuild
		local ids = {}
		for i = 1, #resolved.units do ids[i] = resolved.units[i] end
		table.sort(ids)
		local key = "selection:"
		for i = 1, math_min(#ids, 32) do key = key .. ids[i] .. "," end
		return key
	end
	return nil
end

--------------------------------------------------------------------------------
-- what the mouse is on
--------------------------------------------------------------------------------

local function InRect(rect, x, y)
	return rect and x >= rect[1] and x <= rect[3] and y >= rect[2] and y <= rect[4]
end

-- True when the mouse is on some piece of UI and not on the world. On an
-- RmlUi panel, RmlUi says so itself. A widget that still draws with GL is
-- known only by its tooltip: one that is neither empty nor one of the
-- engine's own (unit stats, terrain position) can only have come from a widget.
local function CursorOverUI(currentTooltip)
	local context = hud.GetContext()
	local ok, interacting = pcall(function() return context:IsMouseInteracting() end)
	if ok and interacting then
		return true
	end
	if currentTooltip == "" then return false end
	if currentTooltip:find("\nHealth ") or currentTooltip:find("\nExperience ") then return false end
	if currentTooltip:find("^Pos ") or currentTooltip:find("^Position") or
			currentTooltip:find("^Elevation") or currentTooltip:find("^Height") or
			currentTooltip:find("^%(") then
		return false
	end
	return true
end

local function ResolveTooltipData()
	local currentTooltip = spGetCurrentTooltip() or ""

	-- While the mouse is on an RmlUi element the engine asks no widget for a
	-- tooltip, so the build/order menu publishes its own: nil off its panels,
	-- "" between its cards.
	local menu = WG.StaticBuildOrderMenu
	local menuTooltip = menu and menu.GetTooltip and menu.GetTooltip()
	if menuTooltip then
		currentTooltip = menuTooltip
	end

	-- UI takes precedence over the world: only look for a unit or wreck under
	-- the mouse when no piece of UI is there.
	if not menuTooltip and not CursorOverUI(currentTooltip) then
		local worldType, worldID = ResolveHoveredWorldObject()
		if worldType == "unit" and worldID then
			return {type = "unit", id = worldID}
		elseif worldType == "feature" and worldID then
			return {type = "feature", id = worldID}
		end
	end

	-- A build card: the menu knows exactly which unit it is. The costs are
	-- read from the card's tooltip, which carries what it costs right now.
	local cmd = menu and menu.GetHovered and menu.GetHovered()
	local ud = cmd and cmd.id and cmd.id < 0 and UnitDefs[-cmd.id]
	if ud then
		local tip = cmd.tooltip or ""
		return {
			type = "build",
			ud = ud,
			name = ud.humanName,
			desc = ud.tooltip,
			health = ud.health,
			buildTime = ud.buildTime,
			metalCost = tonumber(string_match(tip, "Metal cost (%d+)")),
			energyCost = tonumber(string_match(tip, "Energy cost (%d+)")),
		}
	end

	-- a build tooltip from anywhere else, then an order button
	local buildData = ResolveHoveredBuildFromTooltip(currentTooltip)
	if buildData then
		return buildData
	end
	local orderData = ResolveOrderFromTooltip(currentTooltip)
	if orderData then
		return orderData
	end

	-- otherwise, the selection
	local selectedUnits = spGetSelectedUnits()
	if selectedUnits and #selectedUnits == 1 then
		return {type = "unit", id = selectedUnits[1]}
	elseif selectedUnits and #selectedUnits > 1 then
		return {type = "selection", units = selectedUnits}
	end
	return nil
end

--------------------------------------------------------------------------------
-- markup
--
-- A panel's markup holds its structure and the text that cannot change while
-- it is shown. Every figure is an empty element with an id, filled in by
-- ShowValues, so the markup itself tells whether the panel must be rebuilt.
--------------------------------------------------------------------------------

local function HeadRML(title, subtitle, tech)
	local parts = {'<div class="head"><div class="names"><div class="name">', hud.Escape(title), '</div>'}
	if subtitle and subtitle ~= "" then
		parts[#parts + 1] = '<div class="desc">' .. hud.Escape(subtitle) .. '</div>'
	end
	parts[#parts + 1] = '</div>'
	if tech then
		parts[#parts + 1] = string_format('<div class="tech %s">%s</div>', string_lower(tech), tech)
	end
	parts[#parts + 1] = '</div>'
	return table_concat(parts)
end

local function SectionRML(title)
	return '<div class="label sec">' .. title .. '</div>'
end

local function RowRML(label, id, class)
	return string_format('<div class="row"><div class="k">%s</div><div id="%s" class="v%s"/></div>',
		label, id, class and (" " .. class) or "")
end

-- "M <figure> E <figure>", for storage and for income
local function PairRowRML(label, metalID, energyID, colored)
	return string_format('<div class="row"><div class="k">%s</div><div class="pair">'
		.. '<div class="unit">M</div><div id="%s"%s/><div class="unit gap">E</div><div id="%s"%s/></div></div>',
		label, metalID, colored and ' class="metal"' or "", energyID, colored and ' class="energy"' or "")
end

-- Left column: role, hull, shields, status. Right column: what it costs (or,
-- for a wreck, what is left in it), storage, supply and income.
local function StatsRML(data)
	local left, right = {}, {}
	if data.roleText       then left[#left + 1] = RowRML("Role", "tt-role") end
	if data.healthText     then left[#left + 1] = RowRML("HP", "tt-hp") end
	if data.overshieldText then left[#left + 1] = RowRML("OvrShield", "tt-os", "overshield") end
	if data.shieldText     then left[#left + 1] = RowRML("Shield", "tt-sh", "shield") end
	if data.statusText     then left[#left + 1] = RowRML("Status", "tt-status") end

	right[#right + 1] = RowRML(data.isFeature and "M. Left" or "Metal", "tt-m", "metal")
	right[#right + 1] = RowRML(data.isFeature and "E. Left" or "Energy", "tt-e", "energy")
	if data.storageText then
		right[#right + 1] = PairRowRML("Storage", "tt-stm", "tt-ste", true)
	end
	if not data.isFeature then
		right[#right + 1] = RowRML("Supply", "tt-sup")
		right[#right + 1] = PairRowRML("Flow", "tt-fm", "tt-fe", false)
	end

	return SectionRML("Stats / Economy")
		.. '<div class="cols"><div class="col">' .. table_concat(left)
		.. '</div><div class="col second">' .. table_concat(right) .. '</div></div>'
end

local function OrderRML(data)
	local parts = {SectionRML("Command")}
	local clean = string_gsub(data.body or "", "Metal cost %d*\nEnergy cost %d*\n", "")
	for line in (clean .. "\n"):gmatch("([^\n]*)\n") do
		if line ~= "" then
			parts[#parts + 1] = '<div class="text">' .. hud.Escape(line) .. '</div>'
		end
	end
	return table_concat(parts)
end

local function SelectionRML(data)
	local parts = {SectionRML("Units")}
	for _, row in ipairs(data.rows or {}) do
		parts[#parts + 1] = string_format(
			'<div class="srow"><div class="stech %s">%s</div><div class="sname">%s</div><div class="scount">x%d</div></div>',
			row.tech and string_lower(row.tech) or "", row.tech or "", hud.Escape(row.name), row.count)
	end
	parts[#parts + 1] = '<div class="totals"><div class="unit">M</div><div id="tt-fm"/>'
		.. '<div class="unit gap">E</div><div id="tt-fe"/>'
	if data.supplyText then
		parts[#parts + 1] = '<div class="unit gap">S</div><div id="tt-sup" class="supply"/>'
	end
	parts[#parts + 1] = '</div>'
	return table_concat(parts)
end

local function TooltipRML(data)
	local parts = {HeadRML(data.title or "Unknown", data.subtitle, data.tech)}
	if data.type == "selection" then
		parts[#parts + 1] = SelectionRML(data)
	elseif isOrder then
		parts[#parts + 1] = OrderRML(data)
		parts[#parts + 1] = '<div class="hint">' .. TOOLTIP_HINT_TEXT .. '</div>'
	else
		parts[#parts + 1] = StatsRML(data)
		parts[#parts + 1] = '<div class="hint">' .. TOOLTIP_HINT_TEXT .. '</div>'
	end
	return table_concat(parts)
end

local heroPaths = {} -- unit name -> path, or false when there is no picture

local function HeroPath(unitName)
	if not unitName or unitName == "" then
		return nil
	end
	local path = heroPaths[unitName]
	if path == nil then
		path = "unitpics-hero/" .. unitName .. "-hero.png"
		if not VFS.FileExists(path) then
			path = false
		end
		heroPaths[unitName] = path
	end
	return path or nil
end

local function WeaponRML(card)
	local parts = {'<div class="weapon"><div class="wname">',
		hud.Escape(card.title), (card.count > 1) and (" x" .. card.count) or "", '</div>'}
	parts[#parts + 1] = string_format(
		'<div class="wstats"><div class="unit">%s</div><div class="v%s">%s</div>'
		.. '<div class="unit">Range</div><div class="v">%s</div><div class="unit">AoE</div><div class="v">%s</div></div>',
		card.paralyze and "Paralyze" or "DPS", card.paralyze and " paralyze" or "",
		FormatNbr(card.dps, 1), FormatNbr(card.range, 0), FormatNbr(card.aoe, 0))

	local tags = {}
	if card.eps and card.eps > 0 then
		tags[#tags + 1] = '<div class="tag energy">E/s ' .. FormatNbr(card.eps, 1) .. '</div>'
	end
	if card.water   then tags[#tags + 1] = '<div class="tag">WATER</div>' end
	if card.disrupt then tags[#tags + 1] = '<div class="tag disrupt">DISRUPT</div>' end
	if card.heat    then tags[#tags + 1] = '<div class="tag heat">HEAT</div>' end
	if #tags > 0 then
		parts[#parts + 1] = '<div class="tags">' .. table_concat(tags) .. '</div>'
	end
	if card.guide and card.guide ~= "" then
		parts[#parts + 1] = '<div class="guide">' .. hud.Escape(card.guide) .. '</div>'
	end
	parts[#parts + 1] = '</div>'
	return table_concat(parts)
end

local function AdditionalRML(data)
	local parts = {HeadRML("Additional Info", data.title, data.tech)}

	local hero = HeroPath(data.unitName)
	if hero then
		-- the leading slash makes the path absolute instead of relative to the document
		parts[#parts + 1] = '<img class="hero" src="/' .. hero .. '"/>'
	end
	parts[#parts + 1] = '<div class="hint">' .. ADDITIONAL_HINT_TEXT .. '</div>'

	if data.buildTimeText or data.buildPowerText then
		parts[#parts + 1] = SectionRML("Build Info")
		parts[#parts + 1] = '<div class="wide">'
			.. string_format('<div class="row"><div class="k">Build Time</div><div class="v">%s</div></div>', data.buildTimeText or "-")
			.. string_format('<div class="row"><div class="k">Build Power</div><div class="v">%s</div></div>', data.buildPowerText or "-")
			.. '</div>'
	end

	if data.weaponCards and #data.weaponCards > 0 then
		parts[#parts + 1] = SectionRML("Weapons")
		for _, card in ipairs(data.weaponCards) do
			parts[#parts + 1] = WeaponRML(card)
		end
	end

	if data.unitGuideText and data.unitGuideText ~= "" then
		parts[#parts + 1] = SectionRML("Unit Guide")
		parts[#parts + 1] = '<div class="text">' .. hud.Escape(data.unitGuideText):gsub("\n", "<br/>") .. '</div>'
	end
	return table_concat(parts)
end

--------------------------------------------------------------------------------
-- showing
--------------------------------------------------------------------------------

local function ShowFlow(id, text)
	view.SetText(id, text or "-")
	view.SetClass(id, "bad", text ~= nil and text:sub(1, 1) == "-")
	view.SetClass(id, "good", text ~= nil and text:sub(1, 1) ~= "-")
end

-- fills in every figure; an id that is not in the markup is simply skipped
local function ShowValues(data)
	view.SetText("tt-role", hud.Escape(data.roleText or ""))
	view.SetText("tt-hp", data.healthText or "")
	view.SetText("tt-os", data.overshieldText or "")
	view.SetText("tt-sh", data.shieldText or "")
	view.SetText("tt-status", hud.Escape(data.statusText or ""))
	view.SetText("tt-m", data.metalCostText or "-")
	view.SetText("tt-e", data.energyCostText or "-")
	if data.storageText then
		view.SetText("tt-stm", data.storageText.m)
		view.SetText("tt-ste", data.storageText.e)
	end
	view.SetText("tt-sup", data.supplyText or "-")
	if data.type ~= "selection" then
		view.SetClass("tt-sup", "supply", data.supplyText ~= nil)
	end
	ShowFlow("tt-fm", data.metalFlowText)
	ShowFlow("tt-fe", data.energyFlowText)
end

local function ResetScroll(id)
	local element = view.Element(id)
	if element then
		pcall(function() element.scroll_top = 0 end)
	end
end

local function Show()
	if not panelData then
		view.SetClass("tooltip", "hidden", true)
		view.SetClass("additional", "hidden", true)
		return
	end

	local withAdditional = showAdditional and CanShowAdditionalInfo(shownResolved)

	-- The markup is rebuilt only when something it is made from has changed:
	-- what is described, which rows it has, or an order button's text.
	local data = panelData
	local shape = table_concat({
		tostring(shownKey), tostring(data.title), tostring(data.subtitle), tostring(data.tech),
		isOrder and (data.body or "") or "",
		withAdditional and "+" or "-",
		data.roleText and "r" or "", data.healthText and "h" or "", data.overshieldText and "o" or "",
		data.shieldText and "s" or "", data.statusText and "t" or "", data.storageText and "g" or "",
		tostring(data.buildTimeText), tostring(data.buildPowerText),
	}, "|")
	if shape ~= shownShape then
		shownShape = shape
		local tooltip = TooltipRML(data)
		local additional = withAdditional and AdditionalRML(data) or ""
		if tooltip ~= tooltipSignature then
			tooltipSignature = tooltip
			view.Element("tt-scroll").inner_rml = tooltip
		end
		if additional ~= additionalSignature then
			additionalSignature = additional
			view.Element("ad-scroll").inner_rml = additional
		end
		view.Forget() -- the figures are new elements
	end

	ShowValues(panelData)
	view.SetClass("tooltip", "hidden", false)
	view.SetClass("additional", "hidden", not withAdditional)
end

--------------------------------------------------------------------------------
-- placement
--------------------------------------------------------------------------------

-- the tooltip's default spot is beside the order menu: its right edge and bottom
local function OrderAnchor(scale)
	local menu = WG.StaticBuildOrderMenu
	if menu and menu.GetOrderRect then
		local _, y1, x2 = menu.GetOrderRect()
		if x2 and y1 then
			return x2, y1
		end
	end
	return math_floor((MARGIN + PANEL_WIDTH) * scale), math_floor(MARGIN * scale)
end

local function TooltipOrigin(vsx, vsy, w, h, scale)
	local x, y = OrderAnchor(scale)
	lastOrderX, lastOrderY = x, y
	return x + PANEL_GAP * scale, y
end

-- above the tooltip, wherever the tooltip is
local function AdditionalOrigin(vsx, vsy, w, h, scale)
	if tooltipRect then
		return tooltipRect[1], tooltipRect[4] + PANEL_GAP * scale
	end
	return 0, 0
end

local function Place()
	local x, y, w, h = hud.PlacePanel(view.Element("tooltip"), LAYOUT_TOOLTIP, PANEL_WIDTH, TOOLTIP_HEIGHT, TooltipOrigin)
	tooltipRect = x and {x, y, x + w, y + h}
	x, y, w, h = hud.PlacePanel(view.Element("additional"), LAYOUT_ADDITIONAL, PANEL_WIDTH, ADDITIONAL_HEIGHT, AdditionalOrigin)
	additionalRect = x and {x, y, x + w, y + h}
end

--------------------------------------------------------------------------------
-- widget api
--------------------------------------------------------------------------------

function widget:Initialize()
	local helpers = include("rml/hud.lua")
	local result, reason = helpers.LoadDocument(DOCUMENT_PATH, widget)
	if not result then
		Spring.Echo("[Tooltip Panel] " .. tostring(reason))
		widgetHandler:RemoveWidget()
		return
	end
	hud = helpers
	document = result

	view = hud.NewView(document)
	view.Assume("tooltip", "hidden", true) -- set in the markup
	view.Assume("additional", "hidden", true)

	-- this panel replaces the engine's tooltip and selection readout
	Spring.SendCommands({"tooltip 0"})
	Spring.SetDrawSelectionInfo(false)

	-- the build/order menu calls this when the order menu has moved
	WG.StaticTooltip = {
		Relayout = function()
			if document then
				Place()
			end
		end,
	}

	hud.RegisterPanel(LAYOUT_TOOLTIP, "Tooltip", Place)
	hud.RegisterPanel(LAYOUT_ADDITIONAL, "Additional Info", Place)
	Place()

	hud.ShowPassive(document)
end

function widget:Shutdown()
	WG.StaticTooltip = nil
	if hud then
		hud.UnregisterPanel(LAYOUT_TOOLTIP)
		hud.UnregisterPanel(LAYOUT_ADDITIONAL)
	end
	if document then
		document:Close()
		document = nil
		Spring.SendCommands({"tooltip 1"})
	end
end

function widget:ViewResize()
	if hud and document then
		hud.UpdateScale()
		Place()
	end
end

function widget:KeyPress(key, mods, isRepeat)
	if not document or isRepeat or key ~= KEY_SPACE then
		return false
	end
	showAdditional = not showAdditional
	ResetScroll("ad-scroll")
	spPlaySoundFile("leftclick", 1.0, "ui")
	return true
end

function widget:Update()
	if not document then
		return
	end
	if hud.FollowGuiHidden(document) then
		return -- hidden with the rest of the GUI (F5)
	end

	-- follow the order menu if it has moved without saying so
	local x, y = OrderAnchor(hud.GetScale())
	if x ~= lastOrderX or y ~= lastOrderY then
		Place()
	end

	-- While the mouse is on one of these two panels (to scroll it), they keep
	-- describing what they describe: otherwise reaching for the panel would
	-- change it.
	local mx, my = spGetMouseState()
	local onOwnPanel = panelData ~= nil and (InRect(tooltipRect, mx, my)
		or (showAdditional and CanShowAdditionalInfo(shownResolved) and InRect(additionalRect, mx, my)))
	local resolved = onOwnPanel and shownResolved or ResolveTooltipData()
	local key = ResolvedKey(resolved)

	if key ~= shownKey then
		shownKey = key
		shownResolved = resolved
		panelData, isOrder = nil, false
		liveUnitID, liveFeatureID = nil, nil
		if resolved then
			panelData, isOrder = BuildPanelDataFromResolved(resolved)
			if panelData then
				if resolved.type == "unit" then
					liveUnitID = resolved.id
				elseif resolved.type == "feature" then
					liveFeatureID = resolved.id
				end
				spPlaySoundFile("hover", 1.0, "ui")
			end
		end
		ResetScroll("tt-scroll")
		ResetScroll("ad-scroll")
	elseif isOrder and panelData and resolved then
		-- the same order button, saying something new
		panelData.body = resolved.body or ""
	end

	if panelData then
		if liveUnitID then
			RefreshLiveUnitFields(panelData, liveUnitID)
		elseif liveFeatureID then
			RefreshLiveFeatureFields(panelData, liveFeatureID)
		end
	end
	Show()
end
