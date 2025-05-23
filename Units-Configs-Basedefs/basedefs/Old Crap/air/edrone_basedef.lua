unitDef                    = {
	acceleration                 = 0.5,
	airStrafe                    = true,
	bankscale                    = "1",
	brakeRate                    = 0.7,
	buildCostEnergy              = 0,
	buildCostMetal               = 33,
	buildTime                    = 2.5,
	buildpic					 = "edrone.png",
	canAttack                    = true,
	canDropFlare                 = false,
	canFly                       = true,
	canGuard                     = true,
	canLoopbackAttack            = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = "1",
	category                     = "AIRLIGHT VTOL DRONE",
	collide                      = false,
	cruiseAlt                    = 75,
	description                  = [[Harassment Specialist Drone]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = "smallExplosionGenericPurple",
	flareDelay                   = 0.1,
	flareDropVector              = "0 0 -1",
	flareefficieny               = "0.3",
	flareReload                  = 3,
	footprintX                   = 2,
	footprintZ                   = 2,
	hoverAttack                  = true,
	iconType                     = "drone",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	maxDamage                    = 560,
	maxSlope                     = 90,
	maxVelocity                  = 11,
	--verticalSpeed		         = 15,
	maxWaterDepth                = 0,
	metalStorage                 = 0,
	moverate1                    = "8",
	name                         = humanName,
	objectName                   = objectName,
	script			             = script,
	radarDistance                = 0,
	repairable		             = false,
	selfDestructAs               = "smallExplosionGenericPurple",
	side                         = "CORE",
	sightDistance                = 500,
	SonarDistance                = 500,
	smoothAnim                   = true,
	stealth                      = true,
	turnRate                     = 5000,
	unitname                     = unitName,
	sfxtypes                     = { 
		pieceExplosionGenerators = { 
			"deathceg3", 
			"deathceg4", 
		}, 

		explosiongenerators      = {
			"custom:jetstrail",
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
			def                  = "droneweapon",
			badTargetCategory    = "LIGHT ARMORED",
		},
	},
	customParams                 = {
		unittype				  = "mobile",
		isupgraded               = isUpgraded,
		death_sounds             = "generic",
		RequireTech              = tech,
		armortype                = armortype,
		supply_cost              = supply,
		nofriendlyfire	         = "1",
		normaltex               = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "ateran",
		retreatRangeDAI			 = 0,
	},
}


--------------------------------------------------------------------------------

weaponDefs                 = {
	droneweapon                  = {
		--accuracy                 = 500,
		AreaOfEffect             = 25,
		avoidFeature             = false,
		avoidFriendly            = false,
		collideFeature           = false,
		collideFriendly          = false,
		coreThickness            = 0.5,
		beamTime                 = 0.1,
		beamTTL					 = 10,
		beamDecay				 = 1,
		burnblow		         = true,
		largeBeamLaser           = true,
		laserflaresize 	         = 7,
		minIntensity			 = 1,
		--cegTag                   = "railgun",
		duration                 = 0.6,
		edgeeffectiveness		 = 1,
		energypershot            = 0,
		explosionGenerator       = "custom:genericshellexplosion-small-sparks-burn",
		fallOffRate              = 0.1,
		fireStarter              = 50,
		impulseFactor            = 0,
		fallOffRate				 = 0,
		interceptedByShieldType  = 4,
		minintensity             = 1,
		name                     = unitName .. "Weapon",
		range                    = 300,
		reloadtime               = 0.5,
		WeaponType               = "BeamLaser",
		waterweapon				 = true,
		rgbColor                 = "0.1 0.5 0.2",
		rgbColor2                = "0 1 0",
		soundTrigger             = true,
		soundstart               = "weapons/18389_inferno_medlas.wav",
		--soundHit                 = "explosions/artyhit.wav",
		texture1                  = "lightning",
		texture2                  = "laserend",
		thickness                = 5,
		tolerance                = 10000,
		turret                   = true,
		weaponVelocity           = 750,
		customparams             = {
			damagetype		     = "light",
			isupgraded			 = isUpgraded,			
		},    
		damage                   = {
			default              = 15,
		},
	},
}
unitDef.weaponDefs               = weaponDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
