unitDef                    = {
	acceleration                 = 1,
	brakeRate                    = 0.2,
	buildCostEnergy              = 0,
	buildCostMetal               = 16000,
	builder                      = false,
	buildTime                    = 5,
	buildpic					 = "emissiletank.png",
	canAttack                    = true,
	
	canGuard                     = true,
	canHover                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = "1",
	category                     = "GROUND",
	description                  = [[Missile Support Tank]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = "largeExplosionGeneric",
	footprintX                   = 6,
	footprintZ                   = 6,
	iconType                     = "mtd_lit_all",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	leaveTracks                  = false,
	maxDamage                    = 320,
	maxSlope                     = 26,
	maxVelocity                  = 1.5,
	maxReverseVelocity           = 1,
	maxWaterDepth                = 10,
	metalStorage                 = 0,
	movementClass                = "WHEELEDTANK6",
	name                         = humanName,
	objectName                   = objectName,
	script						 = script,
	radarDistance                = 0,
	repairable		             = false,
	selfDestructAs               = "largeExplosionGeneric",
	side                         = "ARM",
	sightDistance                = 1300,
	smoothAnim                   = true,
	stealth			             = true,
	seismicSignature             = 2,
	transportbyenemy             = false;
	--  turnInPlace              = false,
	--  turnInPlaceSpeedLimit    = 2.6,
	turnInPlace                  = true,
	turnRate                     = 350,
	--  turnrate                 = 300,
	unitname                     = unitName,
	upright                      = true,
	workerTime                   = 0,
	sfxtypes                     = { 
		pieceExplosionGenerators = { 
			"deathceg3", 
			"deathceg4", 
		}, 

		explosiongenerators      = {
			"custom:factorysparks",
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
			def                  = "missletankweapon",
			onlyTargetCategory   = "GROUND BUILDING SHIP",
		},
	},
	customParams                 = {
		unittype				  = "mobile",
        unitrole                  = "Artillery",
		canbetransported 		 = "true",
		canareaattack            ="1",
		needed_cover             = 3,
		death_sounds             = "generic",
		nofriendlyfire	         = "1",
		normaltex               = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "Neutral",
	},
}


--------------------------------------------------------------------------------
-- Energy Per Shot Calculation is: dmg / 20 * ((aoe / 1000) + 1)

weaponDefs                 = {
	missletankweapon             = {

		AreaOfEffect             = 100,
		avoidFriendly            = false,
		avoidFeature             = false,
		collideFriendly          = false,
		collideFeature           = false,
		cegTag                   = "emissiletanktrail-optimized",
		craterBoost              = 0,
		craterMult               = 0,
		explosionGenerator       = "custom:genericshellexplosion-medium-red",
		energypershot            = 0,
		fireStarter              = 100,
		flightTime               = 10,
		impulseBoost             = 0,
		impulseFactor            = 0,
		interceptedByShieldType  = 4,
		
		model                    = "missilesmallvlaunch.s3o",
		name                     = "Rocket",
		range                    = 1300,
		reloadtime               = 25,
        burst                    = 10,
        burstrate                = 0.2,
		
		smokeTrail               = false,
		soundHit                 = "explode_large",
		soundStart               = "missile_launch1",
		
		tracks                   = true,
		turnrate                 = 30000,
		
		weaponAcceleration       = 400,
		weaponTimer              = 1,
		weaponType               = "StarburstLauncher",
		weaponVelocity           = 3000,
        
		customparams             = {

		},      
		damage                   = {
			default              = 1000,
		},
	},
}
