--------------------------------------------------------------------------------

unitName = [[fedcommander_up3_ai]]

--------------------------------------------------------------------------------

humanname = [[Federation of Kala Command Unit - Tech 3 - SimpleAI]]
buildpicture = [[ecommander.png]]
buildcostmetal = 2000
builddistance = 550

techprovided = [[tech0, tech1, tech2, tech3, -overseer, -aioverseerup2, aioverseerup3]]
techrequired = [[aioverseerup2]]

maxvelocity = 2
workertime = 1 -- Baseline because this gets multiplied in the tech based factory buildspeed gadget

movementclass = [[WALKERTANK6]]

objectname = [[fedcommander_up3.s3o]]
script = [[ecommander4-battle.cob]]

footprintx = 6
footprintz = 6

buildlist = Shared.buildListFedt3_ai
areamexdef = [[metalextractor_up3]]

weapon1 = [[particlebeamcannon_up3]]

explodeas = [[commnuke_up3]]
selfdestructas = [[commnuke_up3]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/fedcommander_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------