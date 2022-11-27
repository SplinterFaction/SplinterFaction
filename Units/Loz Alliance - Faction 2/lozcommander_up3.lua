--------------------------------------------------------------------------------

unitName = [[lozcommander_up3]]

--------------------------------------------------------------------------------

humanname = [[Loz Alliance Command Unit - Tech 3]]
buildpicture = [[lozcommander.png]]

techprovided = [[tech0, tech1, tech2, tech3, -overseer]]
techrequired = [[0 overseer]]

buildCostMetal = 13000
hp = 4000
builddistance = 550
maxvelocity = 2
workertime = 8

shieldradius = 105

movementclass = [[WHEELEDTANK6]]

objectname = [[lozcommander_up3.s3o]]
script = [[lozcommander_lus.lua]]

footprintx = 6
footprintz = 6

weapon1 = [[commrailgun_up3]]
weapon2 = [[commshield_up3]]

explodeas = [[commnuke_up3]]
selfdestructas = [[commnuke_up3]]

buildlist = Shared.buildListLozt3
areamexdef = [[metalextractor_up3]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/lozcommander_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------