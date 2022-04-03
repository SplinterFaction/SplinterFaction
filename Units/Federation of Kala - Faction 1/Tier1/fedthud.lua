--------------------------------------------------------------------------------

unitName = "fedthud"

--------------------------------------------------------------------------------
humanName = [[Thud]]

objectName = "ehbotthud_legs.s3o"
script = "fedthud_lus.lua"

tech = [[tech1]]
armortype = [[light]]
supply = [[7]]

VFS.Include("units-configs-basedefs/basedefs/hbot/fed/fedthud_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------