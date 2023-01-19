--------------------------------------------------------------------------------

unitName = "lozsilverback"

--------------------------------------------------------------------------------

humanName = "Silverback"

objectName = "lozsilverback.s3o"
script = "lozsilverback_lus.lua"

tech = [[tech3]]

explodeAs = [[largeexplosiongenericred]]

shield1Power               = 36000
shield1StartingPower       = 18000
shield1PowerRegen          = 250
shield1PowerRegenEnergy    = 0
shieldRechargeDelay        = 45

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/Tier 3/lozsilverback_basedef.lua")
	
unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
