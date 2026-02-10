--------------------------------------------------------------------------------

unitName = [[geometalmaker]]

--------------------------------------------------------------------------------
buildCostMetal = 4800

primaryCEG = "custom:fusionreactionnuclear-4color"

humanName = [[Geothermal E->M Converter (Tech 4)]]
description = [[Converts energy to metal]]

explodeAsSelfSAs = [[hugeBuildingExplosionGenericGreen]]

objectName = [[metalmaker_geo_t4.s3o]]
script = [[metalextractor_geo_lus.lua]]

tech = [[tech4]]

noenergycost = false

skyhateceg = [[custom:skyhatelasert3]]

faction = [[Neutral]]

VFS.Include("units-configs-basedefs/basedefs/Fed and Loz Shared Buildings/metalextractor_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------