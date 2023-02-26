--------------------------------------------------------------------------------

unitName = [[fedcommander]]

--------------------------------------------------------------------------------

humanname = [[Federation of Kala Command Unit - Tech 0]]
buildpicture = [[fedcommander.png]]
buildcostmetal = 3500
builddistance = 550

techprovided = [[tech0, -overseer]]
techrequired = [[0 overseer]]

maxvelocity = 2
workertime = 1 -- Baseline because this gets multiplied in the tech based factory buildspeed gadget

movementclass = [[WALKERTANK3]]

objectname = [[fedcommander.s3o]]
script = [[ecommander4-battle.cob]]

footprintx = 3
footprintz = 3

buildlist = Shared.buildListFedUniversalBuilderCommander
areamexdef = [[fedmetalextractor]]

weapon1 = [[particlebeamcannon]]

explodeas = [[commnuke]]
selfdestructas = [[commnuke]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/fedcommander_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------