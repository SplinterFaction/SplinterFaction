--------------------------------------------------------------------------------

unitName = "fedcobra"

--------------------------------------------------------------------------------
humanName = [[Cobra]]

objectName = "fedcobra.s3o"
script = "/fed/hbot/fedcobra_lus.lua"

tech = [[tech2]]

explodeAs = [[mediumexplosiongenericblue]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/Tier 2/fedcobra_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------