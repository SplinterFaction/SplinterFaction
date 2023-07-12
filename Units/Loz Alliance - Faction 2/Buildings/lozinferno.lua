--------------------------------------------------------------------------------

unitName = [[lozinferno]]

--------------------------------------------------------------------------------

humanName = [[Inferno]]

objectName = [[lozinferno.s3o]]
script = [[lozinferno_lus.lua]]

tech = [[tech2]]

faction = [[Loz Alliance]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/buildings/lozinferno_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------