--------------------------------------------------------------------------------

unitName = "fedsparrow"

--------------------------------------------------------------------------------

humanName = [[Sparrow]]

objectName = "fedsparrow.s3o"
script = "fedsparrow_lus.lua"


tech = [[tech1]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("Units-Configs-Basedefs/basedefs/Federation of Kala - Faction 1/Tier 1/fedsparrow_basedef.lua")

unitDef.weaponDefs = weaponDefs

--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
