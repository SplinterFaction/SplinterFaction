unitDef                    = {
	acceleration                 = 1,
	brakeRate                    = 0.1,
	buildCostEnergy              = 0,
	buildCostMetal               = 27,
	builder                      = false,
	buildTime                    = 5,
	buildpic					 = "elighttank3.png",
	canAttack                    = true,
	canGuard                     = true,
	canHover                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = "1",
	category                     = "LIGHT NOTAIR RAID",
	description                  = [[Raider]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = "smallExplosionGenericBlue",
	footprintX                   = 2,
	footprintZ                   = 2,
	iconType                     = "raider",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	leaveTracks                  = false,
	maxDamage                    = 245,
	maxSlope                     = 26,
	maxVelocity                  = 4.5,
	maxReverseVelocity           = 2,
	maxWaterDepth                = 10,
	metalStorage                 = 0,
	movementClass                = "HOVERTANK2",
	name                         = humanName,
	noChaseCategory              = "VTOL",
	objectName                   = objectName,
	script						 = script,
	radarDistance                = 0,
	repairable		             = false,
	selfDestructAs               = "smallExplosionGenericBlue",
	side                         = "CORE",
	sightDistance                = 650,
	smoothAnim                   = true,
	stealth			             = true,
	seismicSignature             = 2,
	transportbyenemy             = false;
	--  turnInPlace              = false,
	--  turnInPlaceSpeedLimit    = 5.5,
	turnInPlace                  = true,
	turnRate                     = 5000,
	--  turnrate                 = 475,
	unitname                     = unitName,
	upright                      = true,
	workerTime                   = 0,

	sfxtypes                     = {
		explosiongenerators      = {
			"custom:electricity",
			"custom:emptydirt",
			"custom:blacksmoke",
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
			def                  = "lighttankweapon",
			badTargetCategory    = "VTOL ARMORED WALL",
		},
	},
	customParams                 = {
		isupgraded			  	 = isUpgraded,
		unittype				  = "mobile",
		canbetransported 		 = "true",
		needed_cover             = 1,
		death_sounds             = "generic",
		RequireTech              = tech,
		armortype                = armortype,
		nofriendlyfire	         = "1",
		supply_cost              = supply,
		normaltex               = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "ateran",
		
	},
}


--------------------------------------------------------------------------------
-- Energy Per Shot Calculation is: dmg / 20 * ((aoe / 1000) + 1)

weaponDefs                 = {
	lighttankweapon              = {
		
		AreaOfEffect             = 25,
		avoidFriendly            = false,
		avoidFeature             = false,
		collideFriendly          = false,
		collideFeature           = false,
		craterBoost              = 0,
		craterMult               = 0,
		beamTTL					 = 10,
		explosionGenerator       = "custom:genericshellexplosion-small-lightning",
		energypershot            = 0,
		edgeeffectiveness		 = 1,
		impulseBoost             = 0,
		impulseFactor            = 0,
		interceptedByShieldType  = 4,
		
		name			         = "elighttank3weapon",
		noSelfDamage             = true,
		range                    = 550,
		reloadtime               = 1,
		WeaponType               = "LightningCannon",
		rgbColor                 = "0.1 0.2 0.5",
		rgbColor2                = "0 0 1",
		soundStart               = "weapons/lightningstrike.wav",
		
		texture1                 = "lightning",
		thickness                = 5,
		turret                   = true,
		weaponVelocity           = 400,
		customparams             = {
			isupgraded		  	 = isUpgraded,
			damagetype		     = "antilightbuilding",
		},      
		damage                   = {
			default              = 60,
		},
	},
}
