unitDef                    = {
	acceleration                 = 0.1,
	airStrafe                    = false,
	brakeRate                    = 0.1,
	buildCostEnergy              = 1000,
	buildCostMetal               = 0,
	builder                      = false,
	buildTime                    = 2.5,
	canAttack                    = true,
	canFly                       = true,

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Fix Spring's Awful Defaults for Planes
-- Flight Characteristics Settings

	wingDrag            = 0.07,
	wingAngle           = 0.08,
	frontToSpeed        = 0,    -- New Default
	speedToFront        = 0.001,  -- New Default
	crashDrag           = 0.005,
	maxBank             = 0.7,  -- New Default
	maxPitch            = 0.65, -- New Default
	turnRadius          = 20.0,  -- New Default
	verticalSpeed       = 3.0,
	maxAileron          = 0.025, -- New Default
	maxElevator         = 0.01,
	maxRudder           = 0.01, -- use this to control turn radius around Y axis - Best value for fighters is 0.01
	maxAcc          	= 1.2,    -- OG Default was 0.065

	useSmoothMesh		= true,

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	
	canGuard                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = true,
	category                     = "AIR",
	collide                      = false,
	cruiseAlt                    = 75,
	description                  = [[Can drop tiny Seismic Sensors via Stockpile]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = "smallExplosionGenericRed",
	footprintX                   = 2,
	footprintZ                   = 2,
	floater                      = true,
	hoverAttack                  = false,
	iconType                     = "airintelt1",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	canLoopbackAttack            = true,
	maxDamage                    = 670,
	maxSlope                     = 90,
	maxVelocity                  = 18,
	maxWaterDepth                = 0,
	metalStorage                 = 0,
	name                         = humanName,
	objectName                   = objectName,
	script			             = script,
	repairable		             = false,
	selfDestructAs               = "smallExplosionGenericRed",
	sightDistance                = 500,
	seismicDistance              = 850,
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

	-- This weapon is lolfake. Spring Sucks. Fite me.
	weapons                      = {
		[1]                      = {
			def                  = "SeismicSensor",
			onlyTargetCategory	 = "NOTHING",
		},
		--[[
		[2]                      = {
			def                  = "fakelaser",
			onlyTargetCategory	 = "NOTHING",
		},
		]]--
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
		unitrole				 = "Air Scout",
		death_sounds             = "generic",
		stockpileLimit           = 5,
		nofriendlyfire           = "1",
		RequireTech              = tech,
		nofriendlyfire	         = "1",
		supply_cost              = 1,
		normaltex                = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "Neutral",
		corpse                   = "energycore",
	},
}

weaponDefs                 = {
	SeismicSensor  	             = {
		commandfire              = true,
		AreaOfEffect             = 50,
		avoidFeature             = false,
		avoidFriendly            = false,
		collideFeature           = false,
		collideFriendly          = false,
		cylinderTargeting		 = 0,
		-- cegTag                   = "genericshellexplosion-small-sparks-burn",
		edgeeffectiveness		 = 1,
		energypershot            = 0,
		explosionGenerator       = "custom:genericshellexplosion-small-red",
		fallOffRate              = 1,
		fireStarter              = 50,
		impulseFactor            = 0,
		interceptedByShieldType  = 4,
		minintensity             = "1",
		name                     = "SeismicSensor",
		projectiles				 = 5,
		range                    = 800,
		reloadtime               = 5,
		WeaponType               = "Cannon",
		rgbColor                 = "1 0.5 0",
		rgbColor2                = "1 1 1",
		soundTrigger             = true,
		model                    = "sensortower.s3o",
		soundstart               = "other/dronespawner.wav",

		-----
		stockpile                = true,
		stockpiletime            = 30,
		metalpershot             = 0,
		energypershot            = 0,
		-----

		sprayangle				 = 5000,
		size					 = 0,
		--texture1                 = "shot",
		--texture2                 = "empty",
		thickness                = 15,
		tolerance                = 7500,
		turret                   = false,
		waterweapon              = true,
		weaponVelocity           = 500,
		customparams             = {
			expl_light_color	= red, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
			turretlauncherweapon= "true",
		},
		damage                   = {
			default              = 0,
		},
	},

	fakelaser                = {
		avoidFriendly          = false,
		avoidFeature 		   = false,
		collideFriendly        = false,
		collideFeature         = false,
		canAttackGround 	   = false,
		cegTag                 = "railgun",
		rgbColor               = "1 0 0",
		rgbColor2              = "1 1 1",
		explosionGenerator     = "custom:genericshellexplosion-small-sparks-burn",
		edgeEffectiveness	   = 1,
		energypershot          = 0,
		fallOffRate            = 0,
		duration			   = 0.1,
		impulseFactor          = 0,
		interceptedByShieldType  = 4,
		name                   = "E.M.G.",
		range                  = 0,
		reloadtime             = 0.2,
		--projectiles			   = 5,
		weaponType		       = "LaserCannon",
		soundStart             = "weapons/pointdefensefire.wav",
		texture1               = "shot",
		texture2               = "empty",
		coreThickness          = 0.25,
		thickness              = 3,
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
			default              = 0,
		},
	},
}
