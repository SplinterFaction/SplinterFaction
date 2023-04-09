function widget:GetInfo()
	return {
		name = "Chicken Stats Panel",
		desc = "Shows statistics and progress when fighting vs Chickens",
		author = "quantum",
		date = "May 04, 2008",
		license = "GNU GPL, v2 or later",
		layer = -9,
		enabled = true  --  loaded by default?
	}
end

local config = VFS.Include('LuaRules/Configs/chicken_spawn_defs.lua')

local customScale = 1
local widgetScale = customScale
local font, font2, chobbyInterface
local messageArgs, marqueeMessage
local refreshMarqueeMessage = false
local showMarqueeMessage = false

local VOLUI = 0.015*Spring.GetConfigInt('snd_volui') or 1.0

if not Spring.Utilities.Gametype.IsChickens() then
	return false
end

if not Spring.GetGameRulesParam("difficulty") then
	return false
end

local GetGameSeconds = Spring.GetGameSeconds

local displayList
local panelTexture = ":n:LuaUI/Images/chickenpanel.tga"

local panelFontSize = 14
local waveFontSize = 36

local vsx, vsy = Spring.GetViewGeometry()

local fontfile2 = "fonts/" .. Spring.GetConfigString("ui_font2", "josefinsans-semibold.ttf")

local viewSizeX, viewSizeY = 0, 0
local w = 300
local h = 210
local x1 = 0
local y1 = 0
local panelMarginX = 30
local panelMarginY = 40
local panelSpacingY = 7
local waveSpacingY = 7
local moving
local capture
local gameInfo
local waveSpeed = 0.1
local waveCount = 0
local waveTime
local enabled
local gotScore
local scoreCount = 0
local resistancesTable = {}
local currentlyResistantTo = {}

local guiPanel --// a displayList
local updatePanel
local hasChickenEvent = false

local difficultyOption = Spring.GetModOptions().chicken_difficulty

local rules = {
	"queenTime",
	"queenAnger",
	"gracePeriod",
	"queenLife",
	"lagging",
	"difficulty",
	"chickenCount",
	"chickenaCount",
	"chickensCount",
	"chickenfCount",
	"chickenrCount",
	"chickenwCount",
	"chickencCount",
	"chickenpCount",
	"chickenhCount",
	"chicken_turretCount",
	"chicken_dodoCount",
	"chicken_hiveCount",
	"chickenKills",
	"chickenaKills",
	"chickensKills",
	"chickenfKills",
	"chickenrKills",
	"chickenwKills",
	"chickencKills",
	"chickenpKills",
	"chickenhKills",
	"chicken_turretKills",
	"chicken_dodoKills",
	"chicken_hiveKills",
}

local waveColor = "\255\255\0\0"
local textColor = "\255\255\255\255"


local chickenTypes = {
	"chicken",
	"chickena",
	"chickenh",
	"chickens",
	"chickenw",
	"chicken_dodo",
	"chickenp",
	"chickenf",
	"chickenc",
	"chickenr",
	"chicken_turret",
}

local function commaValue(amount)
	local formatted = amount
	local k
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
		if k == 0 then
			break
		end
	end
	return formatted
end

local function getChickenCounts(type)
	local total = 0
	local subtotal

	for _, chickenType in ipairs(chickenTypes) do
		subtotal = gameInfo[chickenType .. type]
		total = total + subtotal
	end

	return total
end

local function updatePos(x, y)
	x1 = math.min((viewSizeX * 0.94) - (w * widgetScale) / 2, x)
	y1 = math.min((viewSizeY * 0.89) - (h * widgetScale) / 2, y)
	updatePanel = true
end

local function PanelRow(n)
	return h - panelMarginY - (n - 1) * (panelFontSize + panelSpacingY)
end

local function WaveRow(n)
	return n * (waveFontSize + waveSpacingY)
end

