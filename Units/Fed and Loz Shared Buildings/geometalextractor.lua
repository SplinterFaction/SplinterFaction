--------------------------------------------------------------------------------

unitName = [[geometalextractor]]

--------------------------------------------------------------------------------

metalMultiplier = 32

buildCostMetal = 3000
energyUse = 250

primaryCEG = "custom:fusionreactionnuclear-4color"

humanName = [[Geothermal Metal Extractor - Tech 4]]

explodeAsSelfSAs = [[hugeBuildingExplosionGenericGreen]]

objectName = [[metalextractort3.s3o]]
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