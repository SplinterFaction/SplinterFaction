function widget:GetInfo()
	return {
		name      = "Static Share Menu",
		desc      = "Share resources and units via hotkey H.",
		author    = "",
		date      = "2026-05-09",
		license   = "GNU GPL, v2 or later",
		layer     = 1001,
		enabled   = true,
	}
end

include("keysym.h.lua")

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

local bgcorner  = "LuaUI/Images/bgcorner.png"
local accentImg = ":n:LuaUI/Images/staticgui_accent.png"

local BASE_RESOLUTION     = 1080
local PANEL_WIDTH         = 340
local PANEL_MARGIN_X      = 20
local PANEL_MARGIN_Y      = 60
local OUTER_CORNER        = 10
local INNER_CORNER        = 8.5
local INNER_INSET         = 2.25
local PANEL_ACCENT_HEIGHT = 5

local SECTION_HEADER_H    = 22
local PLAYER_ROW_H        = 28
local PLAYERS_MAX_VISIBLE = 4
local UNIT_LIST_H         = 84
local SLIDER_SECTION_H    = 52
local CHECKBOX_H          = 28
local BUTTON_H            = 32
local INNER_PAD           = 10
local SECTION_GAP         = 8
local SCROLLBAR_W         = 6
local CHECKBOX_SIZE       = 14
local SLIDER_TRACK_H      = 10
local SLIDER_HANDLE_W     = 8

local BORDER_COLOR        = {0.15, 0.15, 0.15, 0.90}
local BORDER_COLOR_GUI    = {0.15, 0.15, 0.15, 0.90}
local PANEL_BG_COLOR      = {0.05, 0.05, 0.06, 0.92}
local PANEL_BG_COLOR_GUI  = {0.00, 0.00, 0.00, 0.28}
local SECTION_BG          = {0.12, 0.12, 0.13, 0.85}
local CATEGORY_BG         = {0.20, 0.20, 0.21, 0.55}
local SCROLLBAR_BG_C      = {1.0, 1.0, 1.0, 0.06}
local SCROLLBAR_THUMB_C   = {1.0, 1.0, 1.0, 0.22}
local SCROLLBAR_THUMBH_C  = {1.0, 1.0, 1.0, 0.35}
local HOVER_OVERLAY       = {0.90, 0.90, 0.90, 0.09}
local SELECTED_OVERLAY    = {0.22, 0.78, 0.35, 0.15}

local ACCENT_PANEL  = {0.18, 0.52, 0.98, 1}
local ACCENT_ALLY   = {0.22, 0.78, 0.35, 1}
local ACCENT_ENEMY  = {0.90, 0.22, 0.22, 1}
local ACCENT_METAL  = {0.53, 0.77, 0.89, 1}
local ACCENT_ENERGY = {0.94, 0.84, 0.24, 1}
local ACCENT_APPLY  = {0.18, 0.52, 0.98, 1}
local ACCENT_CANCEL = {0.90, 0.22, 0.22, 1}

local TEXT_COLOR   = "\255\244\244\244"
local TEXT_DIM     = "\255\160\162\168"
local TEXT_POSITIVE= "\255\90\255\115"
local TEXT_METAL   = "\255\136\197\226"
local TEXT_ENERGY  = "\255\240\214\62"

--------------------------------------------------------------------------------
-- GL / Spring speedups
--------------------------------------------------------------------------------

local glColor    = gl.Color
local glRect     = gl.Rect
local glTexture  = gl.Texture
local glTexRect  = gl.TexRect
local glScissor  = gl.Scissor

local spGetViewGeometry  = Spring.GetViewGeometry
local spGetMouseState    = Spring.GetMouseState
local spPlaySoundFile    = Spring.PlaySoundFile
local spGetMyTeamID      = Spring.GetMyTeamID
local spGetMyAllyTeamID  = Spring.GetMyAllyTeamID
local spGetTeamList      = Spring.GetTeamList
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitDefID     = Spring.GetUnitDefID
local spGetUnitCommands  = Spring.GetUnitCommands
local spIsGUIHidden      = Spring.IsGUIHidden

local math_floor = math.floor
local math_max   = math.max
local math_min   = math.min

local function Clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

--------------------------------------------------------------------------------
-- Font
--------------------------------------------------------------------------------

local vsx, vsy      = spGetViewGeometry()
local uiScale       = 1.0
local fontfile      = LUAUI_DIRNAME .. "fonts/" .. Spring.GetConfigString("ui_font", "Saira_SemiCondensed-SemiBold.ttf")
local fontfileScale = (0.5 + (vsx * vsy / 5700000))
local font

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local isOpen     = false
local panelRect  = {x1=0, y1=0, x2=0, y2=0}
local geom       = {}

local allyPlayers  = {}
local enemyPlayers = {}
local allyScroll   = 0
local enemyScroll  = 0
local allyDrag     = false
local enemyDrag    = false
local allyDragOff  = 0
local enemyDragOff = 0

local selectedUnits = {}
local unitScroll    = 0
local unitDrag      = false
local unitDragOff   = 0

local metalAmt      = 0
local energyAmt     = 0
local metalDrag     = false
local energyDrag    = false

local shareUnits    = false

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function PlayHoverSound()  spPlaySoundFile("hover",     1.0, "ui") end
local function PlayClickSound()  spPlaySoundFile("leftclick", 1.0, "ui") end

local function IsOnPanel(x, y)
	return x >= panelRect.x1 and x <= panelRect.x2
			and y >= panelRect.y1 and y <= panelRect.y2
end

