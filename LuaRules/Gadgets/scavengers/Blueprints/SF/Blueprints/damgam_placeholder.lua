local blueprintConfig = VFS.Include('luarules/gadgets/scavengers/Blueprints/' .. Game.gameShortName .. '/blueprint_tiers.lua')
local tiers = blueprintConfig.Tiers
local types = blueprintConfig.BlueprintTypes
local UDN = UnitDefNames

local function blueprint0()
	return {
		type = types.Land,
		tiers = { tiers.T0, tiers.T1, tiers.T2, tiers.T3, tiers.T4 },
		radius = 80,
		buildings = {
			{ unitDefID = UnitDefNames.fedwasp_scav.id, xOffset = 0, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.fedmenlo_scav.id, xOffset = 32, zOffset = 80, direction = 0},
			{ unitDefID = UnitDefNames.lozjericho_scav.id, xOffset = 32, zOffset = -80, direction = 2},
			{ unitDefID = UnitDefNames.fedmenlo_scav.id, xOffset = 80, zOffset = 32, direction = 1},
			{ unitDefID = UnitDefNames.lozjericho_scav.id, xOffset = -80, zOffset = -32, direction = 3},
			{ unitDefID = UnitDefNames.fedmenlo_scav.id, xOffset = -80, zOffset = 32, direction = 3},
			{ unitDefID = UnitDefNames.lozjericho_scav.id, xOffset = -32, zOffset = -80, direction = 2},
			{ unitDefID = UnitDefNames.fedmenlo_scav.id, xOffset = 80, zOffset = -32, direction = 1},
			{ unitDefID = UnitDefNames.lozjericho_scav.id, xOffset = -32, zOffset = 80, direction = 0},
		},
	}
end

local function blueprint1()
	return {
		type = types.Land,
		tiers = { tiers.T0, tiers.T1, tiers.T2, tiers.T3, tiers.T4 },
		radius = 24,
		buildings = {
			{ unitDefID = UnitDefNames.fedmenlo_scav.id, xOffset = 24, zOffset = -24, direction = 1},
			{ unitDefID = UnitDefNames.lozjericho_scav.id, xOffset = -24, zOffset = 24, direction = 3},
			{ unitDefID = UnitDefNames.fissionpowerplant_scav.id, xOffset = 24, zOffset = 24, direction = 0},
			{ unitDefID = UnitDefNames.fissionpowerplant_scav.id, xOffset = -24, zOffset = -24, direction = 0},
		},
	}
end

return {
	blueprint0,
	blueprint1,
}