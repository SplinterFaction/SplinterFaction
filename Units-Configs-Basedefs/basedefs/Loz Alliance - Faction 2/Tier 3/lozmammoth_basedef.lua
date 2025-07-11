unitDef                    = {
	buildCostEnergy              = 0,
	buildCostMetal               = 20000,
	builder                      = false,
	buildTime                    = 5,
	buildpic					 = "lozmammoth.png",
	canAttack                    = true,
	canGuard                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = "1",
	category                     = "GROUND MASSIVE",
	description                  = [[Main Battle Tank]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = explodeAs,
	footprintX                   = 7,
	footprintZ                   = 7,
	iconType                     = "tankassaultt3",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	leaveTracks                  = false,
	maxDamage                    = 375,
	maxSlope                     = 26,
	maxVelocity                  = 1.3,
	maxReverseVelocity           = 1,
	maxWaterDepth                = 10,
	metalStorage                 = 0,
	movementClass                = "WHEELEDTANK7",
	name                         = humanName,
	noChaseCategory              = "VTOL",
	objectName                   = objectName,
	script			             = script,
	radarDistance                = 0,
	repairable		             = false,
	selfDestructAs               = explodeAs,
	side                         = "CORE",
	sightDistance                = 800,
	smoothAnim                   = true,
	stealth			             = true,
	seismicSignature             = 2,
	transportbyenemy             = false;
	unitname                     = unitName,
	upright                      = false,
	workerTime                   = 0,
	--------------
	-- Movement --
	--------------
	acceleration 				 = 2,
	brakeRate                    = 0.1,
	turninplace 				 = true,
	turninplacespeedlimit 		 = 10,
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
			def                  = "railgun",
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "GROUND BUILDING SHIP",
		},
		[2]                      = {
			def                  = "lasercannon",
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "GROUND BUILDING SHIP",
		},
		[3]                      = {
			def                  = "flamethrower",
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "GROUND BUILDING SHIP",
		},
	},
	customParams                 = {
		unittype				 = "mobile",
		unitrole				 = "Main Battle Tank - Tech 3",
		canbetransported 		 = "true",
		needed_cover             = 3,
		death_sounds             = "generic",
		RequireTech              = tech,
		nofriendlyfire	         = "1",
		supply_cost              = 1,
		normaltex                = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "Loz Alliance",
		
	}
}

weaponDefs                 = {
	railgun_old               = {
		areaofeffect		   = 15,
		avoidFriendly          = false,
		avoidFeature 		   = false,
		collideFriendly        = false,
		collideFeature         = false,
		--cegTag                 = "railgun",
		rgbColor               = "0.2 0 1",
		rgbColor2              = "1 1 1",
		explosionGenerator     = "custom:genericshellexplosion-medium",
		energypershot          = 0,
		fallOffRate            = 0,
		duration			   = 0.25,
		impulseFactor          = 0,
		interceptedByShieldType  = 4,
		name                   = "Railgun",
		range                  = 800,
		reloadtime             = 4,
		--projectiles			   = 5,
		weaponType		       = "LaserCannon",
		soundStart             = "lozmammoth-maingun",
		texture1               = "shot",
		texture2               = "empty",
		coreThickness          = 0.4,
		thickness              = 18,
		tolerance              = 10000,
		turret                 = true,
		weaponTimer            = 1,
		weaponVelocity         = 2000,
		customparams             = {
			--single_hit		 	 = true,
			expl_light_color	= blue, -- As a string, RGB
			expl_light_radius	= largeExplosion, -- In Elmos
			expl_light_life		= largeExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 1500,
		},
	},

	railgun           = {
		areaofeffect		      = 15,
		avoidFeature              = false,
		avoidFriendly             = false,
		collideFeature            = false,
		collideFriendly           = false,
		coreThickness             = 0.5,
		-- cegtag					  = "burnblack",
		beamtime				  = 0.5,
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
		range                     = 800,
		reloadtime                = 4,
		WeaponType                = "BeamLaser",
		rgbColor                  = "0.1 0.1 0.5",
		rgbColor2                 = "1 1 1",
		soundTrigger              = true,
		soundstart                = "lozmammoth-maingun2",
		-- soundHit                  = "explode5",
		-- sprayangle				  = 500,
		texture1                  = "flashside3",
		texture2                  = "empty",
		thickness                 = 5,
		tolerance                 = 1000,
		turret                    = true,
		weaponVelocity            = 750,
		waterweapon				 = false,
		customparams              = {
			--single_hit		 	 = true,
			expl_light_color	= blue, -- As a string, RGB
			expl_light_radius	= largeExplosion, -- In Elmos
			expl_light_life		= largeExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                    = {
			default               = 1500,
		},
	},

	lasercannon                = {
		avoidFriendly          = false,
		avoidFeature 		   = false,
		collideFriendly        = false,
		collideFeature         = false,
		--cegTag                 = "railgun",
		rgbColor               = "1 0 0",
		rgbColor2              = "1 1 1",
		explosionGenerator     = "custom:genericshellexplosion-small",
		edgeEffectiveness	   = 1,
		energypershot          = 0,
		fallOffRate            = 0,
		duration			   = 0.1,
		impulseFactor          = 0,
		interceptedByShieldType  = 4,
		name                   = "Electromagnetic Pulse Laser",
		range                  = 800,
		reloadtime             = 0.5,
		--projectiles			   = 5,
		weaponType		       = "LaserCannon",
		soundStart             = "lozmammoth-sideguns",
		texture1               = "shot",
		texture2               = "empty",
		coreThickness          = 0.3,
		thickness              = 10,
		tolerance              = 10000,
		turret                 = true,
		weaponTimer            = 1,
		weaponVelocity         = 800,
		customparams             = {
			expl_light_color	= red, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 50,
		},
	},
	flamethrower           = {
		avoidFeature              = false,
		avoidFriendly             = false,
		collideFeature            = false,
		collideFriendly           = false,
		coreThickness             = 0.5,
		-- cegtag					  = "burnblack",
		beamtime				  = 0.25,
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
		range                     = 800,
		reloadtime                = 0.25,
		WeaponType                = "BeamLaser",
		rgbColor                  = "0 0.1 0",
		rgbColor2                 = "0.25 0.25 0.25",
		soundTrigger              = true,
		soundstart                = "lozmammoth-sidebeams",
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
			expl_light_color	= yellow, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                    = {
			default               = 37.5,
		},
	},
}
