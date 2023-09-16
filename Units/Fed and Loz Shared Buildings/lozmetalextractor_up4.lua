--------------------------------------------------------------------------------

unitName = [[lozmetalextractor_up4]]

--------------------------------------------------------------------------------

metalMultiplier = 32

buildCostMetal = 2400
energyUse = 250

primaryCEG = "custom:fusionreactionnuclear-4color"

humanName = [[Metal Extractor - Tech 4]]

iconType = [[structuremetalgeneratort4]]

explodeAsSelfSAs = [[largeBuildingExplosionGenericGreen]]

objectName = [[metalextractort3.s3o]]
script = [[metalextractor_up4_lus.lua]]

tech = [[tech4]]

noenergycost = false

skyhateceg = [[custom:skyhatelasert3]]

faction = [[Loz Alliance]]

VFS.Include("units-configs-basedefs/basedefs/Fed and Loz Shared Buildings/metalextractor_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------