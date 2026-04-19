unitDef                    = {
	buildCostEnergy              = 0,
	buildCostMetal               = 2800,
	builder                      = false,
	buildTime                    = 5,
	buildpic					 = "lozwarlord.png",
	canAttack                    = true,
	canGuard                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = "1",
	category                     = "SHIP",
	description                  = [[Heavy Cruiser]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = explodeAs,
	footprintX                   = 6,
	footprintZ                   = 6,
	iconType                     = "shipartilleryt2",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	leaveTracks                  = false,
	maxDamage                    = 360,
	maxSlope                     = 60,
	maxVelocity                  = 1.4,
	maxWaterDepth                = 5000,
	minWaterDepth                = 25,
	metalStorage                 = 0,
	movementClass                = "SHIP6",
	name                         = humanName,
	noChaseCategory              = "AIR GROUND",
	objectName                   = objectName,
	script			             = script,
	radarDistance                = 0,
	repairable		             = false,
	selfDestructAs               = explodeAs,
	side                         = "CORE",
	sightDistance                = 500,
	waterline                    = 5,
	floater                      = true,
	stealth			             = true,
	seismicSignature             = 2,
	smoothAnim                   = true,
	transportbyenemy             = false;
	unitname                     = unitName,
	workerTime                   = 0,
	--------------
	-- Movement --
	--------------
	acceleration 				 = 0.035,
	brakeRate                    = 0.035,
	turninplace 				 = true,
	--	turninplacespeedlimit 		 = 10,
	turnInPlaceAngleLimit		 = 90,
	turnrate 				 	 = 500,
	--------------
	--------------
	sfxtypes                     = { 
		pieceExplosionGenerators = { 
			"deathceg3", 
			"deathceg4", 
		}, 

		explosiongenerators      = {
			"custom:gdhcannon",
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
			def                  = "plasmacannon",
			badTargetCategory     = "SHIP GROUND",
			onlyTargetCategory    = "SHIP GROUND BUILDING",
		},
		[2]                      = {
			def                  = "plasmacannon",
			badTargetCategory     = "SHIP GROUND",
			onlyTargetCategory    = "SHIP GROUND BUILDING",
		},
		[3]                      = {
			def                  = "plasmacannon",
			badTargetCategory     = "SHIP GROUND",
			onlyTargetCategory    = "SHIP GROUND BUILDING",
		},
		[4]                      = {
			def                  = "lightningcannon",
			onlyTargetCategory    = "AIR SHIP GROUND BUILDING",
		},
		[5]                      = {
			def                  = "lightningcannon",
			onlyTargetCategory    = "AIR SHIP GROUND BUILDING",
		},
	},
	customParams                 = {
		unitguide = [[The Warlord is the Loz Alliance's Tier 2 heavy cruiser, packing three long-range plasma cannons for surface bombardment and twin lightning cannons that provide anti-air and supplemental ground coverage. The plasma cannons reach out to extreme range and hit hard, while the lightning cannons discourage aircraft from thinking the Warlord is an easy target. Slow and expensive, it earns its place by being able to threaten targets that most ships cannot reach.]],
		unittype				 = "ship",
		unitrole				 = "Heavy Cruiser",
		buildmenucategory        = "Skirmish",
		canbetransported 		 = "true",
		needed_cover             = 2,
		death_sounds             = "generic",
		RequireTech              = tech,
		nofriendlyfire	         = "1",
		supply_cost              = 1,
		normaltex               = "unittextures/lego2skin_explorernormal.dds",
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "Loz Alliance",
		corpse                   = "lozwarlord_dead",
	},
}

weaponDefs                 = {
	plasmacannon              = {
		AreaOfEffect             = 30,
		avoidFriendly            = false,
		avoidFeature             = false,
		collideFriendly          = false,
		collideFeature           = false,

		--cegTag                   = "artyshot2",
		avoidNeutral	         = false,
		explosionGenerator       = "custom:genericshellexplosion-medium",
		energypershot            = 0,

		model                    = "projectile/projectileorange1-5x.s3o",

		impulseFactor            = 0,
		interceptedByShieldType  = 4,
		highTrajectory	         = 0,
		name                     = "High Explosive Plasma Cannon",
		range                    = 1700,
		reloadtime               = 7,
		size					 = 8,
		weaponType		         = "Cannon",
		soundHit                 = "artyhit",
		soundStart               = "warlordcannon",

		turret                   = true,
		weaponVelocity           = 500,
		customparams             = {
			weaponguide = [[A long-range plasma cannon that lobs high-explosive rounds at surface targets across an enormous engagement envelope. Three of these weapons firing together make the Warlord a serious long-range bombardment platform.]],
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= largeExplosion, -- In Elmos
			expl_light_life		= largeExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 571,
		},
	},

	lasercannon              = {
		areaofeffect            = 30,
		avoidFeature            = false,
		avoidFriendly           = false,
		collideFeature          = false,
		collideFriendly         = false,
		coreThickness           = 0.5,
		-- cegtag					  = "burnblack",
		beamtime                = 0.5,
		beamttl                 = 4,
		largebeamlaser          = true,
		duration                = 0.8,
		energypershot           = 0,
		edgeeffectiveness       = 0,
		explosionGenerator      = "custom:burnblacksmall",
		fallOffRate             = 0.1,
		fireStarter             = 100,
		impulseFactor           = 0,
		interceptedByShieldType = 4,
		minintensity            = 1,
		name                    = "Beam",
		range                   = 1700,
		reloadtime              = 7,
		WeaponType              = "BeamLaser",
		rgbColor                = "0.2 1 0.2",
		rgbColor2               = "1 1 1",
		soundTrigger            = true,
		soundstart              = "warlordlaser",
		-- soundHit                  = "explode5",
		-- sprayangle				  = 500,
		texture1                = "flashside3",
		texture2                = "empty",
		thickness               = 3,
		tolerance               = 1000,
		turret                  = true,
		weaponVelocity          = 750,
		waterweapon             = false,
		customparams            = {
			--single_hit		 	 = true,
			expl_light_color   = blue, -- As a string, RGB
			expl_light_radius  = mediumExplosion, -- In Elmos
			expl_light_life    = mediumExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity = 0.25, -- Use this sparingly
		},
		damage                  = {
			default = 1000,
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
		range                    = 1700,
		reloadtime               = 5,
		WeaponType               = "LightningCannon",
		rgbColor                 = [[1 0.5 0.5]],
		rgbColor2                = "1 1 1",
		soundStart               = "lozscorpion-maingun",
		soundtrigger             = true,

		texture1                 = "lightning",
		thickness                = 1.5,
		turret                   = true,
		weaponVelocity           = 400,
		customparams             = {
			weaponguide = [[An electrical strike cannon with dual coverage — capable of engaging both aircraft and surface targets. The sustained arc damage makes it difficult for aircraft to approach and provides supplemental ground fire support.]],
			expl_light_color	= blue, -- As a string, RGB
			expl_light_radius	= mediumExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 2.5,
		},
	},
}
