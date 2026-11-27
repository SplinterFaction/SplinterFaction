function widget:GetInfo()
	return {
		name    = "Grab Pan",
		desc    = "Hold the middle mouse button and drag: the map is pulled along under the cursor",
		author  = "ForbodingAngel, Claude",
		date    = "2026-11-26",
		license = "GNU GPL, v2 or later",
		layer   = -20, -- before anything else that would take a middle click
		enabled = true,
	}
end

--------------------------------------------------------------------------------
--
--  Pulling the map around with the middle mouse button.
--
--  The engine's own middle button scroll is a mode: a click toggles it, the
--  cursor is taken to the middle of the screen, and the view then moves at a
--  speed set by how far the mouse is from there. This replaces it with the
--  plain thing: press the middle button and the spot of ground under the
--  cursor is held; move the mouse and that spot comes along, staying under
--  the cursor; let go and it is over. The cursor is free the whole time and
--  shows a grabbing hand (Anims/cursorgrab, drawn by Tools/cursors).
--
--  How: on the press, the ray under the cursor is cut with the level plane at
--  the height of the ground it hit. On every move the ray under the cursor is
--  cut with that same plane again, and the camera is shifted by the difference,
--  which puts the held spot back under the cursor. A level plane, not the
--  terrain, so hills under the cursor do not make the view jump.
--
--  Left alone: a middle click on the minimap, with Ctrl or Alt held (the
--  engine's rotate and tilt), and while the map is being drawn on.
--
--------------------------------------------------------------------------------

local CURSOR_NAME = "grabpan"       -- what the cursor is called once assigned
local CURSOR_FILE = "cursorgrab"    -- Anims/cursorgrab.txt
local MIDDLE = 2
local DRAW_KEY = 96                 -- ` : held, the mouse marks the map

local spGetCameraState    = Spring.GetCameraState
local spSetCameraState    = Spring.SetCameraState
local spGetCameraPosition = Spring.GetCameraPosition
local spGetPixelDir       = Spring.GetPixelDir
local spTraceScreenRay    = Spring.TraceScreenRay
local spSetMouseCursor    = Spring.SetMouseCursor
local spGetModKeyState    = Spring.GetModKeyState

local grab = nil -- {x, y, z}: the spot of ground that is being held

-- where the ray under a point of the screen cuts the level plane at height y
local function OnPlane(mx, my, y)
	local cx, cy, cz = spGetCameraPosition()
	-- GetPixelDir counts y down from the top of the view; the mouse is given from the bottom
	local _, vsy = Spring.GetViewGeometry()
	local dx, dy, dz = spGetPixelDir(mx, vsy - my)
	if not dx or dy >= -0.001 then
		return nil -- looking level or up: the ray never comes down to the plane
	end
	local t = (y - cy) / dy
	if t <= 0 then
		return nil
	end
	return cx + dx * t, cz + dz * t
end

local function Pull(mx, my)
	local x, z = OnPlane(mx, my, grab.y)
	if not x then
		return
	end
	local sx, sz = grab.x - x, grab.z - z
	if sx * sx + sz * sz < 0.01 then
		return
	end
	local state = spGetCameraState()
	if not (state and state.px and state.pz) then
		return
	end
	state.px = state.px + sx
	state.pz = state.pz + sz
	spSetCameraState(state, 0)
end

function widget:Initialize()
	Spring.AssignMouseCursor(CURSOR_NAME, CURSOR_FILE, true, false)
end

function widget:MousePress(mx, my, button)
	grab = nil
	if button ~= MIDDLE or Spring.IsGUIHidden() then
		return false
	end
	local alt, ctrl = spGetModKeyState()
	if alt or ctrl or Spring.GetKeyState(DRAW_KEY) or Spring.IsAboveMiniMap(mx, my) then
		return false
	end
	local kind, pos = spTraceScreenRay(mx, my, true)
	if kind ~= "ground" or not pos then
		return false -- the sky: nothing to hold
	end
	grab = { x = pos[1], y = pos[2], z = pos[3] }
	return true -- ours: the engine does not start its own scroll mode
end

function widget:MouseMove(mx, my, dx, dy, button)
	if grab then
		Pull(mx, my)
	end
end

function widget:MouseRelease(mx, my, button)
	grab = nil
	return false
end

function widget:Update()
	if grab then
		spSetMouseCursor(CURSOR_NAME) -- asked for every frame, or the engine puts its own back
	end
end

function widget:IsAbove(mx, my)
	return grab ~= nil
end
