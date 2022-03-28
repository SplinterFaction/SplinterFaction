--------------------------------------------------------------------------------

unitName = "fedanarchid"

--------------------------------------------------------------------------------

isUpgraded = [[0]]

humanName = [[Anarchid]]

objectName = "eallterranarchid.s3o"
script = "eallterranarchid.cob"

tech = [[tech3]]
armortype = [[armored]]
--supply = [[35]]

VFS.Include("Units-Configs-Basedefs/basedefs/allterrain/fed/fedanarchid_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------