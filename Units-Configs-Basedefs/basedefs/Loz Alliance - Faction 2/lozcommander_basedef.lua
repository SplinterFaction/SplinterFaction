unitDef                    = {

	--mobileunit 
	transportbyenemy             = false; 
	--**

	acceleration                 = 0.2,
	brakeRate                    = 1,
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
	objectName                   = objectname,
	script			             = script,
	radarDistance                = 0,
	repairable		             = false,
	selfDestructAs               = selfdestructas,
	showPlayerName	             = true,
	showNanoSpray                = true,
	sightDistance                = 500,
	smoothAnim                   = true,
	stealth			             = true,
	seismicSignature             = 2,
	turnInPlace                  = true,
	turnRate                     = 5000,
	unitname                     = unitName,
	upright                      = false,
	workerTime                   = workertime,
	capturespeed                 = 0.25,
	TerraformSpeed               = 2147000,
	ReclaimSpeed                 = 1,	-- 0.03125 =  1 hp per second
	repairspeed                  = 0.5,
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
			onlyTargetCategory    = "GROUND BUILDING",
		},
		[2]                      = {
			def                  = weapon2,
		},

	},
	customParams                 = {
		unittype				 = "mobile",
		unitrole				 = "Commander",
		area_mex_def			 = areamexdef,
		ProvideTech              = techprovided,
		RequireTech				 = techrequired,
		canbetransported 		 = "true",
		iscommander              = true,
		hpoverride               = hp,
		needed_cover             = 2,
		death_sounds             = "generic",
		factionname	             = "Loz Alliance",

		nofriendlyfire	         = "1",
		normaltex               = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
	},
}

--------------------------------------------------------------------------------

