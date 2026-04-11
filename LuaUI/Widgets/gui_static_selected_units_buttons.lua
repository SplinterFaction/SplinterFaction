--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    gui_selbuttons.lua
--  brief:   adds a selected units button control panel
--  author:  Dave Rodgers
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "Static Selected Units Buttons",
    desc      = "Buttons for the current selection",
    author    = "trepan, Floris",
    date      = "28 may 2015",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Automatically generated local definitions

local fontfile = LUAUI_DIRNAME .. "fonts/" .. Spring.GetConfigString("ui_font", "Saira_SemiCondensed-SemiBold.ttf")
local vsx, vsy = Spring.GetViewGeometry()
local fontfileScale = (0.5 + (vsx*vsy / 5700000))
local fontfileSize = 25
local fontfileOutlineSize = 6
local fontfileOutlineStrength = 1.4
local font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)


--------------------------------------------------------------------------------
-- Style constants (matched to gui_static_tooltip_panel.lua / gui_static_buildordermenu.lua)
--------------------------------------------------------------------------------

local PANEL_RADIUS        = 10
local PANEL_OUTER_COLOR   = {0, 0, 0, 0.85}
local PANEL_INNER_COLOR   = {0.15, 0.15, 0.15, 0.85}
local PANEL_ACCENT_COLOR  = {0.00, 0.50, 1.00, 0.60}
local PANEL_ACCENT_HEIGHT = 5

-- Tier colours - identical to TECH_TEXT_COLORS in gui_static_tooltip_panel.lua,
-- pre-multiplied to 0.60 alpha for use as an accent bar.
local TECH_ACCENT_COLORS = {
  T0 = {0.0, 0.8, 0.8, 0.70},
  T1 = {1.0, 0.5, 0.0, 0.70},
  T2 = {1.0, 0.0, 1.0, 0.70},
  T3 = {0.0, 1.0, 0.0, 0.70},
  T4 = {1.0, 0.0, 0.0, 0.70},
}

local TECH_REQUIREMENT_MAP = {
  tech0 = "T0", tech1 = "T1", tech2 = "T2", tech3 = "T3", tech4 = "T4",
}

local string_lower = string.lower

-- Per-cell separator / hover tint colours
local CELL_BG_COLOR       = {0.14, 0.14, 0.15, 0.90}
local CELL_BORDER_COLOR   = {1.0, 1.0, 1.0, 0.06}

local leftmouseColor   = {1, 0.72, 0.25, 0.22}
local middlemouseColor = {1, 1,    1,    0.16}
local rightmouseColor  = {1, 0.4,  0.4,  0.20}

--------------------------------------------------------------------------------
-- GL / Spring locals
--------------------------------------------------------------------------------

local GL_ONE                 = GL.ONE
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_SRC_ALPHA           = GL.SRC_ALPHA
local GL_QUADS               = GL.QUADS
local GL_TRIANGLE_FAN        = GL.TRIANGLE_FAN
local GL_LINE_LOOP           = GL.LINE_LOOP

local glBlending             = gl.Blending
local glBeginEnd             = gl.BeginEnd
local glColor                = gl.Color
local glRect                 = gl.Rect
local glTexRect              = gl.TexRect
local glText                 = gl.Text
local glTexture              = gl.Texture
local glTexCoord             = gl.TexCoord
local glVertex               = gl.Vertex
local glLineWidth            = gl.LineWidth

local spGetModKeyState       = Spring.GetModKeyState
local spGetMouseState        = Spring.GetMouseState
local spGetMyTeamID          = Spring.GetMyTeamID
local spGetSelectedUnits     = Spring.GetSelectedUnits
local spGetSelectedUnitsCount  = Spring.GetSelectedUnitsCount
local spGetSelectedUnitsCounts = Spring.GetSelectedUnitsCounts
local spGetSelectedUnitsSorted = Spring.GetSelectedUnitsSorted
local spGetTeamUnitsSorted   = Spring.GetTeamUnitsSorted
local spSelectUnitArray      = Spring.SelectUnitArray
local spSelectUnitMap        = Spring.SelectUnitMap
local spSendCommands         = Spring.SendCommands
local spIsGUIHidden          = Spring.IsGUIHidden

local math_floor = math.floor
local math_ceil  = math.ceil
local math_min   = math.min
local math_max   = math.max
local math_cos   = math.cos
local math_sin   = math.sin
local math_pi    = math.pi

