--------------------------------------------------------------------------------

unitName = "fedakm2"

--------------------------------------------------------------------------------
humanName = [[A.K.M.2]]

objectName = "fedakmk2.s3o"
script = "fed/hbot/fedakm2_lus.lua"

tech = [[tech3]]
armortype = [[armored]]
supply = [[6]]

VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/Tier 3/fedakm2_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------