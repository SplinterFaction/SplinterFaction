--------------------------------------------------------------------------------

unitName = [[fedearthquakemine]]

--------------------------------------------------------------------------------

humanName = [[Earthquake Mine]]

objectName = [[fedearthquakemine.s3o]]
script = [[fedearthquakemine.cob]]

tech = [[tech1]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/buildings/fedearthquakemine_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------