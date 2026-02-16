--------------------------------------------------------------------------------

unitName = [[fedmenlo]]

--------------------------------------------------------------------------------

humanName = [[Menlo]]

buildtimemultiplier = 0.75

objectName = [[fedmenlo.s3o]]
script = [[fedmenlo_lus.lua]]

tech = [[tech1]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/buildings/fedmenlo_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------