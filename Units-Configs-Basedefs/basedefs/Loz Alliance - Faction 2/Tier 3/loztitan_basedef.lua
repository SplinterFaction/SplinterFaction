unitDef                    = {
	acceleration                 = 0.8,
	brakeRate                    = 0.8,
	buildCostEnergy              = 270000,
	buildCostMetal               = 0,
	builder                      = false,
	buildTime                    = 2.5,
	canAttack                    = true,

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
	cruiseAlt             = 175,
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
	
	canGuard                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = true,
	category                     = "AIR",
	collide                      = false,
	description                  = [[Massive Transport]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = explodeAs,
	footprintX                   = 5,
	footprintZ                   = 5,
	iconType                     = "airtransportt3",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	maxDamage                    = 670,
	maxSlope                     = 90,
	maxVelocity                  = 7,
	maxWaterDepth                = 0,
	metalStorage                 = 0,
	name                         = humanName,
	objectName                   = objectName,
	script			             = script,
	repairable		             = false,
	selfDestructAs               = explodeAs,
	side                         = "CORE",
	sightDistance                = 500,
	smoothAnim                   = true,
	stealth                      = false,
	transportbyenemy             = false;
	turnRate                     = 250,
	unitname                     = unitName,
	upright						 = true,
	workerTime                   = 0,

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	-- Transport specific tags

	transportSize			= 30,
	-- minTransportSize			=
	transportCapacity		= 100,
	transportMass			= 25000,
	-- minTransportMass			=
	-- loadingRadius			=
	unloadSpread				= 10,
	isFirePlatform			= false,
	-- holdSteady				=
	releaseHeld				= true,
	-- cantBeTransported		=
	-- transportByEnemy			=
	transportUnloadMethod	= 0,
	-- fallSpeed				=
	-- unitFallSpeed			=

	--[[
	int transportSize default: 0
		The size of units that the transport can pick up, in terms of the passengers footprintX.

	int minTransportSize default: 0
		The smallest size of unit that the transport can pick up, in terms of the passengers footprintX.

	int transportCapacity default: 0
		The total number of units that the transport can pick up, with each unit multiplied by it's footprintX size. Prior to 101.0 if this tag is not present, then any Script.AttachUnit and Script.DropUnit call in the animation script will be ignored (See Animation-LuaCallouts#Other), in successive versions all units can use Spring.UnitAttach et al regardless of this tag.

	float transportMass default: 100000.0
		The total cumulative mass of passengers the transport can carry.

	float minTransportMass default: 0.0
		The minimum mass passenger the transport can carry.

	float loadingRadius default: 220.0
		How far away in elmos can the transporter pick up and drop units?

	float unloadSpread default: 5.0
		How spread out the passengers are when unloaded. Is multiplied by the passengers radius.

	bool isFirePlatform default: false
		Can transported units still aim and shoot while loaded by this transport?

	bool holdSteady default: false
		If true - passengers are slaved to orientation of transporter attachment piece, if false - passengers are slaved to orientation of transporter body.

	bool releaseHeld default: false
		Does the transporter unload it's passengers when it dies?

	bool cantBeTransported default: false for mobile units, true for structures
		Controls if a unit is transportable at all or not. If false it is overridden by Modrules.lua transportability subtable tags.

	bool transportByEnemy default: true
		Controls if a unit can be transported by an enemy transport. i.e. can it be kidnapped.

	int transportUnloadMethod default: 0
		For air transports. Can be 0 - Land to unload individually, 1 - Flyover drop (i.e. Parachute), or 2 - Land and flood unload all passengers. Can be used on ground transports with mixed results.

	float fallSpeed default: 0.2
		For air transports with transportUnloadMethod = 1. The speed in elmos per second which units will fall at when released from the transport.

	float unitFallSpeed default: 0.0

		Allows you to override fallSpeed for an individual passenger.
	]]--

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------

	sfxtypes                     = { 
		pieceExplosionGenerators = { 
			"deathceg3", 
			"deathceg4", 
		}, 

		explosiongenerators      = {
			"custom:gdhcannon",
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
			def                  = "heatray",
			onlyTargetCategory	 = "GROUND BUILDING SHIP",
		},
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
		unitrole				 = "Massive Transport",
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
	heatray           = {
		avoidFeature              = false,
		avoidFriendly             = false,
		collideFeature            = false,
		collideFriendly           = false,
		coreThickness             = 0.5,
		-- cegtag					  = "burnblack",
		beamtime				  = 0.1,
		beamttl                   = 4,
		largebeamlaser			  = true,
		laserFlareSize            = 5,
		duration                  = 0.8,
		energypershot             = 0,
		edgeeffectiveness		  = 0,
		explosionGenerator        = "custom:burnblacksmall",
		fallOffRate               = 0.1,
		fireStarter               = 100,
		impulseFactor             = 0,
		interceptedByShieldType   = 4,
		minintensity              = 1,
		name                      = "Microwave Beam",
		range                     = 500,
		reloadtime                = 0.1,
		WeaponType                = "BeamLaser",
		rgbColor                  = "0.5 0.25 0",
		rgbColor2                 = "0.25 0.25 0.25",
		soundTrigger              = true,
		soundstart                = "flamethrower2",
		-- soundHit                  = "explode5",
		-- sprayangle				  = 500,
		texture1                  = "flashside3",
		texture2                  = "empty",
		thickness                 = 7,
		tolerance                 = 1000,
		turret                    = true,
		weaponVelocity            = 750,
		waterweapon				 = true,
		customparams              = {
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= mediumExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                    = {
			default               = 21.6,
		},
	},
}
