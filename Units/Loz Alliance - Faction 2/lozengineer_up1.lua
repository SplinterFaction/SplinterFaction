-- UNITDEF -- lozengineer_up1 --
--------------------------------------------------------------------------------

unitName = "lozengineer_up1"

--------------------------------------------------------------------------------

buildCostMetal = 80
buildDistance = 350

buildpic = [[lozengineer_up1.png]]

maxDamage = 1000

lozt1buildlist = Shared.buildListLozt1

workertime = 2

humanName = [[Architect - Tech 1]]

footprintx = 3
footprintz = 3
movementclass = "WHEELEDTANK3"

objectName = [[lozengineer_up1.s3o]]
script = [[lozengineer_up1_lus.lua]]

areamexdef = [[metalextractor_up1]]
requiretech = [[tech1]]

explodeAs = [[mediumexplosiongenericgreen]]

VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/lozengineer_basedef.lua")

--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
