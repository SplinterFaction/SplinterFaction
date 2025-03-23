--------------------------------------------------------------------------------

unitName = "lozflea"

--------------------------------------------------------------------------------
humanName = [[Flea]]

objectName = "lozflea2.s3o"
script = "lozflea_lus.lua"

tech = [[tech1]]

explodeAs = [[smallexplosiongenericwhite]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/Tier 1/lozflea_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
