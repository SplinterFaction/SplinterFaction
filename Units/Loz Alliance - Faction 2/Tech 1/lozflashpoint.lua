--------------------------------------------------------------------------------

unitName = "lozflashpoint"

--------------------------------------------------------------------------------

humanName = [[Flashpoint]]

objectName = "lozflashpoint.s3o"
script = "lozflashpoint_lus.lua"

tech = [[tech1]]

explodeAs = [[smallexplosiongeneric]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/Tier 1/lozflashpoint_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
