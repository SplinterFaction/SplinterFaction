--------------------------------------------------------------------------------

unitName = [[lozannihilator]]

--------------------------------------------------------------------------------

humanName = [[annihilator]]

objectName = [[lozannihilator.s3o]]
script = [[lozannihilator_lus.lua]]

tech = [[tech3]]

VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/buildings/lozannihilator_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------