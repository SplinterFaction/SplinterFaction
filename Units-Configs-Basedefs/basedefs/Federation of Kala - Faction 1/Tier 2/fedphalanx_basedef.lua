unitDef                    = {

	--mobileunit 
	transportbyenemy             = false;
	--**

	buildCostEnergy              = 0,
	buildCostMetal               = 1400,
	builder                      = false,
	buildTime                    = 5,
	buildpic					 = [[fedphalanx.png]],
	canAttack                    = true,
	
	canGuard                     = true,
	canHover                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = "1",
	category                     = "GROUND",
	description                  = [[Anti-Air Artillery]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = explodeAs,
	footprintX                   = 3,
	footprintZ                   = 3,
	highTrajectory		   		 = 2,
	iconType                     = "botaat2",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	leaveTracks                  = false,
	maxDamage                    = 75,
	maxSlope                     = 90,
	maxVelocity                  = 1.6,
	maxReverseVelocity           = 1,
	maxWaterDepth                = 10,
	metalStorage                 = 0,
	movementClass                = "WALKERTANK3",
	name                         = humanName,
	noChaseCategory              = "VTOL",
	objectName                   = objectName,
	script			             = script,
	radarDistance                = 0,
	repairable		             = false,
	selfDestructAs               = explodeAs,
	side                         = "CORE",
	sightDistance                = 850,
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
	turnrate 				 	 = 500,
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
			def                  = "machinegun",
--			mainDir = "0 0 1", -- x:0 y:0 z:1 => that's forward!
--			maxAngleDif = 70,
			onlyTargetCategory	  = "AIR",
		},
	},
	customParams                 = {
		unittype				  = "mobile",
		unitrole				 = "Anti-Air - Tech 2",
		canbetransported 		 = "true",
		needed_cover             = 1,
		death_sounds             = "generic",
		RequireTech              = tech,
		nofriendlyfire	         = true,
		supply_cost              = 1,
		normaltex               = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "Federation of Kala",
		
	},
}

weaponDefs                 = {
	machinegun                = {
		areaofeffect           = 50,
		predictboost	       = 1,
		avoidFriendly          = false,
		avoidFeature 		   = false,
		collideFriendly        = false,
		collideFeature         = false,
		canattackground		   = false,
		burnblow               = true,
		burst                  = 15,
		burstrate              = 0.07,
		-- cegTag                 = "railgun",
		explosionGenerator     = "custom:genericshellexplosion-small",
		edgeEffectiveness	   = 1,
		energypershot          = 0,
		fallOffRate            = 0,
		impulseFactor          = 0,
		interceptedByShieldType  = 4,
		name                   = "MachineGun",
		range                  = 850,
		reloadtime             = 1,
		--projectiles			   = 5,
		weaponType		       = "Cannon",
		soundStart             = "scifi_machine_gun_B_burst_05",
		soundtrigger           = true,
		size                   = 3,
		tolerance              = 10000,
		turret                 = true,
		weaponVelocity         = 1500,
		customparams             = {
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 10,
		},
	},
}
