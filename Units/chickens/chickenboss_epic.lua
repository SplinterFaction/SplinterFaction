--------------------------------------------------------------------------------

unitName = "chickenboss_epic"

--------------------------------------------------------------------------------

humanName = [[Corrupted Anarchid (Boss)]]

objectName = "fedanarchid_big.s3o"
script = "chickenboss.cob"

hitPoints = 250000

tech = [[tech4]]

explodeAs = [[commnuke_up4]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("Units-Configs-Basedefs/basedefs/chickens/chickenboss_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------