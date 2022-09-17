--------------------------------------------------------------------------------

unitName = [[fedcommander_up2]]

--------------------------------------------------------------------------------

humanname = [[Federation of Kala Command Unit]]
buildpicture = [[ecommander.png]]
buildcostmetal = 12000

techprovided = [[tech0, tech1, tech2, -overseer]]
techrequired = [[0 overseer]]

maxvelocity = 3
workertime = 4

movementclass = [[WALKERTANK5]]

objectname = [[fedcommander_up2.s3o]]
script = [[ecommander4-battle.cob]]

footprintx = 5
footprintz = 5

buildlist = Shared.buildListFedt2
areamexdef = [[metalextractor_up2]]

weapon1 = [[machinegun_up2]]

VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/fedcommander_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------