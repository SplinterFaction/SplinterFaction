--------------------------------------------------------------------------------

unitName = "lozleviathan"

--------------------------------------------------------------------------------

humanName = [[leviathan]]

objectName = "lozleviathan.s3o"
script = "lozleviathan_lus.lua"

tech = [[tech3]]

explodeAs = [[largeexplosiongeneric]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/Tier 3/lozleviathan_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
