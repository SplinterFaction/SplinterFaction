--------------------------------------------------------------------------------

unitName = [[metalextractor_up1]]

--------------------------------------------------------------------------------

metalMultiplier = 4

buildCostMetal = 150
energyUse = 25

primaryCEG = "custom:fusionreactionnuclear-2color"

humanName = [[Metal Extractor - Tech 1]]

objectName = [[metalextractor_up1.s3o]]
script = [[metalextractor_up1_lus.lua]]

tech = [[tech1]]

skyhateceg = [[custom:skyhatelasert1]]

VFS.Include("units-configs-basedefs/basedefs/Fed and Loz Shared Buildings/metalextractor_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------