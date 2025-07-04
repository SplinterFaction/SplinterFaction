unitDef                    = {

	--mobileunit 
	transportbyenemy             = false;
	--**

	buildCostEnergy              = 0,
	buildCostMetal               = 95,
	builder                      = false,
	buildTime                    = 5,
	buildpic					 = [[fedstorm.png]],
	canAttack                    = true,
	
	canGuard                     = true,
	canHover                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = "1",
	category                     = "GROUND",
	description                  = [[Light Anti-Tank Skirmisher Bot]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = explodeAs,
	footprintX                   = 2,
	footprintZ                   = 2,
	--highTrajectory		   		 = 2,
	iconType                     = "botassaultt1",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	leaveTracks                  = false,
	maxDamage                    = 120,
	maxSlope                     = 26,
	maxVelocity                  = 3,
	maxReverseVelocity           = 1,
	maxWaterDepth                = 10,
	metalStorage                 = 0,
	movementClass                = "WALKERTANK2",
	name                         = humanName,
	noChaseCategory              = "VTOL",
	objectName                   = objectName,
	script			             = script,	
	radarDistance                = 0,
	repairable		             = false,
	selfDestructAs               = explodeAs,
	side                         = "CORE",
	sightDistance                = 620,
	smoothAnim                   = true,
	stealth			             = true,
	seismicSignature             = 1,
	unitname                     = unitName,
	--usePieceCollisionVolumes	 = true,
	upright                      = true,
	workerTime                   = 0,
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
			def                  = "sniper",
--			mainDir = "0 0 1", -- x:0 y:0 z:1 => that's forward!
--			maxAngleDif = 70,
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "GROUND BUILDING SHIP",
		},
	},
	customParams                 = {
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
	},
}

weaponDefs                 = {
	sniper           = {
		avoidFeature              = false,
		avoidFriendly             = false,
		collideFeature            = false,
		collideFriendly           = false,
		coreThickness             = 0.5,
		--	cegTag                = "mediumcannonweapon3",
		duration                  = 0.15,
		energypershot             = 0,
		explosionGenerator        = "custom:genericshellexplosion-small",
		fallOffRate            	  = 0,
		fireStarter               = 100,
		impulseFactor             = 0,
		interceptedByShieldType   = 4,
		
		minintensity              = "1",
		name                      = "Laser",
		range                     = 500,
		reloadtime                = 1.2,
		WeaponType                = "LaserCannon",
		rgbColor                  = "0 0.5 1",
		rgbColor2                 = "1 1 1",
		soundTrigger              = true,
		soundstart                = "fedstorm-maingun",
		soundHit                  = "explode5",
		texture1                  = "shot",
		texture2                  = "empty",
		thickness                 = 5,
		tolerance                 = 1000,
		turret                    = true,
		weaponVelocity            = 3000,
		customparams              = {
			expl_light_color	= blue, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		}, 
		damage                    = {
			default               = 80,
		},
	},
}
