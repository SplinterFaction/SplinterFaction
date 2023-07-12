--------------------------------------------------------------------------------

unitName = [[healstation]]

--------------------------------------------------------------------------------

humanName = [[Healstation]]

objectName = [[healstation.s3o]]
script = [[healstation_lus.lua]]

buildCostMetal = 250

workerTime = 1
buildDistance = 350

tech = [[tech2]]

VFS.Include("units-configs-basedefs/basedefs/Fed and Loz Shared Buildings/healstation_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------