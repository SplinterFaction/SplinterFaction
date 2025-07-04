unitDef                      = {

	activatewhenbuilt              = false,
	buildAngle                     = 1024,
	buildCostEnergy                = 0,
	buildCostMetal                 = buildCostMetal,
	builder                        = true,
	buildTime                      = 5,
	buildpic					   = "eamphibfac.png",
	canBeAssisted                  = true,
	canGuard                       = true,
	canMove                        = true,
	canPatrol                      = true,
	canReclaim		               = false,
	canstop                        = true,
	category                       = "BUILDING NOTAIR AMPHIB",
	--   collisionVolumeOffsets    = "0 20 0",
	--   collisionVolumeScales     = "238 92 128",
	--   collisionVolumeTest       = 1,
	--   collisionVolumeType       = "box",
	description                    = [[Build a Tech Facility to unlock units. Build Supply Depots to increase your army size.]],
	energyStorage                  = 0,
	energyUse                      = 0,
	energyMake                     = 0,
	explodeAs                      = "hugeBuildingExplosionGenericBlue",
	footprintX                     = 8,
	footprintZ                     = 8,
	iconType                       = "factory",
	idleAutoHeal                   = .5,
	idleTime                       = 2200,
	maxDamage                      = maxDamage,
	maxSlope                       = 25,
	maxWaterDepth                  = 5000,
	metalStorage                   = 0,
	metalMake                      = 0,
	name                           = humanName,
	objectName                     = objectName,
	script			               = script,
	radarDistance                  = 0,
	repairable		               = false,
	selfDestructAs                 = "hugeBuildingExplosionGenericBlue",
	showNanoSpray                  = true,
	side                           = "CORE",
	sightDistance                  = 388,
--	SonarDistance                  = 175,
	smoothAnim                     = true,
	TEDClass                       = "PLANT",
	unitname                       = unitName,
	--  unitRestricted	           = 1,
	workerTime                     = 1,
	yardMap                        = "cccccccc cccccccc cccccccc cccccccc cccccccc cccccccc cccccccc cccccccc cccccccc ",
	--  usePieceCollisionVolumes   = true,

	useGroundDecal                 = true,
	BuildingGroundDecalType        = "factorygroundplate.dds",
	BuildingGroundDecalSizeX       = 18,
	BuildingGroundDecalSizeY       = 18,
	BuildingGroundDecalDecaySpeed  = 0.9,
	sfxtypes                       = { 
		pieceExplosionGenerators   = { 
			"deathceg3", 
			"deathceg4", 
		}, 

		explosiongenerators        = {
			"custom:nanoorb",
			"custom:nano",
			"custom:blacksmoke",
			"custom:fusionreactionbasic",
		},
	},
	buildoptions = amphibFactoryBuildList,
	sounds                         = {
		underattack                = "units_under_attack",
		select                     = {
			"other/gdfactoryselect",
		},
	},
	customParams                   = {
		unittype				  = "factory",
		death_sounds               = "generic",
		armortype                 = "building", 
		normaltex                 = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                  = "unittextures/lego2skin_explorerbucket.dds",
		factionname	               = "ateran",
		
		--	ProvideTech            = "1 Powergrid",
		--    ProvideTechRange     = "1500",
		--	groundtexselectimg     = ":nc:bitmaps/power/powergrid.png",
		--	groundtexselectxsize   = 1500, -- optional
		--    groundtexselectzsize = 1500, -- optional
	},
}