local function GetBorderColor()
	if WG.guishader then return BORDER_COLOR_GUI end
	return BORDER_COLOR
end

local function GetPanelBGColor(hovered)
	if hovered then
		if WG.guishader then return {0.02, 0.02, 0.02, 0.30} end
		return {0.08, 0.08, 0.10, 0.95}
	end
	if WG.guishader then return PANEL_BG_COLOR_GUI end
	return PANEL_BG_COLOR
end

local function RectRound(px, py, sx, sy, cs)
	px, py, sx, sy, cs = math_floor(px), math_floor(py), math_floor(sx), math_floor(sy), math_floor(cs)
	glRect(px+cs, py, sx-cs, sy)
	glRect(sx-cs, py+cs, sx, sy-cs)
	glRect(px, py+cs, px+cs, sy-cs)
	glTexture(bgcorner)
	glTexRect(px,    py+cs, px+cs, py)
	glTexRect(sx,    py+cs, sx-cs, py)
	glTexRect(px,    sy-cs, px+cs, sy)
	glTexRect(sx,    sy-cs, sx-cs, sy)
	glTexture(false)
end

local function DrawPanelChrome(x1, y1, x2, y2, accent)
	local bc  = GetBorderColor()
	local pc  = GetPanelBGColor(false)
	local oc  = OUTER_CORNER * uiScale
	local ic  = INNER_CORNER * uiScale
	local ins = INNER_INSET  * uiScale
	local ah  = PANEL_ACCENT_HEIGHT * uiScale
	glColor(bc[1], bc[2], bc[3], bc[4])
	RectRound(x1, y1, x2, y2, oc)
	glColor(pc[1], pc[2], pc[3], pc[4])
	RectRound(x1+ins, y1+ins, x2-ins, y2-ins, ic)
	if accent then
		glColor(accent[1], accent[2], accent[3], 1)
		glTexture(accentImg)
		glTexRect(x1+ins, y2-ins-ah, x2-ins, y2-ins)
		glTexture(false)
	end
end

local function DrawSectionBG(x1, y1, x2, y2)
	glColor(SECTION_BG[1], SECTION_BG[2], SECTION_BG[3], SECTION_BG[4])
	RectRound(x1, y1, x2, y2, 4*uiScale)
end

local function DrawSectionHeader(x1, y1, x2, y2, label, accent)
	local ah = PANEL_ACCENT_HEIGHT * uiScale
	glColor(CATEGORY_BG[1], CATEGORY_BG[2], CATEGORY_BG[3], CATEGORY_BG[4])
	RectRound(x1, y1, x2, y2, 4*uiScale)
	if accent then
		glColor(accent[1], accent[2], accent[3], 1)
		glTexture(accentImg)
		glTexRect(x1, y2-ah, x2, y2)
		glTexture(false)
	end
	font:Begin()
	font:Print(TEXT_COLOR .. label, x1 + INNER_PAD*uiScale, y1+(y2-y1)*0.5-5*uiScale, 11*uiScale, "l")
	font:End()
end

local function DrawScrollbar(info, contentH, viewH, scrollOff, mx, my)
	if contentH <= viewH then return end
	local x1, y1, x2, y2 = info.x1, info.y1, info.x2, info.y2
	local trackH = y2 - y1
	local thumbH = math_max(math_floor(16*uiScale), trackH * (viewH / math_max(contentH, 1)))
	local range  = trackH - thumbH
	local frac   = Clamp(scrollOff / math_max(1, contentH - viewH), 0, 1)
	local ty2    = y2 - range * frac
	local ty1    = ty2 - thumbH
	local hov    = mx >= x1 and mx <= x2 and my >= y1 and my <= y2
	glColor(SCROLLBAR_BG_C[1], SCROLLBAR_BG_C[2], SCROLLBAR_BG_C[3], SCROLLBAR_BG_C[4])
	glRect(x1, y1, x2, y2)
	local tc = hov and SCROLLBAR_THUMBH_C or SCROLLBAR_THUMB_C
	glColor(tc[1], tc[2], tc[3], tc[4])
	glRect(x1, ty1, x2, ty2)
end

local function DrawFooterButton(btn, hovered)
	local x1, y1, x2, y2 = btn.x1, btn.y1, btn.x2, btn.y2
	local ac = btn.accent
	-- Base fill: dark with accent tint
	glColor(ac[1]*0.12, ac[2]*0.12, ac[3]*0.12, 0.95)
	glRect(x1, y1, x2, y2)
	-- Hover brightens it
	if hovered then
		glColor(ac[1]*0.25, ac[2]*0.25, ac[3]*0.25, 0.95)
		glRect(x1, y1, x2, y2)
	end
	-- Top accent bar (the accent sits at the TOP of the footer button, i.e. y2)
	local ah = PANEL_ACCENT_HEIGHT * uiScale
	glColor(ac[1], ac[2], ac[3], 1)
	glTexture(accentImg)
	glTexRect(x1, y2-ah, x2, y2)
	glTexture(false)
	-- Left/right divider line
	glColor(0, 0, 0, 0.5)
	glRect(x2, y1, x2+1, y2)
	-- Label
	font:Begin()
	font:Print(TEXT_COLOR .. btn.label, x1+(x2-x1)*0.5, y1+(y2-y1)*0.5-5*uiScale, 12*uiScale, "con")
	font:End()
end

