-- UNITDEF -- EARTYTURRETVULCAN --
--------------------------------------------------------------------------------

unitName = [[eartyturretvulcan]]	
	
isUpgraded = [[0]]

humanName = [[Vulcan]]
objectName = [[eartyturretvulcan.s3o]]
script = [[eartyturretvulcan.cob]]

tech = [[tech3]]
armortype = [[building]]

AreaOfEffect = 250

weapon1 = [[artyweaponvulcan]]
accuracy = 1500

VFS.Include("units-configs-basedefs/basedefs/buildings/eartyturretvulcan_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------