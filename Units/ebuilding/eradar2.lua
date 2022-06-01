-- UNITDEF -- eradar2 --
--------------------------------------------------------------------------------

unitName = [[eradar2]]
buildpic = [[eradar2.png]]

buildCostMetal = 25

humanName = [[Radar Tower]]
objectName = [[eradar3_small.s3o]]

radarDistance = 1750
radarEmitHeight = 64

sightDistance = 1750
sonarDistance = 1750
seismicDistance = 1750

tech = [[tech0]]
armortype = [[building]]


VFS.Include("units-configs-basedefs/basedefs/buildings/eradar2_basedef.lua")

--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------