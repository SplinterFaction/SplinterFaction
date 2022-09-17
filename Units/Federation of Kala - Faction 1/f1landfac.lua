-- UNITDEF -- f1landfac --
--------------------------------------------------------------------------------

unitName = "f1landfac"

--------------------------------------------------------------------------------

buildCostMetal = 300

humanName = [[Land Factory]]

objectName = "eallterrfac2.s3o"
script = "eallterrfac2.cob"

tech = [[tech1]]

F1LandFacBuildList = Shared.buildListf1landfac

explodeAs = [[largebuildingexplosiongeneric]]

VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/f1landfac_basedef.lua")

--------------------------------------------------------------------------------

return lowerkeys({ [unitName]      = unitDef })

--------------------------------------------------------------------------------
