unitDef                    = {
	acceleration                 = 0.1,
	airStrafe                    = false,
	brakeRate                    = 0.1,
	buildCostEnergy              = 144000,
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
	maxBank             = 0.2,  -- New Default
	maxPitch            = 0.625, -- New Default
	turnRadius          = 150,  -- New Default
	verticalSpeed       = 6.0,
	maxAileron          = 0.0144, -- New Default
	maxElevator         = 0.01065,
	maxRudder           = 0.009, -- use this to control turn radius around Y axis - Best value for fighters is 0.01
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
	cruiseAlt                    = 350,
	description                  = [[Bomber]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = "smallExplosionGenericRed",
	footprintX                   = 8,
	footprintZ                   = 8,
	floater                      = true,
	hoverAttack                  = false,
	iconType                     = "air_bomb",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	canLoopbackAttack            = false,
	maxDamage                    = 670,
	maxSlope                     = 90,
	maxVelocity                  = 4,
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
			"custom:electricity",
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
			onlyTargetCategory    = "GROUND BUILDING SHIP",
			mainDir = "0 0 1",
			maxAngleDif = 90,
		},
		[2]                      = {
			def                  = "lightningcannon",
			badTargetCategory     = "GROUND",
			onlyTargetCategory    = "AIR GROUND BUILDING SHIP",
			mainDir = "0 0 1",
			maxAngleDif = 180,
		},
		[3]                      = {
			def                  = "lightningcannon",
			badTargetCategory     = "GROUND",
			onlyTargetCategory    = "AIR GROUND BUILDING SHIP",
			mainDir = "0 1 0",
			maxAngleDif = 180,
		},
		[4]                      = {
			def                  = "lightningcannon",
			badTargetCategory     = "GROUND",
			onlyTargetCategory    = "AIR GROUND BUILDING SHIP",
			mainDir = "0 -1 0",
			maxAngleDif = 180,
		},
		[5]                      = {
			def                  = "lightningcannon",
			badTargetCategory     = "GROUND",
			onlyTargetCategory    = "AIR GROUND BUILDING SHIP",
			mainDir = "1 0 0",
			maxAngleDif = 180,
		},
		[6]                      = {
			def                  = "lightningcannon",
			badTargetCategory     = "GROUND",
			onlyTargetCategory    = "AIR GROUND BUILDING SHIP",
			mainDir = "-1 0 0",
			maxAngleDif = 180,
		},
		[7]                      = {
			def                  = "lightningcannon",
			badTargetCategory     = "GROUND",
			onlyTargetCategory    = "AIR GROUND BUILDING SHIP",
			mainDir = "0 0 -1",
			maxAngleDif = 180,
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
		unitrole				 = "Heavy Bomber",
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
		AreaOfEffect             = 350,
		avoidFeature             = false,
		avoidFriendly            = false,
		collideFeature           = false,
		collideFriendly          = false,
		burst                    = 3,
		burstrate                = 1,
		edgeeffectiveness		 = 1,
		energypershot            = 0,
		explosionGenerator       = "custom:genericshellexplosion-bomb-huge",
		fireStarter              = 50,
		impulseFactor            = 0,
		interceptedByShieldType  = 4,
		mygravity                = 2,
		name                     = "High Explosive Bomb",
		range                    = 740,
		reloadtime               = 15,
		WeaponType               = "AircraftBomb",
		soundTrigger             = true,
		model                    = "missilebomb2.s3o",
		soundstart               = "bombdrop",
		soundHit                 = "Explosion Fireworks_01",
		soundHitWet				 = "subhitbomb",
		sprayangle               = 2000,

		customparams             = {
			expl_light_color	= red, -- As a string, RGB
			expl_light_radius	= largeExplosion, -- In Elmos
			expl_light_life		= mediumExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly

			areadamage_ceg          = "napalm",
			areadamage_damageceg    = "blacksmokesmall",
			areadamage_time         = 5,
			areadamage_damage       = 35,
			areadamage_range        = 350,
			-- areadamage_reistance = ,
		},
		damage                   = {
			default              = 3600,
		},
	},

	lightningcannon   	             = {
		avoidFriendly            = false,
		avoidFeature             = false,
		collideFriendly          = false,
		collideFeature           = false,
		craterBoost              = 0,
		craterMult               = 0,
		burst                    = 20,
		burstrate                = 0.01,
		beamTTL					 = 1,
		duration                 = 1,
		explosionGenerator       = "custom:genericshellexplosion-electric-small",
		energypershot            = 0,
		edgeeffectiveness		 = 1,
		impulseBoost             = 0,
		impulseFactor            = 0,
		interceptedByShieldType  = 4,
		intensity                = 24,
		laserFlareSize           = 1,

		name			         = "Electrical Strike Cannon",
		noSelfDamage             = true,
		range                    = 740,
		reloadtime               = 1,
		WeaponType               = "LightningCannon",
		rgbColor                 = "1 0.5 1",
		rgbColor2                = "1 1 1",
		soundStart               = "lozlocust-electriccannon",
		soundtrigger             = true,

		texture1                 = "lightning",
		thickness                = 1.5,
		turret                   = true,
		weaponVelocity           = 400,
		customparams             = {
			expl_light_color	= purple, -- As a string, RGB
			expl_light_radius	= largeExplosion, -- In Elmos
			expl_light_life		= largeExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 3.5,
		},
	},
}
