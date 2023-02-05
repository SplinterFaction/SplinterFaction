--------------------------------------------------------------------------------

unitName = "fedairplant"

--------------------------------------------------------------------------------

buildCostMetal = 150

humanName = [[VTOL Factory]]

objectName = "fedairplant.s3o"
script = "fedairplant.cob"

tech = [[tech1]]

airPlantBuildList = Shared.buildListFedAirPlant

explodeAs = [[largebuildingexplosiongeneric]]

workerTime = 1 -- Baseline because this gets multiplied in the tech based factory buildspeed gadget

factionname = "Federation of Kala"

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Fed and Loz Shared Buildings/airplant_basedef.lua")

--------------------------------------------------------------------------------

return lowerkeys({ [unitName]      = unitDef })

--------------------------------------------------------------------------------