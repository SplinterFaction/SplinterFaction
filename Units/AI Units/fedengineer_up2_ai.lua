-- UNITDEF -- fedengineer_up2 --
--------------------------------------------------------------------------------

unitName = "fedengineer_up2_ai"

--------------------------------------------------------------------------------

buildCostMetal = 160
buildDistance = 450

buildpic = [[fedengineer_up2.png]]
fedbuildlists = Shared.buildListFedt2_ai

maxDamage = 500 --This is set automatically

fedbuildlists = Shared.buildListFedt2_ai

workertime = 1 -- Baseline because this gets multiplied in the tech based factory buildspeed gadget

humanName = [[Lifter - Tech 2]]

footprintx = 3
footprintz = 3
movementclass = "WALKERTANK3"

objectName = [[fedengineer_up2.s3o]]
script = [[fedengineer_up2_lus.lua]]

areamexdef = [[metalextractor_up2]]
requiretech = [[tech2]]

explodeAs = [[largeexplosiongenericgreen]]

VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/fedengineer_basedef.lua")

--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