local function DrawPlayerRow(entry, x1, y1, x2, y2, hovered)
	local r, g, b = entry.r, entry.g, entry.b
	if entry.selected then
		glColor(r*0.3, g*0.3, b*0.3, 0.4)
		glRect(x1, y1, x2, y2)
		glColor(SELECTED_OVERLAY[1], SELECTED_OVERLAY[2], SELECTED_OVERLAY[3], SELECTED_OVERLAY[4])
		glRect(x1, y1, x2, y2)
		glColor(r, g, b, 1)
		glRect(x1, y1, x1+3*uiScale, y2)
	elseif hovered then
		glColor(HOVER_OVERLAY[1], HOVER_OVERLAY[2], HOVER_OVERLAY[3], HOVER_OVERLAY[4])
		glRect(x1, y1, x2, y2)
	end
	glColor(r, g, b, 0.85)
	glRect(x1+6*uiScale, y1+4*uiScale, x1+18*uiScale, y2-4*uiScale)
	local nameCol = entry.selected and TEXT_COLOR or TEXT_DIM
	font:Begin()
	font:Print(nameCol .. entry.name, x1+24*uiScale, y1+(y2-y1)*0.5-5*uiScale, 10*uiScale, "l")
	font:End()
	glColor(1, 1, 1, 0.05)
	glRect(x1, y1, x2, y1+1)
end

--------------------------------------------------------------------------------
-- Geometry
--------------------------------------------------------------------------------

local function BuildGeometry()
	uiScale = vsy / BASE_RESOLUTION

	local pw  = PANEL_WIDTH * uiScale
	local pad = INNER_PAD   * uiScale
	local sg  = SECTION_GAP * uiScale
	local sw  = SCROLLBAR_W * uiScale

	local accentExtra = PANEL_ACCENT_HEIGHT * uiScale

	local playerRowH  = PLAYER_ROW_H    * uiScale
	local sectionHdrH = SECTION_HEADER_H* uiScale
	local unitListH   = UNIT_LIST_H     * uiScale
	local sliderH     = SLIDER_SECTION_H* uiScale
	local checkH      = CHECKBOX_H      * uiScale
	local btnH        = BUTTON_H        * uiScale
	local playersVisH = playerRowH * PLAYERS_MAX_VISIBLE

	-- Dry-run: simulate the cursor walk to get the exact total height needed.
	-- This runs the same logic as the real layout below, just counting pixels.
	local function measureLayout()
		local c = 0  -- cursor offset from y2, accumulates downward

		local function row(h)  c = c + h + sg  end
		local function gap(g)  c = c + g        end

		c = c + pad + accentExtra  -- top margin

		row(sectionHdrH) ; row(playersVisH) ; gap(sg * 0.5)   -- ally
		row(sectionHdrH) ; row(playersVisH) ; gap(sg * 0.5)   -- enemy
		row(sectionHdrH) ; row(unitListH)   ; gap(sg * 0.5)   -- units
		row(sectionHdrH) ; row(sliderH)     ; gap(sg * 0.5)   -- metal
		row(sectionHdrH) ; row(sliderH)     ; gap(sg * 0.5)   -- energy
		row(checkH)      ; gap(sg * 3)                         -- checkbox + extra gap
		row(btnH)                                               -- buttons
		c = c + pad                                             -- bottom margin

		return c
	end

	local contentH = measureLayout()

	local cx = math_floor(vsx * 0.5)
	local cy = math_floor(vsy * 0.5 + PANEL_MARGIN_Y * uiScale)
	local x1 = cx - math_floor(pw * 0.5)
	local x2 = x1 + math_floor(pw)
	local y2 = cy + math_floor(contentH * 0.5)
	local y1 = y2 - math_floor(contentH)

	if y1 < PANEL_MARGIN_X * uiScale then
		y1 = math_floor(PANEL_MARGIN_X * uiScale)
		y2 = y1 + math_floor(contentH)
	end
	if y2 > vsy - PANEL_MARGIN_X * uiScale then
		y2 = math_floor(vsy - PANEL_MARGIN_X * uiScale)
		y1 = y2 - math_floor(contentH)
	end

	panelRect = {x1=x1, y1=y1, x2=x2, y2=y2}

	local cx1    = x1 + pad
	local cx2    = x2 - pad
	local innerW = cx2 - cx1
	local btnW   = math_floor((innerW - pad) * 0.5)

	-- Real layout: cursor walks downward from y2 (top of panel in Spring coords).
	local cursor = y2 - pad - accentExtra

	local function NextRow(h)
		local ry2 = cursor
		local ry1 = cursor - h
		cursor = ry1 - sg
		return ry1, ry2
	end

	local allyHdrY1,   allyHdrY2   = NextRow(sectionHdrH)
	local allyListY1,  allyListY2  = NextRow(playersVisH)
	cursor = cursor - sg * 0.5

	local enemyHdrY1,  enemyHdrY2  = NextRow(sectionHdrH)
	local enemyListY1, enemyListY2 = NextRow(playersVisH)
	cursor = cursor - sg * 0.5

	local unitHdrY1,   unitHdrY2   = NextRow(sectionHdrH)
	local unitListY1,  unitListY2  = NextRow(unitListH)
	cursor = cursor - sg * 0.5

	local metalHdrY1,    metalHdrY2    = NextRow(sectionHdrH)
	local metalSliderY1, metalSliderY2 = NextRow(sliderH)
	cursor = cursor - sg * 0.5

	local energyHdrY1,    energyHdrY2    = NextRow(sectionHdrH)
	local energySliderY1, energySliderY2 = NextRow(sliderH)
	cursor = cursor - sg * 0.5

	local checkY1, checkY2 = NextRow(checkH)
	cursor = cursor - sg * 3   -- extra gap before buttons

	local btnY1, btnY2 = NextRow(btnH)
	-- remaining space = pad (bottom margin), matches measureLayout

	geom = {
		pad = pad, sw = sw, cx1 = cx1, cx2 = cx2, innerW = innerW,
		playerRowH = playerRowH, sectionHdrH = sectionHdrH,

		allyHdr  = {x1=cx1, y1=allyHdrY1,  x2=cx2,       y2=allyHdrY2},
		allyList = {x1=cx1, y1=allyListY1, x2=cx2-sw-2,  y2=allyListY2},
		allyBar  = {x1=cx2-sw, y1=allyListY1, x2=cx2,    y2=allyListY2},

		enemyHdr  = {x1=cx1, y1=enemyHdrY1,  x2=cx2,      y2=enemyHdrY2},
		enemyList = {x1=cx1, y1=enemyListY1, x2=cx2-sw-2, y2=enemyListY2},
		enemyBar  = {x1=cx2-sw, y1=enemyListY1, x2=cx2,   y2=enemyListY2},

		unitHdr  = {x1=cx1, y1=unitHdrY1,  x2=cx2,      y2=unitHdrY2},
		unitList = {x1=cx1, y1=unitListY1, x2=cx2-sw-2, y2=unitListY2},
		unitBar  = {x1=cx2-sw, y1=unitListY1, x2=cx2,   y2=unitListY2},

		metalHdr    = {x1=cx1, y1=metalHdrY1,    x2=cx2, y2=metalHdrY2},
		metalSlider = {x1=cx1, y1=metalSliderY1, x2=cx2, y2=metalSliderY2},

		energyHdr    = {x1=cx1, y1=energyHdrY1,    x2=cx2, y2=energyHdrY2},
		energySlider = {x1=cx1, y1=energySliderY1, x2=cx2, y2=energySliderY2},

		checkRow  = {x1=cx1, y1=checkY1, x2=cx2, y2=checkY2},

		cancelBtn = {x1=cx1,      y1=btnY1, x2=cx1+btnW, y2=btnY2, label="Cancel", accent=ACCENT_CANCEL},
		applyBtn  = {x1=cx2-btnW, y1=btnY1, x2=cx2,      y2=btnY2, label="Apply",  accent=ACCENT_APPLY},
	}
