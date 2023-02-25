--------------------------------------------------------------------------------

unitName = [[metalextractor_armed_up2]]

--------------------------------------------------------------------------------

metalMultiplier = 8

buildCostMetal = 3480
energyUse = 50

primaryCEG = "custom:fusionreactionnuclear-2color"

humanName = [[Armed Metal Extractor - Tech 2]]

explodeAsSelfSAs = [[largeBuildingExplosionGeneric]]

objectName = [[metalextractort2_armed.s3o]]
script = [[metalextractor_armed_up2_lus.lua]]

tech = [[tech2]]

noenergycost = false

skyhateceg = [[custom:skyhatelasert1]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Fed and Loz Shared Buildings/metalextractor_armed_up2_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------