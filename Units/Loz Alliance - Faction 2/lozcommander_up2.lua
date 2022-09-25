--------------------------------------------------------------------------------

unitName = [[lozcommander_up2]]

--------------------------------------------------------------------------------

humanname = [[Loz Alliance Command Unit]]
buildpicture = [[lozcommander.png]]

techprovided = [[tech0, tech1, tech2, -overseer]]
techrequired = [[0 overseer]]

buildCostMetal = 7500
maxvelocity = 2.3
workertime = 3

movementclass = [[WHEELEDTANK5]]

objectname = [[lozcommander_up2.s3o]]
script = [[lozcommander_lus.lua]]

footprintx = 5
footprintz = 5

buildlist = Shared.buildListLozt2
areamexdef = [[metalextractor_up2]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/lozcommander_up2_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------