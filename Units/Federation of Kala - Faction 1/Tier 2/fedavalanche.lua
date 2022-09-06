--------------------------------------------------------------------------------

unitName = "fedavalanche"

--------------------------------------------------------------------------------
humanName = [[Avalanche]]

objectName = "fedavalanche.s3o"
script = "/fed/hbot/fedavalanche_lus.lua"

tech = [[tech2]]

explodeAs = [[mediumexplosiongenericred]]

VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/Tier 2/fedavalanche_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------