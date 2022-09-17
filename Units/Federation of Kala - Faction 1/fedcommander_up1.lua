--------------------------------------------------------------------------------

unitName = [[fedcommander_up1]]

--------------------------------------------------------------------------------

humanname = [[Federation of Kala Command Unit]]
buildpicture = [[fedcommander.png]]
buildcostmetal = 6200

techprovided = [[tech0, tech1, -overseer]]
techrequired = [[0 overseer]]

maxvelocity = 3
workertime = 2

movementclass = [[WALKERTANK4]]

objectname = [[fedcommander_up1.s3o]]
script = [[ecommander4-battle.cob]]

footprintx = 4
footprintz = 4

buildlist = Shared.buildListFedt1
areamexdef = [[metalextractor_up1]]

weapon1 = [[machinegun_up1]]

VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/fedcommander_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------