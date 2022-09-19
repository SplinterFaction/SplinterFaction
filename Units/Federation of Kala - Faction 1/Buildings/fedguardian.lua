--------------------------------------------------------------------------------

unitName = [[fedguardian]]

--------------------------------------------------------------------------------

humanName = [[guardian]]

objectName = [[fedguardian.s3o]]
script = [[fedguardian_lus.lua]]

tech = [[tech3]]

VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/buildings/fedguardian_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------