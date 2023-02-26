--------------------------------------------------------------------------------

unitName = [[lozmetalextractor_armed_up3]]

--------------------------------------------------------------------------------

metalMultiplier = 16

buildCostMetal = 6220
energyUse = 100

primaryCEG = "custom:fusionreactionnuclear-2color"

humanName = [[Armed Metal Extractor - Tech 3]]

explodeAsSelfSAs = [[largeBuildingExplosionGeneric]]

objectName = [[metalextractort3_armed.s3o]]
script = [[metalextractor_armed_up3_lus.lua]]

tech = [[tech3]]

noenergycost = false

skyhateceg = [[custom:skyhatelasert1]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Fed and Loz Shared Buildings/metalextractor_armed_up3_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------