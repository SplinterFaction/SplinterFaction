unitDef                    = {
	buildCostEnergy              = 0,
	buildCostMetal               = 125,
	builder                      = false,
	buildTime                    = 5,
	buildpic					 = "lozscorpion.png",
	canAttack                    = true,
	
	--  canDgun			         = true,
	canGuard                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = "1",
	category                     = "GROUND",
	description                  = [[Artillery Tank]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = explodeAs,
	footprintX                   = 2,
	footprintZ                   = 2,
	iconType                     = "tankartilleryt1",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	leaveTracks                  = false,
	maxDamage                    = 340,
	maxSlope                     = 28,
	maxVelocity                  = 2,
	maxReverseVelocity           = 1,
	maxWaterDepth                = 5000,
	metalStorage                 = 0,
	movementClass                = "WHEELEDTANK2",
	name                         = humanName,
	noChaseCategory              = "VTOL",
	objectName                   = objectName,
	script			             = script,
	radarDistance                = 0,
	repairable		             = false,
	selfDestructAs               = explodeAs,
	side                         = "CORE",
	sightDistance                = 650,
	stealth			             = true,
	seismicSignature             = 2,
	smoothAnim                   = true,
	transportbyenemy             = false;
	unitname                     = unitName,
	workerTime                   = 0,
	--------------
	-- Movement --
	--------------
	acceleration 				 = 2,
	brakeRate                    = 0.1,
	turninplace 				 = true,
	turninplacespeedlimit 		 = 10,
	turnInPlaceAngleLimit		 = 45,
	turnrate 				 	 = 600,
	--------------
	--------------
	sfxtypes                     = {
		pieceExplosionGenerators = { 
			"deathceg3", 
			"deathceg4", 
		}, 

		explosiongenerators      = {
			"custom:electricity",
			"custom:emptydirt",
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
			def                  = "lightningcannon",
			onlyTargetCategory    = "GROUND BUILDING AIR SHIP",
		},
	},
	customParams                 = {
		unitguide = [[The Scorpion is the Loz Alliance's Tier 1 artillery tank, firing long-range lightning bolts that can engage ground, air, and naval targets indiscriminately. Its electrical strike cannon arcs multiple bursts per shot over a considerable distance, making it useful for area suppression as well as direct fire. Fragile and slow, it must be kept behind a frontline screen — but positioned correctly it reaches targets that most units cannot.]],
		unittype				 = "mobile",
		unitrole				 = "Artillery",
		buildmenucategory        = "Support",
		canbetransported 		 = "true",
		needed_cover             = 2,
		death_sounds             = "generic",
		RequireTech              = tech,
		nofriendlyfire	         = "1",
		supply_cost              = 3,
		normaltex               = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "Loz Alliance",
		
	},
}

weaponDefs                 = {
	flakcannon   	             = {
		avoidFeature             = false,
		avoidFriendly            = false,
		collideFeature           = false,
		collideFriendly          = false,
		-- canAttackGround 		 = false,
		coreThickness            = 0.5,
		burnblow		         = true,
		--cegTag                   = "railgun",
		duration                 = 0.05,
		energypershot            = 0,
		cegTag                 = "plasmacannontrail-purple",
		explosionGenerator       = "custom:genericshellexplosion-medium",
		model                  = "projectile/projectilepurple.s3o",
		edgeEffectiveness		 = 1,
		fallOffRate              = 1,
		fireStarter              = 50,
		impulseFactor            = 0,
		minintensity             = "1",
		name                     = "Flak Cannon",
		range                    = 650,
		reloadtime               = 7,
		WeaponType               = "Cannon",
		rgbColor                 = "1 0.5 0",
		rgbColor2                = "1 1 1",
		soundTrigger             = false,
		soundstart               = "Assault Rifle Shot_05",
		soundhit				 = "deathsounds/generic/Explosion Fireworks_01",
		size					 = 6,
		--texture1                 = "shot",
		--texture2                 = "empty",
		tolerance                = 7500,
		turret                   = true,
		weaponVelocity           = 1000,
		customparams             = {
			expl_light_color	= purple, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly

			-- CustomParams on the PARENT weapon def:
			--
			airburst             = "1",          -- required: marks this weapon as an airburst
			--
			-- Trigger (one or both; altitude checked first, timer as fallback):
			--airburst_altitude    = "80",         -- burst when projectile is this many elmos above ground (AGL)
			airburst_timer       = "0.1",        -- burst after this many seconds of flight
			--
			-- Submunitions:
			airburst_sub         = "lozscorpion_flakfragment",   -- weapondef name of the submunition (required)
			airburst_count       = "10",          -- number of submunitions to spawn (default: 8)
			--
			-- Spread:
			airburst_spread_mode  = "cone",      -- "cone" (forward) or "radial" (perpendicular) (default: cone)
			airburst_spread_angle = "5",        -- half-angle of spread cone/disc in degrees (default: 30)
			 airburst_even_spread  = "0",         -- 1 = evenly spaced around cone, 0 = random scatter (default: 1)
			--
			-- Velocity:
			airburst_speed_inherit = "1.0",      -- fraction of parent speed inherited by subs (default: 1.0)
			airburst_sub_speed     = "1.0",      -- multiplier on sub speed after inheritance (default: 1.0)
			--
			-- Parent behaviour on burst:
			airburst_explode_parent = "0",       -- 1 = trigger parent explosion, 0 = silent delete (default: 0)
			--airburst_burst_ceg      = "",        -- CEG tag to play at burst position when silently deleted
			--                                       --   (only used when airburst_explode_parent = 0)
		},
		damage                   = {
			default              = 300,
		},
	},

	flakfragment   	             = {
		avoidFeature             = false,
		avoidFriendly            = false,
		collideFeature           = false,
		collideFriendly          = false,
		-- canAttackGround 		 = false,
		coreThickness            = 0.5,
		burnblow		         = true,
		--cegTag                   = "railgun",
		duration                 = 0.05,
		energypershot            = 0,
		cegTag                 = "plasmacannontrail-purple",
		explosionGenerator       = "custom:genericshellexplosion-small",
		model                  = "projectile/projectilepurple.s3o",
		edgeEffectiveness		 = 1,
		fallOffRate              = 1,
		fireStarter              = 50,
		impulseFactor            = 0,
		minintensity             = "1",
		name                     = "Flak Cannon",
		range                    = 650,
		reloadtime               = 7,
		WeaponType               = "Cannon",
		rgbColor                 = "1 0.5 0",
		rgbColor2                = "1 1 1",
		soundTrigger             = false,
		soundstart               = "Assault Rifle Shot_05",
		soundhit				 = "deathsounds/generic/Explosion Fireworks_01",
		size					 = 2,
		--texture1                 = "shot",
		--texture2                 = "empty",
		tolerance                = 7500,
		turret                   = true,
		weaponVelocity           = 1000,
		customparams             = {
			expl_light_color	= purple, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 30,
		},
	},

	lightningcannon   	             = {
		avoidFriendly            = false,
		avoidFeature             = false,
		collideFriendly          = false,
		collideFeature           = false,
		craterBoost              = 0,
		craterMult               = 0,
		burst                    = 10,
		burstrate                = 0.01,
		beamTTL					 = 1,
		duration                 = 1,
		explosionGenerator       = "custom:genericshellexplosion-electric-small",
		energypershot            = 0,
		edgeeffectiveness		 = 1,
		impulseBoost             = 0,
		impulseFactor            = 0,
		interceptedByShieldType  = 4,
		intensity                = 24,
		laserFlareSize           = 1,

		name			         = "Electrical Strike Cannon",
		noSelfDamage             = true,
		range                    = 650,
		reloadtime               = 7,
		WeaponType               = "LightningCannon",
		rgbColor                 = "1 0.25 0",
		rgbColor2                = "1 1 1",
		soundStart               = "lozscorpion-maingun",
		soundtrigger             = true,

		texture1                 = "lightning",
		thickness                = 1.5,
		turret                   = true,
		weaponVelocity           = 400,
		customparams             = {
			weaponguide = [[An electrical strike cannon that fires bursts of chained lightning over long range, hitting ground, air, and naval targets alike. The multi-arc discharge makes it effective against both individual targets and clustered formations.]],
			expl_light_color	= blue, -- As a string, RGB
			expl_light_radius	= mediumExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 30,
		},
	},
}
