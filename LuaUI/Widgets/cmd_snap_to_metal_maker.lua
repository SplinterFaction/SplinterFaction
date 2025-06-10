function widget:GetInfo()
	return {
		name    = "Snap Metal Maker Placement",
		desc    = "Snaps metal maker build orders to nearest valid spot",
		author  = "",
		date    = "2025-06-10",
		license = "GPLv2",
		layer   = 0,
		enabled = true,
	}
end

local spGetActiveCommand   = Spring.GetActiveCommand
local spGetActiveCmdDesc   = Spring.GetActiveCmdDesc
local spGetBuildFacing     = Spring.GetBuildFacing
local spTraceScreenRay     = Spring.TraceScreenRay
local spGetGroundHeight    = Spring.GetGroundHeight
local spGiveOrder          = Spring.GiveOrder
local CMD_INSERT           = CMD.INSERT
local hoveredSnapPos = nil
local hoveredUnitDefID = nil
local myTeam = Spring.GetMyTeamID()



local function isMetalMaker(unitDefID)
	local ud = UnitDefs[unitDefID]
	return ud and ud.customParams and ud.customParams.metal_maker
end

function widget:Update()
	hoveredSnapPos = nil
	hoveredUnitDefID = nil

	local metalSpots = WG.metalMakerSpots
	if not metalSpots then return end

	local activeCmdID = spGetActiveCommand()
	if not activeCmdID or activeCmdID >= 0 then return end

	local cmdDesc = spGetActiveCmdDesc(activeCmdID)
	if not cmdDesc then return end

	local _, _, _, _, _, buildUnitDefID = cmdDesc[1], cmdDesc[2], cmdDesc[3], cmdDesc[4], cmdDesc[5], cmdDesc[6]
	if not buildUnitDefID or not isMetalMaker(buildUnitDefID) then return end

	local mx, my = Spring.GetMouseState()
	local _, pos = spTraceScreenRay(mx, my, true)
	if not pos then return end

	local bestSpot, bestDist
	for _, spot in ipairs(metalSpots) do
		local dx, dz = pos[1] - spot.x, pos[3] - spot.z
		local dist = dx*dx + dz*dz
		if not bestDist or dist < bestDist then
			bestSpot = spot
			bestDist = dist
		end
	end

	if bestSpot then
		hoveredSnapPos = {bestSpot.x, spGetGroundHeight(bestSpot.x, bestSpot.z), bestSpot.z}
		hoveredUnitDefID = buildUnitDefID
	end
end


function widget:MouseRelease(x, y, button)
	local metalSpots = WG.metalMakerSpots
	if not metalSpots then return false end

	local activeCmdID = spGetActiveCommand()
	if not activeCmdID or activeCmdID >= 0 then return false end

	local _, _, _, _, _, buildUnitDefID = spGetActiveCmdDesc(activeCmdID)
	if not buildUnitDefID or not isMetalMaker(buildUnitDefID) then return false end

	local _, pos = spTraceScreenRay(x, y, true)
	if not pos then return false end

	local closestSpot, closestDist
	for _, spot in ipairs(metalSpots) do
		local dx = pos[1] - spot.x
		local dz = pos[3] - spot.z
		local dist = dx * dx + dz * dz
		if not closestDist or dist < closestDist then
			closestSpot = spot
			closestDist = dist
		end
	end

	if closestSpot then
		local facing = spGetBuildFacing()
		local wy = spGetGroundHeight(closestSpot.x, closestSpot.z)
		local cmd = {-buildUnitDefID, closestSpot.x, wy, closestSpot.z, facing}

		if Spring.GetModKeyState()["shift"] then
			spGiveOrder(CMD_INSERT, { "0", "0", cmd }, {"shift"})
		else
			spGiveOrder(activeCmdID, cmd, {})
		end
		return true -- swallow original command
	end

	return false
end

function widget:DrawWorld()
	Spring.Echo("[Snap] DrawWorld called")
	if hoveredSnapPos and hoveredUnitDefID then
		Spring.Echo("[Snap] Drawing ghost at", hoveredSnapPos[1], hoveredSnapPos[2], hoveredSnapPos[3])
		Spring.DrawUnit(hoveredUnitDefID, hoveredSnapPos[1], hoveredSnapPos[2], hoveredSnapPos[3], 0, true, true, myTeam, true)
	end
end
