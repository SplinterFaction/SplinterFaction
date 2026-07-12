function gadget:GetInfo()
	return {
		name    = "Disruption Damage",
		desc    = "Disruption buildup with staged system shutdowns; overload nova at full disruption",
		author  = "",
		date    = "2026-07-04",
		license = "MIT",
		layer   = 0,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- SYNCED
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

local GAME_SPEED = 30
local IN_LOS = { inlos = true }

-- Shutdown stages
-- Stage 1 (>= 33%): sensors offline (LOS collapses to MIN_LOS_RADIUS)
-- Stage 2 (>= 66%): weapons offline (ranges collapsed to WEAPON_DEAD_RANGE)
-- Stage 3 (100%):   engines dead for LOCKOUT_SECONDS + overload nova
local STAGE_1_THRESHOLD = 0.33
local STAGE_2_THRESHOLD = 0.66

-- Full disruption
local LOCKOUT_SECONDS    = 10
local LOCKOUT_FRAMES     = LOCKOUT_SECONDS * GAME_SPEED
local POST_TRIGGER_RESET = 0.55 -- come back online at 55% (stage 1: still blind, weapons back)

-- Overload nova (fires when a unit hits full disruption)
-- Applies NOVA_FRACTION of the SOURCE unit's capacity to the source's allies
-- within NOVA_RADIUS. Victims' own disruptionresist still applies.
local NOVA_RADIUS   = 300
local NOVA_FRACTION = 0.25

-- Stage CEGs (stubs -- define these)
local STAGE_CEGS = {
	[1] = "transformerblow-stage1",
	[2] = "transformerblow-stage2",
	[3] = "transformerblow-stage3",
}
local NOVA_CEG    = "transformerblow-large"
local AMBIENT_CEG = "lightning_stormbolt" -- crackle on units at stage >= 1

-- Decay pauses briefly after a disruption hit
local RECENT_HIT_DELAY_SECONDS = 2
local RECENT_HIT_DELAY_FRAMES  = RECENT_HIT_DELAY_SECONDS * GAME_SPEED

-- Decay rates are based on capacity per second
local DECAY_HIGH = 0.02 -- >70%
local DECAY_MID  = 0.04 -- 30-70%
local DECAY_LOW  = 0.06 -- <30%

-- Performance / update cadence
local UPDATE_FRAMES = 6
local RULESPARAM_EPSILON_PERCENT = 0.5

-- Stage effect floors
local MIN_LOS_RADIUS = 50 -- elmos; tiny floor to avoid engine weirdness at zero
local ENGINE_DEAD_SPEED_MULT = 0.001 -- near-zero; true zero can misbehave
local WEAPON_DEAD_RANGE = 1 -- elmos; weapon + acquisition range while weapons offline

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
local spGetAllUnits         = Spring.GetAllUnits
local spGetUnitIsDead       = Spring.GetUnitIsDead
local spGetUnitPosition     = Spring.GetUnitPosition
local spSpawnCEG            = Spring.SpawnCEG
local spGetUnitsInSphere    = Spring.GetUnitsInSphere
local spGetUnitTeam         = Spring.GetUnitTeam
local spAreTeamsAllied      = Spring.AreTeamsAllied
local spGetGroundHeight     = Spring.GetGroundHeight
local spGetUnitWeaponState  = Spring.GetUnitWeaponState
local spSetUnitWeaponState  = Spring.SetUnitWeaponState
local spGetUnitMaxRange     = Spring.GetUnitMaxRange
local spSetUnitMaxRange     = Spring.SetUnitMaxRange
local spSetUnitTarget       = Spring.SetUnitTarget

local SendToUnsynced = SendToUnsynced

local MoveCtrl                = Spring.MoveCtrl
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

local disruption         = {} -- current buildup
local disruptionCapacity = {} -- maxHP * disruptioncapacitymult
local lastDisruptionHit  = {} -- frame of last disruption hit
local disruptedUntil     = {} -- lockout end frame
local activeUnits        = {} -- units with nonzero disruption
local lastShownPercent   = {} -- rulesParam epsilon throttling
local currentStage       = {} -- 0..3

local unitResistMult   = {}
local unitRecoveryMult = {}
local unitCapacityMult = {}
local unitImmune       = {}

local moveTypeCache = {}
-- moveTypeCache[unitID] = {
--   kind = "ground"/"none",
--   baseLOS = ...,
--   baseMove = { maxSpeed = ..., accRate = ..., turnRate = ... },
-- }

local weaponRangeCache = {}
-- weaponRangeCache[unitID] = {
--   weapons = { { num = weaponNum, baseRange = ... }, ... }, -- shields excluded
--   baseMaxRange = ...,
-- }

-- Weapon defs flagged as disruption weapons, resolved once at load
local disruptionWeaponDef    = {} -- [weaponDefID] = true
local disruptionWeaponDamage = {} -- [weaponDefID] = explicit disruptiondamage or nil

for wdid = 0, #WeaponDefs do
	local wd = WeaponDefs[wdid]
	if wd then
		local cp = wd.customParams
		if cp and tonumber(cp.disruptionweapon) == 1 then
			disruptionWeaponDef[wdid] = true
			disruptionWeaponDamage[wdid] = tonumber(cp.disruptiondamage)
		end
	end
end

-- Overload nova work queue (queue instead of recursion so cascades are stack-safe)
local novaQueue      = {}
local novaCount      = 0
local processingNova = false

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
	return untilFrame ~= nil and untilFrame > frame
end

local function GetStageForPercent(pct, fullyDisrupted)
	if fullyDisrupted then
		return 3
	elseif pct >= STAGE_2_THRESHOLD then
		return 2
	elseif pct >= STAGE_1_THRESHOLD then
		return 1
	end
	return 0
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

local function SpawnCEGAtUnit(unitID, cegName, radius)
	if not cegName then return end

	local x, y, z = spGetUnitPosition(unitID)
	if not x then return end

	radius = radius or 0

	local px, pz = x, z
	if radius > 0 then
		px = x + (math.random() * 2 - 1) * radius
		pz = z + (math.random() * 2 - 1) * radius
	end

	local gy = spGetGroundHeight(px, pz)
	local py = math_max(y, gy or y)

	spSpawnCEG(cegName, px, py, pz, 0, 1, 0)
end

--------------------------------------------------------------------------------
-- Stage effects
--------------------------------------------------------------------------------

local function ApplyLOSCollapse(unitID)
	local cache = moveTypeCache[unitID]
	if cache and cache.baseLOS and cache.baseLOS > 0 then
		spSetUnitSensorRadius(unitID, "los", math_min(MIN_LOS_RADIUS, cache.baseLOS))
	end
end

local function RestoreLOS(unitID)
	local cache = moveTypeCache[unitID]
	if cache and cache.baseLOS and cache.baseLOS > 0 then
		spSetUnitSensorRadius(unitID, "los", cache.baseLOS)
	end
end

local function ApplyEngineKill(unitID)
	if not mcSetGroundMoveTypeData then return end

	local cache = moveTypeCache[unitID]
	if not cache or cache.kind ~= "ground" then return end

	local bm = cache.baseMove
	if not bm or not bm.maxSpeed then return end

	local values = {
		maxSpeed = math_max(0.001, bm.maxSpeed * ENGINE_DEAD_SPEED_MULT),
	}
	if bm.accRate then
		values.accRate = math_max(0.0001, bm.accRate * ENGINE_DEAD_SPEED_MULT)
	end
	if bm.turnRate then
		values.turnRate = math_max(0.0001, bm.turnRate * ENGINE_DEAD_SPEED_MULT)
	end

	pcall(mcSetGroundMoveTypeData, unitID, values)
end

local function RestoreMovement(unitID)
	if not mcSetGroundMoveTypeData then return end

	local cache = moveTypeCache[unitID]
	if not cache or cache.kind ~= "ground" then return end

	local bm = cache.baseMove
	if not bm or not bm.maxSpeed then return end

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
end

-- Caches live per-weapon ranges + unit max range so stage 2 can collapse and
-- restore them. Shield weapons are excluded: collapsing a shield's "range"
-- would shrink the shield bubble itself.
local function CacheWeaponRanges(unitID, unitDefID)
	local ud = UnitDefs[unitDefID]
	local cache = { weapons = {} }

	local udWeapons = ud and ud.weapons
	if udWeapons then
		for num = 1, #udWeapons do
			local wd = WeaponDefs[udWeapons[num].weaponDef]
			if wd and wd.type ~= "Shield" then
				local baseRange = spGetUnitWeaponState(unitID, num, "range")
					or wd.range
				if baseRange and baseRange > WEAPON_DEAD_RANGE then
					cache.weapons[#cache.weapons + 1] = {
						num = num,
						baseRange = baseRange,
					}
				end
			end
		end
	end

	local maxRange = spGetUnitMaxRange(unitID)
	if maxRange and maxRange > WEAPON_DEAD_RANGE then
		cache.baseMaxRange = maxRange
	end

	weaponRangeCache[unitID] = cache
end

local function ApplyWeaponsOffline(unitID)
	local cache = weaponRangeCache[unitID]
	if not cache then return end

	local weapons = cache.weapons
	for i = 1, #weapons do
		spSetUnitWeaponState(unitID, weapons[i].num, "range", WEAPON_DEAD_RANGE)
	end

	if cache.baseMaxRange then
		spSetUnitMaxRange(unitID, WEAPON_DEAD_RANGE)
	end

	-- Range changes don't cancel an already-acquired target; drop it now
	spSetUnitTarget(unitID)
end

local function RestoreWeapons(unitID)
	local cache = weaponRangeCache[unitID]
	if not cache then return end

	local weapons = cache.weapons
	for i = 1, #weapons do
		spSetUnitWeaponState(unitID, weapons[i].num, "range", weapons[i].baseRange)
	end

	if cache.baseMaxRange then
		spSetUnitMaxRange(unitID, cache.baseMaxRange)
	end
end

-- Transitions the unit between shutdown stages. Fires a CEG for every stage
-- crossed on the way UP (a single big hit can announce stage 1, 2, and 3).
-- Recovery transitions are silent.
local function SetStage(unitID, newStage)
	local oldStage = currentStage[unitID] or 0
	if newStage == oldStage then
		return
	end

	if newStage > oldStage then
		for stage = oldStage + 1, newStage do
			SpawnCEGAtUnit(unitID, STAGE_CEGS[stage], 0)
			SendToUnsynced("disruptionStageUp", unitID, stage)
		end
	end

	-- Stage 1+: sensors offline
	if newStage >= 1 and oldStage < 1 then
		ApplyLOSCollapse(unitID)
	elseif newStage < 1 and oldStage >= 1 then
		RestoreLOS(unitID)
	end

	-- Stage 2+: weapons offline (ranges collapsed)
	if newStage >= 2 and oldStage < 2 then
		ApplyWeaponsOffline(unitID)
	elseif newStage < 2 and oldStage >= 2 then
		RestoreWeapons(unitID)
	end

	-- Stage 3: engines dead
	if newStage >= 3 and oldStage < 3 then
		ApplyEngineKill(unitID)
	elseif newStage < 3 and oldStage >= 3 then
		RestoreMovement(unitID)
	end

	currentStage[unitID] = newStage
	spSetUnitRulesParam(unitID, "disruption_stage", newStage, IN_LOS)
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

--------------------------------------------------------------------------------
-- Disruption application + overload nova
--------------------------------------------------------------------------------

local function EnqueueNova(unitID, amount)
	novaCount = novaCount + 1
	novaQueue[novaCount] = { unitID = unitID, amount = amount }
end

local function TriggerFullDisruption(unitID, frame)
	local cap = disruptionCapacity[unitID] or 1
	disruption[unitID] = cap
	disruptedUntil[unitID] = frame + LOCKOUT_FRAMES
	activeUnits[unitID] = true

	SetStage(unitID, 3)
	EnqueueNova(unitID, cap * NOVA_FRACTION)
end

-- Adds disruption to a unit (victim resist applied here), updates its stage,
-- and triggers full disruption at cap. Callers are responsible for immunity
-- and lockout checks, and for draining the nova queue afterwards.
local function ApplyDisruption(unitID, amount, frame)
	amount = amount * (unitResistMult[unitID] or 1)
	if amount <= 0 then
		return
	end

	local cap = disruptionCapacity[unitID]
	if not cap or cap <= 0 then
		cap = math_max(1, GetUnitMaxHealth(unitID) * (unitCapacityMult[unitID] or 1))
		disruptionCapacity[unitID] = cap
	end

	local current = math_min(cap, (disruption[unitID] or 0) + amount)
	disruption[unitID] = current
	lastDisruptionHit[unitID] = frame
	activeUnits[unitID] = true

	if current >= cap then
		TriggerFullDisruption(unitID, frame)
	else
		SetStage(unitID, GetStageForPercent(current / cap, false))
	end
end

-- The nova arcs to units ALLIED WITH THE OVERLOADING UNIT (the clumped army
-- pays the price). The disrupting side and third parties are never affected.
local function DoNova(nova, frame)
	local sourceUnitID = nova.unitID

	local x, y, z = spGetUnitPosition(sourceUnitID)
	if not x then return end

	SpawnCEGAtUnit(sourceUnitID, NOVA_CEG, 0)

	local sourceTeam = spGetUnitTeam(sourceUnitID)
	if not sourceTeam then return end

	local nearby = spGetUnitsInSphere(x, y, z, NOVA_RADIUS)
	if not nearby or #nearby == 0 then return end

	for i = 1, #nearby do
		local uid = nearby[i]
		if uid ~= sourceUnitID
				and spValidUnitID(uid)
				and not spGetUnitIsDead(uid)
				and not unitImmune[uid]
				and not IsUnitFullyDisrupted(uid, frame) then
			local uteam = spGetUnitTeam(uid)
			if uteam and (uteam == sourceTeam or spAreTeamsAllied(sourceTeam, uteam)) then
				ApplyDisruption(uid, nova.amount, frame)
			end
		end
	end
end

-- Drains the nova queue. Novas triggered while processing (cascades through
-- clumped units) are appended and picked up by the same loop. Cascades
-- terminate naturally: a unit can only nova once per lockout entry, and
-- already-locked-out units are skipped as nova targets.
local function ProcessNovaQueue(frame)
	if processingNova then
		return
	end
	processingNova = true

	local i = 1
	while i <= novaCount do
		local nova = novaQueue[i]
		i = i + 1
		DoNova(nova, frame)
	end

	novaQueue = {}
	novaCount = 0
	processingNova = false
end

--------------------------------------------------------------------------------
-- Unit state lifecycle
--------------------------------------------------------------------------------

local function ClearUnitState(unitID)
	disruption[unitID] = nil
	disruptionCapacity[unitID] = nil
	lastDisruptionHit[unitID] = nil
	disruptedUntil[unitID] = nil
	activeUnits[unitID] = nil
	lastShownPercent[unitID] = nil
	currentStage[unitID] = nil
	unitResistMult[unitID] = nil
	unitRecoveryMult[unitID] = nil
	unitCapacityMult[unitID] = nil
	unitImmune[unitID] = nil
	moveTypeCache[unitID] = nil
	weaponRangeCache[unitID] = nil

	spSetUnitRulesParam(unitID, "disruption", 0, IN_LOS)
	spSetUnitRulesParam(unitID, "disruption_disrupted", 0, IN_LOS)
	spSetUnitRulesParam(unitID, "disruption_stage", 0, IN_LOS)
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
	currentStage[unitID] = currentStage[unitID] or 0

	unitCapacityMult[unitID] = capacityMult
	unitResistMult[unitID] = resistMult
	unitRecoveryMult[unitID] = recoveryMult
	unitImmune[unitID] = immune

	CacheMoveType(unitID, unitDefID)
	CacheWeaponRanges(unitID, unitDefID)

	spSetUnitRulesParam(unitID, "disruption", 0, IN_LOS)
	spSetUnitRulesParam(unitID, "disruption_disrupted", 0, IN_LOS)
	spSetUnitRulesParam(unitID, "disruption_stage", 0, IN_LOS)
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
	-- If the nanoframe was disrupted while under construction, lift the stage
	-- effects before recaching so we don't capture collapsed values as base.
	local stage = currentStage[unitID] or 0
	if stage >= 1 then
		RestoreLOS(unitID)
	end
	if stage >= 2 then
		RestoreWeapons(unitID)
	end

	CacheMoveType(unitID, unitDefID)
	CacheWeaponRanges(unitID, unitDefID)

	-- Re-apply current stage effects against the fresh cache
	if stage >= 1 then
		ApplyLOSCollapse(unitID)
	end
	if stage >= 2 then
		ApplyWeaponsOffline(unitID)
	end
	if stage >= 3 then
		ApplyEngineKill(unitID)
	end
end

function gadget:UnitDestroyed(unitID)
	ClearUnitState(unitID)
end

function gadget:UnitTaken(unitID, unitDefID)
	RestoreMovement(unitID)
	RestoreLOS(unitID)
	RestoreWeapons(unitID)
	ClearUnitState(unitID)
	InitUnitState(unitID, unitDefID)
end

function gadget:UnitGiven(unitID, unitDefID)
	RestoreMovement(unitID)
	RestoreLOS(unitID)
	RestoreWeapons(unitID)
	ClearUnitState(unitID)
	InitUnitState(unitID, unitDefID)
end

--------------------------------------------------------------------------------
-- Damage interception
--------------------------------------------------------------------------------

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if not weaponDefID or not disruptionWeaponDef[weaponDefID] then
		return damage
	end

	if unitImmune[unitID] then
		return 0
	end

	local frame = spGetGameFrame()

	-- Already locked out: dead hit. AllowWeaponTarget steers attackers to
	-- other targets, so this only absorbs in-flight projectiles.
	if IsUnitFullyDisrupted(unitID, frame) then
		return 0
	end

	local disruptAmount = disruptionWeaponDamage[weaponDefID] or damage or 0
	if disruptAmount <= 0 then
		return 0
	end

	ApplyDisruption(unitID, disruptAmount, frame)
	ProcessNovaQueue(frame)

	return 0
end

--------------------------------------------------------------------------------
-- Weapon control
--------------------------------------------------------------------------------

function gadget:AllowWeaponTarget(attackerID, targetID, attackerWeaponNum, attackerWeaponDefID, defPriority)
	-- Stage 2 weapons-offline is enforced by collapsing weapon ranges in
	-- SetStage; no attacker check needed here.

	-- Best-effort retarget assist: disruption weapons refuse locked-out
	-- targets so the engine picks something useful. This callin isn't
	-- consulted on every targeting path, but when it fails UnitPreDamaged
	-- still absorbs the hit as 0 damage, so it's harmless.
	if targetID
			and attackerWeaponDefID
			and disruptionWeaponDef[attackerWeaponDefID]
			and IsUnitFullyDisrupted(targetID, spGetGameFrame()) then
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

			-- Lockout expiry: come back online at POST_TRIGGER_RESET.
			-- 55% lands in stage 1: weapons and engines back, still blind.
			if disruptedUntil[unitID] and disruptedUntil[unitID] <= frame then
				disruptedUntil[unitID] = nil
				current = cap * POST_TRIGGER_RESET
				disruption[unitID] = current
				fullyDisrupted = false
				lastDisruptionHit[unitID] = frame
			end

			-- Decay (paused briefly after a recent hit, never during lockout)
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

			local pct = Clamp(current / cap, 0, 1)
			local stage = GetStageForPercent(pct, fullyDisrupted)
			SetStage(unitID, stage)

			if stage >= 1 then
				SpawnCEGAtUnit(unitID, AMBIENT_CEG, 20)
			end

			SetDisplayedRulesParams(unitID, pct, fullyDisrupted)

			if (not fullyDisrupted) and current <= 0.001 then
				disruption[unitID] = 0
				SetStage(unitID, 0) -- restores sensors; engines already restored on leaving stage 3
				SetDisplayedRulesParams(unitID, 0, false)
				activeUnits[unitID] = nil
			end
		end
	end
end

else
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- UNSYNCED: 3D stage-up sounds
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Sound files (stubs -- supply these). Stage 3 fires at the same moment as
-- the overload nova, so make it the big one.
local STAGE_SOUNDS = {
	[1] = { file = "sounds/weapons/electricboom.wav", volume = 0.8 },
	[2] = { file = "sounds/weapons/electricboom.wav", volume = 0.9 },
	[3] = { file = "sounds/impacts/phasegun1hit.wav", volume = 1.0 },
}
local SOUND_CHANNEL = "battle"

local spPlaySoundFile     = Spring.PlaySoundFile
local spGetUnitPosition   = Spring.GetUnitPosition
local spIsUnitInLos       = Spring.IsUnitInLos
local spGetMyAllyTeamID   = Spring.GetMyAllyTeamID
local spGetSpectatingState = Spring.GetSpectatingState

local function CanLocalPlayerSee(unitID)
	local spec, fullView = spGetSpectatingState()
	if spec and fullView then
		return true
	end
	return spIsUnitInLos(unitID, spGetMyAllyTeamID())
end

local function OnStageUp(_, unitID, stage)
	local snd = STAGE_SOUNDS[stage]
	if not snd then
		return
	end

	-- SendToUnsynced reaches every client; without this guard, enemies would
	-- hear stage-up sounds on units hidden in the fog.
	if not CanLocalPlayerSee(unitID) then
		return
	end

	local x, y, z = spGetUnitPosition(unitID)
	if not x then
		return
	end

	spPlaySoundFile(snd.file, snd.volume, x, y, z, SOUND_CHANNEL)
end

function gadget:Initialize()
	-- Disable entries whose files don't exist yet, and say so once instead
	-- of spamming warnings on every stage-up.
	for stage, snd in pairs(STAGE_SOUNDS) do
		if not VFS.FileExists(snd.file) then
			Spring.Echo("[Disruption] stage " .. stage .. " sound missing: "
				.. snd.file .. " -- sound disabled until supplied")
			STAGE_SOUNDS[stage] = nil
		end
	end

	gadgetHandler:AddSyncAction("disruptionStageUp", OnStageUp)
end

function gadget:Shutdown()
	gadgetHandler:RemoveSyncAction("disruptionStageUp")
end

end
