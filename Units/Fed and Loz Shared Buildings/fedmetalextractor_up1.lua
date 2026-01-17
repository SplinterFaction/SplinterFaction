--------------------------------------------------------------------------------

unitName = [[fedmetalextractor_up1]]

--------------------------------------------------------------------------------

metalMultiplier = 6

buildCostMetal = 150
energyUse = 25

primaryCEG = "custom:fusionreactionnuclear-2color"

humanName = [[Metal Extractor - Tech 1]]

iconType = [[structuremetalgeneratort1]]

explodeAsSelfSAs = [[largeBuildingExplosionGeneric]]

objectName = [[newmetalextractor.s3o]]
script = [[newmetalextractor_up1_lus.lua]]

tech = [[tech1]]

noenergycost = false

skyhateceg = [[custom:skyhatelasert1]]

faction = [[Federation of Kala]]

VFS.Include("units-configs-basedefs/basedefs/Fed and Loz Shared Buildings/metalextractor_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------