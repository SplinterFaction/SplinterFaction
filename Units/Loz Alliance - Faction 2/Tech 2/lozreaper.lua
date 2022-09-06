--------------------------------------------------------------------------------

unitName = "lozreaper"

--------------------------------------------------------------------------------

humanName = "Reaper"

objectName = "lozreaper.s3o"
script = "lozreaper_lus.lua"

tech = [[tech2]]

explodeAs = [[mediumexplosiongeneric]]

VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/Tier 2/lozreaper_basedef.lua")
	
unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
