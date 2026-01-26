--------------------------------------------------------------------------------

unitName = [[fedcommander_up2]]

--------------------------------------------------------------------------------

humanname = [[Federation of Kala Command Unit - Tech 2]]
buildpicture = [[ecommander.png]]
buildcostmetal = 825
buildCostEnergy = 20000
hp = 25000

builddistance = 550
techprovided = [[tech0, tech1, tech2, -overseer]]
techrequired = [[0 overseer]]
techlevel = [[tech2]]

maxvelocity = 2
workertime = 1 -- Baseline because this gets multiplied in the tech based factory buildspeed gadget

movementclass = [[WALKERTANK5]]

objectname = [[fedcommander2_up2.s3o]]
script = [[fed/hbot/fedcommander2_up2_lus.lua]]

footprintx = 5
footprintz = 5

buildlist = Shared.buildListFedUniversalBuilderCommander
areamexdef = [[fedmetalextractor]]

weapon1 = [[particlebeamcannon_up2]]

explodeas = [[commnuke_up2]]
selfdestructas = [[commnuke_up2]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/fedcommander_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------