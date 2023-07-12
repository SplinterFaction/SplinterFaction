--------------------------------------------------------------------------------

unitName = [[lozmetalextractor_armed_up1]]

--------------------------------------------------------------------------------

metalMultiplier = 4

buildCostMetal = 890
energyUse = 25

primaryCEG = "custom:fusionreactionnuclear-2color"

humanName = [[Armed Metal Extractor - Tech 1]]

explodeAsSelfSAs = [[largeBuildingExplosionGeneric]]

objectName = [[metalextractort1_armed.s3o]]
script = [[metalextractor_armed_up1_lus.lua]]

tech = [[tech1]]

noenergycost = false

skyhateceg = [[custom:skyhatelasert1]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Fed and Loz Shared Buildings/metalextractor_armed_up1_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------