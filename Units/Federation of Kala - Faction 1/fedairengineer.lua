-- UNITDEF -- fedairengineer --
--------------------------------------------------------------------------------

unitName = "fedairengineer"

--------------------------------------------------------------------------------

buildDistance = 200

buildpic = [[fedairengineer.dds]]

maxDamage = 1000

fedt1buildlist = Shared.buildListFedUniversalBuilder

workertime = 1 -- Baseline because this gets multiplied in the tech based factory buildspeed gadget

humanName = [[Originator]]

footprintx = 3
footprintz = 3

objectName = [[fedairengineer.s3o]]
script = [[fedairengineer_lus.lua]]

areamexdef = [[fedmetalextractor]]
requiretech = [[tech1]]

explodeAs = [[mediumexplosiongenericgreen]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/fedairengineer_basedef.lua")

--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
