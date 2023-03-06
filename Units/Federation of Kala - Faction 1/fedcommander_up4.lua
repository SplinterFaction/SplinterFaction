--------------------------------------------------------------------------------

unitName = [[fedcommander_up4]]

--------------------------------------------------------------------------------

humanname = [[Federation of Kala BattleMech Command Unit - Tech 4]]
buildpicture = [[ecommander.png]]
buildcostmetal = 9000
hp = 50000
builddistance = 550

techprovided = [[tech0, tech1, tech2, tech3, tech4, -overseer]]
techrequired = [[0 overseer]]
techlevel = [[tech4]]

maxvelocity = 2
workertime = 1 -- Baseline because this gets multiplied in the tech based factory buildspeed gadget

movementclass = [[WALKERTANK7]]

objectname = [[fedcommander_up4.s3o]]
script = [[ecommander4-battle.cob]]

footprintx = 7
footprintz = 7

buildlist = Shared.buildListFedUniversalBuilderCommander

weapon1 = [[particlebeamcannon_up4]]
areamexdef = [[fedmetalextractor]]

explodeas = [[commnuke_up4]]
selfdestructas = [[commnuke_up4]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/fedcommander_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------