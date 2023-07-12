--------------------------------------------------------------------------------

unitName = [[lozmetalextractor_shield_up1]]

--------------------------------------------------------------------------------

metalMultiplier = 4

buildCostMetal = 150
energyUse = 25

primaryCEG = "custom:fusionreactionnuclear-2color"

humanName = [[Shielded Metal Extractor - Tech 1]]

explodeAsSelfSAs = [[largeBuildingExplosionGeneric]]

objectName = [[metalextractort1.s3o]]
script = [[metalextractor_up1_lus.lua]]

tech = [[tech1]]

noenergycost = false

skyhateceg = [[custom:skyhatelasert1]]

shieldradius = 250
weapon1 = [[shield_up1]]

VFS.Include("units-configs-basedefs/basedefs/Fed and Loz Shared Buildings/metalextractor_shield_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------