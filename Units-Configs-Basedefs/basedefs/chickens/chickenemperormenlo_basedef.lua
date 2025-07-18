unitDef                     = {
	buildAngle                    = 2048,
	buildCostEnergy               = 0,
	buildCostMetal                = 3600,
	builder                       = false,
	buildTime                     = 5,
	canAttack                     = true,
	canstop                       = "1",
	category                      = "BUILDING",
	collisionVolumeTest           = "1",
	description                   = [[Light Anti-Ground Turret]],
	energyStorage                 = 0,
	energyUse                     = 0,
	explodeAs                     = "mediumBuildingExplosionGeneric",
	footprintX                    = 6,
	footprintZ                    = 6,
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
	onlytargetcategory2           = "NOTAIR",
	onlytargetcategory3           = "NOTAIR",
	onlytargetcategory4           = "NOTAIR",
	onlytargetcategory5           = "NOTAIR",
	onlytargetcategory6           = "NOTAIR",
	radarDistance                 = 0,
	repairable		              = false,
	selfDestructAs                = "mediumBuildingExplosionGeneric",
	side                          = "CORE",
	sightDistance                 = 1200,
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
		underattack               = "units_under_attack",
		select                    = {
			"other/turretselect",
		},
	},
	weapons                       = {
		[1]                       = {
			def                   = "particlebeamcannon",
			badTargetCategory     = "BUILDING",
		},
	},
	customParams                  = {
		unittype				  = "building",
		unitrole				  = "Heavy Turret",
		unitrole_sound            = "turret",
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
	particlebeamcannon = {

		accuracy                 = 0,
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
		soundstart               = "fedmenlo-maingun",

		minintensity             = 1,
		impulseFactor            = 0,
		name                     = "Something with Flames",
		range                    = 1200,
		reloadtime               = 0.1,
		WeaponType               = [[LaserCannon]],
		rgbColor                 = "1 0.5 0",
		rgbColor2                = "1 1 1",
		thickness                = 8,
		tolerance                = 1000,
		turret                   = true,
		texture1                 = "shot",
		texture2                 = "empty",
		weaponVelocity           = 1000,
		sprayangle				 = 100,
		customparams             = {
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 400,
		},
	},
}