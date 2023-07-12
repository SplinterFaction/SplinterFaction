--------------------------------------------------------------------------------

unitName = "federaser"

--------------------------------------------------------------------------------
humanName = [[Eraser]]

objectName = "eallterrshield.s3o"
script = "eallterrshield.cob"

tech = [[tech2]]
armortype = [[armored]]
supply = [[5]]

VFS.Include("Units-Configs-Basedefs/basedefs/Federation of Kala - Faction 1/Tier 2/federaser_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------