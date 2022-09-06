--------------------------------------------------------------------------------

unitName = "lozscorpion"

--------------------------------------------------------------------------------

humanName = [[Scorpion]]

objectName = "lozscorpion.s3o"
script = "lozscorpion.cob"

tech = [[tech1]]

explodeAs = [[smallexplosiongenericblue]]

VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/Tier 1/lozscorpion_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
