--------------------------------------------------------------------------------

unitName = "fedseaplant"

--------------------------------------------------------------------------------

buildCostMetal = 300

humanName = [[Sea Factory]]

objectName = "fedseaplant.s3o"
script = "fedseaplant.cob"

tech = [[tech1]]

buildlist = Shared.buildListFedSeaPlant

explodeAs = [[largebuildingexplosiongeneric]]

workertime = 1 -- Baseline because this gets multiplied in the tech based factory buildspeed gadget

faction = [[Federation of Kala]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Fed and Loz Shared Buildings/seaplant_basedef.lua")

--------------------------------------------------------------------------------

return lowerkeys({ [unitName]      = unitDef })

--------------------------------------------------------------------------------
