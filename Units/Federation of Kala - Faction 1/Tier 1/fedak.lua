--------------------------------------------------------------------------------

unitName = "fedak"

--------------------------------------------------------------------------------
humanName = [[A.K.]]

objectName = "fedakmk1.s3o"
script = "fed/hbot/fedak_lus.lua"

tech = [[tech1]]

explodeAs = [[smallexplosiongenericred]]

VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/Tier 1/fedak_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------