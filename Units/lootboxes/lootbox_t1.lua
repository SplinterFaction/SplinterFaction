--------------------------------------------------------------------------------

local unitName                    = "lootbox_t1"

--------------------------------------------------------------------------------

local metalproduced			 = [[4]]

local buildCostMetal 			  = 200
local energyproduced			 = 40
local maxDamage					  = buildCostMetal * 12.5

local unitDef                     = {

	cantBeTransported              = false,

	activateWhenBuilt             = true,
	buildAngle                    = 2048,
	buildCostEnergy               = 0,
	buildCostMetal                = buildCostMetal,
	builder                       = false,
	buildTime                     = 5,
	buildpic					  = "emediumgen.png",
	canAttack			          = false,
	category                      = "BUILDING",
	description                   = [[Produces +]] .. metalproduced .. [[ Metal and +]] .. energyproduced .. [[ Energy]],
	energyStorage                 = 0,
	energyMake                    = energyproduced,
	metalmake                     = metalproduced,
	explodeAs                     = "mediumBuildingExplosionGenericBlueEMP",
	footprintX                    = 3,
	footprintZ                    = 3,
	icontype                      = "economy",
	idleAutoHeal                  = .5,
	idleTime                      = 2200,
	maxDamage                     = maxDamage,
	maxSlope                      = 60,
	maxWaterDepth                 = 0,
	metalStorage                  = 0,
	name                          = "Tier 1 Lootbox",
	objectName                    = "lootbox_t1.s3o",
	script						  = "lootbox_lus.lua",
	onoffable                     = false,
	radarDistance                 = 0,
	repairable		              = false,
	selfDestructAs                = "mediumBuildingExplosionGenericBlueEMP",
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
		unittype				  = "building",
		unitrole				  = "Economy",
		simpleaiunittype          = "energygenerator",
		hpoverride                = 10000,
		iseco                     = 1,
		needed_cover              = 2,
		death_sounds              = "generic",
		normaltex                = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                 = "unittextures/lego2skin_explorerbucket.dds",
		factionname	              = "Neutral",
		corpse                   = "energycore",
		--		groundtexselectimg        = ":nc:bitmaps/power/power.png",
--		groundtexselectimg1       = ":nc:bitmaps/power/power1.png",
--		groundtexselectimg2       = ":nc:bitmaps/power/power2.png",
--		groundtexselectimg3       = ":nc:bitmaps/power/power3.png",
--		groundtexselectimg4       = ":nc:bitmaps/power/power4.png",
--		groundtexselectimg5       = ":nc:bitmaps/power/power5.png",
--		groundtexselectimg6       = ":nc:bitmaps/power/power6.png",
--		groundtexselectxsize      = 400, -- optional
--		groundtexselectzsize      = 400, -- optional
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