-------------------------------------------------------------------------------
-- Config / sizing
-------------------------------------------------------------------------------

local ui_opacityMultiplier = 0.6
local ui_opacity = tonumber(Spring.GetConfigFloat("ui_opacity", 0.66) or 0.66) * ui_opacityMultiplier

local bgcorner     = ":n:LuaUI/Images/bgcorner.png"
local highlightImg  = ":n:LuaUI/Images/button-highlight.dds"
local accentImg     = ":n:LuaUI/Images/staticgui_accent.png"

local iconsPerRow = 16

local unitTypes    = 0
local countsTable  = {}
local activePress  = false
local mouseIcon    = -1
local currentDef   = nil
local prevUnitCount = spGetSelectedUnitsCounts()
local oldUnitpics  = false

local iconSizeX    = 76
local iconSizeY    = 76
local iconImgMult  = 0.85

local usedIconSizeX  = iconSizeX
local usedIconSizeY  = iconSizeY
local rectMinX       = 0
local rectMaxX       = 0
local rectMinY       = 0
local rectMaxY       = 0

local backgroundDimentions = {}
local iconMargin = usedIconSizeX / 25
local fontSize   = iconSizeY * 0.28
local picList

local playSounds  = true
local leftclick   = 'LuaUI/Sounds/buildbar_add.wav'
local middleclick = 'LuaUI/Sounds/buildbar_click.wav'
local rightclick  = 'LuaUI/Sounds/buildbar_rem.wav'

local guishaderDisabled = true
if spGetSelectedUnitsCount() > 0 then
  local checkSelectedUnits = true
end

-------------------------------------------------------------------------------
-- Rounded-rect helpers  (same technique as gui_static_tooltip_panel.lua)
-------------------------------------------------------------------------------

local function RoundedRectVertices(x1, y1, x2, y2, r, segments)
  local rr = math_min(r, (x2-x1)*0.5, (y2-y1)*0.5)
  if rr <= 0 then
    glVertex(x1, y1); glVertex(x2, y1)
    glVertex(x2, y2); glVertex(x1, y2)
    return
  end
  local function Arc(cx, cy, a0, a1)
    for i = 0, segments do
      local a = a0 + (a1-a0)*(i/segments)
      glVertex(cx + math_cos(a)*rr, cy + math_sin(a)*rr)
    end
  end
  Arc(x2-rr, y2-rr, 0,          math_pi*0.5)
  Arc(x1+rr, y2-rr, math_pi*0.5, math_pi)
  Arc(x1+rr, y1+rr, math_pi,    math_pi*1.5)
  Arc(x2-rr, y1+rr, math_pi*1.5, math_pi*2)
end

local function DrawRoundedRect(x1, y1, x2, y2, r, color)
  local rr = math_min(r, (x2-x1)*0.5, (y2-y1)*0.5)
  glColor(color)
  glBeginEnd(GL_TRIANGLE_FAN, function()
    local cx = (x1+x2)*0.5
    local cy = (y1+y2)*0.5
    glVertex(cx, cy)
    RoundedRectVertices(x1, y1, x2, y2, rr, 6)
    if rr <= 0 then
      glVertex(x1, y1)
    else
      glVertex(x2, y2-rr)
    end
  end)
end

-- bgcorner-based RectRound kept for icon-cell backgrounds
local function DrawRectRound(px, py, sx, sy, cs)
  glTexCoord(0.8, 0.8)
  glVertex(px+cs, py, 0); glVertex(sx-cs, py, 0)
  glVertex(sx-cs, sy, 0); glVertex(px+cs, sy, 0)

  glVertex(px, py+cs, 0); glVertex(px+cs, py+cs, 0)
  glVertex(px+cs, sy-cs, 0); glVertex(px, sy-cs, 0)

  glVertex(sx, py+cs, 0); glVertex(sx-cs, py+cs, 0)
  glVertex(sx-cs, sy-cs, 0); glVertex(sx, sy-cs, 0)

  local o = 0.07
  glTexCoord(o,o)   glVertex(px,    py,    0)
  glTexCoord(o,1-o) glVertex(px+cs, py,    0)
  glTexCoord(1-o,1-o) glVertex(px+cs, py+cs, 0)
  glTexCoord(1-o,o) glVertex(px,    py+cs, 0)

  glTexCoord(o,o)   glVertex(sx,    py,    0)
  glTexCoord(o,1-o) glVertex(sx-cs, py,    0)
  glTexCoord(1-o,1-o) glVertex(sx-cs, py+cs, 0)
  glTexCoord(1-o,o) glVertex(sx,    py+cs, 0)

  glTexCoord(o,o)   glVertex(px,    sy,    0)
  glTexCoord(o,1-o) glVertex(px+cs, sy,    0)
  glTexCoord(1-o,1-o) glVertex(px+cs, sy-cs, 0)
  glTexCoord(1-o,o) glVertex(px,    sy-cs, 0)

  glTexCoord(o,o)   glVertex(sx,    sy,    0)
  glTexCoord(o,1-o) glVertex(sx-cs, sy,    0)
  glTexCoord(1-o,1-o) glVertex(sx-cs, sy-cs, 0)
  glTexCoord(1-o,o) glVertex(sx,    sy-cs, 0)
