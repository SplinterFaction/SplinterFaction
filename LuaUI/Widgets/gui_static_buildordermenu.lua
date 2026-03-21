function widget:GetInfo()
    return {
        name    = "Static Build/Order Menu",
        desc    = "Non-Chili build and order menu with categorized build sections",
        author  = "OpenAI",
        date    = "2026-03-21",
        license = "GPL v2 or later",
        layer   = 1,
        enabled = true,
        handler = true,
    }
end

--------------------------------------------------------------------------------
-- Config
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
local SECTION_BG            = {0.14, 0.14, 0.15, 0.90}
local CATEGORY_BG           = {0.20, 0.20, 0.21, 0.55}
local HEADER_TEXT           = {1.0, 1.0, 1.0, 1.0}
local DISABLED_OVERLAY      = {0.0, 0.0, 0.0, 0.60}
local HOVER_OVERLAY         = {0.90, 0.90, 0.90, 0.10}
local ACTIVE_OVERLAY        = {0.95, 0.78, 0.15, 0.28}
local SCROLLBAR_BG          = {1.0, 1.0, 1.0, 0.06}
local SCROLLBAR_THUMB       = {1.0, 1.0, 1.0, 0.20}
local SCROLLBAR_THUMB_HOVER = {1.0, 1.0, 1.0, 0.30}

local INNER_PAD             = 10
local BUTTON_PAD            = 4
local BUILD_COLUMNS         = 3
local ORDER_COLUMNS         = 5
local ORDER_ROWS            = 5
local SECTION_H             = 26
local CATEGORY_H            = 20
local SECTION_GAP           = 6
local CATEGORY_GAP          = 4
local BUILD_GRID_GAP        = 8
local ORDER_GRID_GAP        = 6
local BUILD_INFO_H          = 40
local SCROLLBAR_W           = 10
local SCROLL_STEP           = 56

local SHOW_HOTKEYS_CONFIG   = "evo_showhotkeys"
local SHOW_COST_CONFIG      = "evo_showcost"
local SHOW_TECHREQ_CONFIG   = "evo_showtechreq"

local FAMILY_CATEGORY_ORDER = {
    Factory = { "Scout", "Skirmish", "Support", "Utility", "Unsorted" },
    Builder = { "Economy", "Production", "Combat", "Utility", "Unsorted" },
}

local FAMILY_SECTION_TITLES = {
    Factory = "Factory Units",
    Builder = "Structures",
}

local TECH_TEXT_COLORS = {
    T0 = {0.0, 0.8, 0.8, 1.0},
    T1 = {1.0, 0.5, 0.0, 1.0},
    T2 = {1.0, 0.0, 1.0, 1.0},
    T3 = {0.0, 1.0, 0.0, 1.0},
    T4 = {1.0, 0.0, 0.0, 1.0},
}

local METAL_TEXT_COLOR  = {0.53, 0.77, 0.89, 1.0}
local ENERGY_TEXT_COLOR = {1.0, 1.0, 0.0, 1.0}

--------------------------------------------------------------------------------
-- Spring / GL locals
--------------------------------------------------------------------------------

local spGetViewGeometry      = Spring.GetViewGeometry
local spForceLayoutUpdate    = Spring.ForceLayoutUpdate
local spSetActiveCommand     = Spring.SetActiveCommand
local spGetCmdDescIndex      = Spring.GetCmdDescIndex
local spGetActiveCommand     = Spring.GetActiveCommand
local spGetConfigInt         = Spring.GetConfigInt
local spGetSelectedUnits     = Spring.GetSelectedUnits
local spGetUnitDefID         = Spring.GetUnitDefID
local spGetMouseState        = Spring.GetMouseState
local spGetKeySymbol         = Spring.GetKeySymbol
local spIsGUIHidden          = Spring.IsGUIHidden
local spGetModKeyState       = Spring.GetModKeyState

local glColor                = gl.Color
local glRect                 = gl.Rect
local glText                 = gl.Text
local glTexture              = gl.Texture
local glTexRect              = gl.TexRect
local glScissor              = gl.Scissor
local glBeginEnd             = gl.BeginEnd
local glVertex               = gl.Vertex
local GL_TRIANGLE_FAN        = GL.TRIANGLE_FAN
local GL_LINE_LOOP           = GL.LINE_LOOP

local math_min               = math.min
local math_max               = math.max
local math_floor             = math.floor
local math_ceil              = math.ceil
local math_pi                = math.pi
local math_cos               = math.cos
local math_sin               = math.sin
local string_find            = string.find
local string_sub             = string.sub
local string_gsub            = string.gsub
local type                   = type

--------------------------------------------------------------------------------
-- Hotkey config from existing system
--------------------------------------------------------------------------------

VFS.Include("luaui/configs/evo_buildHotkeysConfig.lua")

