function widget:GetInfo()
	return {
		name    = "Metal Maker Placement Snapping",
		desc    = "Snaps mex placement to nearest valid spot; adds hover ghost + right-click paint-to-queue when builders are selected",
		author  = "",
		date    = "2026-03-03",
		license = "GPLv2",
		layer   = 2,
		enabled = true,
	}
end

local spGetActiveCommand    = Spring.GetActiveCommand
local spGetMouseState       = Spring.GetMouseState
local spTraceScreenRay      = Spring.TraceScreenRay
local spGetGroundHeight     = Spring.GetGroundHeight
local spGiveOrder           = Spring.GiveOrder
local spGetSelectedUnits    = Spring.GetSelectedUnits
local spGetUnitDefID        = Spring.GetUnitDefID
local spGetModKeyState      = Spring.GetModKeyState
local spGetMyTeamID         = Spring.GetMyTeamID
local spGetUnitsInCylinder  = Spring.GetUnitsInCylinder
local spGetUnitCommands     = Spring.GetUnitCommands
local spGetUnitHealth       = Spring.GetUnitHealth
local spGetUnitAllyTeam     = Spring.GetUnitAllyTeam
local spGetMyAllyTeamID     = Spring.GetMyAllyTeamID

local glBeginEnd   = gl.BeginEnd
local glVertex     = gl.Vertex
local glLineWidth  = gl.LineWidth
local glColor      = gl.Color
local glDepthTest  = gl.DepthTest
local glPushMatrix = gl.PushMatrix
local glPopMatrix  = gl.PopMatrix
local glTranslate  = gl.Translate
local glRotate     = gl.Rotate
local glUnitShape  = gl.UnitShape

-- Tuning
local HOVER_RADIUS    = 90     -- how close mouse must be to a spot (world units)
local OCCUPIED_RADIUS = 48     -- radius around a spot to consider it occupied by a mex
local LINE_ALPHA      = 0.65
local GHOST_ALPHA     = 0.35
local GHOST_YOFF      = 1.0    -- small lift so it doesn't z-fight
local SKIP_ALPHA      = 0.55   -- alpha for skipped/occupied spot markers
local SKIP_MARK_SIZE  = 24     -- half-size of the red X on skipped spots

local XOFFSET = 8
local ZOFFSET = 8

local KEYSYM_ESC = 27

local myTeamID = spGetMyTeamID()

-- Paint-to-queue stroke state
local paint = {
	active    = false,
	mexDefID  = nil,   -- resolved once at press time, cached for the stroke
	entries   = {},    -- ordered array of {spot=, repairID=}; traced order = queue order
	seen      = {},    -- dedupe set keyed by spot table reference
	skipped   = {},    -- ordered array of occupied spots we refused (for red markers)
	skipSeen  = {},    -- dedupe set for skipped
	queuedPos = {},    -- array of {x, z} mex build positions already queued on selected builders
}

local function ResetPaint()
	paint.active    = false
	paint.mexDefID  = nil
	paint.entries   = {}
	paint.seen      = {}
	paint.skipped   = {}
	paint.skipSeen  = {}
	paint.queuedPos = {}
end

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

