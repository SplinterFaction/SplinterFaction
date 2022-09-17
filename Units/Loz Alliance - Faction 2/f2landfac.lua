-- UNITDEF -- f2landfac --
--------------------------------------------------------------------------------

unitName = "f2landfac"

--------------------------------------------------------------------------------

buildCostMetal = 300
maxDamage = buildCostMetal * 12.5

humanName = [[Land Factory]]

objectName = "f2landfac.s3o"
script = "f2landfac.cob"

tech = [[tech1]]

explodeAs = [[largebuildingexplosiongeneric]]

hoverFactoryBuildList = Shared.buildListf2landfac

VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/f2landfac_basedef.lua")

--------------------------------------------------------------------------------

return lowerkeys({ [unitName]     = unitDef })

--------------------------------------------------------------------------------
