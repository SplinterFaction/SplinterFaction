--------------------------------------------------------------------------------

unitName = "lozairplant"

--------------------------------------------------------------------------------

buildCostMetal = 150

humanName = [[VTOL Factory]]

objectName = "lozairplant.s3o"
script = "lozairplant.cob"

airPlantBuildList = Shared.buildListFedAirPlant

explodeAs = [[largebuildingexplosiongeneric]]

factionname = "Loz Alliance"

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Fed and Loz Shared Buildings/airplant_basedef.lua")

--------------------------------------------------------------------------------

return lowerkeys({ [unitName]      = unitDef })

--------------------------------------------------------------------------------