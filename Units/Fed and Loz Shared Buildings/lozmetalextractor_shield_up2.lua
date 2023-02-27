--------------------------------------------------------------------------------

unitName = [[lozmetalextractor_shield_up2]]

--------------------------------------------------------------------------------

metalMultiplier = 8

buildCostMetal = 600
energyUse = 50

primaryCEG = "custom:fusionreactionnuclear-3color"

humanName = [[Shielded Metal Extractor - Tech 2]]

explodeAsSelfSAs = [[largeBuildingExplosionGenericPurple]]

objectName = [[metalextractort2.s3o]]
script = [[metalextractor_up2_lus.lua]]

tech = [[tech2]]

noenergycost = false

skyhateceg = [[custom:skyhatelasert2]]

shieldradius = 500
weapon1 = [[shield_up2]]

VFS.Include("units-configs-basedefs/basedefs/Fed and Loz Shared Buildings/metalextractor_shield_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------