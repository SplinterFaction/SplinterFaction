function widget:GetInfo()
	return {
		name    = "Metal Maker Placement Snapping",
		desc    = "Snaps mex placement to nearest valid spot, does not automatically kill the command so that users can speed place Metal Makers",
		author  = "",
		date    = "2025-06-19",
		license = "GPLv2",
		layer   = 0,
		enabled = true,
	}
end

local spGetActiveCommand = Spring.GetActiveCommand
local spGetMouseState = Spring.GetMouseState
local spTraceScreenRay = Spring.TraceScreenRay
local spGetGroundHeight = Spring.GetGroundHeight
local spGiveOrder = Spring.GiveOrder
local glBeginEnd = gl.BeginEnd
local glVertex = gl.Vertex
local glLineWidth = gl.LineWidth
local glColor = gl.Color
local glDepthTest = gl.DepthTest

-- Only metal makers will be snapped
local function isMetalMaker(unitDefID)
	local ud = UnitDefs[unitDefID]
	return ud and ud.customParams and ud.customParams.metal_extractor
end

local function GetClosestSpot(x, z)
	if not WG.metalMakerSpots then return nil end
	local bestDist = math.huge
	local bestSpot = nil
	for _, spot in ipairs(WG.metalMakerSpots) do
		local dx, dz = x - spot.x, z - spot.z
		local distSq = dx * dx + dz * dz
		if distSq < bestDist then
			bestDist = distSq
			bestSpot = spot
		end
	end
	return bestSpot
end

local function DoLine(x1, y1, z1, x2, y2, z2)
	glVertex(x1, y1, z1)
	glVertex(x2, y2, z2)
end

function widget:DrawWorld()
	local _, cmdID = spGetActiveCommand()
	if not cmdID or not isMetalMaker(-cmdID) then return end
	if not WG.metalMakerSpots then return end

	local mx, my = spGetMouseState()
	local _, pos = spTraceScreenRay(mx, my, true, true)
	if not pos then return end

	local bx, by, bz = pos[1], pos[2], pos[3]
	local spot = GetClosestSpot(bx, bz)
	if not spot then return end

	local sy = math.max(0, spGetGroundHeight(spot.x, spot.z))

	glDepthTest(false)
	glLineWidth(2.0)
	glColor(1, 1, 0, 0.7)
	glBeginEnd(GL.LINES, DoLine, bx, by, bz, spot.x, sy, spot.z)
	glLineWidth(1.0)
	glColor(1, 1, 1, 1)
end

-- Intercept clicks and hijack build command even on non-buildable terrain
function widget:MousePress(x, y, button)
	if button ~= 1 then return false end -- left click only

	local _, cmdID = spGetActiveCommand()
	if not cmdID or not isMetalMaker(-cmdID) then return false end

	local _, pos = spTraceScreenRay(x, y, true, true)
	if not pos then return false end

	local spot = GetClosestSpot(pos[1], pos[3])
	if not spot then return false end

	local y = math.max(0, spGetGroundHeight(spot.x, spot.z))

	-- Give build order at valid spot
	spGiveOrder(cmdID, {spot.x, y, spot.z, 0}, {"shift"})

	-- Don't cancel the command – let the user keep placing more
	return true
end
