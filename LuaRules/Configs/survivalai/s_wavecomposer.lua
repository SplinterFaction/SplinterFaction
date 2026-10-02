--------------------------------------------------------------------------------
--
--  file:    s_wavecomposer.lua  (Survival AI module)
--  brief:   Turns a metal budget into a shopping list of units. Waves have
--           archetypes -- role-class weight tables over the pools -- so an
--           "assault" wave is MBT-heavy, a "raid" wave is scouts and heatrays,
--           a "siege" wave is artillery with escort, and so on. Waves may also
--           be faction-pure for flavor.
--
--           Classes come from s_pools' unitrole classifier: scout, mbt,
--           artillery, aa, heat, bomber, fighter, support, other.
--
--           Pure module: no engine state. `random` is injected (math.random in
--           the gadget, a seeded stand-in under test).
--
--------------------------------------------------------------------------------

local M = {}

--------------------------------------------------------------------------------
-- Wave archetypes. `w` is the selection weight, `minWave` gates late-game
-- flavors (no bomber waves before the players can have AA), and `weights` maps
-- role classes to pick weights (nil = uniform over everything: the horde).
-- Classes absent from a table are never picked for that archetype.
--
-- `stage` is how many beacons launch the wave: a number takes the beacons
-- nearest the target, "all" uses the whole network. `split` gives every
-- staging group its own target (multi-direction harassment) instead of
-- converging the wave on one.
--------------------------------------------------------------------------------

M.Archetypes = {
	{ name = "assault", w = 4, minWave = 1, stage = 3,
	  weights = { mbt = 6, heat = 2, support = 1, aa = 1 } },
	{ name = "raid",    w = 3, minWave = 1, stage = "all", split = true,
	  weights = { scout = 5, heat = 3, mbt = 2, gunship = 2 } },
	{ name = "siege",   w = 3, minWave = 3, stage = 1,
	  weights = { artillery = 5, mbt = 3, aa = 1, support = 1 } },
	{ name = "air",     w = 2, minWave = 5, stage = 2,
	  weights = { bomber = 5, fighter = 3, gunship = 3 } },
	{ name = "drop",    w = 2, minWave = 6, stage = 1, drop = true,
	  weights = { mbt = 4, heat = 2, scout = 2, support = 1 } },
	{ name = "horde",   w = 2, minWave = 1, stage = 3,
	  weights = nil },
}

-- A drop wave needs at least one carrier and one rider at this tier.
local function DropViable(pools, arch, maxTier)
	local carrier, rider = false, false
	for i = 1, #pools.entries do
		local e = pools.entries[i]
		if e.tier <= maxTier then
			if e.class == "gunship" and (e.cap or 0) > 0 then carrier = true end
			if e.portable and arch.weights[e.class] then rider = true end
		end
		if carrier and rider then return true end
	end
	return false
end

-- Does this archetype have at least one unit to buy at this tier?
local function ArchetypeViable(pools, arch, maxTier)
	if arch.drop then return DropViable(pools, arch, maxTier) end
	if not arch.weights then return #pools.entries > 0 end
	for i = 1, #pools.entries do
		local e = pools.entries[i]
		if e.tier <= maxTier and arch.weights[e.class] then
			return true
		end
	end
	return false
end

-- Exports for forced-archetype selection (surge waves): name lookup and the
-- same viability test PickArchetype uses.
M.ByName = {}
for i = 1, #M.Archetypes do
	M.ByName[M.Archetypes[i].name] = M.Archetypes[i]
end
M.IsViable = ArchetypeViable

