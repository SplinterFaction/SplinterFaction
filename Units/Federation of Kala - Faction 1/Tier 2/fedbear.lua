--------------------------------------------------------------------------------

unitName = "fedbear"

--------------------------------------------------------------------------------
humanName = [[bear]]

objectName = "fedbear.s3o"
script = "/fed/hbot/fedbear_lus.lua"

tech = [[tech1]]
armortype = [[light]]
supply = [[7]]

VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/Tier 2/fedbear_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------