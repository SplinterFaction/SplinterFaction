--------------------------------------------------------------------------------
--
--  file:    s_pools.lua  (Survival AI module)
--  brief:   Builds the wave unit pools from factory build lists. Every unit a
--           factory can produce is a candidate; builders, factories, buildings
--           and unarmed units are excluded. Role comes from the unit's
--           buildmenucategory customparam, faction from factionname, tier from
--           the requiretech customparam (unit's own, else its factory's).
--
--           Pure module: takes a UnitDefs-shaped table, touches no engine
--           state, so it can be smoke-tested under plain lua5.1.
--
--------------------------------------------------------------------------------

local M = {}

-- requiretech values are strings like "tech2" / "2" / "T2"; pull the digit.
-- No param (or no digit) means tier 1.
local function TechToTier(v)
	if v == nil then return nil end
	local n = tonumber(string.match(tostring(v), "%d+"))
	return n
end

local function IsEligible(ud)
	if not ud then return false end
	if ud.isFactory then return false end           -- factories build, they don't march
	if ud.isBuilder then return false end           -- engineers / constructors
	local cp = ud.customParams or {}
	if cp.unittype == "building" then return false end
	if not ud.canMove then return false end
	if (ud.weapons == nil) or (#ud.weapons == 0) then return false end
	if (ud.minWaterDepth or 0) > 0 then return false end  -- sea units: no land waves (yet)
	if (ud.metalCost or 0) <= 0 then return false end
	return true
end

--------------------------------------------------------------------------------
-- M.Build(unitDefs, unitDefNames) -> pools
--
-- pools = {
--   entries  = { {name, defID, cost, role, faction, tier, isAir}, ... },
--   byRole   = { [role]   = { entryIdx, ... } },
--   byTier   = { [tier]   = { entryIdx, ... } },
--   minCost  = cheapest entry cost,
--   maxTier  = highest tier seen,
-- }
--------------------------------------------------------------------------------

function M.Build(unitDefs, unitDefNames)
	local pools = {
		entries = {},
		byRole  = {},
		byTier  = {},
		minCost = math.huge,
		maxTier = 1,
	}
	local seen = {}   -- defID -> true (a unit can appear in several factories)

	for facID = 1, #unitDefs do
		local fac = unitDefs[facID]
		if fac and fac.isFactory and fac.buildOptions then
			local facTier = TechToTier((fac.customParams or {}).requiretech) or 1
			for i = 1, #fac.buildOptions do
				local udid = fac.buildOptions[i]
				local ud   = unitDefs[udid]
				if ud and not seen[udid] and IsEligible(ud) then
					seen[udid] = true
					local cp = ud.customParams or {}
					local entry = {
						name    = ud.name,
						defID   = udid,
						cost    = ud.metalCost,
						role    = cp.buildmenucategory or "Unknown",
						faction = cp.factionname or "Unknown",
						tier    = TechToTier(cp.requiretech) or facTier,
						isAir   = ud.canFly or false,
					}
					local n = #pools.entries + 1
					pools.entries[n] = entry

					local r = pools.byRole[entry.role]
					if not r then r = {} ; pools.byRole[entry.role] = r end
					r[#r + 1] = n

					local t = pools.byTier[entry.tier]
					if not t then t = {} ; pools.byTier[entry.tier] = t end
					t[#t + 1] = n

					if entry.cost < pools.minCost then pools.minCost = entry.cost end
					if entry.tier > pools.maxTier then pools.maxTier = entry.tier end
				end
			end
		end
	end

	return pools
end

-- Debug helper: one echo line per role bucket.
function M.Describe(pools, echo)
	echo = echo or print
	echo(string.format("[Survival] Pool: %d units, tiers 1-%d, cheapest %d metal",
		#pools.entries, pools.maxTier, pools.minCost ~= math.huge and pools.minCost or 0))
	for role, list in pairs(pools.byRole) do
		echo(string.format("[Survival]   role %-14s x%d", role, #list))
	end
end

return M