local function CreatePanelDisplayList()
	gl.PushMatrix()
	gl.Translate(x1, y1, 0)
	gl.Scale(widgetScale, widgetScale, 1)
	gl.CallList(displayList)

	local currentTime = GetGameSeconds()
	local techLevel = ""
	if currentTime > gameInfo.gracePeriod then
		if gameInfo.queenAnger < 100 then
			local gain = 0
			if Spring.GetGameRulesParam("ChickenQueenAngerGain_Base") then
				gain = math.round(Spring.GetGameRulesParam("ChickenQueenAngerGain_Base"), 3) + math.round(Spring.GetGameRulesParam("ChickenQueenAngerGain_Aggression"), 3) + math.round(Spring.GetGameRulesParam("ChickenQueenAngerGain_Eco"), 3)
			end
			techLevel = "Boss Anger: " .. gameInfo.queenAnger .. "% (+" .. gain .. "%/s)"
		else
			techLevel = "Boss Health: " .. gameInfo.queenLife
		end
	else
		techLevel = "Grace Period: " .. math.ceil(((currentTime - gameInfo.gracePeriod) * -1) - 0.5)
	end

	font:Begin()
	font:SetTextColor(1, 1, 1, 1)
	font:SetOutlineColor(0, 0, 0, 1)
	font:Print(techLevel, panelMarginX, PanelRow(1), panelFontSize, "")
	if Spring.GetGameRulesParam("ChickenQueenAngerGain_Base") and gameInfo.queenAnger < 100 and currentTime > gameInfo.gracePeriod then
		font:Print(textColor .. "Base: +" .. math.round(Spring.GetGameRulesParam("ChickenQueenAngerGain_Base"), 3) .. "%/s", panelMarginX+5, PanelRow(2), panelFontSize, "")
		font:Print(textColor .. "Aggression: +" .. math.round(Spring.GetGameRulesParam("ChickenQueenAngerGain_Aggression"), 3) .. "%/s", panelMarginX+5, PanelRow(3), panelFontSize, "")
		--font:Print(textColor .. "Eco: +" .. math.round(Spring.GetGameRulesParam("ChickenQueenAngerGain_Eco"), 3) .. "%/s", panelMarginX+5, PanelRow(4), panelFontSize, "")
	end
	--font:Print('ui.chickens.chickenPlayerAgression' .. (Spring.GetGameRulesParam("chickenPlayerAgressionLevel") or 0), panelMarginX, PanelRow(2), panelFontSize, "")
	--font:Print(Spring.I18N('ui.chickens.chickenCount', { count = gameInfo.chickenCounts }), panelMarginX, PanelRow(2), panelFontSize, "")
	font:Print('Enemies Killed: ' .. gameInfo.chickenKills, panelMarginX, PanelRow(5), panelFontSize, "")
	--font:Print(Spring.I18N('ui.chickens.burrowCount', { count = gameInfo.chicken_hiveCount }), panelMarginX, PanelRow(4), panelFontSize, "")
	--font:Print(Spring.I18N('ui.chickens.burrowKillCount', { count = gameInfo.chicken_hiveKills }), panelMarginX, PanelRow(5), panelFontSize, "")

	-- if gotScore then
	-- 	font:Print('ui.chickens.score', { score = commaValue(scoreCount) }, 88, h - 170, panelFontSize, "")
	-- else
		font:Print('Difficulty: ' .. difficultyOption, 120, h - 170, panelFontSize, "")
	-- end
	font:End()

	gl.Texture(false)
	gl.PopMatrix()
end

local function getMarqueeMessage(chickenEventArgs)
	local messages = {}
	if chickenEventArgs.type == "firstWave" then
		messages[1] = textColor .. "They're here!"
		messages[2] = textColor .. 'Get ready to fight!'
	elseif chickenEventArgs.type == "airWave" then
		messages[1] = textColor .. "Wave " .. chickenEventArgs.waveCount
		messages[2] = textColor .. 'Air Wave!'
		messages[3] = textColor .. chickenEventArgs.number .. ' Units!'
	elseif chickenEventArgs.type == "queen" then
		messages[1] = textColor .. 'The Boss is here!'
		messages[2] = textColor .. 'Get ready to fight!'
		queenIsAngry = true
	elseif chickenEventArgs.type == "wave" then
		messages[1] = textColor .. "Wave " .. chickenEventArgs.waveCount
		messages[2] = textColor .. chickenEventArgs.number .. ' Units!'
	end

	refreshMarqueeMessage = false

	return messages
end

local function getResistancesMessage()
	local messages = {}
	messages[1] = textColor .. 'The Boss is now resistant to:'
	for i = 1,#resistancesTable do
		-- for a, b in pairs(UnitDefs[resistancesTable[i]]) do
		-- 	Spring.Echo(a,b)
		-- end
		local attackerName = UnitDefs[resistancesTable[i]].humanName or UnitDefs[resistancesTable[i]].name
		messages[i+1] = textColor .. " " .. attackerName
	end
	resistancesTable = {}

	refreshMarqueeMessage = false


	return messages
end

local function Draw()
	if not enabled or not gameInfo then
		return
	end

	if updatePanel then
		if (guiPanel) then
			gl.DeleteList(guiPanel);
			guiPanel = nil
		end
		guiPanel = gl.CreateList(CreatePanelDisplayList)
		updatePanel = false
	end

	if guiPanel then
		gl.CallList(guiPanel)
	end

	if showMarqueeMessage then
		local t = Spring.GetTimer()

		local waveY = viewSizeY - Spring.DiffTimers(t, waveTime) * waveSpeed * viewSizeY
		if waveY > 0 then
			if refreshMarqueeMessage or not marqueeMessage then
				marqueeMessage = getMarqueeMessage(messageArgs)
			end

			font2:Begin()
			for i, message in ipairs(marqueeMessage) do
				font2:Print(message, viewSizeX / 2, waveY - WaveRow(i), waveFontSize * widgetScale, "co")
			end
			font2:End()
		else
			showMarqueeMessage = false
			messageArgs = nil
			waveY = viewSizeY
		end
	elseif #resistancesTable > 0 then
		marqueeMessage = getResistancesMessage()
		waveTime = Spring.GetTimer()
		showMarqueeMessage = true
	end
