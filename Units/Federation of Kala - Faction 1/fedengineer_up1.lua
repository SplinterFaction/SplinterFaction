-- UNITDEF -- fedengineer_up1 --
--------------------------------------------------------------------------------

unitName = "fedengineer_up1"

--------------------------------------------------------------------------------

buildCostMetal = 220
buildDistance = 350

buildpic = [[fedengineer_up1.png]]

maxDamage = 500 --This is set automatically

fedbuildlists = Shared.buildListFedUniversalBuilder

workertime = 1 -- Baseline because this gets multiplied in the tech based factory buildspeed gadget

humanName = [[Lifter]]

footprintx = 2
footprintz = 2
movementclass = "WALKERTANK2"

objectName = [[fedengineer_up1.s3o]]
script = [[fedengineer_up1_lus.lua]]

areamexdef = [[fedmetalextractor]]
requiretech = [[tech0]]

explodeAs = [[mediumexplosiongenericgreen]]

VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/fedengineer_basedef.lua")

--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
