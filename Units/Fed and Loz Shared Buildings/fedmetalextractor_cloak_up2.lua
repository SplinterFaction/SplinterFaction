--------------------------------------------------------------------------------

unitName = [[fedmetalextractor_cloak_up2]]

--------------------------------------------------------------------------------

metalMultiplier = 8

buildCostMetal = 2300
energyUse = 50

primaryCEG = "custom:fusionreactionnuclear-3color"

humanName = [[Metal Extractor - Tech 2]]

explodeAsSelfSAs = [[largeBuildingExplosionGenericPurple]]

objectName = [[metalextractort2.s3o]]
script = [[metalextractor_up2_lus.lua]]

tech = [[tech2]]

noenergycost = false

skyhateceg = [[custom:skyhatelasert2]]

area_cloak = 1 -- Can this unit emit a cloaking field?
area_cloak_upkeep = 0 -- How much energy does it cost to maintain the cloaking field?
area_cloak_radius = 600 -- How large is the cloaking field?
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