end

local function RectRound(px, py, sx, sy, cs)
  glTexture(bgcorner)
  gl.BeginEnd(GL_QUADS, DrawRectRound, px, py, sx, sy, cs)
  glTexture(false)
end

-- Full panel chrome: outer shell + inner shell + accent bar on top edge
-- Mirrors DrawPanel() in gui_static_tooltip_panel.lua exactly.
-- The inner fill stops just below the accent strip so the accent is never buried.
local function DrawPanelChrome(x1, y1, x2, y2)
  -- outer dark shell + inner fill only; accent is drawn separately after cell bgs
  glColor(PANEL_OUTER_COLOR)
  RectRound(x1, y1, x2, y2, PANEL_RADIUS)
  DrawRoundedRect(x1+2, y1+2, x2-2, y2-(2+PANEL_ACCENT_HEIGHT), PANEL_RADIUS-1, PANEL_INNER_COLOR)
  glColor(1, 1, 1, 1)
end

local function DrawPanelAccent(x1, y1, x2, y2, accentColor)
  -- drawn last, on top of everything including cell backgrounds
  local accent = accentColor or PANEL_ACCENT_COLOR
  glColor(accent)
  glTexture(accentImg)
  glTexRect(x1+2, y2-(2+PANEL_ACCENT_HEIGHT), x2-2, y2-2)
  glTexture(false)
  glColor(1, 1, 1, 1)
end

-- Per-icon cell background (matches DrawSectionBox style from tooltip panel)
local function DrawCellBg(x1, y1, x2, y2)
  glColor(CELL_BG_COLOR)
  DrawRoundedRect(x1, y1, x2, y2, 5, CELL_BG_COLOR)
  -- subtle border
  glColor(CELL_BORDER_COLOR)
  glLineWidth(1)
  glBeginEnd(GL_LINE_LOOP, function()
    RoundedRectVertices(x1, y1, x2, y2, 5, 5)
  end)
  glColor(1, 1, 1, 1)
end

-------------------------------------------------------------------------------
-- Guishader integration
-------------------------------------------------------------------------------

local function updateGuishader()
  if WG['guishader'] then
    if not picList then
      WG['guishader'].RemoveDlist('selectionbuttons')
      guishaderDisabled = true
    else
      if backgroundDimentions[1] ~= nil then
        if dlistGuishader ~= nil then
          WG['guishader'].RemoveDlist('selectionbuttons')
          gl.DeleteList(dlistGuishader)
        end
        dlistGuishader = gl.CreateList(function()
          RectRound(backgroundDimentions[1], backgroundDimentions[2],
                    backgroundDimentions[3], backgroundDimentions[4],
                    usedIconSizeX / 8)
          WG['guishader'].InsertDlist(dlistGuishader, 'selectionbuttons')
        end)
        guishaderDisabled = false
      end
    end
  end
end

-------------------------------------------------------------------------------
-- Selection tracking
-------------------------------------------------------------------------------

local cachedAccentColor = nil  -- resolved on SelectionChanged, read by DrawPicList
local selectedUnits = Spring.GetSelectedUnits()
local selectedUnitsCount = Spring.GetSelectedUnitsCount()
local selectedUnitsCounts, selectedUnitsDefCounts = Spring.GetSelectedUnitsCounts()
local selectionChanged = true

-------------------------------------------------------------------------------
-- Tier accent colour helper
-------------------------------------------------------------------------------

