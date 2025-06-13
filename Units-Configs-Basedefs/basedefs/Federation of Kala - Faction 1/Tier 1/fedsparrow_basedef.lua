unitDef                    = {
	acceleration                 = 0.1,
	airStrafe                    = false,
	brakeRate                    = 0.1,
	buildCostEnergy              = 1800,
	buildCostMetal               = 0,
	builder                      = false,
	buildTime                    = 2.5,
	canAttack                    = true,
	canFly                       = true,

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Fix Spring's Awful Defaults for Planes
-- Flight Characteristics Settings

	maxVelocity        = 14,     -- Your defined top speed
	acceleration       = 0.4,    -- How quickly it reaches that speed
	maxAcc             = 1.0,    -- Affects responsiveness to course corrections

	turnRadius         = 80,     -- Lower = tighter turns. 80 is tight for this speed

	wingDrag           = 0.06,   -- Too low = unrealistic glide; too high = stalls
	wingAngle          = 0.07,   -- Lift. Higher = more responsive, but twitchier

	crashDrag          = 0.005,  -- Fine to leave as-is

	maxBank            = 0.7,   -- How far it tilts in turns. 0.7–0.8 = fast-fighter style
	maxPitch           = 0.55,   -- How fast it can nose up/down

	verticalSpeed      = 3.5,    -- Limits climbing/dive rate. Good value for quick altitude change

	maxAileron         = 0.012,  -- Controls roll rate (used to bank). Don't go crazy high
	maxElevator        = 0.012,  -- Controls pitch (up/down)
	maxRudder          = 0.002,  -- Yaw rate — don't set too high or pathing breaks


	useSmoothMesh		= true,

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	
	canGuard                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = true,
	category                     = "AIR",
	collide                      = false,
	cruiseAlt                    = 150,
	description                  = [[Interceptor]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = "smallExplosionGenericRed",
	footprintX                   = 2,
	footprintZ                   = 2,
	floater                      = true,
	hoverAttack                  = false,
	iconType                     = "airaat1",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	canLoopbackAttack            = true,
	maxDamage                    = 670,
	maxSlope                     = 90,
	maxWaterDepth                = 0,
	metalStorage                 = 0,
	name                         = humanName,
	objectName                   = objectName,
	script			             = script,
	repairable		             = false,
	selfDestructAs               = "smallExplosionGenericRed",
	side                         = "CORE",
	sightDistance                = 800,
	smoothAnim                   = true,
	stealth                      = false,
	transportbyenemy             = false;
	turnRate                     = 5,
	unitname                     = unitName,
	upright						 = true,
	workerTime                   = 0,
	sfxtypes                     = { 
		pieceExplosionGenerators = { 
			"deathceg3", 
			"deathceg4", 
		}, 

		explosiongenerators      = {
			"custom:jetstrail",
			"custom:blacksmoke",
		},
	},
	sounds                       = {
		underattack              = "units_under_attack",
		ok                       = {
			"ack",
		},
		select                   = {
			"unitselect",
		},
	},

	weapons                      = {
		[1]                      = {
			def                  = "particlebeamcannon",
			onlyTargetCategory	 = "AIR",
			mainDir = "0 0 1",
			maxAngleDif = 200,
		},
		--[2]                      = {
		--	def                  = "particlebeamcannon",
		--	onlyTargetCategory	 = "AIR",
		--	mainDir = "0 0 1",
		--	maxAngleDif = 200,
		--},
		--[[
			float mainDir default: {0.0, 0.0, 1.0} i.e. forwards
				A vector representing the firing direction of this weapon if it has a limited firing arc. Used in conjunction with maxAngleDif (See Gamedev:WeaponMainDir).

			float maxAngleDif default: 360.0
				How wide this weapons limited firing arc is in degrees. Symmetrical about mainDir i.e. 180.0 is 90 degree freedom either way (See Gamedev:WeaponMainDir).

			Example:
			weapons = {
			  {
				def = "weapon1",
				mainDir = "0 0 1", -- x:0 y:0 z:1 => that's forward!
				maxAngleDif = 90, -- 90° from side to side, or 45° from centre to each direction
			  },
			}
		]]--
	},


	customParams                 = {
		unittype				 = "air",
		unitrole				 = "Interceptor",
		death_sounds             = "generic",
		nofriendlyfire           = "1",
		RequireTech              = tech,
		nofriendlyfire	         = "1",
		supply_cost              = 1,
		normaltex                = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "Federation of Kala",
		corpse                   = "energycore",
	},
}

weaponDefs                 = {
	particlebeamcannon                 = {

		accuracy                 = 0,
		AreaOfEffect             = 10,
		avoidFeature             = false,
		avoidFriendly            = false,
		collideFeature           = false,
		collideFriendly          = false,
		canAttackGround		     = false,
		explosionGenerator       = "custom:genericshellexplosion-small",
		coreThickness            = 0.5,
		duration                 = 0.2,
		energypershot            = 0,
		fallOffRate              = 0.01,
		fireStarter              = 50,
		interceptedByShieldType  = 4,
		soundstart               = "Sci Fi Assault Rifle 4",

		minintensity             = 1,
		impulseFactor            = 0,
		name                     = "Something with Flames",
		range                    = 800,
		reloadtime               = 1,
		WeaponType               = [[LaserCannon]],
		rgbColor                 = "0 0 1",
		rgbColor2                = "1 1 1",
		thickness                = 8,
		tolerance                = 1000,
		turret                   = true,
		texture1                 = "shot",
		texture2                 = "empty",
		weaponVelocity           = 3000,
		sprayangle				 = 75,
		customparams             = {
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 60,
		},
	},
}
