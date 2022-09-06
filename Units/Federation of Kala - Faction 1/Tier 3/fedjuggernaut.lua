--------------------------------------------------------------------------------

unitName = "fedjuggernaut"

--------------------------------------------------------------------------------
humanName = [[Juggernaut]]

objectName = "fedjuggernaut.s3o"
script = "/fed/hbot/fedjuggernaut_lus.lua"

tech = [[tech3]]

explodeAs = [[largeexplosiongenericred]]

VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/Tier 3/fedjuggernaut_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------