-- UNITDEF -- fedengineer_up2 --
--------------------------------------------------------------------------------

unitName = "fedengineer_up2"

--------------------------------------------------------------------------------

buildCostMetal = 160
buildDistance = 350

buildpic = [[fedengineer_up2.png]]

maxDamage = 500 --This is set automatically

fedbuildlists = Shared.buildListFedt3

workertime = 4

humanName = [[Lifter MkIII]]

footprintx = 3
footprintz = 3
movementclass = "HOVERHBOT3"

objectName = [[fedengineer_up2.s3o]]
script = [[fedengineer_up2_lus.lua]]

areamexdef = [[emetalextractor_up2]]
armortype = [[armored]]
requiretech = [[tech2]]

VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/fedengineer_basedef.lua")

--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
