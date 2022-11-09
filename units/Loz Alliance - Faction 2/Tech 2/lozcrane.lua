--------------------------------------------------------------------------------

unitName = "lozcrane"

--------------------------------------------------------------------------------

humanName = [[Crane]]

objectName = "lozcrane.s3o"
script = "lozcrane_lus.lua"


tech = [[tech2]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("Units-Configs-Basedefs/basedefs/Loz Alliance - Faction 2/Tier 2/lozcrane_basedef.lua")

unitDef.weaponDefs = weaponDefs

--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
