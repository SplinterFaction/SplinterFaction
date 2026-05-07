function widget:GetInfo()
	return {
		name    = "Static Faction Chooser",
		desc    = "Pre-game faction selection screen — send choice to game_spawn gadget",
		author  = "",
		date    = "2026",
		license = "GNU GPL, v2 or later",
		layer   = 2000,   -- above all other static widgets
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- Only relevant before the local player has spawned
--------------------------------------------------------------------------------

-- Magic byte that game_spawn.lua's RecvLuaMsg listens for
local SPAWN_MSG_BYTE = "\138"

--------------------------------------------------------------------------------
-- Assets — match gui_static_menu.lua
--------------------------------------------------------------------------------

local bgcorner  = "LuaUI/Images/bgcorner.png"
local accentImg = ":n:LuaUI/Images/staticgui_accent.png"

--------------------------------------------------------------------------------
-- Layout constants
--------------------------------------------------------------------------------

local CARD_WIDTH         = 420    -- wider to give 16:9 image room
local CARD_HEIGHT        = 500    -- tall enough for name + image + wrapped description
local CARD_GAP           = 40
local PANEL_PADDING      = 12
local ACCENT_HEIGHT      = 5
local OUTER_CORNER       = 5
local INNER_CORNER       = 4.3
local INNER_INSET        = 2.25

-- Heights of each content zone (base px, scaled at draw time)
local NAME_ZONE_H        = 36    -- faction name strip at top
local DESC_ZONE_H        = 110   -- description strip at bottom

-- Description text size (base px — tweak this to taste)
local DESC_FONT_SIZE     = 16

-- Faction name text size (base px — tweak this to taste)
local NAME_FONT_SIZE     = 20

--------------------------------------------------------------------------------
-- Theme — identical values to gui_static_menu.lua
--------------------------------------------------------------------------------

local BORDER_COLOR          = {0.15, 0.15, 0.15, 0.90}
local BORDER_COLOR_GUI      = {0.15, 0.15, 0.15, 0.90}
local PANEL_BG_COLOR        = {0.05, 0.05, 0.06, 0.88}
local PANEL_BG_COLOR_GUI    = {0.00, 0.00, 0.00, 0.22}
local PANEL_HOVER_COLOR     = {0.08, 0.08, 0.10, 0.95}
local PANEL_HOVER_COLOR_GUI = {0.02, 0.02, 0.02, 0.30}
local OVERLAY_BG            = {0.02, 0.02, 0.03, 0.82}
local TEXT_COLOR            = "\255\244\244\244"
local SUBTEXT_COLOR         = "\255\190\190\200"
local WAITING_COLOR         = "\255\160\160\170"
local COUNTDOWN_COLOR_NORMAL = "\255\244\244\244"
local COUNTDOWN_COLOR_URGENT = "\255\240\80\80"   -- red for final 10 seconds

-- Per-faction accent colours
local FACTION_DATA = {
	{
		commName    = "fedcommander",
		heroImg     = "unitpics-hero/fedcommander_up1-hero.png",
		label       = "Federation of Kala",
		description = [[Fast, aggressive, and relentless. They favor mobility and area-of-effect firepower, using walkers, missiles, and plasma cannons to overwhelm enemies. Instead of shields, they have rapid hull regeneration, allowing them to recover between fights. Their cloaking technology makes them unpredictable, striking from unexpected angles.]],
		accent      = {0.18, 0.52, 0.98, 1},   -- blue
	},
	{
		commName    = "lozcommander",
		heroImg     = "unitpics-hero/lozcommander_up1-hero.png",
		label       = "Loz Alliance",
		description = [[Slow, heavily shielded, and hard-hitting. Their massive tanks dominate the battlefield with long-range firepower, relying on personal energy shields that regenerate quickly after combat. While their units lack innate health regeneration, their shields and defensive structures keep them standing.]],
		accent      = {0.85, 0.22, 0.22, 1},   -- red
	},
}

--------------------------------------------------------------------------------
-- GL / Spring locals
--------------------------------------------------------------------------------

local glColor        = gl.Color
local glRect         = gl.Rect
local glTexture      = gl.Texture
local glTexRect      = gl.TexRect

local spGetViewGeometry  = Spring.GetViewGeometry
local spGetMouseState    = Spring.GetMouseState
local spPlaySoundFile    = Spring.PlaySoundFile
local spSendLuaRulesMsg  = Spring.SendLuaRulesMsg

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local vsx, vsy       = spGetViewGeometry()
local widgetScale    = 1
local cards          = {}          -- computed geometry per faction card
local chosen         = false       -- true once local player has sent their choice
local chosenCommName = nil         -- commName of the chosen faction
local lastHovered    = nil
local gameStarted    = false       -- true once GameFrame > 0

-- Countdown
local COUNTDOWN_TOTAL   = 30      -- seconds before auto-pick and game begins
local COUNTDOWN_BEEP_AT = 10      -- play tick sound for final N seconds
local TIMER_BAR_H       = 6       -- height of the countdown bar in base px
local countdownStart    = nil     -- set once game clock starts
local secondsLeft       = COUNTDOWN_TOTAL
local lastBeepSecond    = nil

--------------------------------------------------------------------------------
-- Font
--------------------------------------------------------------------------------

local fontfile  = LUAUI_DIRNAME .. "fonts/" .. Spring.GetConfigString("ui_font", "Saira_SemiCondensed-SemiBold.ttf")
local font

local function LoadWidgetFont()
	local scale = 0.5 + (vsx * vsy / 5700000)
	font = gl.LoadFont(fontfile, 25 * scale, 4.5 * scale, 1.8)
end

--------------------------------------------------------------------------------
-- Sound
--------------------------------------------------------------------------------

local function PlayHoverSound()   spPlaySoundFile("hover",     1.0, "ui") end
local function PlayClickSound()   spPlaySoundFile("leftclick", 1.0, "ui") end

--------------------------------------------------------------------------------
-- Helpers — identical to gui_static_menu.lua
--------------------------------------------------------------------------------

local function RectRound(px, py, sx, sy, cs)
	px, py, sx, sy, cs = math.floor(px), math.floor(py), math.floor(sx), math.floor(sy), math.floor(cs)
	glRect(px + cs, py, sx - cs, sy)
	glRect(sx - cs, py + cs, sx, sy - cs)
	glRect(px,      py + cs, px + cs, sy - cs)
	glTexture(bgcorner)
	glTexRect(px,      py + cs, px + cs, py)
	glTexRect(sx,      py + cs, sx - cs, py)
	glTexRect(px,      sy - cs, px + cs, sy)
	glTexRect(sx,      sy - cs, sx - cs, sy)
	glTexture(false)
end

local function IsOnRect(x, y, x1, y1, x2, y2)
	return x >= x1 and x <= x2 and y >= y1 and y <= y2
end

local function GetBorderColor()
	return WG.guishader and BORDER_COLOR_GUI or BORDER_COLOR
end

local function GetPanelBGColor(hovered)
	if hovered then
		return WG.guishader and PANEL_HOVER_COLOR_GUI or PANEL_HOVER_COLOR
	end
	return WG.guishader and PANEL_BG_COLOR_GUI or PANEL_BG_COLOR
end

--------------------------------------------------------------------------------
-- Geometry
--------------------------------------------------------------------------------

local function RecalculateGeometry()
	vsx, vsy   = spGetViewGeometry()
	widgetScale = 0.60 + (vsx * vsy / 5000000)

	local cw   = math.floor(CARD_WIDTH  * widgetScale)
	local ch   = math.floor(CARD_HEIGHT * widgetScale)
	local gap  = math.floor(CARD_GAP    * widgetScale)
	local totalW = cw * #FACTION_DATA + gap * (#FACTION_DATA - 1)

	local ox = math.floor((vsx - totalW) / 2)
	local oy = math.floor((vsy - ch)     / 2)

	cards = {}
	for i, fd in ipairs(FACTION_DATA) do
		local x1 = ox + (i - 1) * (cw + gap)
		local x2 = x1 + cw
		local y1 = oy
		local y2 = oy + ch
		cards[i] = {
			faction  = fd,
			x1 = x1, y1 = y1,
			x2 = x2, y2 = y2,
			cw = cw,  ch = ch,
		}
	end
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------

local function DrawCard(card, hovered)
	local fd = card.faction
	local x1, y1, x2, y2 = card.x1, card.y1, card.x2, card.y2
	local outerCorner = math.floor(OUTER_CORNER * widgetScale)
	local innerCorner = math.floor(INNER_CORNER * widgetScale)
	local inset       = math.floor(INNER_INSET  * widgetScale)
	local accentH     = math.floor(ACCENT_HEIGHT * widgetScale)
	local pad         = math.floor(PANEL_PADDING * widgetScale)
	local nameZoneH   = math.floor(NAME_ZONE_H  * widgetScale)
	local descZoneH   = math.floor(DESC_ZONE_H  * widgetScale)
	local ac          = fd.accent

	-- Outer shell
	local bc = GetBorderColor()
	glColor(bc[1], bc[2], bc[3], bc[4])
	RectRound(x1, y1, x2, y2, outerCorner)

	-- Inner panel
	local isChosenCard = chosen and (fd.commName == chosenCommName)
	local bg = GetPanelBGColor(hovered or isChosenCard)
	glColor(bg[1], bg[2], bg[3], bg[4])
	RectRound(x1 + inset, y1 + inset, x2 - inset, y2 - inset - 0.06, innerCorner)

	-- Accent strip at the very top of the inner panel
	glColor(ac[1], ac[2], ac[3], ac[4])
	glTexture(accentImg)
	glTexRect(x1 + inset, y2 - inset - accentH, x2 - inset, y2 - inset - 0.06)
	glTexture(false)

	-- Hover tint — also applied permanently to the chosen card
	local isChosen = chosen and (fd.commName == chosenCommName)
	if hovered or isChosen then
		glColor(ac[1], ac[2], ac[3], isChosen and 0.15 or 0.08)
		RectRound(x1 + inset + 1, y1 + inset + 1, x2 - inset - 1, y2 - inset - 1, innerCorner)
	end

	-- Inner content bounds (inside inset + pad)
	local cx1 = x1 + inset + pad
	local cx2 = x2 - inset - pad
	local cw  = cx2 - cx1

	-- Layout zones from top (y2) downward in screen space:
	--   [accent strip]
	--   [name zone]
	--   [hero image — 16:9, fills available width]
	--   [description zone]
	--   [bottom padding]

	-- Name zone: sits just below the accent strip
	local nameZoneTop    = y2 - inset - accentH - nameZoneH
	local nameZoneBottom = y2 - inset - accentH
	local nameSize       = math.floor(NAME_FONT_SIZE * widgetScale)
	local nameCentreY    = nameZoneTop + (nameZoneH - nameSize) * 0.5
	local cx             = x1 + (x2 - x1) * 0.5

	-- Hero image: 16:9, fills content width, sits below name zone
	local heroW  = cw
	local heroH  = math.floor(heroW * 9 / 16)
	local heroY2 = nameZoneTop - pad
	local heroY1 = heroY2 - heroH
	local heroX1 = cx1
	local heroX2 = cx2

	-- Description zone sits below hero image — height driven by word-wrap at draw time
	local _descY2 = heroY1 - pad   -- kept for reference, not used directly

	-- Draw faction name (centred in name zone)
	font:Begin()
	font:Print(
			TEXT_COLOR .. fd.label,
			cx,
			nameCentreY,
			nameSize,
			"con"
	)
	font:End()

	-- Hero image background (fallback colour if texture missing)
	glColor(0.08, 0.08, 0.10, 1)
	glRect(heroX1, heroY1, heroX2, heroY2)

	glColor(1, 1, 1, 1)
	glTexture(fd.heroImg)
	glTexRect(heroX1, heroY1, heroX2, heroY2)
	glTexture(false)

	-- Thin accent border around hero image
	glColor(ac[1], ac[2], ac[3], 0.40)
	glRect(heroX1,     heroY1,     heroX2,         heroY1 + 1)
	glRect(heroX1,     heroY2 - 1, heroX2,         heroY2)
	glRect(heroX1,     heroY1,     heroX1 + 1,     heroY2)
	glRect(heroX2 - 1, heroY1,     heroX2,         heroY2)

	-- Description — word-wrapped to fit inside card width
	local descSize  = math.floor(DESC_FONT_SIZE * widgetScale)
	local lineH     = math.floor(descSize * 1.55)
	local maxDescW  = cw - pad * 2

	-- Split description into wrapped lines
	local words = {}
	for word in fd.description:gmatch("%S+") do
		words[#words + 1] = word
	end

	local lines = {}
	local currentLine = ""
	for i = 1, #words do
		local testLine = currentLine == "" and words[i] or (currentLine .. " " .. words[i])
		local testW    = font:GetTextWidth(testLine) * descSize
		if testW > maxDescW and currentLine ~= "" then
			lines[#lines + 1] = currentLine
			currentLine = words[i]
		else
			currentLine = testLine
		end
	end
	if currentLine ~= "" then
		lines[#lines + 1] = currentLine
	end

	-- Draw lines top-to-bottom starting just below the hero image
	local descStartY = heroY1 - pad - descSize
	font:Begin()
	for i = 1, #lines do
		font:Print(
				SUBTEXT_COLOR .. lines[i],
				cx,
				descStartY - (i - 1) * lineH,
				descSize,
				"con"
		)
	end
	font:End()
end

local function DrawOverlay()
	-- Full-screen dim
	glColor(OVERLAY_BG[1], OVERLAY_BG[2], OVERLAY_BG[3], OVERLAY_BG[4])
	glRect(0, 0, vsx, vsy)
end

local function DrawTitle()
	local titleSize     = math.floor(22 * widgetScale)
	local countdownSize = math.floor(14 * widgetScale)
	local topY          = cards[1] and (cards[1].y2 + math.floor(72 * widgetScale)) or (vsy * 0.75)
	local urgent        = secondsLeft <= COUNTDOWN_BEEP_AT

	font:Begin()
	font:Print(
			TEXT_COLOR .. "Choose Your Faction",
			vsx * 0.5,
			topY,
			titleSize,
			"con"
	)
	font:End()

	if not countdownStart then return end

	-- Seconds label
	local labelY     = topY - math.floor(titleSize * 1.6)
	local labelColor = urgent and COUNTDOWN_COLOR_URGENT or COUNTDOWN_COLOR_NORMAL
	font:Begin()
	font:Print(
			labelColor .. secondsLeft .. "s",
			vsx * 0.5,
			labelY,
			countdownSize,
			"con"
	)
	font:End()

	-- Progress bar spanning the full width of both cards
	local barH   = math.floor(TIMER_BAR_H * widgetScale)
	local barY2  = labelY - math.floor(6 * widgetScale)
	local barY1  = barY2 - barH
	local barX1  = cards[1] and cards[1].x1 or math.floor(vsx * 0.2)
	local barX2  = cards[#cards] and cards[#cards].x2 or math.floor(vsx * 0.8)
	local barW   = barX2 - barX1
	local frac   = math.max(0, math.min(1, secondsLeft / COUNTDOWN_TOTAL))

	-- Track (empty)
	glColor(0.12, 0.12, 0.14, 0.9)
	glRect(barX1, barY1, barX2, barY2)

	-- Fill — drains from right to left
	if urgent then
		glColor(0.90, 0.22, 0.22, 1)
	else
		glColor(0.28, 0.62, 1.0, 0.9)
	end
	glRect(barX1, barY1, barX1 + math.floor(barW * frac), barY2)
end

--------------------------------------------------------------------------------
-- Widget lifecycle
--------------------------------------------------------------------------------

function widget:Initialize()
	LoadWidgetFont()
	RecalculateGeometry()
end

function widget:Shutdown()
	if font then gl.DeleteFont(font) ; font = nil end
end

function widget:ViewResize()
	vsx, vsy = spGetViewGeometry()
	if font then gl.DeleteFont(font) end
	LoadWidgetFont()
	RecalculateGeometry()
end

function widget:GameStart()
	countdownStart = Spring.GetTimer()
end

local function AutoPickFaction()
	local pick = cards[math.random(1, #cards)]
	local commDefID = UnitDefNames[pick.faction.commName] and UnitDefNames[pick.faction.commName].id
	if commDefID then
		spSendLuaRulesMsg(SPAWN_MSG_BYTE .. commDefID)
		chosen         = true
		chosenCommName = pick.faction.commName
	end
end

function widget:Update()
	-- Don't show or tick until the game has started
	if not gameStarted then
		if Spring.GetGameFrame() > 0 then
			gameStarted    = true
			countdownStart = Spring.GetTimer()
		end
		return
	end

	if not countdownStart then return end

	local elapsed = Spring.DiffTimers(Spring.GetTimer(), countdownStart)
	secondsLeft   = math.max(0, math.ceil(COUNTDOWN_TOTAL - elapsed))

	-- Tick sound in final COUNTDOWN_BEEP_AT seconds — plays regardless of chosen state
	if secondsLeft <= COUNTDOWN_BEEP_AT and secondsLeft ~= lastBeepSecond and secondsLeft > 0 then
		spPlaySoundFile("hover", 0.6, "ui")
		lastBeepSecond = secondsLeft
	end

	-- Auto-pick if player still hasn't chosen
	if not chosen and secondsLeft == 0 then
		AutoPickFaction()
	end

	-- Remove widget when countdown is fully done
	if secondsLeft == 0 then
		widgetHandler:RemoveWidget(self)
	end
end

--------------------------------------------------------------------------------
-- Input
--------------------------------------------------------------------------------

function widget:MousePress(x, y, button)
	if not gameStarted then return false end   -- don't swallow clicks during start position phase
	if button ~= 1 then return false end
	if chosen then return true end

	for i = 1, #cards do
		local c = cards[i]
		if IsOnRect(x, y, c.x1, c.y1, c.x2, c.y2) then
			return true
		end
	end
	return true
end

function widget:MouseRelease(x, y, button)
	if not gameStarted then return false end   -- don't swallow clicks during start position phase
	if button ~= 1 then return false end
	if chosen then return true end

	for i = 1, #cards do
		local c = cards[i]
		if IsOnRect(x, y, c.x1, c.y1, c.x2, c.y2) then
			local commDefID = UnitDefNames[c.faction.commName] and UnitDefNames[c.faction.commName].id
			if commDefID then
				PlayClickSound()
				spSendLuaRulesMsg(SPAWN_MSG_BYTE .. commDefID)
				chosen         = true
				chosenCommName = c.faction.commName
			end
			return true
		end
	end
	return true
end

--------------------------------------------------------------------------------
-- Draw
--------------------------------------------------------------------------------

function widget:DrawScreen()
	-- Don't show anything during start position phase
	if not gameStarted then return end

	DrawOverlay()
	DrawTitle()

	local mx, my = spGetMouseState()
	local currentHovered = nil

	for i = 1, #cards do
		local c = cards[i]
		-- Once chosen, don't highlight hover on unchosen cards
		local hovered = not chosen and IsOnRect(mx, my, c.x1, c.y1, c.x2, c.y2)
		if hovered then currentHovered = i end
		DrawCard(c, hovered)
	end

	-- Hover sound dedup (only before choosing)
	if not chosen then
		if currentHovered ~= lastHovered then
			if currentHovered then PlayHoverSound() end
			lastHovered = currentHovered
		end
	end
end