weaponDefs                 = {
	commrailgun               = {
		avoidFriendly          = false,
		avoidFeature 		   = false,
		collideFriendly        = false,
		collideFeature         = false,
		cegTag                 = "railgun",
		rgbColor               = "0.133 0 0.4",
		rgbColor2              = "0.75 0.75 0.75",
		explosionGenerator     = "custom:genericshellexplosion-medium-sparks-burn",
		energypershot          = 0,
		fallOffRate            = 0,
		duration			   = 0.25,
		impulseFactor          = 0,
		interceptedByShieldType  = 4,
		name                   = "Railgun",
		range                  = 500,
		reloadtime             = 2,
		--projectiles			   = 5,
		weaponType		       = "LaserCannon",
		soundStart             = "weapons/roachrailgun.wav",
		texture1               = "shot",
		texture2               = "empty",
		coreThickness          = 0.4,
		thickness              = 6,
		tolerance              = 10000,
		turret                 = true,
		weaponTimer            = 1,
		weaponVelocity         = 2000,
		customparams             = {
			expl_light_color	= blue, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 20,
		},
	},

	commshield                        = {

		Smartshield               = true,
		Exteriorshield            = true,
		Visibleshield             = false,
		Visibleshieldrepulse      = false,
		ShieldStartingPower       = 0,
		Shieldenergyuse           = 0,
		Shieldradius              = shieldradius,
		Shieldpower               = 8250,
		Shieldpowerregen          = 150,
		Shieldpowerregenenergy    = 0,
		rechargeDelay		  	  = 80,
		Shieldintercepttype       = 4,
		Shieldgoodcolor           = "0.0 0.2 1.0",
		Shieldbadcolor            = "1.0 0 0",
		Shieldalpha              = 0.2,

		texture1		          = "shield4",

		visibleShieldHitFrames    = 1,
		weaponType                = [[Shield]],
		damage                    = {
			default               = 1,
		},
	},

	commrailgun_up1               = {
		avoidFriendly          = false,
		avoidFeature 		   = false,
		collideFriendly        = false,
		collideFeature         = false,
		cegTag                 = "railgun",
		rgbColor               = "0.133 0 0.4",
		rgbColor2              = "0.75 0.75 0.75",
		explosionGenerator     = "custom:genericshellexplosion-medium-sparks-burn",
		energypershot          = 0,
		fallOffRate            = 0,
		duration			   = 0.25,
		impulseFactor          = 0,
		interceptedByShieldType  = 4,
		name                   = "Railgun",
		range                  = 645,
		reloadtime             = 2.3,
		--projectiles			   = 5,
		weaponType		       = "LaserCannon",
		soundStart             = "weapons/reaperrailgun.wav",
		texture1               = "shot",
		texture2               = "empty",
		coreThickness          = 0.4,
		thickness              = 6,
		tolerance              = 10000,
		turret                 = true,
		weaponTimer            = 1,
		weaponVelocity         = 2000,
		customparams             = {
			expl_light_color	= blue, -- As a string, RGB
			expl_light_radius	= mediumExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 45,
		},
	},

	commshield_up1                        = {

		Smartshield               = true,
		Exteriorshield            = true,
		Visibleshield             = false,
		Visibleshieldrepulse      = false,
		ShieldStartingPower       = 0,
		Shieldenergyuse           = 0,
		Shieldradius              = shieldradius,
		Shieldpower               = 14000,
		Shieldpowerregen          = 200,
		Shieldpowerregenenergy    = 0,
		rechargeDelay		  	  = 60,
		Shieldintercepttype       = 4,
		Shieldgoodcolor           = "0.0 0.2 1.0",
		Shieldbadcolor            = "1.0 0 0",
		Shieldalpha              = 0.2,

		texture1		          = "shield4",

		visibleShieldHitFrames    = 1,
		weaponType                = [[Shield]],
		damage                    = {
			default               = 1,
		},
	},

	commrailgun_up2               = {
		avoidFriendly          = false,
		avoidFeature 		   = false,
		collideFriendly        = false,
		collideFeature         = false,
		cegTag                 = "railgun",
		burst				   = 3,
		burstrate			   = 0.3,
		rgbColor               = "0.133 0 0.4",
		rgbColor2              = "0.75 0.75 0.75",
		explosionGenerator     = "custom:genericshellexplosion-medium-sparks-burn",
		energypershot          = 0,
		fallOffRate            = 0,
		duration			   = 0.25,
		impulseFactor          = 0,
		interceptedByShieldType  = 4,
		name                   = "Railgun",
		range                  = 900,
		reloadtime             = 5.6,
		--projectiles			   = 5,
		weaponType		       = "LaserCannon",
		soundStart             = "weapons/mammothrailgun.wav",
		texture1               = "shot",
		texture2               = "empty",
		coreThickness          = 0.4,
		thickness              = 6,
		tolerance              = 10000,
		turret                 = true,
		weaponTimer            = 1,
		weaponVelocity         = 2000,
		customparams             = {
			expl_light_color	= blue, -- As a string, RGB
			expl_light_radius	= mediumExplosion, -- In Elmos
			expl_light_life		= mediumExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 50,
		},
	},

	commshield_up2                        = {

		Smartshield               = true,
		Exteriorshield            = true,
		Visibleshield             = false,
		Visibleshieldrepulse      = false,
		ShieldStartingPower       = 0,
		Shieldenergyuse           = 0,
		Shieldradius              = shieldradius,
		Shieldpower               = 23000,
		Shieldpowerregen          = 325,
		Shieldpowerregenenergy    = 0,
		rechargeDelay		  	  = 60,
		Shieldintercepttype       = 4,
		Shieldgoodcolor           = "0.0 0.2 1.0",
		Shieldbadcolor            = "1.0 0 0",
		Shieldalpha              = 0.2,

		texture1		          = "shield4",

		visibleShieldHitFrames    = 1,
		weaponType                = [[Shield]],
		damage                    = {
			default               = 1,
		},
	},

	commrailgun_up3               = {
		avoidFriendly          = false,
		avoidFeature 		   = false,
		collideFriendly        = false,
		collideFeature         = false,
		cegTag                 = "railgun",
		burst				   = 4,
		burstrate			   = 0.25,
		rgbColor               = "0.133 0 0.4",
		rgbColor2              = "0.75 0.75 0.75",
		explosionGenerator     = "custom:genericshellexplosion-medium-sparks-burn",
		energypershot          = 0,
		fallOffRate            = 0,
		duration			   = 0.25,
		impulseFactor          = 0,
		interceptedByShieldType  = 4,
		name                   = "Railgun",
		range                  = 900,
		reloadtime             = 5.6,
		--projectiles			   = 5,
		weaponType		       = "LaserCannon",
		soundStart             = "weapons/silverbacksmallrailguns.wav",
		texture1               = "shot",
		texture2               = "empty",
		coreThickness          = 0.4,
		thickness              = 6,
		tolerance              = 10000,
		turret                 = true,
		weaponTimer            = 1,
		weaponVelocity         = 2000,
		customparams             = {
			expl_light_color	= blue, -- As a string, RGB
			expl_light_radius	= largeExplosion, -- In Elmos
			expl_light_life		= mediumExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 60,
		},
	},

	commshield_up3                        = {

		Smartshield               = true,
		Exteriorshield            = true,
		Visibleshield             = false,
		Visibleshieldrepulse      = false,
		ShieldStartingPower       = 0,
		Shieldenergyuse           = 0,
		Shieldradius              = shieldradius,
		Shieldpower               = 28500,
		Shieldpowerregen          = 500,
		Shieldpowerregenenergy    = 0,
		rechargeDelay		  	  = 40,
		Shieldintercepttype       = 4,
		Shieldgoodcolor           = "0.0 0.2 1.0",
		Shieldbadcolor            = "1.0 0 0",
		Shieldalpha              = 0.2,

		texture1		          = "shield4",

		visibleShieldHitFrames    = 1,
		weaponType                = [[Shield]],
		damage                    = {
			default               = 1,
		},
	},

	commrailgun_up4               = {
		avoidFriendly          = false,
		avoidFeature 		   = false,
		collideFriendly        = false,
		collideFeature         = false,
		cegTag                 = "railgun",
		burst				   = 5,
		burstrate			   = 0.2,
		rgbColor               = "0.133 0 0.4",
		rgbColor2              = "0.75 0.75 0.75",
		explosionGenerator     = "custom:genericshellexplosion-medium-sparks-burn",
		energypershot          = 0,
		fallOffRate            = 0,
		duration			   = 0.25,
		impulseFactor          = 0,
		interceptedByShieldType  = 4,
		name                   = "Railgun",
		range                  = 1100,
		reloadtime             = 5.6,
		--projectiles			   = 5,
		weaponType		       = "LaserCannon",
		soundStart             = "weapons/silverbackrailgun.wav",
		texture1               = "shot",
		texture2               = "empty",
		coreThickness          = 0.4,
		thickness              = 6,
		tolerance              = 10000,
		turret                 = true,
		weaponTimer            = 1,
		weaponVelocity         = 2000,
		customparams             = {
			expl_light_color	= blue, -- As a string, RGB
			expl_light_radius	= largeExplosion, -- In Elmos
			expl_light_life		= mediumExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 80,
		},
	},

	commshield_up4                        = {

		Smartshield               = true,
		Exteriorshield            = true,
		Visibleshield             = false,
		Visibleshieldrepulse      = false,
		ShieldStartingPower       = 0,
		Shieldenergyuse           = 0,
		Shieldradius              = shieldradius,
		Shieldpower               = 42000,
		Shieldpowerregen          = 1000,
		Shieldpowerregenenergy    = 0,
		rechargeDelay		  	  = 20,
		Shieldintercepttype       = 4,
		Shieldgoodcolor           = "0.0 0.2 1.0",
		Shieldbadcolor            = "1.0 0 0",
		Shieldalpha              = 0.2,

		texture1		          = "shield4",

		visibleShieldHitFrames    = 1,
		weaponType                = [[Shield]],
		damage                    = {
			default               = 1,
		},
	},
}
