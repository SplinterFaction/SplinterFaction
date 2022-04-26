--------------------------------------------------------------------------------

unitName = "fedrazorback"

--------------------------------------------------------------------------------

isUpgraded = [[0]]

humanName = [[Razorback]]

objectName = "fedrazorback.s3o"
script = "fed/hbot/fedrazorback_lus.lua"

tech = [[tech3]]
armortype = [[armored]]

VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/Tier 3/fedrazorback_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------