-- Returns the TECH_ACCENT_COLORS entry for the highest-tech unit in the
-- current selection, falling back to PANEL_ACCENT_COLOR when no tech tag is found.
local function GetSelectionAccentColor()
  local bestTag = nil
  local bestRank = -1
  local rankOf = { T0=0, T1=1, T2=2, T3=3, T4=4 }
  if not selectedUnitsCounts then return PANEL_ACCENT_COLOR end
  for udid, _ in pairs(selectedUnitsCounts) do
    if type(udid) == 'number' then
      local ud = UnitDefs[udid]
      if ud and ud.customParams and ud.customParams.requiretech then
        local tag = TECH_REQUIREMENT_MAP[string_lower(tostring(ud.customParams.requiretech))]
        if tag and rankOf[tag] and rankOf[tag] > bestRank then
          bestRank = rankOf[tag]
          bestTag  = tag
        end
      end
    end
  end
  return (bestTag and TECH_ACCENT_COLORS[bestTag]) or PANEL_ACCENT_COLOR
end

function widget:SelectionChanged(sel)
  selectedUnits = sel
  selectedUnitsCount = Spring.GetSelectedUnitsCount()
  selectedUnitsCounts, selectedUnitsDefCounts = Spring.GetSelectedUnitsCounts()
  cachedAccentColor = GetSelectionAccentColor()
  selectionChanged = true
end

-------------------------------------------------------------------------------
-- ViewResize
-------------------------------------------------------------------------------

local vsx2, vsy2 = widgetHandler:GetViewSizes()
function widget:ViewResize(n_vsx, n_vsy)
  vsx, vsy = Spring.GetViewGeometry()
  iconsPerRow = math.floor(8 * (vsx / vsy))
  local newFontfileScale = (0.5 + (vsx*vsy / 5700000))
  if fontfileScale ~= newFontfileScale then
    fontfileScale = newFontfileScale
    gl.DeleteFont(font)
    font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)
  end

  usedIconSizeX = math.floor((iconSizeX/2) + ((vsx*vsy) / 115000))
  usedIconSizeY = math.floor((iconSizeY/2) + ((vsx*vsy) / 115000))
  fontSize   = usedIconSizeY * 0.28
  iconMargin = usedIconSizeX / 25

  if picList then
    gl.DeleteList(picList)
    picList = gl.CreateList(DrawPicList)
  end
end

-------------------------------------------------------------------------------
-- Icon cache warm-up
-------------------------------------------------------------------------------

function cacheUnitIcons()
  if cached == nil then
    gl.Color(1, 1, 1, 0.001)
    for id, unit in pairs(UnitDefs) do
      gl.Texture('#' .. id)
      gl.TexRect(-1, -1, 0, 0)
      gl.Texture(false)
    end
    gl.Color(1, 1, 1, 1)
    cached = true
  end
end

-------------------------------------------------------------------------------
-- Hover / tooltip
-------------------------------------------------------------------------------

local prevMouseIcon
local hoverClock = nil

function widget:RecvLuaMsg(msg, playerID)
  if msg:sub(1,18) == 'LobbyOverlayActive' then
    chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
  end
end

function widget:DrawScreen()
  if chobbyInterface then return end
  cacheUnitIcons()
  if picList then
    if spIsGUIHidden() then return end

    if mouseIcon ~= prevMouseIcon then
      gl.DeleteList(picList)
      picList = gl.CreateList(DrawPicList)
      prevMouseIcon = mouseIcon
    end
    gl.CallList(picList)

    -- draw highlights (immediate — mouse-state dependent, not baked)
    local x, y, lb, mb, rb = spGetMouseState()
    mouseIcon = MouseOverIcon(x, y)
    if not widgetHandler:InTweakMode() and mouseIcon >= 0 then
      if lb or mb or rb then
        if lb then
          DrawIconQuad(mouseIcon, leftmouseColor)
        elseif mb then
          DrawIconQuad(mouseIcon, middlemouseColor)
        elseif rb then
          DrawIconQuad(mouseIcon, rightmouseColor)
        end
      end
      if hoverClock == nil then hoverClock = os.clock() end
      Spring.SetMouseCursor('cursornormal')
      if WG['tooltip'] ~= nil and mouseIcon then
        local unitName = ' --- '
        local i = 0
        for udid, count in pairs(selectedUnitsCounts) do
          if type(udid) == 'number' then
            if i == mouseIcon then
              unitName = UnitDefs[udid].humanName
              break
            end
            i = i + 1
          end
        end
        WG['tooltip'].ShowTooltip('selectedunitbuttons_unit',
                                  "\255\215\255\215" .. unitName,
                                  x, backgroundDimentions[4] + (usedIconSizeY*0.37))
      end
      if WG['tooltip'] ~= nil and os.clock() - hoverClock > 0.6 then
        local text = "\255\215\255\215Selected units\n \255\255\255\255Left click\255\210\210\210: Select\n \255\255\255\255   + CTRL\255\210\210\210: Select units of this type on map\n \255\255\255\255   + ALT\255\210\210\210: Remove all by 1 unit of this unit type\n \255\255\255\255Right click\255\210\210\210: Remove\n \255\255\255\255    + CTRL\255\210\210\210: Remove only 1 unit from that unit type\n \255\255\255\255Middle click\255\210\210\210: Move to center location\n \255\255\255\255    + CTRL\255\210\210\210: Move to center off whole selection"
        local textHeight, desc, numLines = font:GetTextHeight(text)
        WG['tooltip'].ShowTooltip('selectedunitbuttons', text,
                                  vsx, backgroundDimentions[4] + (usedIconSizeY*1.3) + (textHeight*numLines*15*fontfileScale))
      end
    else
      hoverClock = nil
    end
  end
