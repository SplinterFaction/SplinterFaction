--------------------------------------------------------------------------------

unitName = "fedequalizer"

--------------------------------------------------------------------------------
humanName = [[Equalizer]]

objectName = "fedequalizer.s3o"
script = "fed/hbot/fedequalizer_lus.lua"

tech = [[tech1]]

explodeAs = [[smallexplosiongeneric]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/Tier 1/fedequalizer_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------