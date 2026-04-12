unitDef                    = {

	--mobileunit 
	transportbyenemy             = false;
	--**

	buildCostEnergy              = 0,
	buildCostMetal               = 5000,
	builder                      = false,
	buildTime                    = 5,
	buildpic					 = [[fedstriker.png]],
	canAttack                    = true,
	
	canGuard                     = true,
	canHover                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = "1",
	category                     = "GROUND MASSIVE",
	description                  = [[Rapid Deployment Mech]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = explodeAs,
	footprintX                   = 7,
	footprintZ                   = 7,
	iconType                     = "botraidert3",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	leaveTracks                  = false,
	maxDamage                    = 75,
	maxSlope                     = 90,
	maxVelocity                  = 2.6,
	maxReverseVelocity           = 1,
	maxWaterDepth                = 10,
	metalStorage                 = 0,
	movementClass                = "WALKERTANK7",
	name                         = humanName,
	noChaseCategory              = "VTOL",
	objectName                   = objectName,
	script			             = script,
	radarDistance                = 0,
	repairable		             = false,
	selfDestructAs               = explodeAs,
	side                         = "CORE",
	sightDistance                = 680,
	smoothAnim                   = true,
	stealth			             = true,
	seismicSignature             = 1,
	unitname                     = unitName,
	upright                      = true,
	--usePieceCollisionVolumes	 = true,
	workerTime                   = 0,
	--------------
	-- Movement --
	--------------
	acceleration 				 = 2,
	brakeRate                    = 0.1,
	turninplace 				 = true,
	turninplacespeedlimit 		 = 10,
	turnInPlaceAngleLimit		 = 45,
	turnrate 				 	 = 350,
	--------------
	--------------

	sfxtypes                     = {
		explosiongenerators      = {
			"custom:gdhcannon",
			"custom:emptydirt",
			"custom:blacksmoke",
			"custom:airfactoryhtrail",
		},
		pieceExplosionGenerators = {
			"deathceg3",
			"deathceg4",
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
			def                  = "disruptionlaser",
			--mainDir = "0 0 1", -- x:0 y:0 z:1 => that's forward!
			--maxAngleDif = 180,
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "GROUND BUILDING SHIP",
		},
		[2]                      = {
			def                  = "particlebeamcannon",
			--mainDir = "0 0 1", -- x:0 y:0 z:1 => that's forward!
			--maxAngleDif = 180,
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "GROUND BUILDING SHIP",
			slaveto				 = 1,
		},
	},
	customParams                 = {
		isupgraded			  	 = isUpgraded,
		unittype				 = "mobile",
		unitrole				 = "Support",
		buildmenucategory        = "Skirmish",
		canbetransported 		 = "true",
		needed_cover             = 1,
		death_sounds             = "generic",
		RequireTech              = tech,
		nofriendlyfire	         = true,
		supply_cost              = 1,
		normaltex               = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "Federation of Kala",
		unitguide = [[The Striker is a large Tier 3 mech that pairs a rapid-fire disruption laser with a sustained depleted uranium particle cannon, both targeting the same enemy simultaneously. The disruption laser stacks its impairment effect with every hit while the particle cannon hammers the target with kinetic rounds — a unit that isn't killed outright by the combined fire will shortly find itself locked down and unable to fight back. Fast for its size and expensive enough to field carefully, the Striker rewards aggressive, well-supported pushes into enemy lines.]],
	},
}

weaponDefs                 = {
	particlebeamcannon                 = {
		avoidFeature             = false,
		avoidFriendly            = false,
		collideFeature           = false,
		collideFriendly          = false,
		explosionGenerator       = "custom:burnblacksmall",
		coreThickness            = 0.1,
		duration                 = 0.2,
		energypershot            = 0,
		fallOffRate              = 0.1,
		fireStarter              = 50,
		interceptedByShieldType  = 4,
		soundstart               = "scifi2_sniper_rifle_single_01",

		minintensity             = 1,
		impulseFactor            = 0,
		name                     = "Depleted Uranium",
		range                    = 680,
		reloadtime               = 0.25,
		WeaponType               = [[LaserCannon]],
		rgbColor                 = "0 0.5 1",
		rgbColor2                = "1 1 1",
		thickness                = 8,
		tolerance                = 1000,
		turret                   = true,
		texture1                 = "shot",
		texture2                 = "empty",
		weaponVelocity           = 2000,
		sprayangle				 = 75,
		customparams             = {
			expl_light_color	= blue, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
			weaponguide = [[Hammers out depleted uranium rounds at a rapid clip, each shot punching through armor with dense kinetic force. The modest individual damage piles up quickly under the relentless cadence of fire.]],
		},
		damage                   = {
			default              = 50,
		},
	},
	disruptionlaser                 = {
		avoidFriendly          = false,
		avoidFeature 		   = false,
		collideFriendly        = false,
		collideFeature         = false,
		cegTag                 = "railgun",
		rgbColor               = "1 0 0",
		rgbColor2              = "1 1 1",
		explosionGenerator     = "custom:genericshellexplosion-medium-sparks-burn",
		edgeEffectiveness	   = 1,
		energypershot          = 0,
		fallOffRate            = 0,
		duration			   = 0.25,
		minintensity             = 1,
		impulseFactor          = 0,
		--interceptedByShieldType  = 4,
		name                   = "E.M.G. Disruption Cannon",
		range                  = 680,
		reloadtime             = 0.25,
		--projectiles			   = 5,
		weaponType		       = "LaserCannon",
		soundStart             = "disruption-laser-high",
		texture1               = "shot",
		texture2               = "empty",
		coreThickness          = 0.5,
		thickness              = 8,
		tolerance              = 10000,
		turret                 = true,
		weaponVelocity         = 2000,
		customparams             = {
			expl_light_color	= red, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
			single_hit          = "true",
			disruptionweapon    = 1,
			weaponguide = [[Applies a stacking disruption effect that increasingly impairs the target's functionality until it shorts out completely. The resulting lockout leaves the unit inoperable for 10 seconds.]],
		},
		damage                   = {
			default              = 50,
		},
	},
}
