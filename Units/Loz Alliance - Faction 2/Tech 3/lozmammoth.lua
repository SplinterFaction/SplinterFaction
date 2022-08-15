--------------------------------------------------------------------------------

unitName = "lozmammoth"

--------------------------------------------------------------------------------

humanName = "Mammoth"

objectName = "lozmammoth.s3o"
script = "lozmammoth_lus.lua"

tech = [[tech3]]

VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/Tier 3/lozmammoth_basedef.lua")
	
unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
