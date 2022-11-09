--------------------------------------------------------------------------------

unitName = "fedbasher"

--------------------------------------------------------------------------------
humanName = [[Basher]]

objectName = "eallterrmed2.s3o"
script = "eallterrmed.cob"

tech = [[tech2]]
armortype = [[armored]]
supply = [[4]]

VFS.Include("Units-Configs-Basedefs/basedefs/Federation of Kala - Faction 1/Tier 2/fedbasher_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------