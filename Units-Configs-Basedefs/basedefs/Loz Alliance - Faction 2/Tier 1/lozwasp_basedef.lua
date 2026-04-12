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

	maxVelocity        = 8,     -- Your defined top speed
	acceleration        = 0.45,   -- was 0.4
	maxAcc              = 1.35,   -- was 1.0  (biggest “snappy” lever)

	turnRadius          = 70,     -- was 80   (starts committing to turns sooner)

	wingDrag            = 0.062,  -- was 0.06 (tiny bump to keep it from gliding through turns)
	wingAngle           = 0.075,  -- was 0.07 (slightly more lift/authority)

	crashDrag           = 0.005,

	maxBank             = 0.75,   -- was 0.7  (tighter circle)
	maxPitch            = 0.60,   -- was 0.55

	maxAileron          = 0.016,  -- was 0.012 (faster roll-in to bank)
	maxElevator         = 0.014,  -- was 0.012
	maxRudder           = 0.0030, -- was 0.002 (more “bite” without getting weird)

	verticalSpeed       = 3.8,    -- was 3.5

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
			def                  = "laser",
			onlyTargetCategory	 = "AIR",
			mainDir = "0 0 1",
			maxAngleDif = 90,
		},
		--[2]                      = {
		--	def                  = "laser",
		--	onlyTargetCategory	 = "AIR",
		--	mainDir = "0 1 0",
		--	maxAngleDif = 180,
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
		unitguide = [[The Wasp is the Loz Alliance's Tier 1 interceptor, armed with a forward-firing particle beam cannon that hits hard and reloads quickly. Purpose-built to kill aircraft, it cannot engage ground targets and has no business in any other role. What it does, it does extremely well — get it into the airspace and anything flying becomes a problem.]],
		unittype				 = "air",
		unitrole				 = "Interceptor",
		buildmenucategory        = "Skirmisher",
		death_sounds             = "generic",
		nofriendlyfire           = "1",
		RequireTech              = tech,
		nofriendlyfire	         = "1",
		supply_cost              = 1,
		normaltex                = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "Loz Alliance",
		
	},
}

weaponDefs                 = {
	laser                = {
		avoidFriendly          = false,
		avoidFeature 		   = false,
		collideFriendly        = false,
		collideFeature         = false,
		canAttackGround 	   = false,
		cegTag                 = "railgun",
		rgbColor               = "1 0 0",
		rgbColor2              = "1 1 1",
		explosionGenerator     = "custom:genericshellexplosion-small",
		edgeEffectiveness	   = 1,
		energypershot          = 0,
		fallOffRate            = 0,
		duration			   = 0.1,
		impulseFactor          = 0,
		interceptedByShieldType  = 4,
		name                   = "Electromagnetic Pulse Laser",
		range                  = 800,
		reloadtime             = 0.2,
		--projectiles			   = 5,
		weaponType		       = "LaserCannon",
		soundStart             = "Sci Fi Blaster 1",
		texture1               = "shot",
		texture2               = "empty",
		coreThickness          = 0.25,
		thickness              = 8,
		tolerance              = 10000,
		turret                 = true,
		weaponTimer            = 1,
		weaponVelocity         = 3000,
		customparams             = {
			weaponguide = [[A forward-firing particle beam cannon that delivers high single-shot damage to aircraft at long range. Fast refire, excellent tracking — anything airborne that wanders into range is in serious trouble.]],
			expl_light_color	= red, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 16,
		},
	},

	railgun               = {
		avoidFriendly          = false,
		avoidFeature 		   = false,
		collideFriendly        = false,
		collideFeature         = false,
		canAttackGround		   = false,
		cegTag                 = "railgun",
		rgbColor               = "0.133 0 0.4",
		rgbColor2              = "0.75 0.75 0.75",
		explosionGenerator     = "custom:genericshellexplosion-medium",
		energypershot          = 0,
		fallOffRate            = 0,
		duration			   = 0.25,
		impulseFactor          = 0,
		interceptedByShieldType  = 4,
		name                   = "Railgun",
		range                  = 800,
		reloadtime             = 3,
		--projectiles			   = 5,
		weaponType		       = "LaserCannon",
		soundStart             = "roachrailgun",
		texture1               = "shot",
		texture2               = "empty",
		coreThickness          = 0.2,
		thickness              = 6,
		tolerance              = 10000,
		turret                 = true,
		weaponTimer            = 1,
		weaponVelocity         = 2000,
		customparams             = {
			--single_hit		 	 = true,
			expl_light_color	= blue, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 30,
		},
	},
}
