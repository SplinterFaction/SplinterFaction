--------------------------------------------------------------------------------

local unitName                    = "smallstorage"

--------------------------------------------------------------------------------

local armortype					 = [[building]]
local energyproduced			 = [[0]]
local storage                    = [[200]]

local buildCostMetal 			  = 50
local maxDamage					  = buildCostMetal * 12.5

local unitDef                     = {
	activateWhenBuilt             = true,
	buildAngle                    = 2048,
	buildCostEnergy               = 0,
	buildCostMetal                = buildCostMetal,
	builder                       = false,
	buildTime                     = 5,
	buildpic					  = "emediumgen.png",
	canAttack			          = false,
	category                      = "BUILDING",
	description                   = [[Provides +]] .. storage .. [[ Metal/Energy Storage]],
	energyStorage                 = storage,
	energyMake                    = energyproduced,
	explodeAs                     = "smallBuildingExplosionGenericPurpleEMP",
	footprintX                    = 3,
	footprintZ                    = 3,
	icontype                      = "structurestoraget1",
	idleAutoHeal                  = .5,
	idleTime                      = 2200,
	maxDamage                     = maxDamage,
	maxSlope                      = 60,
	maxWaterDepth                 = 0,
	metalStorage                  = storage,
	name                          = "Small Resource Storage Facility",
	objectName                    = "smallstorage.s3o",
	script						  = "smallstorage_lus.lua",
	onoffable                     = false,
	radarDistance                 = 0,
	repairable		              = false,
	selfDestructAs                = "smallBuildingExplosionGenericPurpleEMP",
	side                          = "CORE",
	sightDistance                 = 367,
	smoothAnim                    = true,
	unitname                      = unitName,
	yardMap                       = "ooo ooo ooo",

	sfxtypes                      = {
		pieceExplosionGenerators  = {
			"deathceg3",
			"deathceg4",
		},
		
		explosiongenerators       = {
			"custom:blacksmoke",
			"custom:empty",
			"custom:skyhatelasert1",
		},
	},

	sounds                        = {
		underattack               = "unitsunderattack1",
		select                    = {
			"gdenergy",
		},
	},
	weapons                       = {
	},
	customParams                  = {
		unitguide = [[The Small Resource Storage Facility provides 200 units each of metal and energy storage in a small footprint at Tier 1. Its primary value is extending the resource buffer available during early-game expansion — preventing income spikes from going to waste and smoothing out the energy fluctuations that come with running multiple production facilities simultaneously.]],
		unittype				  = "building",
		unitrole				  = "Economy",
		buildmenucategory		  = "Economy",
		simpleaiunittype          = "storage",
		iseco                     = 1,
		needed_cover              = 2,
		death_sounds              = "generic",
		armortype                 = "building",
		RequireTech				  = [[tech1]],
		noenergycost			  = false,
		normaltex                = "unittextures/lego2skin_explorernormal.dds",
		buckettex                 = "unittextures/lego2skin_explorerbucket.dds",
		factionname	              = "Neutral",
		helptext                  = [[]],
	},
	useGroundDecal                = true,
	BuildingGroundDecalType       = "factorygroundplate.dds",
	BuildingGroundDecalSizeX      = 5,
	BuildingGroundDecalSizeY      = 5,
	BuildingGroundDecalDecaySpeed = 0.9,
}
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]     = unitDef })

--------------------------------------------------------------------------------
