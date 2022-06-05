function widget:GetInfo()
  return {
    name      = "Custom Unit Rings",
    desc      = "Draws rings based upon customparams",
    author    = "Original - CarRepairer, Revamped - Regret, This Version - Niobium",
    date      = "04/05/2012",
    license   = "Public Domain",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

--[[Comments section (using block style comment for attention getter...ness]]--

--[[

	You can have as many rings as you like.
		
		color = {0.5,0,1,0.3}, --R,G,B,A on a scale from 0 - 1. A is the opacity with 1 being fully opaque to 0 being fully transparent. Easy and quick color picker here: http://www.dematte.at/colorPicker/  Take 255 divided by the color value you want, and that is it's value on a scale from 0 - 1. 
			 
		radius = 500, --How large of a radius the ring will cover.

		linewidth = 1, --1 is basically 1 pixel thick. It will scale as you zoom in and out. Maximum value seems to be 32.
            
]]--

local ringsDefs = {
	[UnitDefNames.healstation.id] = {
        --{ color = {1,0.5,0,0.8}, lineWidth = 2, radius = 800 },
        --{ color = {0.5,0,1,0.2}, lineWidth = 5, radius = 500 },
		{ color = {0,1,0,0.6}, lineWidth = 10, radius = 500, divs = 128 },
    },
	
	-- Shield Units
	[UnitDefNames.ekmar.id] = {
        { color = {0, 0, 1, 0.5}, lineWidth = 5, radius = 750 },
    },
}

local ringedUnits = {}

function widget:Initialize()
    for _, uId in pairs(Spring.GetAllUnits()) do
        widget:UnitEnteredLos(uId)
    end
end

function widget:UnitEnteredLos(uId)
    local uDefId = Spring.GetUnitDefID(uId)
    if uDefId then
        widget:UnitCreated(uId, uDefId)
    end
end

function widget:UnitCreated(uId, uDefId)
    local rings = ringsDefs[uDefId]
    if rings then
        ringedUnits[uId] = rings
    end
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawWorldPreUnit()
	if chobbyInterface then return end
	if Spring.IsGUIHidden() then return end
    for uId, rings in pairs(ringedUnits) do
		if (Spring.IsUnitAllied(uId)and Spring.IsUnitSelected(uId)) then
			local ux, uy, uz = Spring.GetUnitPosition(uId)
			if ux then
				for _, ring in pairs(rings) do
					gl.Color(ring.color)
					gl.LineWidth(ring.lineWidth or 1)
					gl.DrawGroundCircle(ux, uy, uz, ring.radius, ring.divs or 32)
				end
			else
				ringedUnits[uId] = nil
			end
		end
	end
    
    gl.LineWidth(1)
    gl.Color(1, 1, 1, 1)
end