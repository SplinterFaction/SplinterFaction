--------------------------------------------------------------------------------

unitName = "fedfalcon"

--------------------------------------------------------------------------------

humanName = [[Falcon]]

objectName = "fedfalcon.s3o"
script = "fedfalcon_lus.lua"


tech = [[tech3]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("Units-Configs-Basedefs/basedefs/Federation of Kala - Faction 1/Tier 3/fedfalcon_basedef.lua")

unitDef.weaponDefs = weaponDefs

--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
