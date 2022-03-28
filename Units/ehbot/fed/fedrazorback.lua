--------------------------------------------------------------------------------

unitName = "fedrazorback"

--------------------------------------------------------------------------------

isUpgraded = [[0]]

humanName = [[Razorback]]

objectName = "ehbotkarganneth_legs.s3o"
script = "ehbotkarganneth_lus.lua"

tech = [[tech3]]
armortype = [[armored]]

VFS.Include("units-configs-basedefs/basedefs/hbot/fed/fedrazorback_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------