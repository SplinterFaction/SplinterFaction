--------------------------------------------------------------------------------

local unitName                    = "largestorage"

--------------------------------------------------------------------------------

local storage					  = 5000

local buildCostMetal 			  = 500
local maxDamage					  = buildCostMetal * 12.5

local unitDef                     = {
	activateWhenBuilt             = true,
	buildAngle                    = 8196,
	buildCostEnergy               = 0,
	buildCostMetal                = buildCostMetal,
	builder                       = false,
	buildTime                     = 5,
	canAttack			          = false,
	category                      = "BUILDING NOTAIR ECO",

	description                   = [[Provides +]] .. storage .. [[ Metal/Energy Storage]],
	energyStorage                 = storage,
	metalStorage                 = storage,
	energyUse                     = 0,
	explodeAs                     = "largeBuildingExplosionGenericPurple",
	footprintX                    = 8,
	footprintZ                    = 8,
	idleAutoHeal                  = .5,
	idleTime                      = 2200,
	icontype                      = "supportbuilding",
	maxDamage                     = maxDamage,
	maxSlope                      = 50,
	maxWaterDepth                 = 5000,
	--metalStorage                  = storage,
	name                          = "Large Resource Storage Facility",
	objectName                    = "largestorage.s3o",
	script			              = "largestorage_lus.lua",
	radarDistance                 = 0,
	repairable		              = false,
	selfDestructAs                = "largeBuildingExplosionGenericPurple",
	side                          = "CORE",
	sightDistance                 = 367,
	smoothAnim                    = true,
	unitname                      = unitName,
	workerTime                    = 0,
	yardMap                       = "ooo ooo ooo",

	sfxtypes                      = {
		pieceExplosionGenerators  = {
			"deathceg3",
			"deathceg4",
		},
		
		explosiongenerators       = {
			"custom:blacksmoke",
			"custom:skyhatelasert3",
		},
	},

	sounds                        = {
		underattack               = "other/unitsunderattack1",
		select                    = {
			"other/gdenergy",
		},
	},
	weapons                       = {
	},
	customParams                  = {
		unittype				  = "building",
		unitrole				  = "Economy",
		iseco                     = 1,
		RequireTech				  = [[tech3]],
		needed_cover              = 2,
		death_sounds              = "generic",
		noenergycost			  = true,
		normaltex                = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                 = "unittextures/lego2skin_explorerbucket.dds",
		factionname	              = "Neutral",
		corpse                   = "energycore",
	},
	useGroundDecal                = true,
	BuildingGroundDecalType       = "factorygroundplate.dds",
	BuildingGroundDecalSizeX      = 4,
	BuildingGroundDecalSizeY      = 6,
	BuildingGroundDecalDecaySpeed = 0.9,
}

--------------------------------------------------------------------------------

return lowerkeys({ [unitName]     = unitDef })

--------------------------------------------------------------------------------
