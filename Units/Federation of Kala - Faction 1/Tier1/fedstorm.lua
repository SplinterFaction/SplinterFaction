--------------------------------------------------------------------------------

unitName = "fedstorm"

--------------------------------------------------------------------------------
humanName = [[Storm]]

objectName = "ehbotsniper_legs.s3o"
script = "fed/hbot/fedstorm_lus.lua"

tech = [[tech1]]
armortype = [[light]]
supply = [[9]]

VFS.Include("units-configs-basedefs/basedefs/hbot/fed/fedstorm_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------