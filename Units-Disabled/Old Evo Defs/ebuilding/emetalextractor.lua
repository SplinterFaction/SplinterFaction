-- UNITDEF -- EMETALEXTRACTOR --
--------------------------------------------------------------------------------

unitName = [[emetalextractor]]

--------------------------------------------------------------------------------

ateranMexCost = Spring.GetModOptions().metalextractorcostateran or 50

metalMultiplier = 2

buildCostMetal = ateranMexCost
energyUse = 0

primaryCEG = "custom:fusionreactionnuclear-1color"

humanName = [[Metal Extractor]]

objectName = [[emetalextractor2_small.s3o]]
script = [[emetalextractor.cob]]

tech = [[tech0]]
armortype = [[building]]

skyhateceg = [[custom:skyhatelasert0]]

VFS.Include("units-configs-basedefs/basedefs/buildings/emetalextractor_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------