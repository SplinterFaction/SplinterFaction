--------------------------------------------------------------------------------

unitName = "chickenanarchid"

--------------------------------------------------------------------------------

humanName = [[Anarchid]]

objectName = "chickenanarchid.s3o"
script = "chickenanarchid.cob"

tech = [[tech4]]

explodeAs = [[hugeexplosiongeneric]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("Units-Configs-Basedefs/basedefs/chickens/chickenanarchid_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------