unitDef                    = {
	buildCostEnergy              = 0,
	buildCostMetal               = 300,
	builder                      = false,
	buildTime                    = 5,
	buildpic					 = "fedcrusader.png",
	canAttack                    = true,
	canGuard                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = "1",
	category                     = "SHIP",
	description                  = [[Frigate]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = explodeAs,
	footprintX                   = 5,
	footprintZ                   = 5,
	iconType                     = "shipassaultt1",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	leaveTracks                  = false,
	maxDamage                    = 360,
	maxSlope                     = 60,
	maxVelocity                  = 3,
	maxWaterDepth                = 5000,
	minWaterDepth                = 25,
	metalStorage                 = 0,
	movementClass                = "SHIP5",
	name                         = humanName,
	noChaseCategory              = "AIR GROUND",
	objectName                   = objectName,
	script			             = script,
	radarDistance                = 0,
	repairable		             = false,
	selfDestructAs               = explodeAs,
	side                         = "CORE",
	sightDistance                = 600,
	waterline                    = 3,
	floater                      = true,
	stealth			             = true,
	seismicSignature             = 2,
	smoothAnim                   = true,
	transportbyenemy             = false;
	unitname                     = unitName,
	workerTime                   = 0,
	--------------
	-- Movement --
	--------------
	acceleration 				 = 0.05,
	brakeRate                    = 0.05,
	turninplace 				 = true,
--	turninplacespeedlimit 		 = 10,
	turnInPlaceAngleLimit		 = 90,
	turnrate 				 	 = 500,
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
			def                  = "particlebeamcannon",
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "SHIP GROUND BUILDING",
		},
		[2]                      = {
			def                  = "rockets",
			onlyTargetCategory    = "AIR",
		},
	},
	customParams                 = {
		unittype				 = "ship",
		unitrole				 = "Frigate",
		canbetransported 		 = "true",
		needed_cover             = 2,
		death_sounds             = "generic",
		RequireTech              = tech,
		nofriendlyfire	         = "1",
		supply_cost              = 1,
		normaltex               = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "Federation of Kala",
		corpse                   = "fedcrusader_dead",
	},
}

weaponDefs                 = {
	particlebeamcannon                 = {
		avoidFeature             = false,
		avoidFriendly            = false,
		collideFeature           = false,
		collideFriendly          = false,
		explosionGenerator       = "custom:burnblacksmall",
		coreThickness            = 0.1,
		duration                 = 0.8,
		energypershot            = 0,
		fallOffRate              = 0.1,
		fireStarter              = 50,
		interceptedByShieldType  = 4,
		soundstart               = "fedcrusader-particlecannon",

		minintensity             = 1,
		impulseFactor            = 0,
		name                     = "Particle Cannon",
		range                    = 700,
		reloadtime               = 0.3,
		WeaponType               = [[LaserCannon]],
		rgbColor                 = "1 0.5 0",
		rgbColor2                = "1 1 1",
		thickness                = 2,
		tolerance                = 1000,
		turret                   = true,
		texture1                 = "shot",
		texture2                 = "empty",
		weaponVelocity           = 1000,
		sprayangle				 = 50,
		customparams             = {
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 35,
		},
	},

	rockets             = {
		avoidFriendly            = false,
		avoidFeature             = false,
		collideFriendly          = false,
		collideFeature           = false,
		canAttackGround 		 = false,
		cegTag                   = "gunshiptrail-optimized-longlasting",
		explosionGenerator       = "custom:genericshellexplosion-small",
		energypershot            = 0,
		fireStarter              = 70,
		impulseFactor            = 0,
		interceptedByShieldType  = 4,
		model                    = "neutralmissilex1.s3o",
		name                     = "Rockets",
		range                    = 700,
		reloadtime               = 1,
		weaponType		         = "MissileLauncher",
		smokeTrail               = false,
		soundStart               = "sabotlaunch",
		soundHit                 = "explode5",
		-- stockpile                = true,
		-- stockpiletime            = 2,
		startVelocity            = 100,
		tolerance                = 8000,
		turnrate                 = 100000,
		dance                    = 150,
		turret                   = true,
		tracks                   = true,
		weaponAcceleration       = 2000,
		flightTime               = 1.5,
		weaponVelocity           = 2000,
		customparams             = {
			expl_light_color	= purple, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 50,
		},
	},
}
