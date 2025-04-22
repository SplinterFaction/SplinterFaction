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
	description                  = [[Repair Tower]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = "mediumBuildingExplosionGenericGreen",
	footprintX                   = 4,
	footprintZ                   = 4,
	fireState			         = "0",
	iconType                     = "structuresupportt2",
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
	selfDestructAs               = "mediumBuildingExplosionGenericGreen",
	showNanoSpray                = true,
	sightDistance                = 50,
	smoothAnim                   = true,
	unitname                     = unitName,
	--usePieceCollisionVolumes	 = true,
	upright                      = true,
	workerTime                   = workerTime,
	capturespeed                 = 0,
	TerraformSpeed               = 2147000,
	ReclaimSpeed                 = 0,
	repairspeed                  = 0.3125,
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
		build					 = "miscfx/buildstart.wav",
		underattack              = "units_under_attack",
		ok                       = {
			"ack",
		},
		select                   = {
			"unitselect",
		},
	},
	customParams                 = {
		RequireTech				 = tech,
		unittype				  = "building",
		canbetransported 		 = "false",
		needed_cover             = 2,
		death_sounds             = "generic",
		energycorecollect        = true,
		normaltex               = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "Neutral",
		retreatRangeDAI			 = buildDistance*2,
		areaheal_radius          = "500",
		areaheal_amount          = "100",
		areaheal_delayafterdamage = "5", -- 5 seconds after damage before healing resumes

		-- Begin unit rings
		ring_color = "0,1,0,0.05",
		ring_radius = "500",
		ring_linewidth = "10",
		ring_divs = "128",
		ring_alwaysshow = "true",
		ring_texture = "LuaUI/Images/customringtextures/green_ring_fill.dds", -- texture overlay (super clean & fast)
		ring_texsize = "1024", -- size of texture quad in world units

	},
	useGroundDecal                = true,
	BuildingGroundDecalType       = "factorygroundplate.dds",
	BuildingGroundDecalSizeX      = 8,
	BuildingGroundDecalSizeY      = 8,
	BuildingGroundDecalDecaySpeed = 0.9,
}