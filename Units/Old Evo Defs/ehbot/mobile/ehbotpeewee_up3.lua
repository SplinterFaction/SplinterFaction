-- UNITDEF -- ehbotpeewee_up3 --
--------------------------------------------------------------------------------

unitName = "ehbotpeewee_up3"

--------------------------------------------------------------------------------

isUpgraded = [[3]]

humanName = [[A.K. MK IV]]

objectName = "ehbotpeewee2.s3o"
script = "ehbotpeewee_lus.lua"

tech = [[tech1]]
armortype = [[light]]
supply = [[6]]

VFS.Include("units-configs-basedefs/basedefs/hbot/mobile/ehbotpeewee_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------