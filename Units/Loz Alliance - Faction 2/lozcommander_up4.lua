--------------------------------------------------------------------------------

unitName = [[lozcommander_up4]]

--------------------------------------------------------------------------------

humanname = [[Loz Alliance BattleMech Command Unit - Tech 4]]
buildpicture = [[lozcommander.png]]

techprovided = [[tech0, tech1, tech2, tech3, tech4, -overseer]]
techrequired = [[0 overseer]]

buildCostMetal = 20000
hp = 8000
builddistance = 550
maxvelocity = 2
workertime = 1 -- Baseline because this gets multiplied in the tech based factory buildspeed gadget

shieldradius = 115

movementclass = [[WHEELEDTANK7]]

objectname = [[lozcommander_up4.s3o]]
script = [[lozcommander_lus.lua]]

footprintx = 7
footprintz = 7

weapon1 = [[commrailgun_up4]]
weapon2 = [[commshield_up4]]

explodeas = [[commnuke_up4]]
selfdestructas = [[commnuke_up4]]

buildlist = Shared.buildListLozUniversalBuilderCommander
areamexdef = [[lozmetalextractor]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/lozcommander_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------