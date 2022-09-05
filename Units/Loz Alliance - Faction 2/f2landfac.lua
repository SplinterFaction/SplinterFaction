-- UNITDEF -- f2landfac --
--------------------------------------------------------------------------------

unitName = "f2landfac"

--------------------------------------------------------------------------------

buildCostMetal = 60
maxDamage = buildCostMetal * 12.5

humanName = [[Land Factory]]

objectName = "f2landfac.s3o"
script = "f2landfac.cob"

tech = [[tech1]]

hoverFactoryBuildList = Shared.buildListf2landfac

VFS.Include("units-configs-basedefs/basedefs/hover/f2landfac_basedef.lua")

--------------------------------------------------------------------------------

return lowerkeys({ [unitName]     = unitDef })

--------------------------------------------------------------------------------
