--------------------------------------------------------------------------------

unitName = "fedairplant"

--------------------------------------------------------------------------------

buildCostMetal = 150

humanName = [[VTOL Factory]]

objectName = "sharedairplant.s3o"
script = "sharedairplant.cob"

airPlantBuildList = Shared.buildListFedAirPlant

explodeAs = [[largebuildingexplosiongeneric]]

factionname = "Federation of Kala"

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Fed and Loz Shared Buildings/airplant_basedef.lua")

--------------------------------------------------------------------------------

return lowerkeys({ [unitName]      = unitDef })

--------------------------------------------------------------------------------