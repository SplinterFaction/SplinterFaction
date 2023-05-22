--------------------------------------------------------------------------------

unitName = "fedconqueror"

--------------------------------------------------------------------------------

humanName = [[Conqueror]]

objectName = "fedconqueror.s3o"
script = "fedconqueror_lus.lua"

tech = [[tech2]]

explodeAs = [[largeexplosiongeneric]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/Tier 2/fedconqueror_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
