--------------------------------------------------------------------------------

unitName = [[fedcommander_ai]]

--------------------------------------------------------------------------------

humanname = [[Federation of Kala Command Unit - Tech 0 - SimpleAI]]
buildpicture = [[fedcommander.png]]
buildcostmetal = 250
builddistance = 550

techprovided = [[tech0, -overseer]]
techrequired = [[tech0]]

maxvelocity = 2
workertime = 1

movementclass = [[WALKERTANK3]]

objectname = [[fedcommander.s3o]]
script = [[ecommander4-battle.cob]]

footprintx = 3
footprintz = 3

buildlist = Shared.buildListFedt0_ai
areamexdef = [[metalextractor]]

weapon1 = [[particlebeamcannon]]

explodeas = [[commnuke]]
selfdestructas = [[commnuke]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/fedcommander_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------