-- UNITDEF -- eamphibleveler_up2 --
--------------------------------------------------------------------------------

unitName = "eamphibleveler_up2"

--------------------------------------------------------------------------------

isUpgraded = [[2]]

humanName = [[Leveler Mark III]]

objectName = "eamphibleveler.s3o"
script = "eamphibleveler.cob"

tech = [[tech3]]
armortype = [[armored]]
--supply = [[30]]

VFS.Include("units-configs-basedefs/basedefs/amphib/eamphibleveler_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
