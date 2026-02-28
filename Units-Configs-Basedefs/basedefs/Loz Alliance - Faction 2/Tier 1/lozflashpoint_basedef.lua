unitDef                    = {
	buildCostEnergy              = 0,
	buildCostMetal               = 275,
	builder                      = false,
	buildTime                    = 5,
	buildpic					 = "lozflashpoint.png",
	canAttack                    = true,
	canGuard                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = "1",
	category                     = "GROUND",
	description                  = [[Heat Ray / Direct Fire Support]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = explodeAs,
	footprintX                   = 2,
	footprintZ                   = 2,
	iconType                     = "tankassaultt1",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	leaveTracks                  = false,
	maxDamage                    = 360,
	maxSlope                     = 28,
	maxVelocity                  = 3.5,
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
	sightDistance                = 320,
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
	turninplace 				 = true,
	turninplacespeedlimit 		 = 10,
	turnInPlaceAngleLimit		 = 45,
	turnrate 				 	 = 600,
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
			def                  = "heatray",
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "GROUND BUILDING SHIP",
		},
	},
	customParams                 = {
		unittype				 = "mobile",
		unitrole				 = "Heatray Tank",
		canbetransported 		 = "true",
		needed_cover             = 2,
		death_sounds             = "generic",
		RequireTech              = tech,
		armortype                = "light",
		nofriendlyfire	         = "1",
		supply_cost              = 1,
		normaltex               = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "Loz Alliance",
		
	},
}

weaponDefs                 = {
	heatray           = {
		edgeeffectiveness        = 0.1,
		hardstop                 = true,
		avoidGround               = false,
		avoidFeature              = false,
		avoidFriendly             = false,
		collideFeature            = false,
		collideFriendly           = false,
		coreThickness             = 0.3,
		duration                  = 0.1,
		burst                     = 15,
		burstrate                 = 0.1,
		energypershot             = 50,
		edgeeffectiveness		  = 0,
		explosionGenerator        = "custom:genericshellexplosion-small",
		fallOffRate               = 0.1,
		fireStarter               = 100,
		impulseFactor             = 0,
		interceptedByShieldType   = 4,
		minintensity              = 1,
		name                      = "High Intensity WaveLaser",
		range                     = 300,
		reloadtime                = 5,
		WeaponType                = "LaserCannon",
		rgbColor                  = orange,
		rgbColor2                 = "1 1 1",
		soundTrigger              = true,
		soundstart                = "flashpointheatray",
		soundHit                  = "phasegun1hit.wav",
		-- sprayangle				  = 500,
		texture1                 = "wave",
		texture2                 = "empty",
		thickness                 = 10,
		tolerance                 = 1000,
		turret                    = true,
		weaponVelocity            = 2000,
		waterweapon				 = false,
		noexplode                 = true,
		customparams              = {
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
			single_hit            = "true",
			heatweapon = "1",
			heatmult   = "1.0", -- optional; higher = heats faster per damage
		},
		damage                    = {
			default               = 100,
		},
	},
}
