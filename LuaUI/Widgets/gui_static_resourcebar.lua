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

local TOP_MARGIN       = 8
local SUPPLY_MIN_CAP   = 50       -- minimum visual supply scale
local SUPPLY_STEP      = 10       -- rounds display cap up to this
local SUPPLY_SHRINK_DELAY = 90    -- frames before shrinking display cap

local SHOW_NET_FIRST   = true     -- "net  (+in / -out)" layout

--------------------------------------------------------------------------------
-- locals
--------------------------------------------------------------------------------

local spGetViewGeometry    = Spring.GetViewGeometry
local spGetMyTeamID        = Spring.GetMyTeamID
local spGetTeamResources   = Spring.GetTeamResources
local spGetTeamRulesParam  = Spring.GetTeamRulesParam
local spGetSpectatingState = Spring.GetSpectatingState
local spSendCommands       = Spring.SendCommands
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

local vsx, vsy = spGetViewGeometry()
local widgetScale = 1
local posx, posy = 0, 0
local width = (BAR_WIDTH * 3) + (BAR_GAP * 2)
local height = BAR_HEIGHT

local fontfileScale = 1
local fontfileSize = 23
local fontfileOutlineSize = 6
local fontfileOutlineStrength = 1.33
local font
local font2

local displayListBg
local displayListStatic
local displayListDynamic

local bgcorner = ":n:" .. LUAUI_DIRNAME .. "Images/bgcorner.png"
local supplyTexture = LUAUI_DIRNAME .. "Images/supply.png"
local energyTexture = LUAUI_DIRNAME .. "Images/energy2.png"
local metalTexture  = LUAUI_DIRNAME .. "Images/metal.png"

local barTexture = LUAUI_DIRNAME .. "Images/resbar.dds"
local barGlowCenterTexture = LUAUI_DIRNAME .. "Images/barglow-center.dds"
local barGlowEdgeTexture   = LUAUI_DIRNAME .. "Images/barglow-edge.dds"

local white    = "\255\255\255\255"
local green    = "\255\0\255\1"
local red      = "\255\255\0\1"
local orange   = "\255\255\135\1"
local yellow   = "\255\255\255\1"
local skyblue  = "\255\136\197\226"

local supplyDisplayCap = SUPPLY_MIN_CAP
local supplyShrinkFrame = 0
local chobbyInterface = false

