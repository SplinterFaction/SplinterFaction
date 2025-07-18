unitDef                     = {
	buildAngle                    = 2048,
	buildCostEnergy               = 0,
	buildCostMetal                = 1000,
	builder                       = false,
	buildTime                     = 5,
	canAttack                     = true,
	canstop                       = "1",
	category                      = "BUILDING",
	collisionVolumeTest           = "1",
	description                   = [[Long Range Heavy Anti-Air]],
	energyStorage                 = 0,
	energyUse                     = 0,
	explodeAs                     = "mediumBuildingExplosionGeneric",
	footprintX                    = 4,
	footprintZ                    = 4,
	floater			              = false,
	idleAutoHeal                  = .5,
	idleTime                      = 2200,
	iconType                      = "structureaat1",
	maxDamage                     = 750,
	maxSlope                      = 60,
	maxWaterDepth                 = 0,
	metalStorage                  = 0,
	name                          = humanName,
	objectName                    = objectName,
	script						  = script,
	radarDistance                 = 0,
	repairable		              = false,
	selfDestructAs                = "mediumBuildingExplosionGeneric",
	side                          = "CORE",
	sightDistance                 = 500,
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
			"custom:burnblack",
		},
	},
	sounds                        = {
		underattack               = "units_under_attack",
		select                    = {
			"other/turretselect",
		},
	},
	weapons                       = {
		[1]                       = {
			def                   = "rockets",
			onlyTargetCategory    = "AIR",
		},
	},
	customParams                  = {
		unittype				  = "building",
		unitrole				  = "Medium Range Anti-Air",
		unitrole_sound            = "turret",
		sightdistanceoverride	 = true,
		RequireTech				  = tech,
		--supply_cost               = supply,
		death_sounds              = "generic",
		normaltex                 = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                 = "unittextures/lego2skin_explorerbucket.dds",
		factionname	              = "Federation of Kala",
		
	},
	useGroundDecal                = true,
	BuildingGroundDecalType       = "factorygroundplate.dds",
	BuildingGroundDecalSizeX      = 6,
	BuildingGroundDecalSizeY      = 6,
	BuildingGroundDecalDecaySpeed = 0.9,
}

weaponDefs = {
	rockets             = {
		areaofeffect             = 200,
		avoidFriendly            = false,
		avoidFeature             = false,
		collideFriendly          = false,
		collideFeature           = false,
		canAttackGround 		 = false,
		cegTag                   = "gunshiptrail-optimized-longlasting",
		explosionGenerator       = "custom:genericshellexplosion-large",
		energypershot            = 0,
		burst                    = 2,
		burstrate                = 0.5,
		burnblow		         = false,
		fireStarter              = 70,
		impulseFactor            = 0,
		interceptedByShieldType  = 4,
		model                    = "neutralmissilex2.s3o",
		name                     = "Rockets",
		range                    = 1650,
		reloadtime               = 2,
		weaponType		         = "MissileLauncher",
		smokeTrail               = false,
		soundStart               = "sabotlaunch",
		soundHit                 = "explode5",
		-- stockpile                = true,
		-- stockpiletime            = 2,
		startVelocity            = 100,
		tolerance                = 8000,
		turnrate                 = 100000,
		dance                    = 150,
		turret                   = true,
		tracks                   = true,
		weaponAcceleration       = 2000,
		flightTime               = 1,
		weaponVelocity           = 2000,
		customparams             = {
			expl_light_color	= purple, -- As a string, RGB
			expl_light_radius	= largeExplosion, -- In Elmos
			expl_light_life		= mediumExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 270,
		},
	},
}