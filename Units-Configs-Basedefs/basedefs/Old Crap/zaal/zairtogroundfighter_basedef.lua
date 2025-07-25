unitDef                    = {
	acceleration                 = 1,
	airStrafe                    = false,
	airHoverFactor				 = 0,
	brakeRate                    = 1,
	buildCostEnergy              = 0,
	buildCostMetal               = 53,
	buildTime                    = 2.5,
	buildpic					 = "zaal_unitpics/zairtogroundfighter.png",
	canAttack                    = true,
	canFly                       = true,
	canGuard                     = true,
	canLoopbackAttack            = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = true,
	category                     = "AIRLIGHT VTOL",
	collide                      = true,
	cruiseAlt                    = 140,
	description                  = [[Air to Ground Fighter]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = "BUG_DEATH_MEDIUM",
	floater                      = true,
	footprintX                   = 3,
	footprintZ                   = 3,
	hoverAttack                  = false,
	iconType                     = "zairtogroundfighter",
	idleAutoHeal                 = 2.5,
	idleTime                     = 5,
	maxacc						 = 1,
	maxDamage                    = 812,
	maxSlope                     = 90,
	maxVelocity                  = 15,
	maxWaterDepth                = 255,
	metalStorage                 = 0,
	moverate1                    = "8",
	name                         = humanName,
	objectName                   = objectName,
	script			             = script,
	radarDistance                = 0,
	repairable		             = false,
	selfDestructAs               = "BUG_DEATH_MEDIUM",
	side                         = "ARM",
	sightDistance                = 1000,
	smoothAnim                   = true,
	sonarDistance                = 0,
	transportbyenemy             = false;
	turnRate                     = 5000,
	turnradius					 = 250,
	unitname                     = unitName,
	upright						 = true,
	sfxtypes                     = { 
		pieceExplosionGenerators = { 
			"blood_spray", 
		}, 

		explosiongenerators      = {
			"custom:blood_spray",
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
			badtargetcategory = "VTOL BUILDING",
			def = "WEAPON",
			maindir = "0 0 1",
			maxangledif = 180,
		},
	},
	customParams                 = {
		unittype				 = "mobile",
		--    needed_cover       = 2,
		death_sounds             = "bug",
		RequireTech              = tech,
		armortype                = armortype,
		nofriendlyfire	         = "1",
		supply_cost              = supply,
		factionname	             = "zaal",
		
		normaltex 				 = "unittextures/z_normals.dds",
		retreatRangeDAI			 = 0,
	},
}

weaponDefs                 = {
	weapon = {
		interceptedByShieldType   = 4,
		accuracy 				  = 1100,
		areaofeffect 			  = 24,
		avoidFriendly			 = false,
		avoidFeature			 = false,
		collideFriendly			 = false,
		collideFeature			 = false,
		burnblow 				  = true,
		cegTag                    = "zaalspiketrail-optimized",
		craterboost 			  = 0,
		cratermult 				  = 0,
		explosiongenerator 		  = "custom:chickenspike-large-sparks-burn",
		impulseboost 			  = 0,
		impulsefactor 			  = 0,
		interceptedbyshieldtype   = 4,
		model 					  = "ChickenDefenseModels/spike.s3o",
		name 					  = "Spike",
		noselfdamage 			  = true,
		range 					  = 350,
		reloadtime 				  = 2,
		soundstart 				  = "ChickenDefenseSounds/talonattack",
		startvelocity 			  = 200,
		submissile 				  = 1,
		turret 					  = true,
		waterWeapon				  = true,
		weaponacceleration 		  = 100,
		weapontimer 			  = 1,
		weaponvelocity 			  = 350,
		customparams             = {
			damagetype		     = "light",
			nofriendlyfire	     = 1,
		}, 
		damage = {
			default 			  = 200,
		},
	},
}
