--------------------------------------------------------------------------------

local unitName                    = "lozsuperjericho"

--------------------------------------------------------------------------------

local techrequired				 = [[tech2]]

local buildCostMetal 			  = 900
local maxDamage					  = buildCostMetal * 12.5

local unitDef                     = {
	activateWhenBuilt             = true,
	buildAngle                    = 4096,
	buildCostEnergy               = 0,
	buildCostMetal                = buildCostMetal,
	builder                       = false,
	buildTime                     = 1,
	canAttack                     = false,
	canstop                       = "1",
	category                      = "BUILDING",
	damageModifier                = 0.2,
	description                   = [[]],
	energyStorage                 = 0,
	energyUse                     = 0,
	explodeAs                     = "hugeBuildingExplosionGenericBlue",
	footprintX                    = 2,
	footprintZ                    = 2,
	floater			              = false,
	--iconType                      = "defenseturret",
	idleAutoHeal                  = .5,
	idleTime                      = 2200,
	maxDamage                     = maxDamage,
	maxSlope                      = 60,
	maxWaterDepth                 = 0,
	mass				          = 1000,
	metalStorage                  = 0,
	name                          = "",
	onOffable					  = true,
	objectName                    = "empty.s3o",
	script			              = "empty_lus.lua",
	repairable		              = false,
	selfDestructAs                = "hugeBuildingExplosionGenericBlue",
	selfDestructCountdown         = 0,
	side                          = "ARM",
	sightDistance                 = 0,
	smoothAnim                    = true,
	TEDClass                      = "FORT",
	unitname                      = unitName,
	workerTime                    = 0,
	yardMap                       = "o",

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
			"turretselect",
		},
	},

	weapons                       = {
		[1]                       = {
			def                   = "shield",
		},
	},

	customParams                  = {
		RequireTech				 = techrequired,
		unittype				  = "building",
		unitrole 				  = "Support Building",
		needed_cover              = 1,
		death_sounds              = "generic",
		factionname	              = "Neutral",
	},
	useGroundDecal                = false,
	BuildingGroundDecalType       = "factorygroundplate.dds",
	BuildingGroundDecalSizeX      = 5,
	BuildingGroundDecalSizeY      = 5,
	BuildingGroundDecalDecaySpeed = 0.9,
}
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]     = unitDef })

--------------------------------------------------------------------------------
