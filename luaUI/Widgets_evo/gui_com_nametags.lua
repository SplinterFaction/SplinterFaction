function widget:GetInfo()
  return {
    name      = "Commander Name Tags",
    desc      = "Displays a name tags above commanders.",
    author    = "Bluestone, Floris",
    date      = "20 february 2015",
    license   = "GNU GPL, v2 or later",
    layer     = -2,
    enabled   = true,  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
-- config
--------------------------------------------------------------------------------

local drawForIcon           = true      -- note that commander icon still gets drawn on top of the name
local nameScaling			= true
local useThickLeterring		= true
local heightOffset			= 50
local fontSize				= 15		-- not real fontsize, it will be scaled
local scaleFontAmount		= 120
local fontShadow			= true		-- only shows if font has a white outline
local shadowOpacity			= 0.35

local fontfile = LUAUI_DIRNAME .. "fonts/" .. Spring.GetConfigString("ui_font2", "JosefinSans-Bold.ttf")
local vsx,vsy = Spring.GetViewGeometry()
local fontfileScale = (0.5 + (vsx*vsy / 5700000))
local fontfileSize = 50
local fontfileOutlineSize = 10
local fontfileOutlineStrength = 10
local font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)
local shadowFont = gl.LoadFont(fontfile, fontfileSize*fontfileScale, 35*fontfileScale, 1.6)
local fontfileScale2 = fontfileScale * 0.66
local fonticon = gl.LoadFont(fontfile, fontfileSize*fontfileScale2, fontfileOutlineSize*fontfileScale2, fontfileOutlineStrength*0.33)

local singleTeams = false
if #Spring.GetTeamList()-1  ==  #Spring.GetAllyTeamList()-1 then
    singleTeams = true
end

local spec = Spring.GetSpectatingState()

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local GetUnitTeam        		= Spring.GetUnitTeam
local GetPlayerInfo      		= Spring.GetPlayerInfo
local GetPlayerList    		    = Spring.GetPlayerList
local GetTeamColor       		= Spring.GetTeamColor
local GetUnitDefID       		= Spring.GetUnitDefID
local GetAllUnits        		= Spring.GetAllUnits
local IsUnitInView	 	 		= Spring.IsUnitInView
local GetCameraPosition  		= Spring.GetCameraPosition
local GetUnitPosition    		= Spring.GetUnitPosition

local glDepthTest        		= gl.DepthTest
local glAlphaTest        		= gl.AlphaTest
local glColor            		= gl.Color
local glTranslate        		= gl.Translate
local glBillboard        		= gl.Billboard
local glDrawFuncAtUnit   		= gl.DrawFuncAtUnit
local GL_GREATER     	 		= GL.GREATER
local GL_SRC_ALPHA				= GL.SRC_ALPHA	
local GL_ONE_MINUS_SRC_ALPHA	= GL.ONE_MINUS_SRC_ALPHA
local glBlending          		= gl.Blending
local glScale          			= gl.Scale

local glCallList				= gl.CallList

local diag						= math.diag

--------------------------------------------------------------------------------

local comms = {}
local comnameList = {}
local comnameIconList = {}
local drawScreenUnits = {}
local CheckedForSpec = false
local myTeamID = Spring.GetMyTeamID()
local myPlayerID = Spring.GetMyPlayerID()

local comDefs = {}
for unitDefID, defs in pairs(UnitDefs) do
	--For some reason spring throws errors if I write these statements in short form, so here I am being overly specific
    if defs.customParams.iscommander and defs.customParams.shownametag == false then
			
	elseif defs.customParams.iscommander and defs.customParams.shownametag == nil or defs.customParams.iscommander and defs.customParams.shownametag == true then
		comDefs[unitDefID] = true
	end
end

local sameTeamColors = false
if WG['playercolorpalette'] ~= nil and WG['playercolorpalette'].getSameTeamColors ~= nil then
    sameTeamColors = WG['playercolorpalette'].getSameTeamColors()
end

--------------------------------------------------------------------------------

