--------------------------------------------------------------------------------

unitName = "f1landfac_ai"

--------------------------------------------------------------------------------

buildCostMetal = 300

humanName = [[Land Factory]]

objectName = "f1landfac.s3o"
script = "eallterrfac2.cob"

tech = [[tech1]]

F1LandFacBuildList = Shared.buildListf1landfac_ai

explodeAs = [[largebuildingexplosiongeneric]]

workerTime = 1 -- Baseline because this gets multiplied in the tech based factory buildspeed gadget

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/f1landfac_basedef.lua")

--------------------------------------------------------------------------------

return lowerkeys({ [unitName]      = unitDef })

--------------------------------------------------------------------------------
