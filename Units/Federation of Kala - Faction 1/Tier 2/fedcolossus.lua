--------------------------------------------------------------------------------

unitName = "fedcolossus"

--------------------------------------------------------------------------------

humanName = [[Colossus]]

objectName = "fedcolossus.s3o"
script = "fedcolossus_lus.lua"

tech = [[tech2]]

explodeAs = [[largeexplosiongeneric]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/Tier 2/fedcolossus_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
