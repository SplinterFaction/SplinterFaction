function gadget:GetInfo()
	return {
		name    = "Metal Maker Income Scaler",
		desc    = "Sets metal maker output from metalSpot_value via SetUnitResourcing (cmm + energy use)",
		author  = "",
		date    = "2026-02-21",
		license = "GPLv2",
		layer   = 5,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local SetUnitResourcing = Spring.SetUnitResourcing
local GetGameRulesParam = Spring.GetGameRulesParam
local GetAllUnits       = Spring.GetAllUnits
local GetUnitDefID      = Spring.GetUnitDefID
local GetUnitIsDead     = Spring.GetUnitIsDead
local Echo              = Spring.Echo

local function round(x)
	return math.floor(x + 0.5)
end

-- ------------------------------------------------------------
-- Channels / tuning
-- ------------------------------------------------------------

-- Metal output channel:
-- "cmm" = conditional metal maker (stops when toggled off / no energy, etc. depending on engine behavior)
local METAL_CHANNEL = "cmm"

-- Energy consumption channel:
-- Typically "cue" is the conditional energy use channel.
local ENERGY_USE_CHANNEL = "cue"

-- IMPORTANT: In many setups, resource "use" is represented as NEGATIVE.
-- If you find energy isn't being drained, flip this to -1.
local ENERGY_SIGN = -1

-- Your original balance numbers were tuned around metalSpot_value = 3.
local BASE_SPOT_VALUE = 3

-- ------------------------------------------------------------
-- Tier multipliers / base energy
-- ------------------------------------------------------------

-- Tier multipliers (metalSpot_value * multiplier)
local multipliersByName = {
	lozmetalextractor     = 1.0,
	fedmetalextractor     = 1.0,

	lozmetalextractor_up1 = 2.0,
	fedmetalextractor_up1 = 2.0,

	lozmetalextractor_up2 = 3.0,
	fedmetalextractor_up2 = 3.0,

	lozmetalextractor_up3 = 5.333,
	fedmetalextractor_up3 = 5.333,

	lozmetalextractor_up4 = 10.666,
	fedmetalextractor_up4 = 10.666,

	geometalmaker         = 21.333,
}

-- Base energy upkeep by tier (these are the numbers for metalSpot_value == 3)
local energyBaseByName = {
	lozmetalextractor     = 5,
	fedmetalextractor     = 5,

	lozmetalextractor_up1 = 25,
	fedmetalextractor_up1 = 25,

	lozmetalextractor_up2 = 50,
	fedmetalextractor_up2 = 50,

	lozmetalextractor_up3 = 100,
	fedmetalextractor_up3 = 100,

	lozmetalextractor_up4 = 250,
	fedmetalextractor_up4 = 250,

	geometalmaker         = 500,
}

-- ------------------------------------------------------------
-- Precompute unitDefID -> config (store ONLY base values here)
-- ------------------------------------------------------------

local byDefID = {}
for unitDefID, ud in pairs(UnitDefs) do
	local name = ud and ud.name
	local mult = name and multipliersByName[name]
	if mult then
		byDefID[unitDefID] = {
			name       = name,
			mult       = mult,
			energyBase = energyBaseByName[name] or 0,
		}
	end
end

-- ------------------------------------------------------------
-- Runtime state
-- ------------------------------------------------------------

local metalSpotValue = nil
local appliedValue   = nil

local function GetScaledEnergy(energyBase)
	-- Scale linearly vs BASE_SPOT_VALUE to preserve your original balance curve.
	-- Keep as float; SetUnitResourcing accepts floats.
	return energyBase * (metalSpotValue / BASE_SPOT_VALUE)
end

local function ApplyToUnit(unitID)
	local udid = GetUnitDefID(unitID)
	if not udid then return end

	local cfg = byDefID[udid]
	if not cfg then return end
	if not metalSpotValue then return end

	-- Metal production
	local makes = metalSpotValue * cfg.mult
	if makes < 0 then makes = 0 end
	SetUnitResourcing(unitID, METAL_CHANNEL, makes)

	-- Energy drain (scaled)
	local scaledEnergy = GetScaledEnergy(cfg.energyBase)
	SetUnitResourcing(unitID, ENERGY_USE_CHANNEL, ENERGY_SIGN * scaledEnergy)

	-- Optional UI debug (uncomment if useful)
	-- Spring.SetUnitRulesParam(unitID, "maker_metal", makes, {public=true})
	-- Spring.SetUnitRulesParam(unitID, "maker_energy", ENERGY_SIGN * scaledEnergy, {public=true})
end

local function ApplyToAllExisting()
	local units = GetAllUnits()
	for i = 1, #units do
		local unitID = units[i]
		if not GetUnitIsDead(unitID) then
			ApplyToUnit(unitID)
		end
	end
end

-- ------------------------------------------------------------
-- Events
-- ------------------------------------------------------------

function gadget:GameFrame(n)
	-- Wait until metalSpot_value exists
	if not metalSpotValue then
		local v = GetGameRulesParam("metalSpot_value")
		if type(v) == "number" then
			metalSpotValue = v
			appliedValue   = v
			Echo(string.format(
					"[MetalMakerScaler] metalSpot_value=%.3f (metal=%s, energy=%s sign=%d), applying maker outputs",
					metalSpotValue, METAL_CHANNEL, ENERGY_USE_CHANNEL, ENERGY_SIGN
			))
			ApplyToAllExisting()
		end
		return
	end

	-- If it changes mid-game, reapply (because energy is computed live from current metalSpotValue)
	local v = GetGameRulesParam("metalSpot_value")
	if type(v) == "number" and v ~= appliedValue then
		metalSpotValue = v
		appliedValue   = v
		Echo(string.format("[MetalMakerScaler] metalSpot_value changed to %.3f, reapplying maker outputs", v))
		ApplyToAllExisting()
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	ApplyToUnit(unitID)
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	ApplyToUnit(unitID)
end

function gadget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
	ApplyToUnit(unitID)
end