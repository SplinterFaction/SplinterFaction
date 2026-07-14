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
		unitguide = [[The Equalizer carries an EMG Disruption Cannon that applies a stacking impairment effect with every hit, eventually locking a target unit down entirely for a time. Against individual targets it is a reliable disabler; against a column, a coordinated volley can bring an entire advance to a standstill. Its moderate speed and health make it a solid frontline skirmisher as long as it stays in the fight long enough to stack its effect.]],
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
			weaponguide = [[Disruption weapons don't damage hulls, they damage systems. Every hit builds a target's disruption meter instead of draining health, and as it climbs the target's onboard systems fail in stages: at 33% its sensors drop out and its line of sight collapses to almost nothing, at 66% its weapons lose lock and their range collapses so it can no longer engage at range, and at 100% its engines die, immobilizing it completely for 10 seconds while it discharges an overload nova that arcs a portion of its own disruption charge to nearby allied units, so a tightly clumped formation can chain shutdowns across several units from a single overloaded target. Left alone, disruption bleeds off over time, faster at low charge and slower near the top, and after a full shutdown ends the unit doesn't reset to zero but comes back online at partial charge, sensors still down, weapons and engines restored, leaving a window of vulnerability even after the lockout ends. Disruption resistance and recovery rate vary by hull, so know which units shrug it off and which don't before you commit.]],
		},
		damage                   = {
			default              = 200,
		},
	},
}
