--------------------------------------------------------------------------------

unitName = [[lozcommander_up2]]

--------------------------------------------------------------------------------

humanname = [[Loz Alliance Command Unit - Tech 2]]
buildpicture = [[lozcommander.png]]

techprovided = [[tech0, tech1, tech2, -overseer]]
techrequired = [[0 overseer]]
techlevel = [[tech2]]

buildCostMetal = 0
buildCostEnergy = 30000
hp = 2000
builddistance = 550
maxvelocity = 2
workertime = 1 -- Baseline because this gets multiplied in the tech based factory buildspeed gadget

shieldradius = 95

movementclass = [[WHEELEDTANK5]]

objectname = [[lozcommander_up2.s3o]]
script = [[lozcommander_lus.lua]]

footprintx = 5
footprintz = 5

weapon1 = [[commrailgun_up2]]
weapon2 = [[commshield_up2]]

explodeas = [[commnuke_up2]]
selfdestructas = [[commnuke_up2]]

buildlist = Shared.buildListLozUniversalBuilderCommander
areamexdef = [[lozmetalextractor]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/lozcommander_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------