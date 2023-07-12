--------------------------------------------------------------------------------

unitName = "lozemperorscorpion"

--------------------------------------------------------------------------------

humanName = [[Emperor Scorpion]]

objectName = "lozemperorscorpion.s3o"
script = "lozemperorscorpion_lus.lua"

tech = [[tech3]]

explodeAs = [[largeexplosiongenericblue]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/Tier 3/lozemperorscorpion_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
