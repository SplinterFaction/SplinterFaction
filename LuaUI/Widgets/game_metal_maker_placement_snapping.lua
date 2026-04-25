function widget:GetInfo()
	return {
		name    = "Metal Maker Placement Snapping",
		desc    = "Snaps mex placement to nearest valid spot; adds hover ghost + right-click quick-place when builders are selected",
		author  = "",
		date    = "2026-03-03",
		license = "GPLv2",
		layer   = 2,
		enabled = true,
	}
end

local spGetActiveCommand   = Spring.GetActiveCommand
local spGetMouseState      = Spring.GetMouseState
local spTraceScreenRay     = Spring.TraceScreenRay
local spGetGroundHeight    = Spring.GetGroundHeight
local spGiveOrder          = Spring.GiveOrder
local spGetSelectedUnits   = Spring.GetSelectedUnits
local spGetUnitDefID       = Spring.GetUnitDefID
local spGetModKeyState     = Spring.GetModKeyState
local spGetMyTeamID        = Spring.GetMyTeamID

local glBeginEnd  = gl.BeginEnd
local glVertex    = gl.Vertex
local glLineWidth = gl.LineWidth
local glColor     = gl.Color
local glDepthTest = gl.DepthTest
local glPushMatrix = gl.PushMatrix
local glPopMatrix  = gl.PopMatrix
local glTranslate  = gl.Translate
local glRotate     = gl.Rotate
local glUnitShape  = gl.UnitShape

-- Tuning
local HOVER_RADIUS = 90        -- how close mouse must be to a spot (world units)
local LINE_ALPHA   = 0.65
local GHOST_ALPHA  = 0.35
local GHOST_YOFF   = 1.0       -- small lift so it doesn't z-fight

local XOFFSET      = 8
local ZOFFSET      = 8

local myTeamID = spGetMyTeamID()

-- Only metal makers will be snapped/previewed
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
	return bestSpot, bestDist
end

local function DoLine(x1, y1, z1, x2, y2, z2)
	glVertex(x1, y1, z1)
	glVertex(x2, y2, z2)
end

