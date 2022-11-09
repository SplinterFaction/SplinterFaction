--------------------------------------------------------------------------------

unitName = [[lozjericho]]

--------------------------------------------------------------------------------

humanName = [[Jericho]]

objectName = [[lozjericho.s3o]]
script = [[lozjericho_lus.lua]]

tech = [[tech1]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/buildings/lozjericho_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------