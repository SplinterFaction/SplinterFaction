-- UNITDEF -- eradar2 --
--------------------------------------------------------------------------------

unitName = [[eradar2]]
buildpic = [[eradar2.png]]

buildCostMetal = 5

humanName = [[Radar Tower]]
objectName = [[eradar3_small.s3o]]

radarDistance = 1000
radarEmitHeight = 64

sightDistance = 750
sonarDistance = 750
seismicDistance = 750

tech = [[tech0]]
armortype = [[building]]


VFS.Include("units-configs-basedefs/basedefs/buildings/eradar2_basedef.lua")

--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------