--gets the name, color, and height of the commander
local function GetCommAttributes(unitID, unitDefID)
  local team = GetUnitTeam(unitID)
  if team == nil then
    return nil
  end

  local name = ''
  if Spring.GetGameRulesParam('ainame_'..team) then
      name = Spring.GetGameRulesParam('ainame_'..team)..' (AI)'
  else
    local players = GetPlayerList(team)
    name = (#players>0) and GetPlayerInfo(players[1],false) or '------'
    for _,pID in ipairs(players) do
      local pname,active,isspec = GetPlayerInfo(pID,false)
      if active and not isspec then
        name = pname
        break
      end
    end
  end

  local r, g, b, a = GetTeamColor(team)
  local bgColor = {0,0,0,1}
  if (r + g*1.2 + b*0.4) < 0.8 then  -- try to keep these values the same as the playerlist
	bgColor = {1,1,1,1}
  end
  
  local height = UnitDefs[unitDefID].height + heightOffset
  return {name, {r, g, b, a}, height, bgColor}
end

local function RemoveLists()
    for name, list in pairs(comnameList) do
        gl.DeleteList(comnameList[name])
    end
    for name, list in pairs(comnameIconList) do
        gl.DeleteList(comnameIconList[name])
    end
    comnameList = {}
    comnameIconList = {}
end

local function createComnameList(attributes)
    if comnameList[attributes[1]] ~= nil then
        gl.DeleteList(comnameList[attributes[1]])
    end
	comnameList[attributes[1]] = gl.CreateList( function()
		local outlineColor = {0,0,0,1}
		if (attributes[2][1] + attributes[2][2]*1.2 + attributes[2][3]*0.4) < 0.8 then  -- try to keep these values the same as the playerlist
			outlineColor = {1,1,1,1}
		end
		if useThickLeterring then
			if outlineColor[1] == 1 and fontShadow then
			  glTranslate(0, -(fontSize/44), 0)
			  shadowFont:Begin()
			  shadowFont:SetTextColor({0,0,0,shadowOpacity})
			  shadowFont:SetOutlineColor({0,0,0,shadowOpacity})
			  shadowFont:Print(attributes[1], 0, 0, fontSize, "con")
			  shadowFont:End()
			  glTranslate(0, (fontSize/44), 0)
			end
			font:SetTextColor(outlineColor)
			font:SetOutlineColor(outlineColor)
			
			font:Print(attributes[1], -(fontSize/38), -(fontSize/33), fontSize, "con")
			font:Print(attributes[1], (fontSize/38), -(fontSize/33), fontSize, "con")
		end
		font:Begin()
		font:SetTextColor(attributes[2])
		font:SetOutlineColor(outlineColor)
		font:Print(attributes[1], 0, 0, fontSize, "con")
		font:End()
	end)
end

local sec = 0
function widget:Update(dt)
    sec = sec + dt
    if WG['playercolorpalette'] ~= nil then
        if WG['playercolorpalette'].getSameTeamColors and sameTeamColors ~= WG['playercolorpalette'].getSameTeamColors() then
            sameTeamColors = WG['playercolorpalette'].getSameTeamColors()
            RemoveLists()
            CheckAllComs()
            sec = 0
        end
    elseif sameTeamColors == true then
        sameTeamColors = false
        RemoveLists()
        CheckAllComs()
        sec = 0
    end
    if not singleTeams and WG['playercolorpalette'] ~= nil and WG['playercolorpalette'].getSameTeamColors() then
        if myTeamID ~= Spring.GetMyTeamID() then
            -- old
            local name = GetPlayerInfo(select(2,Spring.GetTeamInfo(myTeamID,false)),false)
            if comnameList[name] ~= nil then
                gl.DeleteList(comnameList[name])
                comnameList[name] = nil
            end
            -- new
            myTeamID = Spring.GetMyTeamID()
            myPlayerID = Spring.GetMyPlayerID()
            name = GetPlayerInfo(select(2,Spring.GetTeamInfo(myTeamID,false)),false)
            if comnameList[name] ~= nil then
                gl.DeleteList(comnameList[name])
                comnameList[name] = nil
            end
            CheckAllComs()
            sec = 0
        end
    end
    if not spec and sec > 1.5 then
        sec = 0
        CheckAllComs()
    end
end

local function DrawName(attributes)
	if comnameList[attributes[1]] == nil then
		createComnameList(attributes)
	end
	glTranslate(0, attributes[3], 0)
	glBillboard()
	if nameScaling then
		glScale(usedFontSize/fontSize,usedFontSize/fontSize,usedFontSize/fontSize)
	end
	glCallList(comnameList[attributes[1]])

	if nameScaling then
		glScale(1,1,1)
	end
end

function widget:ViewResize()
  vsx,vsy = Spring.GetViewGeometry()

    local newFontfileScale = (0.5 + (vsx*vsy / 5700000))
    if (fontfileScale ~= newFontfileScale) then
        RemoveLists()
        CheckAllComs()
        fontfileScale = newFontfileScale
        fontfileScale2 = fontfileScale * 0.66
        font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)
        shadowFont = gl.LoadFont(fontfile, fontfileSize*fontfileScale, 35*fontfileScale, 1.6)
        fonticon = gl.LoadFont(fontfile, fontfileSize*fontfileScale2, fontfileOutlineSize*fontfileScale2, fontfileOutlineStrength*0.33)
    end
end

local function createComnameIconList(unitID, attributes)
    if comnameIconList[attributes[1]] ~= nil then
        gl.DeleteList(comnameIconList[attributes[1]])
    end
    comnameIconList[attributes[1]] = gl.CreateList( function()
        local x,y,z = GetUnitPosition(unitID)
        x,z = Spring.WorldToScreenCoords(x, y, z)

        local outlineColor = {0,0,0,1}
        if (attributes[2][1] + attributes[2][2]*1.2 + attributes[2][3]*0.4) < 0.8 then  -- try to keep these values the same as the playerlist
            outlineColor = {1,1,1,1}
        end
        fonticon:Begin()
        fonticon:SetTextColor(attributes[2])
        fonticon:SetOutlineColor(outlineColor)
        fonticon:Print(attributes[1], 0, 0, fontSize*1.9, "con")
        fonticon:End()
    end)
