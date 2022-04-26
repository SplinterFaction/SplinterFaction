-- UNITDEF -- lozengineer --
--------------------------------------------------------------------------------

unitName = "lozengineer"

--------------------------------------------------------------------------------

buildCostMetal = 40
buildDistance = 350

buildpic = [[lozengineer.png]]

maxDamage = 500

lozt1buildlist = Shared.buildListLozt1

workertime = 1

humanName = [[Architect]]

footprintx = 2
footprintz = 2
movementclass = "HOVERTANK2"

objectName = [[f2engineer.s3o]]
script = [[f2engineer_lus.lua]]

areamexdef = [[emetalextractor]]
armortype = [[light]]
requiretech = [[tech0]]

VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/f2engineer_basedef.lua")

--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
