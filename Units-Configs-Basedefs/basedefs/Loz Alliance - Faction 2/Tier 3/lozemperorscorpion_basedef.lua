unitDef                    = {
	buildCostEnergy              = 0,
	buildCostMetal               = 12000,
	builder                      = false,
	buildTime                    = 5,
	buildpic					 = "lozemperorscorpion.png",
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
	footprintX                   = 6,
	footprintZ                   = 6,
	iconType                     = "artillery",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	leaveTracks                  = false,
	maxDamage                    = 340,
	maxSlope                     = 28,
	maxVelocity                  = 1.2,
	maxReverseVelocity           = 1,
	maxWaterDepth                = 5000,
	metalStorage                 = 0,
	movementClass                = "WHEELEDTANK6",
	name                         = humanName,
	noChaseCategory              = "VTOL",
	objectName                   = objectName,
	script			             = script,
	radarDistance                = 0,
	repairable		             = false,
	selfDestructAs               = explodeAs,
	side                         = "CORE",
	sightDistance                = 1000,
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
			def                  = "flakcannon",
			onlyTargetCategory    = "GROUND BUILDING AIR SHIP",
		},
	},
	customParams                 = {
		unittype				 = "mobile",
		unitrole				 = "Support",
		canbetransported 		 = "true",
		needed_cover             = 2,
		death_sounds             = "generic",
		RequireTech              = tech,
		nofriendlyfire	         = "1",
		supply_cost              = 3,
		normaltex               = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "Loz Alliance",
		corpse                   = "energycore",
	},
}

weaponDefs                 = {
	flakcannon   	             = {
		avoidFeature             = false,
		avoidFriendly            = false,
		collideFeature           = false,
		collideFriendly          = false,
		-- canAttackGround 		 = false,
		burnblow		         = true,
		--cegTag                   = "railgun",
		energypershot            = 0,
		explosionGenerator       = "custom:genericshellexplosion-large",
		edgeEffectiveness		 = 1,
		fallOffRate              = 1,
		fireStarter              = 50,
		impulseFactor            = 0,
		minintensity             = "1",
		name                     = "Flak Cannon",
		range                    = 1200,
		reloadtime               = 12,
		WeaponType               = "Cannon",
		rgbColor                 = "1 0.5 0",
		rgbColor2                = "1 1 1",
		soundTrigger             = false,
		soundstart               = "weapons/scifi2_shotgun_single_02.wav",
		soundhit				 = "deathsounds/generic/Explosion Fireworks_01.wav",
		size					 = 15,
		--texture1                 = "shot",
		--texture2                 = "empty",
		tolerance                = 7500,
		turret                   = true,
		weaponVelocity           = 3000,
		customparams             = {
			expl_light_color	= purple, -- As a string, RGB
			expl_light_radius	= largeExplosion, -- In Elmos
			expl_light_life		= largeExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 5200,
		},
	},
}
