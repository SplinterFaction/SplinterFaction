--------------------------------------------------------------------------------

unitName = [[lozcommander_up3]]

--------------------------------------------------------------------------------

humanname = [[Loz Alliance Command Unit - Tech 3]]
buildpicture = [[lozcommander.png]]

techprovided = [[tech0, tech1, tech2, tech3, -overseer]]
techrequired = [[0 overseer]]
techlevel = [[tech3]]

buildCostMetal = 1800
buildCostEnergy = 46800
hp = 32500

builddistance = 550
maxvelocity = 2
workertime = 1 -- Baseline because this gets multiplied in the tech based factory buildspeed gadget

shieldradius = 105

movementclass = [[WHEELEDTANK6]]

objectname = [[lozcommander_up3.s3o]]
script = [[lozcommander_lus.lua]]

footprintx = 6
footprintz = 6

weapon1 = [[commrailgun_up3]]

explodeas = [[commnuke_up3]]
selfdestructas = [[commnuke_up3]]

buildlist = Shared.buildListLozUniversalBuilderCommander
areamexdef = [[lozmetalextractor]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/lozcommander_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------