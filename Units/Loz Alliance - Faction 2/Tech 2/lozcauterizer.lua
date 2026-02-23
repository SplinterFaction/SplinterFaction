--------------------------------------------------------------------------------

unitName = "lozcauterizer"

--------------------------------------------------------------------------------

humanName = "Cauterizer"

objectName = "lozcauterizer.s3o"
script = "lozcauterizer_lus.lua"

tech = [[tech2]]

explodeAs = [[mediumexplosiongeneric]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/Tier 2/lozcauterizer_basedef.lua")
	
unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
