--------------------------------------------------------------------------------

unitName = [[fedmetalextractor_stripmine_up1]]

--------------------------------------------------------------------------------

metalMultiplier = 6

buildCostMetal = 150
energyUse = 75

primaryCEG = "custom:fusionreactionnuclear-2color"

humanName = [[Stripmining Metal Extractor - Tech 1]]

explodeAsSelfSAs = [[commnuke_up1]]

objectName = [[metalextractort1.s3o]]
script = [[metalextractor_up1_lus.lua]]

tech = [[tech1]]

noenergycost = false

skyhateceg = [[custom:skyhatelasert1]]

VFS.Include("units-configs-basedefs/basedefs/Fed and Loz Shared Buildings/metalextractor_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------