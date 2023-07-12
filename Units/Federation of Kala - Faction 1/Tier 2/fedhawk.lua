--------------------------------------------------------------------------------

unitName = "fedhawk"

--------------------------------------------------------------------------------

humanName = [[Hawk]]

objectName = "fedhawk.s3o"
script = "fedhawk_lus.lua"


tech = [[tech2]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("Units-Configs-Basedefs/basedefs/Federation of Kala - Faction 1/Tier 2/fedhawk_basedef.lua")

unitDef.weaponDefs = weaponDefs

--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
