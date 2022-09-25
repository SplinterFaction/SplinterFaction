--------------------------------------------------------------------------------

unitName = [[lozcommander_up1]]

--------------------------------------------------------------------------------

humanname = [[Loz Alliance Command Unit]]
buildpicture = [[lozcommander.png]]

techprovided = [[tech0, tech1, -overseer]]
techrequired = [[0 overseer]]

buildCostMetal = 6200
maxvelocity = 3
workertime = 2.4

movementclass = [[WHEELEDTANK4]]

objectname = [[lozcommander_up1.s3o]]
script = [[lozcommander_lus.lua]]

footprintx = 4
footprintz = 4

buildlist = Shared.buildListLozt1
areamexdef = [[metalextractor_up1]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/lozcommander_up1_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------