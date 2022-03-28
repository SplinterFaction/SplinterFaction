--------------------------------------------------------------------------------

unitName = "federaser"

--------------------------------------------------------------------------------

isUpgraded = [[0]]

humanName = [[Eraser]]

objectName = "eallterrshield.s3o"
script = "eallterrshield.cob"

tech = [[tech2]]
armortype = [[light]]
supply = [[5]]

VFS.Include("Units-Configs-Basedefs/basedefs/allterrain/fed/federaser_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------