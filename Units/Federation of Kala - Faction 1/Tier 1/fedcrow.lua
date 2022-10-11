--------------------------------------------------------------------------------

unitName = "fedcrow"

--------------------------------------------------------------------------------

humanName = [[Crow]]

objectName = "fedcrow.s3o"
script = "fedcrow_lus.lua"


tech = [[tech1]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("Units-Configs-Basedefs/basedefs/Federation of Kala - Faction 1/Tier 1/fedcrow_basedef.lua")

unitDef.weaponDefs = weaponDefs

--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
