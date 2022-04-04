--------------------------------------------------------------------------------

unitName = "fedthud"

--------------------------------------------------------------------------------
humanName = [[Thud]]

objectName = "ehbotthud_legs.s3o"
script = "fedthud_lus.lua"

tech = [[tech1]]
armortype = [[light]]
supply = [[7]]

VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/Tier 1/fedthud_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------