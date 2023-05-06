unitDef                    = {
	buildCostEnergy              = 0,
	buildCostMetal               = 120,
	builder                      = false,
	buildTime                    = 5,
	buildpic					 = "eallterrriot.png",
	canAttack                    = true,
	
	--  canDgun			         = true,
	canGuard                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = "1",
	category                     = "GROUND",

	-- Cloaking

	-- cancloak		             = true,
	-- cloakCost		             = 0,
	-- cloakCostMoving	             = 0,
	-- minCloakDistance             = 70,
	-- decloakOnFire	             = true,
	-- decloakSpherical             = true,
	-- initCloaked		             = false,
	
	-- End Cloaking

	description                  = [[Shotgun/Riot Tank]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = "mediumExplosionGeneric",
	footprintX                   = 2,
	footprintZ                   = 2,
	iconType                     = "riot_lit",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	leaveTracks                  = false,
	maxDamage                    = 400,
	maxSlope                     = 180,
	maxReverseVelocity           = 1,
	maxWaterDepth                = 10,
	metalStorage                 = 0,
	movementClass                = "ALLTERRAINTANK2",
	name                         = humanName,
	objectName                   = objectName,
	script	                     = script,
	radarDistance                = 0,
	repairable		             = false,
	selfDestructAs               = "mediumExplosionGeneric",
	sightDistance                = 490,
	smoothAnim                   = true,
	stealth			             = true,
	seismicSignature             = 2,
	transportbyenemy             = false;
	turnInPlace                  = true,
	unitname                     = unitName,
	upright                      = false,
	workerTime                   = 0,
    --------------
	-- Movement --
	--------------
    acceleration 				 = 2,
	brakeRate                    = 0.1,
    maxVelocity                  = 3.2,
	turninplace 				 = true,
	turninplacespeedlimit 		 = 10,
	turnInPlaceAngleLimit		 = 45,
	turnrate 				 	 = 750,
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
			def                  = "riottankshotgun",
			onlyTargetCategory   = "GROUND BUILDING SHIP",
		},
	},
	customParams                 = {
		unittype				 = "mobile",
        unitrole				 = "Indirect Fire Support",
		canbetransported 		 = "true",
		needed_cover             = 2,
		death_sounds             = "generic",
		nofriendlyfire	         = "1",
		normaltex               = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "Neutral",
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
		explosionGenerator       = "custom:genericshellexplosion-large-sparks-burn",
		energypershot            = 0,
		interceptedByShieldType  = 4,
		impulseFactor            = 0,
		name                     = "Shotgun",
		noSelfDamage             = true,
		projectiles		     	 = 20,
		range                    = 490,
		reloadtime               = 7,
		sprayangle				 = 3500,
		size					 = 2,
		weaponType		         = "Cannon",
		soundHit                 = "mediumcannonhit",
		soundStart               = "Shotgun Boom 103",
		
		turret                   = true,
		weaponVelocity           = 400,
		customparams             = {
			
		},      
		damage                   = {
			default              = 40,
		},
	},
}