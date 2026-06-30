--------------------------------------------------------------------------------

local unitName                    = "researchcenter"

--------------------------------------------------------------------------------

local storage					  = 0
local supplygranted               = 0
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

	description                   = [[Generates +1/s Research Points]],
	energyStorage                 = storage,
	metalStorage                  = storage,
	energyUse                     = 250,
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
	name                          = "Research Center",
	objectName                    = "researchcenter.s3o",
	script			              = "researchcenter_lus.lua",
	onoffable                     = true,
	radarDistance                 = 0,
	repairable		              = false,
	selfDestructAs                = "mediumBuildingExplosionGenericPurple",
	sightDistance                 = 100,
	smoothAnim                    = true,
	unitname                      = unitName,
	workerTime                    = 0,
	yardMap                       = "ooggoo ooggoo ooggoo ooggoo ooggoo ooggoo",

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
		underattack               = "unitsunderattack1",
		select                    = {
			"gdenergy",
		},
	},
	weapons                       = {
	},
	customParams                  = {
		unitguide = [[The Research Center uses an immense amount of power for it's research. It must be placed upon a geothermal vent. It's power requirements are so large that the power that it is able to generate from the geothermal vent is completely consumed and it needs to draw from other power sources in order to function.]],
		unittype				  = "building",
		unitrole				  = "Economy",
		buildmenucategory         = "Geothermal",
		simpleaiunittype          = "storage",
		iseco                     = 1,
		needed_cover              = 2,
		death_sounds              = "generic",
		armortype                 = "building",
		RequireTech				  = [[tech1]],
		rp_income                 = "1",    -- research points per second
		--rp_energy_cost            = "500",   -- energy per second; the gadget charges this
		noenergycost			  = false,
		normaltex                = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                 = "unittextures/lego2skin_explorerbucket.dds",
		factionname	              = "Neutral",
		helptext                  = [[]],
		
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
