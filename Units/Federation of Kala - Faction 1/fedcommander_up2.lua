--------------------------------------------------------------------------------

unitName = [[fedcommander_up2]]

--------------------------------------------------------------------------------

humanname = [[Federation of Kala Command Unit - Tech 2]]
buildpicture = [[ecommander.png]]
buildcostmetal = 10000
builddistance = 550

techprovided = [[tech0, tech1, tech2, -overseer]]
techrequired = [[0 overseer]]

maxvelocity = 2
workertime = 4

movementclass = [[WALKERTANK5]]

objectname = [[fedcommander_up2.s3o]]
script = [[ecommander4-battle.cob]]

footprintx = 5
footprintz = 5

buildlist = Shared.buildListFedt2
areamexdef = [[metalextractor_up2]]

weapon1 = [[particlebeamcannon_up2]]

explodeas = [[commnuke_up2]]
selfdestructas = [[commnuke_up2]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/fedcommander_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------