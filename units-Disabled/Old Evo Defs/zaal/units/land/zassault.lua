-- UNITDEF -- zassault --
--------------------------------------------------------------------------------

unitName = "zassault"

--------------------------------------------------------------------------------

isUpgraded	= [[0]]

humanName = "Ultralisk"

objectName = "zaal/zassault.s3o"
script = "zaal/zassault.cob"

tech = [[tech3]]
armortype = [[armored]]
supply = [[7]]

VFS.Include("units-configs-basedefs/basedefs/zaal/zassault_basedef.lua")
	
unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