local function GetKeySymbol(k)
    if k >= 97 and k <= 122 then
        return string.char(k):upper()
    end
    local keySymbol = spGetKeySymbol(k)
    return keySymbol:sub(1, 1):upper() .. keySymbol:sub(2)
end

local nameToKeySymbols = {}
for unitDefID = 1, #UnitDefs do
    local ud = UnitDefs[unitDefID]
    local trimmedName = ud.name
    if trimmedName:find("_up", -5) then
        trimmedName = trimmedName:sub(1, -5)
    end
    if nameToKeyCode[trimmedName] then
        nameToKeySymbols[ud.name] = {}
        for i = 1, #nameToKeyCode[trimmedName] do
            nameToKeySymbols[ud.name][i] = GetKeySymbol(nameToKeyCode[trimmedName][i])
        end
    end
end

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local vsx, vsy = spGetViewGeometry()
local showHotkeys = spGetConfigInt(SHOW_HOTKEYS_CONFIG, 1) == 1
local showCost    = spGetConfigInt(SHOW_COST_CONFIG, 1) == 1
local showTechReq = spGetConfigInt(SHOW_TECHREQ_CONFIG, 1) == 1

local orderPanel = {}
local buildPanel = {}

local commandsDirty = true
local lastCommands
local currentCommands = { [1] = {}, [2] = {}, [3] = {} } -- state, order, build
local processedBuild = nil
local buildScrollOffset = 0
local buildContentHeight = 0
local buildViewHeight = 0
local hoveredItem = nil
local tooltipText = nil
local interactiveItems = {}
local currentBuildHitboxes = {}
local currentOrderHitboxes = {}
local scrollbarInfo = nil
local draggingScrollbar = false
local scrollbarDragOffset = 0
local showBuildPanel = false
local showOrderPanel = false

local hiddenCMDs = {
    timewait = true,
    deathwait = true,
    squadwait = true,
    gatherwait = true,
    loadonto = true,
    selfd = false,
    settargetnoground = true,
}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function DeepEquals(t1, t2, ignore_mt)
    if t1 == t2 then return true end
    local ty1 = type(t1)
    local ty2 = type(t2)
    if ty1 ~= ty2 then return false end
    if ty1 ~= 'table' then return t1 == t2 end
    local mt = getmetatable(t1)
    if not ignore_mt and mt and mt.__eq then return t1 == t2 end
    for k1, v1 in pairs(t1) do
        local v2 = t2[k1]
        if v2 == nil or not DeepEquals(v1, v2) then return false end
    end
    for k2, v2 in pairs(t2) do
        local v1 = t1[k2]
        if v1 == nil or not DeepEquals(v1, v2) then return false end
    end
    return true
end

local function Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function IsInside(x, y, bx1, by1, bx2, by2)
    return x >= bx1 and x <= bx2 and y >= by1 and y <= by2
end

local function NormalizeProducerRole(unitRole)
    if unitRole == "Commander" or unitRole == "Builder" then
        return "Builder"
    elseif unitRole == "Factory" then
        return "Factory"
    end
    return nil
end

local function UpdatePanelRects()
    vsx, vsy = spGetViewGeometry()

    local panelW = math_floor(vsx * PANEL_WIDTH_FRAC)
    local totalH = math_floor(vsy * TOTAL_HEIGHT_FRAC)
    local orderH = math_floor(totalH * ORDER_HEIGHT_FRAC)
    local buildH = totalH - orderH - GAP_BETWEEN_PANELS

    orderPanel.x1 = PANEL_MARGIN_X
    orderPanel.y1 = PANEL_MARGIN_Y
    orderPanel.x2 = orderPanel.x1 + panelW
    orderPanel.y2 = orderPanel.y1 + orderH
    orderPanel.w = panelW
    orderPanel.h = orderH

    buildPanel.x1 = PANEL_MARGIN_X
    buildPanel.y1 = orderPanel.y2 + GAP_BETWEEN_PANELS
    buildPanel.x2 = buildPanel.x1 + panelW
    buildPanel.y2 = buildPanel.y1 + buildH
    buildPanel.w = panelW
    buildPanel.h = buildH
end

