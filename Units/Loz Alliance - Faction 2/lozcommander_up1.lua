--------------------------------------------------------------------------------

unitName = [[lozcommander_up1]]

--------------------------------------------------------------------------------

humanname = [[Loz Alliance Command Unit - Tech 1]]
buildpicture = [[lozcommander.png]]

techprovided = [[tech0, tech1, -overseer]]
techrequired = [[0 overseer]]

buildCostMetal = 6000
hp = 1000
builddistance = 550
maxvelocity = 2
workertime = 2

shieldradius = 60

movementclass = [[WHEELEDTANK4]]

objectname = [[lozcommander_up1.s3o]]
script = [[lozcommander_lus.lua]]

footprintx = 4
footprintz = 4

weapon1 = [[commrailgun_up1]]
weapon2 = [[commshield_up1]]

explodeas = [[commnuke_up1]]
selfdestructas = [[commnuke_up1]]

buildlist = Shared.buildListLozt1
areamexdef = [[metalextractor_up1]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/lozcommander_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------