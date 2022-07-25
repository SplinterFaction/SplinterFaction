--------------------------------------------------------------------------------

unitName = [[lozcommander_up1]]

--------------------------------------------------------------------------------

humanname = [[Loz Alliance Command Unit]]
buildpicture = [[lozcommander.png]]

techprovided = [[tech0, tech1, -overseer]]
techrequired = [[0 overseer]]

maxdamage = 5000
maxvelocity = 3
workertime = 2

movementclass = [[WHEELEDTANK4]]

objectname = [[lozcommander_up1.s3o]]
script = [[lozcommander_lus.lua]]

footprintx = 4
footprintz = 4

buildlist = Shared.buildListLozt2

weapon1 = [[machinegun_up1]]

VFS.Include("units-configs-basedefs/basedefs/commander_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------