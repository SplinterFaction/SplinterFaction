--------------------------------------------------------------------------------

unitName = "fedzipper"

--------------------------------------------------------------------------------

isUpgraded = [[0]]

humanName = [[Zipper]]

objectName = "eallterrlight2.s3o"
script = "eallterrlight.cob"

tech = [[tech2]]
armortype = [[light]]
supply = [[2]]

VFS.Include("Units-Configs-Basedefs/basedefs/allterrain/fed/fedzipper_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------