-- UNITDEF -- lozengineer_up2 --
--------------------------------------------------------------------------------

unitName = "lozengineer_up2"

--------------------------------------------------------------------------------

buildCostMetal = 160
buildDistance = 350

buildpic = [[lozengineer_up1.png]]

maxDamage = 1500

lozt1buildlist = Shared.buildListLozt3

workertime = 4

humanName = [[Architect MkIII]]

footprintx = 4
footprintz = 4
movementclass = "HOVERTANK4"

objectName = [[f2engineer_up2.s3o]]
script = [[f2engineer_up2_lus.lua]]

areamexdef = [[emetalextractor_up2]]
armortype = [[light]]
requiretech = [[tech2]]

VFS.Include("units-configs-basedefs/basedefs/Faction 2/f2engineer_basedef.lua")

--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
