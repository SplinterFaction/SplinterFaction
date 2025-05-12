unitDef                    = {

	--mobileunit 
	transportbyenemy             = false;
	--**

	buildCostEnergy              = 0,
	buildCostMetal               = 2500,
	builder                      = false,
	buildTime                    = 5,
	buildpic					 = [[feddeleter.png]],
	canAttack                    = true,
	
	canGuard                     = true,
	canHover                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = "1",
	category                     = "GROUND MASSIVE",
	description                  = [[Heavy Area Cloak and Repair Mech]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = explodeAs,
	fireState					 = 0,
	footprintX                   = 4,
	footprintZ                   = 4,
	iconType                     = "botcounterintelt3",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	leaveTracks                  = false,
	maxDamage                    = 75,
	maxSlope                     = 90,
	maxVelocity                  = 1.8,
	maxReverseVelocity           = 1,
	maxWaterDepth                = 10,
	metalStorage                 = 0,
	movementClass                = "WALKERTANK4",
	name                         = humanName,
	noChaseCategory              = "VTOL",
	objectName                   = objectName,
	script			             = script,
	radarDistance                = 0,
	radarDistanceJam             = 500,
	repairable		             = false,
	selfDestructAs               = explodeAs,
	side                         = "CORE",
	sightDistance                = 650,
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
	turnrate 				 	 = 350,
	--------------
	--------------

	--------------
	-- Cloaking --
	--------------
	cancloak		             = true,
	cloakCost		             = 0,
	cloakCostMoving	             = 0,
	minCloakDistance             = 300,
	decloakOnFire	             = false,
	decloakSpherical             = true,
	initCloaked		             = true,
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
			def                  = "dummy",
		},
	},
	customParams                 = {
		isupgraded			  	 = isUpgraded,
		unittype				 = "mobile",
		unitrole				 = "Support",
		canbetransported 		 = "true",
		needed_cover             = 1,
		death_sounds             = "generic",
		RequireTech              = tech,
		nofriendlyfire	         = true,
		supply_cost              = 1,
		normaltex               = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "Federation of Kala",
		corpse                   = "energycore",

		area_cloak = 1, -- Can this unit emit a cloaking field?
		area_cloak_upkeep = 0, -- How much energy does it cost to maintain the cloaking field?
		area_cloak_radius = 500, -- How large is the cloaking field?
		area_cloak_grow_rate = 200, -- When the cloaking field is turned on, how fast does the field expand to it's full size?
		area_cloak_shrink_rate = 200, -- When the cloaking field is turned off, how fast does the field shrink to nothingness?
		area_cloak_decloak_distance = 50, -- How close does something have to be in order to decloak a unit within a cloaking shield?
		area_cloak_init = true, -- Start up the cloak shield the moment the unit is built?
		area_cloak_draw = true, -- No idea what this does
		area_cloak_self = true, -- Does the cloak shield cloak the unit emitting it?

		areaheal_radius          = "500",
		areaheal_amount          = "50",
		areaheal_delayafterdamage = "5", -- 5 seconds after damage before healing resumes

		-- Begin unit rings
		ring_color = "0,1,0,0.25",
		ring_radius = "500",
		ring_linewidth = "10",
		ring_divs = "128",
		ring_alwaysshow = "true",
		--ring_texture = "LuaUI/Images/customringtextures/green_ring_fill.dds", -- texture overlay (super clean & fast)
		--ing_texsize = "1024", -- size of texture quad in world units
	},
}

weaponDefs                 = {
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
