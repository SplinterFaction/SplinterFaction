function widget:GetInfo()
	return {
		name    = "Static Tooltip Panel",
		desc    = "Panel-style tooltip with optional additional info panel",
		author  = "",
		date    = "2026-03-22",
		license = "GPL v2 or later",
		layer   = 2,
		enabled = true,
	}
end

include("keysym.h.lua")

--------------------------------------------------------------------------------
-- Config (matched to gui_static_buildordermenu.lua)
--------------------------------------------------------------------------------

local PANEL_MARGIN_X        = 8
local PANEL_MARGIN_Y        = 8
local PANEL_WIDTH_FRAC      = 1 / 6
local TOTAL_HEIGHT_FRAC     = 0.70
local ORDER_HEIGHT_FRAC     = 0.28
local GAP_BETWEEN_PANELS    = 10
local PANEL_RADIUS          = 10
local PANEL_BG              = {0.08, 0.08, 0.09, 0.88}
local PANEL_BORDER          = {1.0, 1.0, 1.0, 0.12}
local PANEL_OUTER_COLOR     = {0, 0, 0, 0.85}
local PANEL_INNER_COLOR     = {0.15, 0.15, 0.15, 0.85}
local TOOLTIP_ACCENT_COLOR    = {0.00, 0.50, 1.00, 0.60}
local ADDITIONAL_ACCENT_COLOR = {0.00, 0.50, 1.00, 0.60}
local PANEL_ACCENT_HEIGHT     = 3

-- Accent colors for inner section boxes (Stats, Economy, Build Info, etc.)
local SECTION_ACCENT_COLOR       = {1.0, 1.0, 1.0, 0.035}
local CATEGORY_CARD_ACCENT_COLOR = {1.0, 1.0, 1.0, 0.035}
local SECTION_ACCENT_HEIGHT      = 3

local SECTION_BG            = {0.14, 0.14, 0.15, 0.90}
local CATEGORY_BG           = {0.20, 0.20, 0.21, 0.55}
local HEADER_TEXT           = {1.0, 1.0, 1.0, 1.0}
local SUBTEXT_COLOR         = {0.80, 0.82, 0.86, 1.0}
local MUTED_TEXT_COLOR      = {0.65, 0.67, 0.72, 1.0}
local HINT_TEXT_COLOR       = {0.75, 0.78, 0.83, 0.95}

local INNER_PAD             = 10
local SECTION_GAP           = 6
local CARD_GAP              = 6

local TOOLTIP_WIDTH_MULT    = 1.00
local TOOLTIP_GAP_X         = 10

local TITLE_SIZE  = 15
local HEADER_SIZE = 12
local BODY_SIZE   = 11
local SMALL_SIZE  = 10
local LINE_H      = 14
local uiScale     = 1.0   -- reserved for future use; currently fixed

local TECH_TEXT_COLORS = {
	T0 = {0.0, 0.8, 0.8, 1.0},
	T1 = {1.0, 0.5, 0.0, 1.0},
	T2 = {1.0, 0.0, 1.0, 1.0},
	T3 = {0.0, 1.0, 0.0, 1.0},
	T4 = {1.0, 0.0, 0.0, 1.0},
}

local METAL_TEXT_COLOR      = {0.53, 0.77, 0.89, 1.0}
local ENERGY_TEXT_COLOR     = {1.0, 1.0, 0.0, 1.0}
local SUPPLY_TEXT_COLOR     = {1.0, 0.62, 0.10, 1.0}
local POSITIVE_TEXT_COLOR   = {0.35, 1.0, 0.45, 1.0}
local NEGATIVE_TEXT_COLOR   = {1.0, 0.35, 0.35, 1.0}
local SHIELD_TEXT_COLOR     = {0.62, 0.72, 1.0, 1.0}
local OVERSHIELD_TEXT_COLOR = {0.82, 0.82, 1.0, 1.0}
local PARALYZE_TEXT_COLOR   = {0.55, 1.0, 1.0, 1.0}

local TOOLTIP_HINT_TEXT     = "Press Spacebar for Additional Info"
local ADDITIONAL_HINT_TEXT  = "Press Spacebar to toggle off/on"

--------------------------------------------------------------------------------
-- Spring / Lua locals
--------------------------------------------------------------------------------

local spGetViewGeometry        = Spring.GetViewGeometry
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
local spGetConfigFloat         = Spring.GetConfigFloat
local spIsGUIHidden            = Spring.IsGUIHidden
local spGetKeySymbol           = Spring.GetKeySymbol
local spSendCommands           = Spring.SendCommands
local spSetDrawSelectionInfo   = Spring.SetDrawSelectionInfo

local glColor                  = gl.Color
local glRect                   = gl.Rect
local glText                   = gl.Text
local glBeginEnd               = gl.BeginEnd
local glVertex                 = gl.Vertex
local glLineWidth              = gl.LineWidth
local glScissor                = gl.Scissor
local glTexture                = gl.Texture
local glTexCoord               = gl.TexCoord
local GL_TRIANGLE_FAN          = GL.TRIANGLE_FAN
local GL_LINE_LOOP             = GL.LINE_LOOP
local GL_QUADS                 = GL.QUADS

local math_abs                 = math.abs
local math_min                 = math.min
local math_max                 = math.max
local math_floor               = math.floor
local math_pi                  = math.pi
local math_cos                 = math.cos
local math_sin                 = math.sin
local tostring                 = tostring
local tonumber                 = tonumber
local pairs                    = pairs
local string_format            = string.format
local string_match             = string.match
local string_gsub              = string.gsub
local string_lower             = string.lower
local table_concat             = table.concat

--------------------------------------------------------------------------------
-- Font / ui opacity
--------------------------------------------------------------------------------

local ui_opacity = tonumber(spGetConfigFloat("ui_opacity", 0.66) or 0.66)
local bgcorner = ":n:" .. LUAUI_DIRNAME .. "Images/bgcorner.png"

