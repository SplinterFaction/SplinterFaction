--------------------------------------------------------------------------------

unitName = "lozflea"

--------------------------------------------------------------------------------
humanName = [[Flea]]

objectName = "lozflea.s3o"
script = "lozflea_lus.lua"

tech = [[tech1]]
armortype = [[light]]
supply = [[1]]

VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/Tier 1/lozflea_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
