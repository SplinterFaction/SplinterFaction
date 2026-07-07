--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    luarules/configs/simpleai/behaviors/b_commander.lua
--  brief:   Commander behavior for the SimpleAI gadget (stage 4 of the modular
--           split). Owns the commander's survival state machine (committed-
--           haven retreat, so it runs in ONE direction instead of re-rolling
--           every time it's hit), self-defence, and idle building — the last
--           via services.SelectConstructionProject, which b_construction
--           registers, so that module must appear before this one in the
--           core's BEHAVIOR_FILES manifest.
--
--           Owns ctx state: ctx.comm.retreating, ctx.comm.retreatPos.
--
--  license: GNU GPL, v2 or later
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return function(ctx, lib, cfg, services)

	--------------------------------------------------------------------------
	-- Tunables (owned by this behavior)
	--------------------------------------------------------------------------
	local COMM_RETREAT_HP   = 0.65   -- commander starts running below this EFFECTIVE hp fraction
	local COMM_DANGER_R     = 750    -- enemy within this range counts as "in danger" while retreating
	local COMM_HAVEN_REACH  = 250    -- considered "arrived" at a haven within this distance

	local IsCommander          = ctx.IsCommander
	local SimpleCommRetreating = ctx.comm.retreating
	local SimpleCommRetreatPos = ctx.comm.retreatPos

	local FindCommanderHaven = lib.FindCommanderHaven

	local B = { name = "commander", order = 20 }

	function B.TeamInit(teamID)
		SimpleCommRetreating[teamID] = false
		SimpleCommRetreatPos[teamID] = nil
	end

	--------------------------------------------------------------------------
	-- Ownership: commanders.
	--------------------------------------------------------------------------
	function B.unitFilter(unitDefID)
		return IsCommander[unitDefID] == true
	end

	--------------------------------------------------------------------------
	-- Per-unit commander logic.
	--------------------------------------------------------------------------
	function B.UnitTick(tick, unitID, unitDefID, hpRatio, ux, uy, uz, unitCmds)
		local teamID     = tick.teamID
		local allyTeamID = tick.allyTeamID
		local units      = tick.units
		local allunits   = tick.allUnits

		local nearEnemy = Spring.GetUnitNearestEnemy(unitID, COMM_DANGER_R, true)

		if SimpleCommRetreating[teamID] then
			-- Already fleeing. Commit to the chosen haven; only re-issue
			-- an order when we genuinely need to, so the commander runs
			-- in one direction instead of re-rolling every time it's hit.
			if not nearEnemy then
				-- Threat gone: stop fleeing, resume normal duties next tick.
				SimpleCommRetreating[teamID] = false
				SimpleCommRetreatPos[teamID] = nil
			else
				local rp = SimpleCommRetreatPos[teamID]
				local needNew = (rp == nil)
				if rp then
					local dx, dz = ux - rp.x, uz - rp.z
					if (dx * dx + dz * dz) < (COMM_HAVEN_REACH * COMM_HAVEN_REACH) then
						-- Reached the haven but still in danger: pick a fresh one.
						needNew = true
					end
				end
				if needNew then
					rp = FindCommanderHaven(unitID, teamID, nearEnemy)
					SimpleCommRetreatPos[teamID] = rp
					if rp then
						Spring.GiveOrderToUnit(unitID, CMD.MOVE,
						                       { rp.x, rp.y, rp.z }, 0)
					end
				elseif unitCmds == 0 and rp then
					-- Order queue emptied unexpectedly: resume toward the
					-- SAME committed haven (do not pick a new direction).
					Spring.GiveOrderToUnit(unitID, CMD.MOVE,
					                       { rp.x, rp.y, rp.z }, 0)
				end
				-- Otherwise: leave the existing move order alone.
			end

		elseif nearEnemy and hpRatio <= COMM_RETREAT_HP then
			-- Drop into retreat: choose ONE haven and commit to it.
			local rp = FindCommanderHaven(unitID, teamID, nearEnemy)
			SimpleCommRetreating[teamID] = true
			SimpleCommRetreatPos[teamID] = rp
			if rp then
				Spring.GiveOrderToUnit(unitID, CMD.MOVE,
				                       { rp.x, rp.y, rp.z }, 0)
			end

		elseif nearEnemy and unitCmds == 0 then
			-- Healthy and enemy nearby: fight back
			local tx, ty, tz = Spring.GetUnitPosition(nearEnemy)
			Spring.GiveOrderToUnit(unitID, CMD.FIGHT, { tx, ty, tz }, 0)

		elseif unitCmds == 0 then
			-- Idle: build something
			services.SelectConstructionProject(
					unitID, unitDefID, teamID, allyTeamID,
					units, allunits, "Commander")
		end
	end

	return B
end
