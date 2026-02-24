function gadget:GetInfo()
	return {
		name    = "Heat Weapons",
		desc    = "Converts damage from marked weapons into heat buildup; heat dissipates; at 100% unit explodes",
		author  = "",
		date    = "2026-02-22",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local IN_LOS = { inlos = true }

local IterableMap = VFS.Include("LuaRules/Gadgets/Include/IterableMap.lua")
local heatedUnits = IterableMap.New()

-- Update frequency (frames). 10 = ~3 updates/sec at 30fps sim.
local UPDATE_PERIOD = 10 -- 3 times a second instead of 6. Trying to squeeze a little performance back

local HEAT_DEATH_FLAG   = "killedByHeat"   -- numeric: 1 = heat, nil/0 otherwise
local HEAT_DEATH_KILLER = "heatKiller"     -- optional: attacker unitID
local HEAT_DEATH_WDID   = "heatWeaponDef"  -- optional: weaponDefID

--------------------------------------------------------------------------------
-- Heat slow tuning
--------------------------------------------------------------------------------
-- These lopsided values are so that if for whatever reason a unit or units continually go above/below the threshold, it isn't triggering a million calls.
local HEAT_SLOW_ON  = 55 --Percent
local HEAT_SLOW_OFF = 45 --Percent

local HEAT_SLOW_MAXSPEED_MULT = 0.70
local HEAT_SLOW_ACCRATE_MULT  = 0.75
local HEAT_SLOW_TURNRATE_MULT = 0.85

local MoveCtrl = Spring.MoveCtrl
local SetGroundMoveTypeData = MoveCtrl and MoveCtrl.SetGroundMoveTypeData
local GetGroundMoveTypeData = MoveCtrl and MoveCtrl.GetGroundMoveTypeData -- if available in your build

local HEAT_RULES_UPDATE_THRESHOLD = 1  -- percent difference required to update

--------------------------------------------------------------------------------
-- Tuning (global defaults)
--------------------------------------------------------------------------------

-- Heat "energy" capacity scales with target metal cost:
-- capacity = metalCost * HEAT_CAPACITY_PER_METAL
-- Bigger units => more capacity => require more heat damage to reach 100%.
local HEAT_CAPACITY_PER_METAL = 10

-- Cooling power removes heat energy per second (constant by default).
-- Because capacity scales with metal, this makes big units cool *slower in %*.
local COOLING_POWER_PER_SECOND = 35

-- Optional: small delay (frames) after last heat hit before cooling starts.
local COOLING_DELAY_FRAMES = 0

-- Clamp displayed heat % to [0..100]
local function clamp01(x)
	if x < 0 then return 0 end
	if x > 1 then return 1 end
	return x
end

local function GetUnitMetalCost(unitDefID)
	local ud = UnitDefs[unitDefID]
	if not ud then return 0 end
	return (ud.metalCost or ud.metal or 0)
end

--------------------------------------------------------------------------------
-- Debug
--------------------------------------------------------------------------------

local DEBUG_HEAT = false
local DEBUG_ECHO_INTERVAL = 15  -- frames between echo updates per unit

--------------------------------------------------------------------------------
-- Heat slow helpers
--------------------------------------------------------------------------------

local function CacheBaseMoveData(unitID, unitDefID, data)
	-- This only matters for ground movers. If the call fails, we just skip slow.
	data.baseMove = data.baseMove or {}

	-- Prefer engine-provided move data if available.
	if GetGroundMoveTypeData then
		local ok, mtd = pcall(GetGroundMoveTypeData, unitID)
		if ok and mtd then
			data.baseMove.maxSpeed = mtd.maxSpeed
			data.baseMove.accRate  = mtd.accRate
			data.baseMove.turnRate = mtd.turnRate
			return
		end
	end

	-- Fallback: we can at least get a baseline maxSpeed from UnitDef.
	-- (acc/turn might not be present here, so they may remain nil.)
	local ud = UnitDefs[unitDefID]
	if ud then
		data.baseMove.maxSpeed = data.baseMove.maxSpeed or ud.speed
		data.baseMove.turnRate = data.baseMove.turnRate or ud.turnRate
		data.baseMove.accRate  = data.baseMove.accRate  or ud.accel
	end
end

local function ApplyHeatSlow(unitID, data)
	if not SetGroundMoveTypeData then return end
	if not data or data.slowApplied then return end
	if not Spring.ValidUnitID(unitID) or Spring.GetUnitIsDead(unitID) then return end

	CacheBaseMoveData(unitID, data.unitDefID, data)

	local bm = data.baseMove
	if not bm or not bm.maxSpeed then
		-- No baseline -> don’t apply.
		return
	end

	local values = {
		maxSpeed = bm.maxSpeed * HEAT_SLOW_MAXSPEED_MULT,
	}

	-- Only set keys we successfully cached (avoid stomping nil/unknown)
	if bm.accRate then
		values.accRate = bm.accRate * HEAT_SLOW_ACCRATE_MULT
	end
	if bm.turnRate then
		values.turnRate = bm.turnRate * HEAT_SLOW_TURNRATE_MULT
	end

	pcall(SetGroundMoveTypeData, unitID, values)
	data.slowApplied = true
end

local function ClearHeatSlow(unitID, data)
	if not SetGroundMoveTypeData then return end
	if not data or not data.slowApplied then return end
	if not Spring.ValidUnitID(unitID) then return end

	local bm = data.baseMove
	if not bm or not bm.maxSpeed then
		data.slowApplied = false
		return
	end

	local values = {
		maxSpeed = bm.maxSpeed,
	}
	if bm.accRate then
		values.accRate = bm.accRate
	end
	if bm.turnRate then
		values.turnRate = bm.turnRate
	end

	pcall(SetGroundMoveTypeData, unitID, values)
	data.slowApplied = false
end

local function UpdateSlowState(unitID, data, pct)
	if (not data.slowApplied) and pct > HEAT_SLOW_ON then
		ApplyHeatSlow(unitID, data)
	elseif data.slowApplied and pct < HEAT_SLOW_OFF then
		ClearHeatSlow(unitID, data)
	end
end

--------------------------------------------------------------------------------
-- Cache weapon heat params
--------------------------------------------------------------------------------

local weaponHeat = {}

do
	local wds = WeaponDefs
	for weaponDefID = 1, #wds do
		local wd = wds[weaponDefID]
		local cp = wd and wd.customParams
		if cp and cp.heatweapon == "1" then
			weaponHeat[weaponDefID] = {
				mult = tonumber(cp.heatmult) or 1.0,
			}
		end
	end
end

--------------------------------------------------------------------------------
-- Per-unit init
--------------------------------------------------------------------------------

local function initHeatedUnit(unitID, unitDefID)
	local metalCost = GetUnitMetalCost(unitDefID)
	if metalCost <= 0 then
		metalCost = 1
	end

	local ud = UnitDefs[unitDefID]
	local ucp = ud and ud.customParams or {}
	local capacityMult = tonumber(ucp.heat_capacity_mult) or 1.0
	local coolingMult  = tonumber(ucp.heat_cooling_mult)  or 1.0

	local capacity = math.max(1, metalCost * HEAT_CAPACITY_PER_METAL * capacityMult)
	local coolingPower = math.max(0, COOLING_POWER_PER_SECOND * coolingMult)

	local data = {
		unitID          = unitID,
		unitDefID       = unitDefID,
		metalCost       = metalCost,
		heatEnergy      = 0,
		heatCapacity    = capacity,
		coolingPower    = coolingPower,
		lastFrameHeated = -100000,

		-- debug throttle
		lastEchoFrame   = -100000,
		lastEchoValue   = -1,

		-- slow state
		slowApplied     = false,
		baseMove        = {},  -- cached maxSpeed/accRate/turnRate

		lastHeatPercent = -1,
	}

	IterableMap.Add(heatedUnits, unitID, data)
	Spring.SetUnitRulesParam(unitID, "heat", 0, IN_LOS)
	return data
end

local function setHeatRulesParam(unitID, heatEnergy, heatCapacity, data)
	local pct = 100 * clamp01(heatEnergy / heatCapacity)

	-- Only update rulesparam if change exceeds threshold
	if data then
		local last = data.lastHeatPercent or -1
		if math.abs(pct - last) >= HEAT_RULES_UPDATE_THRESHOLD then
			Spring.SetUnitRulesParam(unitID, "heat", pct, IN_LOS)
			data.lastHeatPercent = pct
		end
	else
		-- fallback safety
		Spring.SetUnitRulesParam(unitID, "heat", pct, IN_LOS)
	end

	-- Debug output (unchanged)
	if DEBUG_HEAT and data then
		local frame = Spring.GetGameFrame()
		if math.abs(pct - (data.lastEchoValue or -1)) >= 0.5 then
			if frame - (data.lastEchoFrame or 0) >= DEBUG_ECHO_INTERVAL then
				local unitName = UnitDefs[data.unitDefID].name
				Spring.Echo(string.format("[HEAT DEBUG] %s (ID %d): %.1f%%", unitName, unitID, pct))
				data.lastEchoFrame = frame
				data.lastEchoValue = pct
			end
		end
	end

	-- Update slow state whenever heat changes
	if data then
		UpdateSlowState(unitID, data, pct)
	end

	return pct
end

--------------------------------------------------------------------------------
-- Cooling / ticking
--------------------------------------------------------------------------------

local function DestroyUnitSafe(unitID, attackerID)
	if attackerID and attackerID > 0 then
		local ok = pcall(Spring.DestroyUnit, unitID, false, false, attackerID)
		if ok then return end
	end
	pcall(Spring.DestroyUnit, unitID, false, false)
end

local function UpdateHeatedUnit(unitID, data, index, frame)
	if not Spring.ValidUnitID(unitID) then
		return true
	end

	if Spring.GetUnitIsDead(unitID) then
		-- best effort restore (in case it matters for death pipeline)
		if data.slowApplied then
			ClearHeatSlow(unitID, data)
		end
		return true
	end

	if data.heatEnergy <= 0 then
		-- cooled out
		Spring.SetUnitRulesParam(unitID, "heat", 0, IN_LOS)
		if data.slowApplied then
			ClearHeatSlow(unitID, data)
		end
		return true
	end

	local framesSinceHeat = frame - (data.lastFrameHeated or -100000)
	if framesSinceHeat <= COOLING_DELAY_FRAMES then
		return
	end

	local dt = UPDATE_PERIOD / 30
	local cool = data.coolingPower * dt
	if cool > 0 then
		data.heatEnergy = data.heatEnergy - cool
		if data.heatEnergy < 0 then data.heatEnergy = 0 end
	end

	setHeatRulesParam(unitID, data.heatEnergy, data.heatCapacity, data)

	if data.heatEnergy <= 0 then
		Spring.SetUnitRulesParam(unitID, "heat", 0, IN_LOS)
		if data.slowApplied then
			ClearHeatSlow(unitID, data)
		end
		return true
	end
end

function gadget:GameFrame(frame)
	IterableMap.ApplyFraction(heatedUnits, UPDATE_PERIOD, frame % UPDATE_PERIOD, UpdateHeatedUnit, frame)
end

--------------------------------------------------------------------------------
-- Core: convert damage -> heat
--------------------------------------------------------------------------------

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer,
                               weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)

	local wh = weaponHeat[weaponDefID]
	if not wh then
		return damage
	end

	if damage <= 0 then
		return 0
	end

	local data = IterableMap.Get(heatedUnits, unitID)
	if not data then
		data = initHeatedUnit(unitID, unitDefID)
	end

	local frame = Spring.GetGameFrame()
	data.lastFrameHeated = frame

	data.heatEnergy = data.heatEnergy + (damage * wh.mult)

	local pct = setHeatRulesParam(unitID, data.heatEnergy, data.heatCapacity, data)

	if pct >= 100 then
		-- Boom (your custom tech-based CEG selection)
		local x, y, z = Spring.GetUnitPosition(unitID)
		local ud = UnitDefs[data.unitDefID]
		local cp = ud and ud.customParams or {}

		if cp.requiretech == "tech0" then
			Spring.SpawnCEG("genericunitexplosion-heatdeath-small", x, y+10, z, 0, 0, 0)
		end
		if cp.requiretech == "tech1" then
			Spring.SpawnCEG("genericunitexplosion-heatdeath-small", x, y+10, z, 0, 0, 0)
		end
		if cp.requiretech == "tech2" then
			Spring.SpawnCEG("genericunitexplosion-heatdeath-medium", x, y+10, z, 0, 0, 0)
		end
		if cp.requiretech == "tech3" then
			Spring.SpawnCEG("genericunitexplosion-heatdeath-large", x, y+10, z, 0, 0, 0)
		end
		if cp.requiretech == "tech4" then
			Spring.SpawnCEG("genericunitexplosion-heatdeath-huge", x, y+10, z, 0, 0, 0)
		end

		-- Mark death reason for other gadgets
		Spring.SetUnitRulesParam(unitID, HEAT_DEATH_FLAG, 1)
		if attackerID and attackerID > 0 then
			Spring.SetUnitRulesParam(unitID, HEAT_DEATH_KILLER, attackerID)
		end
		if weaponDefID then
			Spring.SetUnitRulesParam(unitID, HEAT_DEATH_WDID, weaponDefID)
		end

		-- Best effort: restore move values (doesn't really matter, but keeps state clean)
		if data.slowApplied then
			ClearHeatSlow(unitID, data)
		end

		DestroyUnitSafe(unitID, attackerID)
		return 0
	end

	return 0
end