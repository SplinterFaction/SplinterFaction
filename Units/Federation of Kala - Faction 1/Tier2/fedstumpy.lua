--------------------------------------------------------------------------------

unitName = "fedstumpy"

--------------------------------------------------------------------------------

isUpgraded = [[0]]

humanName = [[Stumpy]]

objectName = "eallterrmed2.s3o"
script = "eallterrmed.cob"

tech = [[tech2]]
armortype = [[armored]]
supply = [[4]]

VFS.Include("Units-Configs-Basedefs/basedefs/allterrain/fed/fedstumpy_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------