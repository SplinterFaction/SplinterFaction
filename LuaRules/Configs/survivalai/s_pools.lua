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

--------------------------------------------------------------------------------
-- Role classification. The tactical vocabulary lives in the `unitrole`
-- customparam ("Main Battle Tank - Tech 2", "Indirect Fire Support", ...);
-- buildmenucategory is only the build-menu grouping and is used as fallback.
-- Precedence matters: "Direct/Indirect Fire Support" must classify as
-- artillery before the generic "support" pattern can swallow it.
--------------------------------------------------------------------------------

local function Classify(cp)
	local role = string.lower(cp.unitrole or cp.buildmenucategory or "")
	-- Only "Basic Transport" (dragonfly) is a true hauler; Combat/Massive
	-- Transports are gunships that happen to carry cargo, and they fight.
	if string.find(role, "basic transport") then return "transport" end
	if string.find(role, "transport")   then return "gunship" end
	if string.find(role, "scout")       then return "scout" end
	if string.find(role, "anti%-air") or string.find(role, "anti air")
	                                    then return "aa" end
	if string.find(role, "artillery") or string.find(role, "fire support")
	                                    then return "artillery" end
	if string.find(role, "heatray")     then return "heat" end
	if string.find(role, "bomber")      then return "bomber" end
	if string.find(role, "interceptor") or string.find(role, "fighter")
	                                    then return "fighter" end
	if string.find(role, "tank")        then return "mbt" end
	if string.find(role, "support")     then return "support" end
	return "other"
end

M.Classify = Classify

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
		entries  = {},
		byRole   = {},
		byClass  = {},
		byTier   = {},
		factions = {},
		minCost  = math.huge,
		maxTier  = 1,
	}
	local seen        = {}   -- defID -> true (a unit can appear in several factories)
	local factionSeen = {}

	for facID = 1, #unitDefs do
		local fac = unitDefs[facID]
		if fac and fac.isFactory and fac.buildOptions then
			local facTier = TechToTier((fac.customParams or {}).requiretech) or 1
			for i = 1, #fac.buildOptions do
				local udid = fac.buildOptions[i]
				local ud   = unitDefs[udid]
				if ud and not seen[udid] and IsEligible(ud) then
					local cp    = ud.customParams or {}
					local class = Classify(cp)
					-- Transports have no cargo logic in waves yet; leave them out
					if class ~= "transport" then
						seen[udid] = true
						local entry = {
							name    = ud.name,
							defID   = udid,
							cost    = ud.metalCost,
							role    = cp.buildmenucategory or "Unknown",
							class   = class,
							faction = cp.factionname or "Unknown",
							tier    = TechToTier(cp.requiretech) or facTier,
							isAir   = ud.canFly or false,
							-- Drop-wave data: what this can carry / whether it can ride
							cap      = ud.transportCapacity or 0,
							tmass    = ud.transportMass or math.huge,
							mass     = ud.mass or ud.metalCost or 100,
							portable = (not ud.canFly) and (not ud.cantBeTransported) or false,
						}
						local n = #pools.entries + 1
						pools.entries[n] = entry

						local r = pools.byRole[entry.role]
						if not r then r = {} ; pools.byRole[entry.role] = r end
						r[#r + 1] = n

						local c = pools.byClass[entry.class]
						if not c then c = {} ; pools.byClass[entry.class] = c end
						c[#c + 1] = n

						local t = pools.byTier[entry.tier]
						if not t then t = {} ; pools.byTier[entry.tier] = t end
						t[#t + 1] = n

						if entry.faction ~= "Unknown" and not factionSeen[entry.faction] then
							factionSeen[entry.faction] = true
							pools.factions[#pools.factions + 1] = entry.faction
						end

						if entry.cost < pools.minCost then pools.minCost = entry.cost end
						if entry.tier > pools.maxTier then pools.maxTier = entry.tier end
					end
				end
			end
		end
	end

	table.sort(pools.factions)   -- deterministic order for synced random picks
	return pools
end

-- Debug helper: one echo line per class bucket.
function M.Describe(pools, echo)
	echo = echo or print
	echo(string.format("[Survival] Pool: %d units, tiers 1-%d, cheapest %d metal, %d faction(s)",
		#pools.entries, pools.maxTier,
		pools.minCost ~= math.huge and pools.minCost or 0, #pools.factions))
	for class, list in pairs(pools.byClass) do
		echo(string.format("[Survival]   class %-10s x%d", class, #list))
	end
end

return M
