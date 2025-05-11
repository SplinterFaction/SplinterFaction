unitDef                    = {
	buildCostEnergy              = 0,
	buildCostMetal               = 3200,
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
	iconType                     = "shipassaultt2",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	leaveTracks                  = false,
	maxDamage                    = 360,
	maxSlope                     = 60,
	maxVelocity                  = 1.9,
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
	sightDistance                = 750,
	sonarDistance                = 750,
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
	acceleration 				 = 0.035,
	brakeRate                    = 0.035,
	turninplace 				 = true,
	--	turninplacespeedlimit 		 = 10,
	turnInPlaceAngleLimit		 = 45,
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
		underattack              = "units_under_attack",
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
			def                  = "flamethrower",
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "SHIP GROUND BUILDING",
			mainDir = "-1 0 0",
			maxAngleDif = 180,
		},
		[2]                      = {
			def                  = "flamethrower",
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "SHIP GROUND BUILDING",
			mainDir = "-1 0 0",
			maxAngleDif = 180,
		},
		[3]                      = {
			def                  = "flamethrower",
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "SHIP GROUND BUILDING",
			mainDir = "1 0 0",
			maxAngleDif = 180,
		},
		[4]                      = {
			def                  = "flamethrower",
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "SHIP GROUND BUILDING",
			mainDir = "1 0 0",
			maxAngleDif = 180,
		},
		[5]                      = {
			def                  = "torpedo",
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "SHIP GROUND BUILDING",
		},
	},
	customParams                 = {
		unittype				 = "ship",
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
		-- cegTag                 = "railgun",
		rgbColor               = "1 0 0",
		rgbColor2              = "1 1 1",
		explosionGenerator     = "custom:genericshellexplosion-medium",
		energypershot          = 0,
		fallOffRate            = 0,
		duration			   = 0.25,
		impulseFactor          = 0,
		interceptedByShieldType  = 4,
		name                   = "Railgun",
		range                  = 1350,
		reloadtime             = 6,
		--projectiles			   = 5,
		weaponType		       = "LaserCannon",
		soundStart             = "lozroach-maingun",
		texture1               = "shot",
		texture2               = "empty",
		coreThickness          = 0.3,
		thickness              = 12,
		tolerance              = 10000,
		turret                 = true,
		weaponTimer            = 1,
		weaponVelocity         = 1500,
		customparams             = {
			--single_hit		 	 = true,
			expl_light_color	= green, -- As a string, RGB
			expl_light_radius	= largeExplosion, -- In Elmos
			expl_light_life		= largeExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 900,
		},
	},

	flamethrower           = {
		avoidFeature              = false,
		avoidFriendly             = false,
		collideFeature            = false,
		collideFriendly           = false,
		coreThickness             = 0.5,
		-- cegtag					  = "burnblack",
		beamtime				  = 0.25,
		beamttl                   = 4,
		largebeamlaser			  = true,
		duration                  = 0.8,
		energypershot             = 0,
		edgeeffectiveness		  = 0,
		explosionGenerator        = "custom:burnblacksmall",
		fallOffRate               = 0.1,
		fireStarter               = 100,
		impulseFactor             = 0,
		interceptedByShieldType   = 4,
		minintensity              = 1,
		name                      = "Beam",
		range                     = 1350,
		reloadtime                = 0.25,
		WeaponType                = "BeamLaser",
		rgbColor                  = "1 0 0",
		rgbColor2                 = "0.25 0.25 0.25",
		soundTrigger              = true,
		soundstart                = "lozmammoth-sidebeams",
		-- soundHit                  = "explode5",
		-- sprayangle				  = 500,
		texture1                  = "flashside3",
		texture2                  = "empty",
		thickness                 = 3,
		tolerance                 = 1000,
		turret                    = true,
		weaponVelocity            = 750,
		waterweapon				 = false,
		customparams              = {
			expl_light_color	= yellow, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                    = {
			default               = 37.5,
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
		model                    = "neutralmissilex1.s3o",
		name                     = "Torpedo",
		range                    = 1350,
		reloadtime               = 4,
		weaponType		         = "TorpedoLauncher",
		waterweapon              = true,
		smokeTrail               = false,
		soundStart               = "torpedolaunch",
		soundHit                 = "subhitbomb",
		tolerance                = 8000,
		turnrate                 = 30000,
		turret                   = true,
		tracks                   = true,
		flightTime               = 10,
		startVelocity            = 200,
		weaponAcceleration       = 25,
		weaponVelocity           = 250,
		customparams             = {
			expl_light_color	= purple, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 500,
		},
	},
}
