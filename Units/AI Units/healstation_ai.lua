--------------------------------------------------------------------------------

unitName = [[healstation_ai]]

--------------------------------------------------------------------------------

humanName = [[Healstation_ai]]

objectName = [[healstation.s3o]]
script = [[healstation.cob]]

buildCostMetal = 10000

workerTime = 1
buildDistance = 350

tech = [[tech0]]

VFS.Include("units-configs-basedefs/basedefs/Fed and Loz Shared Buildings/healstation_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------