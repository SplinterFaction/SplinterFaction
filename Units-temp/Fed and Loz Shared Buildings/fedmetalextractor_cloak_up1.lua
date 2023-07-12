--------------------------------------------------------------------------------

unitName = [[fedmetalextractor_cloak_up1]]

--------------------------------------------------------------------------------

metalMultiplier = 4

buildCostMetal = 400
energyUse = 25

primaryCEG = "custom:fusionreactionnuclear-2color"

humanName = [[Metal Extractor - Tech 1]]

explodeAsSelfSAs = [[largeBuildingExplosionGeneric]]

objectName = [[metalextractort1.s3o]]
script = [[metalextractor_up1_lus.lua]]

tech = [[tech1]]

noenergycost = false

skyhateceg = [[custom:skyhatelasert1]]

area_cloak = 1 -- Can this unit emit a cloaking field?
area_cloak_upkeep = 0 -- How much energy does it cost to maintain the cloaking field?
area_cloak_radius = 400 -- How large is the cloaking field?
area_cloak_grow_rate = 200 -- When the cloaking field is turned on, how fast does the field expand to it's full size?
area_cloak_shrink_rate = 200 -- When the cloaking field is turned off, how fast does the field shrink to nothingness?
area_cloak_decloak_distance = 100 -- How close does something have to be in order to decloak a unit within a cloaking shield?
area_cloak_init = true -- Start up the cloak shield the moment the unit is built?
area_cloak_draw = true -- No idea what this does
area_cloak_self = true -- Does the cloak shield cloak the unit emitting it?

VFS.Include("units-configs-basedefs/basedefs/Fed and Loz Shared Buildings/metalextractor_cloaking_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------