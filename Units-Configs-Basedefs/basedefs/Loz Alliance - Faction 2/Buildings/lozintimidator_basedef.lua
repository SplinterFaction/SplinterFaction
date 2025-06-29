unitDef                     = {
	buildAngle                    = 2048,
	buildCostEnergy               = 0,
	buildCostMetal                = 10000,
	builder                       = false,
	buildTime                     = 5,
	canAttack                     = true,
	canstop                       = "1",
	category                      = "BUILDING",
	collisionVolumeTest           = "1",
	description                   = [[Long Range Artillery Turret]],
	energyStorage                 = 0,
	energyUse                     = 0,
	explodeAs                     = "hugeBuildingExplosionGeneric",
	footprintX                    = 16,
	footprintZ                    = 16,
	floater			              = false,
	fireState					  = 0,
	idleAutoHeal                  = .5,
	idleTime                      = 2200,
	iconType                      = "defenseturret",
	maxDamage                     = 750,
	maxSlope                      = 60,
	maxWaterDepth                 = 0,
	metalStorage                  = 0,
	name                          = humanName,
	objectName                    = objectName,
	script						  = script,
	radarDistance                 = 0,
	repairable		              = false,
	selfDestructAs                = "hugeBuildingExplosionGeneric",
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
			def                   = "plasmacannon",
			badTargetCategory     = "GROUND SHIP",
			onlyTargetCategory    = "GROUND BUILDING SHIP",
		},
	},
	customParams                  = {
		unittype				  = "building",
		unitrole				  = "Artillery Turret",
		unitrole_sound            = "turret",
		sightdistanceoverride	 = true,
		RequireTech				  = tech,
		--supply_cost               = supply,
		death_sounds              = "generic",
		normaltex                 = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                 = "unittextures/lego2skin_explorerbucket.dds",
		factionname	              = "Loz Alliance",
		

		-- Begin unit rings
		ring_color = "1,0,0,0.5",
		ring_radius = "8000",
		ring_linewidth = "1",
		ring_divs = "128",
		ring_alwaysshow = "false",

	},
	useGroundDecal                = true,
	BuildingGroundDecalType       = "factorygroundplate.dds",
	BuildingGroundDecalSizeX      = 6,
	BuildingGroundDecalSizeY      = 6,
	BuildingGroundDecalDecaySpeed = 0.9,
}

weaponDefs = {
	plasmacannon                	= {
		accuracy               = 1000,
		avoidFriendly          = false,
		avoidFeature 		   = false,
		collideFriendly        = false,
		collideFeature         = false,
		--cegTag			   = "thudshot",
		--burst				   = 4,
		--burstrate			   = 0.2,
		edgeEffectiveness	   = 1,
		explosionGenerator     = "custom:genericshellexplosion-large",
		energypershot          = 0,
		--duration			   = 0.25,
		-- highTrajectory		   = 1,
		impulseFactor          = 0,
		interceptedByShieldType  = 4,
		name                   = "High Explosive Plasma Cannon",
		--noExplode			   = true,
		range                  = 8000,
		reloadtime             = 20,
		size				   = 20,
		weaponType		       = "Cannon",
		soundStart             = "arty3",
		soundHit	           = "mediumcannonhit",
		soundTrigger           = true,
		tolerance              = 8000,
		turret                 = true,
		weaponTimer            = 1,
		weaponVelocity         = 1200,
		customparams             = {
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= hugeExplosion, -- In Elmos
			expl_light_life		= hugeExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 3000,
		},
	},
}