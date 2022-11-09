--------------------------------------------------------------------------------

unitName = [[metalextractor_up3]]

--------------------------------------------------------------------------------

metalMultiplier = 16

buildCostMetal = 1200
energyUse = 100

primaryCEG = "custom:fusionreactionnuclear-4color"

humanName = [[Metal Extractor - Tech 3]]

explodeAsSelfSAs = [[largeBuildingExplosionGenericGreen]]

objectName = [[metalextractor_up3.s3o]]
script = [[metalextractor_up3_lus.lua]]

tech = [[tech3]]

skyhateceg = [[custom:skyhatelasert3]]

VFS.Include("units-configs-basedefs/basedefs/Fed and Loz Shared Buildings/metalextractor_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------