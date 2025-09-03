unitDef                    = {
	buildCostEnergy              = 0,
	buildCostMetal               = 150,
	builder                      = false,
	buildTime                    = 5,
	buildpic					 = "lozroach.png",
	canAttack                    = true,
	canGuard                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = "1",
	category                     = "GROUND",
	description                  = [[Main Battle Tank / Direct Fire Support]],
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
	maxVelocity                  = 2.1,
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
	sightDistance                = 620,
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
			def                  = "railgunbeam",
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "GROUND BUILDING SHIP",
		},
	},
	customParams                 = {
		unittype				 = "mobile",
		unitrole				 = "Main Battle Tank",
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
	railgunpulse               = {
		avoidFriendly          = false,
		avoidFeature 		   = false,
		collideFriendly        = false,
		collideFeature         = false,
		-- cegTag                 = "railgun",
		rgbColor               = "0 0 1",
		rgbColor2              = "0.5 0.5 0.5",
		explosionGenerator     = "custom:genericshellexplosion-medium",
		energypershot          = 0,
		fallOffRate            = 0,
		duration			   = 0.25,
		impulseFactor          = 0,
		interceptedByShieldType  = 4,
		name                   = "Railgun",
		range                  = 620,
		reloadtime             = 1.6,
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
			expl_light_color	= blue, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 60,
		},
	},

	railgunballistic               = {
		avoidFriendly          = false,
		avoidFeature 		   = false,
		collideFriendly        = false,
		collideFeature         = false,
		cegTag                 = "plasmacannontrail-blue-short",
		explosionGenerator     = "custom:genericshellexplosion-medium",
		energypershot          = 0,
		impulseFactor          = 0,
		interceptedByShieldType  = 4,
		name                   = "Railgun",
		model                  = "projectile/projectileblue.s3o",
		highTrajectory         = 0,
		range                  = 620,
		reloadtime             = 1.6,
		--projectiles			   = 5,
		weaponType		       = "Cannon",
		soundStart             = "lozroach-maingun",
		tolerance              = 10000,
		turret                 = true,
		weaponVelocity         = 1500,
		customparams             = {
			--single_hit		 	 = true,
			expl_light_color	= blue, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 60,
		},
	},

	railgunbeam           = {
		areaofeffect		      = 25,
		avoidFeature              = false,
		avoidFriendly             = false,
		collideFeature            = false,
		collideFriendly           = false,
		coreThickness             = 0.5,
		-- cegtag					  = "burnblack",
		beamtime				  = 0.2,
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
		range                     = 620,
		reloadtime                = 1.6,
		WeaponType                = "BeamLaser",
		rgbColor                  = blue,
		rgbColor2                 = "1 1 1",
		soundTrigger              = true,
		soundstart                = "lozroach-maingun",
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
			--single_hit		 	 = true,
			expl_light_color	= blue, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                    = {
			default               = 60,
		},
	},
}
