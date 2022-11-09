--------------------------------------------------------------------------------

unitName = "lozdiamondback"

--------------------------------------------------------------------------------

humanName = [[Diamondback]]

objectName = "lozdiamondback.s3o"
script = "lozdiamondback_lus.lua"

tech = [[tech1]]

explodeAs = [[smallexplosiongenericred]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/Tier 1/lozdiamondback_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
