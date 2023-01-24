unitDef                    = {
	buildCostEnergy              = 0,
	buildCostMetal               = 2000,
	builder                      = false,
	buildTime                    = 5,
	buildpic					 = "lozexecutioner.png",
	canAttack                    = true,
	canGuard                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = "1",
	category                     = "SHIP",
	description                  = [[Destroyer]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = explodeAs,
	footprintX                   = 7,
	footprintZ                   = 7,
	iconType                     = "mbt",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	leaveTracks                  = false,
	maxDamage                    = 360,
	maxSlope                     = 60,
	maxVelocity                  = 2,
	maxReverseVelocity           = 1,
	maxWaterDepth                = 5000,
	minWaterDepth                = 25,
	metalStorage                 = 0,
	movementClass                = "SHIP7",
	name                         = humanName,
	noChaseCategory              = "AIR GROUND",
	objectName                   = objectName,
	script			             = script,
	radarDistance                = 0,
	repairable		             = false,
	selfDestructAs               = explodeAs,
	side                         = "CORE",
	sightDistance                = 1350,
	sonarDistance                = 1350,
	waterline                    = 5,
	floater                      = true,
	stealth			             = true,
	seismicSignature             = 2,
	smoothAnim                   = true,
	transportbyenemy             = false;
	unitname                     = unitName,
	workerTime                   = 0,
	--------------
	-- Movement --
	--------------
	acceleration 				 = 2,
	brakeRate                    = 0.1,
	turninplace 				 = false,
	turninplacespeedlimit 		 = 10,
	turnInPlaceAngleLimit		 = 90,
	turnrate 				 	 = 300,
	--------------
	--------------
	sfxtypes                     = { 
		pieceExplosionGenerators = { 
			"deathceg3", 
			"deathceg4", 
		}, 

		explosiongenerators      = {
			"custom:gdhcannon",
			"custom:emptydirt",
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
		[1]                      = {
			def                  = "railgun",
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "SHIP GROUND BUILDING",
			mainDir = "-1 0 0",
			maxAngleDif = 180,
		},
		[2]                      = {
			def                  = "railgun",
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "SHIP GROUND BUILDING",
			mainDir = "-1 0 0",
			maxAngleDif = 180,
		},
		[3]                      = {
			def                  = "railgun",
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "SHIP GROUND BUILDING",
			mainDir = "1 0 0",
			maxAngleDif = 180,
		},
		[4]                      = {
			def                  = "railgun",
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "SHIP GROUND BUILDING",
			mainDir = "1 0 0",
			maxAngleDif = 180,
		},
		[5]                      = {
			def                  = "plasmacannon",
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "SHIP GROUND BUILDING",
			mainDir = "0 0 1",
			maxAngleDif = 220,
		},
		[6]                      = {
			def                  = "lasercannon",
			onlyTargetCategory    = "AIR",
		},
		[7]                      = {
			def                  = "lasercannon",
			onlyTargetCategory    = "AIR",
		},
		[8]                      = {
			def                  = "torpedo",
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "SUBMARINE SHIP BUILDING GROUND",
		},
	},
	customParams                 = {
		unittype				 = "mobile",
		unitsubtype              = "ship",
		unitrole				 = "Destroyer",
		canbetransported 		 = "true",
		needed_cover             = 2,
		death_sounds             = "generic",
		RequireTech              = tech,
		nofriendlyfire	         = "1",
		supply_cost              = 1,
		normaltex               = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "Loz Alliance",
		corpse                   = "energycore",
	},
}

weaponDefs                 = {
	railgun               = {
		avoidFriendly          = false,
		avoidFeature 		   = false,
		collideFriendly        = false,
		collideFeature         = false,
		cegTag                 = "railgun",
		edgeEffectiveness	   = 1,
		rgbColor               = "0.2 0 1",
		rgbColor2              = "1 1 1",
		explosionGenerator     = "custom:genericshellexplosion-medium",
		energypershot          = 0,
		fallOffRate            = 0,
		duration			   = 0.25,
		impulseFactor          = 0,
		interceptedByShieldType  = 4,
		name                   = "Railgun",
		range                  = 1350,
		reloadtime             = 3,
		--projectiles			   = 5,
		weaponType		       = "LaserCannon",
		soundStart             = "weapons/reaperrailgun.wav",
		texture1               = "shot",
		texture2               = "empty",
		coreThickness          = 0.4,
		thickness              = 6,
		tolerance              = 10000,
		turret                 = true,
		weaponTimer            = 1,
		weaponVelocity         = 2000,
		customparams             = {
			single_hit		 	 = true,
			expl_light_color	= blue, -- As a string, RGB
			expl_light_radius	= mediumExplosion, -- In Elmos
			expl_light_life		= mediumExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 150,
		},
	},

	lasercannon                  = {
		predictboost	         = 0.3,
		avoidFeature             = false,
		avoidFriendly            = false,
		beamTime                 = 0.1,
		beamttl                  = 4,
		collideFeature           = false,
		collideFriendly          = false,
		canattackground          = false,
		coreThickness            = 0.3,
		duration                 = 0.1,
		energypershot            = 0,
		explosionGenerator       = "custom:genericshellexplosion-small",
		fallOffRate              = 1,
		fireStarter              = 50,
		interceptedByShieldType  = 4,
		impulsefactor		     = 0.1,

		largebeamlaser	         = true,
		laserflaresize 	         = 8,
		minintensity             = 1,
		name                     = "Electromagnetic Pulse Laser",
		range                    = 1350,
		reloadtime               = 0.3,
		WeaponType               = "BeamLaser",
		rgbColor                 = "0.1 0 0.3",
		rgbColor2                = "1 1 1",
		soundTrigger             = true,
		soundstart               = "weapons/aegis.wav",
		--	soundHit		     = "weapons/amphibmedtankshothit.wav",
		scrollspeed		         = 5,
		texture1                 = "lightning",
		texture2                 = "laserend",
		thickness                = 4,
		tolerance                = 3000,
		turret                   = true,
		weaponVelocity           = 1000,
		customparams              = {
			expl_light_color	= purple, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                    = {
			default               = 2,
		},
	},

	torpedo             = {
		avoidFriendly            = false,
		avoidFeature             = false,
		collideFriendly          = false,
		collideFeature           = false,
		-- cegTag                   = "ehbotrocko-optimized",
		explosionGenerator       = "custom:genericshellexplosion-small",
		energypershot            = 0,
		impulseFactor            = 0,
		interceptedByShieldType  = 4,
		model                    = "missilesmalllauncher.s3o",
		name                     = "Torpedo",
		range                    = 1350,
		reloadtime               = 1,
		weaponType		         = "TorpedoLauncher",
		waterweapon              = true,
		smokeTrail               = false,
		soundStart               = "weapons/torpedolaunch.wav",
		soundHit                 = "explosions/subhitbomb.wav",
		startVelocity            = 250,
		tolerance                = 8000,
		turnrate                 = 30000,
		turret                   = true,
		tracks                   = false,
		flightTime               = 10,
		weaponVelocity           = 100,
		customparams             = {
			expl_light_color	= purple, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 75,
		},
	},
	plasmacannon              = {
		AreaOfEffect             = 50,
		avoidFriendly            = false,
		avoidFeature             = false,
		collideFriendly          = false,
		collideFeature           = false,

		--cegTag                   = "artyshot2",
		avoidNeutral	         = false,
		explosionGenerator       = "custom:genericshellexplosion-medium",
		energypershot            = 0,

		impulseFactor            = 0,
		interceptedByShieldType  = 4,
		highTrajectory	         = 0,
		name                     = "Plasma Cannon",
		range                    = 1350,
		reloadtime               = 2,
		size					 = 5,
		weaponType		         = "Cannon",
		soundHit                 = "explosions/artyhit.wav",
		soundStart               = "weapons/arty2.wav",

		turret                   = true,
		weaponVelocity           = 500,
		customparams             = {
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= largeExplosion, -- In Elmos
			expl_light_life		= largeExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 60,
		},
	},
}
