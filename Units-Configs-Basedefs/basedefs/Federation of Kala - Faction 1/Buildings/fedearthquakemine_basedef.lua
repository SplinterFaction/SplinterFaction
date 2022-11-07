unitDef                     = {
	buildAngle                    = 2048,
	buildCostEnergy               = 0,
	buildCostMetal                = 50,
	builder                       = false,
	buildTime                     = 5,
	canAttack                     = true,
	canstop                       = "1",

	-- Cloaking

	cancloak		              = true,
	cloakCost		              = 0,
	cloakCostMoving	              = 0,
	minCloakDistance              = 0,
	decloakOnFire	              = true,
	decloakSpherical              = true,
	initCloaked		              = true,

	-- End Cloaking

	category                      = "BUILDING",
	collisionVolumeTest           = "1",
	description                   = [[Stealth Mine]],
	energyStorage                 = 0,
	energyUse                     = 0,
	explodeAs                     = "smallBuildingExplosionGeneric",
	footprintX                    = 2,
	footprintZ                    = 2,
	floater			              = false,
	idleAutoHeal                  = .5,
	idleTime                      = 2200,
	iconType                      = "defenseturret",
	maxDamage                     = 625,
	maxSlope                      = 60,
	maxWaterDepth                 = 0,
	metalStorage                  = 0,
	name                          = humanName,
	objectName                    = objectName,
	script						  = script,
	radarDistance                 = 0,
	repairable		              = false,
	selfDestructAs                = "smallBuildingExplosionGeneric",
	side                          = "CORE",
	sightDistance                 = 100,
	smoothAnim                    = true,
	unitname                      = unitName,
	workerTime                    = 0,
	yardMap                       = "oooo oooo oooo oooo",

	sfxtypes                      = { 
		pieceExplosionGenerators  = { 
			"deathceg3", 
			"deathceg4", 
		}, 

		explosiongenerators       = {
			"custom:gdhcannon",
			"custom:needspower",
			"custom:blacksmoke",
		},
	},
	sounds                        = {
		underattack               = "other/unitsunderattack1",
		select                    = {
			"other/turretselect",
		},
	},
	weapons                       = {
		[1]                       = {
			def                   = "mine",
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "GROUND BUILDING",
		},
	},
	customParams                  = {
		unittype				  = "building",
		unitrole				  = "Mine",
		decloakradiushalved		  = "true",
		RequireTech				  = tech,
		--supply_cost               = supply,
		death_sounds              = "generic",
		normaltex                 = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                 = "unittextures/lego2skin_explorerbucket.dds",
		factionname	              = "Federation of Kala",
		corpse                   = "energycore",
	},
	useGroundDecal                = false,
	BuildingGroundDecalType       = "factorygroundplate.dds",
	BuildingGroundDecalSizeX      = 6,
	BuildingGroundDecalSizeY      = 6,
	BuildingGroundDecalDecaySpeed = 0.9,
}

weaponDefs = {
	mine                    = {
		name                      ="Land Mine",
		AreaOfEffect             = 20,
		avoidFriendly             = false,
		avoidFeature              = false,
		collideFriendly           = false,
		collideFeature            = false,
		canAttackGround           = false,
		cegTag                   = "missiletrail",
		flightTime               = 1.5,

		tolerance                 = 1000,
		turret                    = true,
		impulseFactor             = 0,

		model                    = "missilesmallvlaunch.s3o",
		edgeeffectiveness	      = 1,
		energypershot             = 0,
		range                     = 100,
		reloadtime                = 10,
		weaponvelocity            = 2500,


		smokeTrail               = false,
		tracks                   = true,
		turnrate                 = 200000,

		weaponAcceleration       = 800,
		weaponTimer              = 0.5,
		weaponType               = "StarburstLauncher",
		weaponVelocity           = 2500,
		soundHit                ="explosions/minedetonation.wav",
		soundStart				= "weapons/minewhir.wav",
		explosiongenerator        ="custom:genericshellexplosion-small-white",
		customparams              = {
			nofriendlyfire	      = "true",
			expl_light_color	= red, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},

		damage                    = {
			default               = 150,
		},
	},
}