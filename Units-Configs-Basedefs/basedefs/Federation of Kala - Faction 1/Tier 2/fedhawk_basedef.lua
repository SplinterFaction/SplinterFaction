unitDef                    = {
	acceleration                 = 0.1,
	airStrafe                    = false,
	brakeRate                    = 0.1,
	buildCostEnergy              = 18900,
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
	acceleration        = 0.45,   -- was 0.4
	maxAcc              = 1.35,   -- was 1.0  (biggest “snappy” lever)

	turnRadius          = 70,     -- was 80   (starts committing to turns sooner)

	wingDrag            = 0.062,  -- was 0.06 (tiny bump to keep it from gliding through turns)
	wingAngle           = 0.075,  -- was 0.07 (slightly more lift/authority)

	crashDrag           = 0.005,

	maxBank             = 0.75,   -- was 0.7  (tighter circle)
	maxPitch            = 0.60,   -- was 0.55

	maxAileron          = 0.016,  -- was 0.012 (faster roll-in to bank)
	maxElevator         = 0.014,  -- was 0.012
	maxRudder           = 0.0030, -- was 0.002 (more “bite” without getting weird)

	verticalSpeed       = 3.8,    -- was 3.5

	useSmoothMesh		= true,

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	
	canGuard                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = true,
	category                     = "AIR",
	collide                      = false,
	cruiseAlt                    = 200,
	description                  = [[Interceptor]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = "smallExplosionGenericRed",
	footprintX                   = 4,
	footprintZ                   = 4,
	floater                      = true,
	hoverAttack                  = false,
	iconType                     = "airassaultt2",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	canLoopbackAttack            = true,
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
	sightDistance                = 720,
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
			def                  = "missile",
			badTargetCategory    = "GROUND BUILDING",
			onlyTargetCategory	 = "AIR GROUND BUILDING SHIP",
			mainDir = "0 0 1",
			maxAngleDif = 200,
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
		unitrole				 = "Strike Fighter",
		buildmenucategory        = "Skirmish",
		death_sounds             = "generic",
		nofriendlyfire           = "1",
		RequireTech              = tech,
		nofriendlyfire	         = "1",
		supply_cost              = 1,
		normaltex                = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "Federation of Kala",
		unitguide = [[The Hawk is a versatile strike fighter armed with fast-tracking guided missiles capable of engaging both air and ground targets without switching modes. Its flexibility makes it useful in a wide range of situations, though it excels at neither role the way a dedicated interceptor or bomber would. Best deployed as a general-purpose fast response unit — redirect it wherever the enemy is least prepared to deal with it.]],
	},
}

weaponDefs                 = {
	missile           = {
		avoidFriendly            = false,
		avoidFeature             = false,
		collideFriendly          = false,
		collideFeature           = false,
		cegTag                   = "ehbotrocko-optimized",
		explosionGenerator       = "custom:genericshellexplosion-medium",
		energypershot            = 0,
		fireStarter              = 70,
		impulseFactor            = 0,
		interceptedByShieldType  = 4,
		model                    = "neutralmissilex1.s3o",
		name                     = "Rockets",
		range                    = 720,
		reloadtime               = 0.25,
		weaponType		         = "MissileLauncher",
		smokeTrail               = false,
		soundStart               = "scifi_sniper_rifle_A_single_08",
		soundHit                 = "explode5",
		tolerance                = 8000,
		turnrate                 = 30000,
		turret                   = true,
		tracks                   = true,
		startVelocity            = 400,
		weaponAcceleration       = 400,
		flightTime               = 2.5,
		weaponVelocity           = 3000,
		sprayangle               = 20000,
		customparams             = {
			expl_light_color	= purple, -- As a string, RGB
			expl_light_radius	= mediumExplosion, -- In Elmos
			expl_light_life		= mediumExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
			weaponguide = [[A guided missile capable of engaging both air and ground targets with reliable tracking and high maneuverability. Its flexibility makes it a consistent threat regardless of what it is pointed at.]],
		},
		damage                   = {
			default              = 60,
		},
	},
}
