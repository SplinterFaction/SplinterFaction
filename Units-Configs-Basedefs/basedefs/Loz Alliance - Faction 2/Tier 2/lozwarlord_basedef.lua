unitDef                    = {
	buildCostEnergy              = 0,
	buildCostMetal               = 3000,
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
	footprintX                   = 8,
	footprintZ                   = 8,
	iconType                     = "mbt",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	leaveTracks                  = false,
	maxDamage                    = 360,
	maxSlope                     = 60,
	maxVelocity                  = 1.6,
	maxReverseVelocity           = 1,
	maxWaterDepth                = 5000,
	minWaterDepth                = 25,
	metalStorage                 = 0,
	movementClass                = "SHIP8",
	name                         = humanName,
	noChaseCategory              = "AIR GROUND",
	objectName                   = objectName,
	script			             = script,
	radarDistance                = 0,
	repairable		             = false,
	selfDestructAs               = explodeAs,
	side                         = "CORE",
	sightDistance                = 1700,
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
	acceleration 				 = 2,
	brakeRate                    = 0.1,
	turninplace 				 = false,
	turninplacespeedlimit 		 = 10,
	turnInPlaceAngleLimit		 = 90,
	turnrate 				 	 = 150,
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
			def                  = "lasercannon",
			onlyTargetCategory    = "AIR",
		},
		[5]                      = {
			def                  = "lasercannon",
			onlyTargetCategory    = "AIR",
		},
	},
	customParams                 = {
		unittype				 = "mobile",
		unitsubtype              = "ship",
		unitrole				 = "Heavy Cruiser",
		canbetransported 		 = "true",
		needed_cover             = 2,
		death_sounds             = "generic",
		RequireTech              = tech,
		nofriendlyfire	         = "1",
		supply_cost              = 1,
		normaltex               = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "Loz Alliance",
		corpse                   = "energycore",
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

		burst                    = 2,
		burstrate                = 0.3,

		impulseFactor            = 0,
		interceptedByShieldType  = 4,
		highTrajectory	         = 0,
		name                     = "High Explosive Plasma Cannon",
		range                    = 1700,
		reloadtime               = 7,
		size					 = 8,
		weaponType		         = "Cannon",
		soundHit                 = "explosions/artyhit.wav",
		soundStart               = "weapons/arty2.wav",

		turret                   = true,
		weaponVelocity           = 500,
		customparams             = {
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= largeExplosion, -- In Elmos
			expl_light_life		= largeExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 114,
		},
	},

	lasercannon                  = {
		predictboost	         = 0.3,
		avoidFeature             = false,
		avoidFriendly            = false,
		beamTime                 = 0.1,
		beamttl                  = 4,
		collideFeature           = false,
		collideFriendly          = false,
		canattackground          = false,
		coreThickness            = 0.3,
		duration                 = 0.1,
		energypershot            = 0,
		explosionGenerator       = "custom:genericshellexplosion-small",
		fallOffRate              = 1,
		fireStarter              = 50,
		interceptedByShieldType  = 4,
		impulsefactor		     = 0.1,

		largebeamlaser	         = true,
		laserflaresize 	         = 8,
		minintensity             = 1,
		name                     = "Laser",
		range                    = 1700,
		reloadtime               = 0.4,
		WeaponType               = "High Intensity Beam Laser",
		rgbColor                 = "0.1 0 0.3",
		rgbColor2                = "1 1 1",
		soundTrigger             = true,
		soundstart               = "weapons/aegis.wav",
		--	soundHit		     = "weapons/amphibmedtankshothit.wav",
		scrollspeed		         = 5,
		texture1                 = "lightning",
		texture2                 = "laserend",
		thickness                = 4,
		tolerance                = 3000,
		turret                   = true,
		weaponVelocity           = 1000,
		customparams              = {
			expl_light_color	= purple, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                    = {
			default               = 2,
		},
	},
}