-- Last values used to build the dynamic list. The list is only rebuilt when
-- any of these change, instead of every frame.
local lastDynamic = {}

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
	glColor(accentR, accentG, accentB, accentA)
	RectRound(x1 + 2, y2 - 5, x2 - 2, y2 - 2, 3)
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

		local x = 0
		local y = 0

		-- supply (green)
		DrawPanel(x, y, x + BAR_WIDTH, y + BAR_HEIGHT, 0.30, 0.90, 0.35, 0.60)

		-- metal (sky blue)
		x = x + BAR_WIDTH + BAR_GAP
		DrawPanel(x, y, x + BAR_WIDTH, y + BAR_HEIGHT, 0.45, 0.75, 1.00, 0.60)

		-- energy (yellow)
		x = x + BAR_WIDTH + BAR_GAP
		DrawPanel(x, y, x + BAR_WIDTH, y + BAR_HEIGHT, 0.95, 0.85, 0.25, 0.60)

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
			{ x = 0,                         icon = supplyTexture, label = "SUPPLY", color = {0.30, 0.90, 0.35, 1} }, -- green
			{ x = BAR_WIDTH + BAR_GAP,       icon = metalTexture,  label = "METAL",  color = {0.45, 0.75, 1.00, 1} }, -- sky blue
			{ x = (BAR_WIDTH + BAR_GAP) * 2, icon = energyTexture, label = "ENERGY", color = {0.95, 0.85, 0.25, 1} }, -- yellow
		}

		font2:Begin()
		for i = 1, #blocks do
			local b = blocks[i]

			glColor(1, 1, 1, 1)
			glTexture(b.icon)
			glTexRect(
					b.x + INNER_PADDING,
					BAR_HEIGHT - INNER_PADDING - ICON_SIZE,
					b.x + INNER_PADDING + ICON_SIZE,
					BAR_HEIGHT - INNER_PADDING
			)
			glTexture(false)

			font2:SetTextColor(b.color[1], b.color[2], b.color[3], b.color[4])
			font2:Print(
					b.label,
					b.x + INNER_PADDING + ICON_SIZE + 8,
					BAR_HEIGHT - 22,
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

	-- Only rebuild the list if any value actually changed
	if displayListDynamic and not DynamicValuesChanged(
			supplyUsed, supplyMax, supplyFree, supplyPct,
			mc, ms, mi, mp, metalPct,
			ec, es, ei, ep, energyPct) then
		return
	end

	-- Save values for next-frame comparison
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

	displayListDynamic = gl.CreateList(function()
		glPushMatrix()
		glTranslate(posx, posy, 0)
		glScale(widgetScale, widgetScale, 1)

		local textXPad = INNER_PADDING + ICON_SIZE + 8
		local barX1 = INNER_PADDING
		local barX2 = BAR_WIDTH - INNER_PADDING
		local barY1 = 8
		local barY2 = barY1 + FILL_HEIGHT

		-- supply
		do
			local x = 0
			DrawFillBar(x + barX1, barY1, x + barX2, barY2, supplyPct, supplyR, supplyG, supplyB, true)

			local supplyText =
			white .. supplyUsed .. "/" .. supplyMax ..
					white .. "  (" ..
					orange .. "free " .. supplyFree ..
					white .. " / " ..
					green .. "scale " .. supplyDisplayCap ..
					white .. ")"

			font2:Begin()
			font2:SetTextColor(1,1,1,1)
			font2:Print(supplyText, x + BAR_WIDTH - INNER_PADDING, 23, 16, "or")
			font2:End()
		end

		-- metal
		do
			local x = BAR_WIDTH + BAR_GAP
			DrawFillBar(x + barX1, barY1, x + barX2, barY2, metalPct, metalR, metalG, metalB, true)

			local metalText = GetResourceText(mc, ms, mi, mp, skyblue)
			font2:Begin()
			font2:SetTextColor(1,1,1,1)
			font2:Print(metalText, x + BAR_WIDTH - INNER_PADDING, 23, 16, "or")
			font2:End()
		end

		-- energy
		do
			local x = (BAR_WIDTH + BAR_GAP) * 2
			DrawFillBar(x + barX1, barY1, x + barX2, barY2, energyPct, energyR, energyG, energyB, true)

			local energyText = GetResourceText(ec, es, ei, ep, yellow)
			font2:Begin()
			font2:SetTextColor(1,1,1,1)
			font2:Print(energyText, x + BAR_WIDTH - INNER_PADDING, 23, 16, "or")
			font2:End()
		end

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

function widget:Update(dt)
	local newOpacity = GetUIOpacity()
	if newOpacity ~= ui_opacity then
		ui_opacity = newOpacity
		BuildBackgroundList()
	end
end

function widget:DrawScreen()
	if chobbyInterface then return end
	if spGetSpectatingState() then
		-- draw it for spectators too; remove this if you want it hidden
	end

	if not displayListBg then BuildBackgroundList() end
	if not displayListStatic then BuildStaticList() end
	BuildDynamicList()

	glCallList(displayListBg)
	glCallList(displayListStatic)
	glCallList(displayListDynamic)
end

function widget:ViewResize(newX, newY)
	vsx, vsy = newX, newY

	widgetScale = 0.82 + ((vsx * vsy) / 10000000)
	width = (BAR_WIDTH * 3) + (BAR_GAP * 2)
	height = BAR_HEIGHT

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