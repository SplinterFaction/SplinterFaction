--------------------------------------------------------------------------------

unitName = [[lozcommander_up2]]

--------------------------------------------------------------------------------

humanname = [[Loz Alliance Command Unit]]
buildpicture = [[lozcommander.png]]

armortype = [[armored]]
supplygiven = [[0]]
techprovided = [[tech0, tech1, tech2, -overseer]]
techrequired = [[0 overseer]]

maxdamage = 10000
maxvelocity = 3
workertime = 3

movementclass = [[WHEELEDTANK5]]

objectname = [[lozcommander_up2.s3o]]
script = [[lozcommander_lus.lua]]

footprintx = 5
footprintz = 5

buildlist = Shared.buildListLozt3

weapon1 = [[machinegun_up2]]

VFS.Include("units-configs-basedefs/basedefs/commander_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------