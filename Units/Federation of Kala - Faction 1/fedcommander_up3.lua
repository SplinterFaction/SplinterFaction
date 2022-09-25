--------------------------------------------------------------------------------

unitName = [[fedcommander_up3]]

--------------------------------------------------------------------------------

humanname = [[Federation of Kala Command Unit - Tech 3]]
buildpicture = [[ecommander.png]]
buildcostmetal = 9000

techprovided = [[tech0, tech1, tech2, tech3, -overseer]]
techrequired = [[0 overseer]]

maxvelocity = 2.3
workertime = 4

movementclass = [[WALKERTANK6]]

objectname = [[fedcommander_up3.s3o]]
script = [[ecommander4-battle.cob]]

footprintx = 6
footprintz = 6

buildlist = Shared.buildListFedt3
areamexdef = [[metalextractor_up3]]

weapon1 = [[particlebeamcannon_up3]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/fedcommander_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------