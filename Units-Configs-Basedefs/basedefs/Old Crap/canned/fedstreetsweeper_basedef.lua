unitDef                    = {

	acceleration                 = 1,
	brakeRate                    = 1,
	buildCostEnergy              = 0,
	buildCostMetal               = 80,
	builder                      = false,
	buildTime                    = 5,
	buildpic					 = "eallterrriot.png",
	canAttack                    = true,
	
	--  canDgun			         = true,
	canGuard                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = "1",
	category                     = "ARMORED NOTAIR RIOT",
	description                  = [[Shotgun/Riot Tank]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = "mediumexplosiongeneric",
	footprintX                   = 2,
	footprintZ                   = 2,
	iconType                     = "riot_lit",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	leaveTracks                  = false,
	maxDamage                    = 150,
	maxSlope                     = 180,
	maxVelocity                  = 2.2,
	maxReverseVelocity           = 1,
	turninplacespeedlimit        = 3.3,
	maxWaterDepth                = 10,
	metalStorage                 = 0,
	movementClass                = "ALLTERRTANK2",
	name                         = humanName,
	noChaseCategory              = "VTOL",
	objectName                   = objectName,
	script	                     = script,
	radarDistance                = 0,
	repairable		             = false,
	selfDestructAs               = "mediumexplosiongeneric",
	sightDistance                = 400,
	smoothAnim                   = true,
	stealth			             = true,
	seismicSignature             = 2,
	transportbyenemy             = false;
	turnInPlace                  = true,
	turnRate                     = 5000,
	unitname                     = unitName,
	upright                      = false,
	workerTime                   = 0,
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
		-- [1]                      = {
			-- def                  = "riottankempweapon",
			-- onlyTargetCategory   = "BIO LIGHT ARMORED BUILDING",
			-- badTargetCategory    = "WALL",
		-- },
		[1]                      = {
			def                  = "riottankshotgun",
			onlyTargetCategory   = "BIO LIGHT ARMORED BUILDING",
			badTargetCategory    = "WALL BUILDING",
		},
	},
	customParams                 = {
		unittype				 = "mobile",
		canbetransported 		 = "true",
		needed_cover             = 2,
		death_sounds             = "generic",
		RequireTech              = tech,
		armortype                = armortype,
		nofriendlyfire	         = "1",
		supply_cost              = supply,
		normaltex               = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "Federation of Kala",
		
		decloakradiushalved		 = true,
	},
}

weaponDefs                 = {
	riottankshotgun              = {
		areaofeffect 			 = 75,
		avoidFriendly            = false,
		avoidFeature             = false,
		collideFriendly          = false,
		collideFeature           = false,
		--burstrate				 = 0.2,
		--burst					 = 5,
		
		cegTag                   = "bruisercannon",
		edgeeffectiveness		 = 1,
		explosionGenerator       = "custom:bar-genericshellexplosion-medium",
		energypershot            = 0,
		interceptedByShieldType  = 4,
		impulseFactor            = 0,
		name                     = "Shotgun",
		noSelfDamage             = true,
		noexplode		         = true,
		projectiles		     	 = 5,
		range                    = 500,
		reloadtime               = 2.5,
		sprayangle				 = 3500,
		size					 = 2,
		weaponType		         = "Cannon",
		soundHit                 = "explosions/mediumcannonhit.wav",
		soundStart               = "weapons/Shotgun Boom 103.wav",
		
		turret                   = true,
		weaponVelocity           = 400,
		customparams             = {
			damagetype		     = "antilightarmored",  
			nofriendlyfire	     = true,
			single_hit			 = true,
		},      
		damage                   = {
			default              = 25,
		},
	},
}