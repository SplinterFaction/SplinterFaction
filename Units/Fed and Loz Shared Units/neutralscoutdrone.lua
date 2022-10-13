--------------------------------------------------------------------------------

unitName = "neutralscoutdrone"

--------------------------------------------------------------------------------

humanName = [[Gnat]]

objectName = "neutralscoutdrone.s3o"
script = "neutralscoutdrone_lus.lua"

tech = [[tech1]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Fed and Loz Shared Units/neutralscoutdrone_basedef.lua")

--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
