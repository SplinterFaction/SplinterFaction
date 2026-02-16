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
	acceleration       = 0.25,     -- Slower takeoff and sluggish momentum
	maxAcc             = 0.7,      -- Slow to correct heading

	turnRadius         = 160,      -- Big wide turns — can't easily circle back

	wingDrag           = 0.07,     -- High drag to prevent glidey behavior
	wingAngle          = 0.07,     -- Balanced lift to keep it from stalling

	crashDrag          = 0.005,    -- Standard

	maxBank            = 0.45,     -- Shallow rolls; avoids sharp tilting
	maxPitch           = 0.4,      -- Sluggish pitch for slow climb/dive

	verticalSpeed      = 2.5,      -- Reduced climb rate

	maxAileron         = 0.008,    -- Slower roll
	maxElevator        = 0.008,    -- Slower pitch
	maxRudder          = 0.0015,   -- Barely turns without banking

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
	footprintX                   = 4,
	footprintZ                   = 4,
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
	turnRate                     = 1,
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
			def                  = "air2groundmissile",
			badTargetCategory    = "GROUND",
			onlyTargetCategory   = "GROUND BUILDING SHIP SUBMARINE",
			mainDir = "0 -1 1",
			maxAngleDif = 90,
		},
		[2]                      = {
			def                  = "laser",
			onlyTargetCategory	 = "AIR",
			mainDir = "0 0 -1",
			maxAngleDif = 135,
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
		death_sounds             = "generic",
		nofriendlyfire           = "1",
		RequireTech              = tech,
		nofriendlyfire	         = "1",
		supply_cost              = 1,
		normaltex                = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "Loz Alliance",
		
	},
}

weaponDefs                 = {
	laser                = {
		accuracy               = 5000,
		avoidFriendly          = false,
		avoidFeature 		   = false,
		collideFriendly        = false,
		collideFeature         = false,
		canAttackGround		   = false,
		cegTag                 = "railgun",
		rgbColor               = "1 0 0",
		rgbColor2              = "1 1 1",
		explosionGenerator     = "custom:genericshellexplosion-bomb",
		edgeEffectiveness	   = 1,
		energypershot          = 0,
		fallOffRate            = 0,
		duration			   = 0.1,
		impulseFactor          = 0,
		interceptedByShieldType  = 4,
		name                   = "High Velocity Anti-Air Cannon",
		range                  = 800,
		reloadtime             = 0.2,
		--projectiles			   = 5,
		weaponType		       = "LaserCannon",
		soundStart             = "Sci Fi Blaster 1",
		texture1               = "shot",
		texture2               = "empty",
		coreThickness          = 0.5,
		thickness              = 5,
		tolerance              = 10000,
		turret                 = true,
		weaponTimer            = 1,
		weaponVelocity         = 2000,
		customparams             = {
			expl_light_color	= red, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 0.5,
		}, 
	},

	bomb  	             = {
		AreaOfEffect             = 200,
		avoidFeature             = false,
		avoidFriendly            = false,
		collideFeature           = false,
		collideFriendly          = false,

		edgeeffectiveness		 = 1,
		energypershot            = 0,
		cegTag                   = "bombertrail-optimized",
		explosionGenerator       = "custom:genericshellexplosion-bomb",
		fireStarter              = 50,
		impulseFactor            = 0,
		interceptedByShieldType  = 4,
		mygravity                = 0.8,
		name                     = "High Explosive Bomb",
		range                    = 1200,
		reloadtime               = 15,
		WeaponType               = "AircraftBomb",
		soundTrigger             = true,
		turret                   = true,
		tolerance                = 5000,
		model                    = "neutralmissilex2.s3o",
		soundstart               = "bombdrop",
		soundHit                 = "Explosion Fireworks_01",
		soundHitWet				 = "subhitbomb",

		customparams             = {
			expl_light_color	= red, -- As a string, RGB
			expl_light_radius	= largeExplosion, -- In Elmos
			expl_light_life		= mediumExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly

			areadamage_ceg          = "napalm",
			areadamage_damageceg    = "blacksmokesmall",
			areadamage_time         = 5,
			areadamage_damage       = 100,
			areadamage_range        = 200,
			-- areadamage_reistance = ,
		},
		damage                   = {
			default              = 600,
		},
	},

	air2groundmissile               = {
		avoidFriendly            = false,
		avoidFeature             = false,
		collideFriendly          = false,
		collideFeature           = false,
		--cegTag                   = "emissiletanktrail-optimized",

		cylinderTargeting        = 100,

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
		soundHit                 = "Explosion Fireworks_01",
		soundHitWet				 = "subhitbomb",
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
			expl_light_radius	= largeExplosion, -- In Elmos
			expl_light_life		= mediumExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly

			areadamage_ceg          = "napalm",
			areadamage_damageceg    = "blacksmokesmall",
			areadamage_time         = 5,
			areadamage_damage       = 100,
			areadamage_range        = 200,
			-- areadamage_reistance = ,
		},
		damage                   = {
			default              = 600,
		},
	},
}
