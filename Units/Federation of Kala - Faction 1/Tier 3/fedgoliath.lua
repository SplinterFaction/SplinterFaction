--------------------------------------------------------------------------------

unitName = "fedgoliath"

--------------------------------------------------------------------------------
humanName = [[Goliath]]

objectName = "fedgoliath.s3o"
script = "/fed/hbot/fedgoliath_lus.lua"

tech = [[tech3]]

explodeAs = [[largeexplosiongeneric]]

VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/Tier 3/fedgoliath_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------