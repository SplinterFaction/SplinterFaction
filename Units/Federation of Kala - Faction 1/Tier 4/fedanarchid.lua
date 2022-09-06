--------------------------------------------------------------------------------

unitName = "fedanarchid"

--------------------------------------------------------------------------------

humanName = [[Anarchid]]

objectName = "fedanarchid.s3o"
script = "fedanarchid.cob"

tech = [[tech4]]

explodeAs = [[hugeexplosiongeneric]]

VFS.Include("Units-Configs-Basedefs/basedefs/Federation of Kala - Faction 1/Tier 4/fedanarchid_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------