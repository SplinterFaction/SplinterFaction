-- UNITDEF -- ELIGHTTANK3_up1 --
--------------------------------------------------------------------------------

unitName = "elighttank3_up1"

--------------------------------------------------------------------------------

isUpgraded	= [[1]]

humanName = [[Kite Mark II]]

objectName = "elighttank4.s3o"
script = "elighttank3_lus.lua"

tech = [[tech0]]
armortype = [[light]]
supply = [[3]]

VFS.Include("units-configs-basedefs/basedefs/hover/elighttank3_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
