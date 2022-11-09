  


function widget:GetInfo()
  return {
    name      = "Show All Commands",
    desc      = "Acts like CTRL-A SHIFT all the time",
    author    = "Google Frog",
    date      = "Mar 1, 2009",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = false  --  loaded by default?
  }
end

local spDrawUnitCommands = Spring.DrawUnitCommands
local spGetAllUnits = Spring.GetAllUnits

local drawUnits = {}

function widget:DrawWorld()
 	
  for i, v in pairs(drawUnits) do
    if i then
	  spDrawUnitCommands(i)
    end
  end
  
end

function widget:UnitGiven(unitID)

  drawUnits[unitID] = true

end

function widget:UnitCreated(unitID)

  drawUnits[unitID] = true

end

function widget:UnitDestroyed(unitID)

  if (drawUnits[unitID]) then
    drawUnits[unitID] = nil
  end

end

function widget:GameFrame(n)
  if (n == 1) then
  
    local units = spGetAllUnits()
  
    for i, id in pairs(units) do
      widget:UnitCreated(id)
    end
  end
end

function widget:Initialize()

  local units = spGetAllUnits()
  
  for i, id in pairs(units) do
    widget:UnitCreated(id)
  end

end

