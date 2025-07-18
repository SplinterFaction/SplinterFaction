
unitDef                      = {
	activatewhenbuilt              = true,
	buildAngle                     = 1024,
	buildCostEnergy                = 0,
	buildCostMetal                 = buildCostMetal,
	builder                        = true,
	buildTime                      = 5,
	canBeAssisted                  = true,
	canGuard                       = true,
	canMove                        = true,
	canPatrol                      = true,
	canReclaim		               = false,
	canstop                        = true,
	category                       = "BUILDING",
	levelground                    = false,
	description                    = [[Builds Ships]],
	energyStorage                  = 0,
	energyUse                      = 0,
	energyMake                     = 0,
	explodeAs                      = explodeAs,
	footprintX                     = 16,
	footprintZ                     = 16,
	floater                        = true,
	waterline                      = 5,
	iconType                       = "structurefactoryt0",
	idleAutoHeal                   = .5,
	idleTime                       = 2200,
	maxDamage                      = 100,
	maxSlope                       = 60,
	minWaterDepth                  = 40,
	maxWaterDepth                  = 5000,
	metalStorage                   = 0,
	metalMake                      = 0,
	moveState					   = 0,
	name                           = humanName,
	objectName                     = objectName,
	script			               = script,
	radarDistance                  = 0,
	repairable		               = false,
	selfDestructAs                 = explodeAs,
	showNanoSpray                     = true,
	sightDistance                  = 388,
	smoothAnim                     = true,
	TEDClass                       = "PLANT",
	unitname                       = unitName,
	--  unitRestricted	           = 1,
	workerTime                     = workertime,
	yardMap                        = "cccccccccccccccc cccccccccccccccc cccccccccccccccc cccccccccccccccc cccccccccccccccc cccccccccccccccc cccccccccccccccc cccccccccccccccc cccccccccccccccc cccccccccccccccc cccccccccccccccc cccccccccccccccc cccccccccccccccc cccccccccccccccc cccccccccccccccc cccccccccccccccc",
	--  usePieceCollisionVolumes   = true,
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
	buildoptions                   = buildlist,
	sounds                         = {
		underattack                = "units_under_attack",
		select                     = {
			"other/gdfactoryselect",
		},
	},
	customParams                   = {
		unittype				  = "building",
		unitrole 				  = "Factory",
		RequireTech              = tech,
		death_sounds               = "generic",
		normaltex                 = "unittextures/lego2skin_explorernormal.dds",
		buckettex                  = "unittextures/lego2skin_explorerbucket.dds",
		factionname					= faction,
		
		decloakradiushalved		 = true,
		--	ProvideTech            = "1 Powergrid",
		--    ProvideTechRange     = "1500",
		--	groundtexselectimg     = ":nc:bitmaps/power/powergrid.png",
		--	groundtexselectxsize   = 1500, -- optional
		--    groundtexselectzsize = 1500, -- optional
	},
	useGroundDecal                 = false,
}