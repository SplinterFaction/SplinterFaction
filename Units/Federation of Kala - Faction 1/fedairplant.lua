-- UNITDEF -- FEDAIRPLANT --
--------------------------------------------------------------------------------

unitName = "fedairplant"

--------------------------------------------------------------------------------

buildCostMetal = 600

humanName = [[VTOL Factory]]

objectName = "eairplant3.s3o"
script = "eairplant3.cob"

airPlantBuildList = Shared.buildListAirPlant

explodeAs = [[largebuildingexplosiongenericred]]

VFS.Include("Units-Configs-Basedefs/basedefs/Federation of Kala - Faction 1/fedairplant_basedef.lua")

--------------------------------------------------------------------------------

return lowerkeys({ [unitName]      = unitDef })

--------------------------------------------------------------------------------
