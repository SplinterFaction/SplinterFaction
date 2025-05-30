-- UNITDEF -- EMETEOR --
--------------------------------------------------------------------------------

local unitName                   = "emeteor"

--------------------------------------------------------------------------------

local armortype				 = [[building]]
local supplyGiven				 = [[0]]
local techprovided				 = [[]]
local techrequired				 = [[tech3]]


local unitDef                    = {

	--mobileunit 
	transportbyenemy             = false; 

	--**
	
	buildCostEnergy              = 0,
	buildCostMetal               = 1500,
	buildTime                    = 2.5,
	buildpic					 = "etech1.png",
	capturable		             = false,
	CanAttack			         = true,
	CanAssist			         = false,
	canBeAssisted                = true,
	CanCapture                   = false,
	CanRepair			         = false,
	canRestore					 = false,
	
	canGuard                     = true,
	canMove                      = false,
	canPatrol                    = false,
	canreclaim		             = false,
	canstop                      = true,
	category                     = "NOTAIR BUILDING",
	description                  = [[Astrological Control Center]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = "commnuke",
	footprintX                   = 8,
	footprintZ                   = 8,

	iconType                     = "turret_arty",
	idleAutoHeal                 = 5,
	idleTime                     = 300,
	levelground                  = true,
	maxDamage                    = 20000,
	maxSlope                     = 180,
	maxWaterDepth                = 5000,
	metalmake                    = 0,
	metalStorage                 = 0,
	moveState			         = "0",
	name                         = "The Meteor Overseer",
	noChaseCategories	         = "NOTAIR SUPPORT VTOL AMPHIB",
	fireState					 = 0,
	objectName                   = "ecommander-meteor.s3o",
	script			             = "ecommander4-meteor.cob",
	radarDistance                = 0,
	repairable		             = false,
	selfDestructAs               = "commnuke",
	sightDistance                = 250,
	smoothAnim                   = true,
	stealth			             = true,
	unitname                     = unitName,
	upright                      = false,
	yardmap						 = "oooooooo oooooooo oooooooo oooooooo oooooooo oooooooo oooooooo oooooooo",
	
	sfxtypes                     = {
		pieceExplosionGenerators = { 
			"deathceg3", 
			"deathceg4", 
		}, 
		
		explosiongenerators      = {
			"custom:nanoorb",
			"custom:emptydirt",
			"custom:blacksmoke",
			"custom:gdhcannon",
		},
	},
	--buildoptions                 = Shared.buildList,
	sounds                       = {
		build					 = "miscfx/buildstart.wav",
		underattack              = "other/unitsunderattack1",
		ok                       = {
			"ack",
		},
		select                   = {
			"unitselect",
		},
	},
	weapons                      = {
		-- [1]                      = {
			-- def                  = "riottankempweapon",
		-- },
		[1]                      = {
			def                  = "meteor",
			badtargetcategory     = "VTOL LIGHT ARMORED",
		},
	},
	customParams                 = {
		unittype				  = "mobile",
		ProvideTech              = techprovided,
		RequireTech				 = techrequired,
		canbetransported 		 = "true",
		needed_cover             = 2,
		supply_granted            = supplyGiven,
		death_sounds             = "generic",
		
		armortype                = armortype,
		nofriendlyfire	         = "1",
		normaltex               = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "ateran",
	},
	useGroundDecal                = true,
	BuildingGroundDecalType       = "factorygroundplate.dds",
	BuildingGroundDecalSizeX      = 10,
	BuildingGroundDecalSizeY      = 10,
	BuildingGroundDecalDecaySpeed = 0.9,
}

--------------------------------------------------------------------------------

local weaponDefs                 = {
	meteor             = {
		AreaOfEffect             = 500,
		avoidFriendly            = false,
		avoidFeature             = false,
		collideFriendly          = false,
		collideFeature           = false,
		commandFire				 = true,
		burst					 = 100,
		burstrate				 = 0.1,
		--projectiles			 = 5,
		cegTag                   = "METEORTRAIL",
		commandfire				 = true,
		explosionGenerator       = "custom:genericshellexplosion-large",
		energypershot            = 0,
		impulseFactor            = 0,
		interceptedByShieldType  = 4,
		name                     = unitName .. "Weapon",
		range                    = 50000,
		reloadtime               = 120,
		size					 = 16,
		weaponType		         = "Cannon",
		soundHit                 = "explosions/explode3.wav",
		soundStart               = "weapons/meteorwhoosh.wav",
		sprayangle 				 = 1000,
		tolerance                = 2000,
		turret                   = true,
		weaponVelocity           = 1000,
		customparams             = {		
			damagetype		     = "antibuilding",  
			friendlyfireexception = true,
		},      
		damage                   = {
			default              = 100,
		},
	},
	commnuke                   = {
		AreaOfEffect              = 500,
		avoidFriendly             = false,
		avoidFeature              = false,
		cegTag                    = "NUKETRAIL",
		collideFriendly           = false,
		collideFeature            = false,
		craterBoost               = 0,
		craterMult                = 0,
		edgeeffectiveness		  = 0.1,
		energypershot             = 0,
		explosionGenerator        = "custom:NUKEDATBEWMSMALL",
		fireStarter               = 100,
		flightTime                = 400,
		
		id                        = 124,
		impulseBoost              = 0,
		impulseFactor             = 0,
		interceptedByShieldType   = 4,
		
		metalpershot              = 0,
		model                     = "enuke.s3o",
		name                      = "Nuke",
		range                     = 32000,
		reloadtime                = 60,
		weaponType		          = "MissileLauncher",
		
		
		smokeTrail                = false,
		soundHit                  = "explosions/explosion_enormous.wav",
		soundStart                = "weapons/nukelaunch.wav",
		
--		stockpile                 = true,
--		stockpileTime             = stockpiletime,
		startVelocity             = 10,
		tracks                    = true,
		turnRate                  = 3000,
		targetable			      = 1,
		
		weaponAcceleration        = 30,
		weaponTimer               = 15,
		weaponType                = "StarburstLauncher",
		weaponVelocity            = 1000,
		customparams              = {
			damagetype		      = "light",  
			death_sounds 		  = "nuke",
			nocosttofire		  = true,
		},      
		damage                    = {
			default               = 1000,
		},
	},
}
unitDef.weaponDefs               = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
