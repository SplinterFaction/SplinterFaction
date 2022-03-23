-- UNITDEF -- lozengineer --
--------------------------------------------------------------------------------

unitName = "lozengineer"

--------------------------------------------------------------------------------

buildCostMetal = 40
buildDistance = 350

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
providetech = [[tech0]]
requiretech = [[tech0]]

VFS.Include("units-configs-basedefs/basedefs/Faction 2/f2engineer_basedef.lua")

--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
