function widget:GetInfo()
	return {
		name    = "Global Build",
		desc    = "Alt-click a building, place more of it anywhere: the jobs go on a board and the best-placed builders take them",
		author  = "SplinterFaction",
		date    = "2026-11-22",
		license = "GNU GPL, v2 or later",
		layer   = -5, -- before the Build Order Splitter (0): a board job must not be dealt out by it
		enabled = true,
	}
end

--------------------------------------------------------------------------------
--
--  Building without selecting a builder.
--
--  PLACING
--    Alt + left click on a building (yours or anyone's you can see) samples
--    it, and so does Alt + left click on a building in the build menu of a
--    selected builder. You are then placing that building the usual way: click for one,
--    Shift-drag for a line, Shift+Alt-drag for a filled box, Shift+Ctrl-drag
--    for a hollow one, with the usual spacing and facing keys. A tag by the
--    cursor says the builds are going to the board. When placing ends (a click
--    without Shift, or a right click) your selection is as it was.
--
--    The engine only lets a build be placed while a unit that can build it is
--    selected, so for the length of the placing one such builder is selected
--    as a stand-in. Nothing is ordered of it: every build placed is caught in
--    CommandNotify and put on the board instead.
--
--  BOARD MODE
--    The GLOBAL switch on the build menu (or Alt+Q) turns board mode on, and it
--    stays on until it is switched off. While it is on, every building placed
--    with a builder selected goes on the board instead of to that builder: from
--    the build menu, from a build hotkey, from the mex snapping. Alt + click on
--    a card in the menu orders the selected builder itself, that once.
--
--  THE BOARD
--    A job on the board belongs to no builder until one starts on it. Every
--    half second the board plans all waiting jobs over all free-to-use
--    builders: each time, the job and builder that would have it finished
--    soonest of all are paired, where "finished" is
--
--        the time until the builder is free (what is left of the build in
--        hand, the rest of its queue)
--      + its walk to the job from where it will then be
--      + the build itself at its build power
--
--    so an idle builder is preferred, but not one across the map when a
--    builder next to the job will be free in a few seconds. Only a builder
--    that is idle is given an order, and only the first job of its plan; the
--    rest stays on the board, to be planned again as things change. A job
--    kept back for a busy builder for longer than TUNE.holdTime goes to an
--    idle one after all.
--
--    Builders busy with your own orders are counted (they come free
--    eventually) but never interrupted. Builders on patrol, on guard or on
--    repeat are left alone, and so are any you mark as your own: Alt+G with
--    builders selected takes them off the board, or puts them back.
--
--    A job goes back on the board if its builder dies or is given other
--    orders, or its half-built frame is destroyed. One that cannot be built
--    (three tries) is dropped with a note. Every job has one builder: SF
--    builders cannot help one another build, so an idle builder with nothing
--    in its plan stays idle.
--
--    Alt + right click on a job's marker takes it off the board.
--
--  Markers on the ground: white, waiting; yellow, kept for a builder that is
--  about to be free; green, being built. Until its frame is started a job also
--  shows the building itself, see-through, as a builder's own queue does.
--
--------------------------------------------------------------------------------

local TUNE = {
	planInterval = 15,    -- frames between two plans
	graceFrames  = 45,    -- an order is given this many frames, and graceSeconds, to show up in a
	graceSeconds = 1.0,   -- builder's queue: orders go through the network, however fast the game runs
	useCommanders = false, -- commanders build for the board too (off: they stay where you put them)
	holdTime     = 20,    -- seconds a job is kept back for a busy builder before an idle one gets it
	maxPlanJobs  = 60,    -- waiting jobs planned per pass (the oldest first)
	maxTries     = 3,     -- failed starts before a job is dropped
	matchDist    = 24,    -- elmos within which a unit is taken to be a job's building
}

local DEBUG = false
local EXCLUDE_KEY = "g" -- with Alt: take the selected builders off the board, or put them back
local MODE_KEY    = "q" -- with Alt: board mode on or off

local BT = VFS.Include("LuaUI/Widgets/Include/builder_time.lua")

local spGetSelectedUnits  = Spring.GetSelectedUnits
local spSelectUnitArray   = Spring.SelectUnitArray
local spGetUnitDefID      = Spring.GetUnitDefID
local spGetUnitPosition   = Spring.GetUnitPosition
local spGetUnitTeam       = Spring.GetUnitTeam
local spGetUnitCommands   = Spring.GetUnitCommands
local spGetUnitHealth     = Spring.GetUnitHealth
local spGiveOrderToUnit   = Spring.GiveOrderToUnit
local spValidUnitID       = Spring.ValidUnitID
local spGetUnitIsDead     = Spring.GetUnitIsDead
local spGetGameFrame      = Spring.GetGameFrame
local spGetMyTeamID       = Spring.GetMyTeamID
local spGetTeamUnits      = Spring.GetTeamUnits
local spGetActiveCommand  = Spring.GetActiveCommand
local spSetActiveCommand  = Spring.SetActiveCommand
local spGetCmdDescIndex   = Spring.GetCmdDescIndex
local spGetModKeyState    = Spring.GetModKeyState
local spTraceScreenRay    = Spring.TraceScreenRay
local spGetMouseState     = Spring.GetMouseState
local spGetGroundHeight   = Spring.GetGroundHeight
local spEcho              = Spring.Echo

local sqrt, max, abs, huge = math.sqrt, math.max, math.abs, math.huge

local myTeam = spGetMyTeamID()
local spectating = Spring.GetSpectatingState()

--------------------------------------------------------------------------------
-- the board
--------------------------------------------------------------------------------

-- job: {id, def (unitDefID), x, y, z, facing, params, state = "open" | "held" | "active",
--       builder, since (frame it went on the board or was reopened), given (frame its order was given),
--       unit (its nanoframe), tries}
local jobs = {}          -- array, oldest first
local nextJobID = 1
local excluded = {}      -- unitID -> true: builders the board leaves alone
local lastPlan = 0
-- unitID -> {frame, timer, job}: an order of ours that is on its way to the
-- builder. Until it shows in its queue the builder is not idle, whatever its
-- queue says: giving it another order would replace this one.
local ordered = {}

local function Order(unitID, job, frame)
	spGiveOrderToUnit(unitID, -job.def, job.params, 0)
	ordered[unitID] = { frame = frame, timer = Spring.GetTimer(), job = job }
end

-- still waiting for our last order to this builder to arrive?
local function OnItsWay(unitID, frame)
	local o = ordered[unitID]
	if not o then return false end
	if frame - o.frame > TUNE.graceFrames and Spring.DiffTimers(Spring.GetTimer(), o.timer) > TUNE.graceSeconds then
		ordered[unitID] = nil
		return false
	end
	return true, o.job
end

local isCommander = {}
for unitDefID, ud in pairs(UnitDefs) do
	isCommander[unitDefID] = (ud.customParams and ud.customParams.unitrole == "Commander") or false
end

local function Usable(unitID)
	return spValidUnitID(unitID) and not spGetUnitIsDead(unitID) and spGetUnitTeam(unitID) == myTeam
end

local function AddJob(unitDefID, x, y, z, facing)
	if not (unitDefID and UnitDefs[unitDefID] and x and z) then
		return nil
	end
	y = y or spGetGroundHeight(x, z)
	facing = facing or 0
	for i = 1, #jobs do -- placing the same building on the same spot twice is one job
		local j = jobs[i]
		if j.def == unitDefID and abs(j.x - x) < 1 and abs(j.z - z) < 1 then
			return j.id
		end
	end
	local job = {
		id = nextJobID, def = unitDefID, x = x, y = y, z = z, facing = facing,
		params = { x, y, z, facing },
		state = "open", since = spGetGameFrame(), tries = 0,
	}
	nextJobID = nextJobID + 1
	jobs[#jobs + 1] = job
	lastPlan = 0 -- plan on the next frame
	return job.id
end

local function RemoveJobAt(index, stopBuilder)
	local job = table.remove(jobs, index)
	if not job then return end
	if stopBuilder and job.state == "active" and job.builder and Usable(job.builder) then
		local queue = spGetUnitCommands(job.builder, BT.maxQueueRead) or {}
		for i = 1, #queue do
			local cmd = queue[i]
			if cmd.id == -job.def and cmd.params[1] and abs(cmd.params[1] - job.x) < 1 and abs(cmd.params[3] - job.z) < 1 then
				spGiveOrderToUnit(job.builder, CMD.REMOVE, { cmd.tag }, 0)
			end
		end
	end
end

local function Reopen(job, failed)
	job.state = "open"
	job.builder = nil
	job.since = spGetGameFrame()
	if failed then
		job.tries = job.tries + 1
	end
end

-- Is this build order in the builder's queue?
local function HasOrder(unitID, job)
	local queue = spGetUnitCommands(unitID, BT.maxQueueRead) or {}
	for i = 1, #queue do
		local cmd = queue[i]
		if cmd.id == -job.def and cmd.params[1] and abs(cmd.params[1] - job.x) < 1 and abs(cmd.params[3] - job.z) < 1 then
			return true
		end
	end
	return false, #queue
end

--------------------------------------------------------------------------------
-- planning
--------------------------------------------------------------------------------

local function Plan(frame)
	lastPlan = frame
	if #jobs == 0 then
		return
	end

	-- jobs in progress: is each still being done?
	for i = #jobs, 1, -1 do
		local job = jobs[i]
		if job.state == "active" then
			local builder = job.builder
			if not (builder and Usable(builder)) then
				Reopen(job, false)
			else
				local has, count = HasOrder(builder, job)
				-- taking over a half-built frame, the engine may swap the build
				-- order for a repair of it: working on the frame counts as well
				if not has and job.unit and Spring.GetUnitIsBuilding(builder) == job.unit then
					has = true
				end
				if has then
					ordered[builder] = nil -- it arrived
				elseif not OnItsWay(builder, frame) then
					if DEBUG then
						local q = spGetUnitCommands(builder, 4) or {}
						local t = {}
						for k = 1, #q do t[k] = q[k].id .. "@" .. tostring(q[k].params[1]) .. "," .. tostring(q[k].params[3]) end
						spEcho("GBDBG f=" .. frame .. " job " .. job.id .. " (" .. job.x .. "," .. job.z .. " def " .. job.def .. ") not in queue of " .. builder .. ": " .. table.concat(t, " | "))
					end
					-- other orders in its place: the player took the builder. Nothing at
					-- all: the build could not be started, or was stopped.
					Reopen(job, count == 0)
					if job.tries >= TUNE.maxTries then
						spEcho("[Global Build] gave up on a " .. (UnitDefs[job.def].humanName or UnitDefs[job.def].name)
							.. " that could not be built")
						RemoveJobAt(i, false)
					end
				end
			end
		end
	end

	-- the builders the board may use, and when and where each comes free
	local workers = {}
	local units = spGetTeamUnits(myTeam) or {}
	for i = 1, #units do
		local unitID = units[i]
		if not excluded[unitID] and (TUNE.useCommanders or not isCommander[spGetUnitDefID(unitID) or 0]) then
			local info = BT.Info(unitID)
			if info then
				local x, z, time, builds, openEnded = BT.ReadQueue(unitID, info)
				if x and not openEnded then
					local queued = (spGetUnitCommands(unitID, 1) or {})[1] ~= nil
					local worker = {
						unitID = unitID, info = info, x = x, z = z, time = time,
						idle = not queued, first = nil,
					}
					if queued then
						ordered[unitID] = nil
					else
						-- an order of ours has not reached it yet: busy with that
						local coming, job = OnItsWay(unitID, frame)
						if coming then
							worker.idle = false
							worker.time = BT.FinishTime(worker, info, job.def, job.x, job.z)
							worker.x, worker.z = job.x, job.z
						end
					end
					workers[#workers + 1] = worker
				end
			end
		end
	end

	-- waiting jobs, oldest first, as many as are planned in one pass
	local waiting = {}
	for i = 1, #jobs do
		local job = jobs[i]
		if job.state ~= "active" then
			job.state = "open"
			if #waiting < TUNE.maxPlanJobs then
				waiting[#waiting + 1] = job
			end
		end
	end

	-- pair the job and builder with the soonest finish of all, again and again
	while #waiting > 0 and #workers > 0 do
		local bestSlot, bestWorker, bestDone = nil, nil, huge
		for slot = 1, #waiting do
			local job = waiting[slot]
			-- kept back too long for a busy builder: idle ones only now
			local idleOnly = (frame - job.since) > TUNE.holdTime * 30
			for w = 1, #workers do
				local worker = workers[w]
				if worker.info.can[job.def] and not (idleOnly and not worker.idle) then
					local done = BT.FinishTime(worker, worker.info, job.def, job.x, job.z)
					if done < bestDone then
						bestSlot, bestWorker, bestDone = slot, worker, done
					end
				end
			end
		end
		if not bestSlot then
			break -- nobody on the board can build what is left
		end
		local job = table.remove(waiting, bestSlot)
		if not bestWorker.first then
			bestWorker.first = job
			if bestWorker.idle then
				Order(bestWorker.unitID, job, frame)
				if DEBUG then spEcho("GBDBG f=" .. frame .. " give job " .. job.id .. " to " .. bestWorker.unitID) end
				job.state, job.builder, job.given = "active", bestWorker.unitID, frame
			else
				job.state = "held"
			end
		end
		bestWorker.x, bestWorker.z, bestWorker.time = job.x, job.z, bestDone
	end

end

--------------------------------------------------------------------------------
-- what happens to the buildings
--------------------------------------------------------------------------------

local function JobOfUnit(unitID, unitDefID)
	local x, _, z = spGetUnitPosition(unitID)
	if not x then return nil end
	for i = 1, #jobs do
		local job = jobs[i]
		if job.def == unitDefID and abs(job.x - x) < TUNE.matchDist and abs(job.z - z) < TUNE.matchDist then
			return job, i
		end
	end
	return nil
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	if unitTeam == myTeam and #jobs > 0 then
		local job = JobOfUnit(unitID, unitDefID)
		if DEBUG and job then spEcho("GBDBG f=" .. spGetGameFrame() .. " frame " .. unitID .. " created for job " .. job.id) end
		if job then job.unit = unitID end
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if unitTeam == myTeam and #jobs > 0 then
		local job, index = JobOfUnit(unitID, unitDefID)
		if job then
			RemoveJobAt(index, false)
			lastPlan = 0
		end
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if DEBUG then for i = 1, #jobs do if jobs[i].unit == unitID then spEcho("GBDBG f=" .. spGetGameFrame() .. " frame of job " .. jobs[i].id .. " destroyed, state " .. jobs[i].state) end end end
	excluded[unitID] = nil
	ordered[unitID] = nil
	if unitTeam ~= myTeam then return end
	for i = 1, #jobs do
		local job = jobs[i]
		if job.unit == unitID then
			-- Its frame was destroyed (shot, or decayed with nobody on it). A
			-- builder that is on the job still has its order and starts a new
			-- frame; otherwise the job waits on the board again.
			job.unit = nil
			if not (job.state == "active" and job.builder and Usable(job.builder)) then
				Reopen(job, false)
			end
		elseif job.builder == unitID and job.state == "active" then
			Reopen(job, false)
			lastPlan = 0
		end
	end
end

function widget:UnitTaken(unitID, unitDefID, unitTeam)
	widget:UnitDestroyed(unitID, unitDefID, unitTeam)
end

function widget:GameFrame(frame)
	if #jobs > 0 and frame - lastPlan >= TUNE.planInterval then
		Plan(frame)
	end
end

--------------------------------------------------------------------------------
-- placing: sample, place, give the selection back
--------------------------------------------------------------------------------

-- session: {def, proxy, previous = {unitIDs}, started (bool), startFrame (draw frames waited)}
local session = nil

-- Board mode: placed buildings go on the board, not to the selected builder.
local boardMode = false
-- {def, idle}: in board mode, this building is being placed for the selected
-- builder itself (Alt + click on its card). Over when that placing ends.
local direct = nil

local function IsBuilding(unitDefID)
	local ud = unitDefID and UnitDefs[unitDefID]
	return ud ~= nil and not ud.canMove
end

-- Would a build of this, placed now, go on the board?
local function Diverts(unitDefID)
	return boardMode and not spectating and session == nil and IsBuilding(unitDefID)
		and not (direct and direct.def == unitDefID)
end

-- A build order that was about to be given to the selection: puts it on the
-- board when board mode says so. True if the board took it.
local function Intercept(cmdID, params)
	if not (cmdID and cmdID < 0 and params and #params >= 3 and Diverts(-cmdID)) then
		return false
	end
	AddJob(-cmdID, params[1], params[2], params[3], params[4])
	return true
end

-- How many builders the board may use can build each building: [unitDefID] = count.
local capable, capableAt = {}, nil
local function Capable(unitDefID)
	local now = Spring.GetTimer()
	if not capableAt or Spring.DiffTimers(now, capableAt) > 0.5 then
		capableAt = now
		capable = {}
		local units = spGetTeamUnits(myTeam) or {}
		for i = 1, #units do
			local unitID = units[i]
			if not excluded[unitID] and (TUNE.useCommanders or not isCommander[spGetUnitDefID(unitID) or 0]) then
				local info = BT.Info(unitID)
				if info then
					for def in pairs(info.can) do
						capable[def] = (capable[def] or 0) + 1
					end
				end
			end
		end
	end
	return capable[unitDefID] or 0
end

local function SetMode(on)
	on = on and true or false
	if on ~= boardMode then
		boardMode = on
		direct = nil
		spEcho("[Global Build] board mode " .. (on and "on: buildings you place go on the board" or "off"))
	end
	return boardMode
end

local function EndSession()
	if not session then return end
	local s = session
	session = nil
	local back = {}
	for i = 1, #s.previous do
		if spValidUnitID(s.previous[i]) then
			back[#back + 1] = s.previous[i]
		end
	end
	spSelectUnitArray(back)
end

-- A builder that can build this, to stand in as the selection while placing:
-- the nearest to (x, z).
local function FindProxy(unitDefID, x, z)
	local best, bestDist = nil, huge
	local units = spGetTeamUnits(myTeam) or {}
	for i = 1, #units do
		local info = BT.Info(units[i])
		if info and info.can[unitDefID] then
			local ux, _, uz = spGetUnitPosition(units[i])
			local d = (ux - x) ^ 2 + (uz - z) ^ 2
			if d < bestDist then
				best, bestDist = units[i], d
			end
		end
	end
	return best
end

-- Starts placing this building for the board. Returns false when no builder
-- of yours can build it.
local function StartSession(unitDefID, x, z)
	if spectating then return false end
	if session then EndSession() end
	local proxy = FindProxy(unitDefID, x or 0, z or 0)
	if not proxy then
		return false
	end
	session = { def = unitDefID, proxy = proxy, previous = spGetSelectedUnits() or {}, started = false, waited = 0 }
	spSelectUnitArray({ proxy })
	return true
end

function widget:Update()
	if direct then
		-- placing for the selected builder itself: over when that command is let go
		local _, active = spGetActiveCommand()
		if active == -direct.def then
			direct.idle = 0
		else
			direct.idle = direct.idle + 1
			if direct.idle >= 3 then
				direct = nil
			end
		end
	end
	if not session then return end
	local _, cmdID = spGetActiveCommand()
	if not session.started then
		-- the stand-in's commands arrive a frame or two after it is selected
		local index = spGetCmdDescIndex(-session.def)
		if index then
			local alt, ctrl, meta, shift = spGetModKeyState()
			spSetActiveCommand(index, 1, true, false, false, ctrl, meta, shift)
			session.started = true
			session.idle = 0
		else
			session.waited = session.waited + 1
			if session.waited > 30 then
				EndSession() -- it never got the command: cannot be built right now
			end
		end
		return
	end
	if cmdID == -session.def then
		session.idle = 0
	else
		-- placing is over (a click without Shift, a right click, another command)
		session.idle = session.idle + 1
		if session.idle >= 2 then
			EndSession()
		end
	end
end

function widget:CommandNotify(cmdID, cmdParams, cmdOpts)
	if not session then
		return Intercept(cmdID, cmdParams) -- board mode
	end
	if cmdID == -session.def and cmdParams and #cmdParams >= 3 then
		AddJob(session.def, cmdParams[1], cmdParams[2], cmdParams[3], cmdParams[4])
		return true -- on the board: the stand-in is not ordered to build it
	end
	return false
end

-- the unit under the mouse, if it is a building one of your builders can build
local function SampleAt(mx, my)
	local kind, unitID = spTraceScreenRay(mx, my)
	if kind ~= "unit" then return nil end
	local unitDefID = spGetUnitDefID(unitID)
	local ud = unitDefID and UnitDefs[unitDefID]
	if not ud or ud.canMove then return nil end
	local x, _, z = spGetUnitPosition(unitID)
	return unitDefID, x, z
end

local function JobAt(mx, my)
	local kind, pos = spTraceScreenRay(mx, my, true)
	if kind ~= "ground" then return nil end
	local best, bestDist = nil, huge
	for i = 1, #jobs do
		local job = jobs[i]
		local ud = UnitDefs[job.def]
		local half = max(ud.xsize, ud.zsize) * 4 + 8
		local dx, dz = abs(job.x - pos[1]), abs(job.z - pos[3])
		if dx <= half and dz <= half and dx + dz < bestDist then
			best, bestDist = i, dx + dz
		end
	end
	return best
end

function widget:MousePress(mx, my, button)
	if spectating then return false end
	local alt, ctrl, meta, shift = spGetModKeyState()
	if not alt or ctrl or meta or shift then return false end
	local _, cmdID = spGetActiveCommand()
	if cmdID then return false end -- Alt means something else while a command is being given
	if button == 1 then
		local unitDefID, x, z = SampleAt(mx, my)
		if unitDefID and StartSession(unitDefID, x, z) then
			return true
		end
	elseif button == 3 and #jobs > 0 then
		local index = JobAt(mx, my)
		if index then
			RemoveJobAt(index, true)
			return true
		end
	end
	return false
end

function widget:MouseRelease() return false end

function widget:KeyPress(key, mods, isRepeat)
	if isRepeat or not mods.alt or mods.ctrl or mods.shift or mods.meta then return false end
	if key == Spring.GetKeyCode(MODE_KEY) and not spectating then
		SetMode(not boardMode)
		return true
	end
	if key ~= Spring.GetKeyCode(EXCLUDE_KEY) then return false end
	local selected = spGetSelectedUnits() or {}
	local builders, anyIn = {}, false
	for i = 1, #selected do
		if BT.Info(selected[i]) then
			builders[#builders + 1] = selected[i]
			if not excluded[selected[i]] then anyIn = true end
		end
	end
	if #builders == 0 then return false end
	for i = 1, #builders do
		excluded[builders[i]] = anyIn or nil
	end
	capableAt = nil
	spEcho("[Global Build] " .. #builders .. (anyIn and " builder(s) taken off the board" or " builder(s) back on the board"))
	lastPlan = 0
	return true
end

function widget:PlayerChanged()
	myTeam = spGetMyTeamID()
	spectating = Spring.GetSpectatingState()
end

--------------------------------------------------------------------------------
-- drawing: the jobs on the ground, the tag by the cursor, a ring under builders kept off the board
--------------------------------------------------------------------------------

local STATE_COLOR = {
	open   = { 0.94, 0.96, 0.97 },
	held   = { 1.00, 0.86, 0.25 },
	active = { 0.43, 0.86, 0.55 },
}

local function Footprint(job)
	local ud = UnitDefs[job.def]
	local hx, hz = ud.xsize * 4, ud.zsize * 4
	if job.facing == 1 or job.facing == 3 then hx, hz = hz, hx end
	return hx, hz
end

local function JobOutline(x, y, z, hx, hz)
	local c = math.min(hx, hz) * 0.45
	-- four corner brackets and a cross in the middle
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			gl.Vertex(x + sx * hx, y, z + sz * (hz - c)); gl.Vertex(x + sx * hx, y, z + sz * hz)
			gl.Vertex(x + sx * hx, y, z + sz * hz);       gl.Vertex(x + sx * (hx - c), y, z + sz * hz)
		end
	end
	local k = math.min(hx, hz) * 0.25
	gl.Vertex(x - k, y, z); gl.Vertex(x + k, y, z)
	gl.Vertex(x, y, z - k); gl.Vertex(x, y, z + k)
end

function widget:DrawWorldPreUnit()
	if #jobs == 0 and not next(excluded) then return end
	gl.DepthTest(false)
	gl.LineWidth(2)
	local pulse = 0.65 + 0.25 * math.sin(Spring.GetGameFrame() * 0.12)
	for i = 1, #jobs do
		local job = jobs[i]
		local c = STATE_COLOR[job.state] or STATE_COLOR.open
		local hx, hz = Footprint(job)
		gl.Color(c[1], c[2], c[3], job.state == "active" and 0.9 or pulse)
		gl.BeginEnd(GL.LINES, JobOutline, job.x, spGetGroundHeight(job.x, job.z) + 3, job.z, hx, hz)
	end
	for unitID in pairs(excluded) do
		local x, y, z = spGetUnitPosition(unitID)
		if x then
			gl.Color(0.52, 0.58, 0.63, 0.7)
			gl.DrawGroundCircle(x, y, z, 22, 20)
		end
	end
	gl.LineWidth(1)
	gl.Color(1, 1, 1, 1)
end

-- The building itself, see-through, on every job that has no frame yet: what
-- the engine shows for the queue of a selected builder, but for the board.
-- A job whose builder is selected is left to the engine, which draws its own.
local GHOST_MAX = 150 -- ghosts drawn in one frame

local function GhostHeight(job, ud)
	local ground = spGetGroundHeight(job.x, job.z)
	if ground < 0 and ud.floatOnWater then
		return -(ud.waterline or 0)
	end
	return ground
end

function widget:DrawWorld()
	if #jobs == 0 or Spring.IsGUIHidden() then return end
	local drawn = 0
	gl.DepthTest(true)
	gl.Color(1, 1, 1, 1)
	for i = 1, #jobs do
		local job = jobs[i]
		local hasFrame = job.unit and spValidUnitID(job.unit)
		local engineDraws = job.state == "active" and job.builder and Spring.IsUnitSelected(job.builder)
		if not hasFrame and not engineDraws then
			local ud = UnitDefs[job.def]
			local y = GhostHeight(job, ud)
			local r = max(ud.xsize, ud.zsize) * 4
			if Spring.IsAABBInView(job.x - r, y, job.z - r, job.x + r, y + (ud.height or 40), job.z + r) then
				gl.PushMatrix()
				gl.Translate(job.x, y, job.z)
				gl.Rotate(job.facing * 90, 0, 1, 0)
				gl.UnitShape(job.def, myTeam, false, true, false) -- engine state, see-through; 4th argument true: our matrix already holds the camera
				gl.PopMatrix()
				drawn = drawn + 1
				if drawn >= GHOST_MAX then break end
			end
		end
	end
	gl.DepthTest(false)
	gl.Color(1, 1, 1, 1)
end

function widget:DrawScreen()
	if not session then
		-- board mode: the tag shows while a building is being placed for the board
		local _, cmdID = spGetActiveCommand()
		if not (cmdID and cmdID < 0 and Diverts(-cmdID)) then return end
	end
	local mx, my = spGetMouseState()
	local waiting = 0
	for i = 1, #jobs do
		if jobs[i].state ~= "active" then waiting = waiting + 1 end
	end
	gl.Color(1, 0.61, 0.13, 1)
	gl.Text("GLOBAL BUILD" .. (waiting > 0 and ("  \255\240\244\248" .. waiting .. " waiting") or ""), mx + 22, my - 30, 13, "o")
	gl.Color(1, 1, 1, 1)
end

--------------------------------------------------------------------------------

function widget:Initialize()
	WG.globalBuild = {
		-- puts a build on the board; returns the job's id
		AddJob       = AddJob,
		-- {id, def, x, z, state, builder} for every job
		GetJobs      = function()
			local list = {}
			for i = 1, #jobs do
				local j = jobs[i]
				list[i] = { id = j.id, def = j.def, x = j.x, z = j.z, state = j.state, builder = j.builder, tries = j.tries }
			end
			return list
		end,
		ClearJobs    = function() for i = #jobs, 1, -1 do RemoveJobAt(i, true) end end,
		-- starts placing this building for the board, as an Alt-click on one does
		StartSession = StartSession,
		EndSession   = EndSession,
		InSession    = function() return session ~= nil, session and session.started or false end,
		-- board mode: buildings placed with a builder selected go on the board
		GetMode      = function() return boardMode end,
		SetMode      = SetMode,
		-- in board mode: this building, placed next, is for the selected builder after all
		DirectOnce   = function(unitDefID) direct = { def = unitDefID, idle = 0 } end,
		-- would a build of this, placed now, go on the board? (no side effects)
		Diverts      = Diverts,
		-- for whoever gives build orders itself: Intercept(cmdID, params) puts the
		-- order on the board if board mode says so, and returns true if it did
		Intercept    = Intercept,
		-- how many builders the board may use can build this
		Capable      = Capable,
		SetExcluded  = function(unitID, off) excluded[unitID] = off and true or nil; lastPlan = 0; capableAt = nil end,
		IsExcluded   = function(unitID) return excluded[unitID] == true end,
		tune         = TUNE,
	}
end

function widget:Shutdown()
	if session then EndSession() end
	WG.globalBuild = nil
end
