function widget:GetInfo()
    return {
        version   = "0.3",
        name      = "chiliBuildOrderMenu",
        desc      = "Build/Order menu implemented with chili ui, with categorized build sections",
        author    = "Adrianulima + ChatGPT",
        date      = "WIP",
        license   = "GNU GPL, v2 or later",
        layer     = 1,
        enabled   = true,
        handler   = true,
    }
end

local vsx, vsy = Spring.GetViewGeometry()
local widgetScale = (0.5 + (vsx * vsy / 5700000))

--------------------------------------------------------------------------------
-- Hotkeys
VFS.Include("luaui/configs/evo_buildHotkeysConfig.lua")
local sGetKeySymbol = Spring.GetKeySymbol
local function getKeySymbol(k)
    if k >= 97 and k <= 122 then return string.char(k):upper() end
    local keySymbol = sGetKeySymbol(k)
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
            nameToKeySymbols[ud.name][i] = getKeySymbol(nameToKeyCode[trimmedName][i])
        end
    end
end

--------------------------------------------------------------------------------
-- Localize
local sForceLayoutUpdate    = Spring.ForceLayoutUpdate
local sSetActiveCommand     = Spring.SetActiveCommand
local sGetCmdDescIndex      = Spring.GetCmdDescIndex
local sGetActiveCommand     = Spring.GetActiveCommand
local sGetWindowGeometry    = Spring.GetWindowGeometry
local sGetConfigInt         = Spring.GetConfigInt
local sGetSelectedUnits     = Spring.GetSelectedUnits
local sGetUnitDefID         = Spring.GetUnitDefID

local stringfind = string.find
local stringsub  = string.sub
local stringgsub = string.gsub
local mathceil   = math.ceil
local mathmax    = math.max
local mathmin    = math.min
local mathfloor  = math.floor

local glGetTextWidth = gl.GetTextWidth

-- Chili classes
local Chili, Window, Image, Button, Grid, Label, ScrollPanel, Control, color2incolor

-- Global vars
local orderWindow, buildWindow, orderGrid
local buildScroll, buildContainer
local updateRequired, tooltip, btWidth

local chiliCache = {}
local buildButtons = {}
local orderButtons = {}
local hotkeyLabels = {}

local vsx, vsy = sGetWindowGeometry()

local buildOrderUI = sGetConfigInt("evo_buildorderui", 1)
local showCost = sGetConfigInt("evo_showcost", 1) == 1
local showTechReq = sGetConfigInt("evo_showtechreq", 1) == 1
local showHotkeys = sGetConfigInt("evo_showhotkeys", 1) == 1
WG.buildOrderUI = { updateConfigInt = false }

local function GetScaledFontSize()
    return 14 * widgetScale
end

local traditionalCompact = 2
local traditionalSmall = 1
local traditionalLarge = 0

if buildOrderUI == traditionalSmall then
    Config = {
        ordermenu = {
            name = 'ordermenu',
            rows = 5, columns = 5,
            x = '0%', y = '24%',
            width = '100%', height = '25%',
            orientation = 'horizontal',
            maxWidth = 500,
            padding = {0, 0, 0, 0},
        },
        buildmenu = {
            name = 'buildmenu',
            rows = 4, columns = 5,
            x = '0%', y = '50%',
            width = '50%', height = '50%',
            orientation = 'horizontal',
            maxWidth = 500,
            padding = {6, 6, 6, 6},
        },
        labels = {
            captionFontMaxSize = GetScaledFontSize(),
            queueFontSize      = GetScaledFontSize(),
            costFontSize       = GetScaledFontSize(),
            sectionFontSize    = GetScaledFontSize() + 3,
            categoryFontSize   = GetScaledFontSize() - 1,
        },
        hiddenCMDs = {
            timewait = true, deathwait = true, squadwait = true, gatherwait = true,
            loadonto = true, selfd = false, settargetnoground = true,
        },
    }

