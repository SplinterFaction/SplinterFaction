unitDef                     = {
	buildAngle                    = 2048,
	buildCostEnergy               = 0,
	buildCostMetal                = 330,
	builder                       = false,
	buildTime                     = 5,
	canAttack                     = true,
	canstop                       = "1",
	category                      = "BUILDING",
	collisionVolumeTest           = "1",
	description                   = [[Light Anti-Air Turret]],
	energyStorage                 = 0,
	energyUse                     = 0,
	explodeAs                     = "mediumBuildingExplosionGeneric",
	footprintX                    = 2,
	footprintZ                    = 2,
	floater			              = false,
	idleAutoHeal                  = .5,
	idleTime                      = 2200,
	iconType                      = "structureaat1",
	maxDamage                     = 700,
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
	sightDistance                 = 700,
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
			def                  = "machinegun",
			--			mainDir = "0 0 1", -- x:0 y:0 z:1 => that's forward!
			--			maxAngleDif = 70,
			onlyTargetCategory	  = "AIR",
		},
	},
	customParams                  = {
		unittype				  = "building",
		unitrole				  = "Short Range Anti-Air",
		unitrole_sound            = "turret",
		RequireTech				  = tech,
		sightdistanceoverride	 = true,
		--supply_cost               = supply,
		death_sounds              = "generic",
		normaltex                 = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                 = "unittextures/lego2skin_explorerbucket.dds",
		factionname	              = "Federation of Kala",
		

		-- Begin unit rings
		ring_color = "1,0,0,0.5",
		ring_radius = "600",
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
	machinegun                = {
		areaofeffect           = 50,
		predictboost	       = 1,
		avoidFriendly          = false,
		avoidFeature 		   = false,
		collideFriendly        = false,
		collideFeature         = false,
		canattackground		   = false,
		burnblow               = true,
		burst                  = 15,
		burstrate              = 0.07,
		-- cegTag                 = "railgun",
		explosionGenerator     = "custom:genericshellexplosion-small",
		edgeEffectiveness	   = 1,
		energypershot          = 0,
		fallOffRate            = 0,
		impulseFactor          = 0,
		interceptedByShieldType  = 4,
		name                   = "MachineGun",
		range                  = 700,
		reloadtime             = 1,
		--projectiles			   = 5,
		weaponType		       = "Cannon",
		soundStart             = "scifi_machine_gun_B_burst_05",
		soundtrigger           = true,
		size                   = 3,
		tolerance              = 10000,
		turret                 = true,
		weaponVelocity         = 1500,
		customparams             = {
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 4,
		},
	},
}