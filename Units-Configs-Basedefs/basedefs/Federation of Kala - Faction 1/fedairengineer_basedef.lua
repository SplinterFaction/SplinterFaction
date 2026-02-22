unitDef                    = {
	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	-- Fix Spring's Awful Defaults for Planes
	-- Flight Characteristics Settings

	-- Generic Air Tags
	canFly                = true,
	canSubmerge           = false,
	factoryHeadingTakeoff = true,
	collide               = false,
	hoverAttack           = true,
	airStrafe             = true,
	cruiseAlt             = 150,
	airHoverFactor        = -1.0,
	bankingAllowed        = true,
	useSmoothMesh         = true,
	canLoopbackAttack     = false,

	-- Advanced Air Tags
	wingDrag              = 0.07,
	wingAngle             = 0.08,
	frontToSpeed          = 0.1,
	speedToFront          = 0.07,
	crashDrag             = 0.005,
	maxBank               = 0.8,
	maxPitch              = 0.45,
	turnRadius            = 500.0,
	verticalSpeed         = 10.0,
	maxAileron            = 0.015,
	maxElevator           = 0.01,
	maxRudder             = 0.004,
	maxAcc                = 0.065,

	useSmoothMesh		= false,

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	buildCostEnergy         = 2500,
	buildCostMetal          = 0.1,
	buildDistance           = buildDistance,
	builder                 = true,
	buildTime               = 5,
	buildpic                = buildpic,
	canAttack               = true,
	canGuard                = true,
	canHover                = true,
	canMove                 = true,
	canPatrol               = true,
	CanAssist               = true,
	canBeAssisted           = true,
	CanCapture              = true,
	CanRepair               = true,
	canRestore              = true,
	canBuild                = true,
	canGuard                = true,
	canHover                = true,
	canMove                 = true,
	canPatrol               = true,
	canreclaim              = true,
	category                = "AIR",
	description             = [[Builds Units]],
	energyMake              = 0,
	energyStorage           = 0,
	energyUse               = 0,
	explodeAs               = explodeAs,
	footprintX              = footprintx,
	footprintZ              = footprintz,
	iconType                = "tankengineer",
	idleAutoHeal            = .5,
	idleTime                = 2200,
	leaveTracks             = false,
	maxDamage               = maxDamage,
	maxVelocity             = 2,
	maxWaterDepth           = 10,
	metalStorage            = 0,
	name                    = humanName,
	objectName              = objectName,
	script                  = script,
	radarDistance           = 0,
	repairable              = false,
	selfDestructAs          = explodeAs,
	showNanoSpray           = false,
	sightDistance           = 300,
	smoothAnim              = true,
	transportbyenemy        = false;
	unitname                = unitName,
	workerTime              = workertime,
	TerraformSpeed          = 2147000,
	--------------
	-- Movement --
	--------------
	acceleration 				 = 2,
	brakeRate                    = 0.1,
	turnrate 				 	 = 600,
	--------------
	--------------
	sfxtypes                = { 
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
	buildoptions = fedt1buildlist,
	sounds       = {
		underattack = "units_under_attack",
		ok          = {
			"ack",
		},
		select                   = {
			"unitselect",
		},
	},
	customParams                 = {
		unittype         = "air",
		unitrole		 = "Builder",
		area_mex_def     = areamexdef,
		requiretech      = requiretech,
		supply_cost      = 1,
		canbetransported = "true",
		death_sounds     = "generic",
		nofriendlyfire   = "1",
		noenergycost     = false,
		--removerepair     = "true",
		normaltex        = "unittextures/lego2skin_explorernormal.dds",
		buckettex        = "unittextures/lego2skin_explorerbucket.dds",
		factionname      = "Federation of Kala",
	},
}