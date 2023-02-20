function gadget:GetInfo()
	return {
		name = "Continuous Aim",
		desc = "Applies lower 'reaimTime for continuous aim'",
		author = "Doo",
		date = "April 2018",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true, -- When we will move on 105 :)
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local convertedUnits = {
	-- value is reaimtime in frames, engine default is 15

	-- the following units get a faster reaimtime to counteract their turret acceleration
	[UnitDefNames.fedbear.id] = 4,
	[UnitDefNames.fedcobra.id] = 4,
	[UnitDefNames.fedphalanx.id] = 4,
}

-- add for scavengers copies
local convertedUnitsCopy = table.copy(convertedUnits)
for id, v in pairs(convertedUnitsCopy) do
	if UnitDefNames[UnitDefs[id].name..'_scav'] then
		convertedUnits[UnitDefNames[UnitDefs[id].name..'_scav'].id] = v
	end
end

local unitWeapons = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	local weapons = unitDef.weapons
	if #weapons > 0 then
		unitWeapons[unitDefID] = {}
		for id, _ in pairs(weapons) do
			unitWeapons[unitDefID][id] = true	-- no need to store weapondefid
		end
	end
end

function gadget:UnitCreated(unitID, unitDefID)
	if convertedUnits[unitDefID] and unitWeapons[unitDefID] then
		for id, _ in pairs(unitWeapons[unitDefID]) do
			-- NOTE: this will prevent unit from firing if it does not IMMEDIATELY return from AimWeapon (no sleeps, not wait for turns!)
			-- So you have to manually check in script if it is at the desired heading
			-- https://springrts.com/phpbb/viewtopic.php?t=36654
			Spring.SetUnitWeaponState(unitID, id, "reaimTime", convertedUnits[unitDefID])
		end
	end
end
