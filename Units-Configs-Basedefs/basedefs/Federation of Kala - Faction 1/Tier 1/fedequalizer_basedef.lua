unitDef                    = {

	--mobileunit 
	transportbyenemy             = false;
	--**

	buildCostEnergy              = 0,
	buildCostMetal               = 130,
	builder                      = false,
	buildTime                    = 5,
	buildpic					 = [[fedequalizer.png]],
	canAttack                    = true,
	
	canGuard                     = true,
	canHover                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = "1",
	category                     = "GROUND",
	description                  = [[Light Disruption Support Bot]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = explodeAs,
	footprintX                   = 2,
	footprintZ                   = 2,
	--highTrajectory		   		 = 2,
	iconType                     = "botdisruptort1",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	leaveTracks                  = false,
	maxDamage                    = 120,
	maxSlope                     = 26,
	maxVelocity                  = 2.2,
	maxReverseVelocity           = 1,
	maxWaterDepth                = 10,
	metalStorage                 = 0,
	movementClass                = "WALKERTANK2",
	name                         = humanName,
	noChaseCategory              = "VTOL",
	objectName                   = objectName,
	script			             = script,	
	radarDistance                = 0,
	repairable		             = false,
	selfDestructAs               = explodeAs,
	side                         = "CORE",
	sightDistance                = 620,
	smoothAnim                   = true,
	stealth			             = true,
	seismicSignature             = 1,
	unitname                     = unitName,
	--usePieceCollisionVolumes	 = true,
	upright                      = true,
	workerTime                   = 0,
	--------------
	-- Movement --
	--------------
	acceleration 				 = 2,
	brakeRate                    = 0.1,
	turninplace 				 = true,
	turninplacespeedlimit 		 = 10,
	turnInPlaceAngleLimit		 = 45,
	turnrate 				 	 = 750,
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
			def                  = "particlebeamcannon",
--			mainDir = "0 0 1", -- x:0 y:0 z:1 => that's forward!
--			maxAngleDif = 70,
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "GROUND BUILDING SHIP",
		},
	},
	customParams                 = {
		unittype				 = "mobile",
		unitrole				 = "Main Battle Tank",
		buildmenucategory        = "Support",
		canbetransported 		 = "true",
		needed_cover             = 1,
		death_sounds             = "generic",
		RequireTech              = tech,
		nofriendlyfire	         = true,
		supply_cost              = 1,
		normaltex               = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "Federation of Kala",
		unitguide = [[The Equalizer carries an EMG Disruption Cannon that applies a stacking impairment effect with every hit, eventually locking a target unit down entirely for ten seconds. Against individual targets it is a reliable disabler; against a column, a coordinated volley can bring an entire advance to a standstill. Its moderate speed and health make it a solid frontline skirmisher as long as it stays in the fight long enough to stack its effect.]],
	},
}

weaponDefs                 = {
	particlebeamcannon                 = {
		avoidFriendly          = false,
		avoidFeature 		   = false,
		collideFriendly        = false,
		collideFeature         = false,
		cegTag                 = "railgun",
		rgbColor               = "1 0 0",
		rgbColor2              = "1 1 1",
		explosionGenerator     = "custom:genericshellexplosion-medium-sparks-burn",
		edgeEffectiveness	   = 0.1,
		energypershot          = 0,
		fallOffRate            = 0,
		duration			   = 0.25,
		minintensity             = 1,
		impulseFactor          = 0,
		--interceptedByShieldType  = 4,
		name                   = "E.M.G. Disruption Cannon",
		range                  = 550,
		reloadtime             = 1,
		--projectiles			   = 5,
		weaponType		       = "LaserCannon",
		soundStart             = "disruption-laser-high",
		texture1               = "shot",
		texture2               = "empty",
		coreThickness          = 0.5,
		thickness              = 3,
		tolerance              = 10000,
		turret                 = true,
		weaponTimer            = 1,
		weaponVelocity         = 1500,
		customparams             = {
			expl_light_color	= red, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
			single_hit          = "true",
			disruptionweapon    = 1,
			weaponguide = [[Disruption weapons deal no direct damage, instead building disruptive interference within the target's systems. As disruption accumulates, the target's movement degrades progressively — and so does its ability to perceive the battlefield. At full disruption, the target is locked out entirely: immobilized, nearly blind, and unable to fire for several seconds. Disruption also arcs to nearby enemies on impact, making these weapons particularly effective against clustered formations. Continued fire on a locked-out target is not wasted — the arc still spreads to those around it.]],
		},
		damage                   = {
			default              = 70,
		},
	},
}
