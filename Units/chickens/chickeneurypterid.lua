--------------------------------------------------------------------------------

unitName = "chickeneurypterid"

--------------------------------------------------------------------------------

humanName = "Eurypterid"

objectName = "chickeneurypterid.s3o"
script = "chickeneurypterid_lus.lua"

tech = [[tech4]]

explodeAs = [[hugeexplosiongeneric]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("Units-Configs-Basedefs/basedefs/chickens/chickeneurypterid_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
