-- UNITDEF -- ELIGHTTANK3_up2 --
--------------------------------------------------------------------------------

unitName = "elighttank3_up2"

--------------------------------------------------------------------------------

isUpgraded	= [[2]]

humanName = [[Kite Mark III]]

objectName = "elighttank4.s3o"
script = "elighttank3_lus.lua"

tech						 = [[tech0]]
armortype					 = [[light]]
supply					 = [[3]]

VFS.Include("units-configs-basedefs/basedefs/hover/elighttank3_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
