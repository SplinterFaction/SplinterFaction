unitDef                    = {

	--mobileunit 
	transportbyenemy             = false;
	--**

	acceleration                 = 1,
	brakeRate                    = 1,
	buildCostEnergy              = 0,
	buildCostMetal               = 280,
	builder                      = false,
	buildTime                    = 5,
	buildpic					 = [[fedavalanche.png]],
	canAttack                    = true,
	
	canGuard                     = true,
	canHover                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = "1",
	category                     = "LIGHT NOTAIR RAID",
	description                  = [[Direct Fire Support]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = explodeAs,
	footprintX                   = 3,
	footprintZ                   = 3,
	highTrajectory		   		 = 2,
	iconType                     = "td_lit_lit",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	leaveTracks                  = false,
	maxDamage                    = 75,
	maxSlope                     = 90,
	maxVelocity                  = 2,
	maxReverseVelocity           = 1,
	maxWaterDepth                = 10,
	metalStorage                 = 0,
	movementClass                = "WALKERTANK3",
	name                         = humanName,
	noChaseCategory              = "VTOL",
	objectName                   = objectName,
	script			             = script,
	radarDistance                = 0,
	repairable		             = false,
	selfDestructAs               = explodeAs,
	side                         = "CORE",
	sightDistance                = 650,
	smoothAnim                   = true,
	stealth			             = true,
	seismicSignature             = 1,
	--  turnInPlace              = false,
	--  turnInPlaceSpeedLimit    = 5.5,
	turnInPlace                  = true,
	turnRate                     = 1000,
	--  turnrate                 = 475,
	unitname                     = unitName,
	upright                      = true,
	--usePieceCollisionVolumes	 = true,
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
			def                  = "plasmacannon",
--			mainDir = "0 0 1", -- x:0 y:0 z:1 => that's forward!
--			maxAngleDif = 70,
			badTargetCategory    = "VTOL WALL",
		},
		[2]                      = {
			def                  = "plasmacannon",
			--			mainDir = "0 0 1", -- x:0 y:0 z:1 => that's forward!
			--			maxAngleDif = 70,
			badTargetCategory    = "VTOL WALL",
		},
		[3]                      = {
			def                  = "missile",
			--			mainDir = "0 0 1", -- x:0 y:0 z:1 => that's forward!
			--			maxAngleDif = 70,
			badTargetCategory    = "VTOL WALL",
		},
	},
	customParams                 = {
		unittype				  = "mobile",
		unitrole				 = "Artillery",
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
		AreaOfEffect           = 25,
		avoidFriendly          = false,
		avoidFeature 		   = false,
		collideFriendly        = false,
		collideFeature         = false,
		--cegTag			   = "thudshot",
		burst				   = 4,
		burstrate			   = 0.1,
		edgeEffectiveness	   = 0,
		explosionGenerator     = "custom:genericshellexplosion-small",
		energypershot          = 0,
		--duration			   = 0.25,
		highTrajectory		   = 1,
		impulseFactor          = 0,
		interceptedByShieldType  = 4,
		name                   = "Plasma Cannon",
		--noExplode			   = true,
		range                  = 1300,
		reloadtime             = 10,
		size				   = 2,
		projectiles			   = 4,
		weaponType		       = "Cannon",
		soundStart             = "weapons/bruisercannon.wav",
		soundHit	           = "explosions/mediumcannonhit.wav",
		soundTrigger           = true,
		sprayAngle             = 200,
		tolerance              = 10000,
		turret                 = true,
		weaponTimer            = 1,
		weaponVelocity         = 600,
		customparams             = {
		},
		damage                   = {
			default              = 15.625,
		},
	},

	missile            = {

		AreaOfEffect             = 70,
		avoidFriendly            = false,
		avoidFeature             = false,
		collideFriendly          = false,
		collideFeature           = false,
		cegTag                   = "emissiletanktrail-optimized",
		craterBoost              = 0,
		craterMult               = 0,
		explosionGenerator       = "custom:genericshellexplosion-medium-red",
		energypershot            = 0,
		fireStarter              = 100,
		flightTime               = 7.5,
		impulseBoost             = 0,
		impulseFactor            = 0,
		interceptedByShieldType  = 4,

		model                    = "missilesmallvlaunch.s3o",
		name                     = "Rocket",
		range                    = 1300,
		reloadtime               = 4,
		weaponType		         = "MissileLauncher",


		smokeTrail               = false,
		soundHit                 = "explosions/explode_large.wav",
		soundStart               = "weapons/missile_launch1.wav",

		tracks                   = false,
		turnrate                 = 30000,
		turret                   = true,

		weaponAcceleration       = 400,
		weaponTimer              = 3,
		weaponType               = "StarburstLauncher",
		weaponVelocity           = 400,
		customparams             = {
		},
		damage                   = {
			default              = 400,
		},
	},
}
