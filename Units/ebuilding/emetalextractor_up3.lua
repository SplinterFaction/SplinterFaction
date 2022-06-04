-- UNITDEF -- EMETALEXTRACTOR_up3 --
--------------------------------------------------------------------------------

unitName = [[emetalextractor_up3]]

--------------------------------------------------------------------------------

metalMultiplier = 16

buildCostMetal = 1200
energyUse = 100

primaryCEG = "custom:fusionreactionnuclear-4color"

humanName = [[Metal Extractor Mk IV]]

objectName = [[emetalextractor2_up3.s3o]]
script = [[emetalextractor.cob]]

tech = [[tech3]]
armortype = [[building]]

VFS.Include("units-configs-basedefs/basedefs/buildings/emetalextractor_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------