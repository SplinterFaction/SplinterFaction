--------------------------------------------------------------------------------

unitName = [[lozcommander]]

--------------------------------------------------------------------------------

humanname = [[Loz Alliance Command Unit - Tech 0]]
buildpicture = [[lozcommander.png]]

techprovided = [[tech0, -overseer]]
techrequired = [[0 overseer]]

buildCostMetal = 3000
maxvelocity = 2.4
workertime = 1

movementclass = [[WHEELEDTANK3]]

objectname = [[lozcommander.s3o]]
script = [[lozcommander_lus.lua]]

footprintx = 3
footprintz = 3

buildlist = Shared.buildListLozt0
areamexdef = [[metalextractor]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/lozcommander_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------