end

--------------------------------------------------------------------------------
-- Player list helpers
--------------------------------------------------------------------------------

local function GetTeamDisplayName(teamID)
	-- Spring.GetPlayerList(teamID) may not work in all engine versions.
	-- Instead iterate all players and match by team.
	for _, pid in ipairs(Spring.GetPlayerList() or {}) do
		local name, active, spectator, teamID2 = Spring.GetPlayerInfo(pid, false)
		if name and teamID2 == teamID then
			return name
		end
	end
	-- Fallback: AI name from GetTeamInfo
	local _, _, _, isAI, _, _ = Spring.GetTeamInfo(teamID, false)
	if isAI then
		local aiName, aiType = Spring.GetTeamLuaAI(teamID)
		if aiName and aiName ~= "" then return aiName end
	end
	return "Team " .. teamID
end

local function RefreshPlayerLists()
	allyPlayers  = {}
	enemyPlayers = {}
	local myTeam     = spGetMyTeamID()
	local myAllyTeam = spGetMyAllyTeamID()
	for _, teamID in ipairs(spGetTeamList() or {}) do
		if teamID ~= myTeam then
			local _, _, isDead, _, side, allyTeamID = Spring.GetTeamInfo(teamID, false)
			local isGaia = (teamID == 0) or (side and side:lower() == "gaia")
			if not isDead and not isGaia then
				local name = GetTeamDisplayName(teamID)
				local r, g, b = Spring.GetTeamColor(teamID)
				local isAlly = (allyTeamID == myAllyTeam)
				local entry = {teamID=teamID, name=name, r=r or 1, g=g or 1, b=b or 1, selected=false}
				if isAlly then
					allyPlayers[#allyPlayers+1] = entry
				else
					enemyPlayers[#enemyPlayers+1] = entry
				end
			end
		end
	end
	allyScroll  = 0
	enemyScroll = 0
end

local function RefreshSelectedUnits()
	selectedUnits = {}
	local counts = {}
	local order  = {}
	for _, uid in ipairs(spGetSelectedUnits() or {}) do
		local defID = spGetUnitDefID(uid)
		if defID then
			local ud = UnitDefs[defID]
			local hn = ud and ud.humanName or ("Unit "..defID)
			if not counts[hn] then
				counts[hn] = 0
				order[#order+1] = hn
			end
			counts[hn] = counts[hn] + 1
		end
	end
	for _, hn in ipairs(order) do
		selectedUnits[#selectedUnits+1] = {name=hn, count=counts[hn]}
	end
end

--------------------------------------------------------------------------------
-- Slider helpers
--------------------------------------------------------------------------------

local function GetSliderTrackRect(s)
	local th   = SLIDER_TRACK_H * uiScale
	local pad  = geom.pad
	local midY = s.y1 + (s.y2 - s.y1) * 0.5
	return s.x1+pad, midY-th*0.5, s.x2-pad, midY+th*0.5
end

local function SliderHitTest(s, x, y)
	local tx1, ty1, tx2, ty2 = GetSliderTrackRect(s)
	local ex = 6 * uiScale
	return x >= tx1-ex and x <= tx2+ex and y >= ty1-ex and y <= ty2+ex
end

local function SliderXToAmt(x, tx1, tx2, maxAmt)
	return math_floor(Clamp((x-tx1)/(tx2-tx1), 0, 1) * maxAmt + 0.5)
end

local function GetMyResources()
	local myTeam = spGetMyTeamID()
	local mc, ms = Spring.GetTeamResources(myTeam, "metal")
	local ec, es = Spring.GetTeamResources(myTeam, "energy")
	return math_floor(mc or 0), math_floor(ms or 1), math_floor(ec or 0), math_floor(es or 1)
end

local function DrawSlider(s, amount, maxAmt, accentColor, isDragging, label)
	local tx1, ty1, tx2, ty2 = GetSliderTrackRect(s)
	local hw = SLIDER_HANDLE_W * uiScale
	local fillX = tx1 + (tx2-tx1) * Clamp(amount / math_max(maxAmt, 1), 0, 1)

	glColor(0.08, 0.08, 0.08, 0.9)
	glRect(tx1, ty1, tx2, ty2)
	glColor(accentColor[1], accentColor[2], accentColor[3], isDragging and 0.75 or 0.55)
	glRect(tx1, ty1, fillX, ty2)
	local hc = isDragging and {1, 1, 0.4, 1} or {1, 1, 1, 0.9}
	glColor(hc[1], hc[2], hc[3], hc[4])
	glRect(fillX-hw*0.5, ty1-3*uiScale, fillX+hw*0.5, ty2+3*uiScale)

	local _, ms, _, es = GetMyResources()
	local dispMax = (label == "metal") and ms or es
	local centerX = tx1 + (tx2-tx1)*0.5
	font:Begin()
	font:Print(TEXT_DIM .. tostring(amount) .. TEXT_COLOR .. " / " .. TEXT_DIM .. tostring(dispMax),
	           centerX, ty1 - 9*uiScale, 10*uiScale, "con")
	font:End()
end

local function DrawCheckbox(x1, y1, x2, y2, checked, hovered, label)
	local cs  = CHECKBOX_SIZE * uiScale
	local cy1 = y1 + (y2-y1)*0.5 - cs*0.5
	local cy2 = cy1 + cs
	local cx2 = x1 + cs
	glColor(0.08, 0.08, 0.08, 0.9)
	glRect(x1, cy1, cx2, cy2)
	if hovered then
		glColor(0.3, 0.3, 0.3, 0.5)
		glRect(x1, cy1, cx2, cy2)
	end
	glColor(0.5, 0.5, 0.5, 0.8)
	glRect(x1,   cy2-1, cx2, cy2)
	glRect(x1,   cy1,   cx2, cy1+1)
	glRect(x1,   cy1,   x1+1, cy2)
	glRect(cx2-1, cy1,  cx2, cy2)
	if checked then
		glColor(ACCENT_ALLY[1], ACCENT_ALLY[2], ACCENT_ALLY[3], 1)
		local m = cs * 0.15
		glRect(x1+m, cy1+(cy2-cy1)*0.45, x1+(cx2-x1)*0.45, cy1+(cy2-cy1)*0.45+2*uiScale)
		glRect(x1+(cx2-x1)*0.35, cy1+m, x1+(cx2-x1)*0.35+2*uiScale, cy2-m)
	end
	font:Begin()
	font:Print(TEXT_COLOR .. label, cx2+8*uiScale, y1+(y2-y1)*0.5-5*uiScale, 11*uiScale, "l")
	font:End()
end

--------------------------------------------------------------------------------
-- Draw the panel
--------------------------------------------------------------------------------

local function GetPlayerAtPos(list, listRect, scroll, x, y)
	local rowH = geom.playerRowH
	for i, entry in ipairs(list) do
		local ry2 = listRect.y2 - (i-1)*rowH + scroll
		local ry1 = ry2 - rowH
		local cy1 = math_max(ry1, listRect.y1)
		local cy2 = math_min(ry2, listRect.y2)
		if x >= listRect.x1 and x <= listRect.x2 and y >= cy1 and y <= cy2 then
			return i, entry
		end
	end
	return nil, nil
end

local function DrawPlayerList(list, listRect, barRect, scroll, mx, my)
	local rowH    = geom.playerRowH
	local listH   = listRect.y2 - listRect.y1
	local contentH= #list * rowH

	DrawSectionBG(listRect.x1, listRect.y1, barRect.x2, listRect.y2)

	glScissor(math_floor(listRect.x1), math_floor(listRect.y1),
	          math_floor(listRect.x2 - listRect.x1), math_floor(listH))

	for i, entry in ipairs(list) do
		local ry2 = listRect.y2 - (i-1)*rowH + scroll
		local ry1 = ry2 - rowH
		if ry2 > listRect.y1 and ry1 < listRect.y2 then
			local hov = mx >= listRect.x1 and mx <= listRect.x2
					and my >= math_max(ry1, listRect.y1)
					and my <= math_min(ry2, listRect.y2)
			DrawPlayerRow(entry, listRect.x1, ry1, listRect.x2, ry2, hov)
		end
	end

	glScissor(false)
	DrawScrollbar(barRect, contentH, listH, scroll, mx, my)
end

local function DrawSharePanel()
	if not isOpen then return end

	local p = panelRect
	local g = geom
	local mx, my = spGetMouseState()

	DrawPanelChrome(p.x1, p.y1, p.x2, p.y2, ACCENT_PANEL)

	-- Ally list
	DrawSectionHeader(g.allyHdr.x1, g.allyHdr.y1, g.allyHdr.x2, g.allyHdr.y2, "Allies  (click to select)", ACCENT_ALLY)
	DrawPlayerList(allyPlayers, g.allyList, g.allyBar, allyScroll, mx, my)

	-- Enemy list
	DrawSectionHeader(g.enemyHdr.x1, g.enemyHdr.y1, g.enemyHdr.x2, g.enemyHdr.y2, "Enemies  (sharing to enemies is unusual!)", ACCENT_ENEMY)
	DrawPlayerList(enemyPlayers, g.enemyList, g.enemyBar, enemyScroll, mx, my)

	-- Selected units
	DrawSectionHeader(g.unitHdr.x1, g.unitHdr.y1, g.unitHdr.x2, g.unitHdr.y2, "Selected Units", nil)
	DrawSectionBG(g.unitList.x1, g.unitList.y1, g.unitBar.x2, g.unitList.y2)

	local ul      = g.unitList
	local lineH   = 14 * uiScale
	local fontSize= 10 * uiScale
	local viewH   = ul.y2 - ul.y1
	local unitContentH = #selectedUnits * lineH + g.pad

	if #selectedUnits == 0 then
		font:Begin()
		font:Print(TEXT_DIM .. "(no units selected)", ul.x1+g.pad, ul.y1+viewH*0.5-5*uiScale, fontSize, "l")
		font:End()
	else
		glScissor(math_floor(ul.x1), math_floor(ul.y1), math_floor(ul.x2-ul.x1), math_floor(viewH))
		font:Begin()
		for i, entry in ipairs(selectedUnits) do
			local rowY = ul.y2 - g.pad*0.5 - (i-1)*lineH + unitScroll - lineH*0.5 - 5*uiScale
			if rowY+lineH > ul.y1 and rowY < ul.y2 then
				if entry.count > 1 then
					font:Print(TEXT_POSITIVE .. "x"..entry.count, ul.x2-g.pad, rowY, fontSize, "r")
				end
				font:Print(TEXT_COLOR .. entry.name, ul.x1+g.pad, rowY, fontSize, "l")
			end
		end
		font:End()
		glScissor(false)
	end
	DrawScrollbar(g.unitBar, unitContentH, viewH, unitScroll, mx, my)

	-- Metal slider
	local mc, ms, ec, es = GetMyResources()
	metalAmt  = Clamp(metalAmt,  0, ms)
	energyAmt = Clamp(energyAmt, 0, es)
	DrawSectionHeader(g.metalHdr.x1, g.metalHdr.y1, g.metalHdr.x2, g.metalHdr.y2, TEXT_METAL.."Metal  to send", ACCENT_METAL)
	DrawSectionBG(g.metalSlider.x1, g.metalSlider.y1, g.metalSlider.x2, g.metalSlider.y2)
	DrawSlider(g.metalSlider, metalAmt, ms, ACCENT_METAL, metalDrag, "metal")

	-- Energy slider
	DrawSectionHeader(g.energyHdr.x1, g.energyHdr.y1, g.energyHdr.x2, g.energyHdr.y2, TEXT_ENERGY.."Energy  to send", ACCENT_ENERGY)
	DrawSectionBG(g.energySlider.x1, g.energySlider.y1, g.energySlider.x2, g.energySlider.y2)
	DrawSlider(g.energySlider, energyAmt, es, ACCENT_ENERGY, energyDrag, "energy")

	-- Checkbox
	local chov = mx >= g.checkRow.x1 and mx <= g.checkRow.x2 and my >= g.checkRow.y1 and my <= g.checkRow.y2
	DrawCheckbox(g.checkRow.x1, g.checkRow.y1, g.checkRow.x2, g.checkRow.y2, shareUnits, chov, "Share selected units")

	-- Footer buttons — drawn flush inside the panel bottom border
	local cancelHov = mx >= g.cancelBtn.x1 and mx <= g.cancelBtn.x2 and my >= g.cancelBtn.y1 and my <= g.cancelBtn.y2
	local applyHov  = mx >= g.applyBtn.x1  and mx <= g.applyBtn.x2  and my >= g.applyBtn.y1  and my <= g.applyBtn.y2
	DrawFooterButton(g.cancelBtn, cancelHov)
	DrawFooterButton(g.applyBtn,  applyHov)
end

--------------------------------------------------------------------------------
-- Apply
--------------------------------------------------------------------------------

local function DoApply()
	local targets = {}
	for _, e in ipairs(allyPlayers)  do if e.selected then targets[#targets+1] = e.teamID end end
	for _, e in ipairs(enemyPlayers) do if e.selected then targets[#targets+1] = e.teamID end end

	if #targets == 0 then
		Spring.Echo("[ShareMenu] No target selected.")
		return
	end

	local numTargets  = #targets
	local metalEach   = math_floor(metalAmt  / numTargets)
	local energyEach  = math_floor(energyAmt / numTargets)

	for _, teamID in ipairs(targets) do
		if metalEach  > 0 then Spring.ShareResources(teamID, "metal",  metalEach)  end
		if energyEach > 0 then Spring.ShareResources(teamID, "energy", energyEach) end
	end

	if shareUnits and #targets > 0 then
		local targetTeam = targets[1]
		local unitIDs    = spGetSelectedUnits() or {}

		if #unitIDs > 0 then
			-- Snapshot command queues and send to the order-preservation gadget
			-- BEFORE the transfer, while we still own the units.
			for _, uid in ipairs(unitIDs) do
				local cmds   = spGetUnitCommands(uid, -1) or {}
				local tokens = {}
				for _, cmd in ipairs(cmds) do
					local fields = {tostring(cmd.id)}
					for _, p in ipairs(cmd.params or {}) do fields[#fields+1] = tostring(p) end
					fields[#fields+1] = "OPTS:"..tostring(cmd.options or 0)
					tokens[#tokens+1] = table.concat(fields, ",")
				end
				local msg = "ShareOrders:"..uid..":"..targetTeam..":"..table.concat(tokens, "|")
				Spring.SendLuaRulesMsg(msg)
			end

			-- Transfer all selected units to the target team in one call.
			Spring.ShareResources(targetTeam, "units")
			Spring.Echo(string.format("[ShareMenu] Shared %d unit(s) to team %d", #unitIDs, targetTeam))
		end
	end

	metalAmt  = 0
	energyAmt = 0
end

--------------------------------------------------------------------------------
-- Open / Close
--------------------------------------------------------------------------------

local function Open()
	if isOpen then return end
	isOpen = true
	BuildGeometry()
	RefreshPlayerLists()
	RefreshSelectedUnits()
	metalAmt   = 0
	energyAmt  = 0
	shareUnits = false
	unitScroll = 0
	PlayClickSound()
end

local function Close()
	if not isOpen then return end
	isOpen = false
	PlayClickSound()
end

local function Toggle()
	if isOpen then Close() else Open() end
end

--------------------------------------------------------------------------------
-- Widget lifecycle
--------------------------------------------------------------------------------

function widget:Initialize()
	Spring.SendCommands("unbindkeyset h")
	Spring.SendCommands("unbindkeyset H")
	vsx, vsy = spGetViewGeometry()
	fontfileScale = (0.5 + (vsx * vsy / 5700000))
	font = gl.LoadFont(fontfile, 23*fontfileScale, 5*fontfileScale, 1.8)
	BuildGeometry()
	WG.StaticShareMenu = { Toggle = Toggle, Show = Open, Hide = Close }
end

function widget:Shutdown()
	if font then gl.DeleteFont(font) end
	Spring.SendCommands("bind h sharedialog")
	WG.StaticShareMenu = nil
end

function widget:ViewResize(nx, ny)
	vsx, vsy = nx, ny
	local newScale = (0.5 + (vsx * vsy / 5700000))
	if newScale ~= fontfileScale then
		fontfileScale = newScale
		if font then gl.DeleteFont(font) end
		font = gl.LoadFont(fontfile, 23*fontfileScale, 5*fontfileScale, 1.8)
	end
	if isOpen then BuildGeometry() end
end

function widget:KeyPress(key, mods, isRepeat)
	if isRepeat then return false end
	if key == KEYSYMS.h or key == KEYSYMS.H then
		Toggle()
		return true
	end
	if isOpen and key == KEYSYMS.ESCAPE then
		Close()
		return true
	end
	return false
end

function widget:IsAbove(x, y)
	return isOpen and IsOnPanel(x, y)
end

function widget:MouseRelease(x, y, button)
	if not isOpen then return false end
	if button ~= 1 then return false end

	if metalDrag  then metalDrag  = false ; return true end
	if energyDrag then energyDrag = false ; return true end
	if allyDrag   then allyDrag   = false ; return true end
	if enemyDrag  then enemyDrag  = false ; return true end
	if unitDrag   then unitDrag   = false ; return true end

	if not IsOnPanel(x, y) then return false end

	local g = geom

	-- Sliders (handled in MousePress/MouseMove but consume release too)
	if SliderHitTest(g.metalSlider,  x, y) then return true end
	if SliderHitTest(g.energySlider, x, y) then return true end

	-- Apply button
	local ab = g.applyBtn
	if x >= ab.x1 and x <= ab.x2 and y >= ab.y1 and y <= ab.y2 then
		PlayClickSound()
		DoApply()
		return true
	end

	-- Cancel button
	local cb = g.cancelBtn
	if x >= cb.x1 and x <= cb.x2 and y >= cb.y1 and y <= cb.y2 then
		PlayClickSound()
		Close()
		return true
	end

	-- Checkbox
	local cr = g.checkRow
	if x >= cr.x1 and x <= cr.x2 and y >= cr.y1 and y <= cr.y2 then
		shareUnits = not shareUnits
		PlayClickSound()
		return true
	end

	-- Ally player rows
	local _, entry = GetPlayerAtPos(allyPlayers, g.allyList, allyScroll, x, y)
	if entry then
		local was = entry.selected
		for _, e in ipairs(allyPlayers)  do e.selected = false end
		for _, e in ipairs(enemyPlayers) do e.selected = false end
		entry.selected = not was
		PlayClickSound()
		return true
	end

	-- Enemy player rows
	local _, eentry = GetPlayerAtPos(enemyPlayers, g.enemyList, enemyScroll, x, y)
	if eentry then
		local was = eentry.selected
		for _, e in ipairs(allyPlayers)  do e.selected = false end
		for _, e in ipairs(enemyPlayers) do e.selected = false end
		eentry.selected = not was
		PlayClickSound()
		return true
	end

	return true
end

function widget:MousePress(x, y, button)
	if not isOpen then return false end
	if not IsOnPanel(x, y) then return false end
	if button ~= 1 then return true end

	local g = geom

	if SliderHitTest(g.metalSlider, x, y) then
		metalDrag = true
		local tx1, _, tx2, _ = GetSliderTrackRect(g.metalSlider)
		local _, ms, _, _ = GetMyResources()
		metalAmt = SliderXToAmt(x, tx1, tx2, ms)
		return true
	end

	if SliderHitTest(g.energySlider, x, y) then
		energyDrag = true
		local tx1, _, tx2, _ = GetSliderTrackRect(g.energySlider)
		local _, _, _, es = GetMyResources()
		energyAmt = SliderXToAmt(x, tx1, tx2, es)
		return true
	end

	-- Scrollbar drags
	local function TryScrollbar(bar, contentH, viewH, dragFlag, dragOffVar)
		if x >= bar.x1 and x <= bar.x2 and y >= bar.y1 and y <= bar.y2 and contentH > viewH then
			local trackH = bar.y2 - bar.y1
			local thumbH = math_max(16*uiScale, trackH*(viewH/contentH))
			local range  = trackH - thumbH
			local frac   = Clamp(dragOffVar / math_max(1, contentH - viewH), 0, 1)
			local ty2    = bar.y2 - range * frac
			return true, ty2 - y
		end
		return false, 0
	end

	local allyContentH  = #allyPlayers  * g.playerRowH
	local allyViewH     = g.allyList.y2 - g.allyList.y1
	local ok, off = TryScrollbar(g.allyBar, allyContentH, allyViewH, allyDrag, allyScroll)
	if ok then allyDrag = true ; allyDragOff = off ; return true end

	local enemyContentH = #enemyPlayers * g.playerRowH
	local enemyViewH    = g.enemyList.y2 - g.enemyList.y1
	ok, off = TryScrollbar(g.enemyBar, enemyContentH, enemyViewH, enemyDrag, enemyScroll)
	if ok then enemyDrag = true ; enemyDragOff = off ; return true end

	local lineH         = 14 * uiScale
	local unitContentH  = #selectedUnits * lineH + g.pad
	local unitViewH     = g.unitList.y2 - g.unitList.y1
	ok, off = TryScrollbar(g.unitBar, unitContentH, unitViewH, unitDrag, unitScroll)
	if ok then unitDrag = true ; unitDragOff = off ; return true end

	return true
end

function widget:MouseMove(x, y, dx, dy, button)
	if not isOpen then return false end

	if metalDrag then
		local tx1, _, tx2 = GetSliderTrackRect(geom.metalSlider)
		local _, ms, _, _ = GetMyResources()
		metalAmt = SliderXToAmt(x, tx1, tx2, ms)
		return true
	end

	if energyDrag then
		local tx1, _, tx2 = GetSliderTrackRect(geom.energySlider)
		local _, _, _, es = GetMyResources()
		energyAmt = SliderXToAmt(x, tx1, tx2, es)
		return true
	end

	local function DragScrollbar(bar, contentH, viewH, scrollRef, dragOff)
		local trackH = bar.y2 - bar.y1
		local thumbH = math_max(16*uiScale, trackH*(viewH/math_max(contentH,1)))
		local range  = trackH - thumbH
		if range > 0 then
			local ty2 = Clamp(y+dragOff, bar.y1+thumbH, bar.y2)
			local frac= (bar.y2 - ty2) / range
			return Clamp(frac*(contentH-viewH), 0, contentH-viewH)
		end
		return scrollRef
	end

	if allyDrag then
		local contentH = #allyPlayers * geom.playerRowH
		local viewH    = geom.allyList.y2 - geom.allyList.y1
		allyScroll     = DragScrollbar(geom.allyBar, contentH, viewH, allyScroll, allyDragOff)
		return true
	end

	if enemyDrag then
		local contentH = #enemyPlayers * geom.playerRowH
		local viewH    = geom.enemyList.y2 - geom.enemyList.y1
		enemyScroll    = DragScrollbar(geom.enemyBar, contentH, viewH, enemyScroll, enemyDragOff)
		return true
	end

	if unitDrag then
		local lineH    = 14 * uiScale
		local contentH = #selectedUnits * lineH + geom.pad
		local viewH    = geom.unitList.y2 - geom.unitList.y1
		unitScroll     = DragScrollbar(geom.unitBar, contentH, viewH, unitScroll, unitDragOff)
		return true
	end

	return false
end

function widget:MouseWheel(up, value)
	if not isOpen then return false end
	local mx, my = spGetMouseState()
	local step   = math_floor(geom.playerRowH * 2)

	local al = geom.allyList
	if mx >= al.x1 and mx <= al.x2 and my >= al.y1 and my <= al.y2 then
		local contentH = #allyPlayers * geom.playerRowH
		local viewH    = al.y2 - al.y1
		if contentH > viewH then
			allyScroll = Clamp(allyScroll + (up and -step or step), 0, contentH - viewH)
			return true
		end
	end

	local el = geom.enemyList
	if mx >= el.x1 and mx <= el.x2 and my >= el.y1 and my <= el.y2 then
		local contentH = #enemyPlayers * geom.playerRowH
		local viewH    = el.y2 - el.y1
		if contentH > viewH then
			enemyScroll = Clamp(enemyScroll + (up and -step or step), 0, contentH - viewH)
			return true
		end
	end

	local ul = geom.unitList
	if mx >= ul.x1 and mx <= ul.x2 and my >= ul.y1 and my <= ul.y2 then
		local lineH    = 14 * uiScale
		local contentH = #selectedUnits * lineH + geom.pad
		local viewH    = ul.y2 - ul.y1
		if contentH > viewH then
			unitScroll = Clamp(unitScroll + (up and -step or step), 0, contentH - viewH)
			return true
		end
	end

	return false
end

function widget:Update(dt)
	if not isOpen then return end
	RefreshSelectedUnits()
end

function widget:DrawScreen()
	if spIsGUIHidden() then return end
	if not isOpen then return end
	if not font then return end
	DrawSharePanel()
end