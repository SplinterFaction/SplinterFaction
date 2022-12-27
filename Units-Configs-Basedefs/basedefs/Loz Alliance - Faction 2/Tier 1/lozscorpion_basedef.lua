unitDef                    = {
	buildCostEnergy              = 0,
	buildCostMetal               = 125,
	builder                      = false,
	buildTime                    = 5,
	buildpic					 = "lozscorpion.png",
	canAttack                    = true,
	
	--  canDgun			         = true,
	canGuard                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = "1",
	category                     = "GROUND",
	description                  = [[Artillery Tank]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = explodeAs,
	footprintX                   = 2,
	footprintZ                   = 2,
	iconType                     = "artillery",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	leaveTracks                  = false,
	maxDamage                    = 340,
	maxSlope                     = 28,
	maxVelocity                  = 2,
	maxReverseVelocity           = 1,
	maxWaterDepth                = 5000,
	metalStorage                 = 0,
	movementClass                = "WHEELEDTANK2",
	name                         = humanName,
	noChaseCategory              = "VTOL",
	objectName                   = objectName,
	script			             = script,
	radarDistance                = 0,
	repairable		             = false,
	selfDestructAs               = explodeAs,
	side                         = "CORE",
	sightDistance                = 650,
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
	turnrate 				 	 = 1000,
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
			def                  = "clusterrockets",
			onlyTargetCategory    = "GROUND BUILDING AIR",
		},
	},
	customParams                 = {
		unittype				 = "mobile",
		unitrole				 = "Artillery",
		canbetransported 		 = "true",
		needed_cover             = 2,
		death_sounds             = "generic",
		RequireTech              = tech,
		armortype                = "light",
		nofriendlyfire	         = "1",
		supply_cost              = 3,
		normaltex               = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "Loz Alliance",
		corpse                   = "energycore",
	},
}

weaponDefs                 = {
	clusterrockets             = {
		avoidFriendly            = false,
		avoidFeature             = false,
		collideFriendly          = false,
		collideFeature           = false,
		cegTag                   = "amphibrocktrail-optimized",
		explosionGenerator       = "custom:genericshellexplosion-small-red",
		energypershot            = 0,
		fireStarter              = 70,
		tracks                   = true,
		impulseFactor            = 0,
		interceptedByShieldType  = 4,
		model                    = "missilesmalllauncher.s3o",
		name                     = "Rockets",
		range                    = 650,
		reloadtime               = 7,
		weaponType		         = "MissileLauncher",
		smokeTrail               = false,
		soundStart               = "weapons/rocket1.wav",
		soundHit                 = "explosions/explode5.wav",
		startVelocity            = 250,
		tolerance                = 8000,
		turnrate                 = 25000,
		turret                   = true,
		trajectoryHeight		 = 1.5,
		weaponAcceleration       = 200,
		flightTime               = 1.5,
		weaponVelocity           = 1000,
		customparams             = {
			expl_light_color	= red, -- As a string, RGB
			expl_light_radius	= mediumExplosion, -- In Elmos
			expl_light_life		= mediumExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 300,
		},
	},
}
