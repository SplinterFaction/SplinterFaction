--------------------------------------------------------------------------------

unitName = "lozsnake"

--------------------------------------------------------------------------------

humanName = [[Snake]]

objectName = "lozsnake.s3o"
script = "lozsnake_lus.lua"

tech = [[tech1]]

explodeAs = [[mediumexplosiongeneric]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/Tier 1/lozsnake_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