--------------------------------------------------------------------------------
-- Hotkey config from old tooltip
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
	if nameToKeyCode[name] then
		local parts = {}
		for i = 1, #nameToKeyCode[name] do
			parts[#parts + 1] = GetKeySymbol(nameToKeyCode[name][i])
		end
		humanNameToKeySymbols[ud.humanName] = table_concat(parts, " + ")
	end
end

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local vsx, vsy = spGetViewGeometry()

local orderPanel = {}
local tooltipPanel = {}
local additionalPanel = {}

local additionalInfoEnabled = false

--------------------------------------------------------------------------------
-- Display list cache
--
-- All geometry (rounded rects, section boxes, panel chrome, text labels) is
-- compiled into GL display lists so DrawScreen just calls gl.CallList each
-- frame instead of re-emitting hundreds of draw calls.
--
-- Two lists per tooltip panel:
--   staticList   — everything that only changes when the tooltip SOURCE changes
--                  (panel chrome, section boxes, labels, weapon cards, guide)
--   dynamicList  — the live values for hovered units only (health, shield,
--                  flow numbers, status).  nil for build/order/feature sources.
--
-- The additional info panel gets its own staticList (additionalList).
-- It has no dynamic values.
--------------------------------------------------------------------------------

local staticList     = nil
local dynamicList    = nil
local additionalList = nil

local cachedPanelData   = nil
local cachedIsOrder     = false
local cachedResolvedKey = nil
local cachedIsLiveUnit    = false
local lastShowAdditional  = false  -- tracks what was baked into staticList

local function FreeDisplayLists()
	if staticList     then gl.DeleteList(staticList)     ; staticList     = nil end
	if dynamicList    then gl.DeleteList(dynamicList)    ; dynamicList    = nil end
	if additionalList then gl.DeleteList(additionalList) ; additionalList = nil end
end

-- Track the values that went into the last dynamic list compile.
-- The list is only rebuilt when something actually changes.
local lastDynValues = {}

local function DynamicValuesChanged(pd)
	local lv = lastDynValues
	return lv.healthText      ~= pd.healthText
			or lv.shieldText      ~= pd.shieldText
			or lv.overshieldText  ~= pd.overshieldText
			or lv.statusText      ~= pd.statusText
			or lv.metalFlowText   ~= pd.metalFlowText
			or lv.energyFlowText  ~= pd.energyFlowText
			or lv.metalCostText   ~= pd.metalCostText
			or lv.energyCostText  ~= pd.energyCostText
end

local function SaveDynamicValues(pd)
	local lv = lastDynValues
	lv.healthText     = pd.healthText
	lv.shieldText     = pd.shieldText
	lv.overshieldText = pd.overshieldText
	lv.statusText     = pd.statusText
	lv.metalFlowText  = pd.metalFlowText
	lv.energyFlowText = pd.energyFlowText
	lv.metalCostText  = pd.metalCostText
	lv.energyCostText = pd.energyCostText
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
-- Helpers
--------------------------------------------------------------------------------

local function Clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

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

local function UpdateRects()
	vsx, vsy = spGetViewGeometry()

	local panelW = math_floor(vsx * PANEL_WIDTH_FRAC)
	local totalH = math_floor(vsy * TOTAL_HEIGHT_FRAC)
	local orderH = math_floor(totalH * ORDER_HEIGHT_FRAC)
	local buildH = math_max(120, totalH - orderH - GAP_BETWEEN_PANELS)

	orderPanel.x1 = PANEL_MARGIN_X
	orderPanel.y1 = PANEL_MARGIN_Y
	orderPanel.x2 = orderPanel.x1 + panelW
	orderPanel.y2 = orderPanel.y1 + orderH
	orderPanel.w = panelW
	orderPanel.h = orderH

	local tooltipW = math_floor(panelW * TOOLTIP_WIDTH_MULT)

	tooltipPanel.x1 = orderPanel.x2 + TOOLTIP_GAP_X
	tooltipPanel.y1 = orderPanel.y1
	tooltipPanel.x2 = tooltipPanel.x1 + tooltipW
	tooltipPanel.y2 = orderPanel.y2
	tooltipPanel.w = tooltipW
	tooltipPanel.h = orderH

	additionalPanel.x1 = tooltipPanel.x1
	additionalPanel.y1 = tooltipPanel.y2 + GAP_BETWEEN_PANELS
	additionalPanel.x2 = additionalPanel.x1 + panelW
	additionalPanel.y2 = additionalPanel.y1 + buildH
	additionalPanel.w = panelW
	additionalPanel.h = buildH
end

local function RoundedRectVertices(x1, y1, x2, y2, r, segments)
	local rr = math_min(r, (x2 - x1) * 0.5, (y2 - y1) * 0.5)
	if rr <= 0 then
		glVertex(x1, y1)
		glVertex(x2, y1)
		glVertex(x2, y2)
		glVertex(x1, y2)
		return
	end

	local function Arc(cx, cy, startAng, endAng)
		for i = 0, segments do
			local a = startAng + (endAng - startAng) * (i / segments)
			glVertex(cx + math_cos(a) * rr, cy + math_sin(a) * rr)
		end
	end

	Arc(x2 - rr, y2 - rr, 0, math_pi * 0.5)
	Arc(x1 + rr, y2 - rr, math_pi * 0.5, math_pi)
	Arc(x1 + rr, y1 + rr, math_pi, math_pi * 1.5)
	Arc(x2 - rr, y1 + rr, math_pi * 1.5, math_pi * 2)
end

local function DrawRoundedRect(x1, y1, x2, y2, r, color)
	local rr = math_min(r, (x2 - x1) * 0.5, (y2 - y1) * 0.5)

	glColor(color)
	glBeginEnd(GL_TRIANGLE_FAN, function()
		local cx = (x1 + x2) * 0.5
		local cy = (y1 + y2) * 0.5
		glVertex(cx, cy)
		RoundedRectVertices(x1, y1, x2, y2, rr, 6)

		if rr <= 0 then
			glVertex(x1, y1)
		else
			glVertex(x2, y2 - rr)
		end
	end)
end

local function DrawRoundedOutline(x1, y1, x2, y2, r, color)
	glColor(color)
	glLineWidth(1)
	glBeginEnd(GL_LINE_LOOP, function()
		RoundedRectVertices(x1, y1, x2, y2, r, 6)
	end)
end

local function DrawRectRound(px, py, sx, sy, cs)
	glTexCoord(0.8, 0.8)
	glVertex(px + cs, py, 0)
	glVertex(sx - cs, py, 0)
	glVertex(sx - cs, sy, 0)
	glVertex(px + cs, sy, 0)

	glVertex(px, py + cs, 0)
	glVertex(px + cs, py + cs, 0)
	glVertex(px + cs, sy - cs, 0)
	glVertex(px, sy - cs, 0)

	glVertex(sx, py + cs, 0)
	glVertex(sx - cs, py + cs, 0)
	glVertex(sx - cs, sy - cs, 0)
	glVertex(sx, sy - cs, 0)

	local o = 0.07

	-- bottom left
	glTexCoord(o,o)       glVertex(px, py, 0)
	glTexCoord(o,1-o)     glVertex(px+cs, py, 0)
	glTexCoord(1-o,1-o)   glVertex(px+cs, py+cs, 0)
	glTexCoord(1-o,o)     glVertex(px, py+cs, 0)

	-- bottom right
	glTexCoord(o,o)       glVertex(sx, py, 0)
	glTexCoord(o,1-o)     glVertex(sx-cs, py, 0)
	glTexCoord(1-o,1-o)   glVertex(sx-cs, py+cs, 0)
	glTexCoord(1-o,o)     glVertex(sx, py+cs, 0)

	-- top left
	glTexCoord(o,o)       glVertex(px, sy, 0)
	glTexCoord(o,1-o)     glVertex(px+cs, sy, 0)
	glTexCoord(1-o,1-o)   glVertex(px+cs, sy-cs, 0)
	glTexCoord(1-o,o)     glVertex(px, sy-cs, 0)

	-- top right
	glTexCoord(o,o)       glVertex(sx, sy, 0)
	glTexCoord(o,1-o)     glVertex(sx-cs, sy, 0)
	glTexCoord(1-o,1-o)   glVertex(sx-cs, sy-cs, 0)
	glTexCoord(1-o,o)     glVertex(sx, sy-cs, 0)
end

local function RectRound(px, py, sx, sy, cs)
	glTexture(bgcorner)
	gl.BeginEnd(GL_QUADS, DrawRectRound, px, py, sx, sy, cs)
	glTexture(false)
end

local function GetAccentForPanel(panelData, fallbackColor)
	if panelData and panelData.tech and TECH_TEXT_COLORS[panelData.tech] then
		local c = TECH_TEXT_COLORS[panelData.tech]
		return {c[1], c[2], c[3], 0.70}
	end
	return fallbackColor or TOOLTIP_ACCENT_COLOR
end

local function DrawPanel(x1, y1, x2, y2, accentColor)
	RectRound(x1, y1, x2, y2, PANEL_RADIUS)
	glColor(PANEL_OUTER_COLOR)
	RectRound(x1, y1, x2, y2, PANEL_RADIUS)

	glColor(PANEL_INNER_COLOR)
	RectRound(x1 + 2, y1 + 2, x2 - 2, y2 - 2, PANEL_RADIUS - 1)

	local accent = accentColor or TOOLTIP_ACCENT_COLOR
	glColor(accent)
	RectRound(x1 + 2, y2 - (2 + PANEL_ACCENT_HEIGHT), x2 - 2, y2 - 2, 3)
	glColor(1,1,1,1)
end

local function DrawSectionBox(x1, y1, x2, y2, accentColor)
	glColor(0.06, 0.06, 0.07, 0.65)
	RectRound(x1 + 1, y1, x2 - 1, y2, 8)

	local accent = accentColor or SECTION_ACCENT_COLOR
	glColor(accent)
	RectRound(x1 + 1, y2 - (1 + SECTION_ACCENT_HEIGHT), x2 - 1, y2 - 1, 3)
	glColor(1,1,1,1)
end

local function TextWidthApprox(text, size)
	return #tostring(text or "") * size * 0.55
end

local function DrawTextFitted(text, x, y, size, maxWidth, color, align)
	text = tostring(text or "")
	glColor(color or HEADER_TEXT)
	local drawSize = size
	local approxW = TextWidthApprox(text, size)
	if approxW > maxWidth and approxW > 0 then
		drawSize = size * (maxWidth / approxW)
	end
	glText(text, x, y, drawSize, (align or "o"))
end

local function WrapText(text, maxWidth, size)
	local lines = {}
	if not text or text == "" then
		return lines
	end

	for paragraph in (text .. "\n"):gmatch("([^\n]*)\n") do
		if paragraph == "" then
			lines[#lines + 1] = ""
		else
			local current = ""
			for word in paragraph:gmatch("%S+") do
				local candidate = (current == "") and word or (current .. " " .. word)
				if TextWidthApprox(candidate, size) <= maxWidth or current == "" then
					current = candidate
				else
					lines[#lines + 1] = current
					current = word
				end
			end
			if current ~= "" then
				lines[#lines + 1] = current
			end
		end
	end

	return lines
end

local function GetTooltipRole(ud)
	local str = ud and ud.customParams and ud.customParams.buildmenucategory
	if not str or str == "" then
		return "Unsorted"
	end
	return str
end

local TECH_REQUIREMENT_MAP = {
	tech0 = "T0",
	tech1 = "T1",
	tech2 = "T2",
	tech3 = "T3",
	tech4 = "T4",
}

local function GetTechTag(ud)
	if not ud or not ud.customParams then return nil end
	local req = ud.customParams.requiretech
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

--------------------------------------------------------------------------------
-- Weapon extraction / dedupe
--------------------------------------------------------------------------------

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

				card = {
					title = key,
					count = 1,
					perShot = damage,
					dps = dps,
					aoe = weap.damageAreaOfEffect or 0,
					range = weap.range or 0,
					eps = energyPerSecond,
					paralyze = isDisruptor,
					reload = reloadTime,
					water = weap.waterWeapon and true or false,
					guide = (weap.customParams and weap.customParams.weaponguide) or nil,
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

--------------------------------------------------------------------------------
-- Tooltip source resolution
--------------------------------------------------------------------------------

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

local function ResolveTooltipData()
	local currentTooltip = spGetCurrentTooltip() or ""

	local worldType, worldID = ResolveHoveredWorldObject()
	if worldType == "unit" and worldID then
		return { type = "unit", id = worldID }
	elseif worldType == "feature" and worldID then
		return { type = "feature", id = worldID }
	end

	-- Handle selection fallback (single or multi)
	local selectedUnits = spGetSelectedUnits()
	if selectedUnits and #selectedUnits == 1 then
		-- Single selected unit — prefer showing it over any order tooltip.
		return { type = "unit", id = selectedUnits[1] }
	elseif selectedUnits and #selectedUnits > 1 then
		return { type = "selection", units = selectedUnits }
	end

	-- UI tooltip content (build buttons / order buttons)
	local buildData = ResolveHoveredBuildFromTooltip(currentTooltip)
	if buildData then
		return buildData
	end

	local orderData = ResolveOrderFromTooltip(currentTooltip)
	if orderData then
		return orderData
	end

	return nil
end

--------------------------------------------------------------------------------
-- Section drawing
--------------------------------------------------------------------------------

local function DrawHeaderTag(x, y, text, color)
	if not text then return 0 end
	local w = math_floor(TextWidthApprox(text, SMALL_SIZE) + 10)
	local h = 16
	DrawRoundedRect(x, y - 3, x + w, y + h - 3, 5, CATEGORY_BG)
	DrawTextFitted(text, x + 5, y, SMALL_SIZE, w - 10, color or HEADER_TEXT, "o")
	return w + 4
end

local function DrawFlowLine(x, y, label, metalValue, energyValue)
	DrawTextFitted(label, x, y, BODY_SIZE, 140, MUTED_TEXT_COLOR, "o")

	local vx = x + 88
	DrawTextFitted("M ", vx, y, BODY_SIZE, 16, MUTED_TEXT_COLOR, "o")
	vx = vx + 12
	DrawTextFitted(metalValue or "-", vx, y, BODY_SIZE, 52,
	               (metalValue and metalValue:sub(1,1) == "-") and NEGATIVE_TEXT_COLOR or POSITIVE_TEXT_COLOR, "o")

	vx = vx + 42
	DrawTextFitted("   E ", vx, y, BODY_SIZE, 24, MUTED_TEXT_COLOR, "o")
	vx = vx + 24
	DrawTextFitted(energyValue or "-", vx, y, BODY_SIZE, 52,
	               (energyValue and energyValue:sub(1,1) == "-") and NEGATIVE_TEXT_COLOR or POSITIVE_TEXT_COLOR, "o")
end

local function DrawKVLine(x, y, label, value, labelColor, valueColor)
	DrawTextFitted(label, x, y, BODY_SIZE, 140, labelColor or MUTED_TEXT_COLOR, "o")
	DrawTextFitted(value or "-", x + 88, y, BODY_SIZE, 220, valueColor or HEADER_TEXT, "o")
end

local function DrawTitleSection(data, x1, yTop, w)
	local h = 44
	local y1 = yTop - h
	DrawSectionBox(x1, y1, x1 + w, yTop)

	local title = data.title or "Unknown"
	local subtitle = data.subtitle or ""

	DrawTextFitted(title, x1 + 10, yTop - 18, TITLE_SIZE, w - 20, HEADER_TEXT, "o")
	if subtitle ~= "" then
		DrawTextFitted(subtitle, x1 + 10, yTop - 34, BODY_SIZE, w - 20, SUBTEXT_COLOR, "o")
	end

	local tagX = x1 + w - 10
	if data.tech then
		local tagW = TextWidthApprox(data.tech, SMALL_SIZE) + 10
		tagX = tagX - tagW
		DrawHeaderTag(tagX, yTop - 18, data.tech, TECH_TEXT_COLORS[data.tech] or HEADER_TEXT)
	end

	return y1 - SECTION_GAP
end

local function DrawStatsSection_Static(data, x1, yTop, w)
	local lines = 3
	if data.healthText     then lines = lines + 1 end
	if data.overshieldText then lines = lines + 1 end
	if data.shieldText     then lines = lines + 1 end
	if data.statusText     then lines = lines + 1 end

	local h  = 24 + lines * LINE_H
	local y1 = yTop - h
	DrawSectionBox(x1, y1, x1 + w, yTop)
	DrawTextFitted("Stats", x1 + 10, yTop - 16, HEADER_SIZE, w - 20, HEADER_TEXT, "o")

	local cy = yTop - 32
	if data.roleText then
		DrawKVLine(x1 + 10, cy, "Role", data.roleText, MUTED_TEXT_COLOR, HEADER_TEXT)
		cy = cy - LINE_H
	end
	-- Labels are always drawn in the static pass (order: HP, OverShield, Shield, Status)
	-- For live units the value strings are filled in by the dynamic pass
	if data.healthText then
		DrawTextFitted("HP", x1 + 10, cy, BODY_SIZE, 80, MUTED_TEXT_COLOR, "o")
		if not data.isLiveUnit then
			DrawTextFitted(data.healthText, x1 + 98, cy, BODY_SIZE, w - 108, HEADER_TEXT, "o")
		end
		cy = cy - LINE_H
	end
	if data.overshieldText then
		DrawTextFitted("OverShield", x1 + 10, cy, BODY_SIZE, 80, MUTED_TEXT_COLOR, "o")
		if not data.isLiveUnit then
			DrawTextFitted(data.overshieldText, x1 + 98, cy, BODY_SIZE, w - 108, OVERSHIELD_TEXT_COLOR, "o")
		end
		cy = cy - LINE_H
	end
	if data.shieldText then
		DrawTextFitted("Shield", x1 + 10, cy, BODY_SIZE, 80, MUTED_TEXT_COLOR, "o")
		if not data.isLiveUnit then
			DrawTextFitted(data.shieldText, x1 + 98, cy, BODY_SIZE, w - 108, SHIELD_TEXT_COLOR, "o")
		end
		cy = cy - LINE_H
	end
	if data.statusText then
		DrawTextFitted("Status", x1 + 10, cy, BODY_SIZE, 80, MUTED_TEXT_COLOR, "o")
		if not data.isLiveUnit then
			DrawTextFitted(data.statusText, x1 + 98, cy, BODY_SIZE, w - 108, HEADER_TEXT, "o")
		end
	end

	return y1 - SECTION_GAP
end

-- Returns the y positions where dynamic values should be drawn, so the
-- dynamic list can draw just the value strings at the right coordinates.
local function CalcStatsDynamicPositions(data, x1, yTop, w)
	local lines = 3
	if data.healthText     then lines = lines + 1 end
	if data.overshieldText then lines = lines + 1 end
	if data.shieldText     then lines = lines + 1 end
	if data.statusText     then lines = lines + 1 end

	local h  = 24 + lines * 14
	local y1 = yTop - h

	-- skip role and armor (always static); also skip label-only rows (now static too)
	local cy = yTop - 32
	if data.roleText then cy = cy - 14 end

	local positions = { sectionY1 = y1, x1 = x1, w = w, baseY = cy }
	return positions
end

local function DrawStatsDynamic(data, pos)
	local cy = pos.baseY
	local x1 = pos.x1
	local w  = pos.w
	if data.healthText then
		DrawTextFitted(data.healthText, x1 + 98, cy, BODY_SIZE, w - 108, HEADER_TEXT, "o")
		cy = cy - LINE_H
	end
	if data.overshieldText then
		DrawTextFitted(data.overshieldText, x1 + 98, cy, BODY_SIZE, w - 108, OVERSHIELD_TEXT_COLOR, "o")
		cy = cy - LINE_H
	end
	if data.shieldText then
		DrawTextFitted(data.shieldText, x1 + 98, cy, BODY_SIZE, w - 108, SHIELD_TEXT_COLOR, "o")
		cy = cy - LINE_H
	end
	if data.statusText then
		DrawTextFitted(data.statusText, x1 + 98, cy, BODY_SIZE, w - 108, HEADER_TEXT, "o")
	end
end

local function DrawEconomySection_Static(data, x1, yTop, w)
	local h  = 92
	local y1 = yTop - h
	DrawSectionBox(x1, y1, x1 + w, yTop)

	DrawTextFitted("Economy", x1 + 10, yTop - 16, HEADER_SIZE, w - 20, HEADER_TEXT, "o")

	-- Labels are always static
	DrawTextFitted("Metal",   x1 + 10, yTop - 34, BODY_SIZE, 80, MUTED_TEXT_COLOR, "o")
	DrawTextFitted("Energy",  x1 + 10, yTop - 48, BODY_SIZE, 80, MUTED_TEXT_COLOR, "o")
	DrawTextFitted("Supply",  x1 + 10, yTop - 62, BODY_SIZE, 80, MUTED_TEXT_COLOR, "o")
	DrawTextFitted("Flow",    x1 + 10, yTop - 76, BODY_SIZE, 80, MUTED_TEXT_COLOR, "o")
	-- M / E sub-labels for flow
	DrawTextFitted("M ",  x1 + 98, yTop - 76, BODY_SIZE, 16, MUTED_TEXT_COLOR, "o")
	DrawTextFitted("   E ", x1 + 110 + 42, yTop - 76, BODY_SIZE, 24, MUTED_TEXT_COLOR, "o")

	-- Values are static for non-live sources
	if not data.isLiveUnit then
		DrawTextFitted(data.metalCostText  or "-", x1 + 98, yTop - 34, BODY_SIZE, w - 108, METAL_TEXT_COLOR,  "o")
		DrawTextFitted(data.energyCostText or "-", x1 + 98, yTop - 48, BODY_SIZE, w - 108, ENERGY_TEXT_COLOR, "o")
		local supplyColor = data.supplyText and SUPPLY_TEXT_COLOR or HEADER_TEXT
		DrawTextFitted(data.supplyText or "-",     x1 + 98, yTop - 62, BODY_SIZE, w - 108, supplyColor, "o")
		-- flow values
		local mv = data.metalFlowText
		local ev = data.energyFlowText
		local mvColor = (mv and mv:sub(1,1) == "-") and NEGATIVE_TEXT_COLOR or POSITIVE_TEXT_COLOR
		local evColor = (ev and ev:sub(1,1) == "-") and NEGATIVE_TEXT_COLOR or POSITIVE_TEXT_COLOR
		DrawTextFitted(mv or "-", x1 + 110,      yTop - 76, BODY_SIZE, 52, mvColor, "o")
		DrawTextFitted(ev or "-", x1 + 110 + 66, yTop - 76, BODY_SIZE, 52, evColor, "o")
	end

	return y1 - SECTION_GAP
end

local function DrawEconomyDynamic(data, x1, yTop, w)
	DrawTextFitted(data.metalCostText  or "-", x1 + 98, yTop - 34, BODY_SIZE, w - 108, METAL_TEXT_COLOR,  "o")
	DrawTextFitted(data.energyCostText or "-", x1 + 98, yTop - 48, BODY_SIZE, w - 108, ENERGY_TEXT_COLOR, "o")
	local supplyColor = data.supplyText and SUPPLY_TEXT_COLOR or HEADER_TEXT
	DrawTextFitted(data.supplyText or "-",     x1 + 98, yTop - 62, BODY_SIZE, w - 108, supplyColor, "o")
	local mv = data.metalFlowText
	local ev = data.energyFlowText
	local mvColor = (mv and mv:sub(1,1) == "-") and NEGATIVE_TEXT_COLOR or POSITIVE_TEXT_COLOR
	local evColor = (ev and ev:sub(1,1) == "-") and NEGATIVE_TEXT_COLOR or POSITIVE_TEXT_COLOR
	DrawTextFitted(mv or "-", x1 + 110,      yTop - 76, BODY_SIZE, 52, mvColor, "o")
	DrawTextFitted(ev or "-", x1 + 110 + 66, yTop - 76, BODY_SIZE, 52, evColor, "o")
end

-- Original combined versions kept for non-live paths (order, feature) where
-- there is no split needed and we just want a single draw call.
local function DrawStatsSection(data, x1, yTop, w)
	return DrawStatsSection_Static(data, x1, yTop, w)
end

local function DrawEconomySection(data, x1, yTop, w)
	return DrawEconomySection_Static(data, x1, yTop, w)
end


local function DrawBuildSection(data, x1, yTop, w)
	local h = 64
	local y1 = yTop - h
	DrawSectionBox(x1, y1, x1 + w, yTop)

	DrawTextFitted("Build Info", x1 + 10, yTop - 16, HEADER_SIZE, w - 20, HEADER_TEXT, "o")
	DrawKVLine(x1 + 10, yTop - 34, "Build Time", data.buildTimeText or "-", MUTED_TEXT_COLOR, HEADER_TEXT)
	DrawKVLine(x1 + 10, yTop - 48, "Build Power", data.buildPowerText or "-", MUTED_TEXT_COLOR, HEADER_TEXT)

	return y1 - SECTION_GAP
end

local function DrawOrderSection(data, x1, yTop, w)
	local body = data.body or ""
	local lines = 1
	for _ in body:gmatch("\n") do
		lines = lines + 1
	end
	lines = Clamp(lines, 2, 9)

	local h = 34 + lines * 13
	local y1 = yTop - h
	DrawSectionBox(x1, y1, x1 + w, yTop)

	DrawTextFitted("Command", x1 + 10, yTop - 16, HEADER_SIZE, w - 20, HEADER_TEXT, "o")

	local clean = string_gsub(body, "Metal cost %d*\nEnergy cost %d*\n", "")
	local cy = yTop - 34
	for line in (clean .. "\n"):gmatch("([^\n]*)\n") do
		if line ~= "" then
			DrawTextFitted(line, x1 + 10, cy, BODY_SIZE, w - 20, SUBTEXT_COLOR, "o")
			cy = cy - 13
		end
	end

	return y1 - SECTION_GAP
end

local function DrawWeaponCards(cards, x1, yTop, w, clipBottom)
	if not cards or #cards == 0 then
		return yTop
	end

	local guideWrapWidth = w - 32
	local guideLineH = 11
	local baseCardH = 52
	local layout = {}
	local totalCardsH = 0

	for i = 1, #cards do
		local card = cards[i]
		local guideLines = {}
		local extraH = 0
		if card.guide and card.guide ~= "" then
			guideLines = WrapText(card.guide, guideWrapWidth, SMALL_SIZE)
			extraH = #guideLines * guideLineH + 6
		end

		local cardH = baseCardH + extraH
		layout[i] = {
			card = card,
			cardH = cardH,
			guideLines = guideLines,
		}
		totalCardsH = totalCardsH + cardH
		if i < #cards then
			totalCardsH = totalCardsH + CARD_GAP
		end
	end

	local headerH = 22
	local totalH = headerH + totalCardsH + 10
	local y1 = yTop - totalH

	DrawSectionBox(x1, y1, x1 + w, yTop)
	DrawTextFitted("Weapons", x1 + 10, yTop - 16, HEADER_SIZE, w - 20, HEADER_TEXT, "o")

	glScissor(x1, clipBottom, w, yTop - clipBottom)
	local cyTop = yTop - 26

	for i = 1, #layout do
		local entry = layout[i]
		local card = entry.card
		local by2 = cyTop
		local by1 = by2 - entry.cardH

		if by2 >= clipBottom then
			DrawRoundedRect(x1 + 8, by1, x1 + w - 8, by2, 6, CATEGORY_BG)
			glColor(CATEGORY_CARD_ACCENT_COLOR)
			RectRound(x1 + 8, by2 - (1 + SECTION_ACCENT_HEIGHT), x1 + w - 8, by2 - 1, 3)
			glColor(1,1,1,1)
			DrawTextFitted(card.title .. (card.count > 1 and (" x" .. card.count) or ""), x1 + 16, by2 - 14, BODY_SIZE, w - 32, HEADER_TEXT, "o")

			local dmgLabel = card.paralyze and "Paralyze" or "DPS"
			local dmgColor = card.paralyze and PARALYZE_TEXT_COLOR or HEADER_TEXT

			DrawTextFitted(dmgLabel .. ": " .. FormatNbr(card.dps, 1), x1 + 16, by2 - 28, SMALL_SIZE, 110, dmgColor, "o")
			DrawTextFitted("Range: " .. FormatNbr(card.range, 0), x1 + 112, by2 - 28, SMALL_SIZE, 78, SUBTEXT_COLOR, "o")
			DrawTextFitted("AoE: " .. FormatNbr(card.aoe, 0), x1 + 178, by2 - 28, SMALL_SIZE, 62, SUBTEXT_COLOR, "o")

			local extra = ""
			if card.eps and card.eps > 0 then
				extra = extra .. "E/s " .. FormatNbr(card.eps, 1)
			end
			if card.water then
				if extra ~= "" then extra = extra .. "   " end
				extra = extra .. "WATER"
			end
			if extra ~= "" then
				DrawTextFitted(extra, x1 + 16, by2 - 41, SMALL_SIZE, w - 32, ENERGY_TEXT_COLOR, "o")
			end

			if entry.guideLines and #entry.guideLines > 0 then
				local gy = by2 - 54
				for j = 1, #entry.guideLines do
					if gy >= clipBottom then
						DrawTextFitted(entry.guideLines[j], x1 + 16, gy, SMALL_SIZE, w - 32, SUBTEXT_COLOR, "o")
					end
					gy = gy - guideLineH
				end
			end
		end

		cyTop = by1 - CARD_GAP
	end

	glScissor(false)
	return y1 - SECTION_GAP
end

local function DrawGuideSection(guideText, x1, yTop, w, clipBottom)
	if not guideText or guideText == "" then
		return yTop
	end

	local wrapWidth = w - 20
	local lines = WrapText(guideText, wrapWidth, BODY_SIZE)
	if #lines == 0 then
		return yTop
	end

	local lineH = 13
	local totalH = 26 + (#lines * lineH) + 10
	local y1 = yTop - totalH

	DrawSectionBox(x1, y1, x1 + w, yTop)
	DrawTextFitted("Unit Guide", x1 + 10, yTop - 16, HEADER_SIZE, w - 20, HEADER_TEXT, "o")

	glScissor(x1, clipBottom, w, yTop - clipBottom)
	local cy = yTop - 34
	for i = 1, #lines do
		if cy >= clipBottom then
			DrawTextFitted(lines[i], x1 + 10, cy, BODY_SIZE, w - 20, SUBTEXT_COLOR, "o")
		end
		cy = cy - lineH
	end
	glScissor(false)

	return y1 - SECTION_GAP
end

local function DrawHintSection(text, x1, yTop, w)
	local h = 26
	local y1 = yTop - h
	DrawSectionBox(x1, y1, x1 + w, yTop)
	DrawTextFitted(text, x1 + 10, yTop - 17, SMALL_SIZE, w - 20, HINT_TEXT_COLOR, "o")
	return y1 - SECTION_GAP
end

--------------------------------------------------------------------------------
-- Data builders
--------------------------------------------------------------------------------

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
	local shieldMaxStrength  = ud.customParams and ud.customParams.shield_max_strength

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

local function BuildUnitPanelData(unitID)
	local ud = UnitDefs[spGetUnitDefID(unitID)]
	if not ud then return nil end

	local metalMake, metalUse, energyMake, energyUse = spGetUnitResources(unitID)
	local health, maxHealth, _, _, buildProgress = spGetUnitHealth(unitID)
	local _, stunned, beingBuilt = spGetUnitIsStunned(unitID)
	local hasShield, shieldPower = spGetUnitShieldState(unitID)
	local maxShieldPower = ud.shieldWeaponDef and WeaponDefs[ud.shieldWeaponDef] and WeaponDefs[ud.shieldWeaponDef].shieldPower or nil
	local overshieldStrength = spGetUnitRulesParam(unitID, "personalShield")
	local shieldMaxStrength = ud.customParams and ud.customParams.shield_max_strength

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

		roleText = GetTooltipRole(ud),
		healthText = health and (FormatNbr(health, 0) .. "/" .. FormatNbr(maxHealth, 0)) or nil,
		shieldText = (hasShield and maxShieldPower) and (FormatNbr(math_min(shieldPower, maxShieldPower), 0) .. "/" .. FormatNbr(maxShieldPower, 0)) or nil,
		overshieldText = (overshieldStrength and shieldMaxStrength) and (FormatNbr(math_min(overshieldStrength, shieldMaxStrength), 0) .. "/" .. FormatNbr(shieldMaxStrength, 0)) or nil,
		statusText = (#status > 0) and table_concat(status, ", ") or nil,

		metalCostText = FormatNbr(ud.metalCost or 0, 0),
		energyCostText = FormatNbr(ud.energyCost or 0, 0),
		supplyText = supplyText,
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

		roleText = ud and GetTooltipRole(ud) or nil,
		healthText = ud and FormatNbr(ud.health, 0) or (buildData.health and FormatNbr(buildData.health, 0) or nil),
		shieldText = (ud and ud.shieldWeaponDef and WeaponDefs[ud.shieldWeaponDef]) and FormatNbr(WeaponDefs[ud.shieldWeaponDef].shieldPower, 0) or nil,
		overshieldText = (ud and ud.customParams and ud.customParams.isshieldedunit == "1" and ud.customParams.shield_max_strength) and FormatNbr(ud.customParams.shield_max_strength, 0) or nil,
		statusText = humanNameToKeySymbols[buildData.name] and ("Hotkey: " .. humanNameToKeySymbols[buildData.name]) or nil,

		metalCostText = FormatNbr(buildData.metalCost or (ud and ud.metalCost or 0), 0),
		energyCostText = FormatNbr(buildData.energyCost or (ud and ud.energyCost or 0), 0),
		supplyText = supplyText,
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

	local reclaimLeft, metal, energy = spGetFeatureResources(featureID)
	local health, maxHealth = spGetFeatureHealth(featureID)

	return {
		title = fd.name or "Feature",
		subtitle = fd.tooltip or "Map Feature",
		tech = nil,

		roleText = "Feature",
		healthText = health and maxHealth and (FormatNbr(health, 0) .. "/" .. FormatNbr(maxHealth, 0)) or nil,
		shieldText = nil,
		overshieldText = nil,
		statusText = reclaimLeft and ("Reclaim left: " .. FormatNbr(reclaimLeft, 0) .. "%") or nil,

		metalCostText = metal and FormatNbr(metal, 0) or "-",
		energyCostText = energy and FormatNbr(energy, 0) or "-",
		supplyText = nil,
		metalFlowText = nil,
		energyFlowText = nil,

		buildTimeText = nil,
		buildPowerText = nil,

		weaponCards = {},
		unitGuideText = nil,
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
			if ud.customParams and ud.customParams.requiretech then
				local TECH_MAP = { tech0="T0", tech1="T1", tech2="T2", tech3="T3", tech4="T4" }
				tech = TECH_MAP[string_lower(tostring(ud.customParams.requiretech))]
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

--------------------------------------------------------------------------------
-- Additional info
--------------------------------------------------------------------------------

local function CanShowAdditionalInfo(resolved)
	return resolved and (resolved.type == "unit" or resolved.type == "build")
end

-- These store the layout coords needed by the dynamic pass for live units.
local dynamicStatsPos   = nil   -- from CalcStatsDynamicPositions
local dynamicEconomyX1  = nil
local dynamicEconomyTop = nil
local dynamicEconomyW   = nil

--------------------------------------------------------------------------------
-- Display list baking
--------------------------------------------------------------------------------

local function DrawSelectionSection(panelData, x1, yTop, w)
	local rows    = panelData.rows or {}
	local rowH    = LINE_H
	local headerH = 22
	local footerH = 28   -- economy summary
	local totalH  = headerH + #rows * rowH + footerH + 10
	local y1      = yTop - totalH

	DrawSectionBox(x1, y1, x1 + w, yTop)

	-- Header
	DrawTextFitted("Units", x1 + 10, yTop - 16, HEADER_SIZE, w - 20, HEADER_TEXT, "o")

	-- Unit rows
	local cy = yTop - headerH - rowH + 4
	for i = 1, #rows do
		local row   = rows[i]
		local nameW = w - 50   -- leave room for count on right

		-- Tech tag
		local tagW = 0
		if row.tech then
			local tc = TECH_TEXT_COLORS[row.tech] or HEADER_TEXT
			DrawTextFitted(row.tech, x1 + 10, cy, SMALL_SIZE, 24, tc, "o")
			tagW = 28
		end

		-- Unit name
		DrawTextFitted(row.name, x1 + 10 + tagW, cy, BODY_SIZE, nameW - tagW, HEADER_TEXT, "o")

		-- Count on right
		DrawTextFitted("x" .. row.count, x1 + w - 6, cy, BODY_SIZE, 40, MUTED_TEXT_COLOR, "or")

		cy = cy - rowH
	end

	-- Economy summary separator line
	local sepY = y1 + footerH
	glColor(1, 1, 1, 0.06)
	glRect(x1 + 6, sepY, x1 + w - 6, sepY + 1)

	-- Economy row
	local ey = y1 + footerH - 10
	local mv = panelData.metalFlowText
	local ev = panelData.energyFlowText
	DrawTextFitted("M", x1 + 10,      ey, BODY_SIZE, 14, MUTED_TEXT_COLOR, "o")
	DrawTextFitted(mv or "-", x1 + 22, ey, BODY_SIZE, 60,
	               (mv and mv:sub(1,1) == "-") and NEGATIVE_TEXT_COLOR or POSITIVE_TEXT_COLOR, "o")
	DrawTextFitted("E", x1 + 88,       ey, BODY_SIZE, 14, MUTED_TEXT_COLOR, "o")
	DrawTextFitted(ev or "-", x1 + 100, ey, BODY_SIZE, 60,
	               (ev and ev:sub(1,1) == "-") and NEGATIVE_TEXT_COLOR or POSITIVE_TEXT_COLOR, "o")
	if panelData.supplyText then
		DrawTextFitted("S", x1 + 166,       ey, BODY_SIZE, 14, MUTED_TEXT_COLOR, "o")
		DrawTextFitted(panelData.supplyText, x1 + 178, ey, BODY_SIZE, 50, SUPPLY_TEXT_COLOR, "o")
	end

	return y1 - SECTION_GAP
end

local function BakeStaticList(panelData, isOrder, showAdditional)
	local x1, y1, x2, y2 = tooltipPanel.x1, tooltipPanel.y1, tooltipPanel.x2, tooltipPanel.y2
	if x2 > vsx - 8 then return end

	local CORNER_SAFE_TOP    = PANEL_RADIUS + 3
	local CORNER_SAFE_SIDE   = PANEL_RADIUS + 3
	local CORNER_SAFE_BOTTOM = INNER_PAD - 2

	local top    = y2 - CORNER_SAFE_TOP
	local bottom = y1 + CORNER_SAFE_BOTTOM
	local sx     = x1 + CORNER_SAFE_SIDE
	local width  = (x2 - x1) - (CORNER_SAFE_SIDE * 2)
	local cy     = top

	DrawPanel(x1, y1, x2, y2, GetAccentForPanel(panelData, TOOLTIP_ACCENT_COLOR))
	cy = DrawTitleSection(panelData, sx, cy, width)

	if panelData.type == "selection" then
		DrawSelectionSection(panelData, sx, cy, width)
		return
	elseif isOrder then
		cy = DrawOrderSection(panelData, sx, cy, width)
		DrawHintSection(TOOLTIP_HINT_TEXT, sx, cy, width)
	else
		cy = DrawStatsSection_Static(panelData, sx, cy, width)

		-- Record where economy section top will be for dynamic pass
		dynamicEconomyX1  = sx
		dynamicEconomyTop = cy
		dynamicEconomyW   = width

		-- Record stats dynamic positions
		if panelData.isLiveUnit then
			local lines = 3
			if panelData.healthText     then lines = lines + 1 end
			if panelData.shieldText     then lines = lines + 1 end
			if panelData.overshieldText then lines = lines + 1 end
			if panelData.statusText     then lines = lines + 1 end
			local statsH = 24 + lines * LINE_H
			local statsYTop = cy + statsH + SECTION_GAP  -- reverse the section gap
			dynamicStatsPos = CalcStatsDynamicPositions(panelData, sx, statsYTop, width)
		else
			dynamicStatsPos = nil
		end

		cy = DrawEconomySection_Static(panelData, sx, cy, width)
		DrawHintSection(TOOLTIP_HINT_TEXT, sx, cy, width)
	end

	-- Additional panel (entirely static — no live values there)
	if showAdditional then
		local ax1, ay1, ax2, ay2 = additionalPanel.x1, additionalPanel.y1, additionalPanel.x2, additionalPanel.y2
		if ax2 <= vsx - 8 then
			DrawPanel(ax1, ay1, ax2, ay2, GetAccentForPanel(panelData, ADDITIONAL_ACCENT_COLOR))
			local atop   = ay2 - CORNER_SAFE_TOP
			local abottom = ay1 + CORNER_SAFE_BOTTOM
			local asx    = ax1 + CORNER_SAFE_SIDE
			local awidth = (ax2 - ax1) - (CORNER_SAFE_SIDE * 2)
			local acy    = atop

			acy = DrawTitleSection({ title = "Additional Info", subtitle = panelData.title or "", tech = panelData.tech }, asx, acy, awidth)
			acy = DrawHintSection(ADDITIONAL_HINT_TEXT, asx, acy, awidth)

			if panelData.buildTimeText or panelData.buildPowerText then
				acy = DrawBuildSection(panelData, asx, acy, awidth)
			end
			if panelData.weaponCards and #panelData.weaponCards > 0 and acy > abottom + 60 then
				acy = DrawWeaponCards(panelData.weaponCards, asx, acy, awidth, abottom + 4)
			end
			if acy > abottom + 40 and panelData.unitGuideText and panelData.unitGuideText ~= "" then
				DrawGuideSection(panelData.unitGuideText, asx, acy, awidth, abottom + 4)
			end
		end
	end
end

local function BakeDynamicList(panelData)
	-- Only called for live units; draws just the changing value strings.
	if dynamicStatsPos then
		DrawStatsDynamic(panelData, dynamicStatsPos)
	end
	if dynamicEconomyX1 then
		DrawEconomyDynamic(panelData, dynamicEconomyX1, dynamicEconomyTop, dynamicEconomyW)
	end
end

local function RebuildAllLists(panelData, isOrder, showAdditional)
	FreeDisplayLists()
	if not panelData then return end

	staticList = gl.CreateList(function()
		BakeStaticList(panelData, isOrder, showAdditional)
	end)

	if panelData.isLiveUnit then
		dynamicList = gl.CreateList(function()
			BakeDynamicList(panelData)
		end)
	end
end

--------------------------------------------------------------------------------
-- Widget callins
--------------------------------------------------------------------------------

function widget:Initialize()
	UpdateRects()
	spSendCommands({"tooltip 0"})
	spSetDrawSelectionInfo(false)

	for _, ud in pairs(UnitDefs) do
		ud.shieldPower = 0
		local shieldDefID = ud.shieldWeaponDef
		ud.shieldPower = ((shieldDefID) and (WeaponDefs[shieldDefID].shieldPower)) or (-1)
	end
end

function widget:Shutdown()
	FreeDisplayLists()
	spSendCommands({"tooltip 1"})
end


function widget:ViewResize()
	UpdateRects()
	cachedResolvedKey = nil
	cachedPanelData   = nil
	FreeDisplayLists()
end

function widget:Update()
	ui_opacity = tonumber(spGetConfigFloat("ui_opacity", 0.66) or 0.66)
end

function widget:KeyPress(key, mods, isRepeat)
	if isRepeat then return false end
	if key == KEYSYMS.SPACE then
		additionalInfoEnabled = not additionalInfoEnabled
		-- DrawScreen will detect lastShowAdditional changed and rebuild safely
		return true
	end
	return false
end

function widget:DrawScreen()
	if spIsGUIHidden() then return end
	if not spGetCurrentTooltip then return end

	local resolved = ResolveTooltipData()
	local key      = ResolvedKey(resolved)
	local showAdditional = additionalInfoEnabled and resolved and CanShowAdditionalInfo(resolved)

	-- If the additional panel was toggled, rebuild the static list with the same data
	if showAdditional ~= lastShowAdditional and cachedPanelData then
		lastShowAdditional = showAdditional
		RebuildAllLists(cachedPanelData, cachedIsOrder, showAdditional)
	end

	if key ~= cachedResolvedKey then
		-- Source changed — rebuild data and all display lists
		cachedResolvedKey = key
		if resolved then
			cachedPanelData, cachedIsOrder = BuildPanelDataFromResolved(resolved)
			cachedIsLiveUnit = (resolved.type == "unit")
			if cachedPanelData then
				cachedPanelData.isLiveUnit = cachedIsLiveUnit
			end
		else
			cachedPanelData  = nil
			cachedIsOrder    = false
			cachedIsLiveUnit = false
		end
		lastDynValues = {}  -- reset so new unit always compiles its first dynamic list
		lastShowAdditional = showAdditional
		RebuildAllLists(cachedPanelData, cachedIsOrder, showAdditional)

	elseif cachedIsOrder and cachedPanelData and resolved then
		-- Same order command — only rebuild if body text actually changed
		local newBody = resolved.body or ""
		if cachedPanelData.body ~= newBody then
			cachedPanelData.body = newBody
			RebuildAllLists(cachedPanelData, cachedIsOrder, showAdditional)
		end

	elseif cachedIsLiveUnit and cachedPanelData then
		-- Same live unit — refresh values, but only recompile the dynamic list
		-- if something actually changed. This avoids gl.DeleteList+CreateList every frame.
		RefreshLiveUnitFields(cachedPanelData, resolved.id)
		if not dynamicList or DynamicValuesChanged(cachedPanelData) then
			SaveDynamicValues(cachedPanelData)
			if dynamicList then gl.DeleteList(dynamicList) ; dynamicList = nil end
			dynamicList = gl.CreateList(function()
				BakeDynamicList(cachedPanelData)
			end)
		end
	end

	if not staticList then return end

	gl.CallList(staticList)
	if dynamicList then
		gl.CallList(dynamicList)
	end
end