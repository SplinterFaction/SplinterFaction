unitDef                    = {

	--mobileunit 
	transportbyenemy             = false; 
	--**
	buildCostEnergy              = 500,
	buildCostMetal               = buildcostmetal,
	buildDistance                = builddistance,
	builder                      = true,
	buildTime                    = 2.5,
	buildpic					 = buildpicture,
	capturable		             = false,
	CanAttack			         = true,
	CanAssist			         = true,
	canBeAssisted                = true,
	CanCapture                   = false,
	CanRepair			         = true,
	canRestore					 = true,
	
	canGuard                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canreclaim		             = true,
	canstop                      = true,
	category                     = "GROUND",
	description                  = [[Builds Units]],
	energyMake                   = 10,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = explodeas,
	footprintX                   = footprintx,
	footprintZ                   = footprintz,
	
	iconType                     = "commander",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	autoHeal                     = 15,
	levelground                  = true,
	maxDamage                    = 1,
	maxSlope                     = 180,
	maxVelocity                  = maxvelocity,
	maxReverseVelocity           = 1,
	maxWaterDepth                = 5000,
	metalmake                    = 2,
	metalStorage                 = 0,
	movementClass                = movementclass,
	moveState			         = "0",
	name                         = humanname,
	noChaseCategories	         = "NOTAIR SUPPORT VTOL AMPHIB",
	--------------------------
	-- Skillshot (aka DGun) --
	--------------------------
	noAutoFire                   = true,
	fireState                    = 0,
	canManualFire                = true,
	--------------------------
	--------------------------
	objectName                   = objectname,
	script			             = script,
	radarDistance                = 0,
	repairable		             = false,
	selfDestructAs               = selfdestructas,
	selfDestructCountdown         = 15,
	showPlayerName	             = true,
	showNanoSpray                = true,
	sightDistance                = 500,
	smoothAnim                   = true,
	stealth			             = true,
	seismicSignature             = 2,
	unitname                     = unitName,
	upright                      = false,
	workerTime                   = workertime,
	capturespeed                 = 1,
	TerraformSpeed               = 2147000,
	ReclaimSpeed                 = 1,	-- 0.03125 =  1 hp per second
	repairspeed                  = 1,
	--------------
	-- Movement --
	--------------
	acceleration 				 = 2,
	brakeRate                    = 0.1,
	turninplace 				 = true,
	turninplacespeedlimit 		 = 10,
	turnInPlaceAngleLimit		 = 45,
	turnrate 				 	 = 750,
	--------------
	--------------
	sfxtypes                     = {
		pieceExplosionGenerators = { 
			"deathceg3", 
			"deathceg4", 
		}, 
		
		explosiongenerators      = {
			"custom:nanoorb",
			"custom:emptydirt",
			"custom:blacksmoke",
			"custom:gdhcannon",
		},
	},
	buildoptions                 = buildlist,
	sounds                       = {
		build					 = "miscfx/buildstart.wav",
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
			def                  = weapon1,
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "GROUND BUILDING SHIP",
		},
	},
	customParams                 = {
		unittype				 = "mobile",
		unitrole 				 = "Commander",
		area_mex_def			 = areamexdef,
		ProvideTech              = techprovided,
		RequireTech				 = techrequired,
		techlevel                = techlevel,
		canbetransported 		 = "true",
		iscommander              = true,
		needed_cover             = 2,
		death_sounds             = "generic",
		factionname	             = "Federation of Kala",
		hpoverride               = hp,
		buildcostenergyoverride  = buildCostEnergy,
		nofriendlyfire	         = "1",
		normaltex               = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
	},
}

--------------------------------------------------------------------------------

