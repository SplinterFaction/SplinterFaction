-- UNITDEF -- lozengineer_up3 --
--------------------------------------------------------------------------------

unitName = "lozengineer_up3"

--------------------------------------------------------------------------------

buildCostMetal = 320
buildDistance = 350

buildpic = [[lozengineer_up1.png]]

maxDamage = 2000

lozt1buildlist = Shared.buildListLozt4

workertime = 8

humanName = [[Architect MkIV]]

footprintx = 6
footprintz = 6
movementclass = "WHEELEDTANK5"

objectName = [[lozengineer_up3.s3o]]
script = [[lozengineer_up3_lus.lua]]

areamexdef = [[emetalextractor_up3]]
requiretech = [[tech3]]

VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/lozengineer_basedef.lua")

--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
