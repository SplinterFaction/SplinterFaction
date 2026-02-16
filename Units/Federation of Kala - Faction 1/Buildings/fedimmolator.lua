--------------------------------------------------------------------------------

unitName = [[fedimmolator]]

--------------------------------------------------------------------------------

humanName = [[Immolator]]

buildtimemultiplier = 0.5

objectName = [[fedimmolator.s3o]]
script = [[fedimmolator_lus.lua]]

tech = [[tech2]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/buildings/fedimmolator_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------