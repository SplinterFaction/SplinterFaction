--------------------------------------------------------------------------------

unitName = "fedjuggernaut"

--------------------------------------------------------------------------------
humanName = [[Juggernaut]]

objectName = "fedjuggernaut2.s3o"
script = "/fed/hbot/fedjuggernaut_lus.lua"

tech = [[tech4]]

explodeAs = [[hugeexplosiongenericred]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/Tier 4/fedjuggernaut_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------