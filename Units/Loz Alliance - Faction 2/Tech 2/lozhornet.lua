--------------------------------------------------------------------------------

unitName = "lozhornet"

--------------------------------------------------------------------------------

humanName = [[Hornet]]

objectName = "lozhornet.s3o"
script = "lozhornet_lus.lua"


tech = [[tech2]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("Units-Configs-Basedefs/basedefs/Loz Alliance - Faction 2/Tier 2/lozhornet_basedef.lua")

unitDef.weaponDefs = weaponDefs

--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
