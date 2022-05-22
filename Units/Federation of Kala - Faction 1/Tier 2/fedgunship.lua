-- UNITDEF -- FEDGUNSHIP --
--------------------------------------------------------------------------------

unitName = "FEDGUNSHIP"

--------------------------------------------------------------------------------

isUpgraded = [[0]]

humanName = [[Scimitar]]

objectName = "fedgunship.s3o"
script = "fedgunship.cob"


tech = [[tech2]]
armortype = [[air]]
supply = [[2]]

VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/tier 2/fedgunship_basedef.lua")

unitDef.weaponDefs = weaponDefs

--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
