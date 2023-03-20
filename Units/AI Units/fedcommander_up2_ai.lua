--------------------------------------------------------------------------------

unitName = [[fedcommander_up2_ai]]

--------------------------------------------------------------------------------

humanname = [[Federation of Kala Command Unit - Tech 2 - SimpleAI]]
buildpicture = [[ecommander.png]]
buildcostmetal = 0
buildCostEnergy = 30000
hp = 25000
builddistance = 550

techprovided = [[tech0, tech1, tech2, -overseer, -aioverseerup1, aioverseerup2]]
techrequired = [[aioverseerup1]]

maxvelocity = 2
workertime = 1 -- Baseline because this gets multiplied in the tech based factory buildspeed gadget

movementclass = [[WALKERTANK5]]

objectname = [[fedcommander_up2.s3o]]
script = [[ecommander4-battle.cob]]

footprintx = 5
footprintz = 5

buildlist = Shared.buildListFedUniversalBuilderCommander_ai
areamexdef = [[fedmetalextractor_up2]]

weapon1 = [[particlebeamcannon_up2]]

explodeas = [[commnuke_up2]]
selfdestructas = [[commnuke_up2]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/fedcommander_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------