unitDef                    = {
	buildCostEnergy              = 0,
	buildCostMetal               = 27000,
	builder                      = false,
	buildTime                    = 5,
	buildpic					 = "lozjaguar.png",
	canAttack                    = true,
	
	canGuard                     = true,
	canHover                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = "1",
	category                     = "GROUND",
	description                  = [[Endbringer Class Nuclear Battle Tank]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 400,
	explodeAs                    = explodeAs,
	footprintX                   = 6,
	footprintZ                   = 6,
	--highTrajectory               = 1,
	iconType                     = "artillery",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	leaveTracks                  = false,
	maxDamage                    = 15000,
	maxVelocity                  = 1.5,
	maxReverseVelocity           = 0.25,
	maxWaterDepth                = 20,
	metalStorage                 = 0,
	movementClass                = "WHEELEDTANK16",
	noChaseCategory              = "VTOL",
	name                         = humanName,
	objectName                   = objectName,
	script						 = script,
	pushResistant		         = true,
	radarDistance                = 0,
	repairable		             = false,
	selfDestructAs               = explodeAs,
	side                         = "CORE",
	sightDistance                = 1600,
	smoothAnim                   = true,
	stealth			             = true,
	seismicSignature             = 4,
	transportbyenemy             = false;
	unitname                     = unitName,
	workerTime                   = 0,
	--------------
	-- Movement --
	--------------
	acceleration 				 = 2,
	brakeRate                    = 0.1,
	turninplace 				 = true,
	turninplacespeedlimit 		 = 45,
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
			def                  = "nukeartyweapon",
			onlyTargetCategory    = "GROUND BUILDING SHIP",
		},
	},
	customParams                 = {
		unittype				  = "mobile",
		unitrole				 = "Assault",
		hpoverride               = 15000,
		death_sounds             = "nuke",
		RequireTech              = tech,
		normaltex               = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "Loz Alliance",
		corpse                   = "energycore",
	},
}

weaponDefs                 = {
	nukeartyweapon               = {
		AreaOfEffect             = 800,
		avoidFriendly            = false,
		avoidFeature             = false,
		collideFriendly          = false,
		collideFeature           = false,
		
		cegTag                   = "nukeartyshot",
		explosionGenerator       = "custom:NUKEDATBEWMSMALL",
		edgeEffectiveness        = 0.5,
		energypershot            = 0,
		highTrajectory			 = 0,
		impulseFactor            = 0,
		interceptedByShieldType  = 4,
		name                     = "Light Cannon",
		range                    = 1600,
		reloadtime               = 1.2,
		size					 = 16,
		weaponType		         = "Cannon",
		soundHit                 = "deathsounds/nuke/nuke1.wav",
		soundStart               = "weapons/nukeartyshot.wav",
		
		tolerance                = 2000,
		turret                   = true,
		weaponVelocity           = 800,
		customparams             = {
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= 10000, -- In Elmos
			expl_light_life		= 100, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.1, -- Use this sparingly
		}, 
		damage                   = {
			default              = 850,
		},
	},
}
