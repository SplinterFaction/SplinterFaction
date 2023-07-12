--------------------------------------------------------------------------------

unitName = [[chickensbeacon]]

--------------------------------------------------------------------------------

humanName = [[Beacon]]

objectName = [[chickensbeacon.s3o]]
script = [[chickensbeacon_lus.lua]]

buildCostMetal = 1

workerTime = 1
buildDistance = 1
hp = 250000

VFS.Include("units-configs-basedefs/basedefs/chickens/chickensbeacon_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------