--------------------------------------------------------------------------------

unitName = [[chickenemperormenlo]]

--------------------------------------------------------------------------------

humanName = [[Emperor Menlo]]

objectName = [[chickenemperormenlo.s3o]]
script = [[chickenemperormenlo.lua]]

tech = [[tech1]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/chickens/chickenemperormenlo_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------