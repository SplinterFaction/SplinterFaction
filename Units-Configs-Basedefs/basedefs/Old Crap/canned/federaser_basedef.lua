unitDef                    = {
	acceleration                 = 1,
	brakeRate                    = 1,
	buildCostEnergy              = 0,
	buildCostMetal               = 28,
	builder                      = false,
	buildTime                    = 5,
	buildpic					 = "eallterrshield.png",
	canAttack                    = false,
	
	canGuard                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = "1",
	category                     = "LIGHT NOTAIR RAID",
	description                  = [[Shield/Cloak Field Emitter]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = "mediumexplosiongenericwhite",
	fireState			         = "0",
	footprintX                   = 2,
	footprintZ                   = 2,
	iconType                     = "shield_lit",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	leaveTracks                  = false,
	maxDamage                    = 200,
	maxVelocity                  = 2.3,
	maxReverseVelocity           = 2,
	turninplacespeedlimit        = 4,
	maxWaterDepth                = 10,
	metalStorage                 = 0,
	movementClass                = "ALLTERRTANK2",
	moveState			         = "0",
	name                         = humanName,
	noChaseCategory              = "VTOL",
	objectName                   = objectName,
	script	                     = script,
	radarDistance                = 0,
	repairable		             = false,
	selfDestructAs               = "mediumexplosiongenericwhite",
	sightDistance                = 200,
	smoothAnim                   = true,
	stealth			             = true,
	seismicSignature             = 2,
	transportbyenemy             = false;
	turnInPlace                  = true,
	turnRate                     = 5000,
	unitname                     = "eallterrshield",
	upright			             = false,
	workerTime                   = 0,
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
			def                  = "allterrshield",
		},
	},
	customParams                 = {
		unittype				 = "mobile",
		canbetransported 		 = "true",
		needed_cover             = 3,
		death_sounds             = "generic",
		RequireTech              = tech,
		armortype                = armortype,
		nofriendlyfire	         = "1",
		supply_cost              = supply,
		shield_power			  = 500,
		shield_radius			  = 300,
		normaltex               = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "Federation of Kala",
		
		retreatRangeDAI			 = 600,
		
		decloakradiushalved		 = true,
		
		area_cloak = 1, -- Can this unit emit a cloaking field?
		area_cloak_upkeep = 0, -- How much energy does it cost to maintain the cloaking field?
		area_cloak_radius = 150, -- How large is the cloaking field?
		--area_cloak_grow_rate = 200, -- When the cloaking field is turned on, how fast does the field expand to it's full size?
		--area_cloak_shrink_rate = 200, -- When the cloaking field is turned off, how fast does the field shrink to nothingness?
		area_cloak_decloak_distance = 150, -- How close does something have to be in order to decloak a unit within a cloaking shield?
		area_cloak_init = true, -- Start up the cloak shield the moment the unit is built?
		area_cloak_draw = true, -- No idea what this does
		area_cloak_self = true, -- Does the cloak shield cloak the unit emitting it?
	},
}


--------------------------------------------------------------------------------

weaponDefs                 = {
	allterrshield                = {
		
		Smartshield              = true,
		Exteriorshield           = true,
		Visibleshield            = false,
		Visibleshieldrepulse     = false,
		ShieldStartingPower      = 0,
		Shieldenergyuse          = 0,
		Shieldradius             = 300,
		Shieldpower              = 500,
		Shieldpowerregen         = 25,
		Shieldpowerregenenergy   = 25,
		Shieldintercepttype      = 4,
		Shieldgoodcolor          = "0.0 0.2 1.0",
		Shieldbadcolor           = "1.0 0 0",
		Shieldalpha              = 0.2,
		
		texture1		         = "shield4",
		
		visibleShieldHitFrames   = 0,
		weaponType               = [[Shield]],
		
		customparams             = {
			isshieldupgraded     = isUpgraded,
		},   
		
		damage                   = {
			default              = 0,
		},
	},
}
