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
	category                     = "SHIP",
	description                  = [[Corvette]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = explodeAs,
	footprintX                   = 3,
	footprintZ                   = 3,
	iconType                     = "shipraidert1",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	leaveTracks                  = false,
	maxDamage                    = 360,
	maxSlope                     = 60,
	maxVelocity                  = 4.2,
--	maxReverseVelocity           = 0.5,
	maxWaterDepth                = 5000,
	minWaterDepth                = 25,
	metalStorage                 = 0,
	movementClass                = "SHIP3",
	name                         = humanName,
	noChaseCategory              = "AIR GROUND",
	objectName                   = objectName,
	script			             = script,
	radarDistance                = 0,
	repairable		             = false,
	selfDestructAs               = explodeAs,
	side                         = "CORE",
	sightDistance                = 500,
	waterline                    = 2,
	sonarDistance                = 500,
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
	acceleration 				 = 0.075,
	brakeRate                    = 0.075,
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
			"custom:factorysparks",
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
			def                  = "torpedo",
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "SUBMARINE SHIP BUILDING GROUND",
		},
	},
	customParams                 = {
		unittype				 = "ship",
		unitrole				 = "Corvette",
		buildmenucategory        = "Skirmish",
		canbetransported 		 = "true",
		needed_cover             = 2,
		death_sounds             = "generic",
		RequireTech              = tech,
		nofriendlyfire	         = "1",
		supply_cost              = 1,
		normaltex               = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "Federation of Kala",
		corpse                   = "fedpiranha_dead",
		unitguide = [[The Piranha is a fast torpedo corvette built for aggressive naval raiding. Its unguided torpedo deals heavy damage per hit and reloads quickly, relying on the projectile's raw speed to intercept moving targets without any tracking system. Cheap relative to larger warships and quick enough to dictate engagement range, it excels at harassing enemy fleets and picking off isolated vessels before they can respond.]],
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
		model                    = "neutralmissilex1.s3o",
		name                     = "Torpedo",
		range                    = 550,
		reloadtime               = 1,
		weaponType		         = "TorpedoLauncher",
		waterweapon              = true,
		smokeTrail               = false,
		soundStart               = "torpedolaunch",
		soundHit                 = "subhitbomb",
		tolerance                = 8000,
		turnrate                 = 30000,
		turret                   = true,
		tracks                   = false,
		flightTime               = 10,
		startVelocity            = 100,
		weaponAcceleration       = 25,
		weaponVelocity           = 250,
		customparams             = {
			expl_light_color	= purple, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
			weaponguide = [[A fast-moving unguided torpedo with a short reload cycle. Its speed alone is sufficient to intercept most moving targets without the need for any tracking system.]],
		},
		damage                   = {
			default              = 250,
		},
	},
}