-- Collect positions of mex build orders already queued on the selected builders.
-- Called once per stroke (at press time), not per capture.
local function CollectQueuedMexPositions()
	local queued = {}
	local sel = spGetSelectedUnits()
	if not sel then return queued end
	for i = 1, #sel do
		local cmds = spGetUnitCommands(sel[i], -1)
		if cmds then
			for c = 1, #cmds do
				local cmd = cmds[c]
				if cmd.id < 0 and isMetalMaker(-cmd.id) then
					local p = cmd.params
					if p and p[1] and p[3] then
						queued[#queued + 1] = { x = p[1], z = p[3] }
					end
				end
			end
		end
	end
	return queued
end

-- Return the unitID of an allied under-construction mex (nanoframe) at this
-- spot, or nil. buildProgress is the 5th return of GetUnitHealth; < 1 means
-- the unit is still a nanoframe.
local function GetNanoframeMexAt(spot)
	local units = spGetUnitsInCylinder(spot.x, spot.z, OCCUPIED_RADIUS)
	if not units then return nil end
	local myAllyTeam = spGetMyAllyTeamID()
	for i = 1, #units do
		local uID = units[i]
		local udID = spGetUnitDefID(uID)
		if udID and isMetalMaker(udID) and spGetUnitAllyTeam(uID) == myAllyTeam then
			local buildProgress = select(5, spGetUnitHealth(uID))
			if buildProgress and buildProgress < 1 then
				return uID
			end
		end
	end
	return nil
end

-- Occupied = existing/under-construction mex nearby, or a mex build already
-- queued at this spot by the selected builders.
local function IsSpotOccupied(spot)
	-- existing or nanoframe mex (any team)
	local units = spGetUnitsInCylinder(spot.x, spot.z, OCCUPIED_RADIUS)
	if units then
		for i = 1, #units do
			local udID = spGetUnitDefID(units[i])
			if udID and isMetalMaker(udID) then
				return true
			end
		end
	end

	-- already queued by selected builders (snapshot from stroke start)
	local rSq = OCCUPIED_RADIUS * OCCUPIED_RADIUS
	for i = 1, #paint.queuedPos do
		local q = paint.queuedPos[i]
		local dx, dz = spot.x - q.x, spot.z - q.z
		if dx * dx + dz * dz < rSq then
			return true
		end
	end

	return false
end

-- Classify and add a spot to the current stroke:
--   allied nanoframe mex there -> repair entry (spliced inline, traced order)
--   otherwise occupied         -> skipped (red marker)
--   otherwise                  -> build entry
local function CaptureSpot(spot)
	if paint.seen[spot] or paint.skipSeen[spot] then return end

	local nano = GetNanoframeMexAt(spot)
	if nano then
		paint.seen[spot] = true
		paint.entries[#paint.entries + 1] = { spot = spot, repairID = nano }
		return
	end

	if IsSpotOccupied(spot) then
		paint.skipSeen[spot] = true
		paint.skipped[#paint.skipped + 1] = spot
		return
	end

	paint.seen[spot] = true
	paint.entries[#paint.entries + 1] = { spot = spot }
end

-- Try to add the spot under the cursor to the current stroke.
local function TryCaptureAt(screenX, screenY)
	local _, pos = spTraceScreenRay(screenX, screenY, true, true)
	if not pos then return end  -- cursor over sky/void: skip sample, keep painting

	local spot, distSq = GetClosestSpot(pos[1], pos[3])
	if not spot then return end

	local rSq = HOVER_RADIUS * HOVER_RADIUS
	if distSq > rSq then return end

	CaptureSpot(spot)
end

-- Stroke is only valid while there's still a selection and no active command.
local function PaintStillValid()
	local _, activeCmdID = spGetActiveCommand()
	if activeCmdID ~= nil then return false end
	local sel = spGetSelectedUnits()
	if not sel or #sel == 0 then return false end
	return true
end

local function DoSkipMark(x, y, z)
	glVertex(x - SKIP_MARK_SIZE, y, z - SKIP_MARK_SIZE)
	glVertex(x + SKIP_MARK_SIZE, y, z + SKIP_MARK_SIZE)
	glVertex(x - SKIP_MARK_SIZE, y, z + SKIP_MARK_SIZE)
	glVertex(x + SKIP_MARK_SIZE, y, z - SKIP_MARK_SIZE)
end

local function DoRepairMark(x, y, z)
	glVertex(x - SKIP_MARK_SIZE, y, z)
	glVertex(x + SKIP_MARK_SIZE, y, z)
	glVertex(x, y, z - SKIP_MARK_SIZE)
	glVertex(x, y, z + SKIP_MARK_SIZE)
end

local function DrawPaintPath(cursorX, cursorY, cursorZ)
	glDepthTest(false)

	-- polyline: entry 1 -> entry 2 -> ... -> cursor
	glLineWidth(2.0)
	glColor(0.2, 1, 0.2, LINE_ALPHA)
	local n = #paint.entries
	if n > 0 then
		glBeginEnd(GL.LINE_STRIP, function()
			for i = 1, n do
				local s = paint.entries[i].spot
				local sy = spGetGroundHeight(s.x, s.z)
				glVertex(s.x, sy, s.z)
			end
			if cursorX then
				glVertex(cursorX, cursorY, cursorZ)
			end
		end)
	end
	glLineWidth(1.0)

	-- build entries: ghost; repair entries: green "+" over the nanoframe
	for i = 1, n do
		local e = paint.entries[i]
		local s = e.spot
		local sy = spGetGroundHeight(s.x, s.z)
		if e.repairID then
			glLineWidth(2.0)
			glColor(0.3, 1, 0.3, SKIP_ALPHA)
			glBeginEnd(GL.LINES, DoRepairMark, s.x, sy + GHOST_YOFF, s.z)
			glLineWidth(1.0)
		else
			glColor(1, 1, 1, GHOST_ALPHA)
			glPushMatrix()
			glTranslate(s.x + XOFFSET, sy + GHOST_YOFF, s.z + ZOFFSET)
			glRotate(0, 0, 1, 0)
			glUnitShape(paint.mexDefID, myTeamID, false, true, true)
			glPopMatrix()
		end
	end

	-- red X on skipped (occupied) spots, persistent for the stroke
	if #paint.skipped > 0 then
		glLineWidth(2.0)
		glColor(1, 0.2, 0.2, SKIP_ALPHA)
		for i = 1, #paint.skipped do
			local s = paint.skipped[i]
			local sy = spGetGroundHeight(s.x, s.z) + GHOST_YOFF
			glBeginEnd(GL.LINES, DoSkipMark, s.x, sy, s.z)
		end
		glLineWidth(1.0)
	end

	glColor(1, 1, 1, 1)
end

function widget:DrawWorldPreUnit()
	-- MODE A: placement snapping mode (original behavior)
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

	-- MODE B (painting): path polyline + ghosts on all pending spots
	if paint.active then
		local mx, my = spGetMouseState()
		local _, pos = spTraceScreenRay(mx, my, true, true)
		if pos then
			DrawPaintPath(pos[1], pos[2], pos[3])
		else
			DrawPaintPath(nil, nil, nil)
		end
		return
	end

	-- MODE B (hover): single ghost + guide line
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
--  A) left-click in placement mode: snap (original)
--  B) right-click in idle builder mode: start paint-to-queue stroke
function widget:MousePress(x, y, button)
	-- A) placement snapping mode (left-click)
	if button == 1 then
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

	-- B) idle builder paint-to-queue (right-click)
	if button == 3 then
		local spot, mexDefID = GetHoverSpotAndBuildDef(x, y)
		if not spot then return false end

		ResetPaint()
		paint.active    = true
		paint.mexDefID  = mexDefID  -- cached for the stroke; selection changes can't swap it
		paint.queuedPos = CollectQueuedMexPositions()

		-- shared classification: build entry, inline repair entry (allied
		-- nanoframe), or skipped (otherwise occupied)
		CaptureSpot(spot)

		-- returning true is what makes the engine deliver MouseMove/MouseRelease to us
		return true
	end

	return false
