unitDef                    = {
	buildCostEnergy              = 0,
	buildCostMetal               = 900,
	builder                      = false,
	buildTime                    = 5,
	buildpic					 = "lozluger.png",
	canAttack                    = true,
	fireState                    = 0,
	canGuard                     = true,
	canHover                     = false,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = "1",
	category                     = "GROUND",
	description                  = [[Self-Propelled Long-Range Artillery]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = explodeAs,
	footprintX                   = 4,
	footprintZ                   = 4,
	iconType                     = "tankartilleryt2",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	leaveTracks                  = false,
	maxDamage                    = 300,
	maxVelocity                  = 1.3,
	maxReverseVelocity           = 1,
	maxWaterDepth                = 10,
	metalStorage                 = 0,
	movementClass                = "WHEELEDTANK4",
	name                         = humanName,
	noChaseCategory              = "VTOL",
	objectName                   = objectName,
	script			             = script,
	radarDistance                = 0,
	repairable		             = false,
	selfDestructAs               = explodeAs,
	side                         = "CORE",
	sightDistance                = 850,
	smoothAnim                   = true,
	stealth			             = true,
	seismicSignature             = 2,
	transportbyenemy             = false;
	unitname                      = unitName,
	workerTime                   = 0,
	--------------
	-- Movement --
	--------------
	acceleration 				 = 2,
	brakeRate                    = 0.1,
	turninplace 				 = true,
	turninplacespeedlimit 		 = 10,
	turnInPlaceAngleLimit		 = 45,
	turnrate 				 	 = 400,
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
		[1]                      = {
			def                  = "Artilleryweapon",
			badTargetCategory     = "GROUND",
			onlyTargetCategory    = "GROUND BUILDING SHIP",
		},
	},
	customParams                 = {
		unittype				  = "mobile",
		unitrole				 = "Artillery - Tech 2",
		canbetransported 		 = "true",
		canareaattack            ="1",
		stockpileLimit           = 5,
		needed_cover             = 3,
		death_sounds             = "generic",
		RequireTech              = tech,
		nofriendlyfire	         = "1",
		supply_cost              = 1,
		normaltex               = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "Loz Alliance",
		
	},
}


--------------------------------------------------------------------------------

weaponDefs                 = {
	Artilleryweapon              = {
		commandfire              = true,
		AreaOfEffect             = 100,
		avoidFriendly            = false,
		avoidFeature             = false,
		collideFriendly          = false,
		collideFeature           = false,

		cegTag                   = "plasmacannontrail-purple-large",
		avoidNeutral	         = false,
		explosionGenerator       = "custom:genericshellexplosion-large",
		energypershot            = 0,
		edgeEffectiveness	     = 0.1,
		impulseFactor            = 0,
		interceptedByShieldType  = 4,
		name                     = "High Explosive Plasma Cannon",
		model                    = "projectile/projectilepurple.s3o",
		range                    = 1300,
		reloadtime               = 40,
		size					 = 10,
		weaponType		         = "Cannon",
		soundHit                 = "artyhit",
		soundStart               = "lozluger-maingun",
		sprayangle               = 500,

		-----
		stockpile                = true,
		stockpiletime            = 90,
		metalpershot             = 0,
		energypershot            = 0,
		-----

		trajectoryHeight	     = 2,
		turret                   = true,
		weaponVelocity           = 450,
		customparams             = {
			expl_light_color	= purple, -- As a string, RGB
			expl_light_radius	= largeExplosion, -- In Elmos
			expl_light_life		= largeExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},  
		damage                   = {
			default              = 8000,
		},
	},
}
