--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    luarules/configs/simpleai/behaviors/b_economy.lua
--  brief:   Economy behavior for the SimpleAI gadget (stage 4 of the modular
--           split). Currently owns the Build Boost policy: spending Research
--           Points on temporary factory production surges. Runs after defense
--           intel (order 30) and before combat, preserving the original tick
--           order (threat scan -> boost -> squad transitions).
--
--           Owns ctx state: ctx.pacing.lastBoost.
--           Reads: ctx.intel.underAttack, ctx.techLevel, ctx.BoostCost,
--                  ctx.IsFactory, tick.overflowing.
--
--  license: GNU GPL, v2 or later
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return function(ctx, lib, cfg)

	--------------------------------------------------------------------------
	-- Tunables (owned by this behavior)
	-- Keep CMD id and default cost in sync with unit_research_buildboost.lua
	-- (CMD_BUILD_BOOST / DEF_COST).
	--------------------------------------------------------------------------
	local CMD_BUILD_BOOST   = 35410
	local BOOST_RP_RESERVE  = 150    -- RP kept back for commander morphs; waived at tech 4
	local BOOST_COOLDOWN    = 300    -- min frames between boosts per team (~10s)

	local IsFactory         = ctx.IsFactory
	local BoostCost         = ctx.BoostCost
	local TeamTechLevel     = ctx.techLevel
	local SimpleUnderAttack = ctx.intel.underAttack
	local SimpleLastBoost   = ctx.pacing.lastBoost

	local B = { name = "economy", order = 30 }

	function B.TeamInit(teamID)
		SimpleLastBoost[teamID] = 0
	end

	--------------------------------------------------------------------------
	-- Build Boost policy
	-- Spend RP on a factory surge in exactly two moments it pays:
	-- resources overflowing (banked surplus -> units NOW, alongside
	-- the new-factory overflow response) or the base under attack.
	-- A reserve protects the commander's morph RP until tech is
	-- maxed, and a per-team cooldown stops one tick from boosting
	-- every factory at once.
	--------------------------------------------------------------------------
	function B.TeamTick(tick)
		if not GG.Research then return end

		local n      = tick.frame
		local teamID = tick.teamID
		local units  = tick.units

		local boostReady = (n - (SimpleLastBoost[teamID] or 0)) >= BOOST_COOLDOWN
		if boostReady and (tick.overflowing or SimpleUnderAttack[teamID]) then
			local reserve = ((TeamTechLevel[teamID] or 1) >= 4)
					and 0 or BOOST_RP_RESERVE
			for k = 1, #units do
				local uid    = units[k]
				local uDefID = Spring.GetUnitDefID(uid)
				local cost   = uDefID and BoostCost[uDefID]
				if cost and IsFactory[uDefID]
						and GG.Research.CanAfford(teamID, cost + reserve) then
					local endF = Spring.GetUnitRulesParam(uid, "buildboost_end") or 0
					local _, _, _, _, bp = Spring.GetUnitHealth(uid)
					if endF <= n and ((bp == nil) or bp >= 1)
							and #Spring.GetFullBuildQueue(uid, 0) > 0 then
						Spring.GiveOrderToUnit(uid, CMD_BUILD_BOOST, {}, 0)
						SimpleLastBoost[teamID] = n
						break
					end
				end
			end
		end
	end

	return B
end
