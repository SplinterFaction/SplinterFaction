--------------------------------------------------------------------------------

unitName = [[fedmetalextractor_stripmine_up3]]

--------------------------------------------------------------------------------

metalMultiplier = 24

buildCostMetal = 1200
energyUse = 300

primaryCEG = "custom:fusionreactionnuclear-4color"

humanName = [[Stripmining Metal Extractor - Tech 3]]

explodeAsSelfSAs = [[commnuke_up3]]

objectName = [[metalextractort3.s3o]]
script = [[metalextractor_up3_lus.lua]]

tech = [[tech3]]

noenergycost = false

skyhateceg = [[custom:skyhatelasert3]]

VFS.Include("units-configs-basedefs/basedefs/Fed and Loz Shared Buildings/metalextractor_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------