elseif buildOrderUI == traditionalCompact then
    Config = {
        ordermenu = {
            name = 'ordermenu',
            rows = 5, columns = 5,
            x = '0%', y = '24%',
            width = '100%', height = '25%',
            orientation = 'horizontal',
            maxWidth = 500,
            padding = {5, 5, 5, 5},
        },
        buildmenu = {
            name = 'buildmenu',
            rows = 4, columns = 6,
            x = '0%', y = '50%',
            width = '50%', height = '50%',
            orientation = 'horizontal',
            maxWidth = 500,
            padding = {6, 6, 6, 6},
        },
        labels = {
            captionFontMaxSize = GetScaledFontSize(),
            queueFontSize      = GetScaledFontSize(),
            costFontSize       = GetScaledFontSize(),
            sectionFontSize    = GetScaledFontSize() + 3,
            categoryFontSize   = GetScaledFontSize() - 1,
        },
        hiddenCMDs = {
            timewait = true, deathwait = true, squadwait = true, gatherwait = true,
            loadonto = true, selfd = false, settargetnoground = true,
        },
    }
else
    buildOrderUI = traditionalLarge
    Config = {
        ordermenu = {
            name = 'ordermenu',
            rows = 5, columns = 5,
            x = '0%', y = '24%',
            width = '100%', height = '25%',
            orientation = 'horizontal',
            maxWidth = 600,
            padding = {5, 5, 5, 5},
        },
        buildmenu = {
            name = 'buildmenu',
            rows = 4, columns = 5,
            x = '0%', y = '49.25%',
            width = '50%', height = '50%',
            orientation = 'horizontal',
            maxWidth = 600,
            padding = {6, 6, 6, 6},
        },
        labels = {
            captionFontMaxSize = GetScaledFontSize(),
            queueFontSize      = GetScaledFontSize(),
            costFontSize       = GetScaledFontSize(),
            sectionFontSize    = GetScaledFontSize() + 3,
            categoryFontSize   = GetScaledFontSize() - 1,
        },
        hiddenCMDs = {
            timewait = true, deathwait = true, squadwait = true, gatherwait = true,
            loadonto = true, selfd = false, settargetnoground = true,
        },
    }
end

--------------------------------------------------------------------------------
-- Category config

local FAMILY_CATEGORY_ORDER = {
    Factory = { "Scout", "Skirmish", "Support", "Utility", "Unsorted" },
    Builder = { "Economy", "Production", "Combat", "Utility", "Unsorted" },
}

local FAMILY_SECTION_TITLES = {
    Factory = "Factory Units",
    Builder = "Structures",
}

local HEADER_STYLE = {
    section = {
        height = 28,
        bgColor = {0.08, 0.08, 0.08, 0.75},
        lineColor = {1, 1, 1, 0.10},
        textX = 10,
    },
    category = {
        height = 22,
        bgColor = {1, 1, 1, 0.05},
        lineColor = {1, 1, 1, 0.08},
        textX = 16,
    },
}

local function NormalizeProducerRole(unitRole)
    if unitRole == "Commander" or unitRole == "Builder" then
        return "Builder"
    elseif unitRole == "Factory" then
        return "Factory"
    end
    return nil
end

--------------------------------------------------------------------------------
-- Helpers

local function deepEquals(t1, t2, ignore_mt)
    if t1 == t2 then return true end
    local ty1 = type(t1)
    local ty2 = type(t2)
    if ty1 ~= ty2 then return false end
    if ty1 ~= 'table' and ty2 ~= 'table' then return t1 == t2 end
    local mt = getmetatable(t1)
    if not ignore_mt and mt and mt.__eq then return t1 == t2 end
    for k1, v1 in pairs(t1) do
        local v2 = t2[k1]
        if v2 == nil or not deepEquals(v1, v2) then return false end
    end
    for k2, v2 in pairs(t2) do
        local v1 = t1[k2]
        if v1 == nil or not deepEquals(v1, v2) then return false end
    end
    return true
end

local function processRelativeCoord(code, total)
    local num = tonumber(code)
    if (type(code) == "string") then
        local percent = tonumber(code:sub(1, -2)) or 0
        if percent < 0 then
            percent = 0
        elseif percent > 100 then
            percent = 100
        end
        return mathfloor(total * percent / 100)
    elseif (num) and ((1 / num) < 0) then
        return mathfloor(total + num)
    else
        return mathfloor(num or 0)
    end
end

