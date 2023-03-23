-- $Id$
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


function widget:GetInfo()
  return {
    name      = "Select n Center!",
    desc      = "Selects and centers the Commander at the start of the game.",
    author    = "quantum and Evil4Zerggin",
    date      = "19 April 2008",
    license   = "GNU GPL, v2 or later",
    layer     = 5,
    enabled   = true  --  loaded by default?
  }
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


local go = true
local unitArray = {}


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


function widget:Update()
  local t = Spring.GetGameSeconds()
  _, _, spectator = Spring.GetPlayerInfo(Spring.GetMyTeamID())
  if (spectator or t > 10) then
    widgetHandler:RemoveWidget()
    return
  end
  if (t > 0) then
    unitArray = Spring.GetTeamUnits(Spring.GetMyTeamID())
    if (go and unitArray[1]) then
      local x, y, z = Spring.GetUnitPosition(unitArray[1])
      -- Spring.SetCameraTarget(x, y, z)
      Spring.SetCameraState({
                              name=spring,
                              mode=2,
                              dist=900,
                              px=x,
                              py=y,
                              pz=z,
                            }, 5) -- It's not documented, but the 5 here is transition time/speed. Internally I think it's referred to as "camTime".
    --  These are the arguments for Spring.SetCameraState() for the spring camera
    --  name, spring
    --  dist, 3150.0271
    --  px, 3171.03955
    --  py, 211.709076
    --  pz, 882.631409
    --  rz, 0
    --  dx, 0
    --  dy, -0.8940042
    --  dz, -0.4480586
    --  fov, 45
    --  ry, 0
    --  mode, 2
    --  rx, 2.67700005
    --  Spring.SelectUnitArray{unitArray[1]}

    go = false
    end
    if (not go) then
      widgetHandler:RemoveWidget()
    end
  end
  --for index,value in pairs(Spring.GetCameraState()) do
  --  Spring.Echo(index,value)
  --end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
