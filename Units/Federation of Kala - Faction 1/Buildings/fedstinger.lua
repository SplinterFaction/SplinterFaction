--------------------------------------------------------------------------------

unitName = [[fedstinger]]

--------------------------------------------------------------------------------

humanName = [[Stinger]]

objectName = [[fedstinger.s3o]]
script = [[fedwasp_lus.lua]]

tech = [[tech1]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/buildings/fedstinger_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------