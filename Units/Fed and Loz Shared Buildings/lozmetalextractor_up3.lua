--------------------------------------------------------------------------------

unitName = [[lozmetalextractor_up3]]

--------------------------------------------------------------------------------

metalMultiplier = 24

buildCostMetal = 1200
energyUse = 100

primaryCEG = "custom:fusionreactionnuclear-4color"

humanName = [[Metal Extractor - Tech 3]]

iconType = [[structuremetalgeneratort3]]

explodeAsSelfSAs = [[largeBuildingExplosionGenericGreen]]

objectName = [[metalextractort3.s3o]]
script = [[metalextractor_up3_lus.lua]]

tech = [[tech3]]

noenergycost = false

skyhateceg = [[custom:skyhatelasert3]]

faction = [[Loz Alliance]]

VFS.Include("units-configs-basedefs/basedefs/Fed and Loz Shared Buildings/metalextractor_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------