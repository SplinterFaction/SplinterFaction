--------------------------------------------------------------------------------

unitName = "fedanvil"

--------------------------------------------------------------------------------

isUpgraded = [[0]]

humanName = [[Anvil]]

objectName = "eallterrassault.s3o"
script = "eallterrassault.cob"

tech = [[tech2]]
armortype = [[armored]]
supply = [[8]]

VFS.Include("Units-Configs-Basedefs/basedefs/Federation of Kala - Faction 1/Tier 2/fedanvil_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------