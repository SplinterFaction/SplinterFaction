unitDef                    = {
	acceleration                 = 0.1,
	airStrafe                    = false,
	brakeRate                    = 0.1,
	buildCostEnergy              = 1800,
	buildCostMetal               = 0,
	builder                      = false,
	buildTime                    = 2.5,
	canAttack                    = true,
	canFly                       = true,

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Fix Spring's Awful Defaults for Planes
-- Flight Characteristics Settings

	maxVelocity         = 7,     -- Your defined top speed
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
	cruiseAlt                    = 150,
	description                  = [[Interceptor]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = "smallExplosionGenericRed",
	footprintX                   = 2,
	footprintZ                   = 2,
	floater                      = true,
	hoverAttack                  = false,
	iconType                     = "airaat1",
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
			def                  = "particlebeamcannon",
			onlyTargetCategory	 = "AIR",
			mainDir = "0 0 1",
			maxAngleDif = 200,
		},
		--[2]                      = {
		--	def                  = "particlebeamcannon",
		--	onlyTargetCategory	 = "AIR",
		--	mainDir = "0 0 1",
		--	maxAngleDif = 200,
		--},
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
		unitrole				 = "Interceptor",
		death_sounds             = "generic",
		nofriendlyfire           = "1",
		RequireTech              = tech,
		nofriendlyfire	         = "1",
		supply_cost              = 1,
		normaltex                = "unittextures/lego2skin_explorernormal.dds", 
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
		canAttackGround		     = false,
		explosionGenerator       = "custom:genericshellexplosion-small",
		coreThickness            = 0.5,
		duration                 = 0.2,
		energypershot            = 0,
		fallOffRate              = 0.01,
		fireStarter              = 50,
		interceptedByShieldType  = 4,
		soundstart               = "Sci Fi Assault Rifle 4",

		minintensity             = 1,
		impulseFactor            = 0,
		name                     = "Something with Flames",
		range                    = 800,
		reloadtime               = 1,
		WeaponType               = [[LaserCannon]],
		rgbColor                 = "0 0 1",
		rgbColor2                = "1 1 1",
		thickness                = 8,
		tolerance                = 1000,
		turret                   = true,
		texture1                 = "shot",
		texture2                 = "empty",
		weaponVelocity           = 3000,
		sprayangle				 = 75,
		customparams             = {
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
			weaponguide = [[A dedicated anti-air particle beam that delivers a devastating hit to any aircraft it connects with. Fast and hard-hitting, it makes short work of anything that ventures into range.]],
		},
		damage                   = {
			default              = 80,
		},
	},
}
