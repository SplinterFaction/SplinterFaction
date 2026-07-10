function widget:GetInfo()
	return {
		name    = "Static Resourcebar",
		desc    = "Static top resource bars for supply, metal and energy",
		author  = "",
		date    = "2026-03-22",
		license = "GPL v2 or later",
		layer   = 1,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- config
--------------------------------------------------------------------------------

local ui_opacity = tonumber(Spring.GetConfigFloat("ui_opacity", 0.66) or 0.66)

local FONT_FILE  = LUAUI_DIRNAME .. "fonts/" .. Spring.GetConfigString("ui_font",  "Saira_SemiCondensed-SemiBold.ttf")
local FONT_FILE2 = LUAUI_DIRNAME .. "fonts/" .. Spring.GetConfigString("ui_font2", "Saira_SemiCondensed-SemiBold.ttf")

local BAR_HEIGHT       = 52
local BAR_WIDTH        = 350
local BAR_GAP          = 14
local PANEL_PADDING    = 10
local INNER_PADDING    = 8
local ICON_SIZE        = 24
local FILL_HEIGHT      = 10
local CORNER_SIZE      = 10
local PANEL_ACCENT_HEIGHT = 5

local TOP_MARGIN       = 8
local SUPPLY_MIN_CAP   = 50       -- minimum visual supply scale
local SUPPLY_STEP      = 10       -- rounds display cap up to this
local SUPPLY_SHRINK_DELAY = 90    -- frames before shrinking display cap

local SHOW_NET_FIRST   = true     -- "net  (+in / -out)" layout

local PCT_STEPS        = 200      -- fill-bar quantization steps (~1px at default width)

-- research points (RP): a pure accumulator, no storage cap, no share slider.
local RP_WIDTH          = 200    -- compact panel; no fill bar or slider
local RP_RATE_WINDOW    = 150    -- frames (~5s) used to smooth the +/s readout
local RP_FLASH_DURATION = 1.5    -- seconds a spend "-N" stays visible

--------------------------------------------------------------------------------
-- locals
--------------------------------------------------------------------------------

local spGetViewGeometry    = Spring.GetViewGeometry
local spGetMyTeamID        = Spring.GetMyTeamID
local spGetTeamResources   = Spring.GetTeamResources
local spGetTeamRulesParam  = Spring.GetTeamRulesParam
local spGetSpectatingState = Spring.GetSpectatingState
local spSendCommands       = Spring.SendCommands
local spSetShareLevel      = Spring.SetShareLevel
local spGetGameFrame       = Spring.GetGameFrame
local spGetConfigFloat     = Spring.GetConfigFloat

local glColor      = gl.Color
local glTexture    = gl.Texture
local glTexRect    = gl.TexRect
local glPushMatrix = gl.PushMatrix
local glPopMatrix  = gl.PopMatrix
local glTranslate  = gl.Translate
local glScale      = gl.Scale
local glCallList   = gl.CallList
local glRect       = gl.Rect

local vsx, vsy = spGetViewGeometry()
local widgetScale = 1
local posx, posy = 0, 0
-- 2x2 grid: metal/energy on the top row, supply/research beneath them.
local ROW_GAP   = 10                    -- vertical gap between the two rows
local COL2_X    = BAR_WIDTH + BAR_GAP    -- x-origin of the right column
local ROW_TOP_Y = BAR_HEIGHT + ROW_GAP   -- y-origin of the top row (metal/energy)
local ROW_BOT_Y = 0                      -- y-origin of the bottom row (supply/research)

local width = (BAR_WIDTH * 2) + BAR_GAP
local height = (BAR_HEIGHT * 2) + ROW_GAP

local fontfileScale = 1
local fontfileSize = 23
local fontfileOutlineSize = 6
local fontfileOutlineStrength = 1.33
local font
local font2

local displayListBg
local displayListStatic
local displayListDynamic

local bgcorner   = ":n:" .. LUAUI_DIRNAME .. "Images/bgcorner.png"
local accentImg  = ":n:" .. LUAUI_DIRNAME .. "Images/staticgui_accent.png"
local supplyTexture = LUAUI_DIRNAME .. "Images/supply.png"
local energyTexture = LUAUI_DIRNAME .. "Images/energy2.png"
local metalTexture  = LUAUI_DIRNAME .. "Images/metal.png"
local researchTexture = LUAUI_DIRNAME .. "Images/research.png"  -- add this asset; panel still reads fine without it

local barTexture = LUAUI_DIRNAME .. "Images/resbar.dds"
local barGlowCenterTexture = LUAUI_DIRNAME .. "Images/barglow-center.dds"
local barGlowEdgeTexture   = LUAUI_DIRNAME .. "Images/barglow-edge.dds"

local white    = "\255\255\255\255"
local green    = "\255\0\255\1"
local red      = "\255\255\0\1"
local orange   = "\255\255\135\1"
local yellow   = "\255\255\255\1"
local skyblue  = "\255\136\197\226"
local violet   = "\255\190\120\255"  -- research accent, matches morph tooltip

local supplyDisplayCap = SUPPLY_MIN_CAP
local supplyShrinkFrame = 0
local chobbyInterface = false

-- research point display state (computed widget-side)
local rpValue        = 0      -- current balance
local rpPrevValue    = nil    -- last sampled balance (spend detection)
local rpSmoothedRate = 0      -- +/s, smoothed over RP_RATE_WINDOW
local rpSamples      = {}     -- ring of { frame=, value= }
local rpLastFrame    = -1
local rpFlashAmount  = 0      -- size of the most recent spend
local rpFlashTimer   = 0      -- seconds remaining on the spend flash

-- cached formatted strings; rebuilt only when the displayed value changes so
-- DrawResearchPanel allocates no garbage per draw frame
local rpValueStr     = "0"
local rpRateStr      = "+0.0/s"
local rpFlashStr     = "-0"
local rpValueInt     = 0
local rpRateRounded  = 0

--------------------------------------------------------------------------------
-- Share level state
--------------------------------------------------------------------------------

local metalShareLevel  = 0.8
local energyShareLevel = 0.8

-- drag state
local draggingMetal  = false
local draggingEnergy = false

-- slider visual config
local SLIDER_LINE_W    = 2     -- width of the vertical marker line
local SLIDER_HANDLE_W  = 5   -- total width of the draggable handle
local SLIDER_HANDLE_H  = 1    -- height of handle tab above/below the bar
local SLIDER_COLOR     = {1.0, 1.0, 1.0, 0.85}
local SLIDER_DRAG_COLOR= {1.0, 1.0, 0.4, 1.0}

-- Last values used to build the dynamic list. The list is only rebuilt when
-- any of these change, instead of every frame.
local lastDynamic = {}
local lastBuildFrame = -1  -- last sim frame the dynamic list was sampled

local function DynamicValuesChanged(supplyUsed, supplyMax, supplyFree, supplyPct,
                                    mc, ms, mi, mp, metalPct,
                                    ec, es, ei, ep, energyPct)
	return lastDynamic.supplyUsed ~= supplyUsed
			or lastDynamic.supplyMax  ~= supplyMax
			or lastDynamic.supplyFree ~= supplyFree
			or lastDynamic.supplyPct  ~= supplyPct
			or lastDynamic.mc ~= mc or lastDynamic.ms ~= ms
			or lastDynamic.mi ~= mi or lastDynamic.mp ~= mp
			or lastDynamic.metalPct   ~= metalPct
			or lastDynamic.ec ~= ec or lastDynamic.es ~= es
			or lastDynamic.ei ~= ei or lastDynamic.ep ~= ep
			or lastDynamic.energyPct  ~= energyPct
end

--------------------------------------------------------------------------------
-- helpers
--------------------------------------------------------------------------------

local function round(num, idp)
	local mult = 10 ^ (idp or 0)
	return math.floor(num * mult + 0.5) / mult
end

local function clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

local function roundUpToStep(v, step)
	return math.ceil(v / step) * step
end

local function GetUIOpacity()
	return tonumber(spGetConfigFloat("ui_opacity", 0.66) or 0.66)
end

--------------------------------------------------------------------------------
-- rounded rect
--------------------------------------------------------------------------------

local function DrawRectRound(px, py, sx, sy, cs)
	gl.TexCoord(0.8, 0.8)
	gl.Vertex(px + cs, py, 0)
	gl.Vertex(sx - cs, py, 0)
	gl.Vertex(sx - cs, sy, 0)
	gl.Vertex(px + cs, sy, 0)

	gl.Vertex(px, py + cs, 0)
	gl.Vertex(px + cs, py + cs, 0)
	gl.Vertex(px + cs, sy - cs, 0)
	gl.Vertex(px, sy - cs, 0)

	gl.Vertex(sx, py + cs, 0)
	gl.Vertex(sx - cs, py + cs, 0)
	gl.Vertex(sx - cs, sy - cs, 0)
	gl.Vertex(sx, sy - cs, 0)

	local o = 0.07

	-- bottom left
	gl.TexCoord(o,o)       gl.Vertex(px, py, 0)
	gl.TexCoord(o,1-o)     gl.Vertex(px+cs, py, 0)
	gl.TexCoord(1-o,1-o)   gl.Vertex(px+cs, py+cs, 0)
	gl.TexCoord(1-o,o)     gl.Vertex(px, py+cs, 0)

	-- bottom right
	gl.TexCoord(o,o)       gl.Vertex(sx, py, 0)
	gl.TexCoord(o,1-o)     gl.Vertex(sx-cs, py, 0)
	gl.TexCoord(1-o,1-o)   gl.Vertex(sx-cs, py+cs, 0)
	gl.TexCoord(1-o,o)     gl.Vertex(sx, py+cs, 0)

	-- top left
	gl.TexCoord(o,o)       gl.Vertex(px, sy, 0)
	gl.TexCoord(o,1-o)     gl.Vertex(px+cs, sy, 0)
	gl.TexCoord(1-o,1-o)   gl.Vertex(px+cs, sy-cs, 0)
	gl.TexCoord(1-o,o)     gl.Vertex(px, sy-cs, 0)

	-- top right
	gl.TexCoord(o,o)       gl.Vertex(sx, sy, 0)
	gl.TexCoord(o,1-o)     gl.Vertex(sx-cs, sy, 0)
	gl.TexCoord(1-o,1-o)   gl.Vertex(sx-cs, sy-cs, 0)
	gl.TexCoord(1-o,o)     gl.Vertex(sx, sy-cs, 0)
end

local function RectRound(px, py, sx, sy, cs)
	glTexture(bgcorner)
	gl.BeginEnd(GL.QUADS, DrawRectRound, px, py, sx, sy, cs)
	glTexture(false)
end

local function DrawPanel(x1, y1, x2, y2, accentR, accentG, accentB, accentA)
	-- outer
	glColor(0, 0, 0, ui_opacity)
	RectRound(x1, y1, x2, y2, CORNER_SIZE)

	-- inner
	glColor(0.12, 0.12, 0.12, 0.78)
	RectRound(x1 + 2, y1 + 2, x2 - 2, y2 - 2, CORNER_SIZE - 1)

	-- subtle top accent
	glColor(accentR, accentG, accentB, 1)
	glTexture(accentImg)
	gl.TexRect(x1 + 2, y2 - (2 + PANEL_ACCENT_HEIGHT), x2 - 2, y2 - 2)
	glTexture(false)
end

local function DrawFillBar(x1, y1, x2, y2, pct, r, g, b, glow)
	pct = clamp(pct, 0, 1)

	-- track
	glColor(0.08, 0.08, 0.08, 0.9)
	glTexture(barTexture)
	RectRound(x1, y1, x2, y2, 4)

	-- faint inner track
	glColor(0.18, 0.18, 0.18, 0.9)
	glTexRect(x1 + 1, y1 + 1, x2 - 1, y2 - 1)

	local fillX2 = x1 + ((x2 - x1) * pct)
	if fillX2 > x1 + 1 then
		glColor(r, g, b, 1)
		glTexRect(x1 + 1, y1 + 1, fillX2 - 1, y2 - 1)

		if glow then
			local glowSize = (y2 - y1) * 1.8
			glColor(r, g, b, 0.15)
			glTexture(barGlowCenterTexture)
			glTexRect(x1, y1 - glowSize, fillX2, y2 + glowSize)
			glTexture(barGlowEdgeTexture)
			glTexRect(fillX2 + glowSize + glowSize, y1 - glowSize, fillX2, y2 + glowSize)
			glTexture(barTexture)
		end
	end

	glTexture(false)
end

local function FormatSigned(v)
	if v >= 0 then
		return "+" .. string.format("%.1f", v)
	end
	return string.format("%.1f", v)
end

local function GetResourceText(current, storage, income, outgoing, currentColor)
	local net = income - outgoing

	local netStr      = FormatSigned(net)
	local incomeStr   = string.format("%.1f", income)
	local outgoingStr = string.format("%.1f", outgoing)

	if SHOW_NET_FIRST then
		return
		((net >= 0) and green or red) .. netStr ..
				white .. "  (" ..
				green .. "+" .. incomeStr ..
				white .. " / " ..
				red .. "-" .. outgoingStr ..
				white .. ")  " ..
				currentColor .. tostring(math.floor(current + 0.5)) ..
				white .. "/" .. tostring(math.floor(storage + 0.5))
	else
		return
		green .. "+" .. incomeStr ..
				white .. " / " ..
				red .. "-" .. outgoingStr ..
				white .. "  (" ..
				currentColor .. tostring(math.floor(current + 0.5)) ..
				white .. "/" .. tostring(math.floor(storage + 0.5)) ..
				white .. ")"
	end
end

local function UpdateSupplyDisplayCap(supplyMax)
	local targetCap = math.max(SUPPLY_MIN_CAP, roundUpToStep(supplyMax, SUPPLY_STEP))

	if targetCap > supplyDisplayCap then
		supplyDisplayCap = targetCap
		supplyShrinkFrame = spGetGameFrame() + SUPPLY_SHRINK_DELAY
	elseif targetCap < supplyDisplayCap then
		if spGetGameFrame() >= supplyShrinkFrame then
			supplyDisplayCap = targetCap
		end
	else
		supplyShrinkFrame = spGetGameFrame() + SUPPLY_SHRINK_DELAY
	end
end

--------------------------------------------------------------------------------
-- Share level helpers
--------------------------------------------------------------------------------

-- Returns the world-space x1,y1,x2,y2 of the fill bar for metal or energy.
-- Matches the coordinate system used in BuildDynamicList.
local function GetBarWorldRect(resource)
	local barX1 = INNER_PADDING
	local barX2 = BAR_WIDTH - INNER_PADDING
	local barY1 = ROW_TOP_Y + 8
	local barY2 = barY1 + FILL_HEIGHT

	local localX = (resource == "metal") and 0 or COL2_X

	local wx1 = posx + (localX + barX1) * widgetScale
	local wx2 = posx + (localX + barX2) * widgetScale
	local wy1 = posy + barY1 * widgetScale
	local wy2 = posy + barY2 * widgetScale
	return wx1, wy1, wx2, wy2
end

local function DrawShareSlider(resource, shareLevel, dragging)
	local wx1, wy1, wx2, wy2 = GetBarWorldRect(resource)
	local sliderX = wx1 + (wx2 - wx1) * shareLevel

	local hw     = (SLIDER_HANDLE_W * widgetScale) * 0.5
	local hpad   = SLIDER_HANDLE_H * widgetScale
	local lw     = SLIDER_LINE_W * widgetScale * 0.5
	local col    = dragging and SLIDER_DRAG_COLOR or SLIDER_COLOR

	-- vertical marker line through the full bar height
	glColor(col[1], col[2], col[3], col[4])
	glRect(sliderX - lw, wy1, sliderX + lw, wy2)

	-- handle tab (slightly taller than the bar so it's easy to grab)
	glRect(sliderX - hw, wy1 - hpad, sliderX + hw, wy2 + hpad)
end

local function SliderHitTest(x, y, resource, shareLevel)
	local wx1, wy1, wx2, wy2 = GetBarWorldRect(resource)
	local sliderX = wx1 + (wx2 - wx1) * shareLevel
	local hw  = (SLIDER_HANDLE_W * widgetScale) * 0.5
	local hpad = SLIDER_HANDLE_H * widgetScale
	return x >= sliderX - hw and x <= sliderX + hw
			and y >= wy1 - hpad  and y <= wy2 + hpad
end

local function ClampShareLevel(v)
	if v < 0 then return 0 end
	if v > 1 then return 1 end
	return v
end

local function ApplyShareLevel(resource, level)
	spSetShareLevel(resource, level)
end

--------------------------------------------------------------------------------
-- build lists
--------------------------------------------------------------------------------

local function BuildBackgroundList()
	if displayListBg then
		gl.DeleteList(displayListBg)
	end

	displayListBg = gl.CreateList(function()
		glPushMatrix()
		glTranslate(posx, posy, 0)
		glScale(widgetScale, widgetScale, 1)

		-- top row: metal (left), energy (right)
		DrawPanel(0,      ROW_TOP_Y, BAR_WIDTH,          ROW_TOP_Y + BAR_HEIGHT, 0.45, 0.75, 1.00, 0.60) -- metal (sky blue)
		DrawPanel(COL2_X, ROW_TOP_Y, COL2_X + BAR_WIDTH, ROW_TOP_Y + BAR_HEIGHT, 0.95, 0.85, 0.25, 0.60) -- energy (yellow)

		-- bottom row: supply (under metal), research (under energy, narrower, left-aligned)
		DrawPanel(0,      ROW_BOT_Y, BAR_WIDTH,          ROW_BOT_Y + BAR_HEIGHT, 0.30, 0.90, 0.35, 0.60) -- supply (green)
		DrawPanel(COL2_X, ROW_BOT_Y, COL2_X + RP_WIDTH,  ROW_BOT_Y + BAR_HEIGHT, 0.745, 0.470, 1.0, 0.60) -- research (violet)

		glPopMatrix()
	end)
end

local function BuildStaticList()
	if displayListStatic then
		gl.DeleteList(displayListStatic)
	end

	displayListStatic = gl.CreateList(function()
		glPushMatrix()
		glTranslate(posx, posy, 0)
		glScale(widgetScale, widgetScale, 1)

		local blocks = {
			{ x = 0,      y = ROW_TOP_Y, icon = metalTexture,    label = "METAL",    color = {0.45, 0.75, 1.00, 1} }, -- sky blue
			{ x = COL2_X, y = ROW_TOP_Y, icon = energyTexture,   label = "ENERGY",   color = {0.95, 0.85, 0.25, 1} }, -- yellow
			{ x = 0,      y = ROW_BOT_Y, icon = supplyTexture,   label = "SUPPLY",   color = {0.30, 0.90, 0.35, 1} }, -- green
			{ x = COL2_X, y = ROW_BOT_Y, icon = researchTexture, label = "RESEARCH", color = {0.745, 0.470, 1.0, 1} }, -- violet
		}

		font2:Begin()
		for i = 1, #blocks do
			local b = blocks[i]

			glColor(1, 1, 1, 1)
			glTexture(b.icon)
			glTexRect(
					b.x + INNER_PADDING,
					b.y + BAR_HEIGHT - INNER_PADDING - ICON_SIZE,
					b.x + INNER_PADDING + ICON_SIZE,
					b.y + BAR_HEIGHT - INNER_PADDING
			)
			glTexture(false)

			font2:SetTextColor(b.color[1], b.color[2], b.color[3], b.color[4])
			font2:Print(
					b.label,
					b.x + INNER_PADDING + ICON_SIZE + 8,
					b.y + BAR_HEIGHT - 22,
					16,
					"o"
			)
		end
		font2:End()

		glPopMatrix()
	end)
end

local function BuildDynamicList()
	local myTeamID = spGetMyTeamID()
	if not myTeamID then return end

	local supplyUsed = round(spGetTeamRulesParam(myTeamID, "supplyUsed") or 0)
	local supplyMax  = round(spGetTeamRulesParam(myTeamID, "supplyMax") or 0)

	local ec, es, ep, ei, ee = spGetTeamResources(myTeamID, "energy")
	local mc, ms, mp, mi, me = spGetTeamResources(myTeamID, "metal")

	ec, es, ep, ei, ee = ec or 0, es or 1, ep or 0, ei or 0, ee or 0
	mc, ms, mp, mi, me = mc or 0, ms or 1, mp or 0, mi or 0, me or 0

	UpdateSupplyDisplayCap(supplyMax)

	local supplyFree = math.max(0, supplyMax - supplyUsed)
	local supplyPct  = (supplyDisplayCap > 0) and (supplyFree / supplyDisplayCap) or 0
	local metalPct   = (ms > 0) and (mc / ms) or 0
	local energyPct  = (es > 0) and (ec / es) or 0

	-- Quantize everything to DISPLAYED precision before the change check.
	-- Raw resource floats tick every sim frame, so comparing them rebuilt the
	-- display list ~30x/sec; comparing display-precision values only triggers
	-- a rebuild when something visible actually changes.
	mc = math.floor(mc + 0.5) ; ms = math.floor(ms + 0.5)
	ec = math.floor(ec + 0.5) ; es = math.floor(es + 0.5)
	mi = round(mi, 1) ; mp = round(mp, 1)
	ei = round(ei, 1) ; ep = round(ep, 1)
	supplyPct = math.floor(supplyPct * PCT_STEPS) / PCT_STEPS
	metalPct  = math.floor(metalPct  * PCT_STEPS) / PCT_STEPS
	energyPct = math.floor(energyPct * PCT_STEPS) / PCT_STEPS

	-- Only rebuild the list if any displayed value actually changed
	if displayListDynamic
			and lastDynamic.supplyCap == supplyDisplayCap
			and not DynamicValuesChanged(
			supplyUsed, supplyMax, supplyFree, supplyPct,
			mc, ms, mi, mp, metalPct,
			ec, es, ei, ep, energyPct) then
		return
	end

	-- Save values for next comparison
	lastDynamic.supplyCap  = supplyDisplayCap
	lastDynamic.supplyUsed = supplyUsed ; lastDynamic.supplyMax  = supplyMax
	lastDynamic.supplyFree = supplyFree ; lastDynamic.supplyPct  = supplyPct
	lastDynamic.mc = mc ; lastDynamic.ms = ms
	lastDynamic.mi = mi ; lastDynamic.mp = mp ; lastDynamic.metalPct  = metalPct
	lastDynamic.ec = ec ; lastDynamic.es = es
	lastDynamic.ei = ei ; lastDynamic.ep = ep ; lastDynamic.energyPct = energyPct

	if displayListDynamic then gl.DeleteList(displayListDynamic) end

	local supplyR, supplyG, supplyB = 0.30, 0.90, 0.35

	if supplyFree <= 0 then
		supplyR, supplyG, supplyB = 1.0, 0.24, 0.24
	elseif supplyFree <= math.max(5, supplyMax * 0.20) then
		supplyR, supplyG, supplyB = 1.0, 0.65, 0.18
	end

	local metalR, metalG, metalB = 0.74, 0.84, 0.95
	if metalPct > 0.85 then
		metalR, metalG, metalB = 1.0, 0.50, 0.18
	elseif metalPct < 0.20 then
		metalR, metalG, metalB = 1.0, 0.25, 0.25
	end

	local energyR, energyG, energyB = 0.94, 0.84, 0.24
	if energyPct < 0.20 then
		energyR, energyG, energyB = 1.0, 0.25, 0.25
	elseif energyPct > 0.80 then
		energyR, energyG, energyB = 0.35, 0.95, 0.35
	end

	local metalText  = GetResourceText(mc, ms, mi, mp, skyblue)
	local energyText = GetResourceText(ec, es, ei, ep, yellow)
	local supplyText =
	white .. supplyUsed .. "/" .. supplyMax ..
			white .. "  (" ..
			orange .. "free " .. supplyFree ..
			white .. " / " ..
			green .. "scale " .. supplyDisplayCap ..
			white .. ")"

	displayListDynamic = gl.CreateList(function()
		glPushMatrix()
		glTranslate(posx, posy, 0)
		glScale(widgetScale, widgetScale, 1)

		local barX1 = INNER_PADDING
		local barX2 = BAR_WIDTH - INNER_PADDING
		local barY1 = 8
		local barY2 = barY1 + FILL_HEIGHT

		-- metal (top-left), energy (top-right), supply (bottom-left)
		DrawFillBar(barX1,          ROW_TOP_Y + barY1, barX2,          ROW_TOP_Y + barY2, metalPct,  metalR,  metalG,  metalB,  true)
		DrawFillBar(COL2_X + barX1, ROW_TOP_Y + barY1, COL2_X + barX2, ROW_TOP_Y + barY2, energyPct, energyR, energyG, energyB, true)
		DrawFillBar(barX1,          ROW_BOT_Y + barY1, barX2,          ROW_BOT_Y + barY2, supplyPct, supplyR, supplyG, supplyB, true)

		-- single font pass; each Begin/End pair flushes the font renderer
		font2:Begin()
		font2:SetTextColor(1, 1, 1, 1)
		font2:Print(metalText,           BAR_WIDTH - INNER_PADDING, ROW_TOP_Y + 23, 16, "or")
		font2:Print(energyText, COL2_X + BAR_WIDTH - INNER_PADDING, ROW_TOP_Y + 23, 16, "or")
		font2:Print(supplyText,          BAR_WIDTH - INNER_PADDING, ROW_BOT_Y + 23, 16, "or")
		font2:End()

		glPopMatrix()
	end)
end

--------------------------------------------------------------------------------
-- widget api
--------------------------------------------------------------------------------

function widget:Initialize()
	spSendCommands({ "resbar 0" })

	fontfileScale = (0.5 + ((vsx * vsy) / 5700000))
	font = gl.LoadFont(FONT_FILE,  fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength)
	font2 = gl.LoadFont(FONT_FILE2, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength)

	self:ViewResize(vsx, vsy)

	-- Set initial share levels
	ApplyShareLevel("metal",  metalShareLevel)
	ApplyShareLevel("energy", energyShareLevel)
end

function widget:Shutdown()
	if displayListBg then gl.DeleteList(displayListBg) end
	if displayListStatic then gl.DeleteList(displayListStatic) end
	if displayListDynamic then gl.DeleteList(displayListDynamic) end

	if font then gl.DeleteFont(font) end
	if font2 then gl.DeleteFont(font2) end
end

function widget:RecvLuaMsg(msg)
	if msg:sub(1,18) == "LobbyOverlayActive" then
		chobbyInterface = (msg:sub(1,19) == "LobbyOverlayActive1")
	end
end

-- Sample the RP balance once per sim frame, smooth the income rate over a
-- window, and detect spends (only a spend lowers the balance).
local function SampleResearch(dt)
	local myTeamID = spGetMyTeamID()
	if not myTeamID then return end

	local value = spGetTeamRulesParam(myTeamID, "researchPoints") or 0
	rpValue = value

	if rpPrevValue and value < rpPrevValue then
		rpFlashAmount = rpPrevValue - value
		rpFlashTimer  = RP_FLASH_DURATION
		rpFlashStr    = "-" .. tostring(math.floor(rpFlashAmount + 0.5))
	end
	rpPrevValue = value

	local vInt = math.floor(value + 0.5)
	if vInt ~= rpValueInt then
		rpValueInt = vInt
		rpValueStr = tostring(vInt)
	end

	if rpFlashTimer > 0 then
		rpFlashTimer = rpFlashTimer - (dt or 0)
		if rpFlashTimer < 0 then rpFlashTimer = 0 end
	end

	local frame = spGetGameFrame()
	if frame ~= rpLastFrame then
		rpLastFrame = frame
		rpSamples[#rpSamples + 1] = { frame = frame, value = value }
		while #rpSamples > 1 and (frame - rpSamples[1].frame) > RP_RATE_WINDOW do
			table.remove(rpSamples, 1)
		end
		local first = rpSamples[1]
		local span  = frame - first.frame
		if span > 0 then
			rpSmoothedRate = (value - first.value) / (span / 30)
		else
			rpSmoothedRate = 0
		end

		local rateR = round(rpSmoothedRate, 1)
		if rateR ~= rpRateRounded then
			rpRateRounded = rateR
			rpRateStr = string.format("+%.1f/s", rateR)
		end
	end
end

-- Immediate-mode RP panel content: big total (bottom-right), smoothed income
-- (bottom-left), and the fading spend flash (top-right). No fill bar.
-- Lives in the bottom-right column, left-aligned under the energy panel.
local function DrawResearchPanel()
	local rpX = COL2_X

	glPushMatrix()
	glTranslate(posx, posy, 0)
	glScale(widgetScale, widgetScale, 1)

	font2:Begin()

	font2:SetTextColor(1, 1, 1, 1)
	font2:Print(rpValueStr, rpX + RP_WIDTH - INNER_PADDING, 10, 22, "or")

	font2:SetTextColor(0, 1, 0, 1)
	font2:Print(rpRateStr, rpX + INNER_PADDING, 12, 14, "o")

	if rpFlashTimer > 0 and rpFlashAmount > 0 then
		local a = rpFlashTimer / RP_FLASH_DURATION
		font2:SetTextColor(1, 0.15, 0.15, a)
		font2:Print(rpFlashStr, rpX + RP_WIDTH - INNER_PADDING, 30, 16, "or")
	end

	font2:End()
	glPopMatrix()
end

local opacityCheckTimer = 0

function widget:Update(dt)
	-- config reads aren't free; poll ui_opacity twice a second, not per frame
	opacityCheckTimer = opacityCheckTimer + (dt or 0)
	if opacityCheckTimer >= 0.5 then
		opacityCheckTimer = 0
		local newOpacity = GetUIOpacity()
		if newOpacity ~= ui_opacity then
			ui_opacity = newOpacity
			BuildBackgroundList()
		end
	end
	SampleResearch(dt)
end

function widget:IsAbove(x, y)
	if SliderHitTest(x, y, "metal",  metalShareLevel)  then return true end
	if SliderHitTest(x, y, "energy", energyShareLevel) then return true end
	return false
end

function widget:MousePress(x, y, button)
	if button ~= 1 then return false end
	if SliderHitTest(x, y, "metal",  metalShareLevel)  then draggingMetal  = true ; return true end
	if SliderHitTest(x, y, "energy", energyShareLevel) then draggingEnergy = true ; return true end
	return false
end

function widget:MouseMove(x, y, dx, dy, button)
	if draggingMetal then
		local wx1, _, wx2 = GetBarWorldRect("metal")
		metalShareLevel = ClampShareLevel((x - wx1) / (wx2 - wx1))
		ApplyShareLevel("metal", metalShareLevel)
		return true
	end
	if draggingEnergy then
		local wx1, _, wx2 = GetBarWorldRect("energy")
		energyShareLevel = ClampShareLevel((x - wx1) / (wx2 - wx1))
		ApplyShareLevel("energy", energyShareLevel)
		return true
	end
end

function widget:MouseRelease(x, y, button)
	if draggingMetal or draggingEnergy then
		draggingMetal  = false
		draggingEnergy = false
		return true
	end
	return false
end

function widget:DrawScreen()
	if chobbyInterface then return end
	if spGetSpectatingState() then
		-- draw it for spectators too; remove this if you want it hidden
	end

	if not displayListBg then BuildBackgroundList() end
	if not displayListStatic then BuildStaticList() end

	-- resources only change on sim frames; skip sampling and the change
	-- check entirely on intermediate draw frames
	local frame = spGetGameFrame()
	if frame ~= lastBuildFrame or not displayListDynamic then
		lastBuildFrame = frame
		BuildDynamicList()
	end

	glCallList(displayListBg)
	glCallList(displayListStatic)
	if displayListDynamic then glCallList(displayListDynamic) end

	-- research panel content is immediate-mode: the number counts constantly,
	-- so it must not live in the cached dynamic list.
	DrawResearchPanel()

	-- Share level sliders — drawn immediate mode on top of everything
	DrawShareSlider("metal",  metalShareLevel,  draggingMetal)
	DrawShareSlider("energy", energyShareLevel, draggingEnergy)
end

function widget:ViewResize(newX, newY)
	vsx, vsy = newX, newY

	widgetScale = 0.82 + ((vsx * vsy) / 10000000)
	width = (BAR_WIDTH * 2) + BAR_GAP
	height = (BAR_HEIGHT * 2) + ROW_GAP

	posx = math.floor((vsx - (width * widgetScale)) * 0.5)
	posy = math.floor(vsy - (height * widgetScale) - TOP_MARGIN)

	local newFontfileScale = (0.5 + ((vsx * vsy) / 5700000))
	if fontfileScale ~= newFontfileScale then
		fontfileScale = newFontfileScale
		if font then gl.DeleteFont(font) end
		if font2 then gl.DeleteFont(font2) end
		font = gl.LoadFont(FONT_FILE,  fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength)
		font2 = gl.LoadFont(FONT_FILE2, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength)
	end

	-- Force the dynamic list to rebuild on the next draw so the fill bars
	-- reposition themselves to match the new scale/offset. Without this,
	-- BuildDynamicList() skips the rebuild when resource values haven't
	-- changed, leaving the bars detached from the panels at the new resolution.
	if displayListDynamic then
		gl.DeleteList(displayListDynamic)
		displayListDynamic = nil
	end
	lastDynamic = {}

	BuildBackgroundList()
	BuildStaticList()
end