--------------------------------------------------------------------------------

unitName = [[geometalmaker]]

--------------------------------------------------------------------------------
buildCostMetal = 4800

primaryCEG = "custom:fusionreactionnuclear-4color"

humanName = [[Geothermal E->M Converter]]
description = [[Converts energy to metal]]

explodeAsSelfSAs = [[hugeBuildingExplosionGenericGreen]]

objectName = [[metalmaker_geo_t4.s3o]]
script = [[metalextractor_geo_lus.lua]]

tech = [[tech4]]

noenergycost = false

-- This is decided by the scaler gadget
metalMake = 0
energyUse = 0

skyhateceg = [[custom:skyhatelasert3]]

faction = [[Neutral]]

VFS.Include("units-configs-basedefs/basedefs/Fed and Loz Shared Buildings/geometalmaker_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------