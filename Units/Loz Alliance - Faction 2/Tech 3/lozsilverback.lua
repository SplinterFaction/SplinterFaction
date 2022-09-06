--------------------------------------------------------------------------------

unitName = "lozsilverback"

--------------------------------------------------------------------------------

humanName = "Silverback"

objectName = "lozsilverback.s3o"
script = "lozsilverback_lus.lua"

tech = [[tech3]]

explodeAs = [[largeexplosiongenericred]]

shield1Power               = 10000
shield1PowerRegen          = 25
shield1PowerRegenEnergy    = 0

VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/Tier 3/lozsilverback_basedef.lua")
	
unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
