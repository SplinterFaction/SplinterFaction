--------------------------------------------------------------------------------

unitName = [[beacon]]

--------------------------------------------------------------------------------

humanName = [[Spawn Beacon]]

engineUnitName = [[beacon]]

objectName = [[beacon.s3o]]
script = [[beacon.cob]]

VFS.Include("units-configs-basedefs/basedefs/survivalai/beacon_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
