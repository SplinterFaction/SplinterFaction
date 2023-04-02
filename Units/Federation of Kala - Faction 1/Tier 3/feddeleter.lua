--------------------------------------------------------------------------------

unitName = "feddeleter"

--------------------------------------------------------------------------------
humanName = [[Deleter]]

objectName = "feddeleter.s3o"
script = "/fed/hbot/feddeleter_lus.lua"

tech = [[tech3]]

explodeAs = [[largeexplosiongeneric]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/Tier 3/feddeleter_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------