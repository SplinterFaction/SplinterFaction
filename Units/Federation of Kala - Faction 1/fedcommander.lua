--------------------------------------------------------------------------------

unitName = [[fedcommander]]

--------------------------------------------------------------------------------

humanname = [[Federation of Kala Command Unit]]
buildpicture = [[fedcommander.png]]
buildcostmetal = 3000

techprovided = [[tech0, -overseer]]
techrequired = [[0 overseer]]

maxvelocity = 3
workertime = 1

movementclass = [[WALKERTANK3]]

objectname = [[fedcommander.s3o]]
script = [[ecommander4-battle.cob]]

footprintx = 3
footprintz = 3

buildlist = Shared.buildListFedt0

weapon1 = [[machinegun]]

VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/fedcommander_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------