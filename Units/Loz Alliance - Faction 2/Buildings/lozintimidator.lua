--------------------------------------------------------------------------------

unitName = [[lozintimidator]]

--------------------------------------------------------------------------------

humanName = [[Intimidator]]

objectName = [[lozintimidator.s3o]]
script = [[lozintimidator_lus.lua]]

tech = [[tech3]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/buildings/lozintimidator_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------