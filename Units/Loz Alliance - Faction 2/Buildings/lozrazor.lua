--------------------------------------------------------------------------------

unitName = [[lozrazor]]

--------------------------------------------------------------------------------

humanName = [[Razor]]

buildtimemultiplier = 0.5

objectName = [[lozrazor.s3o]]
script = [[lozrazor_lus.lua]]

tech = [[tech1]]

faction = [[Loz Alliance]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/buildings/lozrazor_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------