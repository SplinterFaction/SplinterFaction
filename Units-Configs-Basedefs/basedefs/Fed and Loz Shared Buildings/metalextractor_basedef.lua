unitDef                     = {

	activateWhenBuilt             = true,
	buildAngle                    = 2048,
	buildCostEnergy               = 0,
	buildCostMetal                = buildCostMetal,
	buildingMask				  = 4,
	builder                       = false,
	buildTime                     = 5,
	buildPic					  = "emetalextractor.png",
	canAttack			          = false,
	category                      = "BUILDING",
	description                   = [[Generates Metal from Resource Nodes]], --This value is set in alldefspost
	energyStorage                 = 100,
	energyUse                     = energyUse, --This value is set in alldefspost
	explodeAs                     = explodeAsSelfSAs,
	footprintX                    = 5,
	footprintZ                    = 5,
	iconType                      = iconType,
	idleAutoHeal                  = .5,
	idleTime                      = 2200,
	levelground                   = true,
	maxDamage                     = buildCostMetal * 12.5,
	maxSlope                      = 90,
	maxWaterDepth                 = 5000,
	metalStorage                  = 100,
	makesmetal                    = metalMultiplier, --This value is set in alldefspost
	name                          = humanName, --This value is set in alldefspost
	objectName                    = objectName,
	script						  = script,
	onoffable                     = true,
	radarDistance                 = 0,
	repairable		              = false,
	selfDestructAs                = explodeAsSelfSAs,
	selfDestructCountdown         = 15,
	side                          = "CORE",
	sightDistance                 = 200,
	smoothAnim                    = true,
	unitName                      = unitName,
	workerTime                    = 0,
	yardMap                       = "yoooy yoooy yoooy yoooy yoooy",
	sfxtypes                      = { 
		pieceExplosionGenerators  = { 
			"deathceg3", 
			"deathceg4", 
		}, 

		explosiongenerators       = {
			"custom:blacksmoke",
			primaryCEG,
			skyhateceg,
		},
	},
	sounds                        = {
		underattack               = "units_under_attack",
		select                    = {
			"gdmex",
		},
		activate                  = "mexactivate",
		deactivate                = "mexdeactivate",
	},
	weapons                       = {
	},
	customParams                  = {
		RequireTech				  = tech,
		unittype				  = "building",
		unitrole				  = "Economy",
		metal_maker               = true,
		metal_extractor           = true, --Keeping this flag for compatibility
		iseco                     = 1,
		needed_cover              = 3,
		death_sounds              = "generic",
		armortype                 = armortype,
		noenergycost			  = noenergycost,
		normaltex                = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                 = "unittextures/lego2skin_explorerbucket.dds",
		factionname	              = faction,
		
	},
	useGroundDecal                = true,
	BuildingGroundDecalType       = "factorygroundplate.dds",
	BuildingGroundDecalSizeX      = 9,
	BuildingGroundDecalSizeY      = 9,
	BuildingGroundDecalDecaySpeed = 0.9,
}