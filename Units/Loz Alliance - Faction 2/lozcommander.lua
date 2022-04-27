-- UNITDEF -- lozcommander --
--------------------------------------------------------------------------------

unitName = [[lozcommander]]

--------------------------------------------------------------------------------

humanname = [[Loz Alliance Command Unit]]
buildpicture = [[lozcommander.png]]

armortype = [[light]]
supplygiven = [[0]]
techprovided = [[tech0, -overseer]]
techrequired = [[0 overseer]]

maxdamage = 2000
maxvelocity = 3
workertime = 1

movementclass = [[COMMANDERTANK4]]

objectname = [[lozcommandtank.s3o]]
script = [[lozcommandtank.cob]]

footprintx = 4
footprintz = 4

buildlist = Shared.buildListLozt1

weapon1 = [[machinegun]]

VFS.Include("units-configs-basedefs/basedefs/commander_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------