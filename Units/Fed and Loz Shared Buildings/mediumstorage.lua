--------------------------------------------------------------------------------

local unitName                    = "mediumstorage"

--------------------------------------------------------------------------------

local storage					  = 500
local buildCostMetal 			  = 100

local unitDef                     = {
	activateWhenBuilt             = true,
	buildAngle                    = 8196,
	buildCostEnergy               = 0,
	buildCostMetal                = buildCostMetal,
	builder                       = false,
	buildTime                     = 5,
	canAttack			          = false,
	category                      = "BUILDING",

	description                   = [[Provides +]] .. storage .. [[ Metal/Energy Storage]],
	energyStorage                 = storage,
	metalStorage                  = storage,
	energyUse                     = 0,
	explodeAs                     = "mediumBuildingExplosionGenericPurple",
	footprintX                    = 4,
	footprintZ                    = 4,
	idleAutoHeal                  = .5,
	idleTime                      = 2200,
	icontype                      = "supportbuilding",
	maxDamage                     = 1,
	maxSlope                      = 50,
	maxWaterDepth                 = 0,
	--metalStorage                  = storage,
	name                          = "Medium Resource Storage Facility",
	objectName                    = "mediumstorage.s3o",
	script			              = "mediumstorage_lus.lua",
	radarDistance                 = 0,
	repairable		              = false,
	selfDestructAs                = "mediumBuildingExplosionGenericPurple",
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
			"custom:blacksmoke",
			"custom:skyhatelasert2",
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
		needed_cover              = 2,
		death_sounds              = "generic",
		armortype                 = "building",
		RequireTech				  = [[tech2]],
		noenergycost			  = false,
		normaltex                = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                 = "unittextures/lego2skin_explorerbucket.dds",
		factionname	              = "Neutral",
		helptext                  = [[]],
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
