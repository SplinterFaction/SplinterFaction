--------------------------------------------------------------------------------

unitName = "fedcrasher"

--------------------------------------------------------------------------------
humanName = [[Crasher]]

objectName = "fedcrasher.s3o"
script = "fed/hbot/fedcrasher_lus.lua"

tech = [[tech1]]

explodeAs = [[smallexplosiongenericpurple]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/Tier 1/fedcrasher_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------