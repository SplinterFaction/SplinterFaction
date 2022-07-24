--------------------------------------------------------------------------------

unitName = [[lozcommander_up3]]

--------------------------------------------------------------------------------

humanname = [[Loz Alliance Command Unit]]
buildpicture = [[lozcommander.png]]

armortype = [[armored]]
supplygiven = [[0]]
techprovided = [[tech0, tech1, tech2, tech3, -overseer]]
techrequired = [[0 overseer]]

maxdamage = 15000
maxvelocity = 3
workertime = 4

movementclass = [[WHEELEDTANK6]]

objectname = [[lozcommander_up3.s3o]]
script = [[lozcommander_lus.lua]]

footprintx = 6
footprintz = 6

buildlist = Shared.buildListLozt4

weapon1 = [[machinegun_up3]]

VFS.Include("units-configs-basedefs/basedefs/commander_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------