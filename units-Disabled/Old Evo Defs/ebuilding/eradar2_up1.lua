-- UNITDEF -- eradar2_up1 --
--------------------------------------------------------------------------------

unitName = [[eradar2_up1]]	
buildpic = [[eradar2_up1.png]]

buildCostMetal = 100

humanName = [[Radar Tower]]
objectName = [[eradar3_large.s3o]]

radarDistance = 3000
radarEmitHeight = 128

sightDistance = 3000
sonarDistance = 3000
seismicDistance = 3000

tech = [[tech2]]
armortype = [[building]]


VFS.Include("units-configs-basedefs/basedefs/buildings/eradar2_basedef.lua")

--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------