unitDef                    = {

	--mobileunit 
	transportbyenemy             = false;
	--**

	buildCostEnergy              = 0,
	buildCostMetal               = 7500,
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
	description                  = [[Heavy Area Cloaker Mech]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = explodeAs,
	footprintX                   = 4,
	footprintZ                   = 4,
	iconType                     = "mbt",
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
		underattack              = "other/unitsunderattack1",
		ok                       = {
			"ack",
		},
		select                   = {
			"unitselect",
		},
	},
	weapons                      = {
	},
	customParams                 = {
		isupgraded			  	 = isUpgraded,
		unittype				 = "mobile",
		unitrole				 = "Main Battle Tank - Tech 3",
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
		area_cloak_radius = 300, -- How large is the cloaking field?
		--area_cloak_grow_rate = 200, -- When the cloaking field is turned on, how fast does the field expand to it's full size?
		--area_cloak_shrink_rate = 200, -- When the cloaking field is turned off, how fast does the field shrink to nothingness?
		area_cloak_decloak_distance = 100, -- How close does something have to be in order to decloak a unit within a cloaking shield?
		area_cloak_init = true, -- Start up the cloak shield the moment the unit is built?
		area_cloak_draw = true, -- No idea what this does
		area_cloak_self = true, -- Does the cloak shield cloak the unit emitting it?
	},
}
