unitDef                    = {

	--mobileunit 
	transportbyenemy             = false;

	--**


	acceleration                 = 1,
	brakeRate                    = 0.24,
	buildCostEnergy              = 0,
	buildCostMetal               = buildCostMetal,
	buildDistance                = buildDistance,
	builder                      = false,
	buildTime                    = 5,
	buildPic					 = "healstation.png",
	category                     = "BUILDING",
	description                  = [[Summoning Beacon]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = "commnuke_up4",
	footprintX                   = 8,
	footprintZ                   = 8,
	fireState			         = "0",
	iconType                     = "supportbuilding",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	levelground                  = true,
	maxDamage                    = 600,
	maxSlope                     = 90,
	maxWaterDepth                = 0,
	metalmake                    = 0,
	metalStorage                 = 0,
	moveState			         = "2",
	name                         = humanName,
	objectName                   = objectName,
	script			             = script,
	radarDistance                = 0,
	--radarDistanceJam           = 20,
	repairable		             = false,
	selfDestructAs               = "commnuke_up4",
	showNanoSpray                = true,
	sightDistance                = 50,
	smoothAnim                   = true,
	unitname                     = unitName,
	--usePieceCollisionVolumes	 = true,
	upright                      = true,
	yardmap						 = "yyyy yooy yooy yyyy",
	sfxtypes                     = { 
		pieceExplosionGenerators = { 
			"deathceg3", 
			"deathceg4", 
		}, 

		explosiongenerators      = {
			"custom:nanoorb",
			"custom:emptydirt",
			"custom:blacksmoke",
		},
	},
	--buildoptions                 = buildlist,
	sounds                       = {
		underattack              = "other/unitsunderattack1",
		ok                       = {
			"ack",
		},
		select                   = {
			"unitselect",
		},
	},
	customParams                 = {
		unittype				  = "building",
		hpoverride               = hp,
		canbetransported 		 = "false",
		needed_cover             = 2,
		death_sounds             = "generic",
		energycorecollect        = true,
		normaltex               = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "Neutral",
		
		-- groundtexselectimg    = ":nc:bitmaps/icons/repairzone.png",
		-- groundtexselectxsize  = 1000, 
		-- groundtexselectzsize  = 1000, 	
	},
	useGroundDecal                = true,
	BuildingGroundDecalType       = "factorygroundplate.dds",
	BuildingGroundDecalSizeX      = 8,
	BuildingGroundDecalSizeY      = 8,
	BuildingGroundDecalDecaySpeed = 0.9,
}