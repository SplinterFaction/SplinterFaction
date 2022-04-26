-- UNITDEF -- lozengineer_up1 --
--------------------------------------------------------------------------------

unitName = "lozengineer_up1"

--------------------------------------------------------------------------------

buildCostMetal = 80
buildDistance = 350

buildpic = [[lozengineer_up1.png]]

maxDamage = 1000

lozt1buildlist = Shared.buildListLozt2

workertime = 2

humanName = [[Architect MkII]]

footprintx = 3
footprintz = 3
movementclass = "HOVERTANK3"

objectName = [[f2engineer_up1.s3o]]
script = [[f2engineer_up1_lus.lua]]

areamexdef = [[emetalextractor_up1]]
armortype = [[light]]
requiretech = [[tech1]]

VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/f2engineer_basedef.lua")

--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
