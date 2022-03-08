--------------------------------------------------------------------------------

unitName = [[healstation]]

--------------------------------------------------------------------------------

humanName = [[Healstation]]

objectName = [[healstation.s3o]]
script = [[healstation.cob]]

workerTime = 1
buildDistance = 350

tech = [[tech2]]
armortype = [[light]]

VFS.Include("units-configs-basedefs/basedefs/buildings/healstation_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------