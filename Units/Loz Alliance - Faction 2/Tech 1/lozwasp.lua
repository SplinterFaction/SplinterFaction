--------------------------------------------------------------------------------

unitName = "lozwasp"

--------------------------------------------------------------------------------

humanName = [[Wasp]]

objectName = "lozwasp.s3o"
script = "lozwasp_lus.lua"


tech = [[tech1]]

VFS.Include("Units-Configs-Basedefs/basedefs/Loz Alliance - Faction 2/Tier 1/lozwasp_basedef.lua")

unitDef.weaponDefs = weaponDefs

--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
