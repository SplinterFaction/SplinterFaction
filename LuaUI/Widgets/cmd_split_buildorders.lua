function widget:GetInfo()
	return {
		name = "Build Order Splitter",
		desc = "Shares queued build orders between the selected builders: each job goes to whoever can get it done soonest, and a builder that runs out takes work from one that has plenty",
		author = "SplinterFaction",
		date = "2026-11-22",
		license = "GPLv2",
		layer = 0,
		enabled = true
	}
end

--------------------------------------------------------------------------------
--
--  What happens when several builders are selected and builds are queued with
--  shift.
--
--  Before: the orders of one click or drag were dealt out in turn starting
--  from the first builder every time. Buildings placed one click at a time
--  therefore ALL went to the first builder, a dragged line was dealt out
--  without looking where anyone stood, and a builder that could not build the
--  thing was dealt it anyway.
--
--  Now each job goes to the builder that would have it FINISHED soonest:
--
--      the time its queue already holds (walking and building)
--    + the walk from where that queue ends to the job
--    + the time the job takes with its build power
--
--  Only builders that can build the thing are considered. One formula covers
--  the cases that matter: a near builder is preferred until it has enough to do
--  that a farther, freer one would be quicker, and strong builders take more
--  than weak ones.
--
--  The orders of one click or drag are handed out together, not in the order
--  they were placed: each time, the job and builder that give the soonest
--  finish of all are paired first. That cuts a dragged line into stretches,
--  one per builder, each worked from the end nearest its builder, instead of
--  sending builders past one another.
--
--  Sharing does not stop when the orders are given. Builders that were given a
--  share form a crew. When one of them has nothing left to do it looks at the
--  crewmate with the most still queued and takes over one of its waiting jobs
--  (the one nearest to itself). The job a mate has in hand is left to it: SF
--  builders cannot help one another build.
--  A builder leaves its crew when the player gives it any order that is not a
--  queued build, so a builder sent elsewhere stays where it was sent.
--
--  Unchanged: a build ordered without shift is given to every selected builder
--  (they all build that one thing), and so is anything ordered with the insert
--  key held (gui_commandinsert).
--
--  WG.buildSplitter.Assign(cmdID, params, opts, builders) hands out one job
--  the same way for other widgets, and AssignBatch(jobs, builders) several.
--
--------------------------------------------------------------------------------

local TUNE = {
	stealing     = true,  -- idle crew members take over a crewmate's waiting work
	stealDelay   = 12,    -- frames between two looks by the same idle builder
	crewTimeout  = 900,   -- frames an idle builder stays in a crew with nothing to do
	virtualLife  = 20,    -- frames an assignment is trusted before the real queue is read again
	maxBatch     = 160,   -- more orders than this in one drag are handed out in the order placed (cost)
}

local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitDefID     = Spring.GetUnitDefID
local spGetUnitPosition  = Spring.GetUnitPosition
local spGetUnitCommands  = Spring.GetUnitCommands
local spGiveOrderToUnit  = Spring.GiveOrderToUnit
local spGetGameFrame     = Spring.GetGameFrame
local spValidUnitID      = Spring.ValidUnitID
local spGetUnitIsDead    = Spring.GetUnitIsDead
local spGetMyTeamID      = Spring.GetMyTeamID
local spGetUnitTeam      = Spring.GetUnitTeam

local CMD_REMOVE = CMD.REMOVE
local sqrt, max, huge = math.sqrt, math.max, math.huge

--------------------------------------------------------------------------------
-- how busy a builder is (shared with cmd_global_build.lua)
--------------------------------------------------------------------------------

local BT = VFS.Include("LuaUI/Widgets/Include/builder_time.lua")
local BuilderInfo = BT.Info
local ReadQueue   = BT.ReadQueue
local buildTime   = BT.buildTime

-- unitID -> {x, z, time, frame}: where its queue ends and how long that takes,
-- kept for a moment after an assignment, because an order given now is not in
-- the queue the engine reports until it has gone through the network
local virtual = {}

local function EndState(unitID, info, frame)
	local v = virtual[unitID]
	if v and frame - v.frame <= TUNE.virtualLife then
		return v
	end
	local x, z, time = ReadQueue(unitID, info)
	if not x then
		return nil
	end
	v = v or {}
	v.x, v.z, v.time, v.frame = x, z, time, frame
	virtual[unitID] = v
	return v
end

--------------------------------------------------------------------------------
-- crews
--------------------------------------------------------------------------------

