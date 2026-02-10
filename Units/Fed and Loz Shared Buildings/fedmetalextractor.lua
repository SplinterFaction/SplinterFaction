--------------------------------------------------------------------------------

unitName = [[fedmetalextractor]]

--------------------------------------------------------------------------------
buildCostMetal = 50

primaryCEG = "custom:fusionreactionnuclear-1color"

humanName = [[E->M Converter (Tech 0)]]
description = [[Converts energy to metal]]

iconType = [[structuremetalgeneratort0]]

explodeAsSelfSAs = [[largeBuildingExplosionGenericBlue]]

objectName = [[newmetalextractor.s3o]]
script = [[newmetalextractor_lus.lua]]

tech = [[tech0]]

noenergycost = false

skyhateceg = [[custom:skyhatelasert0]]

faction = [[Federation of Kala]]

VFS.Include("units-configs-basedefs/basedefs/Fed and Loz Shared Buildings/metalextractor_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------