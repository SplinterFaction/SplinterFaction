--------------------------------------------------------------------------------

unitName = "fedrecluse"

--------------------------------------------------------------------------------
humanName = [[Recluse]]

objectName = "eallterrlight2.s3o"
script = "eallterrlight.cob"

tech = [[tech2]]
armortype = [[armored]]
supply = [[2]]

VFS.Include("Units-Configs-Basedefs/basedefs/Federation of Kala - Faction 1/Tier 2/fedrecluse_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------