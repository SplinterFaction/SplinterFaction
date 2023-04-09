--------------------------------------------------------------------------------

unitName = "lozprotector"

--------------------------------------------------------------------------------

humanName = [[Protector]]

objectName = "lozprotector.s3o"
script = "lozprotector_lus.lua"

tech = [[tech3]]

explodeAs = [[largeexplosiongenericblue]]

shield1Power               = 54670
shield1StartingPower       = 54670
shield1PowerRegen          = 1000
shield1PowerRegenEnergy    = 0
shieldRechargeDelay        = 25

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/Tier 3/lozprotector_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
