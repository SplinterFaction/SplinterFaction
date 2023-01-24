unitDef                    = {

	buildCostEnergy              = 0,
	buildCostMetal               = 25000,
	builder                      = false,
	buildTime                    = 5,
	buildpic					 = "fedanarchid.png",
	canAttack                    = true,
	
	canGuard                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = "1",
	cantBeTransported            = true,
	category                     = "GROUND",
	
	description                  = [[Endbringer Class Obliteration Strider]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 600,
	explodeAs                    = explodeAs,
	firestandorders              = "1",
	footprintX                   = 16,
	footprintZ                   = 16,
	iconType                     = "assault",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	leaveTracks                  = false,
	maxDamage                    = 40000,
	maxVelocity                  = 2.2,
	maxReverseVelocity           = 1,
	maxWaterDepth                = 80,
	metalStorage                 = 0,
	movementClass                = "WALKERTANK16",
	name                         = humanName,
	noChaseCategory              = "VTOL",
	objectName                   = objectName,
	script	                     = script,
	pushResistant		         = true,
	radarDistance                = 0,
	repairable		             = false,
	selfDestructAs               = explodeAs,
	sightDistance                = 1200,
	smoothAnim                   = true,
	stealth			             = true,
	seismicSignature             = 4,
	transportbyenemy             = false;
	unitname                     = unitName,
	upright                      = false,
	--  usePieceCollisionVolumes = true,
	--------------
	-- Movement --
	--------------
	acceleration 				 = 2,
	brakeRate                    = 0.1,
	turninplace 				 = true,
	turninplacespeedlimit 		 = 10,
	turnInPlaceAngleLimit		 = 45,
	turnrate 				 	 = 200,
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
			"custom:flamethrowerrange750",
			"custom:blacksmoke",
			"custom:burnblack",
		},
	},
	sounds                       = {
		underattack              = "other/unitsunderattack1",
		ok                       = {
			"ack",
		},
		select                   = {
			"unitselect",
		},
	},
	weapons                      = {
		[1]                      = {
			def                  = "heavybeamweapon",
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "GROUND BUILDING SHIP",
		},
		[2]                      = {
			def                  = "particlebeamcannon",
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "GROUND BUILDING SHIP",
		},
		[3]                      = {
			def                  = "particlebeamcannon",
			badTargetCategory     = "BUILDING",
			onlyTargetCategory    = "GROUND BUILDING SHIP",
		},
	},
	customParams                 = {
		unittype				  = "mobile",
		unitrole				 = "Assault",
		hpoverride               = hitPoints,
		death_sounds             = "nuke",
		RequireTech              = tech,
		normaltex               = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "Federation of Kala",
		corpse                   = "energycore",
	},
}

weaponDefs                 = {
	heavybeamweapon              = {
		AreaOfEffect             = 10,
		avoidFriendly            = false,
		avoidFeature             = false,
		collideFriendly          = false,
		collideFeature           = false,
		beamTime                 = 0.5,
		beamttl                  = 4,
		largebeamlaser			 = true,
		cameraShake		         = 1,
		coreThickness            = 0.2,
		--	cegTag               = "mediumcannonweapon3",
		--    duration           = 0.2,
		energypershot            = 0,
		explosionGenerator       = "custom:genericshellexplosion-large-sparks-burn",
		fallOffRate              = 0,
		fireStarter              = 50,
		impulseFactor            = 0,
		interceptedByShieldType  = 4,
		minintensity             = "1",
		name                     = "Laser",
		range                    = 1000,
		reloadtime               = 1,
		WeaponType               = "BeamLaser",
		rgbColor                 = "1 0 0",
		rgbColor2                = "1 1 1",
		soundTrigger             = true,
		soundstart               = "weapons/krabprimary.wav",
		--    soundHit           = "explosions/mediumcannonhit.wav",
		--	sweepfire		     = true,
		texture1                 = "lightning",
		texture2                 = "laserend",
		thickness                = 12,
		tolerance                = 1000,
		turret                   = true,
		weaponVelocity           = 2000,
		customparams             = {
			expl_light_color	= red, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= largeExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 400,
		},
	},
	
	particlebeamcannon                 = {
		
		accuracy                 = 0,
		AreaOfEffect             = 10,
		avoidFeature             = false,
		avoidFriendly            = false,
		collideFeature           = false,
		collideFriendly          = false,
		explosionGenerator       = "custom:burnblack",
		coreThickness            = 0.1,
		duration                 = 0.8,
		energypershot            = 0,
		fallOffRate              = 0.1,
		fireStarter              = 50,
		interceptedByShieldType  = 4,
		soundstart               = "weapons/Sci Fi Assault Rifle 4.wav",
		
		minintensity             = 1,
		impulseFactor            = 0,
		name                     = "Something with Flames",
		range                    = 1200,
		reloadtime               = 0.2,
		WeaponType               = [[LaserCannon]],
		rgbColor                 = "1 0.5 0",
		rgbColor2                = "1 1 1",
		thickness                = 2,
		tolerance                = 1000,
		turret                   = true,
		texture1                 = "shot",
		texture2                 = "empty",
		weaponVelocity           = 1000,
		sprayangle				 = 500,
		customparams             = {
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= mediumExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},      
		damage                   = {
			default              = 20,
		},
	},
}