end

function widget:MouseMove(x, y, dx, dy, button)
	if not paint.active then return false end

	if not PaintStillValid() then
		ResetPaint()
		return false
	end

	TryCaptureAt(x, y)
	return true
end

function widget:MouseRelease(x, y, button)
	if not paint.active then return false end
	if button ~= 3 then return false end

	-- one last capture at the release point
	if PaintStillValid() then
		TryCaptureAt(x, y)
	else
		ResetPaint()
		return false
	end

	local entries = paint.entries
	local mexDefID = paint.mexDefID
	ResetPaint()

	if #entries == 0 then
		-- pressed on an occupied spot and never painted a valid one: swallow, do nothing
		return false
	end

	-- shift is read at release time
	local shift = select(4, spGetModKeyState())
	if not shift then
		spGiveOrder(CMD.STOP, {}, {})
	end

	-- traced order = queue order; all orders chained with shift.
	-- Repair entries whose nanoframe died mid-stroke fall back to a fresh
	-- build order on the same spot (GetUnitDefID is nil for dead/invalid IDs).
	for i = 1, #entries do
		local e = entries[i]
		if e.repairID and spGetUnitDefID(e.repairID) then
			spGiveOrder(CMD.REPAIR, {e.repairID}, {"shift"})
		else
			local s = e.spot
			local gy = math.max(0, spGetGroundHeight(s.x, s.z))
			spGiveOrder(-mexDefID, {s.x, gy, s.z, 0}, {"shift"})
		end
	end

	return false
end

function widget:KeyPress(key, mods, isRepeat)
	if paint.active and key == KEYSYM_ESC then
		ResetPaint()
		return true  -- swallow ESC so it doesn't also deselect
	end
	return false
end