end

function widget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
  if unitCounts ~= nil and unitCounts[unitDefID] ~= nil then
    if unitCounts[unitDefID] > 1 then
      unitCounts[unitDefID] = unitCounts[unitDefID] - 1
    else
      unitCounts[unitDefID] = nil
    end
    checkSelectedUnits = true
    skipGetUnitCounts = true
  end
end

-------------------------------------------------------------------------------
-- Update
-------------------------------------------------------------------------------

local uiOpacitySec  = 0
local selChangedSec = 0

function widget:Update(dt)
  uiOpacitySec = uiOpacitySec + dt
  if uiOpacitySec > 0.5 then
    uiOpacitySec = 0
    local newOpacity = Spring.GetConfigFloat("ui_opacity", 0.66) * ui_opacityMultiplier
    if ui_opacity ~= newOpacity then
      ui_opacity = newOpacity
      gl.DeleteList(picList)
      picList = gl.CreateList(DrawPicList)
    end
  end

  selChangedSec = selChangedSec + dt
  if selectionChanged and selChangedSec > 0.1 then
    selChangedSec  = 0
    selectionChanged = nil
    if picList then
      gl.DeleteList(picList)
      picList = nil
    end
    if selectedUnitsCount > 0 then
      picList = gl.CreateList(DrawPicList)
    end
    updateGuishader()
  end
end

-------------------------------------------------------------------------------
-- Initialize / Shutdown
-------------------------------------------------------------------------------

function widget:Initialize()
  WG['selunitbuttons'] = {}
  WG['selunitbuttons'].getOldUnitIcons = function() return oldUnitpics end
  WG['selunitbuttons'].setOldUnitIcons = function(value) oldUnitpics = value end
  widget:ViewResize(vsx, vsy)
end

function widget:Shutdown()
  if picList then gl.DeleteList(picList) end
  gl.DeleteFont(font)
  WG['selunitbuttons'] = nil
  enabled = false
  updateGuishader()
end

-------------------------------------------------------------------------------
-- DrawPicList  — baked into a GL display list on selection change
-------------------------------------------------------------------------------

local startFromIcon = 0

