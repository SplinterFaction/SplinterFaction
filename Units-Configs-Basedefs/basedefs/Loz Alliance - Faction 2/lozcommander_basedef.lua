unitDef                    = {
	--mobileunit 
	transportbyenemy             = false; 
	--**
	buildCostEnergy              = 0,
	buildCostMetal               = buildCostMetal,
	buildDistance                = builddistance,
	builder                      = true,
	buildTime                    = 2.5,
	buildpic					 = buildpicture,
	capturable		             = false,
	CanAttack			         = true,
	CanAssist			         = true,
	canBeAssisted                = true,
	CanCapture                   = true,
	CanRepair			         = true,
	canRestore					 = true,

	cantBeTransported            = true,

	canGuard                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canreclaim		             = true,
	canstop                      = true,
	category                     = "GROUND",
	description                  = [[Builds Units]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = explodeas,
	footprintX                   = footprintx,
	footprintZ                   = footprintz,
	iconType                     = "commander",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	levelground                  = true,
	maxDamage                    = 1,
	maxSlope                     = 180,
	maxVelocity                  = maxvelocity,
	maxReverseVelocity           = 1,
	maxWaterDepth                = 5000,
	metalmake                    = 0,
	metalStorage                 = 0,
	movementClass                = movementclass,
	moveState			         = "0",
	name                         = humanname,
	noChaseCategories	         = "NOTAIR SUPPORT VTOL AMPHIB",
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
	TerraformSpeed               = 2147000,
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

	--------------------------
	-- Skillshot (aka DGun) --
	--------------------------
	noAutoFire                   = true,
	fireState                    = 0,
	canManualFire                = true,
	--------------------------
	--------------------------

	sfxtypes                     = {
		pieceExplosionGenerators = { 
			"deathceg3", 
			"deathceg4", 
		}, 
		
		explosiongenerators      = {
			"custom:nanoorb",
			"custom:emptydirt",
			"custom:burnblacksmall",
			"custom:gdhcannon",
		},
	},
	buildoptions                 = buildlist,
	sounds                       = {
		build					 = "miscfx/buildstart",
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
			def                  = weapon1,
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "GROUND BUILDING SHIP",
		},
	},
	customParams                 = {
		unittype				 = "mobile",
		unitrole				 = "Commander",
		area_mex_def			 = areamexdef,
		ProvideTech              = techprovided,
		RequireTech				 = techrequired,
		stockpileLimit           = 5,
		techlevel                = techlevel,
		--hpoverride               = hp,
		iscommander              = true,
		needed_cover             = 2,
		death_sounds             = "commander",
		factionname	             = "Loz Alliance",
		--removeattack             = "true",
		--removerepair             = "true",
		nofriendlyfire	         = "1",
		normaltex               = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		unitguide                = [[Lorem ipsum dolor sit amet consectetur adipiscing elit. Quisque faucibus ex sapien vitae pellentesque sem placerat. In id cursus mi pretium tellus duis convallis. Tempus leo eu aenean sed diam urna tempor. Pulvinar vivamus fringilla lacus nec metus bibendum egestas. Iaculis massa nisl malesuada lacinia integer nunc posuere. Ut hendrerit semper vel class aptent taciti sociosqu. Ad litora torquent per conubia nostra inceptos himenaeos.

Lorem ipsum dolor sit amet consectetur adipiscing elit. Quisque faucibus ex sapien vitae pellentesque sem placerat. In id cursus mi pretium tellus duis convallis. Tempus leo eu aenean sed diam urna tempor. Pulvinar vivamus fringilla lacus nec metus bibendum egestas. Iaculis massa nisl malesuada lacinia integer nunc posuere. Ut hendrerit semper vel class aptent taciti sociosqu. Ad litora torquent per conubia nostra inceptos himenaeos.]],
	},
}

--------------------------------------------------------------------------------

