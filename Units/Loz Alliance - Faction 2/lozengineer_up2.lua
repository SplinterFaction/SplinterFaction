-- UNITDEF -- lozengineer_up2 --
--------------------------------------------------------------------------------

unitName = "lozengineer_up2"

--------------------------------------------------------------------------------

buildCostMetal = 160
buildDistance = 350

buildpic = [[lozengineer_up1.png]]

maxDamage = 1500

lozt1buildlist = Shared.buildListLozt2

workertime = 4

humanName = [[Architect MkIII]]

footprintx = 4
footprintz = 4
movementclass = "WHEELEDTANK4"

objectName = [[lozengineer_up2.s3o]]
script = [[lozengineer_up2_lus.lua]]

areamexdef = [[emetalextractor_up2]]
requiretech = [[tech2]]

explodeAs = [[largeexplosiongenericgreen]]

VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/lozengineer_basedef.lua")

--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
