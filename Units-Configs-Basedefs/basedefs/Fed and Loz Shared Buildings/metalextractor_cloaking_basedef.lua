unitDef                     = {

	activateWhenBuilt             = true,
	buildAngle                    = 2048,
	buildCostEnergy               = 0,
	buildCostMetal                = buildCostMetal,
	buildingMask				  = 0,
	builder                       = false,
	buildTime                     = 5,
	buildPic					  = "emetalextractor.png",
	canAttack			          = false,
	category                      = "BUILDING",
	description                   = [[Generates Metal from Resource Nodes]],
	energyStorage                 = 100,
	energyUse                     = energyUse,
	explodeAs                     = explodeAsSelfSAs,
	makesMetal                    = 0,
	footprintX                    = 5,
	footprintZ                    = 5,
	iconType                      = "economy",
	idleAutoHeal                  = .5,
	idleTime                      = 2200,
	maxDamage                     = buildCostMetal * 12.5,
	maxSlope                      = 90,
	maxWaterDepth                 = 5000,
	metalStorage                  = 100,
	metalMake                     = 0,
	name                          = humanName,
	objectName                    = objectName,
	script						  = script,
	onoffable                     = true,
	radarDistance                 = 0,
	repairable		              = false,
	selfDestructAs                = explodeAsSelfSAs,
	selfDestructCountdown         = 15,
	side                          = "CORE",
	sightDistance                 = 200,
	smoothAnim                    = true,
	unitName                      = unitName,
	workerTime                    = 0,
	yardMap                       = "yoooy yoooy yoooy yoooy yoooy",

	--------------
	-- Cloaking --
	--------------
	cancloak		             = true,
	cloakCost		             = 0,
	cloakCostMoving	             = 0,
	minCloakDistance             = 300,
	decloakOnFire	             = false,
	decloakSpherical             = true,
	initCloaked		             = true,
	--------------
	--------------

	sfxtypes                      = { 
		pieceExplosionGenerators  = { 
			"deathceg3", 
			"deathceg4", 
		}, 

		explosiongenerators       = {
			"custom:blacksmoke",
			primaryCEG,
			skyhateceg,
		},
	},
	sounds                        = {
		underattack               = "units_under_attack",
		select                    = {
			"other/gdmex",
		},
	},
	weapons                       = {
	},
	customParams                  = {
		RequireTech				  = tech,
		unittype				  = "building",
		unitrole				  = "Economy",
		metal_extractor			  = metalMultiplier,
		iseco                     = 1,
		needed_cover              = 3,
		death_sounds              = "generic",
		armortype                 = armortype,
		noenergycost			  = noenergycost,
		normaltex                = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                 = "unittextures/lego2skin_explorerbucket.dds",
		factionname	              = "Neutral",
		corpse                   = "energycore",

		area_cloak = area_cloak, -- Can this unit emit a cloaking field?
		area_cloak_upkeep = area_cloak_upkeep, -- How much energy does it cost to maintain the cloaking field?
		area_cloak_radius = area_cloak_radius, -- How large is the cloaking field?
		area_cloak_grow_rate = area_cloak_grow_rate, -- When the cloaking field is turned on, how fast does the field expand to it's full size?
		area_cloak_shrink_rate = area_cloak_shrink_rate, -- When the cloaking field is turned off, how fast does the field shrink to nothingness?
		area_cloak_decloak_distance = area_cloak_decloak_distance, -- How close does something have to be in order to decloak a unit within a cloaking shield?
		area_cloak_init = area_cloak_init, -- Start up the cloak shield the moment the unit is built?
		area_cloak_draw = area_cloak_draw, -- No idea what this does
		area_cloak_self = area_cloak_self, -- Does the cloak shield cloak the unit emitting it?

	},
	useGroundDecal                = true,
	BuildingGroundDecalType       = "factorygroundplate.dds",
	BuildingGroundDecalSizeX      = 9,
	BuildingGroundDecalSizeY      = 9,
	BuildingGroundDecalDecaySpeed = 0.9,
}