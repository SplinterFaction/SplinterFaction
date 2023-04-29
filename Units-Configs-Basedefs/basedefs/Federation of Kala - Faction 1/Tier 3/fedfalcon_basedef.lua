unitDef                    = {
	acceleration                 = 0.1,
	airStrafe                    = false,
	brakeRate                    = 0.1,
	buildCostEnergy              = 36000,
	buildCostMetal               = 0,
	builder                      = false,
	buildTime                    = 2.5,
	canAttack                    = true,
	canFly                       = true,

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Fix Spring's Awful Defaults for Planes
-- Flight Characteristics Settings

	wingDrag            = 0.135,
	wingAngle           = 0.06315,
	-- frontToSpeed        = 0,    -- New Default
	speedToFront        = 0.063,  -- New Default
	-- crashDrag           = 0.005,
	maxBank             = 0.8,  -- New Default
	maxPitch            = 0.625, -- New Default
	turnRadius          = 150,  -- New Default
	verticalSpeed       = 3.0,
	maxAileron          = 0.0144, -- New Default
	maxElevator         = 0.01065,
	maxRudder           = 0.001, -- use this to control turn radius around Y axis - Best value for fighters is 0.01
	maxAcc          	= 1.2,    -- OG Default was 0.065

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
	cruiseAlt                    = 300,
	description                  = [[Bomber]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = "largeExplosionGenericRed",
	footprintX                   = 6,
	footprintZ                   = 6,
	floater                      = true,
	hoverAttack                  = false,
	iconType                     = "air_bomb",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	canLoopbackAttack            = false,
	maxDamage                    = 670,
	maxSlope                     = 90,
	maxVelocity                  = 20,
	maxWaterDepth                = 0,
	metalStorage                 = 0,
	name                         = humanName,
	objectName                   = objectName,
	script			             = script,
	repairable		             = false,
	selfDestructAs               = "largeExplosionGenericRed",
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
			def                  = "rockets",
			badTargetCategory     = "GROUND",
			onlyTargetCategory    = "GROUND BUILDING SHIP SUBMARINE",
			mainDir = "0 0 1",
			maxAngleDif = 90,
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
		unitrole				 = "Strategic Bomber",
		death_sounds             = "generic",
		nofriendlyfire           = "1",
		RequireTech              = tech,
		nofriendlyfire	         = "1",
		supply_cost              = 1,
		normaltex                = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "Federation of Kala",
		corpse                   = "energycore",
	},
}

weaponDefs                 = {
	bomb  	             = {
		AreaOfEffect             = 650,
		accuracy                 = 500,
		avoidFeature             = false,
		avoidFriendly            = false,
		collideFeature           = false,
		collideFriendly          = false,
		edgeeffectiveness		 = 1,
		energypershot            = 0,
		explosionGenerator       = "custom:NUKEDATBEWMSMALL",
		fireStarter              = 50,
		impulseFactor            = 0,
		interceptedByShieldType  = 4,
		mygravity                = 0.5,
		name                     = "Cluster Bomb",
		range                    = 1200,
		reloadtime               = 15,
		WeaponType               = "AircraftBomb",
		soundTrigger             = false,
		model                    = "missilebomb2.s3o",
		soundstart               = "bombdrop",
		soundHit                 = "Explosion Grenade_02",
		soundHitWet				 = "subhitbomb",
		customparams             = {
			expl_light_color	= red, -- As a string, RGB
			expl_light_radius	= hugeExplosion, -- In Elmos
			expl_light_life		= hugeExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.025, -- Use this sparingly
		},
		damage                   = {
			default              = 13000,
		},
	},

	rockets             = {
		AreaOfEffect             = 650,
		avoidFriendly            = false,
		avoidFeature             = false,
		collideFriendly          = false,
		collideFeature           = false,
		cegTag                   = "ehbotrocko-optimized",
		explosionGenerator       = "custom:NUKEDATBEWMSMALL",
		energypershot            = 0,
		fireStarter              = 70,
		impulseFactor            = 0,
		interceptedByShieldType  = 4,
		model                    = "missilebomb2.s3o",
		name                     = "Rockets",
		range                    = 500,
		reloadtime               = 15,
		weaponType		         = "MissileLauncher",
		smokeTrail               = false,
		soundStart               = "fedcrasher-maingun",
		soundHit                 = "explode5",
		startVelocity            = 250,
		tolerance                = 8000,
		turnrate                 = 30000,
		turret                   = true,
		tracks                   = true,
		weaponAcceleration       = 100,
		flightTime               = 2.5,
		weaponVelocity           = 800,
		customparams             = {
			expl_light_color	= purple, -- As a string, RGB
			expl_light_radius	= hugeExplosion, -- In Elmos
			expl_light_life		= hugeExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 13000,
		},
	},
}