end

local function UpdateRules()
	if not gameInfo then
		gameInfo = {}
	end

	for _, rule in ipairs(rules) do
		gameInfo[rule] = Spring.GetGameRulesParam(rule) or 0
	end
	gameInfo.chickenCounts = getChickenCounts('Count')
	gameInfo.chickenKills = getChickenCounts('Kills')

	updatePanel = true
end

function ChickenEvent(chickenEventArgs)
	if chickenEventArgs.type == "firstWave" or chickenEventArgs.type == "queen" then
		showMarqueeMessage = true
		refreshMarqueeMessage = true
		messageArgs = chickenEventArgs
		waveTime = Spring.GetTimer()
	end

	if chickenEventArgs.type == "queenResistance" then
		if chickenEventArgs.number then
			if not currentlyResistantTo[chickenEventArgs.number] then
				table.insert(resistancesTable, chickenEventArgs.number)
				currentlyResistantTo[chickenEventArgs.number] = true
			end
		end
	end

	if (chickenEventArgs.type == "wave" or chickenEventArgs.type == "airWave") and config.useWaveMsg and (not queenIsAngry) then
		waveCount = waveCount + 1
		chickenEventArgs.waveCount = waveCount
		showMarqueeMessage = true
		refreshMarqueeMessage = true
		messageArgs = chickenEventArgs
		waveTime = Spring.GetTimer()
	end
end

function widget:Initialize()
	widget:ViewResize()

	Spring.PlaySoundFile("sounds/corrupted/briefing.wav", VOLUI)

	displayList = gl.CreateList(function()
		gl.Blending(true)
		gl.Color(1, 1, 1, 1)
		gl.Texture(panelTexture)
		gl.TexRect(0, 0, w, h)
	end)

	widgetHandler:RegisterGlobal("ChickenEvent", ChickenEvent)
	UpdateRules()
	viewSizeX, viewSizeY = gl.GetViewSizes()
	local x = math.abs(math.floor(viewSizeX - 320))
	local y = math.abs(math.floor(viewSizeY - 300))

	-- reposition if scavengers panel is shown as well
	if Spring.Utilities.Gametype.IsScavengers() then
		x = x - 315
	end

	updatePos(x, y)
end

function widget:Shutdown()
	if hasChickenEvent then
		Spring.SendCommands({ "luarules HasChickenEvent 0" })
	end

	if guiPanel then
		gl.DeleteList(guiPanel);
		guiPanel = nil
	end

	gl.DeleteList(displayList)
	gl.DeleteTexture(panelTexture)
	widgetHandler:DeregisterGlobal("ChickenEvent")
end

function widget:GameFrame(n)
	if not hasChickenEvent and n > 1 then
		Spring.SendCommands({ "luarules HasChickenEvent 1" })
		hasChickenEvent = true
	end
	if n % 30 < 1 then
		UpdateRules()
		if not enabled and n > 1 then
			enabled = true
		end
	end
	if gotScore then
		local sDif = gotScore - scoreCount
		if sDif > 0 then
			scoreCount = scoreCount + math.ceil(sDif / 7.654321)
			if scoreCount > gotScore then
				scoreCount = gotScore
			else
				updatePanel = true
			end
		end
	end
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1, 19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawScreen()
	if chobbyInterface then
		return
	end
	Draw()
end

function widget:MouseMove(x, y, dx, dy, button)
	if enabled and moving then
		updatePos(x1 + dx, y1 + dy)
	end
end

function widget:MousePress(x, y, button)
	if enabled and
		x > x1 and x < x1 + (w * widgetScale) and
		y > y1 and y < y1 + (h * widgetScale)
	then
		capture = true
		moving = true
	end
	return capture
end

function widget:MouseRelease(x, y, button)
	if not enabled then
		return
	end
	capture = nil
	moving = nil
	return capture
end

function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()

	font = WG['fonts'].getFont()
	font2 = WG['fonts'].getFont(fontfile2)

	x1 = math.floor(x1 - viewSizeX)
	y1 = math.floor(y1 - viewSizeY)
	viewSizeX, viewSizeY = vsx, vsy
	widgetScale = (0.75 + (viewSizeX * viewSizeY / 10000000)) * customScale
	x1 = viewSizeX + x1 + ((x1 / 2) * (widgetScale - 1))
	y1 = viewSizeY + y1 + ((y1 / 2) * (widgetScale - 1))
end

function widget:LanguageChanged()
	refreshMarqueeMessage = true;
	updatePanel = true;
end
