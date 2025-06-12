unitDef                    = {

	--mobileunit 
	transportbyenemy             = false;
	--**
	buildCostEnergy              = 0,
	buildCostMetal               = 840,
	builder                      = false,
	buildTime                    = 5,
	buildpic					 = [[fedavalanche.png]],
	canAttack                    = true,
	fireState                    = 0,
	canGuard                     = true,
	canHover                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = "1",
	category                     = "GROUND",
	description                  = [[Direct Fire Support]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = explodeAs,
	footprintX                   = 3,
	footprintZ                   = 3,
	highTrajectory		   		 = 2,
	iconType                     = "botartilleryt2",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	leaveTracks                  = false,
	maxDamage                    = 75,
	maxSlope                     = 90,
	maxVelocity                  = 1.4,
	maxReverseVelocity           = 1,
	maxWaterDepth                = 10,
	metalStorage                 = 0,
	movementClass                = "WALKERTANK3",
	name                         = humanName,
	noChaseCategory              = "VTOL",
	objectName                   = objectName,
	script			             = script,
	radarDistance                = 0,
	repairable		             = false,
	selfDestructAs               = explodeAs,
	side                         = "CORE",
	sightDistance                = 650,
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
	turnrate 				 	 = 500,
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
			def                  = "plasmacannon",
--			mainDir = "0 0 1", -- x:0 y:0 z:1 => that's forward!
--			maxAngleDif = 70,
			badTargetCategory     = "GROUND",
			onlyTargetCategory    = "GROUND BUILDING SHIP",
		},
		[2]                      = {
			def                  = "missile",
			--			mainDir = "0 0 1", -- x:0 y:0 z:1 => that's forward!
			--			maxAngleDif = 70,
			badTargetCategory     = "GROUND",
			onlyTargetCategory    = "GROUND BUILDING SHIP",
		},
	},
	customParams                 = {
		unittype				  = "mobile",
		unitrole				 = "Artillery - Tech 2",
		canbetransported 		 = "true",
		stockpileLimit           = 5,
		needed_cover             = 1,
		death_sounds             = "generic",
		RequireTech              = tech,
		nofriendlyfire	         = true,
		supply_cost              = 1,
		normaltex               = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "Federation of Kala",
		corpse                   = "energycore",
	},
}

weaponDefs                 = {
	plasmacannon                	= {
		commandfire            = true,
		AreaOfEffect           = 50,
		avoidFriendly          = false,
		avoidFeature 		   = false,
		collideFriendly        = false,
		collideFeature         = false,
		--cegTag			   = "thudshot",
		burst				   = 8,
		burstrate			   = 0.1,
		edgeEffectiveness	   = 0.1,
		explosionGenerator     = "custom:genericshellexplosion-small",
		energypershot          = 0,
		-- duration			   = 0.25,
		impulseFactor          = 0,
		interceptedByShieldType  = 4,
		name                   = "Plasma Cannon",
		--noExplode			   = true,
		range                  = 1300,
		reloadtime             = 35,
		-----
		stockpile                = true,
		stockpiletime            = 70,
		metalpershot             = 0,
		energypershot            = 0,
		-----
		trajectoryHeight	   = 2,
		size				   = 4,
		weaponType		       = "Cannon",
		soundStart             = "scifi_pistol_B_single_01-8roundburst",
		soundHit	           = "mediumcannonhit",
		soundTrigger           = true,
		sprayAngle             = 750,
		tolerance              = 10000,
		turret                 = true,
		weaponTimer            = 1,
		weaponVelocity         = 450,
		customparams             = {
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 440,
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

		model                    = "neutralmissilex1.s3o",
		name                     = "Rocket",
		range                    = 1300,
		reloadtime               = 12,
		weaponType		         = "MissileLauncher",


		smokeTrail               = false,
		soundHit                 = "explode_large",
		soundStart               = "missile_launch1",

		tracks                   = false,
		turnrate                 = 30000,
		turret                   = true,

		weaponAcceleration       = 400,
		weaponTimer              = 1,
		weaponType               = "StarburstLauncher",
		weaponVelocity           = 400,
		customparams             = {
			expl_light_color	= red, -- As a string, RGB
			expl_light_radius	= mediumExplosion, -- In Elmos
			expl_light_life		= mediumExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 600,
		},
	},
}
