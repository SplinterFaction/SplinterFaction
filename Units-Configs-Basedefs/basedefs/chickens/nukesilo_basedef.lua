unitDef                     = {

	buildAngle                    = 8192,
	buildCostEnergy               = 0,
	buildCostMetal                = buildCostMetal,
	builder                       = false,
	buildTime                     = 5,
	buildpic					  = buildpic,
	canAttack                     = true,
	canstop                       = "1",
	category                      = "BUILDING NOTAIR",
	description                   = description,
	energyMake                    = 0,
	energyStorage                 = 0,
	energyUse                     = 0,
	explodeAs                     = deathexplosion,
	floater						  = true,
	fireState					  = 0,
	footprintX                    = footprintx,
	footprintZ                    = footprintz,
	iconType                      = "esilo",
	idleAutoHeal                  = .5,
	idleTime                      = 2200,
	maxDamage                     = 10000,
	maxSlope                      = 30,
	maxWaterDepth                 = 5000,
	metalStorage                  = 0,
	name                          = name,
	objectName                    = objectname,
	radarDistance                 = 0,
	repairable		              = false,
	script			              = script,
	selfDestructAs                = deathexplosion,
	sightDistance                 = 600,
	smoothAnim                    = true,
	unitlimit                     = "2",
	unitname                      = "nukesilo",
	workerTime                    = 0,
	yardMap                       = "oooooooooooooooo oooooooooooooooo oooooooooooooooo oooooooooooooooo oooooooooooooooo oooooooooooooooo oooooooooooooooo oooooooooooooooo oooooooooooooooo oooooooooooooooo oooooooooooooooo oooooooooooooooo oooooooooooooooo oooooooooooooooo oooooooooooooooo oooooooooooooooo",

	sfxtypes                      = { 
		pieceExplosionGenerators  = { 
			"deathceg3", 
			"deathceg4", 
		}, 

		explosiongenerators       = {
			"custom:needspower",
			"custom:blacksmoke",
			"custom:steam",
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
			def                   = "nukemissile",
		},
	},
	customParams                  = {
		--ProvideTech              = techprovided,
		--RequireTech				 = techrequired,
		unittype				  = "building",
		unitrole                  = "Weapon of Mass Destruction",
		--needed_cover              = 8,
		--supply_cost               = supply,
		stockpileLimit           = 1,
		death_sounds              = "nuke",
		normaltex                = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                 = "unittextures/lego2skin_explorerbucket.dds",
		
		factionname	             = "Neutral",
	},
	useGroundDecal                = false,
	BuildingGroundDecalType       = "factorygroundplate.dds",
	BuildingGroundDecalSizeX      = 18,
	BuildingGroundDecalSizeY      = 18,
	BuildingGroundDecalDecaySpeed = 0.9,
}

weaponDefs                  = {
	nukemissile                   = {
		AreaOfEffect              = 1500,
		avoidFriendly             = false,
		avoidFeature              = false,
		cegTag                    = "NUKETRAIL",
		collideFriendly           = false,
		collideFeature            = false,
		commandFire				  = true,
		craterBoost               = 0,
		craterMult                = 0,
		edgeeffectiveness		  = 1,
		energypershot             = 0,
		explosionGenerator        = "custom:nukedatbewm",
		fireStarter               = 100,
		flightTime                = 400,
		
		id                        = 124,
		impulseBoost              = 0,
		impulseFactor             = 0,
		--interceptedByShieldType   = 4,
		
		metalpershot              = 0,
		model                     = "neutralmissilex4.s3o",
		name                      = "Nuke",
		range                     = 32000,
		reloadtime                = 200,
		weaponType		          = "MissileLauncher",
		
		
		smokeTrail                = false,
		soundHit                  = "explosions/explosion_enormous.wav",
		soundStart                = "weapons/nukelaunch.wav",
		
		stockpile                 = true,
		stockpileTime             = 500,
		startVelocity             = 10,
		tracks                    = true,
		turnRate                  = 3000,
		targetable			      = 1,
		
		weaponAcceleration        = 60,
		weaponTimer               = 5,
		weaponType                = "StarburstLauncher",
		weaponVelocity            = 1000,
		customparams              = {
			damagetype			  = "antibuilding", 
			death_sounds 		  = "nuke",
			oldcosttofireforumula = true,
			effectedByunitHealthModifier = true,
			friendlyfireexception = true,
		},      
		damage                    = {
			default               = 100000,
		},
	},
}
