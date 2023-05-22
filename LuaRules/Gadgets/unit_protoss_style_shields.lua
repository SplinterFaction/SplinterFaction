
function gadget:GetInfo()
	return {
		name    = "Protoss style shields",
		desc    = "Provides personal shields for selected units",
		author  = "GoogleFrog and ChatGPT3",
		date    = "21 May 2023",
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
local IN_LOS = {inlos = true}
local UPDATE_PERIOD = 5
local IterableMap = VFS.Include("LuaRules/Gadgets/Include/IterableMap.lua")

-- Table to store shielded units
local shieldedUnits = IterableMap.New()
local cachedShieldParams = {}

-- Initialize a new shielded unit
local function initShieldedUnit(unitID, shieldParams)
	local shieldedUnit = {
		unitID = unitID,
		lastFrameDamaged = -10000,
		shieldStrength = shieldParams.shieldMaxStrength or 100,
		shieldMaxStrength = shieldParams.shieldMaxStrength or 100,
		shieldRegenerationRate = shieldParams.shieldRegenerationRate or 5,
		shieldRegenerationDelay = shieldParams.shieldRegenerationDelay * 30 or 300,
	}
	IterableMap.Add(shieldedUnits, unitID, shieldedUnit)
	Spring.SetUnitRulesParam(unitID, "personalShield", shieldedUnit.shieldStrength, IN_LOS)
end

function gadget:Initialize()

end

-- Cache shield parameters
local unitDefs = UnitDefs
for unitDefID = 1, #unitDefs do
	local unitDef = UnitDefs[unitDefID]
	local customParams = unitDef.customParams
	if customParams and customParams.isshieldedunit == "1" then
		--Spring.Echo("[Protoss Style Shields] " .. UnitDefs[unitDefID].name .. [[ IS shielded]])
		cachedShieldParams[unitDefID] = {
			shieldMaxStrength = tonumber(customParams.shield_max_strength) or 100,
			shieldRegenerationRate = tonumber(customParams.shield_regeneration_rate) or 5,
			shieldRegenerationDelay = tonumber(customParams.shield_regeneration_delay) or 10,
		}
	else
		--Spring.Echo("[Protoss Style Shields] " .. UnitDefs[unitDefID].name .. [[ is NOT shielded]])
	end
end

-- Apply function for updating shielded units
local function UpdateShieldedUnit(unitID, shieldedUnit, index, frame)
	-- Check if the Shielded Unit is still alive
	if not Spring.ValidUnitID(unitID) then
		-- Remove destroyed units from the map
		return true
	end

	if shieldedUnit.lastFrameDamaged == nil then
		shieldedUnit.lastFrameDamaged = 1
	end

	-- Regenerate shield if necessary
	local frameDiff = frame - shieldedUnit.lastFrameDamaged
	-- Spring.Echo([[Frame]] .. frame)
	-- Spring.Echo([[Last Frame Damaged]] .. shieldedUnit.lastFrameDamaged)
	-- Spring.Echo([[Framediff]] .. frameDiff)
	if frameDiff > shieldedUnit.shieldRegenerationDelay and shieldedUnit.shieldStrength < shieldedUnit.shieldMaxStrength then
		local regenAmount = shieldedUnit.shieldRegenerationRate * UPDATE_PERIOD / 30  -- Divide by 30 to convert frames to seconds
		shieldedUnit.shieldStrength = math.min(shieldedUnit.shieldStrength + regenAmount, shieldedUnit.shieldMaxStrength)
		Spring.SetUnitRulesParam(unitID, "personalShield", shieldedUnit.shieldStrength, IN_LOS)
	end
end

function gadget:GameFrame(frame)
	--if frame > 1 then
		IterableMap.ApplyFraction(shieldedUnits, UPDATE_PERIOD, frame%UPDATE_PERIOD, UpdateShieldedUnit, frame)
	--end
end

-- Handle unit pre-damage event
function gadget:UnitPreDamaged(unitID, _, _, damage)
	local shieldedUnit = IterableMap.Get(shieldedUnits, unitID)
	if shieldedUnit then
		local remainingDamage = 0
		if shieldedUnit.shieldStrength >= damage then
			shieldedUnit.shieldStrength = shieldedUnit.shieldStrength - damage
		else
			remainingDamage = damage - shieldedUnit.shieldStrength
			shieldedUnit.shieldStrength = 0
		end
		Spring.SetUnitRulesParam(unitID, "personalShield", shieldedUnit.shieldStrength, IN_LOS)
		shieldedUnit.lastFrameDamaged = Spring.GetGameFrame()
		return remainingDamage -- Remaining damage applied to the unit
	end
	return damage
end

-- Handle unit creation event
function gadget:UnitCreated(unitID, unitDefID)
	local shieldParams = cachedShieldParams[unitDefID]
	--Spring.Echo("[Protoss Style Shields] " .. UnitDefs[unitDefID].name .. [[ is NOT shielded]])
	if shieldParams then
		--Spring.Echo("[Protoss Style Shields] " .. UnitDefs[unitDefID].name .. [[ IS shielded]])
		initShieldedUnit(unitID, shieldParams)
	end
end

