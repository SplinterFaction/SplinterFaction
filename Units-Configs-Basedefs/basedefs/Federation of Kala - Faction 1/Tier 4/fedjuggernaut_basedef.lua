unitDef                    = {

	--mobileunit 
	transportbyenemy             = false;
	--**

	buildCostEnergy              = 0,
	buildCostMetal               = 62000,
	builder                      = false,
	buildTime                    = 5,
	buildpic					 = [[fedjuggernaut.png]],
	canAttack                    = true,
	
	canGuard                     = true,
	canHover                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = "1",
	category                     = "GROUND MASSIVE",
	description                  = [[Heavy Assault Mech]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = explodeAs,
	footprintX                   = 12,
	footprintZ                   = 12,
	highTrajectory		   		 = 2,
	iconType                     = "botassaultt4",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	leaveTracks                  = false,
	maxDamage                    = 75,
	maxSlope                     = 90,
	maxVelocity                  = 1.2,
	maxReverseVelocity           = 1,
	maxWaterDepth                = 10,
	metalStorage                 = 0,
	movementClass                = "WALKERTANK12",
	name                         = humanName,
	noChaseCategory              = "VTOL",
	objectName                   = objectName,
	script			             = script,
	radarDistance                = 0,
	repairable		             = false,
	selfDestructAs               = explodeAs,
	side                         = "CORE",
	sightDistance                = 1200,
	smoothAnim                   = true,
	stealth			             = true,
	seismicSignature             = 1,
	unitname                     = unitName,
	upright                      = true,
	--usePieceCollisionVolumes	 = true,
	workerTime                   = 0,
	--------------
	-- Movement --
	--------------
	acceleration 				 = 2,
	brakeRate                    = 0.1,
	turninplace 				 = true,
	turninplacespeedlimit 		 = 10,
	turnInPlaceAngleLimit		 = 45,
	turnrate 				 	 = 350,
	--------------
	--------------

	sfxtypes                     = {
		explosiongenerators      = {
			"custom:gdhcannon",
			"custom:emptydirt",
			"custom:blacksmoke",
			"custom:airfactoryhtrail",
		},
		pieceExplosionGenerators = {
			"deathceg3",
			"deathceg4",
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
			--mainDir = "0 0 1", -- x:0 y:0 z:1 => that's forward!
			--maxAngleDif = 180,
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "SHIP GROUND BUILDING",
		},
		[2]                      = {
			def                  = "plasmacannon",
			--mainDir = "0 0 1", -- x:0 y:0 z:1 => that's forward!
			--maxAngleDif = 180,
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "SHIP GROUND BUILDING",
		},
		[3]                      = {
			def                  = "plasmacannon",
			--mainDir = "0 0 1", -- x:0 y:0 z:1 => that's forward!
			--maxAngleDif = 180,
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "SHIP GROUND BUILDING",
		},
		[4]                      = {
			def                  = "clusterrockets",
			--mainDir = "0 0 1", -- x:0 y:0 z:1 => that's forward!
			--maxAngleDif = 180,
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "SHIP GROUND BUILDING",
		},
		[5]                      = {
			def                  = "clusterrockets",
			--mainDir = "0 0 1", -- x:0 y:0 z:1 => that's forward!
			--maxAngleDif = 180,
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "SHIP GROUND BUILDING",
		},
		[6]                      = {
			def                  = "missile",
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "SHIP GROUND BUILDING",
		},
	},
	customParams                 = {
		unittype				 = "mobile",
		unitrole				 = "Main Battle Tank - Tech 3",
		canbetransported 		 = "true",
		needed_cover             = 1,
		death_sounds             = "generic",
		RequireTech              = tech,
		nofriendlyfire	         = true,
		supply_cost              = 1,
		normaltex               = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "Federation of Kala",
		
	},
}

weaponDefs                 = {
	particlebeamcannon                 = {

		accuracy                 = 0,
		AreaOfEffect             = 10,
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
		soundstart               = "particlebeam1",

		minintensity             = 1,
		impulseFactor            = 0,
		name                     = "Particle Cannon",
		range                    = 1000,
		reloadtime               = 0.5,
		WeaponType               = [[LaserCannon]],
		rgbColor                 = "1 0.5 0",
		rgbColor2                = "1 1 1",
		thickness                = 8,
		tolerance                = 1000,
		turret                   = true,
		texture1                 = "shot",
		texture2                 = "empty",
		weaponVelocity           = 1000,
		sprayangle				 = 500,
		customparams             = {
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 400,
		},
	},
	plasmacannon                	= {
		areaofeffect		   = 25,
		avoidFriendly          = false,
		avoidFeature 		   = false,
		collideFriendly        = false,
		collideFeature         = false,
		--cegTag			   = "thudshot",
		--burst				   = burst,
		--burstrate			   = 0.1,
		edgeEffectiveness	   = 0,
		explosionGenerator     = "custom:genericshellexplosion-medium",
		energypershot          = 0,
		--duration			   = 0.25,
		highTrajectory		   = 2,
		impulseFactor          = 0,
		interceptedByShieldType  = 4,
		name                   = "Plasma Cannon",
		--noExplode			   = true,
		range                  = 1000,
		reloadtime             = 3,
		size					 = 8,
		--projectiles			   = projectiles,
		weaponType		       = "Cannon",
		soundStart             = "plasmacannon1",
		soundHit	           = "mediumcannonhit",
		soundTrigger           = true,
		--sprayAngle             = 1000,
		tolerance              = 2000,
		turret                 = true,
		weaponTimer            = 1,
		weaponVelocity         = 1200,
		customparams             = {
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= mediumExplosion, -- In Elmos
			expl_light_life		= mediumExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 1670,
		},
	},
	clusterrockets             = {
		AreaOfEffect             = 20,
		avoidFriendly            = false,
		avoidFeature             = false,
		collideFriendly          = false,
		collideFeature           = false,
		cegTag                   = "amphibrocktrail-optimized",
		explosionGenerator       = "custom:genericshellexplosion-small",
		-- burst 					 = 16,
		-- burstrate 				 = 0.25,
		energypershot            = 0,
		fireStarter              = 70,
		tracks                   = true,
		impulseFactor            = 0,
		interceptedByShieldType  = 4,
		model                    = "neutralmissilex2.s3o",
		name                     = "Rockets",
		range                    = 1000,
		reloadtime               = 0.25,
		weaponType		         = "MissileLauncher",
		smokeTrail               = false,
		soundStart               = "sabotlaunch",
		soundHit                 = "explode5",
		soundTrigger             = true,
		startVelocity            = 300,
		tolerance                = 2000,
		turnrate                 = 2500,
		turret                   = true,
		trajectoryHeight		 = 1.5,
		weaponAcceleration       = 300,
		flightTime               = 10,
		weaponVelocity           = 300,
		sprayangle				 = 5000,
		customparams             = {
			expl_light_color	= red, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 120,
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
		range                    = 1000,
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
}
