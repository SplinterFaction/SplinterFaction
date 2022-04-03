--------------------------------------------------------------------------------

unitName = "fedcrasher"

--------------------------------------------------------------------------------
humanName = [[Crasher]]

objectName = "ehbotrocko_legs.s3o"
script = "fed/hbot/fedcrasher_lus.lua"

tech = [[tech1]]
armortype = [[light]]
supply = [[15]]

VFS.Include("units-configs-basedefs/basedefs/hbot/fed/fedcrasher_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------