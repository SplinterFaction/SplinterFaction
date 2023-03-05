--------------------------------------------------------------------------------

unitName = [[lozcommander]]

--------------------------------------------------------------------------------

humanname = [[Loz Alliance Command Unit - Tech 0]]
buildpicture = [[lozcommander.png]]

techprovided = [[tech0, -overseer]]
techrequired = [[0 overseer]]
techlevel = [[tech0]]

buildCostMetal = 500
hp = 500
builddistance = 550
maxvelocity = 2
workertime = 1 -- Baseline because this gets multiplied in the tech based factory buildspeed gadget

shieldradius = 75

movementclass = [[WHEELEDTANK3]]

objectname = [[lozcommander.s3o]]
script = [[lozcommander_lus.lua]]

footprintx = 3
footprintz = 3

weapon1 = [[commrailgun]]
weapon2 = [[commshield]]

explodeas = [[commnuke]]
selfdestructas = [[commnuke]]

buildlist = Shared.buildListLozUniversalBuilderCommander
areamexdef = [[lozmetalextractor]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/lozcommander_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------