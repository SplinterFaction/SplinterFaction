--------------------------------------------------------------------------------

unitName = "lozroach"

--------------------------------------------------------------------------------

humanName = [[Roach]]

objectName = "lozroach.s3o"
script = "lozroach_lus.lua"

tech = [[tech1]]

explodeAs = [[smallexplosiongeneric]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/Tier 1/lozroach_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
