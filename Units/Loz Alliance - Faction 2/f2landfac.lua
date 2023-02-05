-- UNITDEF -- f2landfac --
--------------------------------------------------------------------------------

unitName = "f2landfac"

--------------------------------------------------------------------------------

buildCostMetal = 300

humanName = [[Land Factory]]

objectName = "f2landfac.s3o"
script = "f2landfac.cob"

tech = [[tech1]]

explodeAs = [[largebuildingexplosiongeneric]]

workertime = 1 -- Baseline because this gets multiplied in the tech based factory buildspeed gadget

hoverFactoryBuildList = Shared.buildListf2landfac

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/f2landfac_basedef.lua")

--------------------------------------------------------------------------------

return lowerkeys({ [unitName]     = unitDef })

--------------------------------------------------------------------------------
