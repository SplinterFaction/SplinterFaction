unitDef                    = {
	acceleration                 = 0.1,
	airStrafe                    = false,
	brakeRate                    = 0.1,
	buildCostEnergy              = 2160,
	buildCostMetal               = 0,
	builder                      = false,
	buildTime                    = 2.5,
	canAttack                    = true,
	canFly                       = true,

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Fix Spring's Awful Defaults for Planes
-- Flight Characteristics Settings

	maxVelocity        = 6,
	acceleration       = 0.25,
	maxAcc             = 1.2,

	turnRadius         = 120,

	wingDrag           = 0.07,
	wingAngle          = 0.07,

	crashDrag          = 0.005,

	maxBank            = 0.65,
	maxPitch           = 0.4,

	verticalSpeed      = 2.5,

	maxAileron         = 0.014,
	maxElevator        = 0.010,
	maxRudder          = 0.0045,

	useSmoothMesh		= true,

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	
	canGuard                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = true,
	category                     = "AIR",
	nochasecategory              = "AIR",
	collide                      = false,
	cruiseAlt                    = 100,
	description                  = [[Bomber]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = "smallExplosionGenericRed",
	footprintX                   = 3,
	footprintZ                   = 3,
	floater                      = true,
	hoverAttack                  = false,
	iconType                     = "airbombert1",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	canLoopbackAttack            = false,
	maxDamage                    = 670,
	maxSlope                     = 90,
	maxWaterDepth                = 0,
	metalStorage                 = 0,
	name                         = humanName,
	objectName                   = objectName,
	script			             = script,
	repairable		             = false,
	selfDestructAs               = "smallExplosionGenericRed",
	side                         = "CORE",
	sightDistance                = 800,
	smoothAnim                   = true,
	stealth                      = false,
	transportbyenemy             = false;
	turnRate                     = 5,
	unitname                     = unitName,
	upright						 = true,
	workerTime                   = 0,
	sfxtypes                     = { 
		pieceExplosionGenerators = { 
			"deathceg3", 
			"deathceg4", 
		}, 

		explosiongenerators      = {
			"custom:jetstrail",
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
			def                  = "air2groundmissile2",
			badTargetCategory     = "GROUND",
			onlyTargetCategory    = "GROUND BUILDING SHIP SUBMARINE",
			mainDir = "0 -1 1",
			maxAngleDif = 100,
		},
		[2]                      = {
			def                  = "machinegun",
			onlyTargetCategory	 = "AIR",
			mainDir = "0 0 -1",
			maxAngleDif = 100,
		},
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
	},


	customParams                 = {
		unittype				 = "air",
		unitrole				 = "Assault Bomber",
		buildmenucategory        = "Support",
		death_sounds             = "generic",
		attacksafetydistance     = "300",
		nofriendlyfire           = "1",
		RequireTech              = tech,
		nofriendlyfire	         = "1",
		supply_cost              = 1,
		normaltex                = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "Federation of Kala",
		unitguide = [[The Crow is a heavy-payload bomber that delivers clusters of explosive submunitions across a broad area, making it devastating against grouped units and unprotected structures alike. A rear-facing machinegun provides minimal self-defense against pursuing interceptors, but the Crow should never be flying without an escort. Its long reload demands good timing — commit it to a target worth the wait.]],
	},
}

weaponDefs                 = {
	machinegun                = {
		accuracy               = 50,
		avoidFriendly          = false,
		avoidFeature 		   = false,
		collideFriendly        = false,
		collideFeature         = false,
		canattackground		   = false,
		-- cegTag                 = "railgun",
		rgbColor               = "1 0.5 0",
		rgbColor2              = "1 1 1",
		explosionGenerator     = "custom:genericshellexplosion-small",
		edgeEffectiveness	   = 1,
		energypershot          = 0,
		fallOffRate            = 0,
		duration			   = 0.025,
		impulseFactor          = 0,
		interceptedByShieldType  = 4,
		name                   = "MachineGun",
		range                  = 800,
		reloadtime             = 0.2,
		--projectiles			   = 5,
		weaponType		       = "LaserCannon",
		soundStart             = "Shotgun Shot 5",
		texture1               = "shot",
		texture2               = "empty",
		coreThickness          = 0.5,
		thickness              = 5,
		tolerance              = 10000,
		turret                 = true,
		weaponTimer            = 1,
		weaponVelocity         = 6000,
		customparams             = {
			expl_light_color	= yellow, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 5,
		},
	},

	bomb  	             = {
		AreaOfEffect             = 250,
		accuracy                 = 500,
		avoidFeature             = false,
		avoidFriendly            = false,
		collideFeature           = false,
		collideFriendly          = false,
		burst                    = 10,
		burstrate                = 0.05,
		edgeeffectiveness		 = 0.5,
		energypershot            = 0,
		cegTag                   = "bombertrail-optimized",
		explosionGenerator       = "custom:genericshellexplosion-bomb",
		fireStarter              = 50,
		impulseFactor            = 0,
		interceptedByShieldType  = 4,
		mygravity                = 1,
		name                     = "Cluster Bomb",
		range                    = 1200,
		reloadtime               = 15,
		WeaponType               = "AircraftBomb",
		soundTrigger             = false,
		model                    = "neutralmissilex1.s3o",
		soundstart               = "bombdrop",
		soundHit                 = "Explosion Grenade_02",
		soundHitWet				 = "subhitbomb",
		sprayangle				 = 10000,
		turret                   = true,
		tolerance                = 5000,
		weaponvelocity           = 100,
		customparams             = {
			expl_light_color	= red, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= mediumExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.025, -- Use this sparingly
		},
		damage                   = {
			default              = 110,
		},
	},

	air2groundmissile               = {
		AreaOfEffect             = 250,
		accuracy                 = 500,
		avoidFriendly            = false,
		avoidFeature             = false,
		collideFriendly          = false,
		collideFeature           = false,
		--cegTag                   = "emissiletanktrail-optimized",

		cylinderTargeting        = 100,
		burst                    = 10,
		burstrate                = 0.05,
		edgeeffectiveness		 = 0.5,

		explosionGenerator       = "custom:genericshellexplosion-bomb",
		energypershot            = 0,
		fireStarter              = 70,
		impulseFactor            = 0,
		interceptedByShieldType  = 4,
		model                    = "neutralmissilex1.s3o",
		name                     = "High Explosive Bomb",
		range                    = 800,
		reloadtime               = 15,
		weaponType		         = "MissileLauncher",
		smokeTrail               = false,
		soundstart               = "bombdrop",
		soundHit                 = "Explosion Grenade_02",
		soundHitWet				 = "subhitbomb",
		sprayangle				 = 2000,
		tolerance                = 100,
		turnrate                 = 10,
		turret                   = true,
		tracks                   = false,
		startVelocity            = 150,
		weaponAcceleration       = -50,
		flightTime               = 10,
		weaponVelocity           = 0,

		customparams             = {
			expl_light_color	= red, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= mediumExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.025, -- Use this sparingly
		},
		damage                   = {
			default              = 110,
		},
	},

	air2groundmissile2              = {
		AreaOfEffect             = 250,
		accuracy                 = 500,
		avoidFriendly            = false,
		avoidFeature             = false,
		collideFriendly          = false,
		collideFeature           = false,
		--cegTag                   = "emissiletanktrail-optimized",

		cylinderTargeting        = 100,
		projectiles              = 10,
		edgeeffectiveness		 = 0.5,

		explosionGenerator       = "custom:genericshellexplosion-bomb",
		energypershot            = 0,
		fireStarter              = 70,
		impulseFactor            = 0,
		interceptedByShieldType  = 4,
		model                    = "neutralmissilex1.s3o",
		name                     = "High Explosive Bomb",
		range                    = 300,
		reloadtime               = 15,
		weaponType		         = "MissileLauncher",
		smokeTrail               = false,
		soundstart               = "bombdrop",
		soundHit                 = "Explosion Grenade_02",
		soundHitWet				 = "subhitbomb",
		sprayangle				 = 2000,
		tolerance                = 100,
		turret                   = true,
		weaponVelocity           = 175,
		startVelocity            = 175,

		customparams             = {
			expl_light_color	= red, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= mediumExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.025, -- Use this sparingly
			weaponguide = [[Disperses multiple explosive submunitions over a broad area on detonation. Devastating against grouped units or unprotected structures caught in the spread.]],
		},
		damage                   = {
			default              = 55,
		},
	}
}
