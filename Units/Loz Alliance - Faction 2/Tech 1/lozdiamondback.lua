--------------------------------------------------------------------------------

unitName = "lozdiamondback"

--------------------------------------------------------------------------------

humanName = [[Diamondback]]

objectName = "lozdiamondback.s3o"
script = "lozdiamondback_lus.lua"

tech = [[tech1]]
armortype = [[light]]
supply = [[1]]

VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/Tier 1/lozdiamondback_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
