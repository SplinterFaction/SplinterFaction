--------------------------------------------------------------------------------

unitName = [[fedmetalextractor_up2]]

--------------------------------------------------------------------------------
buildCostMetal = 600

primaryCEG = "custom:fusionreactionnuclear-3color"

humanName = [[E->M Converter (Tech 2)]]
description = [[Converts energy to metal]]

iconType = [[structuremetalgeneratort2]]

explodeAsSelfSAs = [[largeBuildingExplosionGenericPurple]]

objectName = [[newmetalextractor.s3o]]
script = [[newmetalextractor_up2_lus.lua]]

tech = [[tech2]]

noenergycost = false

skyhateceg = [[custom:skyhatelasert2]]

faction = [[Federation of Kala]]

VFS.Include("units-configs-basedefs/basedefs/Fed and Loz Shared Buildings/metalextractor_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------