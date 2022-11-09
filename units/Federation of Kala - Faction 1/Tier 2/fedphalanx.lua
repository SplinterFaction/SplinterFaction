--------------------------------------------------------------------------------

unitName = "fedphalanx"

--------------------------------------------------------------------------------
humanName = [[Phalanx]]

objectName = "fedphalanx.s3o"
script = "/fed/hbot/fedphalanx_lus.lua"

tech = [[tech2]]

explodeAs = [[mediumexplosiongenericpurple]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/Tier 2/fedphalanx_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------