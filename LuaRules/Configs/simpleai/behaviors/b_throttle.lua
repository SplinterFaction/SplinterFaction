--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    luarules/configs/simpleai/behaviors/b_throttle.lua
--  brief:   Demand throttle for the SimpleAI gadget. When a team is stalling
--           (it wants to spend more than it earns and has no bank left; see
--           the stall signal in the core), every consumer gets a thin slice
--           and nothing finishes. This behavior sheds factory demand until
--           what is left can actually be paid for, the way a player does:
--
--             PAUSE   put factories on WAIT one at a time while the stall
--                     lasts, so the rest build at full speed. Nothing is
--                     thrown away; the paused build resumes where it stopped.
--             RESUME  take them off WAIT one at a time once the stall clears.
--             CANCEL  in a bad ENERGY stall, drop a build that has barely
--                     started and costs several times the energy of the
--                     factory's cheapest unit.
--                     The engine refunds the METAL spent on a cancelled
--                     factory build (CFactory::StopBuild); the energy is
--                     lost, hence "barely started" only. b_construction then
--                     queues something cheaper (it leans toward cheap units
--                     while the team is stalling).
--
--           WAIT is read straight from each factory's own build queue, so
--           this file keeps no list of paused factories that could go stale.
--           b_construction queues nothing on a waiting factory.
--
--           Owns ctx state: ctx.stall.paused (count, for the decision trace).
--           Reads: ctx.stall, tick.stall, tick.units, ctx.IsFactory, ctx.IsCombat.
--           Trace keys: stall.pause, stall.resume, stall.cancel.
--
--  license: GNU GPL, v2 or later
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return function(ctx, lib, cfg)

	--------------------------------------------------------------------------
	-- Tunables (owned by this behavior). The stall thresholds themselves are
	-- owned by the core (STALL_ON / STALL_OFF / STALL_HARD).
	--------------------------------------------------------------------------
	local STALL_ON        = cfg.STALL_ON   or 0.20
	local STALL_OFF       = cfg.STALL_OFF  or 0.08
	local STALL_HARD      = cfg.STALL_HARD or 0.45

	local MIN_ACTIVE      = 1      -- never pause the last working factory
	local PAUSE_SPACING   = 150    -- min frames between pause steps per team (~5s)
	local RESUME_SPACING  = 300    -- min frames after any step before a resume (~10s); slower than
	                               -- pausing on purpose, so the two do not chase each other
	local CANCEL_SPACING  = 300    -- min frames between cancels per team (~10s)
	local CANCEL_PROGRESS = 0.20   -- only cancel builds less complete than this
	local CANCEL_RATIO    = 2.0    -- ...that cost more than this x the factory's cheapest combat unit

	local IsFactory = ctx.IsFactory
	local IsCombat  = ctx.IsCombat
	local stallE    = ctx.stall.e
	local paused    = ctx.stall.paused
	local trace     = ctx.trace or {}

	local CMD_WAIT  = CMD.WAIT

	-- [factoryDefID] = energy cost of the cheapest combat unit it can build
	local cheapest = {}
	local function CheapestFor(factoryDefID)
		local c = cheapest[factoryDefID]
		if c then return c end
		c = math.huge
		local options = UnitDefs[factoryDefID].buildOptions or {}
		for i = 1, #options do
			if IsCombat[options[i]] then
				local cost = UnitDefs[options[i]].energyCost
				if cost and cost > 0 and cost < c then c = cost end
			end
		end
		cheapest[factoryDefID] = c
		return c
	end

	-- per-team pacing
	local lastStep   = {}   -- [teamID] = frame of the last pause/resume
	local lastCancel = {}   -- [teamID] = frame of the last cancel

	-- scratch, reused every tick
	local activeIDs, activeProg, waitingIDs, waitingProg = {}, {}, {}, {}

	local function Tally(teamID, key)
		local t = trace[teamID]
		if t then t[key] = (t[key] or 0) + 1 end
	end

	local B = { name = "throttle", order = 32 }

	function B.TeamInit(teamID)
		lastStep[teamID], lastCancel[teamID] = -PAUSE_SPACING, -CANCEL_SPACING
		paused[teamID] = 0
	end

	function B.TeamTick(tick)
		local teamID = tick.teamID
		local stall  = tick.stall or 0

		-- Nothing to do: not stalling and nothing of ours is on WAIT.
		if stall < STALL_OFF and (paused[teamID] or 0) == 0 then return end

		local now    = tick.frame
		local eStall = stallE[teamID] or 0

		-- Census of this team's finished factories: working vs waiting, with
		-- the progress of whatever each has on the pad (-1 = pad empty).
		local nActive, nWaiting = 0, 0
		local cancelFac, cancelDef, cancelWorst = nil, nil, CANCEL_RATIO
		local units = tick.units
		for i = 1, #units do
			local unitID    = units[i]
			local unitDefID = Spring.GetUnitDefID(unitID)
			if unitDefID and IsFactory[unitDefID] then
				local _, _, _, _, facProgress = Spring.GetUnitHealth(unitID)
				if facProgress == nil or facProgress >= 1 then
					local head    = Spring.GetFactoryCommands(unitID, 1)
					local waiting = head and head[1] and head[1].id == CMD_WAIT
					local buildee = Spring.GetUnitIsBuilding(unitID)
					local progress = -1
					local buildeeDef
					if buildee then
						local _, _, _, _, bp = Spring.GetUnitHealth(buildee)
						progress   = bp or 0
						buildeeDef = Spring.GetUnitDefID(buildee)
					end
					if waiting then
						nWaiting = nWaiting + 1
						waitingIDs[nWaiting], waitingProg[nWaiting] = unitID, progress
					else
						nActive = nActive + 1
						activeIDs[nActive], activeProg[nActive] = unitID, progress
						-- Cancel candidate: barely started, combat, and far
						-- pricier in energy than this factory's cheapest
						-- option. Keep the worst offender.
						if buildeeDef and IsCombat[buildeeDef] and progress < CANCEL_PROGRESS then
							local cost  = UnitDefs[buildeeDef].energyCost
							local floor = CheapestFor(unitDefID)
							if cost and floor > 0 and floor < math.huge then
								local ratio = cost / floor
								if ratio > cancelWorst then
									cancelFac, cancelDef, cancelWorst = unitID, buildeeDef, ratio
								end
							end
						end
					end
				end
			end
		end
		paused[teamID] = nWaiting

		-- CANCEL (bad energy stall only): swap the worst barely-started
		-- expensive build for whatever b_construction queues next. "right" on
		-- a build order removes copies of it; "alt" takes them from the FRONT
		-- of the queue (the one on the pad first) and "ctrl"+"shift" makes it
		-- every queued copy, so the same unit is not simply started again.
		-- The engine refunds the metal already spent on the pad.
		if eStall >= STALL_HARD and cancelFac
				and (now - (lastCancel[teamID] or 0)) >= CANCEL_SPACING then
			Spring.GiveOrderToUnit(cancelFac, -cancelDef, {}, { "right", "alt", "ctrl", "shift" })
			lastCancel[teamID] = now
			Tally(teamID, "stall.cancel")
		end

		-- PAUSE / RESUME, one factory per step.
		if (now - (lastStep[teamID] or 0)) < PAUSE_SPACING then return end

		if stall >= STALL_ON and nActive > MIN_ACTIVE then
			-- Pause the factory with the least sunk into its current build
			-- (an empty pad counts as least).
			local pick, least = 1, activeProg[1]
			for i = 2, nActive do
				if activeProg[i] < least then pick, least = i, activeProg[i] end
			end
			Spring.GiveOrderToUnit(activeIDs[pick], CMD_WAIT, {}, 0)
			lastStep[teamID] = now
			paused[teamID]   = nWaiting + 1
			Tally(teamID, "stall.pause")

		elseif stall <= STALL_OFF and nWaiting > 0
				and (now - (lastStep[teamID] or 0)) >= RESUME_SPACING then
			-- Resume the one closest to finishing its build.
			local pick, most = 1, waitingProg[1]
			for i = 2, nWaiting do
				if waitingProg[i] > most then pick, most = i, waitingProg[i] end
			end
			Spring.GiveOrderToUnit(waitingIDs[pick], CMD_WAIT, {}, 0)
			lastStep[teamID] = now
			paused[teamID]   = nWaiting - 1
			Tally(teamID, "stall.resume")
		end
	end

	return B
end
