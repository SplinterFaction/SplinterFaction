--------------------------------------------------------------------------------

unitName = "loztitan"

--------------------------------------------------------------------------------

humanName = [[Titan]]

objectName = "loztitan.s3o"
script = "loztitan_lus.lua"


tech = [[tech3]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("Units-Configs-Basedefs/basedefs/Loz Alliance - Faction 2/Tier 3/loztitan_basedef.lua")

unitDef.weaponDefs = weaponDefs

--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
