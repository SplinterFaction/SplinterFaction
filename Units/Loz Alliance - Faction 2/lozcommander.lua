--------------------------------------------------------------------------------

unitName = [[lozcommander]]

--------------------------------------------------------------------------------

humanname = [[Loz Alliance Command Unit - Tech 0]]
buildpicture = [[lozcommander.png]]

techprovided = [[tech0, -overseer]]
techrequired = [[0 overseer]]

buildCostMetal = 3500
hp = 500
builddistance = 550
maxvelocity = 2
workertime = 1

shieldradius = 50

movementclass = [[WHEELEDTANK3]]

objectname = [[lozcommander.s3o]]
script = [[lozcommander_lus.lua]]

footprintx = 3
footprintz = 3

weapon1 = [[commrailgun]]
weapon2 = [[commshield]]

explodeas = [[commnuke]]
selfdestructas = [[commnuke]]

buildlist = Shared.buildListLozt0
areamexdef = [[metalextractor]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/lozcommander_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------