function DrawPicList()
  if selectedUnitsCount == 0 then return end

  unitTypes = selectedUnitsDefCounts
  local displayedUnitTypes = unitTypes
  if displayedUnitTypes > iconsPerRow then
    displayedUnitTypes = iconsPerRow
  end

  if unitTypes <= 0 then
    countsTable  = {}
    activePress  = false
    currentDef   = nil
    return
  end

  local xmid  = vsx * 0.5
  local width = math_floor(usedIconSizeX * displayedUnitTypes)
  rectMinX = math_floor(xmid - 0.5 * width)
  rectMaxX = math_floor(xmid + 0.5 * width)
  rectMinY = 0
  rectMaxY = math_floor(rectMinY + usedIconSizeY)

  local xmin = math_floor(rectMinX)
  local xmax = math_floor(rectMinX + usedIconSizeX * displayedUnitTypes)

  if unitTypes > 16 then
    if startFromIcon > 0 then
      xmin = xmin - usedIconSizeX
    end
    if startFromIcon + iconsPerRow < unitTypes then
      xmax = xmax + usedIconSizeX
    end
  end

  if xmax < 0 or xmin > vsx then return end

  local padH = math_floor(iconMargin * 1.2)
  local padV = math_floor(iconMargin * 0.8)
  local bgX1 = xmin - padH
  local bgY1 = rectMinY
  local bgX2 = xmax + padH
  local bgY2 = rectMaxY + padV

  backgroundDimentions = {bgX1, bgY1, bgX2, bgY2}

  -- Panel chrome: outer shell + inner fill (accent drawn after cell bgs)
  DrawPanelChrome(bgX1, bgY1, bgX2, bgY2)

  -- Per-icon cell backgrounds (subtle, matches section-box feel)
  for i = 0, displayedUnitTypes - 1 do
    local cx1 = math_floor(rectMinX + usedIconSizeX * i) + math_floor(iconMargin * 0.4)
    local cx2 = cx1 + usedIconSizeX - math_floor(iconMargin * 0.8)
    local cy1 = rectMinY + math_floor(iconMargin * 0.3)
    local cy2 = rectMaxY + math_floor(iconMargin * 0.2)
    DrawCellBg(cx1, cy1, cx2, cy2)
  end

  -- Accent bar drawn last so nothing can paint over it
  DrawPanelAccent(bgX1, bgY1, bgX2, bgY2, cachedAccentColor or PANEL_ACCENT_COLOR)

  -- Draw unit icons
  local icon = 0
  local displayedIcon = 0
  for udid, count in pairs(selectedUnitsCounts) do
    if type(udid) == 'number' then
      if icon >= startFromIcon then
        DrawUnitDefTexture(udid, icon, count, 0)
        displayedIcon = displayedIcon + 1
        if displayedIcon >= iconsPerRow then break end
      end
      icon = icon + 1
    end
  end
end

-------------------------------------------------------------------------------
-- DrawUnitDefTexture
-------------------------------------------------------------------------------

function DrawUnitDefTexture(unitDefID, iconPos, count, row)
  local usedIconImgMult = iconImgMult
  local ypad2 = -usedIconSizeY / 50
  local color = {1, 1, 1, 0.9}
  if not WG['topbar'] or not WG['topbar'].showingQuit() then
    if mouseIcon ~= -1 then
      color = {1, 1, 1, 0.7}
    end
    if iconPos == mouseIcon then
      usedIconImgMult = iconImgMult * 1.1
      color = {1, 1, 1, 1}
      ypad2 = 0
    end
  end

  local yPad = (usedIconSizeY * (1 - usedIconImgMult)) / 3
  local xPad = (usedIconSizeX * (1 - usedIconImgMult)) / 3

  local xmin = math_floor(rectMinX + usedIconSizeX * iconPos) + xPad
  local xmax = xmin + usedIconSizeX - xPad - xPad
  if xmax < 0 or xmin > vsx then return end

  local ymin = rectMinY + yPad
  local ymax = rectMaxY - yPad

  glColor(color)
  glTexture('#' .. unitDefID)
  glTexRect(math_floor(xmin+iconMargin), math_floor(ymin+iconMargin+ypad2),
            math_ceil(xmax-iconMargin),  math_ceil(ymax-iconMargin+ypad2))
  glTexture(false)

  if count > 1 then
    local offset = math_ceil((ymax - (ymin+iconMargin+iconMargin)) / 20)
    font:Begin()
    font:SetTextColor(0.85, 0.85, 0.85, 1)
    font:Print(count,
               xmax - (iconMargin*1.3) - offset,
               ymin + (iconMargin*2.2) + offset + (fontSize/16) - (yPad/2),
               fontSize, "or")
    font:End()
  end
end

-------------------------------------------------------------------------------
-- DrawIconQuad  — immediate hover/click highlight, not baked
-------------------------------------------------------------------------------

