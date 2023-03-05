--------------------------------------------------------------------------------

unitName = [[fedcommander_up1]]

--------------------------------------------------------------------------------

humanname = [[Federation of Kala Command Unit - Tech 1]]
buildpicture = [[fedcommander.png]]
buildcostmetal = 1400
hp = 15000
builddistance = 550

techprovided = [[tech0, tech1, -overseer]]
techrequired = [[0 overseer]]
techlevel = [[tech1]]

maxvelocity = 2
workertime = 1 -- Baseline because this gets multiplied in the tech based factory buildspeed gadget

movementclass = [[WALKERTANK4]]

objectname = [[fedcommander_up1.s3o]]
script = [[ecommander4-battle.cob]]

footprintx = 4
footprintz = 4

buildlist = Shared.buildListFedUniversalBuilderCommander
areamexdef = [[fedmetalextractor]]

weapon1 = [[particlebeamcannon_up1]]

explodeas = [[commnuke_up1]]
selfdestructas = [[commnuke_up1]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/fedcommander_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------