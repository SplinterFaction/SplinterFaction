-- UNITDEF -- ehbotthud_turret --
--------------------------------------------------------------------------------

unitName = [[ehbotthud_turret_up1]]

--------------------------------------------------------------------------------

isUpgraded = [[1]]

humanName = [[Thud Mk II (Deployed)]]

objectName = [[ehbotthud_turret.s3o]]
script = [[ehbotthud_turret_lus.lua]]

tech = [[tech1]]
armortype = [[light]]
supply = [[7]]

VFS.Include("Units-Configs-Basedefs/basedefs/hbot/turret/ehbotthud_turret_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------