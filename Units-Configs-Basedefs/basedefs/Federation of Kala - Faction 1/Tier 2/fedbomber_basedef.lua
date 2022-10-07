unitDef                    = {
	acceleration                 = 5,
	airStrafe                    = false,
	airHoverFactor				 = -1.0,
	brakeRate                    = 0.1,
	buildCostEnergy              = 0,
	buildCostMetal               = 300,
	builder                      = false,
	buildTime                    = 2.5,
	buildpic					 = "ebomber.png",
	canAttack                    = true,
	canFly                       = true,

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Fix Spring's Awful Defaults for Planes
-- Flight Characteristics Settings

	wingDrag            = 0.07,
	wingAngle           = 0.08,
	frontToSpeed        = 0,    -- New Default
	speedToFront        = 0.1,  -- New Default
	crashDrag           = 0.005,
	maxBank             = 0.7,  -- New Default
	maxPitch            = 0.65, -- New Default
	turnRadius          = 20.0,  -- New Default
	verticalSpeed       = 3.0,
	maxAileron          = 0.025, -- New Default
	maxElevator         = 0.01,
	maxRudder           = 0.004, -- use this to control turn radius around Y axis - Best value for fighters is 0.01
	maxAcc          	= 1.2,    -- OG Default was 0.065
	attackSafetyDistance = 0, --Exists only in version 99.0

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	
	canGuard                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = true,
	category                     = "AIRARMORED VTOL",
	collide                      = true,
	cruiseAlt                    = 100,
	description                  = [[Bomber]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = "largeExplosionGeneric",
	footprintX                   = 2,
	footprintZ                   = 2,
	floater                      = true,
	hoverAttack                  = false,
	iconType                     = "air_bomb",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	loopbackattack               = true,
	maxDamage                    = 670,
	maxSlope                     = 90,
	maxVelocity                  = 6,
	maxWaterDepth                = 0,
	metalStorage                 = 0,
	name                         = humanName,
	objectName                   = objectName,
	script			             = script,
	repairable		             = false,
	selfDestructAs               = "largeExplosionGeneric",
	side                         = "CORE",
	sightDistance                = 1000,
	smoothAnim                   = true,
	stealth                      = false,
	transportbyenemy             = false;
	turnRate                     = 5,
	unitname                     = unitName,
	upright						 = true,
	workerTime                   = 0,
	sfxtypes                     = { 
		pieceExplosionGenerators = { 
			"deathceg3", 
			"deathceg4", 
		}, 

		explosiongenerators      = {
			"custom:jetstrail",
			"custom:blacksmoke",
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
			def                  = "missile",
			-- onlyTargetCategory	 = "BUILDING",
			noChaseCategory      = "VTOL LIGHT ARMORED",
		},
	},
	customParams                 = {
		isupgraded				 = isUpgraded,
		unittype				 = "mobile",
		--    needed_cover       = 2,
		death_sounds             = "generic",
		nofriendlyfire           = "1",
		RequireTech              = tech,
		armortype                = armortype,
		nofriendlyfire	         = "1",
		supply_cost              = 1,
		normaltex                = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "Federation of Kala",
		corpse                   = "energycore",
		retreatRangeDAI			 = 0,
		maxammo					 = 1,
	},
}

weaponDefs                 = {

	missile                      = {
		AreaOfEffect             = 300,
		avoidFriendly            = false,
		avoidFeature             = false,
		collideFriendly          = false,
		collideFeature           = false,
		cegTag                   = "bombertrail-optimized",
		explosionGenerator       = "custom:genericshellexplosion-large-red",
		energypershot            = 0,
		edgeEffectiveness        = 0.1,
		fireStarter              = 70,
		
		id                       = 136,
		impulseBoost             = 0,
		impulseFactor            = 0,
		interceptedByShieldType  = 4,
		
		metalpershot             = 0,
		model                    = "missile.s3o",
		name                     = "Rockets",
		range                    = 400,
		reloadtime               = 6,
		weaponType		         = "MissileLauncher",		
		
		smokeTrail               = false,
		soundHit                 = "other/18402_inferno_xplo.wav",
		soundHitWet				 = "explosions/subhitbomb.wav",
		soundHitVolume	         = 10,
		soundStart               = "weapons/bomberlaunch.wav",
		soundStartVolume         = 10,
		
		startVelocity            = 200,
		tolerance                = 8000,
		turnRate                 = 15000,
		tracks                   = false,
		turret			         = false,
		weaponAcceleration       = 50,
		waterweapon				 = true,
		flightTime               = 10,
		weaponVelocity           = 800,
		customparams             = {
			nofriendlyfire	     = 1,
		},
		damage                   = {
			default              = 500,
		},
	},
	
	bomb  	             = {
		AreaOfEffect             = 150,
		avoidFeature             = false,
		avoidFriendly            = false,
		collideFeature           = false,
		collideFriendly          = false,
		cylinderTargeting		 = 0,
		burst					 = 10,
		burstrate				 = 0.1,
		cegTag                   = "genericshellexplosion-large-sparks-burn",
		energypershot            = 0,
		explosionGenerator       = "custom:genericshellexplosion-medium-red",
		fallOffRate              = 1,
		fireStarter              = 50,
		impulseFactor            = 0,
		minintensity             = "1",
		name                     = "Cluster Bomb",
		range                    = 1000,
		reloadtime               = 6,
		WeaponType               = "Cannon",
		rgbColor                 = "1 0.5 0",
		rgbColor2                = "1 1 1",
		soundTrigger             = true,
		soundstart               = "weapons/bombdrop.wav",
		soundHit                 = "other/18402_inferno_xplo.wav",
		soundHitWet				 = "explosions/subhitbomb.wav",
		sprayangle				 = 5000,
		size					 = 4,
		--texture1                 = "shot",
		--texture2                 = "empty",
		thickness                = 15,
		tolerance                = 7500,
		turret                   = false,
		weaponVelocity           = 150,
		customparams             = {
			nofriendlyfire	     = true,
		}, 
		damage                   = {
			default              = 150,
		},
	},  
}
