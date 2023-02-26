--------------------------------------------------------------------------------

unitName = [[fedmetalextractor_stripmine_up2]]

--------------------------------------------------------------------------------

metalMultiplier = 12

buildCostMetal = 600
energyUse = 150

primaryCEG = "custom:fusionreactionnuclear-3color"

humanName = [[Stripmining Metal Extractor - Tech 2]]

explodeAsSelfSAs = [[commnuke_up2]]

objectName = [[metalextractort2.s3o]]
script = [[metalextractor_up2_lus.lua]]

tech = [[tech2]]

noenergycost = false

skyhateceg = [[custom:skyhatelasert2]]

VFS.Include("units-configs-basedefs/basedefs/Fed and Loz Shared Buildings/metalextractor_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------