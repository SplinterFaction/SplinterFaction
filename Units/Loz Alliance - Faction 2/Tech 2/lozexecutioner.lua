--------------------------------------------------------------------------------

unitName = "lozexecutioner"

--------------------------------------------------------------------------------

humanName = [[Executioner]]

objectName = "lozexecutioner.s3o"
script = "lozexecutioner_lus.lua"

tech = [[tech2]]

explodeAs = [[largeexplosiongeneric]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/Tier 2/lozexecutioner_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