local crewOf = {}      -- unitID -> crew (a table: [unitID] = true)
local idleSince = {}   -- unitID -> frame it went idle, while it is in a crew
local nextLook = {}    -- unitID -> frame it may look for work again

local function LeaveCrew(unitID)
	local crew = crewOf[unitID]
	if crew then
		crew[unitID] = nil
		crewOf[unitID] = nil
	end
	idleSince[unitID] = nil
	nextLook[unitID] = nil
end

-- Puts these builders in one crew, merging the crews any of them were in.
local function FormCrew(units)
	local crew = nil
	for i = 1, #units do
		crew = crew or crewOf[units[i]]
	end
	crew = crew or {}
	for i = 1, #units do
		local unitID = units[i]
		local old = crewOf[unitID]
		if old and old ~= crew then
			for member in pairs(old) do
				crew[member] = true
				crewOf[member] = crew
			end
		end
		crew[unitID] = true
		crewOf[unitID] = crew
		idleSince[unitID] = nil
	end
end

--------------------------------------------------------------------------------
-- handing out a job
--------------------------------------------------------------------------------

-- When this builder would have the job finished, and its end state; nil if it cannot build it.
local function FinishTime(unitID, target, jx, jz, frame)
	local info = BuilderInfo(unitID)
	if not (info and info.can[target]) then
		return nil
	end
	local state = EndState(unitID, info, frame)
	if not state then
		return nil
	end
	local dx, dz = jx - state.x, jz - state.z
	local walk = max(0, sqrt(dx * dx + dz * dz) - info.range)
	return state.time + walk / info.speed + (buildTime[target] or 1) / info.buildSpeed, state
end

