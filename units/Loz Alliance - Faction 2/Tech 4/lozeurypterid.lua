--------------------------------------------------------------------------------

unitName = "lozeurypterid"

--------------------------------------------------------------------------------

humanName = "Eurypterid"

objectName = "lozeurypterid.s3o"
script = "lozeurypterid_lus.lua"

tech = [[tech4]]

explodeAs = [[hugeexplosiongeneric]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/Tier 4/lozeurypterid_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
