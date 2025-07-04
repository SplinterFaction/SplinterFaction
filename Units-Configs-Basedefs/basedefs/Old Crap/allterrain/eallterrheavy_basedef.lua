unitDef                    = {

	acceleration                 = 1,
	brakeRate                    = 1,
	buildCostEnergy              = 0,
	buildCostMetal               = 64,
	builder                      = false,
	buildTime                    = 5,
	buildpic					 = "eallterrheavy.png",
	canAttack                    = true,
	
	canGuard                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = "1",
	category                     = "ARMORED NOTAIR SKIRMISHER",

	-- Cloaking

	cancloak		             = true,
	cloakCost		             = 0,
	cloakCostMoving	             = 0,
	minCloakDistance             = 70,
	decloakOnFire	             = true,
	decloakSpherical             = true,
	initCloaked		             = false,
	
	-- End Cloaking

	description                  = [[Main Battle Tank]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = "largeExplosionGenericGreen",
	firestandorders              = "1",
	footprintX                   = 2,
	footprintZ                   = 2,
	iconType                     = "td_arm_all",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	leaveTracks                  = false,
	maxDamage                    = 545,
	maxVelocity                  = 2.8,
	turninplacespeedlimit        = 2.8,
	maxReverseVelocity           = 1,
	maxWaterDepth                = 10,
	metalStorage                 = 0,
	movementClass                = "ALLTERRTANK2",
	name                         = humanName,
	noChaseCategory              = "VTOL",
	objectName                   = objectName,
	script	                     = script,
	radarDistance                = 0,
	repairable		             = false,
	selfDestructAs               = "largeExplosionGenericGreen",
	shootme                      = "1",
	sightDistance                = 700,
	smoothAnim                   = true,
	stealth			             = true,
	seismicSignature             = 2,
	transportbyenemy             = false;
	turnInPlace                  = true,
	turnRate                     = 5000,
	unitname                     = unitName,
	unitnumber                   = "110",
	upright                      = false,
	workerTime                   = 0,
	sfxtypes                     = { 
		pieceExplosionGenerators = { 
			"deathceg3", 
			"deathceg4", 
		}, 

		explosiongenerators      = {
			"custom:gdhcannon",
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
			def                  = "heavytankweapon",
			badTargetCategory    = "BUILDING WALL",
		},
	},
	customParams                 = {
		unittype				  = "mobile",
		isupgraded           	 = isUpgraded,
		canbetransported 		 = "true",
		needed_cover             = 3,
		death_sounds             = "generic",
		RequireTech              = tech,
		armortype                = armortype,
		nofriendlyfire	         = "1",
		supply_cost              = supply,
		normaltex               = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "ateran",
		
		decloakradiushalved		 = true,
	},
}

weaponDefs                 = {
	heavytankweapon              = {
		
		AreaOfEffect             = 1,
		avoidFriendly            = false,
		avoidFeature             = false,
		collideFriendly          = false,
		collideFeature           = false,
		beamTime                 = 0.1,
		
		coreThickness            = 0.5,
		--	cegTag               = "mediumcannonweapon3",
		duration                 = 0.1,
		energypershot            = 0,
		explosionGenerator       = "custom:genericshellexplosion-medium-green",
		fallOffRate              = 0,
		fireStarter              = 50,
		impulseFactor            = 0,
		interceptedByShieldType  = 4,
		
		minintensity             = "1",
		name                     = "Laser",
		range                    = 700,
		reloadtime               = 1,
		WeaponType               = "LaserCannon",
		rgbColor                 = "0 1 0",
		rgbColor2                = "1 1 1",
		soundTrigger             = true,
		soundstart               = "weapons/allterrheavyshot.wav",
		soundHit                 = "explosions/mediumcannonhit.wav",
		texture1                 = "shot",
		texture2                 = "empty",
		thickness                = 9,
		tolerance                = 1000,
		turret                   = true,
		weaponVelocity           = 1500,
		customparams             = {
			isupgraded           	 = isUpgraded,
			damagetype		     = "antilightarmored",  
		}, 
		damage                   = {
			default              = 125,
		},
	},
}
