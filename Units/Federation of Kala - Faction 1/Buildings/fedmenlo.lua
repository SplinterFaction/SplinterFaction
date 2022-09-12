--------------------------------------------------------------------------------

unitName = [[fedmenlo]]

--------------------------------------------------------------------------------

humanName = [[Menlo]]

objectName = [[fedmenlo.s3o]]
script = [[fedmenlo_lus.lua]]

tech = [[tech1]]

VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/buildings/fedmenlo_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------