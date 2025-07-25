--------------------------------------------------------------------------------

local unitName                    = "cloakingtower"

--------------------------------------------------------------------------------

local armortype					 = [[building]]

local techrequired				 = [[tech2]]

local buildCostMetal 			  = 250

local unitDef                     = {
	activateWhenBuilt             = true,
	buildAngle                    = 16384,
	buildCostEnergy               = 0,
	buildCostMetal                = buildCostMetal,
	builder                       = false,
	buildTime                     = 5,
	category                      = "BUILDING",
	description                   = [[Generates a Cloaking Field]],
	energyMake                    = 0,
	energyStorage                 = 0,
	energyUse                     = 0,
	explodeAs                     = "smallBuildingExplosionGenericPurple",
	footprintX                    = 2,
	footprintZ                    = 2,
	iconType                      = "structurecounterintelt2",
	idleAutoHeal                  = .5,
	idleTime                      = 2200,
	maxDamage                     = 100,
	maxSlope                      = 60,
	maxWaterDepth                 = 0,
	metalStorage                  = 0,
	name                          = "Cloaking Tower",
	objectName                    = "ejammer3.s3o",
	script						  = "ejammer3.cob",
	onoffable                     = true,
	radarDistanceJam              = 300,
	repairable		              = false,
	selfDestructAs                = "smallBuildingExplosionGenericPurple",
	side                          = "CORE",
	sightDistance                 = 500,
	smoothAnim                    = true,
	sonarDistance                 = 0,
	unitname                      = unitName,
	workerTime                    = 0,
	yardMap                       = "oooo oooo oooo oooo",

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
		},
	},

	sounds                        = {
		underattack               = "unitsunderattack1",
		select                    = {
			"gdradar",
		},
	},
	customParams                  = {
		RequireTech				 = techrequired,
		unittype				  = "building",
		unitrole				  = "Support Building",
		cannotcloak               = false,
		needed_cover              = 3,
		death_sounds              = "generic",
		armortype                 = armortype,
		normaltex                = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                 = "unittextures/lego2skin_explorerbucket.dds",
		
		factionname	              = "Federation of Kala",
		
		area_cloak = 1, -- Can this unit emit a cloaking field?
		area_cloak_upkeep = 0, -- How much energy does it cost to maintain the cloaking field?
		area_cloak_radius = 300, -- How large is the cloaking field?
		--area_cloak_grow_rate = 200, -- When the cloaking field is turned on, how fast does the field expand to it's full size?
		--area_cloak_shrink_rate = 200, -- When the cloaking field is turned off, how fast does the field shrink to nothingness?
		area_cloak_decloak_distance = 100, -- How close does something have to be in order to decloak a unit within a cloaking shield?
		area_cloak_init = true, -- Start up the cloak shield the moment the unit is built?
		area_cloak_draw = true, -- No idea what this does
		area_cloak_self = true, -- Does the cloak shield cloak the unit emitting it?

		-- Begin unit rings
		ring_color = "1,1,0,0.5",
		ring_radius = "300",
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


--------------------------------------------------------------------------------

return lowerkeys({ [unitName]     = unitDef })

--------------------------------------------------------------------------------
