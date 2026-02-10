--------------------------------------------------------------------------------

unitName = [[fedmetalextractor_up4]]

--------------------------------------------------------------------------------
buildCostMetal = 2400

primaryCEG = "custom:fusionreactionnuclear-4color"

humanName = [[E->M Converter (Tech 4)]]
description = [[Converts energy to metal]]

iconType = [[structuremetalgeneratort4]]

explodeAsSelfSAs = [[largeBuildingExplosionGenericGreen]]

objectName = [[newmetalextractor.s3o]]
script = [[newmetalextractor_up4_lus.lua]]

tech = [[tech4]]

noenergycost = false

skyhateceg = [[custom:skyhatelasert3]]

faction = [[Federation of Kala]]

VFS.Include("units-configs-basedefs/basedefs/Fed and Loz Shared Buildings/metalextractor_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------