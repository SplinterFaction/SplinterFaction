unitDef                     = {
	buildAngle                    = 2048,
	buildCostEnergy               = 0,
	buildCostMetal                = 10,
	builder                       = false,
	buildTime                     = 5,
	canAttack                     = false,
	canstop                       = false,
	canwait                       = false,

	-- Cloaking

	cancloak		              = true,
	cloakCost		              = 0,
	cloakCostMoving	              = 0,
	minCloakDistance              = 100,
	decloakOnFire	              = true,
	decloakSpherical              = true,
	initCloaked		              = true,

	-- End Cloaking

	category                      = "BUILDING",
	collisionVolumeTest           = "1",
	description                   = [[Seismic Sensor]],
	energyStorage                 = 0,
	energyUse                     = 0,
	explodeAs                     = "smallBuildingExplosionGeneric",
	footprintX                    = 1,
	footprintZ                    = 1,
	floater			              = false,
	idleAutoHeal                  = .5,
	idleTime                      = 2200,
	iconType                      = "structureintelt0",
	maxDamage                     = 625,
	maxSlope                      = 60,
	maxWaterDepth                 = 0,
	metalStorage                  = 0,
	name                          = humanName,
	objectName                    = objectName,
	script						  = script,
	radarDistance                 = 0,
	seismicDistance               = 300,
	repairable		              = false,
	selfDestructAs                = "smallBuildingExplosionGeneric",
	side                          = "CORE",
	sightDistance                 = 250,
	smoothAnim                    = true,
	unitname                      = unitName,
	workerTime                    = 0,
	yardMap                       = "y",

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
			"other/gdradar",
		},
	},
	customParams                  = {
		unittype				  = "building",
		unitrole				  = "Seismic Sensor",
		--supply_cost               = supply,
		death_sounds              = "generic",
		normaltex                 = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                 = "unittextures/lego2skin_explorerbucket.dds",
		factionname	              = "Neutral",
		

		-- Begin unit rings
		ring_color = "1,1,0,0.5",
		ring_radius = "100",
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