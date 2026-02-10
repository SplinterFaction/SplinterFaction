--------------------------------------------------------------------------------

unitName = [[fedmetalextractor_up3]]

--------------------------------------------------------------------------------
buildCostMetal = 1200

primaryCEG = "custom:fusionreactionnuclear-4color"

humanName = [[E->M Converter (Tech 3)]]
description = [[Converts energy to metal]]

iconType = [[structuremetalgeneratort3]]

explodeAsSelfSAs = [[largeBuildingExplosionGenericGreen]]

objectName = [[newmetalextractor.s3o]]
script = [[newmetalextractor_up3_lus.lua]]

tech = [[tech3]]

noenergycost = false

skyhateceg = [[custom:skyhatelasert3]]

faction = [[Federation of Kala]]

VFS.Include("units-configs-basedefs/basedefs/Fed and Loz Shared Buildings/metalextractor_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------