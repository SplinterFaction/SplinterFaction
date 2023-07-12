unitDef                    = {
	buildCostEnergy              = 0,
	buildCostMetal               = 1800,
	builder                      = false,
	buildTime                    = 5,
	buildpic					 = "eallterrheavy.png",
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

	description                  = [[Main Battle Tank]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = "mediumExplosionGeneric",
	firestandorders              = "1",
	footprintX                   = 4,
	footprintZ                   = 4,
	iconType                     = "td_arm_all",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	leaveTracks                  = false,
	maxDamage                    = 545,
	maxReverseVelocity           = 1,
	maxWaterDepth                = 10,
	metalStorage                 = 0,
	movementClass                = "ALLTERRAINTANK4",
	name                         = humanName,
	objectName                   = objectName,
	script	                     = script,
	radarDistance                = 0,
	repairable		             = false,
	selfDestructAs               = "mediumExplosionGeneric",
	shootme                      = "1",
	sightDistance                = 900,
	smoothAnim                   = true,
	stealth			             = true,
	seismicSignature             = 2,
	transportbyenemy             = false;
	turnInPlace                  = true,
	unitname                     = unitName,
	unitnumber                   = "110",
	upright                      = false,
	workerTime                   = 0,
    --------------
	-- Movement --
	--------------
    acceleration 				 = 2,
	brakeRate                    = 0.1,
    maxVelocity                  = 1.5,
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
			"custom:gdhcannon",
			"custom:emptydirt",
			"custom:blacksmoke",
		},
	},
	sounds                       = {
		underattack              = "other/unitsunderattack1",
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
			onlyTargetCategory   = "GROUND BUILDING SHIP",
		},
	},
	customParams                 = {
		unittype				  = "mobile",
        unitrole                  = "Assault",
		canbetransported 		 = "true",
		needed_cover             = 3,
		death_sounds             = "generic",
		nofriendlyfire	         = "1",
		normaltex               = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "Neutral",
		decloakradiushalved		 = true,
	},
}

weaponDefs                 = {
	heavytankweapon              = {
		
		AreaOfEffect             = 50,
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
		range                    = 900,
		reloadtime               = 1.7,
		WeaponType               = "LaserCannon",
		rgbColor                 = "0 1 0",
		rgbColor2                = "1 1 1",
		soundTrigger             = true,
		soundstart               = "allterrheavyshot",
		soundHit                 = "mediumcannonhit",
		texture1                 = "shot",
		texture2                 = "empty",
		thickness                = 9,
		tolerance                = 1000,
		turret                   = true,
		weaponVelocity           = 1500,
		customparams             = {

		}, 
		damage                   = {
			default              = 340,
		},
	},
}