weaponDefs                 = {
	commgun           = {
		avoidFeature             = false,
		avoidFriendly            = false,
		avoidGround				 = false,
		collideFeature           = false,
		collideFriendly          = false,
		coreThickness            = 0.6,
		--	cegTag               = "mediumcannonweapon3",
		duration                 = 0.1,
		edgeeffectiveness        = 0.1,
		energypershot            = 0,
		explosionGenerator       = "custom:genericshellexplosion-small-lightning",
		fallOffRate              = 1,
		fireStarter              = 100,
		impulseFactor            = 0,

		minintensity             = 1,
		name                     = "EMP Blast Wave",
		paralyzer		         = true,
		paralyzetime	         = 2.5,
		range                    = 350,
		reloadtime               = 1,
		WeaponType               = "LaserCannon",
		rgbColor                 = "0 0.2 1",
		rgbColor2                = "1 1 1",
		soundTrigger             = true,
		soundstart               = "lozcommander-beam-short",
		soundHit                 = "phasegun1hit",
		texture1                 = "wave",
		texture2                 = "empty",
		thickness                = 5,
		tolerance                = 1000,
		turret                   = true,
		weaponVelocity           = 1000,
		customparams             = {
			expl_light_color	= purple, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
			single_hit            = "true",
		},
		damage                   = {
			default              = 50,
		},
	},

	commgun_up1               = {
		avoidFeature             = false,
		avoidFriendly            = false,
		avoidGround				 = false,
		collideFeature           = false,
		collideFriendly          = false,
		coreThickness            = 0.6,
		--	cegTag               = "mediumcannonweapon3",
		duration                 = 0.1,
		edgeeffectiveness        = 0.1,
		energypershot            = 0,
		explosionGenerator       = "custom:genericshellexplosion-small-lightning",
		fallOffRate              = 1,
		fireStarter              = 100,
		impulseFactor            = 0,

		minintensity             = 1,
		name                     = "EMP Blast Wave",
		paralyzer		         = true,
		paralyzetime	         = 2.5,
		range                    = 480,
		reloadtime               = 1,
		WeaponType               = "LaserCannon",
		rgbColor                 = "0 0.2 1",
		rgbColor2                = "1 1 1",
		soundTrigger             = true,
		soundstart               = "weapons/fnubeamfire.wav",
		soundHit                 = "explosions/phasegun1hit.wav",
		texture1                 = "wave",
		texture2                 = "empty",
		thickness                = 5,
		tolerance                = 1000,
		turret                   = true,
		weaponVelocity           = 1000,
		customparams             = {
			expl_light_color	= purple, -- As a string, RGB
			expl_light_radius	= mediumExplosion, -- In Elmos
			expl_light_life		= mediumExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
			single_hit            = "true",
			weaponguide         = [[A powerful EMP wave that will stun for a short period of time.]],
		},
		damage                   = {
			default              = 400,
		},
	},

	commgun_up2               = {
		avoidFeature             = false,
		avoidFriendly            = false,
		avoidGround				 = false,
		collideFeature           = false,
		collideFriendly          = false,
		coreThickness            = 0.6,
		--	cegTag               = "mediumcannonweapon3",
		duration                 = 0.1,
		edgeeffectiveness        = 0.1,
		energypershot            = 0,
		explosionGenerator       = "custom:genericshellexplosion-small-lightning",
		fallOffRate              = 1,
		fireStarter              = 100,
		impulseFactor            = 0,

		minintensity             = 1,
		name                     = "EMP Blast Wave",
		paralyzer		         = true,
		paralyzetime	         = 2.5,
		range                    = 700,
		reloadtime               = 3.0,
		WeaponType               = "LaserCannon",
		rgbColor                 = "0 0.2 1",
		rgbColor2                = "1 1 1",
		soundTrigger             = true,
		soundstart               = "weapons/fnubeamfire.wav",
		soundHit                 = "explosions/phasegun1hit.wav",
		texture1                 = "wave",
		texture2                 = "empty",
		thickness                = 5,
		tolerance                = 1000,
		turret                   = true,
		weaponVelocity           = 1000,
		customparams             = {
			expl_light_color	= purple, -- As a string, RGB
			expl_light_radius	= mediumExplosion, -- In Elmos
			expl_light_life		= mediumExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
			single_hit            = "true",
		},
		damage                   = {
			default              = 8010,
		},
	},

	commgun_up3               = {
		avoidFeature             = false,
		avoidFriendly            = false,
		avoidGround				 = false,
		collideFeature           = false,
		collideFriendly          = false,
		coreThickness            = 0.6,
		--	cegTag               = "mediumcannonweapon3",
		duration                 = 0.1,
		edgeeffectiveness        = 0.1,
		energypershot            = 0,
		explosionGenerator       = "custom:genericshellexplosion-small-lightning",
		fallOffRate              = 1,
		fireStarter              = 100,
		impulseFactor            = 0,

		minintensity             = 1,
		name                     = "EMP Blast Wave",
		paralyzer		         = true,
		paralyzetime	         = 2.5,
		range                    = 700,
		reloadtime               = 4,
		WeaponType               = "LaserCannon",
		rgbColor                 = "0 0.2 1",
		rgbColor2                = "1 1 1",
		soundTrigger             = true,
		soundstart               = "weapons/fnubeamfire.wav",
		soundHit                 = "explosions/phasegun1hit.wav",
		texture1                 = "wave",
		texture2                 = "empty",
		thickness                = 5,
		tolerance                = 1000,
		turret                   = true,
		weaponVelocity           = 1000,
		customparams             = {
			expl_light_color	= purple, -- As a string, RGB
			expl_light_radius	= mediumExplosion, -- In Elmos
			expl_light_life		= mediumExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
			single_hit            = "true",
		},
		damage                   = {
			default              = 70005,
		},
	},

	commgun_up4               = {
		avoidFeature             = false,
		avoidFriendly            = false,
		avoidGround				 = false,
		collideFeature           = false,
		collideFriendly          = false,
		coreThickness            = 0.6,
		--	cegTag               = "mediumcannonweapon3",
		duration                 = 0.1,
		edgeeffectiveness        = 0.1,
		energypershot            = 0,
		explosionGenerator       = "custom:genericshellexplosion-small-lightning",
		fallOffRate              = 1,
		fireStarter              = 100,
		impulseFactor            = 0,

		minintensity             = 1,
		name                     = "EMP Blast Wave",
		paralyzer		         = true,
		paralyzetime	         = 2.5,
		range                    = 1100,
		reloadtime               = 5,
		WeaponType               = "LaserCannon",
		rgbColor                 = "0 0.2 1",
		rgbColor2                = "1 1 1",
		soundTrigger             = true,
		soundstart               = "weapons/fnubeamfire.wav",
		soundHit                 = "explosions/phasegun1hit.wav",
		texture1                 = "wave",
		texture2                 = "empty",
		thickness                = 5,
		tolerance                = 1000,
		turret                   = true,
		weaponVelocity           = 1000,
		customparams             = {
			expl_light_color	= purple, -- As a string, RGB
			expl_light_radius	= mediumExplosion, -- In Elmos
			expl_light_life		= mediumExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
			single_hit            = "true",
		},
		damage                   = {
			default              = 263000,
		},
	},
}