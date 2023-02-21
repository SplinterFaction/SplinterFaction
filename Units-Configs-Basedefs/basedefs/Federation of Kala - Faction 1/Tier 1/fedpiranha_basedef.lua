unitDef                    = {
	buildCostEnergy              = 0,
	buildCostMetal               = 150,
	builder                      = false,
	buildTime                    = 5,
	buildpic					 = "lozpiranha.png",
	canAttack                    = true,
	canGuard                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = "1",
	category                     = "SUBMARINE",
	description                  = [[Attack Submarine]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = explodeAs,
	footprintX                   = 4,
	footprintZ                   = 4,
	iconType                     = "mbt",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	leaveTracks                  = false,
	maxDamage                    = 360,
	maxSlope                     = 60,
	maxVelocity                  = 3,
	maxReverseVelocity           = 1,
	maxWaterDepth                = 5000,
	minWaterDepth                = 25,
	metalStorage                 = 0,
	movementClass                = "SUBMARINE4",
	name                         = humanName,
	noChaseCategory              = "AIR GROUND",
	objectName                   = objectName,
	script			             = script,
	radarDistance                = 0,
	repairable		             = false,
	selfDestructAs               = explodeAs,
	side                         = "CORE",
	sightDistance                = 550,
	sonarDistance                = 550,
	waterline                    = 40,
	floater                      = true,
	stealth			             = true,
	seismicSignature             = 2,
	smoothAnim                   = true,
	transportbyenemy             = false;
	unitname                     = unitName,
	workerTime                   = 0,

	--------------
	-- Cloaking --
	--------------
	cancloak		             = true,
	cloakCost		             = 0,
	cloakCostMoving	             = 0,
	minCloakDistance             = 425,
	decloakOnFire	             = true,
	decloakSpherical             = true,
	initCloaked		             = true,
	--------------
	--------------

	--------------
	-- Movement --
	--------------
	acceleration 				 = 2,
	brakeRate                    = 0.1,
	turninplace 				 = false,
	turninplacespeedlimit 		 = 10,
	turnInPlaceAngleLimit		 = 90,
	turnrate 				 	 = 200,
	--------------
	--------------
	sfxtypes                     = { 
		pieceExplosionGenerators = { 
			"deathceg3", 
			"deathceg4", 
		}, 

		explosiongenerators      = {
			"custom:factorysparks",
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
			def                  = "torpedo",
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "SUBMARINE SHIP BUILDING GROUND",
		},
	},
	customParams                 = {
		unittype				 = "ship",
		unitrole				 = "Submarine",
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
		range                    = 550,
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
			default              = 50,
		},
	},
}
