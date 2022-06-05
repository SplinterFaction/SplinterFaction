-- UNITDEF -- fedengineer_up3 --
--------------------------------------------------------------------------------

unitName = "fedengineer_up3"

--------------------------------------------------------------------------------

buildCostMetal = 320
buildDistance = 350

buildpic = [[fedengineer_up3.png]]

maxDamage = 500 --This is set automatically

fedbuildlists = Shared.buildListFedt4

workertime = 4

humanName = [[Lifter Mk IV]]

footprintx = 4
footprintz = 4
movementclass = "WALKERTANK4"

objectName = [[fedengineer_up3.s3o]]
script = [[fedengineer_up3_lus.lua]]

areamexdef = [[emetalextractor_up3]]
armortype = [[armored]]
requiretech = [[tech3]]

VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/fedengineer_basedef.lua")

--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
