--------------------------------------------------------------------------------

unitName = [[fedjavelin]]

--------------------------------------------------------------------------------

humanName = [[Javelin]]

objectName = [[fedjavelin.s3o]]
script = [[fedjavelin_lus.lua]]

tech = [[tech2]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/buildings/fedjavelin_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------