weaponDefs                 = {

	particlebeamcannon                 = {
		accuracy                 = 0,
		avoidFeature             = false,
		avoidFriendly            = false,
		collideFeature           = false,
		collideFriendly          = false,
		commandfire              = true,
		explosionGenerator       = "custom:genericshellexplosion-small",
		coreThickness            = 0.1,
		duration                 = 0.8,
		energypershot            = 500,
		fallOffRate              = 0.1,
		fireStarter              = 50,
		interceptedByShieldType  = 4,
		soundstart               = "weapons/Sci Fi Assault Rifle 7.wav",

		minintensity             = 1,
		impulseFactor            = 0,
		name                     = "Something with Flames",
		range                    = 300,
		burst                    = 10,
		burstrate                = 0.1,
		reloadtime               = 1,
		WeaponType               = [[LaserCannon]],
		rgbColor                 = "1 0.5 0",
		rgbColor2                = "1 1 1",
		thickness                = 2,
		tolerance                = 1000,
		turret                   = true,
		texture1                 = "shot",
		texture2                 = "empty",
		weaponVelocity           = 1000,
		sprayangle				 = 200,
		customparams             = {
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 30,
		},
	},

	particlebeamcannon_up1                 = {
		accuracy                 = 0,
		avoidFeature             = false,
		avoidFriendly            = false,
		collideFeature           = false,
		collideFriendly          = false,
		commandfire              = true,
		explosionGenerator       = "custom:genericshellexplosion-small",
		coreThickness            = 0.1,
		duration                 = 0.8,
		energypershot            = 1000,
		fallOffRate              = 0.1,
		fireStarter              = 50,
		interceptedByShieldType  = 4,
		soundstart               = "weapons/Sci Fi Assault Rifle 7.wav",

		minintensity             = 1,
		impulseFactor            = 0,
		name                     = "Something with Flames",
		range                    = 500,
		burst                    = 10,
		burstrate                = 0.1,
		reloadtime               = 2.5,
		WeaponType               = [[LaserCannon]],
		rgbColor                 = "1 0.5 0",
		rgbColor2                = "1 1 1",
		thickness                = 4,
		tolerance                = 1000,
		turret                   = true,
		texture1                 = "shot",
		texture2                 = "empty",
		weaponVelocity           = 1000,
		sprayangle				 = 200,
		customparams             = {
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 40,
		},
	},

	particlebeamcannon_up2                 = {
		accuracy                 = 0,
		avoidFeature             = false,
		avoidFriendly            = false,
		collideFeature           = false,
		collideFriendly          = false,
		commandfire              = true,
		explosionGenerator       = "custom:genericshellexplosion-medium",
		coreThickness            = 0.1,
		duration                 = 0.8,
		energypershot            = 2500,
		fallOffRate              = 0.1,
		fireStarter              = 50,
		interceptedByShieldType  = 4,
		soundstart               = "weapons/Sci Fi Assault Rifle 7.wav",

		minintensity             = 1,
		impulseFactor            = 0,
		name                     = "Something with Flames",
		range                    = 600,
		burst                    = 10,
		burstrate                = 0.1,
		reloadtime               = 7.5,
		WeaponType               = [[LaserCannon]],
		rgbColor                 = "1 0.5 0",
		rgbColor2                = "1 1 1",
		thickness                = 6,
		tolerance                = 1000,
		turret                   = true,
		texture1                 = "shot",
		texture2                 = "empty",
		weaponVelocity           = 1000,
		sprayangle				 = 200,
		customparams             = {
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 810,
		},
	},

	particlebeamcannon_up3                 = {
		accuracy                 = 0,
		avoidFeature             = false,
		avoidFriendly            = false,
		collideFeature           = false,
		collideFriendly          = false,
		commandfire              = true,
		explosionGenerator       = "custom:genericshellexplosion-large",
		coreThickness            = 0.1,
		duration                 = 0.8,
		energypershot            = 5000,
		fallOffRate              = 0.1,
		fireStarter              = 50,
		interceptedByShieldType  = 4,
		soundstart               = "weapons/Sci Fi Assault Rifle 7.wav",

		minintensity             = 1,
		impulseFactor            = 0,
		name                     = "Something with Flames",
		range                    = 700,
		burst                    = 10,
		burstrate                = 0.1,
		reloadtime               = 15,
		WeaponType               = [[LaserCannon]],
		rgbColor                 = "1 0.5 0",
		rgbColor2                = "1 1 1",
		thickness                = 8,
		tolerance                = 1000,
		turret                   = true,
		texture1                 = "shot",
		texture2                 = "empty",
		weaponVelocity           = 1000,
		sprayangle				 = 200,
		customparams             = {
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 7050,
		},
	},

	particlebeamcannon_up4                 = {
		accuracy                 = 0,
		avoidFeature             = false,
		avoidFriendly            = false,
		collideFeature           = false,
		collideFriendly          = false,
		commandfire              = true,
		explosionGenerator       = "custom:genericshellexplosion-large",
		coreThickness            = 0.1,
		duration                 = 0.8,
		energypershot            = 10000,
		fallOffRate              = 0.1,
		fireStarter              = 50,
		interceptedByShieldType  = 4,
		soundstart               = "weapons/Sci Fi Assault Rifle 7.wav",

		minintensity             = 1,
		impulseFactor            = 0,
		name                     = "Something with Flames",
		range                    = 900,
		burst                    = 10,
		burstrate                = 0.1,
		reloadtime               = 30,
		WeaponType               = [[LaserCannon]],
		rgbColor                 = "1 0.5 0",
		rgbColor2                = "1 1 1",
		thickness                = 12,
		tolerance                = 1000,
		turret                   = true,
		texture1                 = "shot",
		texture2                 = "empty",
		weaponVelocity           = 1000,
		sprayangle				 = 200,
		customparams             = {
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 24000,
		},
	},
}
