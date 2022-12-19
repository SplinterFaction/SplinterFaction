unitDef                    = {
	acceleration                 = 1,
	brakeRate                    = 0.1,
	buildCostEnergy              = 0,
	buildCostMetal               = 2600,
	builder                      = false,
	buildTime                    = 5,
	buildpic					 = "fedconqueror.png",
	canAttack                    = true,
	canGuard                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = "1",
	category                     = "SHIP",
	description                  = [[Light Cruiser]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = explodeAs,
	footprintX                   = 8,
	footprintZ                   = 8,
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
	movementClass                = "SHIP8",
	name                         = humanName,
	noChaseCategory              = "AIR GROUND",
	objectName                   = objectName,
	script			             = script,
	radarDistance                = 0,
	repairable		             = false,
	selfDestructAs               = explodeAs,
	side                         = "CORE",
	sightDistance                = 1550,
	sonarDistance                = 1550,
	waterline                    = 8,
	floater                      = true,
	stealth			             = true,
	seismicSignature             = 2,
	smoothAnim                   = true,
	transportbyenemy             = false;
	--  turnInPlace              = false,
	--  turnInPlaceSpeedLimit    = 4.5,
	turnInPlace                  = true,
	turnRate                     = 5000,
	--  turnrate                 = 430,
	unitname                     = unitName,
	workerTime                   = 0,
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
			def                  = "plasmacannon",
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "SHIP BUILDING GROUND",
		},
		[2]                      = {
			def                  = "plasmacannon",
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "SHIP BUILDING GROUND",
		},
		[3]                      = {
			def                  = "plasmacannon",
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "SHIP BUILDING GROUND",
		},
		[4]                      = {
			def                  = "plasmacannon",
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "SHIP BUILDING GROUND",
		},
		[5]                      = {
			def                  = "rockets",
			onlyTargetCategory    = "AIR",
		},
		[6]                      = {
			def                  = "torpedo",
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "SUBMARINE SHIP BUILDING GROUND",
		},
	},
	customParams                 = {
		unittype				 = "mobile",
		unitsubtype              = "ship",
		unitrole				 = "Light Cruiser",
		canbetransported 		 = "true",
		needed_cover             = 2,
		death_sounds             = "generic",
		RequireTech              = tech,
		nofriendlyfire	         = "1",
		supply_cost              = 1,
		normaltex               = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "Federation of Kala",
		corpse                   = "energycore",
	},
}

weaponDefs                 = {
	plasmacannon                	= {
		AreaOfEffect           = 40,
		avoidFriendly          = false,
		avoidFeature 		   = false,
		collideFriendly        = false,
		collideFeature         = false,
		--cegTag			   = "thudshot",
		burst				   = 4,
		burstrate			   = 0.5,
		edgeEffectiveness	   = 1,
		explosionGenerator     = "custom:genericshellexplosion-small",
		energypershot          = 0,
		-- duration			   = 0.25,
		highTrajectory		   = 1,
		impulseFactor          = 0,
		interceptedByShieldType  = 4,
		name                   = "Plasma Cannon",
		--noExplode			   = true,
		range                  = 1550,
		reloadtime             = 5,
		size				   = 2,
		stages                 = 20,
		alphaDecay             = 0.1,
		weaponType		       = "Cannon",
		soundStart             = "weapons/Shotgun Boom 101.wav",
		soundHit	           = "explosions/mediumcannonhit.wav",
		soundTrigger           = true,
		sprayAngle             = 100,
		tolerance              = 10000,
		turret                 = true,
		weaponTimer            = 1,
		weaponVelocity         = 600,
		customparams             = {
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 130,
		},
	},

	torpedo             = {
		areaofeffect             = 175,
		avoidFriendly            = false,
		avoidFeature             = false,
		collideFriendly          = false,
		collideFeature           = false,
		-- cegTag                   = "ehbotrocko-optimized",
		explosionGenerator       = "custom:genericshellexplosion-small-purple",
		energypershot            = 0,
		impulseFactor            = 0,
		interceptedByShieldType  = 4,
		model                    = "missilesmalllauncher.s3o",
		name                     = "Torpedo",
		range                    = 1550,
		burst                    = 3,
		burstrate                = 0.25,
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
		tracks                   = true,
		weaponAcceleration       = 400,
		flightTime               = 2.5,
		weaponVelocity           = 3000,
		customparams             = {
			expl_light_color	= purple, -- As a string, RGB
			expl_light_radius	= mediumExplosion, -- In Elmos
			expl_light_life		= mediumExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 15,
		},
	},

	rockets             = {
		avoidFriendly            = false,
		avoidFeature             = false,
		collideFriendly          = false,
		collideFeature           = false,
		canAttackGround 		 = false,
		cegTag                   = "gunshiptrail-optimized-longlasting",
		explosionGenerator       = "custom:genericshellexplosion-small-purple",
		energypershot            = 0,
		burst                    = 2,
		burstrate                = 0.1,
		fireStarter              = 70,
		impulseFactor            = 0,
		interceptedByShieldType  = 4,
		model                    = "missilesmalllauncher.s3o",
		name                     = "Rockets",
		range                    = 1550,
		reloadtime               = 1,
		weaponType		         = "MissileLauncher",
		smokeTrail               = false,
		soundStart               = "weapons/sabotlaunch.wav",
		soundHit                 = "explosions/explode5.wav",
		-- stockpile                = true,
		-- stockpiletime            = 2,
		startVelocity            = 100,
		tolerance                = 8000,
		turnrate                 = 100000,
		dance                    = 150,
		turret                   = true,
		tracks                   = true,
		weaponAcceleration       = 2000,
		flightTime               = 1.5,
		weaponVelocity           = 2000,
		customparams             = {
			expl_light_color	= purple, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 7.5,
		},
	},
}
