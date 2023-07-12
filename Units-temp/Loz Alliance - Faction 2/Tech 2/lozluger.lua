--------------------------------------------------------------------------------

unitName = "lozluger"

--------------------------------------------------------------------------------

humanName = "Luger"

objectName = "lozluger.s3o"
script = "lozluger_lus.lua"

tech = [[tech2]]

explodeAs = [[mediumexplosiongenericred]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/Tier 2/lozluger_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
