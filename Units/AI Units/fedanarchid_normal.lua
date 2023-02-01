--------------------------------------------------------------------------------

unitName = "fedanarchid_normal"

--------------------------------------------------------------------------------

humanName = [[Corrupted Anarchid (Boss)]]

objectName = "fedanarchid_big.s3o"
script = "fedanarchid.cob"

hitPoints = 80000

tech = [[tech4]]

explodeAs = [[commnuke_up4]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("Units-Configs-Basedefs/basedefs/Federation of Kala - Faction 1/Tier 4/fedanarchid_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------