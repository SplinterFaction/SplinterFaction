-- UNITDEF -- ETRANSPORT --
--------------------------------------------------------------------------------

unitName = "etransport"

--------------------------------------------------------------------------------

isUpgraded = [[0]]

humanName = [[Kharter]]

objectName = "etransport2-small.s3o"
script = "etransport2.cob"


--tech = [[tech1]]
armortype = [[armored]]
supply = [[0]]

VFS.Include("units-configs-basedefs/basedefs/air/etransport_basedef.lua")

-- unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