local function createGridWindow(config)
    local scroll = ScrollPanel:New{
        name = 'scroll_' .. config.name,
        x = '0%', y = '0%',
        width = '100%', height = '100%',
        padding = config.padding,
    }

    local grid = Grid:New{
        name = 'grid_' .. config.name,
        x = '0%', y = '0%',
        width = '100%', height = '100%',
        rows = config.rows,
        columns = config.columns,
        orientation = config.orientation,
        padding = {0, 0, 0, 0},
    }

    local gridWindow = Window:New{
        name = 'window_' .. config.name,
        parent = Chili.Screen0,
        x = config.x, y = config.y,
        height = config.height, width = config.width,
        maxWidth = config.maxWidth,
        children = {grid},
        bringToFrontOnClick = true, dockable = false, draggable = false,
        resizable = false, tweakDraggable = true, tweakResizable = false,
        padding = config.padding,
    }

    local function updateGrid()
        local rowsNeeded = mathceil(#grid.children / grid.columns)
        if rowsNeeded > grid.rows then
            local ratio = (gridWindow.height / config.rows) / (gridWindow.width / config.columns)
            grid:SetPos(nil, nil, nil, (grid.width / grid.columns) * ratio * rowsNeeded)
            grid.rows = rowsNeeded
            if grid.parent and grid.parent.name == gridWindow.name then
                gridWindow:RemoveChild(grid)
                gridWindow:AddChild(scroll)
                scroll:AddChild(grid)
            end
        elseif rowsNeeded <= config.rows then
            grid:SetPos(nil, nil, nil, gridWindow.height - gridWindow.padding[2] - gridWindow.padding[4])
            grid.rows = config.rows
            if scroll.parent and scroll.parent.name == gridWindow.name then
                scroll:RemoveChild(grid)
                gridWindow:RemoveChild(scroll)
                gridWindow:AddChild(grid)
            end
        end
    end

    grid.updateGrid = updateGrid
    gridWindow:Hide()
    return grid, gridWindow
end

local function createBuildWindow(config)
    buildContainer = Control:New{
        name = 'build_container',
        x = 0, y = 0,
        width = '100%',
        height = 1,
        padding = {0, 0, 0, 0},
    }

    buildScroll = ScrollPanel:New{
        name = 'scroll_' .. config.name,
        x = '0%', y = '0%',
        width = '100%', height = '100%',
        padding = config.padding,
        children = { buildContainer },
    }

    local window = Window:New{
        name = 'window_' .. config.name,
        parent = Chili.Screen0,
        x = config.x, y = config.y,
        height = config.height, width = config.width,
        maxWidth = config.maxWidth,
        children = { buildScroll },
        bringToFrontOnClick = true, dockable = false, draggable = false,
        resizable = false, tweakDraggable = true, tweakResizable = false,
        padding = config.padding,
    }

    window:Hide()
    return window
end

local function applyHighlightHandler(button, cmd)
    local selected = {0.85, 0.65, 0, 0.5}
    local hovered  = {0.75, 0.75, 0.75, 0.25}
    local out      = {0, 0, 0, 0}
    local disabled = {0, 0, 0, 0.6}

    local highlight = chiliCache['highlight' .. button.cmdID] or Image:New{
        name   = 'highlight' .. button.cmdID,
        parent = button,
        file   = 'LuaUI/Images/button-highlight.dds',
        width  = '100%', height = '100%',
        fixedRatio = false, keepAspect = false,
        color = out,
    }
    chiliCache['highlight' .. button.cmdID] = highlight

    local function updateSelection(cmdID)
        local function checkColor(color)
            if highlight.color ~= color then
                highlight.color = color
                highlight:Invalidate()
            end
        end

        if cmd.disabled then
            checkColor(disabled)
            if button.state.hovered then
                tooltip = stringgsub(cmd.tooltip, "Metal cost %d*\nEnergy cost %d*\n", "")
            end
        elseif button.cmdID == cmdID then
            checkColor(selected)
        elseif button.state.hovered then
            tooltip = stringgsub(cmd.tooltip, "Metal cost %d*\nEnergy cost %d*\n", "")
            checkColor(hovered)
        else
            checkColor(out)
        end
    end

    button.updateSelection = updateSelection
    updateSelection()
    return button
end

local function applyStateHandler(button, cmd)
    local stateCount = #cmd.params - 1
    local state = cmd.params[1] + 1

    local function curve(c) return -0.5 * c * (c - 4) end
    local function getStateColor(i)
        local g = (i - 1) / (stateCount - 1)
        return (i == state) and {curve(1 - g), curve(g), 0, 1} or {0.9, 0.9, 0.9, 0.3}
    end

    local stateButtons = {}
    for i = 1, stateCount do
        local pad = 7
        local sx = (100 - pad * (stateCount + 3)) / stateCount
        local px = pad + i * pad + (i - 1) * sx
        stateButtons[i] = chiliCache['stateButton_' .. cmd.id .. '_' .. i] or Image:New{
            name = 'stateButton_' .. cmd.id .. '_' .. i,
            parent = button,
            file   = 'LuaUI/Images/button-highlight.dds',
            x = px .. '%', y = '75%',
            width = sx .. '%', maxHeight = 6,
            keepAspect = false,
            color = getStateColor(i),
        }
        chiliCache['stateButton_' .. cmd.id .. '_' .. i] = stateButtons[i]
    end

    local oldUpdateSelection = button.updateSelection
    local function updateSelection(cmdID)
        oldUpdateSelection(cmdID)
        for i = 1, stateCount do
            stateButtons[i].color = getStateColor(i)
        end
    end
    button.updateSelection = updateSelection
    return button
end

--------------------------------------------------------------------------------

local function InitializeControls()
    orderGrid, orderWindow = createGridWindow(Config.ordermenu)
    buildWindow = createBuildWindow(Config.buildmenu)
end

local function ActionCommand(self, x, y, mouse, mods)
    local index = sGetCmdDescIndex(self.cmdID)
    if index then
        local left, right = mouse == 1, mouse == 3
        local alt, ctrl, meta, shift = mods.alt, mods.ctrl, mods.meta, mods.shift
        sSetActiveCommand(index, mouse, left, right, alt, ctrl, meta, shift)
    end
end

local function addOrderCommand(cmd)
    local button = chiliCache['button' .. cmd.id] or Button:New{
        name = 'button' .. cmd.id,
        cmdID = cmd.id,
        caption = cmd.name,
        textPadding = 9,
        padding = {0, 0, 0, 0},
        margin = {2, 2, 2, 2},
        OnClick = {function() end},
        OnMouseDown = {ActionCommand}
    }

    if cmd.name == "Repair" then
        button:SetCaption("Build")
    else
        button:SetCaption(cmd.name)
    end

    chiliCache['button' .. cmd.id] = button
    local s = (btWidth - button.textPadding * 2) / glGetTextWidth(button.caption)
    button.font:SetSize(mathmin(s, Config.labels.captionFontMaxSize))
    applyHighlightHandler(button, cmd)
    orderGrid:AddChild(button)
    orderButtons[#orderButtons + 1] = button
end

local function addStateCommand(cmd)
    local button = chiliCache['button' .. cmd.id] or Button:New{
        name = 'button' .. cmd.id,
        cmdID = cmd.id,
        caption = cmd.params[cmd.params[1] + 2],
        textPadding = 12,
        padding = {0, 0, 0, 0},
        margin = {2, 2, 2, 2},
        OnClick = {function() end},
        OnMouseDown = {ActionCommand}
    }

    button:SetCaption(cmd.params[cmd.params[1] + 2])
    chiliCache['button' .. cmd.id] = button
    local s = (btWidth - button.textPadding * 2) / glGetTextWidth(button.caption)
    button.font:SetSize(mathmin(s, Config.labels.captionFontMaxSize))
    applyHighlightHandler(button, cmd)
    applyStateHandler(button, cmd)
    orderGrid:AddChild(button)
    orderButtons[#orderButtons + 1] = button
end

local function addBuildCommand(cmd, parentGrid)
    local image = chiliCache['button' .. cmd.id] or Image:New{
        name = 'button' .. cmd.id,
        cmdID = cmd.id,
        width = '100%', height = '100%',
        file = '#' .. cmd.id * -1,
        padding = {0, 0, 0, 0},
        margin = {2, 2, 2, 2},
        OnClick = {function() end},
        OnMouseDown = {ActionCommand}
    }
    chiliCache['button' .. cmd.id] = image

    if cmd.params[1] then
        if not chiliCache['queueLabel' .. cmd.id] then
            chiliCache['queueLabel' .. cmd.id] = Label:New{
                name = 'queueLabel' .. cmd.id,
                parent = image,
                right = '5%', y = '5%',
                align = 'right',
                valign = 'top',
                font = {
                    size = Config.labels.queueFontSize,
                    outline = true, shadow = true,
                    outlineWidth = 4, outlineWeight = 4,
                },
            }
        end
    end
    if chiliCache['queueLabel' .. cmd.id] then
        chiliCache['queueLabel' .. cmd.id]:SetCaption(tostring(cmd.params[1] or ''))
    end

    local str = ''
    if showCost then
        local s, e = 0, 0
        local separator = color2incolor(1,1,1) .. '\n'
        s, e = stringfind(cmd.tooltip, 'Uses %+%d* Supply')
        if s then
            str = str .. color2incolor(1,0.5,0) .. stringsub(cmd.tooltip, s + 6, e - 7) .. " " .. separator
        end
        s, e = stringfind(cmd.tooltip, 'Metal cost %d*')
        if s and e then
            str = str .. color2incolor(0.53,0.77,0.89) .. stringsub(cmd.tooltip, s + 11, e) .. " " .. separator
        end
        s, e = stringfind(cmd.tooltip, 'Energy cost %d*')
        if s and e then
            str = str .. color2incolor(1,1,0) .. stringsub(cmd.tooltip, s + 12, e) .. " " .. separator
        end
    end

    local techReqColors = {
        color2incolor(0,0.8,1),
        color2incolor(1,0.5,0),
        color2incolor(1,0,1),
        color2incolor(0,1,0),
        color2incolor(1,0,0)
    }

    if showTechReq then
        if stringfind(cmd.tooltip, 'Requires') or stringfind(cmd.tooltip, 'Provides') then
            local s, e = stringfind(cmd.tooltip, 'tech%d*')
            if s and e then
                local techLevel = stringsub(cmd.tooltip, s + 4, e)
                str = techReqColors[tonumber(techLevel) + 1] .. "T" .. techLevel .. '\n' .. str
            end
        end
    end

    if str ~= '' then
        if not chiliCache['costLabel' .. cmd.id] then
            chiliCache['costLabel' .. cmd.id] = Label:New{
                name = 'costLabel' .. cmd.id,
                parent = image,
                x = '5%', bottom = '5%',
                valign = 'bottom',
                font = {
                    size = Config.labels.costFontSize,
                    outline = true, shadow = true,
                    outlineWidth = 4, outlineWeight = 4,
                },
            }
        end
        chiliCache['costLabel' .. cmd.id]:SetCaption(str:sub(1, -2))
    elseif chiliCache['costLabel' .. cmd.id] then
        chiliCache['costLabel' .. cmd.id]:SetCaption(str)
    end

    if showHotkeys and widgetHandler.orderList["SplinterFaction Build Hotkeys"] and widgetHandler.orderList["SplinterFaction Build Hotkeys"] ~= 0 then
        if nameToKeySymbols[cmd.name] then
            if not chiliCache['hotkeyLabel' .. cmd.id] then
                chiliCache['hotkeyLabel' .. cmd.id] = Label:New{
                    name = 'hotkeyLabel' .. cmd.id,
                    parent = image,
                    x = '5%', y = '5%',
                    valign = 'top',
                    font = {
                        size = Config.labels.costFontSize,
                        outline = true, shadow = true,
                        outlineWidth = 4, outlineWeight = 4,
                    },
                }
            end

            local function updateLabel()
                local str = color2incolor(1,1,1)
                local leng = #nameToKeySymbols[cmd.name]
                local getLengKeysPressed = WG.buildHotkeys and #WG.buildHotkeys.keysPressed or 0
                local matching = true
                for i = 1, leng do
                    if i <= getLengKeysPressed and matching then
                        if nameToKeySymbols[cmd.name][i] == WG.buildHotkeys.keysPressed[i] then
                            str = str .. color2incolor(0,1,0)
                        else
                            matching = false
                        end
                    end
                    str = str .. nameToKeySymbols[cmd.name][i]
                    if i < leng then
                        str = str .. color2incolor(1,1,1) .. ' + '
                    end
                end
                chiliCache['hotkeyLabel' .. cmd.id]:SetCaption(str)
            end

            chiliCache['hotkeyLabel' .. cmd.id].updateLabel = updateLabel
            updateLabel()
            hotkeyLabels[cmd.id] = chiliCache['hotkeyLabel' .. cmd.id]
        end
    elseif chiliCache['hotkeyLabel' .. cmd.id] then
        chiliCache['hotkeyLabel' .. cmd.id].updateLabel = nil
        chiliCache['hotkeyLabel' .. cmd.id]:SetCaption('')
    end

    applyHighlightHandler(image, cmd)
    parentGrid:AddChild(image)
    buildButtons[#buildButtons + 1] = image
end

local function processCommand(cmd)
    if UnitDefNames[cmd.name] then
        return 3
    elseif #cmd.params > 1 then
        return 1
    else
        return 2
    end
end

--------------------------------------------------------------------------------
-- Categorized build rendering

local function GetSelectedProducerFamilyData()
    local selectedUnits = sGetSelectedUnits()
    local familyData = {
        Builder = { canBuild = {}, hasProducer = false },
        Factory = { canBuild = {}, hasProducer = false },
    }

    for i = 1, #selectedUnits do
        local unitID = selectedUnits[i]
        local unitDefID = sGetUnitDefID(unitID)
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

local function GetBuildWindowInnerWidth()
    local rawWidth = buildWindow.width or processRelativeCoord(Config.buildmenu.width, vsx)
    local pad = Config.buildmenu.padding or {0, 0, 0, 0}
    local innerWidth = rawWidth - (pad[1] or 0) - (pad[3] or 0) - 8
    return mathmax(innerWidth, 100)
end

local function MakeHeaderBar(parent, y, height, bgColor, lineColor)
    local bar = Control:New{
        parent = parent,
        x = 0,
        y = y,
        width = '100%',
        height = height,
        padding = {0, 0, 0, 0},
        backgroundColor = bgColor,
    }

    Image:New{
        parent = bar,
        x = 0,
        bottom = 0,
        width = '100%',
        height = 1,
        file = 'LuaUI/Images/button-highlight.dds',
        color = lineColor,
        keepAspect = false,
        fixedRatio = false,
    }

    return bar
end

local function MakeSectionHeader(text, parent, y)
    local bar = MakeHeaderBar(
        parent,
        y,
        HEADER_STYLE.section.height,
        HEADER_STYLE.section.bgColor,
        HEADER_STYLE.section.lineColor
    )

    Label:New{
        parent = bar,
        x = HEADER_STYLE.section.textX,
        y = 0,
        width = '100%',
        height = '100%',
        caption = text,
        valign = 'center',
        font = {
            size = Config.labels.sectionFontSize,
            outline = true,
            shadow = true,
            outlineWidth = 2,
            outlineWeight = 2,
        },
    }

    return HEADER_STYLE.section.height
end

local function MakeCategoryHeader(text, parent, y)
    local bar = MakeHeaderBar(
        parent,
        y,
        HEADER_STYLE.category.height,
        HEADER_STYLE.category.bgColor,
        HEADER_STYLE.category.lineColor
    )

    Label:New{
        parent = bar,
        x = HEADER_STYLE.category.textX,
        y = 0,
        width = '100%',
        height = '100%',
        caption = text,
        valign = 'center',
        font = {
            size = Config.labels.categoryFontSize,
            outline = true,
            shadow = true,
            outlineWidth = 2,
            outlineWeight = 2,
        },
    }

    return HEADER_STYLE.category.height
end

local function RenderFamilySection(parent, family, familyCommands, yOffset)
    local categories = FAMILY_CATEGORY_ORDER[family]
    if not categories then
        return yOffset
    end

    local anyCommands = false
    for _, categoryName in ipairs(categories) do
        if familyCommands[categoryName] and #familyCommands[categoryName] > 0 then
            anyCommands = true
            break
        end
    end
    if not anyCommands then
        return yOffset
    end

    local y = yOffset
    local innerWidth = GetBuildWindowInnerWidth()
    local columns = Config.buildmenu.columns
    local cellSize = mathfloor(innerWidth / columns)

    y = y + MakeSectionHeader(FAMILY_SECTION_TITLES[family], parent, y) + 4

    for _, categoryName in ipairs(categories) do
        local cmds = familyCommands[categoryName]
        if cmds and #cmds > 0 then
            y = y + MakeCategoryHeader(categoryName, parent, y) + 6

            local rows = mathmax(1, mathceil(#cmds / columns))
            local gridHeight = rows * cellSize

            local grid = Grid:New{
                parent = parent,
                x = 0, y = y,
                width = '100%',
                height = gridHeight,
                rows = rows,
                columns = columns,
                orientation = 'horizontal',
                padding = {0, 0, 0, 0},
            }

            for i = 1, #cmds do
                addBuildCommand(cmds[i], grid)
            end

            y = y + gridHeight + 10
        end
    end

    return y + 8
end

local function RenderCategorizedBuildCommands(buildCommands)
    buildContainer:ClearChildren()
    buildButtons = {}
    hotkeyLabels = {}

    local familyData = GetSelectedProducerFamilyData()

    local grouped = {
        Factory = {
            Scout = {}, Skirmish = {}, Support = {}, Utility = {}, Unsorted = {}
        },
        Builder = {
            Economy = {}, Production = {}, Combat = {}, Utility = {}, Unsorted = {}
        },
    }

    local fallbackFlat = false

    for i = 1, #buildCommands do
        local cmd = buildCommands[i]
        local buildDefID = -cmd.id
        local category = GetBuildCategoryForUnitDef(buildDefID)

        local addedToAny = false

        if familyData.Factory.hasProducer and familyData.Factory.canBuild[buildDefID] then
            local cat = grouped.Factory[category] and category or "Unsorted"
            grouped.Factory[cat][#grouped.Factory[cat] + 1] = cmd
            addedToAny = true
        end

        if familyData.Builder.hasProducer and familyData.Builder.canBuild[buildDefID] then
            local cat = grouped.Builder[category] and category or "Unsorted"
            grouped.Builder[cat][#grouped.Builder[cat] + 1] = cmd
            addedToAny = true
        end

        if not addedToAny then
            fallbackFlat = true
        end
    end

    local y = 4

    if familyData.Factory.hasProducer then
        y = RenderFamilySection(buildContainer, "Factory", grouped.Factory, y)
    end

    if familyData.Builder.hasProducer then
        y = RenderFamilySection(buildContainer, "Builder", grouped.Builder, y)
    end

    if fallbackFlat then
        local rows = mathmax(1, mathceil(#buildCommands / Config.buildmenu.columns))
        local innerWidth = GetBuildWindowInnerWidth()
        local cellSize = mathfloor(innerWidth / Config.buildmenu.columns)
        local gridHeight = rows * cellSize

        y = y + MakeSectionHeader("Build List", buildContainer, y) + 4

        local grid = Grid:New{
            parent = buildContainer,
            x = 0, y = y,
            width = '100%',
            height = gridHeight,
            rows = rows,
            columns = Config.buildmenu.columns,
            orientation = 'horizontal',
            padding = {0, 0, 0, 0},
        }
        for i = 1, #buildCommands do
            addBuildCommand(buildCommands[i], grid)
        end
        y = y + gridHeight + 8
    end

    buildContainer:SetPos(nil, nil, nil, y + 4)
    buildContainer:Invalidate()
end

--------------------------------------------------------------------------------

local lastCommands
local function processAllCommands(flush)
    if deepEquals(lastCommands, widgetHandler.commands) and not flush then
        return
    end
    lastCommands = widgetHandler.commands

    orderGrid:ClearChildren()
    if buildContainer then
        buildContainer:ClearChildren()
    end

    orderButtons = {}
    buildButtons = {}
    hotkeyLabels = {}

    local haveCmd = 0
    local commands = { [1] = {}, [2] = {}, [3] = {} }

    for _, cmd in ipairs(lastCommands) do
        if cmd.name ~= '' and not (Config.hiddenCMDs[cmd.name] or Config.hiddenCMDs[cmd.action]) then
            local grid = processCommand(cmd)
            haveCmd = mathmax(haveCmd, grid)
            commands[grid][#commands[grid] + 1] = cmd
        end
    end

    for i = 1, #commands[1] do addStateCommand(commands[1][i]) end
    for i = 1, #commands[2] do addOrderCommand(commands[2][i]) end

    if #commands[3] > 0 then
        RenderCategorizedBuildCommands(commands[3])
    end

    orderGrid.updateGrid()

    if haveCmd > 0 and orderWindow.hidden then
        orderWindow:Show()
    elseif haveCmd == 0 and orderWindow.visible then
        orderWindow:Hide()
    end

    if #commands[3] > 0 and buildWindow.hidden then
        buildWindow:Show()
    elseif #commands[3] == 0 and buildWindow.visible then
        buildWindow:Hide()
    end
end

local function updateSelection()
    tooltip = nil
    local _, cmdID = sGetActiveCommand()

    for i = 1, #buildButtons do
        local bt = buildButtons[i]
        if bt and bt.updateSelection then
            bt.updateSelection(cmdID)
        end
    end

    for i = 1, #orderButtons do
        local bt = orderButtons[i]
        if bt and bt.updateSelection then
            bt.updateSelection(cmdID)
        end
    end
end

local function updateLabel()
    for _, label in pairs(hotkeyLabels) do
        if label.updateLabel then
            label.updateLabel()
        end
    end
end

local function OverrideDefaultMenu()
    local function layoutHandler(xIcons, yIcons, cmdCount, commands)
        widgetHandler.commands = commands
        widgetHandler.commands.n = cmdCount
        widgetHandler:CommandsChanged()
        local customCmds = widgetHandler.customCommands
        return '', xIcons, yIcons, {}, customCmds, {}, {}, {}, {}, {}, {[1337] = 9001}
    end
    widgetHandler:ConfigLayoutHandler(layoutHandler)
    sForceLayoutUpdate()
end

--------------------------------------------------------------------------------

function widget:Initialize()
    if not WG.Chili then
        widgetHandler:RemoveWidget()
        return
    end

    OverrideDefaultMenu()

    Chili         = WG.Chili
    Window        = Chili.Window
    Grid          = Chili.Grid
    Image         = Chili.Image
    Button        = Chili.Button
    Label         = Chili.Label
    ScrollPanel   = Chili.ScrollPanel
    Control       = Chili.Control
    color2incolor = Chili.color2incolor

    btWidth = processRelativeCoord(Config.ordermenu.width, vsx / Config.ordermenu.columns)

    InitializeControls()
end

function widget:CommandsChanged()
    updateRequired = true
end

function widget:SelectionChanged()
    updateRequired = true
end

function widget:UnitCreated()
    updateRequired = true
end

function widget:UnitDestroyed()
    updateRequired = true
end

function widget:UnitGiven()
    updateRequired = true
end

function widget:UnitTaken()
    updateRequired = true
end

function widget:Update()
    if WG['topbar'] and WG['topbar'].showingQuit() then
        return
    end

    if updateRequired then
        processAllCommands()
        updateRequired = false
    end

    updateSelection()

    if WG.buildHotkeys and WG.buildHotkeys.hasUpdated then
        updateLabel()
        WG.buildHotkeys.hasUpdated = false
    end

    if WG.buildOrderUI and WG.buildOrderUI.updateConfigInt then
        WG.buildOrderUI.updateConfigInt = false
        showCost = sGetConfigInt("evo_showcost", 1) == 1
        showTechReq = sGetConfigInt("evo_showtechreq", 1) == 1
        showHotkeys = sGetConfigInt("evo_showhotkeys", 1) == 1
        processAllCommands(true)
    end
end

function widget:WorldTooltip(ttType, data1, data2, data3)
    return tooltip
end

function widget:ViewResize(newX, newY)
    vsx, vsy = Spring.GetViewGeometry()
    widgetScale = (0.5 + (vsx * vsy / 5700000))

    Config.labels = {
        captionFontMaxSize = GetScaledFontSize(),
        queueFontSize      = GetScaledFontSize(),
        costFontSize       = GetScaledFontSize(),
        sectionFontSize    = GetScaledFontSize() + 3,
        categoryFontSize   = GetScaledFontSize() - 1,
    }

    processAllCommands(true)
end

function widget:Shutdown()
    if orderWindow then orderWindow:Dispose() end
    if buildWindow then buildWindow:Dispose() end
    widgetHandler:ConfigLayoutHandler(nil)
    chiliCache = nil
    sForceLayoutUpdate()
end