end

function widget:DrawScreenEffects()     -- using DrawScreenEffects so that guishader will blur it when needed
    if Spring.IsGUIHidden() then return end

    for unitID, attributes in pairs(drawScreenUnits) do
        if not comnameIconList[attributes[1]] then
            createComnameIconList(unitID, attributes)
        end
        local x,y,z = GetUnitPosition(unitID)
        x,z = Spring.WorldToScreenCoords(x, y+50+heightOffset, z)
        local scale = 1-(attributes[5]/25000)
        if scale < 0.5 then scale = 0.5 end
        gl.PushMatrix()
        gl.Translate(x,z,0)
        gl.Scale(scale,scale,scale)
        gl.CallList(comnameIconList[attributes[1]])
        gl.PopMatrix()
    end
    drawScreenUnits = {}
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawWorld()
	if chobbyInterface then return end
  if Spring.IsGUIHidden() then return end
  -- untested fix: when you resign, to also show enemy com playernames  (because widget:PlayerChanged() isnt called anymore)
  if not CheckedForSpec and Spring.GetGameFrame() > 1 then
	  if spec then
		CheckedForSpec = true
		CheckAllComs()
	  end
  end
  
  glDepthTest(true)
  glAlphaTest(GL_GREATER, 0)
  glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
   
  local camX, camY, camZ = GetCameraPosition()

  for unitID, attributes in pairs(comms) do
    
    -- calc opacity
	if IsUnitInView(unitID) then
		local x,y,z = GetUnitPosition(unitID)
		camDistance = diag(camX-x, camY-y, camZ-z) 

	    if drawForIcon and Spring.IsUnitIcon(unitID) then
            attributes[5] = camDistance
            drawScreenUnits[unitID] = attributes
        else
            usedFontSize = (fontSize*0.5) + (camDistance/scaleFontAmount)
		    glDrawFuncAtUnit(unitID, false, DrawName, attributes)
        end
	end
  end
  
  glAlphaTest(false)
  glColor(1,1,1,1)
  glDepthTest(false)
end

--------------------------------------------------------------------------------



function CheckCom(unitID, unitDefID, unitTeam)
    if comDefs[unitDefID] then
      comms[unitID] = GetCommAttributes(unitID, unitDefID)
  end
end

function CheckAllComs()
  local allUnits = GetAllUnits()
  for _, unitID in pairs(allUnits) do
    local unitDefID = GetUnitDefID(unitID)
    if comDefs[unitDefID] then
      comms[unitID] = GetCommAttributes(unitID, unitDefID)
    end
  end
end

function widget:Initialize()
    WG['nametags'] = {}
    WG['nametags'].getDrawForIcon = function()
        return drawForIcon
    end
    WG['nametags'].setDrawForIcon = function(value)
        drawForIcon = value
    end
    CheckAllComs()
end

function widget:Shutdown()
    RemoveLists()
    gl.DeleteFont(font)
end

function widget:PlayerChanged(playerID)
  spec = Spring.GetSpectatingState()
  local name,_ = GetPlayerInfo(playerID,false)
  comnameList[name] = nil
  CheckAllComs() -- handle substitutions, etc
end
    
function widget:UnitCreated(unitID, unitDefID, unitTeam)
  CheckCom(unitID, unitDefID, unitTeam)
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
  comms[unitID] = nil

    if comnameIconList[unitID] then
        gl.DeleteList(comnameIconList[unitID])
        comnameIconList[unitID] = nil
    end
end

function widget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
  CheckCom(unitID, unitDefID, unitTeam)
    if comnameIconList[unitID] then
        gl.DeleteList(comnameIconList[unitID])
        comnameIconList[unitID] = nil
    end
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
  CheckCom(unitID, unitDefID, unitTeam)
    if comnameIconList[unitID] then
        gl.DeleteList(comnameIconList[unitID])
        comnameIconList[unitID] = nil
    end
end

function widget:UnitEnteredLos(unitID, unitDefID, unitTeam)
  CheckCom(unitID, unitDefID, unitTeam)
end


function toggleNameScaling()
	nameScaling = not nameScaling
end

function widget:GetConfigData()
    return {
        nameScaling = nameScaling,
        drawForIcon = drawForIcon
    }
end

function widget:SetConfigData(data) --load config
	widgetHandler:AddAction("comnamescale", toggleNameScaling)
    if data.nameScaling ~= nil then
        nameScaling = data.nameScaling
    end
    if data.drawForIcon ~= nil then
        drawForIcon = data.drawForIcon
    end
end
