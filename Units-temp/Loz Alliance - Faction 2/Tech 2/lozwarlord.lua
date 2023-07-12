--------------------------------------------------------------------------------

unitName = "lozwarlord"

--------------------------------------------------------------------------------

humanName = [[Warlord]]

objectName = "lozwarlord.s3o"
script = "lozwarlord_lus.lua"

tech = [[tech2]]

explodeAs = [[largeexplosiongeneric]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/Tier 2/lozwarlord_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
