--------------------------------------------------------------------------------

unitName = "fedcondor"

--------------------------------------------------------------------------------

humanName = [[Condor]]

objectName = "fedcondor.s3o"
script = "fedcondor_lus.lua"


tech = [[tech2]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("Units-Configs-Basedefs/basedefs/Federation of Kala - Faction 1/Tier 2/fedcondor_basedef.lua")

unitDef.weaponDefs = weaponDefs

--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
