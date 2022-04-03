--------------------------------------------------------------------------------

unitName = "fedak"

--------------------------------------------------------------------------------
humanName = [[A.K.]]

objectName = "ehbotak_legs.s3o"
script = "fed/hbot/fedak_lus.lua"

tech = [[tech1]]
armortype = [[light]]
supply = [[6]]

VFS.Include("units-configs-basedefs/basedefs/hbot/fed/fedak_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------