function DrawIconQuad(iconPos, color)
  local usedIconImgMult = iconImgMult * 1.08
  local yPad = (usedIconSizeY * (1 - usedIconImgMult)) / 2
  local xPad = (usedIconSizeX * (1 - usedIconImgMult)) / 2

  local xmin = math_floor(rectMinX + usedIconSizeX * iconPos) + xPad
  local xmax = xmin + usedIconSizeX - xPad - xPad
  if xmax < 0 or xmin > vsx then return end

  local ymin = rectMinY
  local ymax = rectMaxY - yPad
  local cs   = (xmax - xmin) / 15

  gl.Texture(highlightImg)
  gl.Color(color)
  glTexRect(xmin+iconMargin, ymin+iconMargin+iconMargin, xmax-iconMargin, ymax-iconMargin)
  gl.Texture(false)

  RectRound(xmin+iconMargin, ymin+iconMargin+iconMargin, xmax-iconMargin, ymax-iconMargin, cs)
  glBlending(GL_SRC_ALPHA, GL_ONE)
  gl.Color(color[1], color[2], color[3], color[4] / 2)
  RectRound(xmin+iconMargin, ymin+iconMargin+iconMargin, xmax-iconMargin, ymax-iconMargin, cs)
  glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
end

-------------------------------------------------------------------------------
-- Mouse handling
-------------------------------------------------------------------------------

function widget:MousePress(x, y, button)
  mouseIcon = MouseOverIcon(x, y)
  activePress = (mouseIcon >= 0)
  return activePress
end

local function LeftMouseButton(unitDefID, unitTable)
  local alt, ctrl, meta, shift = spGetModKeyState()
  local acted = false
  if not ctrl then
    if alt or meta then
      acted = true
      spSelectUnitArray({unitTable[1]})
    else
      acted = true
      spSelectUnitArray(unitTable)
    end
  else
    local sorted = spGetTeamUnitsSorted(spGetMyTeamID())
    local units  = sorted[unitDefID]
    if units then
      acted = true
      spSelectUnitArray(units, shift)
    end
  end
  if acted and playSounds then
    Spring.PlaySoundFile(leftclick, 0.75, 'ui')
  end
end

local function MiddleMouseButton(unitDefID, unitTable)
  local alt, ctrl, meta, shift = spGetModKeyState()
  if ctrl then
    spSendCommands({"viewselection"})
  else
    local selUnits = spGetSelectedUnits()
    spSelectUnitArray(unitTable)
    spSendCommands({"viewselection"})
    spSelectUnitArray(selUnits)
  end
  if playSounds then
    Spring.PlaySoundFile(middleclick, 0.75, 'ui')
  end
end

local function RightMouseButton(unitDefID, unitTable)
  local alt, ctrl, meta, shift = spGetModKeyState()
  local selUnits = spGetSelectedUnits()
  local map = {}
  for _, uid in ipairs(selUnits) do map[uid] = true end
  for _, uid in ipairs(unitTable) do
    map[uid] = nil
    if ctrl then break end
  end
  spSelectUnitMap(map)
  if playSounds then
    Spring.PlaySoundFile(rightclick, 0.75, 'ui')
  end
end

function widget:MouseRelease(x, y, button)
  if WG['smartselect'] and not WG['smartselect'].updateSelection then return end
  if not activePress then return -1 end
  activePress = false
  local icon = MouseOverIcon(x, y)

  local units, unitDefsCount = spGetSelectedUnitsSorted()
  if unitDefsCount ~= unitTypes then return -1 end

  local unitDefID = -1
  local unitTable = nil
  local index = 0
  for udid, uTable in pairs(units) do
    if index == icon then
      unitDefID = udid
      unitTable = uTable
      break
    end
    index = index + 1
  end
  if unitTable == nil then return -1 end

  if     button == 1 then LeftMouseButton(unitDefID, unitTable)
  elseif button == 2 then MiddleMouseButton(unitDefID, unitTable)
  elseif button == 3 then RightMouseButton(unitDefID, unitTable)
  end
  return -1
end

function MouseOverIcon(x, y)
  if unitTypes <= 0      then return -1 end
  if x < rectMinX        then return -1 end
  if x > rectMaxX        then return -1 end
  if y < rectMinY        then return -1 end
  if y > rectMaxY        then return -1 end

  local icon = math.floor((x - rectMinX) / usedIconSizeX)
  if icon < 0           then icon = 0 end
  if icon >= unitTypes  then icon = unitTypes - 1 end
  return icon
end

-------------------------------------------------------------------------------
-- Config persistence
-------------------------------------------------------------------------------

function widget:GetConfigData()
  return {oldUnitpics = oldUnitpics}
end

function widget:SetConfigData(data)
  if data.oldUnitpics ~= nil then
    oldUnitpics = data.oldUnitpics
  end
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------