-- UNITDEF -- fedengineer_up1 --
--------------------------------------------------------------------------------

unitName = "fedengineer_up1"

--------------------------------------------------------------------------------

buildCostMetal = 80
buildDistance = 350

buildpic = [[fedengineer_up1.png]]

maxDamage = 500 --This is set automatically

fedbuildlists = Shared.buildListFedt1

workertime = 2

humanName = [[Lifter - Tech 1]]

footprintx = 2
footprintz = 2
movementclass = "WALKERTANK2"

objectName = [[fedengineer_up1.s3o]]
script = [[fedengineer_up1_lus.lua]]

areamexdef = [[metalextractor_up1]]
requiretech = [[tech1]]

explodeAs = [[mediumexplosiongenericgreen]]

VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/fedengineer_basedef.lua")

--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
