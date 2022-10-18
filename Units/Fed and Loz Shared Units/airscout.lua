--------------------------------------------------------------------------------

unitName = "airscout"

--------------------------------------------------------------------------------

humanName = [[Gnat]]

objectName = "airscout.s3o"
script = "airscout_lus.lua"


tech = [[tech1]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("Units-Configs-Basedefs/basedefs/Fed and Loz Shared Units/airscout_basedef.lua")

unitDef.weaponDefs = weaponDefs

--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
