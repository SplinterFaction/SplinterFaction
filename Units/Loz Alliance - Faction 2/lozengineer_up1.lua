-- UNITDEF -- lozengineer_up1 --
--------------------------------------------------------------------------------

unitName = "lozengineer_up1"

--------------------------------------------------------------------------------

buildCostMetal = 300
buildDistance = 350

buildpic = [[lozengineer_up1.png]]

maxDamage = 1000

lozt1buildlist = Shared.buildListLozUniversalBuilder

workertime = 1 -- Baseline because this gets multiplied in the tech based factory buildspeed gadget

humanName = [[Architect]]

footprintx = 3
footprintz = 3
movementclass = "WHEELEDTANK3"

objectName = [[lozengineer_up1.s3o]]
script = [[lozengineer_up1_lus.lua]]

areamexdef = [[lozmetalextractor]]
requiretech = [[tech0]]

explodeAs = [[mediumexplosiongenericgreen]]

VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/lozengineer_basedef.lua")

--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