-- Return a metal-maker buildOption unitDefID that ALL selected builders can build (if any).
-- If none are common to all, returns nil.
local function GetCommonMetalMakerBuildOption()
	local sel = spGetSelectedUnits()
	if not sel or #sel == 0 then return nil end

	-- collect selected builders (units that actually have buildOptions)
	local builders = {}
	for i = 1, #sel do
		local uID = sel[i]
		local udID = spGetUnitDefID(uID)
		local ud = udID and UnitDefs[udID]
		if ud and ud.buildOptions and #ud.buildOptions > 0 then
			builders[#builders + 1] = ud
		end
	end
	if #builders == 0 then return nil end

	-- count metal-maker options across builders
	local counts = {}
	for b = 1, #builders do
		local opts = builders[b].buildOptions
		for i = 1, #opts do
			local bo = opts[i]
			if isMetalMaker(bo) then
				counts[bo] = (counts[bo] or 0) + 1
			end
		end
	end

	-- pick one that every builder shares; prefer cheapest metal cost (nice default)
	local need = #builders
	local best, bestCost = nil, math.huge
	for bo, c in pairs(counts) do
		if c == need then
			local cost = (UnitDefs[bo] and UnitDefs[bo].metalCost) or math.huge
			if cost < bestCost then
				bestCost = cost
				best = bo
			end
		end
	end

	return best
end

-- Compute hover info for "idle builder selected" mode
local function GetHoverSpotAndBuildDef(screenX, screenY)
	-- must have mex spots
	if not WG.metalMakerSpots then return nil end

	-- must be "idle": no active command selected (not move/attack/build/etc)
	local _, activeCmdID = spGetActiveCommand()
	if activeCmdID ~= nil then return nil end

	-- must have a common metal maker option among selected builders
	local mexDefID = GetCommonMetalMakerBuildOption()
	if not mexDefID then return nil end

	local _, pos = spTraceScreenRay(screenX, screenY, true, true)
	if not pos then return nil end

	local bx, by, bz = pos[1], pos[2], pos[3]
	local spot, distSq = GetClosestSpot(bx, bz)
	if not spot then return nil end

	local rSq = HOVER_RADIUS * HOVER_RADIUS
	if distSq > rSq then return nil end

	return spot, mexDefID, bx, by, bz
end

function widget:DrawWorldPreUnit()
	-- MODE A: placement snapping mode (your original behavior)
	local _, cmdID = spGetActiveCommand()
	if cmdID and isMetalMaker(-cmdID) then
		if not WG.metalMakerSpots then return end

		local mx, my = spGetMouseState()
		local _, pos = spTraceScreenRay(mx, my, true, true)
		if not pos then return end

		local bx, by, bz = pos[1], pos[2], pos[3]
		local spot = GetClosestSpot(bx, bz)
		if not spot then return end

		local sy = spGetGroundHeight(spot.x, spot.z)  -- negative when underwater; intentional

		glDepthTest(false)
		glLineWidth(2.0)
		glColor(1, 1, 0, LINE_ALPHA)
		glBeginEnd(GL.LINES, DoLine, bx, by, bz, spot.x, sy, spot.z)
		glLineWidth(1.0)
		glColor(1, 1, 1, 1)
		return
	end

	-- MODE B: idle builder hover ghost + guide line
	local mx, my = spGetMouseState()
	local spot, mexDefID, bx, by, bz = GetHoverSpotAndBuildDef(mx, my)
	if not spot then return end

	local sy = spGetGroundHeight(spot.x, spot.z)  -- negative when underwater; intentional

	-- guide line (mouse -> spot)
	glDepthTest(false)
	glLineWidth(2.0)
	glColor(0.2, 1, 0.2, LINE_ALPHA)
	glBeginEnd(GL.LINES, DoLine, bx, by, bz, spot.x, sy, spot.z)
	glLineWidth(1.0)

	-- ghost building on the spot
	glColor(1, 1, 1, GHOST_ALPHA)
	glPushMatrix()
	glTranslate(spot.x + XOFFSET, sy + GHOST_YOFF, spot.z + ZOFFSET)
	-- facing = 0 (south) by default; rotate if you later want spot.facing
	glRotate(0, 0, 1, 0)
	-- draw as translucent "shape"
	glUnitShape(mexDefID, myTeamID, false, true, true)
	glPopMatrix()

	glColor(1, 1, 1, 1)
end

-- Intercept clicks:
--  A) left-click in placement mode: snap (your original)
--  B) right-click in idle builder mode: quick-place mex at hovered spot
function widget:MousePress(x, y, button)
	-- A) placement snapping mode (left-click)
	if button == 1 then
		local spGetModKeyState = Spring.GetModKeyState
		local _, cmdID = spGetActiveCommand()
		if not cmdID or not isMetalMaker(-cmdID) then return false end

		local _, pos = spTraceScreenRay(x, y, true, true)
		if not pos then return false end

		local spot = GetClosestSpot(pos[1], pos[3])
		if not spot then return false end

		local shift = select(4, spGetModKeyState())  -- alt, ctrl, meta, shift
		local gy = math.max(0, spGetGroundHeight(spot.x, spot.z))

		if not shift then
			-- clears current command queue for selected units
			spGiveOrder(CMD.STOP, {}, {})
		end

		-- then issue the build
		spGiveOrder(cmdID, {spot.x, gy, spot.z, 0}, shift and {"shift"} or {})
		if not shift then
			-- Cancel the current active build command so it doesn't queue up more
			Spring.SetActiveCommand(0)
		end
		return true
	end

	-- B) idle builder hover quick-place (right-click)
	if button == 3 then
		local spot, mexDefID = GetHoverSpotAndBuildDef(x, y)
		if not spot then return false end

		local gy = math.max(0, spGetGroundHeight(spot.x, spot.z))

		local alt, ctrl, meta, shift = spGetModKeyState()
		local opts = {}
		if shift then opts[#opts + 1] = "shift" end

		-- issue build order directly (cmdID = -unitDefID)
		spGiveOrder(-mexDefID, {spot.x, gy, spot.z, 0}, opts)

		-- swallow the RMB so it doesn't also issue a move order
		return true
	end

	return false
end