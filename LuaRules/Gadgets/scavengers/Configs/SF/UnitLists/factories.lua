local factories = {
	"f1landfac",
	"f2landfac",
	"fedairplant",
	"lozairplant",
}

local scavFactories = {}
for _, name in ipairs(factories) do
	table.insert(scavFactories, name .. scavconfig.unitnamesuffix)
end

for _, name in ipairs(scavFactories) do
	table.insert(factories, name)
end

local factoriesID = {}
for _, unitName in ipairs(factories) do
	local unitDefID = UnitDefNames[unitName].id
	factoriesID[unitDefID] = true
end

local factoryBannedUnits = {

}

return {
	Factories = factories,
	FactoriesID = factoriesID,
	FactoryBannedUnits = factoryBannedUnits,
}