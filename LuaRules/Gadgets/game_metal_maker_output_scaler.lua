function gadget:GetInfo()
	return {
		name    = "Metal Maker Income Scaler",
		desc    = "Sets metal maker output from metalSpot_value via SetUnitResourcing (cmm + energy use)",
		author  = "",
		date    = "2026-02-09",
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

-- Choose which metal channel to drive.
-- For makers that should stop producing when toggled off / insufficient conditions:
--   "cmm" is the usual choice.
-- If you ever want "always produces regardless", switch to "umm".
local METAL_CHANNEL = "cmm"

-- Energy consumption channel (this is the usual one used for upkeep)
local ENERGY_USE_CHANNEL = "cue"

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

-- Energy upkeep base numbers by tier
local energyUseByName = {
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

-- Precompute unitDefID -> config
local byDefID = {}
for unitDefID, ud in pairs(UnitDefs) do
	local name = ud.name
	local mult = name and multipliersByName[name]
	if mult then
		byDefID[unitDefID] = {
			mult = mult,
			energy = energyUseByName[name] or 0,
			name = name,
		}
	end
end

local metalSpotValue = nil
local appliedValue = nil

local function ApplyToUnit(unitID)
	local udid = GetUnitDefID(unitID)
	if not udid then return end

	local cfg = byDefID[udid]
	if not cfg then return end
	if not metalSpotValue then return end

	local makes = round(metalSpotValue * cfg.mult)
	if makes < 0 then makes = 0 end

	-- Conditional metal output
	SetUnitResourcing(unitID, METAL_CHANNEL, makes)

	-- Energy upkeep while producing (and generally tied to on/off state)
	-- If you ever want "only consume when producing", this is usually correct.
	-- If your game wants always-on energy drain, we'd switch to a different channel/logic.
	SetUnitResourcing(unitID, ENERGY_USE_CHANNEL, cfg.energy)

	-- Optional for UI/widgets:
	-- Spring.SetUnitRulesParam(unitID, "maker_metal", makes, {public=true})
	-- Spring.SetUnitRulesParam(unitID, "maker_energy", cfg.energy, {public=true})
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

function gadget:GameFrame()
	-- Wait until metalSpot_value exists
	if not metalSpotValue then
		local v = GetGameRulesParam("metalSpot_value")
		if v and type(v) == "number" then
			metalSpotValue = v
			appliedValue = v
			Echo(string.format("[MetalMakerScaler] metalSpot_value=%.3f (channel=%s), applying maker outputs",
			                   metalSpotValue, METAL_CHANNEL))
			ApplyToAllExisting()
		end
		return
	end

	-- If it changes mid-game, reapply
	local v = GetGameRulesParam("metalSpot_value")
	if v and type(v) == "number" and v ~= appliedValue then
		metalSpotValue = v
		appliedValue = v
		Echo(string.format("[MetalMakerScaler] metalSpot_value changed to %.3f, reapplying maker outputs", v))
		ApplyToAllExisting()
	end
end

function gadget:UnitFinished(unitID)
	ApplyToUnit(unitID)
end

function gadget:UnitGiven(unitID)
	ApplyToUnit(unitID)
end

function gadget:UnitTaken(unitID)
	ApplyToUnit(unitID)
end