--------------------------------------------------------------------------------

unitName = [[fedcommander_up4]]

--------------------------------------------------------------------------------

humanname = [[Federation of Kala BattleMech Command Unit]]
buildpicture = [[ecommander.png]]
buildcostmetal = 48000

techprovided = [[tech0, tech1, tech2, tech3, tech4, -overseer]]
techrequired = [[0 overseer]]

maxvelocity = 3
workertime = 5

movementclass = [[WALKERTANK7]]

objectname = [[fedcommander_up4.s3o]]
script = [[ecommander4-battle.cob]]

footprintx = 7
footprintz = 7

buildlist = Shared.buildListFedt4

weapon1 = [[heavybeamweapon]]
areamexdef = [[metalextractor_up3]]

VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/fedcommander_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------