--------------------------------------------------------------------------------

unitName = "fedeagle"

--------------------------------------------------------------------------------

humanName = [[Eagle]]

objectName = "fedeagle.s3o"
script = "fedeagle_lus.lua"


tech = [[tech3]]

explodeAs = [[largeexplosiongenericred]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("Units-Configs-Basedefs/basedefs/Federation of Kala - Faction 1/Tier 3/fedeagle_basedef.lua")

unitDef.weaponDefs = weaponDefs

--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
