--------------------------------------------------------------------------------

unitName = "fedstreetsweeper"

--------------------------------------------------------------------------------

isUpgraded = [[0]]

humanName = [[StreetSweeper]]

objectName = "eallterrriot2.s3o"
script = "eallterrriot.cob"

tech = [[tech2]]
armortype = [[light]]
supply = [[3]]

VFS.Include("Units-Configs-Basedefs/basedefs/allterrain/fed/fedstreetsweeper_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------