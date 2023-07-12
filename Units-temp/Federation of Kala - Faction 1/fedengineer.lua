-- UNITDEF -- fedengineer --
--------------------------------------------------------------------------------

unitName = "fedengineer"

--------------------------------------------------------------------------------

buildCostMetal = 40
buildDistance = 250

buildpic = [[fedengineer.png]]

maxDamage = 500 --This is set automatically

fedbuildlists = Shared.buildListFedt0

workertime = 1 -- Baseline because this gets multiplied in the tech based factory buildspeed gadget

humanName = [[Lifter - Tech 0]]

footprintx = 2
footprintz = 2
movementclass = "WALKERTANK2"

objectName = [[fedengineer.s3o]]
script = [[fedengineer_lus.lua]]

areamexdef = [[fedmetalextractor]]
requiretech = [[tech0]]

explodeAs = [[smallexplosiongenericgreen]]

VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/fedengineer_basedef.lua")

--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
