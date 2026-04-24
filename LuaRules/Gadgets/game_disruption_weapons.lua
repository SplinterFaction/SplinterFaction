function gadget:GetInfo()
	return {
		name    = "Disruption Damage",
		desc    = "Converts marked weapon damage into disruption buildup; progressive impairment; full disruption at 100%",
		author  = "",
		date    = "2026-03-14",
		license = "MIT",
		layer   = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

local GAME_SPEED = 30
local IN_LOS = { inlos = true }

-- Full disruption
local LOCKOUT_SECONDS   = 10
local LOCKOUT_FRAMES    = LOCKOUT_SECONDS * GAME_SPEED
local POST_TRIGGER_RESET = 0.55

-- Disruption chaining
local CHAIN_TARGETS  = 3
local CHAIN_FRACTION = 0.25
local CHAIN_RADIUS   = 300
local RECENT_HIT_DELAY_SECONDS = 2
local RECENT_HIT_DELAY_FRAMES  = RECENT_HIT_DELAY_SECONDS * GAME_SPEED

-- Decay rates are based on max HP per second
local DECAY_HIGH = 0.02 -- >70%
local DECAY_MID  = 0.04 -- 30-70%
local DECAY_LOW  = 0.06 -- <30%

-- Performance / update cadence
local UPDATE_FRAMES = 6
local RULESPARAM_EPSILON_PERCENT = 0.5

-- Penalty floors at 100% disruption
local MIN_SPEED_MULT = 0.25
local MIN_ACCEL_MULT = 0.25
local MIN_TURN_MULT  = 0.25
local MIN_LOS_RADIUS = 50  -- elmos; tiny floor to avoid engine weirdness at zero

--------------------------------------------------------------------------------
-- optional customparams
--------------------------------------------------------------------------------
--unitdefs
--customParams = {
--	disruptionresist = 1.0,
--	disruptionrecovery = 1.0,
--	disruptioncapacitymult = 1.0,
--	disruptionimmune = 0,
--}

--weapondefs
--customParams = {
--	disruptionweapon = 1,
--	disruptiondamage = 180, -- if you want it to differ from the default weapon damage
--}

--------------------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------------------

local spGetGameFrame        = Spring.GetGameFrame
local spValidUnitID         = Spring.ValidUnitID
local spGetUnitHealth       = Spring.GetUnitHealth
local spGetUnitDefID        = Spring.GetUnitDefID
local spSetUnitRulesParam   = Spring.SetUnitRulesParam
local spSetUnitSensorRadius = Spring.SetUnitSensorRadius
local spGetUnitSensorRadius = Spring.GetUnitSensorRadius
local spGetUnitWeaponState  = Spring.GetUnitWeaponState
local spSetUnitWeaponState  = Spring.SetUnitWeaponState
local spGiveOrderToUnit     = Spring.GiveOrderToUnit
local spGetAllUnits         = Spring.GetAllUnits
local spGetUnitIsDead       = Spring.GetUnitIsDead
local spGetUnitPosition     = Spring.GetUnitPosition
local spSpawnCEG            = Spring.SpawnCEG
local spGetUnitsInSphere    = Spring.GetUnitsInSphere
local spGetUnitTeam         = Spring.GetUnitTeam
local spAreTeamsAllied      = Spring.AreTeamsAllied

local MoveCtrl              = Spring.MoveCtrl
local mcGetGroundMoveTypeData = MoveCtrl and MoveCtrl.GetGroundMoveTypeData
local mcSetGroundMoveTypeData = MoveCtrl and MoveCtrl.SetGroundMoveTypeData

local UnitDefs   = UnitDefs
local WeaponDefs = WeaponDefs
local math_min   = math.min
local math_max   = math.max
local math_abs   = math.abs

--------------------------------------------------------------------------------
-- Tables
--------------------------------------------------------------------------------

local disruption = {}
local disruptionCapacity = {}
local lastDisruptionHit = {}
local disruptedUntil = {}
local activeUnits = {}
local lastShownPercent = {}

local unitResistMult = {}
local unitRecoveryMult = {}
local unitCapacityMult = {}
local unitImmune = {}

local moveTypeCache = {}
local weaponCache = {}
-- weaponCache[unitID] = { [weaponNum] = { reloadTime = ... }, ... }
-- moveTypeCache[unitID] = {
--   kind = "ground"/"none",
--   baseLOS = ...,
--   baseMove = {
--     maxSpeed = ...,
--     accRate  = ...,
--     turnRate = ...,
--   }
-- }

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function Clamp(x, lo, hi)
	if x < lo then return lo end
	if x > hi then return hi end
	return x
end

local function GetUnitMaxHealth(unitID)
	local _, maxHealth = spGetUnitHealth(unitID)
	return maxHealth or 1
end

local function IsUnitFullyDisrupted(unitID, frame)
	local untilFrame = disruptedUntil[unitID]
	return untilFrame and untilFrame > frame
end

local function GetPenaltyMultipliersFromPercent(pct, fullyDisrupted)
	-- Stronger early ramp than linear, but still ends at 25% at 100%.
	local shaped = pct ^ 0.7

	local speedMult = 1 - (shaped * 0.75)
	local accelMult = 1 - (shaped * 0.75)
	local turnMult  = 1 - (shaped * 0.75)

	speedMult = math_max(MIN_SPEED_MULT, speedMult)
	accelMult = math_max(MIN_ACCEL_MULT, accelMult)
	turnMult  = math_max(MIN_TURN_MULT, turnMult)

	if fullyDisrupted then
		speedMult = MIN_SPEED_MULT
		accelMult = MIN_ACCEL_MULT
		turnMult  = MIN_TURN_MULT
	end

	return speedMult, accelMult, turnMult
end

local function CacheMoveType(unitID, unitDefID)
	local ud = UnitDefs[unitDefID]
	if not ud then
		moveTypeCache[unitID] = { kind = "none" }
		return
	end

	local cache = {
		kind = "ground",
		baseLOS  = spGetUnitSensorRadius(unitID, "los") or 0,
		baseMove = {},
	}

	if mcGetGroundMoveTypeData then
		local ok, mtd = pcall(mcGetGroundMoveTypeData, unitID)
		if ok and mtd then
			cache.baseMove.maxSpeed = mtd.maxSpeed
			cache.baseMove.accRate  = mtd.accRate
			cache.baseMove.turnRate = mtd.turnRate
			moveTypeCache[unitID] = cache
			return
		end
	end

	cache.baseMove.maxSpeed = ud.speed
	cache.baseMove.turnRate = ud.turnRate
	cache.baseMove.accRate  = ud.accel

	if not cache.baseMove.maxSpeed then
		cache.kind = "none"
	end

	moveTypeCache[unitID] = cache
end

local function CacheWeapons(unitID, unitDefID)
	local ud = UnitDefs[unitDefID]
	if not ud or not ud.weapons then return end

	local cache = {}
	for i = 1, #ud.weapons do
		local ws = spGetUnitWeaponState(unitID, i, "reloadTime")
		if ws then
			cache[i] = { reloadTime = ws }
		end
	end
	weaponCache[unitID] = cache
end

local function SpawnCEG(unitID, cegName, radius)
	local x, y, z = spGetUnitPosition(unitID)
	if not x then return end

	radius = radius or 20

	local rx = (math.random() * 2 - 1) * radius
	local rz = (math.random() * 2 - 1) * radius

	local gy = Spring.GetGroundHeight(x + rx, z + rz)
	local py = math.max(y, gy)

	spSpawnCEG(cegName, x + rx, py, z + rz, 0, 1, 0)
end

local function ApplyMovementPenalty(unitID, speedMult, accelMult, turnMult)
	if not mcSetGroundMoveTypeData then return end

	local cache = moveTypeCache[unitID]
	if not cache or cache.kind ~= "ground" then
		return
	end

	local bm = cache.baseMove
	if not bm or not bm.maxSpeed then
		return
	end

	local values = {
		maxSpeed = bm.maxSpeed * speedMult,
	}

	if bm.accRate then
		values.accRate = bm.accRate * accelMult
	end
	if bm.turnRate then
		values.turnRate = bm.turnRate * turnMult
	end

	pcall(mcSetGroundMoveTypeData, unitID, values)
end

local function RestoreMovement(unitID)
	if not mcSetGroundMoveTypeData then return end

	local cache = moveTypeCache[unitID]
	if not cache or cache.kind ~= "ground" then
		return
	end

	local bm = cache.baseMove
	if not bm or not bm.maxSpeed then
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

	pcall(mcSetGroundMoveTypeData, unitID, values)

	-- Restore LOS
	if cache.baseLOS and cache.baseLOS > 0 then
		spSetUnitSensorRadius(unitID, "los", cache.baseLOS)
	end

	-- Restore weapon reload times
	local wcache = weaponCache[unitID]
	if wcache then
		for weaponNum, wdata in pairs(wcache) do
			spSetUnitWeaponState(unitID, weaponNum, "reloadTime", wdata.reloadTime)
		end
	end
end

local function SetDisplayedRulesParams(unitID, pct, fullyDisrupted)
	local displayPercent = pct * 100
	local prev = lastShownPercent[unitID]

	if (not prev) or math_abs(displayPercent - prev) >= RULESPARAM_EPSILON_PERCENT then
		lastShownPercent[unitID] = displayPercent
		spSetUnitRulesParam(unitID, "disruption", displayPercent, IN_LOS)
	end

	spSetUnitRulesParam(unitID, "disruption_disrupted", fullyDisrupted and 1 or 0, IN_LOS)
end

local function ClearUnitState(unitID)
	disruption[unitID] = nil
	disruptionCapacity[unitID] = nil
	lastDisruptionHit[unitID] = nil
	disruptedUntil[unitID] = nil
	activeUnits[unitID] = nil
	lastShownPercent[unitID] = nil
	unitResistMult[unitID] = nil
	unitRecoveryMult[unitID] = nil
	unitCapacityMult[unitID] = nil
	unitImmune[unitID] = nil
	moveTypeCache[unitID] = nil
	weaponCache[unitID] = nil

	spSetUnitRulesParam(unitID, "disruption", 0, IN_LOS)
	spSetUnitRulesParam(unitID, "disruption_disrupted", 0, IN_LOS)
	spSetUnitRulesParam(unitID, "disruption_speedmult", 1, IN_LOS)
end

local function GetDecayRateForPercent(pct)
	if pct > 0.70 then
		return DECAY_HIGH
	elseif pct >= 0.30 then
		return DECAY_MID
	else
		return DECAY_LOW
	end
end

local function TriggerFullDisruption(unitID, frame, noStop)
	local cap = disruptionCapacity[unitID] or 1
	disruption[unitID] = cap
	disruptedUntil[unitID] = frame + LOCKOUT_FRAMES
	activeUnits[unitID] = true

	if not noStop then

		-- spGiveOrderToUnit(unitID, CMD.STOP, {}, 0)
	end
end

local function InitUnitState(unitID, unitDefID)
	local ud = UnitDefs[unitDefID]
	if not ud then
		return
	end

	local maxHealth = GetUnitMaxHealth(unitID)
	local cp = ud.customParams or {}

	local capacityMult = tonumber(cp.disruptioncapacitymult) or 1
	local resistMult   = tonumber(cp.disruptionresist) or 1
	local recoveryMult = tonumber(cp.disruptionrecovery) or 1
	local immune       = tonumber(cp.disruptionimmune) == 1

	disruption[unitID] = disruption[unitID] or 0
	disruptionCapacity[unitID] = math_max(1, maxHealth * capacityMult)
	lastDisruptionHit[unitID] = lastDisruptionHit[unitID] or -999999
	disruptedUntil[unitID] = disruptedUntil[unitID] or nil

	unitCapacityMult[unitID] = capacityMult
	unitResistMult[unitID] = resistMult
	unitRecoveryMult[unitID] = recoveryMult
	unitImmune[unitID] = immune

	CacheMoveType(unitID, unitDefID)
	CacheWeapons(unitID, unitDefID)

	spSetUnitRulesParam(unitID, "disruption", 0, IN_LOS)
	spSetUnitRulesParam(unitID, "disruption_disrupted", 0, IN_LOS)
	spSetUnitRulesParam(unitID, "disruption_speedmult", 1, IN_LOS)
end

--------------------------------------------------------------------------------
-- Gadget Callins
--------------------------------------------------------------------------------

function gadget:Initialize()
	local allUnits = spGetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		local unitDefID = spGetUnitDefID(unitID)
		if unitDefID then
			InitUnitState(unitID, unitDefID)
		end
	end
end

function gadget:UnitCreated(unitID, unitDefID)
	InitUnitState(unitID, unitDefID)
end

function gadget:UnitFinished(unitID, unitDefID)
	CacheMoveType(unitID, unitDefID)
	CacheWeapons(unitID, unitDefID)
end

function gadget:UnitDestroyed(unitID)
	RestoreMovement(unitID)
	ClearUnitState(unitID)
end

function gadget:UnitTaken(unitID, unitDefID)
	RestoreMovement(unitID)
	ClearUnitState(unitID)
	InitUnitState(unitID, unitDefID)
end

function gadget:UnitGiven(unitID, unitDefID)
	RestoreMovement(unitID)
	ClearUnitState(unitID)
	InitUnitState(unitID, unitDefID)
end

--------------------------------------------------------------------------------
-- Chaining
--------------------------------------------------------------------------------

local function ApplyChainDisruption(sourceUnitID, sourceTeam, chainAmount, frame)
	local x, y, z = spGetUnitPosition(sourceUnitID)
	if not x then return end

	local nearby = spGetUnitsInSphere(x, y, z, CHAIN_RADIUS)
	if not nearby or #nearby == 0 then return end

	-- Build candidate list: enemy, alive, not the source, not immune, not already fully disrupted
	local candidates = {}
	for i = 1, #nearby do
		local uid = nearby[i]
		if uid ~= sourceUnitID
				and spValidUnitID(uid)
				and not spGetUnitIsDead(uid)
				and not unitImmune[uid]
				and not IsUnitFullyDisrupted(uid, frame) then
			local uteam = spGetUnitTeam(uid)
			if uteam and uteam ~= sourceTeam and not spAreTeamsAllied(sourceTeam, uteam) then
				candidates[#candidates + 1] = uid
			end
		end
	end

	if #candidates == 0 then return end

	-- Fisher-Yates shuffle then take up to CHAIN_TARGETS
	for i = #candidates, 2, -1 do
		local j = math.random(i)
		candidates[i], candidates[j] = candidates[j], candidates[i]
	end

	local hits = math_min(CHAIN_TARGETS, #candidates)
	for i = 1, hits do
		local uid = candidates[i]

		local resist = unitResistMult[uid] or 1
		local amount = chainAmount * resist

		local cap = disruptionCapacity[uid]
		if not cap or cap <= 0 then
			local maxHealth = GetUnitMaxHealth(uid)
			cap = math_max(1, maxHealth * (unitCapacityMult[uid] or 1))
			disruptionCapacity[uid] = cap
		end

		disruption[uid] = math_min(cap, (disruption[uid] or 0) + amount)
		lastDisruptionHit[uid] = frame
		activeUnits[uid] = true

		if disruption[uid] >= cap then
			TriggerFullDisruption(uid, frame, true)
		end
	end
end

--------------------------------------------------------------------------------
-- Damage interception
--------------------------------------------------------------------------------

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if not weaponDefID then
		return damage
	end

	local wd = WeaponDefs[weaponDefID]
	if not wd then
		return damage
	end

	local cp = wd.customParams
	if not cp or tonumber(cp.disruptionweapon) ~= 1 then
		return damage
	end

	if unitImmune[unitID] then
		return 0
	end

	local frame = spGetGameFrame()

	-- Target is already fully disrupted: block the hit and stop the attacker
	-- so it immediately drops its target and looks for something else.
	-- Chain still fires so disruption weapons aren't wasted on a locked-out target.
	if IsUnitFullyDisrupted(unitID, frame) then
		if attackerID and spValidUnitID(attackerID) then
			spGiveOrderToUnit(attackerID, CMD.STOP, {}, 0)
		end
		local disruptAmount = tonumber(cp.disruptiondamage) or damage or 0
		if disruptAmount > 0 then
			ApplyChainDisruption(unitID, attackerTeam, disruptAmount * CHAIN_FRACTION, frame)
		end
		return 0
	end

	local disruptAmount = tonumber(cp.disruptiondamage) or damage or 0
	if disruptAmount <= 0 then
		return 0
	end

	local resist = unitResistMult[unitID] or 1
	disruptAmount = disruptAmount * resist

	local cap = disruptionCapacity[unitID]
	if not cap or cap <= 0 then
		local maxHealth = GetUnitMaxHealth(unitID)
		cap = math_max(1, maxHealth * (unitCapacityMult[unitID] or 1))
		disruptionCapacity[unitID] = cap
	end

	disruption[unitID] = math_min(cap, (disruption[unitID] or 0) + disruptAmount)
	lastDisruptionHit[unitID] = frame
	activeUnits[unitID] = true

	if disruption[unitID] >= cap then
		TriggerFullDisruption(unitID, frame)
	end

	-- Chain 25% of the disruption amount to up to 3 nearby enemies
	local chainAmount = disruptAmount * CHAIN_FRACTION
	ApplyChainDisruption(unitID, attackerTeam, chainAmount, frame)

	return 0
end

--------------------------------------------------------------------------------
-- Weapon control
--------------------------------------------------------------------------------

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
	-- Block manual attack orders while fully disrupted.
	if cmdID == CMD.ATTACK or cmdID == CMD.FIGHT then
		local frame = spGetGameFrame()
		if IsUnitFullyDisrupted(unitID, frame) then
			return false
		end
	end
	return true
end

function gadget:AllowWeaponTarget(attackerID, targetID, attackerWeaponNum, attackerWeaponDefID, defPriority)
	local frame = spGetGameFrame()

	-- Fully disrupted units cannot fire at all.
	if IsUnitFullyDisrupted(attackerID, frame) then
		return false
	end

	return true
end

--------------------------------------------------------------------------------
-- Main update loop
--------------------------------------------------------------------------------

function gadget:GameFrame(frame)
	if frame % UPDATE_FRAMES ~= 0 then
		return
	end

	local dt = UPDATE_FRAMES / GAME_SPEED

	for unitID in pairs(activeUnits) do
		if (not spValidUnitID(unitID)) or spGetUnitIsDead(unitID) then
			activeUnits[unitID] = nil
		else
			local cap = disruptionCapacity[unitID] or 1
			local current = disruption[unitID] or 0
			local fullyDisrupted = IsUnitFullyDisrupted(unitID, frame)

			SpawnCEG(unitID, "lightning_stormbolt", 20)

			if disruptedUntil[unitID] and disruptedUntil[unitID] <= frame then
				disruptedUntil[unitID] = nil
				current = cap * POST_TRIGGER_RESET
				disruption[unitID] = current
				fullyDisrupted = false
				lastDisruptionHit[unitID] = frame
			end

			if (not fullyDisrupted) and current > 0 then
				local lastHit = lastDisruptionHit[unitID] or -999999
				if frame - lastHit > RECENT_HIT_DELAY_FRAMES then
					local pct = current / cap
					local decayRate = GetDecayRateForPercent(pct)
					local recoveryMult = unitRecoveryMult[unitID] or 1
					local decayAmount = cap * decayRate * recoveryMult * dt

					current = math_max(0, current - decayAmount)
					disruption[unitID] = current
				end
			end

			local pct = current / cap
			pct = Clamp(pct, 0, 1)

			local speedMult, accelMult, turnMult = GetPenaltyMultipliersFromPercent(pct, fullyDisrupted)

			spSetUnitRulesParam(unitID, "disruption_speedmult", speedMult, IN_LOS)

			ApplyMovementPenalty(unitID, speedMult, accelMult, turnMult)

			-- LOS ramping: same shaped curve, floors at MIN_LOS_RADIUS
			local cache = moveTypeCache[unitID]
			if cache and cache.baseLOS and cache.baseLOS > 0 then
				local losMult
				if fullyDisrupted then
					losMult = 0
				else
					local shaped = pct ^ 0.7
					losMult = 1 - shaped
				end
				local newLOS = math.max(MIN_LOS_RADIUS, math.floor(cache.baseLOS * losMult))
				spSetUnitSensorRadius(unitID, "los", newLOS)
			end

			-- Reload time penalty: same shaped curve, max 2x at full disruption
			local wcache = weaponCache[unitID]
			if wcache then
				local shaped = fullyDisrupted and 1 or (pct ^ 0.7)
				local reloadMult = 1 + shaped
				for weaponNum, wdata in pairs(wcache) do
					spSetUnitWeaponState(unitID, weaponNum, "reloadTime", wdata.reloadTime * reloadMult)
				end
			end

			SetDisplayedRulesParams(unitID, pct, fullyDisrupted)

			if (not fullyDisrupted) and current <= 0.001 then
				disruption[unitID] = 0
				RestoreMovement(unitID)  -- also restores LOS
				SetDisplayedRulesParams(unitID, 0, false)
				spSetUnitRulesParam(unitID, "disruption_speedmult", 1, IN_LOS)
				activeUnits[unitID] = nil
			end
		end
	end
end