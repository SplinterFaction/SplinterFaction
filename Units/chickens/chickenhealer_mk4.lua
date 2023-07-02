-- UNITDEF -- fedengineer --
--------------------------------------------------------------------------------

unitName = "chickenhealer_mk4"

--------------------------------------------------------------------------------

buildCostMetal = 640
buildDistance = 250

buildpic = [[fedengineer.png]]

maxDamage = 2000 --This is set automatically

fedbuildlists = Shared.buildListFedt0

workertime = 64 -- Baseline because this gets multiplied in the tech based factory buildspeed gadget

humanName = [[ORB - Tech 4]]

footprintx = 2
footprintz = 2
movementclass = "WALKERTANK2"

objectName = [[chickenhealer_mk4.s3o]]
script = [[chickenhealer.cob]]

areamexdef = [[fedmetalextractor]]
requiretech = [[tech0]]

explodeAs = [[smallexplosiongenericgreen]]

VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/fedengineer_basedef.lua")

--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
