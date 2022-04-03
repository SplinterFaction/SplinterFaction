--------------------------------------------------------------------------------

unitName = "fedsledge"

--------------------------------------------------------------------------------

isUpgraded = [[0]]

humanName = [[Sledge]]

objectName = "eallterrheavy2.s3o"
script = "eallterrheavy.cob"

tech = [[tech2]]
armortype = [[armored]]
supply = [[6]]

VFS.Include("Units-Configs-Basedefs/basedefs/allterrain/fed/fedsledge_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------