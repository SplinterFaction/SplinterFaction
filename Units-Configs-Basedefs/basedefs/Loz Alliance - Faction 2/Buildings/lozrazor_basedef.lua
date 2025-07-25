unitDef                     = {
	buildAngle                    = 2048,
	buildCostEnergy               = 0,
	buildCostMetal                = 320,
	builder                       = false,
	buildTime                     = 5,
	canAttack                     = true,
	canstop                       = "1",
	category                      = "BUILDING",
	collisionVolumeTest           = "1",
	description                   = [[Light Anti-Air Turret]],
	energyStorage                 = 0,
	energyUse                     = 0,
	explodeAs                     = "mediumBuildingExplosionGeneric",
	footprintX                    = 2,
	footprintZ                    = 2,
	floater			              = false,
	idleAutoHeal                  = .5,
	idleTime                      = 2200,
	iconType                      = "structureaat1",
	maxDamage                     = 625,
	maxSlope                      = 60,
	maxWaterDepth                 = 0,
	metalStorage                  = 0,
	name                          = humanName,
	objectName                    = objectName,
	script						  = script,
	radarDistance                 = 0,
	repairable		              = false,
	selfDestructAs                = "mediumBuildingExplosionGeneric",
	side                          = "CORE",
	sightDistance                 = 700,
	smoothAnim                    = true,
	unitname                      = unitName,
	workerTime                    = 0,
	yardMap                       = "oooo oooo oooo oooo",

	sfxtypes                      = { 
		pieceExplosionGenerators  = { 
			"deathceg3", 
			"deathceg4", 
		}, 

		explosiongenerators       = {
			"custom:gdhcannon",
			"custom:needspower",
			"custom:blacksmoke",
		},
	},
	sounds                        = {
		underattack               = "units_under_attack",
		select                    = {
			"other/turretselect",
		},
	},
	weapons                       = {
		[1]                       = {
			def                   = "lightningcannon",
			onlyTargetCategory    = "AIR",
		},
	},
	customParams                  = {
		unittype				  = "building",
		unitrole				  = "Short Range Anti-Air",
		unitrole_sound            = "turret",
		sightdistanceoverride	 = true,
		RequireTech				  = tech,
		--supply_cost               = supply,
		death_sounds              = "generic",
		normaltex                 = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                 = "unittextures/lego2skin_explorerbucket.dds",
		factionname	              = faction,
		

		-- Begin unit rings
		ring_color = "1,0,0,0.5",
		ring_radius = "550",
		ring_linewidth = "1",
		ring_divs = "128",
		ring_alwaysshow = "false",

	},
	useGroundDecal                = true,
	BuildingGroundDecalType       = "factorygroundplate.dds",
	BuildingGroundDecalSizeX      = 6,
	BuildingGroundDecalSizeY      = 6,
	BuildingGroundDecalDecaySpeed = 0.9,
}

weaponDefs = {
	beamweapon                  = {
		predictboost	         = 0.3,
		AreaOfEffect             = 0,
		avoidFeature             = false,
		avoidFriendly            = false,
		collideFeature           = false,
		collideFriendly          = false,
		canAttackGround 		 = false,
		coreThickness            = 0.5,
		duration                 = 0.1,
		energypershot            = 0,
		explosionGenerator       = "custom:genericshellexplosion-small-sparks-burn",
		fallOffRate              = 1,
		fireStarter              = 50,
		interceptedByShieldType  = 4,
		impulsefactor		     = 0.1,

		largebeamlaser	         = true,
		laserflaresize 	         = 8,
		minintensity             = 1,
		name                     = "High Intensity Laser Beam",
		range                    = 700,
		reloadtime               = 1,
		WeaponType               = "LaserCannon",
		rgbColor                 = "0.25 0 0.6",
		rgbColor2                = "0.8 0.8 0.8",
		soundTrigger             = true,
		soundstart               = "aegis",
		--	soundHit		     = "amphibmedtankshothit",
		scrollspeed		         = 5,
		texture1                 = "shot",
		texture2                 = "laserend",
		thickness                = 10,
		tolerance                = 3000,
		turret                   = true,
		weaponVelocity           = 2500,
		waterweapon		         = true,
		customparams              = {
			expl_light_color	= purple, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                    = {
			default               = 90,
		},
	},

	lightningcannon   	             = {
		avoidFriendly            = false,
		avoidFeature             = false,
		collideFriendly          = false,
		collideFeature           = false,
		canAttackGround 		 = false,
		craterBoost              = 0,
		craterMult               = 0,
		burst                    = 10,
		burstrate                = 0.01,
		beamTTL					 = 1,
		duration                 = 1,
		explosionGenerator       = "custom:genericshellexplosion-electric-small",
		energypershot            = 0,
		edgeeffectiveness		 = 1,
		impulseBoost             = 0,
		impulseFactor            = 0,
		interceptedByShieldType  = 4,
		intensity                = 24,
		laserFlareSize           = 1,

		name			         = "elighttank3weapon",
		noSelfDamage             = true,
		range                    = 700,
		reloadtime               = 1,
		WeaponType               = "LightningCannon",
		rgbColor                 = "1 1 1",
		rgbColor2                = "1 1 1",
		soundStart               = "lightningstrike",
		soundtrigger             = true,

		texture1                 = "lightning",
		thickness                = 1.5,
		turret                   = true,
		weaponVelocity           = 400,
		customparams             = {
			expl_light_color	= white, -- As a string, RGB
			expl_light_radius	= mediumExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
		},
		damage                   = {
			default              = 9,
		},
	},
}