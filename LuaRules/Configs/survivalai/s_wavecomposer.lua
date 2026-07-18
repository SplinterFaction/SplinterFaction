--------------------------------------------------------------------------------
--
--  file:    s_wavecomposer.lua  (Survival AI module)
--  brief:   Turns a metal budget into a shopping list of units. Phase 1 is a
--           deliberately simple uniform-random spend over all tier-eligible
--           entries; wave archetypes (raid / siege / air / deathball) land in
--           Phase 2 as role-weight tables over the same pools.
--
--           Pure module: no engine state. `random` is injected (math.random in
--           the gadget, a seeded stand-in under test).
--
--------------------------------------------------------------------------------

local M = {}

--------------------------------------------------------------------------------
-- M.Compose(pools, budget, maxTier, maxUnits, random) -> unitList, spent
--
-- unitList = { entry, entry, ... }  (references into pools.entries)
-- Guarantees at least one unit (the cheapest eligible) even if the budget is
-- below its cost, so an early wave is never silently empty.
--------------------------------------------------------------------------------

function M.Compose(pools, budget, maxTier, maxUnits, random)
	random = random or math.random

	-- Entries unlocked at this tier
	local eligible = {}
	local cheapest = nil
	for i = 1, #pools.entries do
		local e = pools.entries[i]
		if e.tier <= maxTier then
			eligible[#eligible + 1] = e
			if (not cheapest) or e.cost < cheapest.cost then cheapest = e end
		end
	end

	local list, spent = {}, 0
	if not cheapest then return list, spent end   -- empty pools (misconfigured mod)

	local remaining = budget
	while #list < maxUnits do
		-- Affordable subset under the remaining budget
		local afford = {}
		for i = 1, #eligible do
			if eligible[i].cost <= remaining then
				afford[#afford + 1] = eligible[i]
			end
		end
		if #afford == 0 then break end

		local pick = afford[random(1, #afford)]
		list[#list + 1] = pick
		spent     = spent + pick.cost
		remaining = remaining - pick.cost
	end

	-- Never send an empty wave
	if #list == 0 then
		list[1] = cheapest
		spent   = cheapest.cost
	end

	return list, spent
end

--------------------------------------------------------------------------------
-- M.Budget(waveNumber, base, linear, compound, mult) -> metal budget
--
-- budget = base * (1 + linear*(n-1)) * compound^(n-1) * difficultyMult
-- Linear keeps early waves readable; compound makes the late game a problem.
--------------------------------------------------------------------------------

function M.Budget(waveNumber, base, linear, compound, mult)
	local n = waveNumber
	return math.floor(base * (1 + linear * (n - 1)) * (compound ^ (n - 1)) * (mult or 1))
end

return M
