--------------------------------------------------------------------------------

unitName = [[geometalmaker]]

--------------------------------------------------------------------------------

metalMultiplier = 64

buildCostMetal = 4800
energyUse = 500

primaryCEG = "custom:fusionreactionnuclear-4color"

humanName = [[Geothermal Metal Maker]]

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