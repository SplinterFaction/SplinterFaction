--------------------------------------------------------------------------------

unitName = [[lozcommander_up4]]

--------------------------------------------------------------------------------

humanname = [[Loz Alliance BattleMech Command Unit]]
buildpicture = [[lozcommander.png]]

techprovided = [[tech0, tech1, tech2, tech3, tech4, -overseer]]
techrequired = [[0 overseer]]

buildCostMetal = 11000
maxvelocity = 2
workertime = 5

movementclass = [[WHEELEDTANK7]]

objectname = [[lozcommander_up4.s3o]]
script = [[lozcommander_lus.lua]]

footprintx = 7
footprintz = 7

buildlist = Shared.buildListLozt4
areamexdef = [[metalextractor_up3]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/lozcommander_up4_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------