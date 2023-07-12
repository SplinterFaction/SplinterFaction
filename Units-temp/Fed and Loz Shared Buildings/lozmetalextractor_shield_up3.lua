--------------------------------------------------------------------------------

unitName = [[lozmetalextractor_shield_up3]]

--------------------------------------------------------------------------------

metalMultiplier = 16

buildCostMetal = 1200
energyUse = 100

primaryCEG = "custom:fusionreactionnuclear-4color"

humanName = [[Shielded Metal Extractor - Tech 3]]

explodeAsSelfSAs = [[largeBuildingExplosionGenericGreen]]

objectName = [[metalextractort3.s3o]]
script = [[metalextractor_up3_lus.lua]]

tech = [[tech3]]

noenergycost = false

skyhateceg = [[custom:skyhatelasert3]]

shieldradius = 750
weapon1 = [[shield_up3]]

VFS.Include("units-configs-basedefs/basedefs/Fed and Loz Shared Buildings/metalextractor_shield_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------