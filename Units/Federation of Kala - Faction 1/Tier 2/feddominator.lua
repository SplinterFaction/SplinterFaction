--------------------------------------------------------------------------------

unitName = "feddominator"

--------------------------------------------------------------------------------
humanName = [[Dominator]]

objectName = "feddominator.s3o"
script = "/fed/hbot/feddominator_lus.lua"

tech = [[tech2]]

explodeAs = [[mediumexplosiongeneric]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/Tier 2/feddominator_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------