unitDef                    = {

	--mobileunit 
	transportbyenemy             = false; 
	--**

	acceleration                 = 0.2,
	brakeRate                    = 1,
	buildCostEnergy              = 0,
	buildCostMetal               = buildCostMetal,
	buildDistance                = 350,
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
	explodeAs                    = "commnuke",
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
	selfDestructAs               = "commnuke",
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
			def                  = [[railgun_up4]],
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "GROUND BUILDING",
		},
		[2]                      = {
			def                  = [[shield_up4]],
		},
	},
	customParams                 = {
		unittype				  = "mobile",
		unitrole				 = "Commander",
		area_mex_def			 = areamexdef,
		ProvideTech              = techprovided,
		RequireTech				 = techrequired,
		canbetransported 		 = "true",
		iscommander              = true,
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

	commnuke                   = {
		AreaOfEffect              = 1000,
		avoidFriendly             = false,
		avoidFeature              = false,
		cegTag                    = "NUKETRAIL",
		collideFriendly           = false,
		collideFeature            = false,
		commandfire               = true,
		craterBoost               = 0,
		craterMult                = 0,
		edgeeffectiveness		  = 0.1,
		energypershot             = 0,
		explosionGenerator        = "custom:NUKEDATBEWMSMALL",
		fireStarter               = 100,
		flightTime                = 400,

		id                        = 124,
		impulseBoost              = 0,
		impulseFactor             = 0,
		interceptedByShieldType   = 4,

		metalpershot              = 0,
		model                     = "enuke.s3o",
		name                      = "Nuke",
		range                     = 32000,
		reloadtime                = 60,
		weaponType		          = "MissileLauncher",


		smokeTrail                = false,
		soundHit                  = "explosions/explosion_enormous.wav",
		soundStart                = "weapons/nukelaunch.wav",

		--		stockpile                 = true,
		--		stockpileTime             = stockpiletime,
		startVelocity             = 10,
		tracks                    = true,
		turnRate                  = 3000,
		targetable			      = 1,

		weaponAcceleration        = 30,
		weaponTimer               = 15,
		weaponType                = "StarburstLauncher",
		weaponVelocity            = 1000,
		customparams              = {
			death_sounds 		  = "nuke",
			nocosttofire		  = true,
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= 10000, -- In Elmos
			expl_light_life		= 600, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                    = {
			default               = 10000,
		},
	},
}
