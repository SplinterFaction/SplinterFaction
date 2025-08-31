unitDef                    = {
	buildCostEnergy              = 0,
	buildCostMetal               = 3000,
	builder                      = false,
	buildTime                    = 5,
	buildpic					 = "fedcolossus.png",
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
	footprintX                   = 8,
	footprintZ                   = 8,
	iconType                     = "shipfiresupportt2",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	leaveTracks                  = false,
	maxDamage                    = 360,
	maxSlope                     = 60,
	maxVelocity                  = 2.1,
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
	sightDistance                = 750,
	waterline                    = 8,
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
	turnInPlaceAngleLimit		 = 90,
	turnrate 				 	 = 500,
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
			def                  = "clusterrockets",
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "SHIP BUILDING GROUND",
		},
		[5]                      = {
			def                  = "clusterrockets",
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "SHIP BUILDING GROUND",
		},
		[6]                      = {
			def                  = "machinegun",
			--			mainDir = "0 0 1", -- x:0 y:0 z:1 => that's forward!
			--			maxAngleDif = 70,
			onlyTargetCategory	  = "AIR",
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
		factionname	             = "Federation of Kala",
		corpse                   = "fedcolossus_dead",
	},
}

weaponDefs                 = {
	plasmacannon                	= {
		AreaOfEffect           = 25,
		avoidFriendly          = false,
		avoidFeature 		   = false,
		collideFriendly        = false,
		collideFeature         = false,
		--cegTag			   = "thudshot",
		burst				   = 5,
		burstrate			   = 0.1,
		edgeEffectiveness	   = 1,
		explosionGenerator     = "custom:genericshellexplosion-small",
		energypershot          = 0,
		--duration			   = 0.25,
		highTrajectory		   = 0,
		impulseFactor          = 0,
		interceptedByShieldType  = 4,
		name                   = "Plasma Cannon",
		--noExplode			   = true,
		range                  = 1200,
		reloadtime             = 3,
		size				   = 2,
		-- projectiles			   = 5,
		weaponType		       = "Cannon",
		soundStart             = "Shotgun Boom 101",
		soundHit	           = "mediumcannonhit",
		soundTrigger           = false,
		sprayAngle             = 750,
		tolerance              = 8000,
		turret                 = true,
		weaponTimer            = 1,
		weaponVelocity         = 800,
		customparams             = {
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 100,
		},
	},


	machinegun                = {
		areaofeffect           = 50,
		predictboost	       = 1,
		avoidFriendly          = false,
		avoidFeature 		   = false,
		collideFriendly        = false,
		collideFeature         = false,
		canattackground		   = false,
		burnblow               = true,
		burst                  = 15,
		burstrate              = 0.065,
		-- cegTag                 = "railgun",
		explosionGenerator     = "custom:genericshellexplosion-small",
		edgeEffectiveness	   = 1,
		energypershot          = 0,
		fallOffRate            = 0,
		impulseFactor          = 0,
		interceptedByShieldType  = 4,
		name                   = "MachineGun",
		range                  = 1200,
		reloadtime             = 1,
		--projectiles			   = 5,
		weaponType		       = "Cannon",
		soundStart             = "scifi_machine_gun_B_burst_05",
		soundtrigger           = true,
		size                   = 3,
		tolerance              = 10000,
		turret                 = true,
		weaponVelocity         = 1500,
		customparams             = {
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 1,
		},
	},

	clusterrockets             = {
		AreaOfEffect             = 100,
		avoidFriendly            = false,
		avoidFeature             = false,
		collideFriendly          = false,
		collideFeature           = false,
		cegTag                   = "amphibrocktrail-optimized",
		explosionGenerator       = "custom:genericshellexplosion-small",
		burst 					 = 4,
		burstrate 				 = 0.2,
		energypershot            = 0,
		fireStarter              = 70,
		tracks                   = true,
		impulseFactor            = 0,
		interceptedByShieldType  = 4,
		model                    = "neutralmissilex1.s3o",
		name                     = "Rockets",
		range                    = 1200,
		reloadtime               = 7,
		weaponType		         = "MissileLauncher",
		smokeTrail               = false,
		soundStart               = "rocket1",
		soundHit                 = "explode5",
		startVelocity            = 300,
		tolerance                = 2000,
		turnrate                 = 2500,
		turret                   = true,
		trajectoryHeight		 = 1.5,
		weaponAcceleration       = 300,
		flightTime               = 10,
		weaponVelocity           = 300,
		sprayangle				 = 5000,
		customparams             = {
			expl_light_color	= red, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              =120,
		},
	},
}
