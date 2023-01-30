unitDef                    = {

	--mobileunit 
	transportbyenemy             = false;
	--**

	buildCostEnergy              = 0,
	buildCostMetal               = 2000,
	builder                      = false,
	buildTime                    = 5,
	buildpic					 = [[fedgoliath.png]],
	canAttack                    = true,
	
	canGuard                     = true,
	canHover                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = "1",
	category                     = "GROUND MASSIVE",
	description                  = [[Main Battle Tank]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = explodeAs,
	footprintX                   = 8,
	footprintZ                   = 8,
	iconType                     = "mbt",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	leaveTracks                  = false,
	maxDamage                    = 75,
	maxSlope                     = 90,
	maxVelocity                  = 2.5,
	maxReverseVelocity           = 1,
	maxWaterDepth                = 10,
	metalStorage                 = 0,
	movementClass                = "WALKERTANK8",
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
	seismicSignature             = 1,
	unitname                     = unitName,
	upright                      = true,
	--usePieceCollisionVolumes	 = true,
	workerTime                   = 0,
	--------------
	-- Movement --
	--------------
	acceleration 				 = 2,
	brakeRate                    = 0.1,
	turninplace 				 = true,
	turninplacespeedlimit 		 = 10,
	turnInPlaceAngleLimit		 = 45,
	turnrate 				 	 = 350,
	--------------
	--------------

	sfxtypes                     = {
		explosiongenerators      = {
			"custom:gdhcannon",
			"custom:emptydirt",
			"custom:blacksmoke",
			"custom:airfactoryhtrail",
		},
		pieceExplosionGenerators = {
			"deathceg3",
			"deathceg4",
		},	
	},

	sounds                       = {
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
			def                  = "particlebeamcannon",
			--mainDir = "0 0 1", -- x:0 y:0 z:1 => that's forward!
			--maxAngleDif = 180,
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "GROUND BUILDING SHIP",
		},
		[2]                      = {
			def                  = "particlebeamcannon",
			--mainDir = "0 0 1", -- x:0 y:0 z:1 => that's forward!
			--maxAngleDif = 180,
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "GROUND BUILDING SHIP",
			slaveto				 = 1,
		},
		[3]                      = {
			def                  = "plasmacannon",
			--mainDir = "0 0 1", -- x:0 y:0 z:1 => that's forward!
			--maxAngleDif = 180,
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "GROUND BUILDING SHIP",
			slaveto				 = 1,
		},
		[4]                      = {
			def                  = "plasmacannon",
			--mainDir = "0 0 1", -- x:0 y:0 z:1 => that's forward!
			--maxAngleDif = 180,
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "GROUND BUILDING SHIP",
			slaveto				 = 1,
		},
	},
	customParams                 = {
		isupgraded			  	 = isUpgraded,
		unittype				 = "mobile",
		unitrole				 = "Main Battle Tank",
		canbetransported 		 = "true",
		needed_cover             = 1,
		death_sounds             = "generic",
		RequireTech              = tech,
		nofriendlyfire	         = true,
		supply_cost              = 1,
		normaltex               = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "Federation of Kala",
		corpse                   = "energycore",
	},
}

weaponDefs                 = {
	plasmacannon                	= {
		AreaOfEffect           = 50,
		avoidFriendly          = false,
		avoidFeature 		   = false,
		collideFriendly        = false,
		collideFeature         = false,
		--cegTag			   = "thudshot",
		--burst				   = 4,
		--burstrate			   = 0.2,
		edgeEffectiveness	   = 1,
		explosionGenerator     = "custom:genericshellexplosion-small",
		energypershot          = 0,
		--duration			   = 0.25,
		highTrajectory		   = 0,
		impulseFactor          = 0,
		interceptedByShieldType  = 4,
		name                   = "Plasma Cannon",
		--noExplode			   = true,
		range                  = 720,
		reloadtime             = 2.8,
		size				   = 8,
		projectiles			   = 4,
		weaponType		       = "Cannon",
		soundStart             = "weapons/ShotGun Boom 101 (Suppressed).wav",
		soundHit	           = "explosions/mediumcannonhit.wav",
		soundTrigger           = true,
		sprayAngle             = 1250,
		tolerance              = 8000,
		turret                 = true,
		weaponTimer            = 1,
		weaponVelocity         = 800,
		customparams             = {
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              =130,
		},
	},
	particlebeamcannon                 = {

		accuracy                 = 0,
		AreaOfEffect             = 10,
		avoidFeature             = false,
		avoidFriendly            = false,
		collideFeature           = false,
		collideFriendly          = false,
		explosionGenerator       = "custom:burnblacksmall",
		coreThickness            = 0.1,
		duration                 = 0.4,
		energypershot            = 0,
		fallOffRate              = 0.1,
		fireStarter              = 50,
		interceptedByShieldType  = 4,
		soundstart               = "weapons/Revolver Single Shot (Suppressed) 2.wav",

		minintensity             = 1,
		impulseFactor            = 0,
		name                     = "Something with Flames",
		range                    = 720,
		reloadtime               = 0.2,
		WeaponType               = [[LaserCannon]],
		rgbColor                 = "1 0.5 0",
		rgbColor2                = "1 1 1",
		thickness                = 8,
		tolerance                = 1000,
		turret                   = true,
		texture1                 = "shot",
		texture2                 = "empty",
		weaponVelocity           = 1000,
		sprayangle				 = 500,
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
}
