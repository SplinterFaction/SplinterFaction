--------------------------------------------------------------------------------

unitName = [[fedcommander_up4]]

--------------------------------------------------------------------------------

humanname = [[Federation of Kala BattleMech Command Unit - Tech 4]]
buildpicture = [[ecommander.png]]
buildcostmetal = 11000
builddistance = 450

techprovided = [[tech0, tech1, tech2, tech3, tech4, -overseer]]
techrequired = [[0 overseer]]

maxvelocity = 2.3
workertime = 16

movementclass = [[WALKERTANK7]]

objectname = [[fedcommander_up4.s3o]]
script = [[ecommander4-battle.cob]]

footprintx = 7
footprintz = 7

buildlist = Shared.buildListFedt4

weapon1 = [[particlebeamcannon_up4]]
areamexdef = [[metalextractor_up3]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/fedcommander_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------