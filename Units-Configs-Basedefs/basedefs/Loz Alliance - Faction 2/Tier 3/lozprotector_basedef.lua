unitDef                    = {
	buildCostEnergy              = 0,
	buildCostMetal               = 4500,
	builder                      = false,
	buildTime                    = 5,
	buildpic					 = "lozprotector.png",
	canAttack                    = true,
	
	--  canDgun			         = true,
	canGuard                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = "1",
	category                     = "GROUND",
	description                  = [[Shield Tank]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = explodeAs,
	footprintX                   = 5,
	footprintZ                   = 5,
	iconType                     = "tankshieldt3",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	leaveTracks                  = false,
	maxDamage                    = 340,
	maxSlope                     = 28,
	maxVelocity                  = 1.5,
	maxReverseVelocity           = 1,
	maxWaterDepth                = 5000,
	metalStorage                 = 0,
	movementClass                = "WHEELEDTANK5",
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
			def                  = "dummy",
		},
		[2]                      = {
			def                  = "shield",
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
	shield                        = {
		Smartshield               = true,
		Exteriorshield            = true,
		Visibleshield             = false,
		Visibleshieldrepulse      = false,
		ShieldStartingPower       = shield1StartingPower,
		Shieldenergyuse           = 0,
		Shieldradius              = 400,
		Shieldpower               = shield1Power,
		Shieldpowerregen          = shield1PowerRegen,
		Shieldpowerregenenergy    = shield1PowerRegenEnergy,
		rechargeDelay		  	  = shieldRechargeDelay,
		Shieldintercepttype       = 4,
		Shieldgoodcolor           = "0.0 0.2 1.0",
		Shieldbadcolor            = "1.0 0 0",
		Shieldalpha              = 0.2,

		texture1		          = "shield4",

		visibleShieldHitFrames    = 1,
		weaponType                = [[Shield]],
		damage                    = {
			default               = 1,
		},
	},

	dummy = {
		avoidFeature            = false,
		avoidFriendly           = false,
		collideFeature          = false,
		collideFriendly         = false,
		coreThickness           = 0,
		--	cegTag                = "mediumcannonweapon3",
		duration                = 0,
		energypershot           = 0,
		fallOffRate             = 0,
		impulseFactor           = 0,

		minintensity            = "1",
		name                    = "Fake Weapon",
		range                   = 900,
		reloadtime              = 100,
		WeaponType              = "LaserCannon",
		rgbColor                = "0 0 0",
		rgbColor2               = "0 0 0",
		soundTrigger            = true,
		texture1                = "shot",
		texture2                = "empty",
		thickness               = 0,
		tolerance               = 0,
		turret                  = true,
		weaponVelocity          = 3000,
		customparams            = {
		},
		damage                  = {
			default = 0,
		},
	},
}
