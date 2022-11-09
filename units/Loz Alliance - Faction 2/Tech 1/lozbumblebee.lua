--------------------------------------------------------------------------------

unitName = "lozbumblebee"

--------------------------------------------------------------------------------

humanName = [[Bumblebee]]

objectName = "lozbumblebee.s3o"
script = "lozbumblebee_lus.lua"


tech = [[tech1]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("Units-Configs-Basedefs/basedefs/Loz Alliance - Faction 2/Tier 1/lozbumblebee_basedef.lua")

unitDef.weaponDefs = weaponDefs

--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
