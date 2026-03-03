--------------------------------------------------------------------------------

unitName = [[lozearthquakemine]]

--------------------------------------------------------------------------------

humanName = [[Earthquake Mine]]

objectName = [[fedearthquakemine.s3o]]
script = [[fedearthquakemine.cob]]

tech = [[tech1]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 1/buildings/lozearthquakemine_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------