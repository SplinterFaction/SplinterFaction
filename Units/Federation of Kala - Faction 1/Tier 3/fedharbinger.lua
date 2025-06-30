--------------------------------------------------------------------------------

unitName = "fedharbinger"

--------------------------------------------------------------------------------

humanName = [[Harbinger]]

objectName = "fedharbinger.s3o"
script = "fedharbinger_lus.lua"

tech = [[tech3]]

explodeAs = [[hugeExplosionGeneric]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/Tier 3/fedharbinger_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
