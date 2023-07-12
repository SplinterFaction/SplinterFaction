--------------------------------------------------------------------------------

unitName = "fedpiranha"

--------------------------------------------------------------------------------

humanName = [[Piranha]]

objectName = "fedpiranha.s3o"
script = "fedpiranha_lus.lua"

tech = [[tech1]]

explodeAs = [[mediumexplosiongeneric]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/Tier 1/fedpiranha_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
