--------------------------------------------------------------------------------

unitName = "fedstorm"

--------------------------------------------------------------------------------
humanName = [[Storm]]

objectName = "fedstorm.s3o"
script = "fed/hbot/fedstorm_lus.lua"

tech = [[tech1]]

explodeAs = [[smallexplosiongeneric]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/Tier 1/fedstorm_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------