unitDef                    = {
	buildCostEnergy              = 0,
	buildCostMetal               = 75000,
	builder                      = false,
	buildTime                    = 5,
	buildpic					 = "lozsilverback.png",
	canAttack                    = true,
	canGuard                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = "1",
	category                     = "GROUND MASSIVE",
	description                  = [[Endbringer Class Mobile Target Evaporator]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = explodeAs,
	footprintX                   = 12,
	footprintZ                   = 12,
	iconType                     = "tankassaultt4",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	leaveTracks                  = false,
	maxDamage                    = 20000,
	maxSlope                     = 28,
	maxVelocity                  = 1.2,
	maxReverseVelocity           = 1,
	maxWaterDepth                = 25,
	metalStorage                 = 0,
	movementClass                = "WHEELEDTANK8",
	name                         = humanName,
	noChaseCategory              = "VTOL",
	objectName                   = objectName,
	script			             = script,
	radarDistance                = 0,
	repairable		             = false,
	selfDestructAs               = explodeAs,
	sightDistance                = 1200,
	smoothAnim                   = true,
	stealth			             = true,
	seismicSignature             = 4,
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
			def                  = "heavyrailgun",
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "GROUND BUILDING SHIP",
		},
		[2]                      = {
			def                  = "railgun",
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "GROUND BUILDING SHIP",
		},
		[3]                      = {
			def                  = "flamethrower",
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "GROUND BUILDING SHIP",
			mainDir = "0 0 1",
			maxAngleDif = 120,
		},
	},
	customParams                 = {
		isupgraded			  	 = isUpgraded,
		unittype				 = "mobile",
		unitrole				 = "Main Battle Tank - Tech 3",
		death_sounds             = "generic",
		RequireTech              = tech,
		nofriendlyfire	         = "1",
		supply_cost              = 1,
		normaltex               = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "Loz Alliance",
		
	},
}

weaponDefs                 = {
	heavyrailgun_old              = {
		areaofeffect		   = 50,
		avoidFriendly            = false,
		avoidFeature             = false,
		collideFriendly          = false,
		collideFeature           = false,
		--cegTag               	  = "railgun",
		beamTime                 = 0.1,
		coreThickness            = 0.5,
		duration                 = 0.1,
		explosionGenerator       = "custom:genericshellexplosion-large",
		fallOffRate              = 0,
		fireStarter              = 100,
		interceptedByShieldType  = 4,
		impulseFactor            = 0,
		minintensity             = 1,
		name                     = "Anti-Tank Railgun",
		range                    = 1200,
		reloadtime               = 10,
		WeaponType               = "LaserCannon",
		rgbColor                 = "1 1 1",
		rgbColor2                = "1 1 1",
		soundTrigger             = true,
		soundstart               = "lozsilverback-maingun",
		texture1                 = "pulseshot2",
		texture2                 = "empty",
		thickness                = 16,
		tolerance                = 1000,
		turret                   = true,
		weaponVelocity           = 1500,
		customparams             = {
			expl_light_color	= blue, -- As a string, RGB
			expl_light_radius	= hugeExplosion, -- In Elmos
			expl_light_life		= hugeExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		}, 
		damage                   = {
			default              = 10000,
		},
	},

	heavyrailgun           = {
		areaofeffect		      = 50,
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
		name                      = "Anti-Tank Railgun",
		range                     = 1200,
		reloadtime                = 10,
		WeaponType                = "BeamLaser",
		rgbColor                  = "1 1 5",
		rgbColor2                 = "1 1 1",
		soundTrigger              = true,
		soundstart                = "lozsilverback-maingun1",
		-- soundHit                  = "explode5",
		-- sprayangle				  = 500,
		texture1                  = "flashside3",
		texture2                  = "empty",
		thickness                 = 7,
		tolerance                 = 1000,
		turret                    = true,
		weaponVelocity            = 750,
		waterweapon				 = false,
		customparams              = {
			--single_hit		 	 = true,
			expl_light_color	= white, -- As a string, RGB
			expl_light_radius	= hugeExplosion, -- In Elmos
			expl_light_life		= hugeExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                    = {
			default               = 10000,
		},
	},

	railgun               = {
		areaofeffect		   = 25,
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
		minintensity             = 1,
		interceptedByShieldType  = 4,
		name                   = "Railgun",
		range                  = 1200,
		reloadtime             = 0.6,
		--projectiles			   = 5,
		weaponType		       = "LaserCannon",
		soundStart             = "efighterlaser",
		texture1               = "shot",
		texture2               = "empty",
		coreThickness          = 0.4,
		thickness              = 12,
		tolerance              = 10000,
		turret                 = true,
		weaponTimer            = 1,
		weaponVelocity         = 2000,
		customparams             = {
			--single_hit		 	 = true,
			expl_light_color	= purple, -- As a string, RGB
			expl_light_radius	= mediumExplosion, -- In Elmos
			expl_light_life		= mediumExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 1000,
		},
	},

	flamethrower           = {
		avoidFeature              = false,
		avoidFriendly             = false,
		collideFeature            = false,
		collideFriendly           = false,
		coreThickness             = 0.3,
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
		minintensity              = 0.5,
		name                      = "Microwave Beam",
		range                     = 1200,
		reloadtime                = 0.5,
		WeaponType                = "BeamLaser",
		rgbColor                  = "0.5 0.25 0",
		rgbColor2                 = "0.25 0.25 0.25",
		soundTrigger              = true,
		soundstart                = "flamethrower2",
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
			default               = 500,
		},
	},
}
