local blueprintConfig = VFS.Include('luarules/gadgets/scavengers/Blueprints/' .. Game.gameShortName .. '/blueprint_tiers.lua')
local tiers = blueprintConfig.Tiers
local types = blueprintConfig.BlueprintTypes
local UDN = UnitDefNames

local function blueprint0()
	return {
		type = types.Land,
		tiers = { tiers.T0, tiers.T1, tiers.T2, tiers.T3, tiers.T4 },
		radius = 0,
		buildings = {
		},
	}
end

local function blueprint1()
	return {
		type = types.Land,
		tiers = { tiers.T0, tiers.T1, tiers.T2, tiers.T3, tiers.T4 },
		radius = 389,
		buildings = {
			{ unitDefID = UnitDefNames.emine_scav.id, xOffset = -499, zOffset = 156, direction = 0},
			{ unitDefID = UnitDefNames.emine_scav.id, xOffset = -499, zOffset = 156, direction = 0},
			{ unitDefID = UnitDefNames.eradar2_scav.id, xOffset = -323, zOffset = -116, direction = 0},
			{ unitDefID = UnitDefNames.esolar2_scav.id, xOffset = -259, zOffset = -100, direction = 1},
			{ unitDefID = UnitDefNames.estorage_scav.id, xOffset = 341, zOffset = -108, direction = 0},
			{ unitDefID = UnitDefNames.estorage_scav.id, xOffset = 341, zOffset = -12, direction = 0},
			{ unitDefID = UnitDefNames.estorage_scav.id, xOffset = 341, zOffset = 36, direction = 0},
			{ unitDefID = UnitDefNames.esolar2_scav.id, xOffset = -227, zOffset = -100, direction = 1},
			{ unitDefID = UnitDefNames.esolar2_scav.id, xOffset = -227, zOffset = -132, direction = 1},
			{ unitDefID = UnitDefNames.estorage_scav.id, xOffset = 389, zOffset = -12, direction = 0},
			{ unitDefID = UnitDefNames.esolar2_scav.id, xOffset = -259, zOffset = -132, direction = 1},
			{ unitDefID = UnitDefNames.estorage_scav.id, xOffset = 293, zOffset = 36, direction = 0},
			{ unitDefID = UnitDefNames.estorage_scav.id, xOffset = 389, zOffset = 36, direction = 0},
			{ unitDefID = UnitDefNames.estorage_scav.id, xOffset = 389, zOffset = -60, direction = 0},
			{ unitDefID = UnitDefNames.estorage_scav.id, xOffset = 389, zOffset = -108, direction = 0},
			{ unitDefID = UnitDefNames.estorage_scav.id, xOffset = 293, zOffset = -12, direction = 0},
			{ unitDefID = UnitDefNames.estorage_scav.id, xOffset = 293, zOffset = -108, direction = 0},
			{ unitDefID = UnitDefNames.estorage_scav.id, xOffset = 293, zOffset = -60, direction = 0},
			{ unitDefID = UnitDefNames.estorage_scav.id, xOffset = 341, zOffset = -60, direction = 0},
			{ unitDefID = UnitDefNames.elightturret2_scav.id, xOffset = 93, zOffset = 124, direction = 0},
			{ unitDefID = UnitDefNames.elightturret2_scav.id, xOffset = 13, zOffset = 300, direction = 0},
			{ unitDefID = UnitDefNames.elightturret2_scav.id, xOffset = -419, zOffset = 284, direction = 0},
			{ unitDefID = UnitDefNames.elightturret2_scav.id, xOffset = -403, zOffset = -84, direction = 0},
			{ unitDefID = UnitDefNames.elaserbattery_scav.id, xOffset = -411, zOffset = 84, direction = 0},
			{ unitDefID = UnitDefNames.eflakturret_scav.id, xOffset = -59, zOffset = -28, direction = 0},
			{ unitDefID = UnitDefNames.eheavyturret2_scav.id, xOffset = 181, zOffset = 324, direction = 0},
			{ unitDefID = UnitDefNames.eheavyturret2_scav.id, xOffset = -523, zOffset = 84, direction = 0},
			{ unitDefID = UnitDefNames.eheavyturret2_scav.id, xOffset = 53, zOffset = -28, direction = 0},
			{ unitDefID = UnitDefNames.f1landfac_scav.id, xOffset = -235, zOffset = 116, direction = 0},
			{ unitDefID = UnitDefNames.egeothermal_scav.id, xOffset = -275, zOffset = -260, direction = 0},
			{ unitDefID = UnitDefNames.egeothermal_scav.id, xOffset = 205, zOffset = -212, direction = 0},
		},
	}
end

return {
	blueprint0,
}