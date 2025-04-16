unitDef                     = {

	activateWhenBuilt             = true,
	buildAngle                    = 2048,
	buildCostEnergy               = 0,
	buildCostMetal                = buildCostMetal,
	buildingMask				  = 0,
	builder                       = false,
	buildTime                     = 5,
	buildPic					  = "emetalextractor.png",
	canAttack			          = false,
	category                      = "BUILDING",
	description                   = [[Generates Metal from Resource Nodes]],
	energyStorage                 = 100,
	energyUse                     = energyUse,
	explodeAs                     = explodeAsSelfSAs,
	makesMetal                    = 0,
	footprintX                    = 5,
	footprintZ                    = 5,
	iconType                      = "economy",
	idleAutoHeal                  = .5,
	idleTime                      = 2200,
	maxDamage                     = buildCostMetal * 12.5,
	maxSlope                      = 90,
	maxWaterDepth                 = 5000,
	metalStorage                  = 100,
	metalMake                     = 0,
	name                          = humanName,
	objectName                    = objectName,
	script						  = script,
	onoffable                     = true,
	radarDistance                 = 0,
	repairable		              = false,
	selfDestructAs                = explodeAsSelfSAs,
	selfDestructCountdown         = 15,
	side                          = "CORE",
	sightDistance                 = 200,
	smoothAnim                    = true,
	unitName                      = unitName,
	workerTime                    = 0,
	yardMap                       = "yoooy yoooy yoooy yoooy yoooy",
	sfxtypes                      = { 
		pieceExplosionGenerators  = { 
			"deathceg3", 
			"deathceg4", 
		}, 

		explosiongenerators       = {
			"custom:blacksmoke",
			primaryCEG,
			skyhateceg,
		},
	},
	sounds                        = {
		underattack               = "units_under_attack",
		select                    = {
			"other/gdmex",
		},
	},
	weapons                       = {
		[1]                      = {
			def                  = weapon1,
		},
	},
	customParams                  = {
		RequireTech				  = tech,
		unittype				  = "building",
		unitrole				  = "Economy",
		metal_extractor			  = metalMultiplier,
		iseco                     = 1,
		needed_cover              = 3,
		death_sounds              = "generic",
		armortype                 = armortype,
		noenergycost			  = noenergycost,
		normaltex                = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                 = "unittextures/lego2skin_explorerbucket.dds",
		factionname	              = "Neutral",
		corpse                   = "energycore",
	},
	useGroundDecal                = true,
	BuildingGroundDecalType       = "factorygroundplate.dds",
	BuildingGroundDecalSizeX      = 9,
	BuildingGroundDecalSizeY      = 9,
	BuildingGroundDecalDecaySpeed = 0.9,
}


weaponDefs                 = {
	shield_up1                = {

		Smartshield               = true,
		Exteriorshield            = true,
		Visibleshield             = false,
		Visibleshieldrepulse      = false,
		ShieldStartingPower       = 4125,
		Shieldenergyuse           = 0,
		Shieldradius              = shieldradius,
		Shieldpower               = 8250,
		Shieldpowerregen          = 150,
		Shieldpowerregenenergy    = 0,
		rechargeDelay		  	  = 80,
		Shieldintercepttype       = 4,
		Shieldgoodcolor           = "0 0.2 1.0",
		Shieldbadcolor            = "1 0 0",
		Shieldalpha              = 0.2,

		texture1		          = "shield4",

		visibleShieldHitFrames    = 1,
		weaponType                = [[Shield]],
		damage                    = {
			default               = 1,
		},
	},

	shield_up2                = {

		Smartshield               = true,
		Exteriorshield            = true,
		Visibleshield             = false,
		Visibleshieldrepulse      = false,
		ShieldStartingPower       = 4125,
		Shieldenergyuse           = 0,
		Shieldradius              = shieldradius,
		Shieldpower               = 8250,
		Shieldpowerregen          = 150,
		Shieldpowerregenenergy    = 0,
		rechargeDelay		  	  = 80,
		Shieldintercepttype       = 4,
		Shieldgoodcolor           = "0 0.2 1.0",
		Shieldbadcolor            = "1 0 0",
		Shieldalpha              = 0.2,

		texture1		          = "shield4",

		visibleShieldHitFrames    = 1,
		weaponType                = [[Shield]],
		damage                    = {
			default               = 1,
		},
	},

	shield_up3                = {

		Smartshield               = true,
		Exteriorshield            = true,
		Visibleshield             = false,
		Visibleshieldrepulse      = false,
		ShieldStartingPower       = 4125,
		Shieldenergyuse           = 0,
		Shieldradius              = shieldradius,
		Shieldpower               = 8250,
		Shieldpowerregen          = 150,
		Shieldpowerregenenergy    = 0,
		rechargeDelay		  	  = 80,
		Shieldintercepttype       = 4,
		Shieldgoodcolor           = "0 0.2 1.0",
		Shieldbadcolor            = "1 0 0",
		Shieldalpha              = 0.2,

		texture1		          = "shield4",

		visibleShieldHitFrames    = 1,
		weaponType                = [[Shield]],
		damage                    = {
			default               = 1,
		},
	},

}