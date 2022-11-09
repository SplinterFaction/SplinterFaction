-- UNITDEF -- EAMPHIBRIOT_up1--
--------------------------------------------------------------------------------

unitName = "eamphibriot_up1"

--------------------------------------------------------------------------------

isUpgraded = [[1]]

humanName = [[Dicer Mark II]]

objectName = "eamphibriot2.s3o"
script = "eamphibriot.cob"

tech = [[tech0]]
armortype = [[light]]
supply = [[3]]

VFS.Include("units-configs-basedefs/basedefs/amphib/eamphibriot_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
