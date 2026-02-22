-- UNITDEF -- lozairengineer --
--------------------------------------------------------------------------------

unitName = "lozairengineer"

--------------------------------------------------------------------------------

buildDistance = 200

buildpic = [[lozairengineer.dds]]

maxDamage = 1000

lozt1buildlist = Shared.buildListLozUniversalBuilder

workertime = 1 -- Baseline because this gets multiplied in the tech based factory buildspeed gadget

humanName = [[Fabricator]]

footprintx = 3
footprintz = 3

objectName = [[lozairengineer.s3o]]
script = [[lozairengineer_lus.lua]]

areamexdef = [[lozmetalextractor]]
requiretech = [[tech1]]

explodeAs = [[mediumexplosiongenericgreen]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/lozairengineer_basedef.lua")

--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
