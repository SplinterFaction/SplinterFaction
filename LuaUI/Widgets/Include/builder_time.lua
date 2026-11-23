--------------------------------------------------------------------------------
--
--  How long builders will be busy, for the widgets that hand out build jobs
--  (cmd_split_buildorders.lua, cmd_global_build.lua).
--
--    local BT = VFS.Include("LuaUI/Widgets/Include/builder_time.lua")
--
--    BT.Info(unitID)            what kind of builder this is, or nil:
--                               {speed, buildSpeed, range, can = {[unitDefID] = true}}
--    BT.buildTime[unitDefID]    build time of a unit def
--    BT.ReadQueue(unitID, info) x, z, seconds, builds, openEnded
--                               where its queue ends, how long that takes, the
--                               builds in it ({id, tag, x, z, params} each), and
--                               whether it holds an order with no end (patrol,
--                               guard, or repeat is on)
--    BT.FinishTime(state, info, target, x, z)
--                               when a builder whose queue ends at state
--                               ({x, z, time}) would have target built at x, z
--
--  Times are in seconds and assume the builder is never short of resources.
--
--------------------------------------------------------------------------------

local spGetUnitDefID     = Spring.GetUnitDefID
local spGetUnitPosition  = Spring.GetUnitPosition
local spGetUnitCommands  = Spring.GetUnitCommands
local spGetUnitIsBuilding = Spring.GetUnitIsBuilding
local spGetUnitHealth    = Spring.GetUnitHealth
local spGetUnitStates    = Spring.GetUnitStates

local sqrt, max = math.sqrt, math.max

local BT = {}

BT.maxQueueRead = 64   -- queue entries read per builder
BT.otherJobTime = 5    -- seconds allowed for a repair, reclaim or the like, whose length cannot be known

-- unitDefID -> {speed, buildSpeed, range, can} for mobile builders, false otherwise
local builderDefs = {}
local buildTime = {}
for unitDefID, ud in pairs(UnitDefs) do
	local info = false
	if ud.isBuilder and ud.canMove and not ud.isFactory and ud.buildOptions and #ud.buildOptions > 0 then
		local can = {}
		for i = 1, #ud.buildOptions do
			can[ud.buildOptions[i]] = true
		end
		info = {
			speed      = max(1, ud.speed or 1),            -- elmos per second
			buildSpeed = max(0.01, ud.buildSpeed or 0.01),
			range      = ud.buildDistance or 0,
			can        = can,
		}
	end
	builderDefs[unitDefID] = info
	buildTime[unitDefID] = ud.buildTime or 1
end
BT.builderDefs = builderDefs
BT.buildTime = buildTime

function BT.Info(unitID)
	local unitDefID = spGetUnitDefID(unitID)
	return unitDefID and builderDefs[unitDefID] or nil
end

local OPEN_ENDED = { [CMD.PATROL] = true, [CMD.GUARD] = true }
local TIMED_GUESS = {
	[CMD.REPAIR] = true, [CMD.RECLAIM] = true, [CMD.RESURRECT] = true,
	[CMD.CAPTURE] = true, [CMD.RESTORE] = true,
}

function BT.ReadQueue(unitID, info)
	local x, _, z = spGetUnitPosition(unitID)
	if not x then
		return nil
	end
	local time = 0
	local builds = {}
	local openEnded = false
	local queue = spGetUnitCommands(unitID, BT.maxQueueRead) or {}

	-- what is left of the build it is working on, not the whole of it
	local nanoframe = spGetUnitIsBuilding(unitID)
	local leftOfFirst = nil
	if nanoframe then
		local _, _, _, _, progress = spGetUnitHealth(nanoframe)
		if progress then
			leftOfFirst = 1 - progress
		end
	end

	for i = 1, #queue do
		local cmd = queue[i]
		local p = cmd.params
		if OPEN_ENDED[cmd.id] then
			openEnded = true
		end
		if p and #p >= 3 then
			local isBuild = cmd.id < 0
			local working = (i == 1 and isBuild and leftOfFirst ~= nil)
			if not working then
				local dx, dz = p[1] - x, p[3] - z
				local walk = sqrt(dx * dx + dz * dz) - (isBuild and info.range or 0)
				if walk > 0 then
					time = time + walk / info.speed
				end
			end
			x, z = p[1], p[3]
			if isBuild then
				time = time + (buildTime[-cmd.id] or 1) / info.buildSpeed * (working and leftOfFirst or 1)
				builds[#builds + 1] = { id = cmd.id, tag = cmd.tag, x = p[1], z = p[3], params = p }
			elseif TIMED_GUESS[cmd.id] then
				time = time + BT.otherJobTime
			end
		elseif TIMED_GUESS[cmd.id] then
			time = time + BT.otherJobTime
		end
	end

	if #queue > 0 and not openEnded then
		local states = spGetUnitStates(unitID)
		if states and states["repeat"] then
			openEnded = true
		end
	end
	return x, z, time, builds, openEnded
end

function BT.FinishTime(state, info, target, x, z)
	local dx, dz = x - state.x, z - state.z
	local walk = max(0, sqrt(dx * dx + dz * dz) - info.range)
	return state.time + walk / info.speed + (buildTime[target] or 1) / info.buildSpeed
end

return BT
