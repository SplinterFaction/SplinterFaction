--------------------------------------------------------------------------------

unitName = "lozseaplant"

--------------------------------------------------------------------------------

buildCostMetal = 300

humanName = [[Sea Factory]]

objectName = "sharedseaplant.s3o"
script = "sharedseaplant.cob"

tech = [[tech1]]

lozseaplantbuildlist = Shared.buildListLozSeaPlant

explodeAs = [[largebuildingexplosiongeneric]]

workertime = 1 -- Baseline because this gets multiplied in the tech based factory buildspeed gadget

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/lozseaplant_basedef.lua")

--------------------------------------------------------------------------------

return lowerkeys({ [unitName]      = unitDef })

--------------------------------------------------------------------------------
