unitDef                    = {
	buildCostEnergy              = 0,
	buildCostMetal               = 6500,
	builder                      = false,
	buildTime                    = 5,
	buildpic					 = "fedharbinger.png",
	canAttack                    = true,
	canGuard                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = "1",
	category                     = "SHIP",
	description                  = [[Battlecruiser]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = explodeAs,
	footprintX                   = 15,
	footprintZ                   = 15,
	iconType                     = "shipassaultt3",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	leaveTracks                  = false,
	maxDamage                    = 360,
	maxSlope                     = 60,
	maxVelocity                  = 2.5,
	maxWaterDepth                = 5000,
	minWaterDepth                = 25,
	metalStorage                 = 0,
	movementClass                = "SHIP15",
	name                         = humanName,
	noChaseCategory              = "AIR GROUND",
	objectName                   = objectName,
	script			             = script,
	radarDistance                = 0,
	repairable		             = false,
	selfDestructAs               = explodeAs,
	side                         = "CORE",
	sightDistance                = 500,
	waterline                    = 8,
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
	acceleration 				 = 0.015,
	brakeRate                    = 0.015,
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
		--[[
			float mainDir default: {0.0, 0.0, 1.0} i.e. forwards
				A vector representing the firing direction of this weapon if it has a limited firing arc. Used in conjunction with maxAngleDif (See Gamedev:WeaponMainDir).

			float maxAngleDif default: 360.0
				How wide this weapons limited firing arc is in degrees. Symmetrical about mainDir i.e. 180.0 is 90 degree freedom either way (See Gamedev:WeaponMainDir).

			Example:
			weapons = {
			  {
				def = "weapon1",
				mainDir = "0 0 1", -- x:0 y:0 z:1 => that's forward!
				maxAngleDif = 90, -- 90° from side to side, or 45° from centre to each direction
			  },
			}
		]]--
		[1]                      = {
			def                  = "mainplasmacannon",
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "SHIP BUILDING GROUND",
		},
		[2]                      = {
			def                  = "plasmacannon",
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "SHIP BUILDING GROUND",
		},
		[3]                      = {
			def                  = "plasmacannon",
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "SHIP BUILDING GROUND",
		},
		[4]                      = {
			def                  = "plasmacannon",
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "SHIP BUILDING GROUND",
		},
		[5]                      = {
			def                  = "plasmacannon",
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "SHIP BUILDING GROUND",
		},
		[6]                      = {
			def                  = "missile",
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "SHIP BUILDING GROUND",
		},
		[7]                      = {
			def                  = "particlebeamcannon",
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "SHIP BUILDING GROUND",
		},

	},
	customParams                 = {
		unittype				 = "ship",
		unitrole				 = "Battlecruiser",
		canbetransported 		 = "false",
		needed_cover             = 2,
		death_sounds             = "generic",
		RequireTech              = tech,
		nofriendlyfire	         = "1",
		supply_cost              = 1,
		normaltex               = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "Federation of Kala",
		corpse                   = "fedharbinger_dead",
	},
}

weaponDefs                 = {
	plasmacannon                	= {
		AreaOfEffect           = 40,
		avoidFriendly          = false,
		avoidFeature 		   = false,
		collideFriendly        = false,
		collideFeature         = false,
		--cegTag			   = "thudshot",
		burst				   = 8,
		burstrate			   = 0.25,
		edgeEffectiveness	   = 1,
		explosionGenerator     = "custom:genericshellexplosion-small",
		energypershot          = 0,
		-- duration			   = 0.25,
		impulseFactor          = 0,
		interceptedByShieldType  = 4,
		name                   = "Plasma Cannon",
		--noExplode			   = true,
		range                  = 1400,
		reloadtime             = 8,
		size				   = 5,
		weaponType		       = "Cannon",
		soundStart             = "fedconqueror-plasmacannon",
		soundHit	           = "mediumcannonhit",
		soundTrigger           = false,
		sprayAngle             = 100,
		tolerance              = 10000,
		turret                 = true,
		weaponTimer            = 1,
		weaponVelocity         = 600,
		customparams             = {
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 250,
		},
	},
	missile            = {
		avoidFriendly            = false,
		avoidFeature             = false,
		collideFriendly          = false,
		collideFeature           = false,
		cegTag                   = "emissiletanktrail-optimized",
		craterBoost              = 0,
		craterMult               = 0,
		explosionGenerator       = "custom:genericshellexplosion-medium",
		energypershot            = 0,
		fireStarter              = 100,
		flightTime               = 7.5,
		impulseBoost             = 0,
		impulseFactor            = 0,
		interceptedByShieldType  = 4,

		model                    = "neutralmissilex3.s3o",
		name                     = "Rocket",
		range                    = 1400,
		reloadtime               = 1,
		weaponType		         = "MissileLauncher",


		smokeTrail               = false,
		soundHit                 = "explode_large",
		soundStart               = "missile_launch1",

		tracks                   = true,
		turnrate                 = 30000,
		turret                   = true,

		weaponAcceleration       = 400,
		weaponTimer              = 1.5,
		weaponType               = "StarburstLauncher",
		weaponVelocity           = 400,
		customparams             = {
			expl_light_color	= red, -- As a string, RGB
			expl_light_radius	= mediumExplosion, -- In Elmos
			expl_light_life		= mediumExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 800,
		},
	},
	particlebeamcannon = {

		accuracy                 = 0,
		avoidFeature             = false,
		avoidFriendly            = false,
		collideFeature           = false,
		collideFriendly          = false,
		explosionGenerator       = "custom:burnblacksmall",
		coreThickness            = 0.1,
		duration                 = 0.4,
		energypershot            = 0,
		fallOffRate              = 0.1,
		fireStarter              = 50,
		interceptedByShieldType  = 4,
		soundstart               = "fedmenlo-maingun",

		minintensity             = 1,
		impulseFactor            = 0,
		name                     = "Something with Flames",
		range                    = 1400,
		reloadtime               = 0.1,
		WeaponType               = [[LaserCannon]],
		rgbColor                 = "1 0.5 0",
		rgbColor2                = "1 1 1",
		thickness                = 8,
		tolerance                = 1000,
		turret                   = true,
		texture1                 = "shot",
		texture2                 = "empty",
		weaponVelocity           = 1000,
		sprayangle				 = 100,
		customparams             = {
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 10,
		},
	},
	mainplasmacannon                	= {
		avoidFriendly          = false,
		avoidFeature 		   = false,
		collideFriendly        = false,
		collideFeature         = false,
		--cegTag			   = "thudshot",
		--burst				   = burst,
		--burstrate			   = 0.1,
		edgeEffectiveness	   = 0,
		explosionGenerator     = "custom:genericshellexplosion-small",
		energypershot          = 0,
		--duration			   = 0.25,
		highTrajectory		   = 2,
		impulseFactor          = 0,
		interceptedByShieldType  = 4,
		name                   = "Plasma Cannon",
		--noExplode			   = true,
		range                  = 1400,
		reloadtime             = 2.6,
		size					 = 8,
		--projectiles			   = projectiles,
		weaponType		       = "Cannon",
		soundHit                 = "42024_digifishmusic_Missile_Strike",
		soundStart               = "plasmacannon2",
		soundTrigger           = true,
		--sprayAngle             = 1000,
		tolerance              = 10000,
		turret                 = true,
		weaponTimer            = 1,
		weaponVelocity         = 800,
		customparams             = {
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= mediumExplosion, -- In Elmos
			expl_light_life		= mediumExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 230,
		},
	},
}