-- M.PickArchetype(pools, waveNumber, maxTier, random) -> archetype table
function M.PickArchetype(pools, waveNumber, maxTier, random)
	random = random or math.random
	local viable, total = {}, 0
	for i = 1, #M.Archetypes do
		local a = M.Archetypes[i]
		if waveNumber >= a.minWave and ArchetypeViable(pools, a, maxTier) then
			viable[#viable + 1] = a
			total = total + a.w
		end
	end
	if #viable == 0 then return M.Archetypes[#M.Archetypes] end   -- horde fallback

	local roll, acc = random() * total, 0
	for i = 1, #viable do
		acc = acc + viable[i].w
		if roll <= acc then return viable[i] end
	end
	return viable[#viable]
end

--------------------------------------------------------------------------------
-- M.Compose(pools, budget, opts) -> unitList, spent
--
-- opts = {
--   maxTier  = highest unlocked tier          (default: everything)
--   maxUnits = wave size cap                  (default: 40)
--   weights  = { class = weight, ... } or nil (nil = uniform)
--   faction  = faction-name filter or nil     (falls back to mixed if empty)
--   random   = rng                            (default math.random)
--   tierLimit = { [tier] = max units of that tier in this wave } or nil
--   tierUsed  = { [tier] = count } running tally, shared across calls that
--               belong to one wave (ComposeDrop's riders and carriers)
-- }
--
-- Guarantees at least one unit (the cheapest eligible) even if the budget is
-- below its cost, so an early wave is never silently empty.
--------------------------------------------------------------------------------

local function BuildEligible(pools, maxTier, weights, faction, portableOnly)
	local byClass, classes, cheapest = {}, {}, nil
	for i = 1, #pools.entries do
		local e = pools.entries[i]
		if e.tier <= maxTier
			and (not faction or e.faction == faction)
			and (not portableOnly or e.portable)
			and ((not weights) or weights[e.class]) then
			local c = byClass[e.class]
			if not c then
				c = {}
				byClass[e.class] = c
				classes[#classes + 1] = e.class
			end
			c[#c + 1] = e
			if (not cheapest) or e.cost < cheapest.cost then cheapest = e end
		end
	end
	table.sort(classes)   -- deterministic iteration for synced randomness
	return byClass, classes, cheapest
end

-- Is there room left under the per-wave limit for this tier?
function M.TierOpen(tierLimit, tierUsed, tier)
	local cap = tierLimit and tierLimit[tier]
	if not cap then return true end
	return (tierUsed[tier] or 0) < cap
end

function M.Compose(pools, budget, opts)
	opts = opts or {}
	local maxTier  = opts.maxTier  or math.huge
	local maxUnits = opts.maxUnits or 40
	local weights  = opts.weights
	local random   = opts.random   or math.random
	local tierLimit = opts.tierLimit
	local tierUsed  = opts.tierUsed or {}

	local byClass, classes, cheapest =
		BuildEligible(pools, maxTier, weights, opts.faction, opts.portableOnly)

	-- Faction filter starved the pool (e.g. archetype+faction combination with
	-- no members): fall back to mixed factions rather than an empty wave.
	if not cheapest and opts.faction then
		byClass, classes, cheapest =
			BuildEligible(pools, maxTier, weights, nil, opts.portableOnly)
	end
	-- Archetype weights starved it (shouldn't happen past PickArchetype's
	-- viability check, but belt and braces): fall back to uniform.
	if not cheapest and weights then
		byClass, classes, cheapest =
			BuildEligible(pools, maxTier, nil, nil, opts.portableOnly)
	end

	local list, spent = {}, 0
	if not cheapest then return list, spent end   -- empty pools (misconfigured mod)

	local remaining = budget
	while #list < maxUnits do
		-- Classes with at least one affordable member, and their weights
		local pickable, totalW = {}, 0
		for ci = 1, #classes do
			local class   = classes[ci]
			local members = byClass[class]
			local afford  = {}
			for i = 1, #members do
				local m = members[i]
				if m.cost <= remaining and M.TierOpen(tierLimit, tierUsed, m.tier) then
					afford[#afford + 1] = m
				end
			end
			if #afford > 0 then
				local w = weights and weights[class] or 1
				pickable[#pickable + 1] = { afford = afford, w = w }
				totalW = totalW + w
			end
		end
		if totalW == 0 then break end

		local roll, acc, chosen = random() * totalW, 0, pickable[#pickable]
		for i = 1, #pickable do
			acc = acc + pickable[i].w
			if roll <= acc then chosen = pickable[i] break end
		end

		local pick = chosen.afford[random(1, #chosen.afford)]
		list[#list + 1] = pick
		spent     = spent + pick.cost
		remaining = remaining - pick.cost
		tierUsed[pick.tier] = (tierUsed[pick.tier] or 0) + 1
	end

	-- Never send an empty wave, unless the only thing on offer is a unit from
	-- a tier that is at its limit.
	if #list == 0 and M.TierOpen(tierLimit, tierUsed, cheapest.tier) then
		list[1] = cheapest
		spent   = cheapest.cost
		tierUsed[cheapest.tier] = (tierUsed[cheapest.tier] or 0) + 1
	end

	return list, spent
end

--------------------------------------------------------------------------------
-- M.ComposeDrop(pools, budget, opts) -> drop
--
-- drop = {
--   ground  = { entry, ... },              -- the riders (portable units only)
--   plan    = { { entry = carrierEntry,    -- one row per bought carrier
--                 passengers = {gIdx,...}  -- indexes into `ground`
--               }, ... },
--   walkers = { gIdx, ... },               -- riders no carrier could take:
--                                          -- they march on foot instead
-- }
--
-- Roughly DROP_GROUND_FRACTION of the budget buys the ground contingent
-- (portable units under the archetype weights); the rest buys gunship
-- carriers, greedily packed by transportCapacity and transportMass.
--------------------------------------------------------------------------------

local DROP_GROUND_FRACTION = 0.65

function M.ComposeDrop(pools, budget, opts)
	opts = opts or {}
	local maxTier = opts.maxTier or math.huge
	local random  = opts.random  or math.random
	local tierLimit = opts.tierLimit
	local tierUsed  = opts.tierUsed or {}

	-- Riders
	local groundOpts = {
		tierLimit    = tierLimit,
		tierUsed     = tierUsed,
		maxTier      = maxTier,
		maxUnits     = opts.maxUnits or 40,
		weights      = opts.weights,
		faction      = opts.faction,
		random       = random,
		portableOnly = true,
	}
	local ground, groundSpent =
		M.Compose(pools, math.floor(budget * DROP_GROUND_FRACTION), groundOpts)

	-- Carrier candidates at this tier (faction filter honored, with fallback)
	local function CarrierList(faction)
		local list = {}
		for i = 1, #pools.entries do
			local e = pools.entries[i]
			if e.class == "gunship" and (e.cap or 0) > 0 and e.tier <= maxTier
				and (not faction or e.faction == faction) then
				list[#list + 1] = e
			end
		end
		return list
	end
	local carriers = CarrierList(opts.faction)
	if #carriers == 0 and opts.faction then carriers = CarrierList(nil) end

	local plan, walkers = {}, {}
	local remaining  = budget - groundSpent
	local unassigned = {}
	for i = 1, #ground do unassigned[#unassigned + 1] = i end

	while #unassigned > 0 and #carriers > 0 do
		local afford = {}
		for i = 1, #carriers do
			if carriers[i].cost <= remaining
				and M.TierOpen(tierLimit, tierUsed, carriers[i].tier) then
				afford[#afford + 1] = carriers[i]
			end
		end
		if #afford == 0 then break end

		local c = afford[random(1, #afford)]
		remaining = remaining - c.cost
		tierUsed[c.tier] = (tierUsed[c.tier] or 0) + 1
		local row = { entry = c, passengers = {} }

		-- Fill this carrier: capacity slots, mass limit; too-heavy riders are
		-- skipped and stay in the queue for a (possibly) bigger carrier.
		local keep = {}
		for i = 1, #unassigned do
			local gIdx = unassigned[i]
			if #row.passengers < c.cap and ground[gIdx].mass <= c.tmass then
				row.passengers[#row.passengers + 1] = gIdx
			else
				keep[#keep + 1] = gIdx
			end
		end
		unassigned = keep

		if #row.passengers > 0 then
			plan[#plan + 1] = row
		else
			-- Bought a carrier nothing fits into (all riders too heavy):
			-- refund and stop trying, the rest walk.
			remaining = remaining + c.cost
			tierUsed[c.tier] = tierUsed[c.tier] - 1
			break
		end
	end

	for i = 1, #unassigned do walkers[#walkers + 1] = unassigned[i] end

	return { ground = ground, plan = plan, walkers = walkers }
end

--------------------------------------------------------------------------------
-- M.Budget(minutes, curve, mult) -> metal budget for a wave launched now
--
-- curve = {
--   base     = budget at the first wave
--   peak     = plateau the ramp levels off at
--   start    = minute of the first wave (the grace period); the ramp is zero here
--   mid      = minute at which the ramp is halfway from base to peak
--   steep    = logistic steepness per minute
--   creep    = metal added per minute once past `plateau` (the slow squeeze)
--   plateau  = minute the late creep starts
-- }
--
-- An S-curve on the wave clock: slow start, a ramp through the mid game, then
-- a plateau, with a linear creep on top so the game still tightens with time.
-- Time-driven rather than wave-count-driven, so anything that launches extra
-- waves (accelerator beacons, rage) adds pressure without also dragging the
-- whole game up the curve.
--------------------------------------------------------------------------------

local function Logistic(m, steep, mid)
	return 1 / (1 + math.exp(-steep * (m - mid)))
end

function M.Budget(minutes, curve, mult)
	local m  = math.max(minutes, curve.start)
	local l0 = Logistic(curve.start, curve.steep, curve.mid)
	local s  = (Logistic(m, curve.steep, curve.mid) - l0) / (1 - l0)
	local b  = curve.base + (curve.peak - curve.base) * s
	         + curve.creep * math.max(0, m - curve.plateau)
	return math.floor(b * (mult or 1))
end

--------------------------------------------------------------------------------
-- M.FieldClamp(budget, fieldValue, capMult, minFraction) -> spawnBudget
--
-- The budget is a target for pressure, not a spawn order: what is already
-- alive on the field counts against it. The field may hold capMult budgets'
-- worth of metal; a wave tops it up to that cap, never spawning more than one
-- full budget and never less than minFraction of one (pressure never stops).
-- Unspent budget is dropped, not banked.
--------------------------------------------------------------------------------

function M.FieldClamp(budget, fieldValue, capMult, minFraction)
	local room = budget * capMult - fieldValue
	local low  = budget * minFraction
	if room > budget then room = budget end
	if room < low    then room = low end
	return math.floor(room)
end

return M
