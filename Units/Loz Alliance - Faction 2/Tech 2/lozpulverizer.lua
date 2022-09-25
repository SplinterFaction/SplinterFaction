--------------------------------------------------------------------------------

unitName = "lozpulverizer"

--------------------------------------------------------------------------------

humanName = "Pulverizer"

objectName = "lozpulverizer.s3o"
script = "lozpulverizer_lus.lua"

tech = [[tech2]]

explodeAs = [[mediumexplosiongenericblue]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/Tier 2/lozpulverizer_basedef.lua")
	
unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
