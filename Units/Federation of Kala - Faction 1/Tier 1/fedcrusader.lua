--------------------------------------------------------------------------------

unitName = "fedcrusader"

--------------------------------------------------------------------------------

humanName = [[Crusader]]

objectName = "fedcrusader.s3o"
script = "fedcrusader_lus.lua"

tech = [[tech1]]

explodeAs = [[mediumexplosiongeneric]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/Tier 1/fedcrusader_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
