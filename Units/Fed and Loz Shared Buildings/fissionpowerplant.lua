--------------------------------------------------------------------------------

local unitName                    = "fissionpowerplant"

--------------------------------------------------------------------------------

local armortype					 = [[building]]
local energyproduced			 = [[25]]

local buildCostMetal 			  = 100
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
	description                   = [[Produces +]] .. energyproduced .. [[ Energy]],
	energyStorage                 = 0,
	energyMake                    = energyproduced,
	explodeAs                     = "mediumBuildingExplosionGenericBlueEMP",
	footprintX                    = 5,
	footprintZ                    = 5,
	icontype                      = "structureenergygeneratort0",
	idleAutoHeal                  = .5,
	idleTime                      = 2200,
	maxDamage                     = maxDamage,
	maxSlope                      = 60,
	maxWaterDepth                 = 0,
	metalStorage                  = 0,
	name                          = "Fission Energy Generator",
	objectName                    = "fissionpowerplant2.s3o",
	script						  = "fissionpowerplant_lus.lua",
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
		iseco                     = 1,
		needed_cover              = 2,
		death_sounds              = "generic",
		RequireTech				 = "tech0",
--		ProvideTech               = powerprovided,
--		ProvideTechRange          = powerradius,
		armortype                 = armortype,
		noenergycost			  = false,
--		supply_granted            = supplygranted,
		normaltex                = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                 = "unittextures/lego2skin_explorerbucket.dds",
		factionname	              = "Neutral",
		
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
