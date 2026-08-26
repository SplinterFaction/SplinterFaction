--------------------------------------------------------------------------------

unitName = [[lozmetalextractor_up1]]

--------------------------------------------------------------------------------
buildCostMetal = 150

primaryCEG = "custom:fusionreactionnuclear-2color"

humanName = [[E->M Converter (Tech 1)]]
description = [[Converts energy to metal]]

iconType = [[structuremetalgeneratort1]]

explodeAsSelfSAs = [[largeBuildingExplosionGeneric]]

objectName = [[newmetalextractor.s3o]]
script = [[newmetalextractor_up1_lus.lua]]

tech = [[tech1]]

noenergycost = false

skyhateceg = [[custom:skyhatelasert1]]

faction = [[Loz Alliance]]

VFS.Include("units-configs-basedefs/basedefs/Fed and Loz Shared Buildings/metalextractor_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------