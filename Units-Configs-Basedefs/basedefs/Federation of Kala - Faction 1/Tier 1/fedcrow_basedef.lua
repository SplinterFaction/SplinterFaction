unitDef                    = {
	acceleration                 = 0.1,
	airStrafe                    = false,
	brakeRate                    = 0.1,
	buildCostEnergy              = 10800,
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
	maxRudder           = 0.00615, -- use this to control turn radius around Y axis - Best value for fighters is 0.01
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
	cruiseAlt                    = 250,
	description                  = [[Bomber]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = "smallExplosionGenericRed",
	footprintX                   = 2,
	footprintZ                   = 2,
	floater                      = true,
	hoverAttack                  = false,
	iconType                     = "air_bomb",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	canLoopbackAttack            = false,
	maxDamage                    = 670,
	maxSlope                     = 90,
	maxVelocity                  = 12,
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
			def                  = "bomb",
			badTargetCategory     = "GROUND",
			onlyTargetCategory    = "GROUND BUILDING SHIP SUBMARINE",
			mainDir = "0 -1 0",
			maxAngleDif = 200,
		},
		[2]                      = {
			def                  = "machinegun",
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
		factionname	             = "Federation of Kala",
		corpse                   = "energycore",
	},
}

weaponDefs                 = {
	machinegun                = {
		accuracy               = 5000,
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
			default              = 0.5,
		},
	},
	bomb  	             = {
		AreaOfEffect             = 250,
		accuracy                 = 500,
		avoidFeature             = false,
		avoidFriendly            = false,
		collideFeature           = false,
		collideFriendly          = false,
		burst                    = 4,
		burstrate                = 0.25,
		edgeeffectiveness		 = 0.5,
		energypershot            = 0,
		explosionGenerator       = "custom:genericshellexplosion-bomb",
		fireStarter              = 50,
		impulseFactor            = 0,
		interceptedByShieldType  = 4,
		mygravity                = 0.8,
		name                     = "Cluster Bomb",
		range                    = 1200,
		reloadtime               = 15,
		WeaponType               = "AircraftBomb",
		soundTrigger             = false,
		model                    = "neutralmissilex1.s3o",
		soundstart               = "bombdrop",
		soundHit                 = "Explosion Grenade_02",
		soundHitWet				 = "subhitbomb",
		sprayangle				 = 1000,
		customparams             = {
			expl_light_color	= red, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= mediumExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.025, -- Use this sparingly
		},
		damage                   = {
			default              = 275,
		},
	},
}
