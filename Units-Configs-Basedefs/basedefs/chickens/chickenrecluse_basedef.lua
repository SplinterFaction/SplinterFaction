unitDef                    = {
	buildCostEnergy              = 0,
	buildCostMetal               = 80,
	builder                      = false,
	buildTime                    = 5,
	buildpic					 = "chickenrecluse.png",
	canAttack                    = true,
	
	canGuard                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = "1",
	category                     = "GROUND",

	-- Cloaking

	-- cancloak		             = true,
	-- cloakCost		             = 0,
	-- cloakCostMoving	             = 0,
	-- minCloakDistance             = 70,
	-- decloakOnFire	             = true,
	-- decloakSpherical             = true,
	-- initCloaked		             = false,
	
	-- End Cloaking

	description                  = [[Raider]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = "smallExplosionGeneric",
	firestandorders              = "1",
	footprintX                   = 2,
	footprintZ                   = 2,
	iconType                     = "raider",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	leaveTracks                  = false,
	maxDamage                    = 245,
	
	maxReverseVelocity           = 2,
	maxWaterDepth                = 10,
	metalStorage                 = 0,
	movementClass                = "ALLTERRAINTANK2",
	name                         = humanName,
	objectName                   = objectName,
	script	                     = script,
	radarDistance                = 0,
	repairable		             = false,
	selfDestructAs               = "smallExplosionGeneric",
	sightDistance                = 450,
	smoothAnim                   = true,
	stealth			             = true,
	seismicSignature             = 2,
	transportbyenemy             = false;
	unitname                     = unitName,
	upright			             = false,
	workerTime                   = 0,
	--------------
	-- Movement --
	--------------
	acceleration 				 = 2,
	brakeRate                    = 0.1,
	maxVelocity                  = 5.3,
	turninplace 				 = true,
	turninplacespeedlimit 		 = 10,
	turnInPlaceAngleLimit		 = 45,
	turnrate 				 	 = 750,
	--------------
	--------------

	sfxtypes                     = { 
		pieceExplosionGenerators = { 
			"deathceg3", 
			"deathceg4", 
		}, 

		explosiongenerators      = {
			"custom:factorysparks",
			"custom:emptydirt",
			"custom:blacksmoke",
		},
	},
	sounds                       = {
		underattack              = "units_under_attack",
		ok                       = {
			"ack",
		},
		select                   = {
			"unitselect",
		},
	},
	weapons                      = {
		[1]                      = {
			def                  = "lighttankweapon",
			onlyTargetCategory   = "GROUND BUILDING SHIP",
		},
	},
	customParams                 = {
		unittype				 = "mobile",
		unitrole				 = "Raider",
		canbetransported 		 = "true",
		needed_cover             = 1,
		death_sounds             = "generic",
		nofriendlyfire	         = "1",
		normaltex               = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "Neutral",
		decloakradiushalved		 = true,
	},
}

	weaponDefs                 = {
	lighttankweapon              = {
		
		AreaOfEffect             = 1,
		avoidFeature             = false,
		avoidFriendly            = false,
		collideFeature           = false,
		collideFriendly          = false,
		coreThickness            = 0.3,
		duration                 = 0.1,
		energypershot            = 0,
		explosionGenerator       = "custom:genericshellexplosion-small",
		fallOffRate              = 0,
		fireStarter              = 50,
		impulseFactor            = 0,
		interceptedByShieldType  = 4,
		
		minintensity             = "1",
		name                     = "Laser",
		range                    = 450,
		reloadtime               = 1,
		WeaponType               = "LaserCannon",
		rgbColor                 = "0.5 0.8 1",
		rgbColor2                = "1 1 1",
		soundTrigger             = true,
		soundstart               = "heavycannonGD",
		texture1                 = "shot",
		texture2                 = "empty",
		thickness                = 6,
		tolerance                = 1000,
		turret                   = true,
		weaponVelocity           = 2000,
		customparams             = {

		}, 
		damage                   = {
			default              = 45,
		},
	},
}
