-- UNITDEF -- fedengineer_up3 --
--------------------------------------------------------------------------------

unitName = "fedengineer_up3_ai"

--------------------------------------------------------------------------------

buildCostMetal = 320
buildDistance = 450

buildpic = [[fedengineer_up3.png]]
fedbuildlists = Shared.buildListFedt3_ai

maxDamage = 500 --This is set automatically

fedbuildlists = Shared.buildListFedt3_ai

workertime = 8

humanName = [[Lifter - Tech 3]]

footprintx = 4
footprintz = 4
movementclass = "WALKERTANK4"

objectName = [[fedengineer_up3.s3o]]
script = [[fedengineer_up3_lus.lua]]

areamexdef = [[metalextractor_up3]]
requiretech = [[tech3]]

explodeAs = [[hugeexplosiongenericgreen]]

VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/fedengineer_basedef.lua")

--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
