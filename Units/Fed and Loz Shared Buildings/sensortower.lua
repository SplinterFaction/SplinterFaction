--------------------------------------------------------------------------------

unitName = [[sensortower]]

--------------------------------------------------------------------------------

humanName = [[Seismic Sensor]]

objectName = [[sensortower.s3o]]
script = [[fedearthquakemine.cob]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Fed and Loz Shared Buildings/sensortower_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------