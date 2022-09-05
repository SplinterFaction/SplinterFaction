-- UNITDEF -- fedengineer --
--------------------------------------------------------------------------------

unitName = "fedengineer"

--------------------------------------------------------------------------------

buildCostMetal = 40
buildDistance = 350

buildpic = [[fedengineer.png]]

maxDamage = 500 --This is set automatically

fedbuildlists = Shared.buildListFedt0

workertime = 1

humanName = [[Lifter]]

footprintx = 2
footprintz = 2
movementclass = "WALKERTANK2"

objectName = [[fedengineer.s3o]]
script = [[fedengineer_lus.lua]]

areamexdef = [[emetalextractor]]
armortype = [[light]]
requiretech = [[tech0]]

VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/fedengineer_basedef.lua")

--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
