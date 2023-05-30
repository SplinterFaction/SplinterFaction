--------------------------------------------------------------------------------

unitName = [[fedmenlomk2]]

--------------------------------------------------------------------------------

humanName = [[Menlo Mark II]]

objectName = [[fedmenlomk2.s3o]]
script = [[fedmenlo_lus.lua]]

tech = [[tech2]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/buildings/fedmenlomk2_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------