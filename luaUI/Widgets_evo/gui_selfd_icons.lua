function widget:GetInfo()
   return {
      name      = "Self-Destruct icons",
      desc      = "",
      author    = "Floris",
      date      = "06.05.2014",
      license   = "GNU GPL, v2 or later",
      layer     = -50,
      enabled   = true
   }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- preferred to keep these values the same as fancy unit selections widget
local unitConf				= {}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local fontfile = LUAUI_DIRNAME .. "fonts/" .. Spring.GetConfigString("ui_font", "JosefinSans-SemiBold.ttf")
local vsx,vsy = Spring.GetViewGeometry()
local fontfileScale = (0.5 + (vsx*vsy / 5700000))
local fontfileSize = 45
local fontfileOutlineSize = 4.5
local fontfileOutlineStrength = 9
local font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)

local selfdUnits = {}
local drawLists = {}
local glDrawListAtUnit			= gl.DrawListAtUnit

local spIsGUIHidden				= Spring.IsGUIHidden
local spGetUnitDefID			= Spring.GetUnitDefID
local spIsUnitInView 			= Spring.IsUnitInView
local spGetUnitSelfDTime		= Spring.GetUnitSelfDTime
local spGetAllUnits				= Spring.GetAllUnits
local spGetCommandQueue			= Spring.GetCommandQueue
local spIsUnitAllied			= Spring.IsUnitAllied
local spGetCameraDirection		= Spring.GetCameraDirection

local spec = Spring.GetSpectatingState()

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:ViewResize(n_vsx,n_vsy)
	vsx,vsy = Spring.GetViewGeometry()

	local newFontfileScale = (0.5 + (vsx*vsy / 5700000))
	if (fontfileScale ~= newFontfileScale) then
		fontfileScale = newFontfileScale
		font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)
	end
end

function DrawIcon(text)
	local iconSize = 0.9
	gl.PushMatrix()
	gl.Texture(':n:LuaUI/Images/skull.dds')
	gl.Translate(0.32,1,1.4)
	gl.Billboard()
	gl.TexRect(-(iconSize+0.085), 0, -0.08, iconSize)
	font:Begin()
	font:Print(text,0,(iconSize/4),0.66,"oc")
	font:End()
	gl.PopMatrix()
end


function SetUnitConf()
	for udid, unitDef in pairs(UnitDefs) do
		local xsize, zsize = unitDef.xsize, unitDef.zsize
		local scale = 6*( xsize^2 + zsize^2 )^0.5
		unitConf[udid] = 7 +(scale/2.5)
	end
end

--------------------------------------------------------------------------------
-- Engine Calls
--------------------------------------------------------------------------------

function init()
	spec = Spring.GetSpectatingState()
	-- check all units for selfd cmd
	selfdUnits = {}
	local units = spGetAllUnits()
	for _, unitID in ipairs(units) do
		if spGetUnitSelfDTime(unitID) ~= nil then
			if spGetUnitSelfDTime(unitID) > 0 then
				selfdUnits[unitID] = true
			end
			-- check for queued selfd
			local unitQueue = spGetCommandQueue(unitID,20) or {}
			if (#unitQueue > 0) then
				for _,cmd in ipairs(unitQueue) do
					if cmd.id == CMD.SELFD then
						selfdUnits[unitID] = true
					end
				end
			end
		end
	end
end

function widget:PlayerChanged(playerID)
	init()
end

function widget:Initialize()
	SetUnitConf()
	init()
end


function widget:Shutdown()
	for k,_ in pairs(drawLists) do
		gl.DeleteList(drawLists[k])
	end
	gl.DeleteFont(font)
end


local sec = 0
local prevCam = {spGetCameraDirection()}
function widget:Update(dt)
	sec = sec + dt
	if sec > 0.15 then
		sec = 0
		local camX, camY, camZ = spGetCameraDirection()
		if camX ~= prevCam[1] or  camY ~= prevCam[2] or  camZ ~= prevCam[3] then
			for k,_ in pairs(drawLists) do
				gl.DeleteList(drawLists[k])
				drawLists[k] = nil
			end
		end
		prevCam = {camX,camY,camZ}
	end
end

-- draw icons
function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawWorld()
	if chobbyInterface then return end
	if spIsGUIHidden() then return end

	gl.DepthTest(true)
	gl.Color(0.9,0.9,0.9,1)

	local unitScale, countdown
	for unitID, unitDefID in pairs(selfdUnits) do
		if spIsUnitAllied(unitID) or spec then
			if spIsUnitInView(unitID) then
				unitScale = unitConf[unitDefID]
				countdown = math.ceil(spGetUnitSelfDTime(unitID) / 2)
				if not drawLists[countdown] then
					drawLists[countdown] = gl.CreateList(DrawIcon, countdown)
				end
				glDrawListAtUnit(unitID, drawLists[countdown], false, unitScale,unitScale,unitScale)
			end
		else
			selfdUnits[unitID] = nil
		end
	end

	gl.Color(1,1,1,1)
	gl.Texture(false)
	gl.DepthTest(false)
end


function widget:UnitCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)

	-- check for queued selfd (to check if queue gets cancelled)
	if selfdUnits[unitID] then
		local foundSelfdCmd = false
		local unitQueue = spGetCommandQueue(unitID,20) or {}
		if (#unitQueue > 0) then
			for _,cmd in ipairs(unitQueue) do
				if cmd.id == CMD.SELFD then
					foundSelfdCmd = true
					break
				end
			end
		end
		if foundSelfdCmd then
			selfdUnits[unitID] = nil
		end
	end
	
	if cmdID == CMD.SELFD then
		if spGetUnitSelfDTime(unitID) > 0 then  	-- since cmd hasnt been cancelled yet
			selfdUnits[unitID] = nil
		else
			selfdUnits[unitID] = spGetUnitDefID(unitID)
		end
	end
end


function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	
	if selfdUnits[unitID] then  
		selfdUnits[unitID] = nil
	end
end
