--------------------------------------------------------------------------------

unitName = "airscoutxl"

--------------------------------------------------------------------------------

humanName = [[Cicada]]

objectName = "airscoutxl.s3o"
script = "airscout_lus.lua"


tech = [[tech3]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("Units-Configs-Basedefs/basedefs/Fed and Loz Shared Units/airscoutxl_basedef.lua")

unitDef.weaponDefs = weaponDefs

--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
