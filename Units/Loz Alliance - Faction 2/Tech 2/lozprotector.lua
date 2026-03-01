--------------------------------------------------------------------------------

unitName = "lozprotector"

--------------------------------------------------------------------------------

humanName = [[Protector]]

objectName = "lozprotector.s3o"
script = "lozprotector_lus.lua"

tech = [[tech2]]

explodeAs = [[largeexplosiongenericblue]]

shield1Power               = 4400
shield1StartingPower       = 4400
shield1PowerRegen          = 60
shield1PowerRegenEnergy    = 0
shieldRechargeDelay        = 50

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/Tier 2/lozprotector_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
