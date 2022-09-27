--------------------------------------------------------------------------------

local unitName                    = "supplydepot"

--------------------------------------------------------------------------------

local armortype					 = [[building]]
local storage					  = 100
local supplygranted				  = 5

local buildCostMetal 			  = 50
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

	description                   = [[Provides +]] .. supplygranted .. [[ Supply • Provides +]] .. storage .. [[ Metal/Energy Storage]],
	energyStorage                 = storage,
	metalStorage                 = storage,
	energyUse                     = 0,
	explodeAs                     = "smallBuildingExplosionGenericPurple",
	footprintX                    = 3,
	footprintZ                    = 3,
	idleAutoHeal                  = .5,
	idleTime                      = 2200,
	icontype                      = "supportbuilding",
	maxDamage                     = maxDamage,
	maxSlope                      = 50,
	maxWaterDepth                 = 5000,
	--metalStorage                  = storage,
	name                          = "Supply/Storage Depot",
	objectName                    = "storage.s3o",
	script			              = "estorage3.cob",
	radarDistance                 = 0,
	repairable		              = false,
	selfDestructAs                = "smallBuildingExplosionGenericPurple",
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
			"custom:skyhatelasert0",
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
		supply_granted            = supplygranted,
		death_sounds              = "generic",
		armortype                 = "building", 
		noenergycost			  = true,
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
