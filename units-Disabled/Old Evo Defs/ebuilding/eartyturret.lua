-- UNITDEF -- EARTYTURRET --
--------------------------------------------------------------------------------

unitName = [[eartyturret]]	

humanName = [[Big Bertha]]
objectName = [[eartyturret.s3o]]
script = [[eartyturret.cob]]

tech = [[tech3]]
armortype = [[building]]

AreaOfEffect = 250

weapon1 = [[artyweapon]]
accuracy = 500

isUpgraded = [[0]]

VFS.Include("units-configs-basedefs/basedefs/buildings/eartyturret_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------