-- Hands out jobs ({cmdID, params, opts} each) between `builders`. Each time,
-- the job and builder with the soonest finish of all are paired. Returns the
-- builder each job went to (nil where nobody could build it), by job index.
local function AssignBatch(jobs, builders)
	local frame = spGetGameFrame()
	local result = {}
	local left = {}
	for i = 1, #jobs do left[i] = i end
	local inOrder = #jobs > TUNE.maxBatch

	while #left > 0 do
		local bestSlot, bestUnit, bestDone, bestState = nil, nil, huge, nil
		for slot = 1, (inOrder and 1 or #left) do
			local job = jobs[left[slot]]
			local target, jx, jz = -job[1], job[2][1], job[2][3]
			for i = 1, #builders do
				local done, state = FinishTime(builders[i], target, jx, jz, frame)
				if done and done < bestDone then
					bestSlot, bestUnit, bestDone, bestState = slot, builders[i], done, state
				end
			end
		end
		if not bestSlot then
			break -- nobody can build what is left
		end
		local index = table.remove(left, bestSlot)
		local job = jobs[index]
		spGiveOrderToUnit(bestUnit, job[1], job[2], job[3])
		bestState.x, bestState.z, bestState.time, bestState.frame = job[2][1], job[2][3], bestDone, frame
		result[index] = bestUnit
	end
	return result
end

-- Gives the build to the one of `builders` that would finish it soonest.
-- Returns that builder, or nil when none of them can build it.
local function Assign(cmdID, params, opts, builders)
	return AssignBatch({ { cmdID, params, opts } }, builders)[1]
end

local pending = {} -- the queued builds of this frame: {cmdID, params, opts} each

-- the selected builders that can build this
local function CapableBuilders(target)
	local list = {}
	local selected = spGetSelectedUnits()
	for i = 1, #selected do
		local info = BuilderInfo(selected[i])
		if info and info.can[target] then
			list[#list + 1] = selected[i]
		end
	end
	return list
end

function widget:CommandNotify(cmdID, cmdParams, cmdOpts)
	local isBuild = cmdID < 0 and cmdParams and #cmdParams >= 3
	if not (isBuild and cmdOpts.shift) then
		-- any order that is not a queued build takes the selected builders out
		-- of their crews: the player has other plans for them
		if not cmdOpts.shift and next(crewOf) then
			local selected = spGetSelectedUnits()
			for i = 1, #selected do
				LeaveCrew(selected[i])
			end
		end
		return false
	end
	if cmdOpts.meta then
		return false -- the insert key: gui_commandinsert places it in every queue
	end

	local builders = CapableBuilders(-cmdID)
	if #builders < 2 then
		return false
	end
	-- held until Update: a dragged line arrives as one of these calls per
	-- building, all in one frame, and is handed out as a whole
	pending[#pending + 1] = { cmdID, cmdParams, cmdOpts }
	return true -- handled: the engine must not give it to everyone as well
end

function widget:Update()
	if #pending == 0 then
		return
	end
	local jobs = pending
	pending = {}
	-- every selected mobile builder: AssignBatch leaves out those that cannot build a job
	local builders = {}
	local selected = spGetSelectedUnits()
	for i = 1, #selected do
		if BuilderInfo(selected[i]) then
			builders[#builders + 1] = selected[i]
		end
	end
	local result = AssignBatch(jobs, builders)
	local crew, seen = {}, {}
	for i = 1, #jobs do
		local unitID = result[i]
		if not unitID then
			-- could not be placed with anyone after all: give it the engine's way
			Spring.GiveOrderToUnitArray(selected, jobs[i][1], jobs[i][2], jobs[i][3])
		end
	end
	-- the crew is everyone who could have taken any of it
	for i = 1, #builders do
		local info = BuilderInfo(builders[i])
		for j = 1, #jobs do
			if info.can[-jobs[j][1]] and not seen[builders[i]] then
				seen[builders[i]] = true
				crew[#crew + 1] = builders[i]
			end
		end
	end
	if #crew > 1 then
		FormCrew(crew)
	end
end

--------------------------------------------------------------------------------
-- a crew member with nothing to do
--------------------------------------------------------------------------------

local function Usable(unitID)
	return spValidUnitID(unitID) and not spGetUnitIsDead(unitID) and spGetUnitTeam(unitID) == spGetMyTeamID()
end

-- Returns true when it found something for the builder to do.
local function FindWork(unitID)
	local crew = crewOf[unitID]
	local info = BuilderInfo(unitID)
	if not (crew and info) then
		return false
	end
	local x, _, z = spGetUnitPosition(unitID)
	if not x then
		return false
	end

	-- the crewmate with the most still to do
	local mate, mateTime, mateBuilds = nil, 0, nil
	for member in pairs(crew) do
		if member ~= unitID then
			if not Usable(member) then
				LeaveCrew(member)
			else
				local memberInfo = BuilderInfo(member)
				if memberInfo then
					local _, _, time, builds = ReadQueue(member, memberInfo)
					if time and #builds > 0 and time > mateTime then
						mate, mateTime, mateBuilds = member, time, builds
					end
				end
			end
		end
	end
	if not mate then
		return false
	end

	-- one of its waiting jobs, the nearest this builder can build
	local pick, pickDist = nil, huge
	for i = 2, #mateBuilds do
		local job = mateBuilds[i]
		if info.can[-job.id] then
			local dx, dz = job.x - x, job.z - z
			local d = dx * dx + dz * dz
			if d < pickDist then
				pick, pickDist = job, d
			end
		end
	end
	if pick then
		spGiveOrderToUnit(mate, CMD_REMOVE, { pick.tag }, 0)
		spGiveOrderToUnit(unitID, pick.id, pick.params, 0)
		virtual[mate] = nil
		virtual[unitID] = nil
		return true
	end

	return false
end

function widget:UnitIdle(unitID)
	if TUNE.stealing and crewOf[unitID] then
		idleSince[unitID] = idleSince[unitID] or spGetGameFrame()
		nextLook[unitID] = spGetGameFrame() + 2 -- not in the callin: let the queue settle
	end
end

function widget:GameFrame(frame)
	if not next(nextLook) then
		return
	end
	for unitID, at in pairs(nextLook) do
		if frame >= at then
			if not Usable(unitID) then
				LeaveCrew(unitID)
			elseif (spGetUnitCommands(unitID, 1) or {})[1] then
				-- it has been given something since: not idle
				nextLook[unitID], idleSince[unitID] = nil, nil
			elseif FindWork(unitID) then
				nextLook[unitID], idleSince[unitID] = nil, nil
			elseif frame - (idleSince[unitID] or frame) > TUNE.crewTimeout then
				LeaveCrew(unitID) -- the crew has nothing for it
			else
				nextLook[unitID] = frame + TUNE.stealDelay
			end
		end
	end
end

function widget:UnitDestroyed(unitID)
	LeaveCrew(unitID)
	virtual[unitID] = nil
end

function widget:UnitTaken(unitID)
	LeaveCrew(unitID)
	virtual[unitID] = nil
end

--------------------------------------------------------------------------------

function widget:Initialize()
	WG.buildSplitter = {
		Assign    = Assign,
		AssignBatch = AssignBatch,
		FormCrew  = FormCrew,
		LeaveCrew = LeaveCrew,
		tune      = TUNE,
	}
end

function widget:Shutdown()
	WG.buildSplitter = nil
end
