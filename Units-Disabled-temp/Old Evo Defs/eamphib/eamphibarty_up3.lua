-- UNITDEF -- EAMPHIBARTY_up3 --
--------------------------------------------------------------------------------

unitName = "eamphibarty_up3"

--------------------------------------------------------------------------------

isUpgraded = [[3]]

humanName = [[Assimilator Mark IV]]

objectName = "eamphibarty2.s3o"
script = "eamphibarty2.cob"

tech = [[tech0]]
armortype = [[light]]
supply = [[5]]

VFS.Include("units-configs-basedefs/basedefs/amphib/eamphibarty_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
