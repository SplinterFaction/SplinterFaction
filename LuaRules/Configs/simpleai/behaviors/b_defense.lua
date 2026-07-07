--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    luarules/configs/simpleai/behaviors/b_defense.lua
--  brief:   Defense intel for the SimpleAI gadget (stage 4 of the modular
--           split). Runs FIRST each team tick (order 10): finds the enemy
--           intruder nearest the base centre and publishes it as
--           tick.baseThreat / ctx.intel.baseThreat for every other behavior
--           (combat suppresses launches and sics the home guard on it; the
--           reactive-turret priority in construction reads underAttack).
--
--           Owns ctx state: ctx.intel.baseThreat.
--
--  license: GNU GPL, v2 or later
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return function(ctx, lib, cfg)

	--------------------------------------------------------------------------
	-- Tunables (owned by this behavior)
	--------------------------------------------------------------------------
	local BASE_DEFEND_RADIUS = 1600  -- enemy within this range of base centre is an "intruder"

	local gaiaTeamID       = cfg.gaiaTeamID
	local SimpleBaseThreat = ctx.intel.baseThreat

	local B = { name = "defense", order = 10 }

	function B.TeamInit(teamID)
		SimpleBaseThreat[teamID] = nil
	end

	--------------------------------------------------------------------------
	-- Base intruder detection
	-- Find the enemy unit nearest our base centre that's inside the
	-- defend radius. The home guard will hunt it down. This is what
	-- stops units strolling past raiders chewing on the base.
	--------------------------------------------------------------------------
	function B.TeamTick(tick)
		local teamID = tick.teamID
		local units  = tick.units

		local baseThreat = nil
		do
			local bx, bz, bc = 0, 0, 0
			for k = 1, #units do
				local uDefID = Spring.GetUnitDefID(units[k])
				if uDefID and UnitDefs[uDefID] and UnitDefs[uDefID].isBuilding then
					local px, _, pz = Spring.GetUnitPosition(units[k])
					bx = bx + px; bz = bz + pz; bc = bc + 1
				end
			end
			if bc > 0 then
				bx, bz = bx / bc, bz / bc
				local near = Spring.GetUnitsInCylinder(bx, bz, BASE_DEFEND_RADIUS)
				local bestD
				for _, eu in ipairs(near) do
					local et = Spring.GetUnitTeam(eu)
					if et ~= teamID and et ~= gaiaTeamID
							and not Spring.AreTeamsAllied(teamID, et) then
						local ex, ey, ez = Spring.GetUnitPosition(eu)
						local dx, dz = ex - bx, ez - bz
						local d = dx * dx + dz * dz
						if not bestD or d < bestD then
							bestD = d
							baseThreat = { x = ex, y = ey, z = ez, uid = eu }
						end
					end
				end
			end
		end
		SimpleBaseThreat[teamID] = baseThreat
		tick.baseThreat = baseThreat
	end

	return B
end
