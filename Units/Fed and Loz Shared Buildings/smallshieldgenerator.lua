--------------------------------------------------------------------------------

local unitName                    = "smallshieldgenerator"

--------------------------------------------------------------------------------

local armortype					 = [[building]]

local techrequired				 = [[tech2]]

local shield1Power               = 1200
local shield1PowerRegen          = 25
local shield1PowerRegenEnergy    = 0
local buildCostMetal 			  = 350
local maxDamage					  = buildCostMetal * 12.5
local shieldRechargeDelay		 = 8

local unitDef                     = {
	activateWhenBuilt             = true,
	buildAngle                    = 4096,
	buildCostEnergy               = 0,
	buildCostMetal                = buildCostMetal,
	builder                       = false,
	buildTime                     = 1,
	canAttack                     = false,
	canstop                       = "1",
	category                      = "BUILDING",
	damageModifier                = 0.2,
	description                   = [[Protective Shield • Shield can link with other shield units to increase charging and capacity]],
	energyStorage                 = 0,
	energyUse                     = 0,
	explodeAs                     = "mediumBuildingExplosionGenericBlue",
	footprintX                    = 2,
	footprintZ                    = 2,
	floater			              = false,
	iconType                      = "shield",
	idleAutoHeal                  = .5,
	idleTime                      = 2200,
	maxDamage                     = maxDamage,
	maxSlope                      = 60,
	maxWaterDepth                 = 0,
	mass				          = 1000,
	metalStorage                  = 0,
	name                          = "Kmar",
	onOffable					  = true,
	objectName                    = "smallshieldgenerator.s3o",
	script			              = "smallshieldgenerator_lus.lua",
	repairable		              = false,
	selfDestructAs                = "mediumBuildingExplosionGenericBlue",
	selfDestructCountdown         = 0,
	side                          = "ARM",
	sightDistance                 = 0,
	smoothAnim                    = true,
	TEDClass                      = "FORT",
	unitname                      = unitName,
	workerTime                    = 0,
	yardMap                       = "ooo ooo ooo",

	sfxtypes                      = {
		pieceExplosionGenerators  = {
			"deathceg3",
			"deathceg4",
		},
		
		explosiongenerators       = {
			"custom:blacksmoke",
		},
	},

	sounds                        = {
		underattack               = "other/unitsunderattack1",
		select                    = {
			"other/turretselect",
		},
	},

	weapons                       = {
		[1]                       = {
			def                   = "shield",
		},
	},

	customParams                  = {
		RequireTech				 = techrequired,
		unittype				  = "building",
		unitrole 				  = "Support Building",
		needed_cover              = 1,
		death_sounds              = "generic",
		shield_power			  = shield1Power,
		normaltex                = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                 = "unittextures/lego2skin_explorerbucket.dds",
		factionname	              = "Neutral",
	},
	useGroundDecal                = true,
	BuildingGroundDecalType       = "factorygroundplate.dds",
	BuildingGroundDecalSizeX      = 5,
	BuildingGroundDecalSizeY      = 5,
	BuildingGroundDecalDecaySpeed = 0.9,
}


--------------------------------------------------------------------------------

local weaponDefs                  = {
	shield                        = {
		
		Smartshield               = true,
		Exteriorshield            = true,
		Visibleshield             = false,
		Visibleshieldrepulse      = false,
		ShieldStartingPower       = shield1Power * 0.5,
		Shieldenergyuse           = 0,
		Shieldradius              = 150,
		Shieldpower               = shield1Power,
		Shieldpowerregen          = shield1PowerRegen,
		Shieldpowerregenenergy    = shield1PowerRegenEnergy,
		rechargeDelay		  	  = shieldRechargeDelay,
		Shieldintercepttype       = 4,
		Shieldgoodcolor           = "0.0 0.2 1.0",
		Shieldbadcolor            = "1.0 0 0",
		Shieldalpha              = 0.2,
		
		texture1		          = "shield4",
		
		visibleShieldHitFrames    = 1,
		weaponType                = [[Shield]],
		damage                    = {
			default               = 1,
		},
	},
}
unitDef.weaponDefs                = weaponDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName]     = unitDef })

--------------------------------------------------------------------------------
