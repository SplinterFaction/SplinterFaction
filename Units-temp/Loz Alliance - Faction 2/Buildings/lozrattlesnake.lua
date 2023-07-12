--------------------------------------------------------------------------------

unitName = [[lozrattlesnake]]

--------------------------------------------------------------------------------

humanName = [[Rattlesnake]]

objectName = [[lozrattlesnake.s3o]]
script = [[lozrattlesnake_lus.lua]]

tech = [[tech2]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/buildings/lozrattlesnake_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------