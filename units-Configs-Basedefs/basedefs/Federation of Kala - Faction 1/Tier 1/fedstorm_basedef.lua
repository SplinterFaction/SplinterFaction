unitDef                    = {

	--mobileunit 
	transportbyenemy             = false;
	--**

	acceleration                 = 1,
	brakeRate                    = 1,
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
	iconType                     = "mbt",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	leaveTracks                  = false,
	maxDamage                    = 120,
	maxSlope                     = 26,
	maxVelocity                  = 2.8,
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
	--  turnInPlace              = false,
	--  turnInPlaceSpeedLimit    = 5.5,
	turnInPlace                  = true,
	turnRate                     = 1000,
	--  turnrate                 = 475,
	unitname                     = unitName,
	--usePieceCollisionVolumes	 = true,
	upright                      = true,
	workerTime                   = 0,

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
			def                  = "sniper",
--			mainDir = "0 0 1", -- x:0 y:0 z:1 => that's forward!
--			maxAngleDif = 70,
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "GROUND BUILDING",
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
		corpse                   = "energycore",
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
		explosionGenerator        = "custom:genericshellexplosion-small-sparks-burn",
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
		soundstart                = "weapons/snipershot.wav",
		soundHit                  = "explosions/explode5.wav",
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
			default               = 60,
		},
	},
}
