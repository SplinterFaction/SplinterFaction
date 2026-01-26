--------------------------------------------------------------------------------

unitName = [[fedcommander_up3]]

--------------------------------------------------------------------------------

humanname = [[Federation of Kala Command Unit - Tech 3]]
buildpicture = [[ecommander.png]]
buildcostmetal = 2625
buildCostEnergy = 66800
hp = 32500

builddistance = 550
techprovided = [[tech0, tech1, tech2, tech3, -overseer]]
techrequired = [[0 overseer]]
techlevel = [[tech3]]

maxvelocity = 2
workertime = 1 -- Baseline because this gets multiplied in the tech based factory buildspeed gadget

movementclass = [[WALKERTANK6]]

objectname = [[fedcommander2_up3.s3o]]
script = [[fed/hbot/fedcommander2_up3_lus.lua]]

footprintx = 6
footprintz = 6

buildlist = Shared.buildListFedUniversalBuilderCommander
areamexdef = [[fedmetalextractor]]

weapon1 = [[particlebeamcannon_up3]]

explodeas = [[commnuke_up3]]
selfdestructas = [[commnuke_up3]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/fedcommander_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------