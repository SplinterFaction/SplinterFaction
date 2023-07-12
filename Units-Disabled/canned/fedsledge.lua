--------------------------------------------------------------------------------

unitName = "fedsledge"

--------------------------------------------------------------------------------
humanName = [[Sledge]]

objectName = "eallterrheavy2.s3o"
script = "eallterrheavy.cob"

tech = [[tech2]]
armortype = [[armored]]
supply = [[6]]

VFS.Include("Units-Configs-Basedefs/basedefs/Federation of Kala - Faction 1/Tier 2/fedsledge_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------