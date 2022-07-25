--------------------------------------------------------------------------------

unitName = [[lozcommander_up4]]

--------------------------------------------------------------------------------

humanname = [[Loz Alliance BattleMech Command Unit]]
buildpicture = [[lozcommander.png]]

techprovided = [[tech0, tech1, tech2, tech3, -overseer]]
techrequired = [[0 overseer]]

maxdamage = 20000
maxvelocity = 3
workertime = 5

movementclass = [[WHEELEDTANK7]]

objectname = [[lozcommander_up4.s3o]]
script = [[lozcommander_lus.lua]]

footprintx = 7
footprintz = 7

buildlist = Shared.buildListLozt4

weapon1 = [[heavybeamweapon]]

VFS.Include("units-configs-basedefs/basedefs/commander_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------