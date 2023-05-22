unitDef                    = {
	buildCostEnergy              = 0,
	buildCostMetal               = 28000,
	builder                      = false,
	buildTime                    = 5,
	buildpic					 = "lozwarlord.png",
	canAttack                    = true,
	canGuard                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = "1",
	category                     = "SHIP",
	description                  = [[Heavy Cruiser]],
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
	maxVelocity                  = 1.4,
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
	sightDistance                = 500,
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
	turnrate 				 	 = 150,
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
		[1]                      = {
			def                  = "plasmacannon",
			badTargetCategory     = "SHIP GROUND",
			onlyTargetCategory    = "SHIP GROUND BUILDING",
		},
		[2]                      = {
			def                  = "lightningcannon",
			onlyTargetCategory    = "AIR SHIP GROUND BUILDING",
		},
		[3]                      = {
			def                  = "lightningcannon",
			onlyTargetCategory    = "AIR SHIP GROUND BUILDING",
		},
	},
	customParams                 = {
		unittype				 = "ship",
		unitrole				 = "Heavy Cruiser",
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
	plasmacannon              = {
		AreaOfEffect             = 30,
		avoidFriendly            = false,
		avoidFeature             = false,
		collideFriendly          = false,
		collideFeature           = false,

		--cegTag                   = "artyshot2",
		avoidNeutral	         = false,
		explosionGenerator       = "custom:genericshellexplosion-medium",
		energypershot            = 0,

		burst                    = 6,
		burstrate                = 0.3,

		impulseFactor            = 0,
		interceptedByShieldType  = 4,
		highTrajectory	         = 0,
		name                     = "High Explosive Plasma Cannon",
		range                    = 1700,
		reloadtime               = 7,
		size					 = 8,
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

	lightningcannon   	             = {
		avoidFriendly            = false,
		avoidFeature             = false,
		collideFriendly          = false,
		collideFeature           = false,
		craterBoost              = 0,
		craterMult               = 0,
		burst                    = 10,
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
		range                    = 1700,
		reloadtime               = 5,
		WeaponType               = "LightningCannon",
		rgbColor                 = [[0.5 0 0]],
		rgbColor2                = "1 1 1",
		soundStart               = "lozscorpion-maingun",
		soundtrigger             = true,

		texture1                 = "lightning",
		thickness                = 1.5,
		turret                   = true,
		weaponVelocity           = 400,
		customparams             = {
			expl_light_color	= blue, -- As a string, RGB
			expl_light_radius	= mediumExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 2.5,
		},
	},
}
