-- UNITDEF -- zairbomber --
--------------------------------------------------------------------------------

unitName = "zairbomber"

--------------------------------------------------------------------------------

isUpgraded = [[0]]

humanName = [[Scourge]]

objectName = "zaal/zairbomber.s3o"
script = "zaal/zairbomber.cob"


tech = [[tech2]]
armortype = [[air]]
supply = [[2]]

VFS.Include("units-configs-basedefs/basedefs/zaal/zairbomber_basedef.lua")

unitDef.weaponDefs = weaponDefs

--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
