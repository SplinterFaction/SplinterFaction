--------------------------------------------------------------------------------

unitName = "lozseaplant"

--------------------------------------------------------------------------------

buildCostMetal = 300

humanName = [[Sea Factory]]

objectName = "sharedseaplant2.s3o"
script = "sharedseaplant.cob"

tech = [[tech1]]

buildlist = Shared.buildListLozSeaPlant

explodeAs = [[largebuildingexplosiongeneric]]

workertime = 1 -- Baseline because this gets multiplied in the tech based factory buildspeed gadget

faction = [[Loz Alliance]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Fed and Loz Shared Buildings/seaplant_basedef.lua")

--------------------------------------------------------------------------------

return lowerkeys({ [unitName]      = unitDef })

--------------------------------------------------------------------------------