local function AddInteractiveItem(item)
    interactiveItems[#interactiveItems + 1] = item
end

local function FormatSupplyValue(v)
    if not v then return nil end
    if v == math_floor(v) then
        return tostring(math_floor(v))
    end
    return tostring(v)
end

local function ParseBuildOverlay(cmd)
    local supplyText, metalText, energyText, techText = nil, nil, nil, nil

    if showCost then
        local buildDefID = -cmd.id
        local ud = UnitDefs[buildDefID]
        local cp = ud and ud.customParams
        if cp then
            local supplyGranted = tonumber(cp.supply_granted or cp.supplyGranted)
            local supplyCost = tonumber(cp.supply_cost or cp.supplyCost)

            if supplyGranted and supplyGranted ~= 0 then
                supplyText = "+" .. FormatSupplyValue(supplyGranted)
            elseif supplyCost and supplyCost ~= 0 then
                supplyText = "-" .. FormatSupplyValue(supplyCost)
            end
        end

        local s, e = string_find(cmd.tooltip, 'Metal cost %d*')
        if s and e then
            metalText = string_sub(cmd.tooltip, s + 11, e)
        end
        s, e = string_find(cmd.tooltip, 'Energy cost %d*')
        if s and e then
            energyText = string_sub(cmd.tooltip, s + 12, e)
        end
    end

    if showTechReq and (string_find(cmd.tooltip, 'Requires') or string_find(cmd.tooltip, 'Provides')) then
        local s, e = string_find(cmd.tooltip, 'tech%d*')
        if s and e then
            techText = "T" .. string_sub(cmd.tooltip, s + 4, e)
        end
    end

    return {
        supply = supplyText,
        metal = metalText,
        energy = energyText,
        tech = techText,
    }
end

local function GetHotkeyText(cmd)
    if not showHotkeys then return nil end
    if not (widgetHandler.orderList["SplinterFaction Build Hotkeys"] and widgetHandler.orderList["SplinterFaction Build Hotkeys"] ~= 0) then
        return nil
    end
    local keys = nameToKeySymbols[cmd.name]
    if not keys then return nil end

    if WG.buildHotkeys and WG.buildHotkeys.keysPressed then
        local str = ""
        local matching = true
        local pressedCount = #WG.buildHotkeys.keysPressed
        for i = 1, #keys do
            if i <= pressedCount and matching and keys[i] ~= WG.buildHotkeys.keysPressed[i] then
                matching = false
            end
            str = str .. keys[i]
            if i < #keys then
                str = str .. "+"
            end
        end
        return str, matching
    end

    return table.concat(keys, "+"), false
end

local function GetSelectedProducerFamilyData()
    local selectedUnits = spGetSelectedUnits()
    local familyData = {
        Builder = { canBuild = {}, hasProducer = false },
        Factory = { canBuild = {}, hasProducer = false },
    }

    for i = 1, #selectedUnits do
        local unitDefID = spGetUnitDefID(selectedUnits[i])
        if unitDefID then
            local ud = UnitDefs[unitDefID]
            if ud and ud.customParams then
                local family = NormalizeProducerRole(ud.customParams.unitrole)
                if family then
                    familyData[family].hasProducer = true
                    if ud.buildOptions then
                        for j = 1, #ud.buildOptions do
                            familyData[family].canBuild[ud.buildOptions[j]] = true
                        end
                    end
                end
            end
        end
    end

    return familyData
end

local function GetBuildCategoryForUnitDef(buildDefID)
    local ud = UnitDefs[buildDefID]
    if not ud or not ud.customParams then
        return "Unsorted"
    end
    return ud.customParams.buildmenucategory or "Unsorted"
end

local function SelectionHasProducer()
    local sel = spGetSelectedUnits()
    if not sel or #sel == 0 then
        return false
    end

    for i = 1, #sel do
        local unitDefID = spGetUnitDefID(sel[i])
        if unitDefID then
            local ud = UnitDefs[unitDefID]
            if ud then
                if ud.buildOptions and #ud.buildOptions > 0 then
                    return true
                end
                if ud.isBuilder then
                    return true
                end
                if ud.customParams and ud.customParams.unitrole then
                    local role = ud.customParams.unitrole
                    if role == "Builder" or role == "Commander" or role == "Factory" then
                        return true
                    end
                end
            end
        end
    end

    return false
end

local function UpdatePanelVisibility(orderCount, buildCount)
    local sel = spGetSelectedUnits()
    local hasSelection = sel and #sel > 0
    local hasProducer = false

    showBuildPanel = false
    showOrderPanel = false

    if not hasSelection then
        return
    end

    hasProducer = SelectionHasProducer()

    if hasProducer then
        showBuildPanel = (buildCount > 0)
        showOrderPanel = true
    else
        showBuildPanel = false
        showOrderPanel = (orderCount > 0)
    end
end

local function ProcessCommand(cmd)
    if UnitDefNames[cmd.name] then
        return 3
    elseif #cmd.params > 1 then
        return 1
    else
        return 2
    end
end

local function ProcessAllCommands(flush)
    if DeepEquals(lastCommands, widgetHandler.commands) and not flush then
        return
    end

    lastCommands = widgetHandler.commands
    currentCommands = { [1] = {}, [2] = {}, [3] = {} }

    for _, cmd in ipairs(lastCommands) do
        if cmd.name ~= '' and not (hiddenCMDs[cmd.name] or hiddenCMDs[cmd.action]) then
            currentCommands[ProcessCommand(cmd)][#currentCommands[ProcessCommand(cmd)] + 1] = cmd
        end
    end

    local familyData = GetSelectedProducerFamilyData()
    local grouped = {
        Factory = { Scout = {}, Skirmish = {}, Support = {}, Utility = {}, Unsorted = {} },
        Builder = { Economy = {}, Production = {}, Combat = {}, Utility = {}, Unsorted = {} },
    }
    local fallback = {}

    for i = 1, #currentCommands[3] do
        local cmd = currentCommands[3][i]
        local buildDefID = -cmd.id
        local category = GetBuildCategoryForUnitDef(buildDefID)
        local matched = false

        if familyData.Factory.hasProducer and familyData.Factory.canBuild[buildDefID] then
            local cat = grouped.Factory[category] and category or "Unsorted"
            grouped.Factory[cat][#grouped.Factory[cat] + 1] = cmd
            matched = true
        end
        if familyData.Builder.hasProducer and familyData.Builder.canBuild[buildDefID] then
            local cat = grouped.Builder[category] and category or "Unsorted"
            grouped.Builder[cat][#grouped.Builder[cat] + 1] = cmd
            matched = true
        end
        if not matched then
            fallback[#fallback + 1] = cmd
        end
    end

    processedBuild = {
        grouped = grouped,
        showFactory = familyData.Factory.hasProducer,
        showBuilder = familyData.Builder.hasProducer,
        fallback = fallback,
    }

    UpdatePanelVisibility(#currentCommands[1] + #currentCommands[2], #currentCommands[3])

    commandsDirty = false
end

--------------------------------------------------------------------------------
-- Layout handler override
--------------------------------------------------------------------------------

local function OverrideDefaultMenu()
    local function layoutHandler(xIcons, yIcons, cmdCount, commands)
        widgetHandler.commands = commands
        widgetHandler.commands.n = cmdCount
        widgetHandler:CommandsChanged()
        local customCmds = widgetHandler.customCommands
        return '', xIcons, yIcons, {}, customCmds, {}, {}, {}, {}, {}, {[1337] = 9001}
    end
    widgetHandler:ConfigLayoutHandler(layoutHandler)
    spForceLayoutUpdate()
end

--------------------------------------------------------------------------------
-- Drawing primitives
--------------------------------------------------------------------------------

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
    glBeginEnd(GL_LINE_LOOP, function()
        RoundedRectVertices(x1, y1, x2, y2, r, 6)
    end)
end

local function DrawPanel(x1, y1, x2, y2)
    DrawRoundedRect(x1, y1, x2, y2, PANEL_RADIUS, PANEL_BG)
    DrawRoundedOutline(x1, y1, x2, y2, PANEL_RADIUS, PANEL_BORDER)
end

local function DrawTextFitted(text, x, y, size, opts, maxWidth)
    if not text or text == '' then return end
    local estWidth = gl.GetTextWidth(text) * size
    local drawSize = size
    if maxWidth and estWidth > maxWidth and estWidth > 0 then
        drawSize = size * (maxWidth / estWidth)
    end
    glText(text, x, y, drawSize, opts)
end

local function GetInfoTextBaseSizes(buttonW)
    local rowH = BUILD_INFO_H * 0.5
    local widthTop = math_floor(buttonW * 0.105)
    local widthBottom = math_floor(buttonW * 0.095)
    local heightTop = math_floor(rowH * 0.68)
    local heightBottom = math_floor(rowH * 0.58)

    local topSize = math_max(8, math_min(widthTop, heightTop))
    local bottomSize = math_max(7, math_min(widthBottom, heightBottom))

    return topSize, bottomSize
end

local function DrawIcon(x1, y1, x2, y2, texture)
    glColor(1, 1, 1, 1)
    glTexture(texture)
    glTexRect(x1, y1, x2, y2)
    glTexture(false)
end

local function ApplyCommand(cmdID, button)
    local index = spGetCmdDescIndex(cmdID)
    if index then
        local alt, ctrl, meta, shift = spGetModKeyState()
        local left = button == 1
        local right = button == 3
        spSetActiveCommand(index, button, left, right, alt, ctrl, meta, shift)
        return true
    end
    return false
end

--------------------------------------------------------------------------------
-- Build content layout and draw
--------------------------------------------------------------------------------

local function BuildButtonLayout(mx, my, activeCmdID)
    currentBuildHitboxes = {}
    scrollbarInfo = nil

    local x1 = buildPanel.x1 + INNER_PAD
    local x2 = buildPanel.x2 - INNER_PAD
    local y1 = buildPanel.y1 + INNER_PAD
    local y2 = buildPanel.y2 - INNER_PAD

    local contentX1 = x1
    local contentX2 = x2 - SCROLLBAR_W - 6
    local contentW = contentX2 - contentX1
    local buttonW = math_floor((contentW - BUTTON_PAD * (BUILD_COLUMNS - 1)) / BUILD_COLUMNS)
    local buttonH = buttonW + BUILD_INFO_H

    buildViewHeight = y2 - y1

    local layoutItems = {}
    local cy = 0

    local function AddSectionHeader(text)
        layoutItems[#layoutItems + 1] = { kind = "section", text = text, x1 = contentX1, y1 = cy, x2 = contentX2, y2 = cy + SECTION_H }
        cy = cy + SECTION_H + SECTION_GAP
    end

    local function AddCategoryHeader(text)
        layoutItems[#layoutItems + 1] = { kind = "category", text = text, x1 = contentX1, y1 = cy, x2 = contentX2, y2 = cy + CATEGORY_H }
        cy = cy + CATEGORY_H + CATEGORY_GAP
    end

    local function AddGridButtons(cmds)
        for i = 1, #cmds do
            local col = (i - 1) % BUILD_COLUMNS
            local row = math_floor((i - 1) / BUILD_COLUMNS)
            local bx1 = contentX1 + col * (buttonW + BUTTON_PAD)
            local by1 = cy + row * (buttonH + BUTTON_PAD)
            local bx2 = bx1 + buttonW
            local by2 = by1 + buttonH
            layoutItems[#layoutItems + 1] = {
                kind = "buildbutton",
                cmd = cmds[i],
                x1 = bx1, y1 = by1, x2 = bx2, y2 = by2,
            }
        end
        cy = cy + math_max(1, math_ceil(#cmds / BUILD_COLUMNS)) * (buttonH + BUTTON_PAD) - BUTTON_PAD + BUILD_GRID_GAP
    end

    local function AddFamily(family)
        local grouped = processedBuild.grouped[family]
        local order = FAMILY_CATEGORY_ORDER[family]
        local any = false
        for i = 1, #order do
            if #grouped[order[i]] > 0 then any = true break end
        end
        if not any then return end
        AddSectionHeader(FAMILY_SECTION_TITLES[family])
        for i = 1, #order do
            local cat = order[i]
            if #grouped[cat] > 0 then
                AddCategoryHeader(cat)
                AddGridButtons(grouped[cat])
            end
        end
        cy = cy + SECTION_GAP
    end

    if processedBuild.showFactory then AddFamily("Factory") end
    if processedBuild.showBuilder then AddFamily("Builder") end
    if #processedBuild.fallback > 0 then
        AddSectionHeader("Build List")
        AddGridButtons(processedBuild.fallback)
    end

    buildContentHeight = math_max(cy, buildViewHeight)
    buildScrollOffset = Clamp(buildScrollOffset, 0, math_max(0, buildContentHeight - buildViewHeight))

    glScissor(contentX1, y1, contentW, buildViewHeight)
    for i = 1, #layoutItems do
        local item = layoutItems[i]
        local iy1 = y2 - (item.y1 - buildScrollOffset) - (item.y2 - item.y1)
        local iy2 = y2 - (item.y1 - buildScrollOffset)

        if iy2 >= y1 and iy1 <= y2 then
            if item.kind == "section" then
                DrawRoundedRect(item.x1, iy1, item.x2, iy2, 7, SECTION_BG)
                glColor(HEADER_TEXT)
                DrawTextFitted(item.text, item.x1 + 8, iy1 + 6, 13, "o", item.x2 - item.x1 - 16)
            elseif item.kind == "category" then
                DrawRoundedRect(item.x1, iy1, item.x2, iy2, 6, CATEGORY_BG)
                glColor(HEADER_TEXT)
                DrawTextFitted(item.text, item.x1 + 12, iy1 + 4, 11, "o", item.x2 - item.x1 - 20)
            elseif item.kind == "buildbutton" then
                local cmd = item.cmd
                local hovered = mx and my and IsInside(mx, my, item.x1, iy1, item.x2, iy2)
                local active = (activeCmdID == cmd.id)
                local disabled = cmd.disabled
                local buildDefID = -cmd.id

                local iconY1 = iy1 + BUILD_INFO_H
                local iconY2 = iy2
                local infoY1 = iy1
                local infoY2 = iy1 + BUILD_INFO_H - 2

                DrawRoundedRect(item.x1, infoY1, item.x2, iconY2, 6, {0.12, 0.12, 0.13, 0.80})
                DrawRoundedRect(item.x1 + 1, infoY1 + 1, item.x2 - 1, infoY2, 5, {0.08, 0.08, 0.09, 0.92})
                glColor(1, 1, 1, 0.08)
                glRect(item.x1 + 4, infoY2, item.x2 - 4, infoY2 + 1)
                DrawIcon(item.x1 + 1, iconY1 + 1, item.x2 - 1, iconY2 - 1, '#' .. buildDefID)

                if not disabled and hovered then
                    DrawRoundedRect(item.x1, infoY1, item.x2, iconY2, 6, HOVER_OVERLAY)
                end
                if active then
                    DrawRoundedRect(item.x1, infoY1, item.x2, iconY2, 6, ACTIVE_OVERLAY)
                    DrawRoundedOutline(item.x1, infoY1, item.x2, iconY2, 6, {1.0, 0.85, 0.2, 0.7})
                end
                if disabled then
                    DrawRoundedRect(item.x1, infoY1, item.x2, iconY2, 6, DISABLED_OVERLAY)
                end

                local overlay = ParseBuildOverlay(cmd)
                local hotkeyText, hotkeyMatch = GetHotkeyText(cmd)

                local leftTop = nil
                local rightTop = nil
                local bottomLeft = nil
                local bottomRight = nil

                if hotkeyText then
                    leftTop = hotkeyText
                end
                if overlay.tech then
                    rightTop = overlay.tech
                end

                if overlay.metal and overlay.energy then
                    bottomLeft = overlay.metal .. " / " .. overlay.energy
                elseif overlay.metal then
                    bottomLeft = overlay.metal
                elseif overlay.energy then
                    bottomLeft = overlay.energy
                end

                if overlay.supply then
                    bottomRight = overlay.supply -- Previously it was: "S:" .. overlay.supply
                end

                local panelPad = 5
                local infoW = item.x2 - item.x1
                local topSize, bottomSize = GetInfoTextBaseSizes(infoW)
                local rightTopReserve = rightTop and math_floor(topSize * 3.8) or 0
                local bottomRightReserve = bottomRight and math_floor(bottomSize * 4.8) or 0
                local topY = infoY1 + BUILD_INFO_H - topSize - 3
                local bottomY = infoY1 + 4

                if leftTop then
                    if hotkeyMatch then
                        glColor(0.2, 1.0, 0.2, 1.0)
                    else
                        glColor(1.0, 1.0, 1.0, 1.0)
                    end
                    local maxW = (item.x2 - item.x1) - panelPad * 2 - rightTopReserve
                    DrawTextFitted(leftTop, item.x1 + panelPad, topY, topSize, "o", maxW)
                end

                if rightTop then
                    glColor(TECH_TEXT_COLORS[rightTop] or {1.0, 0.75, 0.30, 1.0})
                    local rightW = math_floor(topSize * 3.2)
                    DrawTextFitted(rightTop, item.x2 - panelPad, topY, topSize, "or", rightW)
                end

                if bottomLeft then
                    local metalWidth = 0
                    local slashWidth = 0
                    if overlay.metal then
                        metalWidth = gl.GetTextWidth(overlay.metal) * bottomSize
                    end
                    if overlay.metal and overlay.energy then
                        slashWidth = gl.GetTextWidth(" / ") * bottomSize
                    end
                    glColor(METAL_TEXT_COLOR)
                    local maxW = (item.x2 - item.x1) - panelPad * 2 - bottomRightReserve
                    DrawTextFitted(overlay.metal or bottomLeft, item.x1 + panelPad, bottomY, bottomSize, "o", maxW)
                    if overlay.metal and overlay.energy then
                        local energyX = item.x1 + panelPad + metalWidth
                        glColor(1.0, 1.0, 1.0, 1.0)
                        DrawTextFitted(" / ", energyX, bottomY, bottomSize, "o", maxW)
                        glColor(ENERGY_TEXT_COLOR)
                        DrawTextFitted(overlay.energy, energyX + slashWidth, bottomY, bottomSize, "o", maxW)
                    end
                end
                if bottomRight then
                    glColor(1.0, 0.7, 0.2, 1.0)
                    local rightW = math_floor(bottomSize * 4.2)
                    DrawTextFitted(bottomRight, item.x2 - panelPad, bottomY, bottomSize, "or", rightW)
                end

                currentBuildHitboxes[#currentBuildHitboxes + 1] = {
                    type = "build",
                    cmd = cmd,
                    x1 = item.x1,
                    y1 = iy1,
                    x2 = item.x2,
                    y2 = iy2,
                    disabled = disabled,
                }
            end
        end
    end
    glScissor(false)

    if buildContentHeight > buildViewHeight then
        local sbx1 = contentX2 + 6
        local sbx2 = x2
        local sby1 = y1
        local sby2 = y2
        DrawRoundedRect(sbx1, sby1, sbx2, sby2, 5, SCROLLBAR_BG)

        local thumbH = math_max(24, buildViewHeight * (buildViewHeight / buildContentHeight))
        local trackH = buildViewHeight - thumbH
        local thumbOffset = 0
        if buildContentHeight > buildViewHeight then
            thumbOffset = trackH * (buildScrollOffset / (buildContentHeight - buildViewHeight))
        end
        local thy2 = y2 - thumbOffset
        local thy1 = thy2 - thumbH
        local thumbHover = mx and my and IsInside(mx, my, sbx1, thy1, sbx2, thy2)
        DrawRoundedRect(sbx1 + 1, thy1, sbx2 - 1, thy2, 5, thumbHover and SCROLLBAR_THUMB_HOVER or SCROLLBAR_THUMB)

        scrollbarInfo = { x1 = sbx1, y1 = sby1, x2 = sbx2, y2 = sby2, tx1 = sbx1, ty1 = thy1, tx2 = sbx2, ty2 = thy2 }
        AddInteractiveItem({ type = "scrollbar", x1 = sbx1, y1 = sby1, x2 = sbx2, y2 = sby2 })
    end

    for i = 1, #currentBuildHitboxes do
        AddInteractiveItem(currentBuildHitboxes[i])
    end
end

--------------------------------------------------------------------------------
-- Order layout and draw
--------------------------------------------------------------------------------

local function DrawStateBars(cmd, x1, y1, x2, y2)
    local stateCount = #cmd.params - 1
    local state = cmd.params[1] + 1
    if stateCount <= 0 then return end

    local pad = 6
    local h = 4
    local totalW = (x2 - x1) - pad * (stateCount + 1)
    local sx = totalW / stateCount

    local function Curve(c)
        return -0.5 * c * (c - 4)
    end

    for i = 1, stateCount do
        local bx1 = x1 + pad + (i - 1) * (sx + pad)
        local bx2 = bx1 + sx
        local by1 = y1 + 4
        local by2 = by1 + h
        local g = (i - 1) / math_max(1, (stateCount - 1))
        local color
        if i == state then
            color = {Curve(1 - g), Curve(g), 0, 1}
        else
            color = {0.9, 0.9, 0.9, 0.25}
        end
        DrawRoundedRect(bx1, by1, bx2, by2, 2, color)
    end
end

local function DrawOrderButtons(mx, my, activeCmdID)
    currentOrderHitboxes = {}

    local x1 = orderPanel.x1 + INNER_PAD
    local x2 = orderPanel.x2 - INNER_PAD
    local y1 = orderPanel.y1 + INNER_PAD
    local y2 = orderPanel.y2 - INNER_PAD

    local count = math_min(#currentCommands[1] + #currentCommands[2], ORDER_COLUMNS * ORDER_ROWS)
    if count <= 0 then return end

    local bw = math_floor((x2 - x1 - ORDER_GRID_GAP * (ORDER_COLUMNS - 1)) / ORDER_COLUMNS)
    local bh = math_floor((y2 - y1 - ORDER_GRID_GAP * (ORDER_ROWS - 1)) / ORDER_ROWS)

    local merged = {}
    for i = 1, #currentCommands[1] do merged[#merged + 1] = { cmd = currentCommands[1][i], state = true } end
    for i = 1, #currentCommands[2] do merged[#merged + 1] = { cmd = currentCommands[2][i], state = false } end

    for i = 1, math_min(#merged, ORDER_COLUMNS * ORDER_ROWS) do
        local col = (i - 1) % ORDER_COLUMNS
        local row = math_floor((i - 1) / ORDER_COLUMNS)
        local bx1 = x1 + col * (bw + ORDER_GRID_GAP)
        local by2 = y2 - row * (bh + ORDER_GRID_GAP)
        local bx2 = bx1 + bw
        local by1 = by2 - bh
        local entry = merged[i]
        local cmd = entry.cmd

        local hovered = mx and my and IsInside(mx, my, bx1, by1, bx2, by2)
        local active = activeCmdID == cmd.id
        local disabled = cmd.disabled

        DrawRoundedRect(bx1, by1, bx2, by2, 6, {0.14, 0.14, 0.15, 0.85})
        if not disabled and hovered then
            DrawRoundedRect(bx1, by1, bx2, by2, 6, HOVER_OVERLAY)
        end
        if active then
            DrawRoundedRect(bx1, by1, bx2, by2, 6, ACTIVE_OVERLAY)
            DrawRoundedOutline(bx1, by1, bx2, by2, 6, {1.0, 0.85, 0.2, 0.75})
        end
        if disabled then
            DrawRoundedRect(bx1, by1, bx2, by2, 6, DISABLED_OVERLAY)
        end

        local caption = cmd.name == "Repair" and "Build" or cmd.name
        glColor(1, 1, 1, 1)
        DrawTextFitted(caption, bx1 + 6, by1 + bh * 0.45, 11, "o", bw - 12)

        if entry.state then
            DrawStateBars(cmd, bx1, by1, bx2, by2)
        end

        currentOrderHitboxes[#currentOrderHitboxes + 1] = {
            type = entry.state and "state" or "order",
            cmd = cmd,
            x1 = bx1, y1 = by1, x2 = bx2, y2 = by2,
            disabled = disabled,
        }
    end

    for i = 1, #currentOrderHitboxes do
        AddInteractiveItem(currentOrderHitboxes[i])
    end
end

--------------------------------------------------------------------------------
-- Hover / tooltip
--------------------------------------------------------------------------------

local function UpdateHover(mx, my)
    hoveredItem = nil
    tooltipText = nil

    for i = #interactiveItems, 1, -1 do
        local item = interactiveItems[i]
        if IsInside(mx, my, item.x1, item.y1, item.x2, item.y2) then
            hoveredItem = item
            if item.cmd then
                tooltipText = string_gsub(item.cmd.tooltip or '', "Metal cost %d*\nEnergy cost %d*\n", "")
            end
            return
        end
    end
end

--------------------------------------------------------------------------------
-- Widget callins
--------------------------------------------------------------------------------

function widget:Initialize()
    UpdatePanelRects()
    OverrideDefaultMenu()
end

function widget:Shutdown()
    widgetHandler:ConfigLayoutHandler(nil)
    spForceLayoutUpdate()
end

function widget:ViewResize()
    UpdatePanelRects()
    commandsDirty = true
end

function widget:CommandsChanged()
    commandsDirty = true
end

function widget:SelectionChanged()
    commandsDirty = true
end

function widget:UnitCreated() commandsDirty = true end
function widget:UnitDestroyed() commandsDirty = true end
function widget:UnitGiven() commandsDirty = true end
function widget:UnitTaken() commandsDirty = true end

function widget:Update()
    if commandsDirty then
        showHotkeys = spGetConfigInt(SHOW_HOTKEYS_CONFIG, 1) == 1
        showCost    = spGetConfigInt(SHOW_COST_CONFIG, 1) == 1
        showTechReq = spGetConfigInt(SHOW_TECHREQ_CONFIG, 1) == 1
        ProcessAllCommands(true)
    end

    if draggingScrollbar and scrollbarInfo then
        local _, my = spGetMouseState()
        local thumbH = scrollbarInfo.ty2 - scrollbarInfo.ty1
        local trackTop = scrollbarInfo.y2
        local trackBottom = scrollbarInfo.y1
        local trackRange = (trackTop - trackBottom) - thumbH
        if trackRange > 0 then
            local desiredTop = Clamp(my + scrollbarDragOffset, trackBottom + thumbH, trackTop)
            local frac = (trackTop - desiredTop) / trackRange
            buildScrollOffset = frac * math_max(0, buildContentHeight - buildViewHeight)
        end
    end
end

function widget:DrawScreen()
    if spIsGUIHidden() then return end
    if not lastCommands then return end
    if not showBuildPanel and not showOrderPanel then return end

    interactiveItems = {}
    local mx, my = spGetMouseState()
    local _, activeCmdID = spGetActiveCommand()

    if showBuildPanel then
        DrawPanel(buildPanel.x1, buildPanel.y1, buildPanel.x2, buildPanel.y2)
        BuildButtonLayout(mx, my, activeCmdID)
    end

    if showOrderPanel then
        DrawPanel(orderPanel.x1, orderPanel.y1, orderPanel.x2, orderPanel.y2)
        DrawOrderButtons(mx, my, activeCmdID)
    end

    UpdateHover(mx, my)
end

function widget:WorldTooltip()
    return tooltipText
end

function widget:IsAbove(x, y)
    return (showBuildPanel and IsInside(x, y, buildPanel.x1, buildPanel.y1, buildPanel.x2, buildPanel.y2))
            or (showOrderPanel and IsInside(x, y, orderPanel.x1, orderPanel.y1, orderPanel.x2, orderPanel.y2))
end

function widget:MousePress(x, y, button)
    if scrollbarInfo and IsInside(x, y, scrollbarInfo.tx1, scrollbarInfo.ty1, scrollbarInfo.tx2, scrollbarInfo.ty2) then
        draggingScrollbar = true
        scrollbarDragOffset = scrollbarInfo.ty2 - y
        return true
    end

    if hoveredItem and hoveredItem.cmd and not hoveredItem.disabled then
        return ApplyCommand(hoveredItem.cmd.id, button)
    end

    return false
end

function widget:MouseRelease(x, y, button)
    draggingScrollbar = false
    return false
end

function widget:MouseWheel(up, value)
    local mx, my = spGetMouseState()
    if showBuildPanel and IsInside(mx, my, buildPanel.x1, buildPanel.y1, buildPanel.x2, buildPanel.y2) and buildContentHeight > buildViewHeight then
        local delta = up and -SCROLL_STEP or SCROLL_STEP
        buildScrollOffset = Clamp(buildScrollOffset + delta, 0, math_max(0, buildContentHeight - buildViewHeight))
        return true
    end
    return false
end
