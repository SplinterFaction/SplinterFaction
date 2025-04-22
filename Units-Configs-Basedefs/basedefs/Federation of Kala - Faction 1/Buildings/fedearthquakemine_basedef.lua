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
	iconType                      = "structuredefenset1",
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
		underattack               = "units_under_attack",
		select                    = {
			"other/turretselect",
		},
	},
	weapons                       = {
		[1]                       = {
			def                   = "shotgunblast",
			badTargetCategory     = "SHIP",
			onlyTargetCategory    = "GROUND SHIP",
		},
	},
	customParams                  = {
		unittype				  = "building",
		unitrole				  = "Mine",
		unitrole_sound            = "turret",
		decloakradiushalved		  = "true",
		RequireTech				  = tech,
		--supply_cost               = supply,
		death_sounds              = "generic",
		normaltex                 = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                 = "unittextures/lego2skin_explorerbucket.dds",
		factionname	              = "Federation of Kala",
		corpse                   = "energycore",

		-- Begin unit rings
		ring_color = "1,0,0,0.5",
		ring_radius = "200",
		ring_linewidth = "1",
		ring_divs = "128",
		ring_alwaysshow = "false",

	},
	useGroundDecal                = false,
	BuildingGroundDecalType       = "factorygroundplate.dds",
	BuildingGroundDecalSizeX      = 6,
	BuildingGroundDecalSizeY      = 6,
	BuildingGroundDecalDecaySpeed = 0.9,
}

weaponDefs = {
	shotgunblast                = {
		predictboost	       = 1,
		avoidFriendly          = false,
		avoidFeature 		   = false,
		collideFriendly        = false,
		collideFeature         = false,
		canattackground		   = false,
		burnblow               = true,
		burst                  = 10,
		burstrate              = 0.001,
		-- cegTag                 = "railgun",
		explosionGenerator     = "custom:genericshellexplosion-small",
		edgeEffectiveness	   = 1,
		energypershot          = 0,
		fallOffRate            = 0,
		impulseFactor          = 0,
		interceptedByShieldType  = 4,
		name                   = "Shotgun Mine",
		range                  = 200,
		reloadtime             = 10,
		--projectiles			   = 5,
		weaponType		       = "Cannon",
		soundStart             = "shotgunmine",
		soundtrigger           = true,
		size                   = 1,
		sprayangle             = 500,
		tolerance              = 10000,
		turret                 = true,
		weaponVelocity         = 400,
		customparams             = {
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 35,
		},
	},
}