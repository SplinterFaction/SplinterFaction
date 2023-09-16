--------------------------------------------------------------------------------

local unitName                    = "condenser"

--------------------------------------------------------------------------------

local storage					  = 2000
local supplygranted               = 100
local buildCostMetal 			  = 400

local unitDef                     = {
	activateWhenBuilt             = true,
	buildAngle                    = 8196,
	buildCostEnergy               = 0,
	buildCostMetal                = buildCostMetal,
	builder                       = false,
	buildTime                     = 5,
	canAttack			          = false,
	category                      = "BUILDING",

	description                   = [[Provides +]] .. storage .. [[ Metal/Energy Storage and Provides +]] .. supplygranted .. [[ Supply]],
	energyStorage                 = storage,
	metalStorage                  = storage,
	energyUse                     = 0,
	explodeAs                     = "mediumBuildingExplosionGenericPurple",
	footprintX                    = 6,
	footprintZ                    = 6,
	idleAutoHeal                  = .5,
	idleTime                      = 2200,
	icontype                      = "structurestoraget1",
	maxDamage                     = 1,
	maxSlope                      = 50,
	maxWaterDepth                 = 0,
	--metalStorage                  = storage,
	name                          = "Resource Storage Facility and Supply Depot",
	objectName                    = "condenser.s3o",
	script			              = "condenser_lus.lua",
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
		simpleaiunittype          = "storage",
		iseco                     = 1,
		needed_cover              = 2,
		death_sounds              = "generic",
		armortype                 = "building",
		supply_granted            = supplygranted,
		RequireTech				  = [[tech1]],
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
