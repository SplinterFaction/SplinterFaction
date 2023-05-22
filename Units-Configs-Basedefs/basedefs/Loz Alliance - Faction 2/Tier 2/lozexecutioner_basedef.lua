unitDef                    = {
	buildCostEnergy              = 0,
	buildCostMetal               = 15000,
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
			single_hit		 	 = true,
			expl_light_color	= green, -- As a string, RGB
			expl_light_radius	= largeExplosion, -- In Elmos
			expl_light_life		= largeExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 900,
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
		name                     = "Plasma Cannon",
		range                    = 1350,
		reloadtime               = 4,
		size					 = 7,
		weaponType		         = "Cannon",
		soundHit                 = "artyhit",
		soundStart               = "arty2",

		turret                   = true,
		weaponVelocity           = 500,
		customparams             = {
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= largeExplosion, -- In Elmos
			expl_light_life		= largeExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 500,
		},
	},
}
