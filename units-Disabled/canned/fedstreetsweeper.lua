--------------------------------------------------------------------------------

unitName = "fedstreetsweeper"

--------------------------------------------------------------------------------
humanName = [[StreetSweeper]]

objectName = "eallterrriot2.s3o"
script = "eallterrriot.cob"

tech = [[tech2]]
armortype = [[armored]]
supply = [[3]]

VFS.Include("Units-Configs-Basedefs/basedefs/Federation of Kala - Faction 1/Tier 2/fedstreetsweeper_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------