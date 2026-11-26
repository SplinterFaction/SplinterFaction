function widget:GetInfo()
	return {
		name    = "Minimap Click Move",
		desc    = "With nothing selected, a left click on the minimap centres the view there",
		author  = "ForbodingAngel, Claude",
		date    = "2026-11-26",
		license = "GNU GPL, v2 or later",
		layer   = -10, -- before anything that would take the click for itself
		enabled = true,
	}
end

--------------------------------------------------------------------------------
--
--  Left click on the minimap, nothing selected and no command being given:
--  the camera goes to that spot. Keep the button down and drag, and it follows.
--
--  With units selected the click is the engine's as ever (select, or give the
--  active command on the minimap). Before the game starts it is left alone
--  too: the minimap is then used to pick a start spot.
--
--------------------------------------------------------------------------------

local MOVE_TIME = 0.2   -- seconds the camera takes to get there on the click
local DRAG_TIME = 0.04  -- ... and while dragging

local spGetMiniMapGeometry   = Spring.GetMiniMapGeometry
local spGetSelectedUnitsCount = Spring.GetSelectedUnitsCount
local spGetActiveCommand     = Spring.GetActiveCommand
local spGetGroundHeight      = Spring.GetGroundHeight
local spSetCameraTarget      = Spring.SetCameraTarget

local mapX, mapZ = Game.mapSizeX, Game.mapSizeZ
local dragging = false

-- The spot on the map under a point of the screen, if that point is on the
-- minimap. Follows the minimap when it is turned (quarter turns).
local function MapSpot(x, y)
	local px, py, sx, sy, minimized, maximized = spGetMiniMapGeometry()
	if not px or minimized or maximized or sx <= 0 or sy <= 0 then
		return nil
	end
	local u, v = (x - px) / sx, 1 - (y - py) / sy -- 0..1 across, 0..1 down
	if u < 0 or u > 1 or v < 0 or v > 1 then
		return nil
	end
	local turns = 0
	if Spring.GetMiniMapRotation then
		turns = math.floor((Spring.GetMiniMapRotation() or 0) / (math.pi / 2) + 0.5) % 4
	end
	if turns == 1 then
		u, v = 1 - v, u
	elseif turns == 2 then
		u, v = 1 - u, 1 - v
	elseif turns == 3 then
		u, v = v, 1 - u
	end
	local wx, wz = u * mapX, v * mapZ
	return wx, spGetGroundHeight(wx, wz), wz
end

function widget:MousePress(x, y, button)
	dragging = false
	if button ~= 1 or Spring.IsGUIHidden() or Spring.GetGameFrame() <= 0 then
		return false
	end
	if spGetSelectedUnitsCount() > 0 then
		return false
	end
	local _, cmdID = spGetActiveCommand()
	if cmdID then
		return false
	end
	local wx, wy, wz = MapSpot(x, y)
	if not wx then
		return false
	end
	spSetCameraTarget(wx, wy, wz, MOVE_TIME)
	dragging = true
	return true -- ours: the engine does not start a selection box on the minimap
end

function widget:MouseMove(x, y)
	if dragging then
		local wx, wy, wz = MapSpot(x, y)
		if wx then
			spSetCameraTarget(wx, wy, wz, DRAG_TIME)
		end
	end
end

function widget:MouseRelease()
	dragging = false
	return false
end
