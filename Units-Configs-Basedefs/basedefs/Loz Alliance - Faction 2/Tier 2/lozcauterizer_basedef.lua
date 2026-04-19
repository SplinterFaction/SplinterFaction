unitDef                    = {
	buildCostEnergy              = 0,
	buildCostMetal               = 1900,
	builder                      = false,
	buildTime                    = 5,
	buildpic					 = "lozcauterizer.png",
	canAttack                    = true,
	canGuard                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = "1",
	category                     = "GROUND",
	description                  = [[Heat Ray Tank]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = explodeAs,
	footprintX                   = 4,
	footprintZ                   = 4,
	iconType                     = "tankassaultt2",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	leaveTracks                  = false,
	maxDamage                    = 375,
	maxSlope                     = 26,
	maxVelocity                  = 2.7,
	maxReverseVelocity           = 1,
	maxWaterDepth                = 10,
	metalStorage                 = 0,
	movementClass                = "WHEELEDTANK4",
	name                         = humanName,
	noChaseCategory              = "VTOL",
	objectName                   = objectName,
	script			             = script,
	radarDistance                = 0,
	repairable		             = false,
	selfDestructAs               = explodeAs,
	side                         = "CORE",
	sightDistance                = 450,
	smoothAnim                   = true,
	stealth			             = true,
	seismicSignature             = 2,
	transportbyenemy             = false;
	unitname                     = unitName,
	upright                      = false,
	workerTime                   = 0,
	--------------
	-- Movement --
	--------------
	acceleration 				 = 2,
	brakeRate                    = 0.1,
	turninplace 				 = true,
	turninplacespeedlimit 		 = 10,
	turnInPlaceAngleLimit		 = 45,
	turnrate 				 	 = 400,
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
			def                  = "heatraymk2",
			onlyTargetCategory    = "GROUND SHIP",
		},
	},
	customParams                 = {
		unitguide = [[The Cauterizer is the Loz Alliance's Tier 2 heat ray tank, carrying a significantly upgraded wave laser that burns through targets with greater intensity than its Flashpoint predecessor. The heat accumulation mechanic remains — each burst stacks thermal stress until the target malfunctions — but the Cauterizer hits harder and reaches further, making it far more threatening against armored Tier 2 opposition.]],
		unittype				 = "mobile",
		unitrole				 = "Heatray Tank - Tech 2",
		buildmenucategory        = "Skirmish",
		canbetransported 		 = "true",
		needed_cover             = 3,
		death_sounds             = "generic",
		RequireTech              = tech,
		nofriendlyfire	         = "1",
		supply_cost              = 1,
		normaltex                = "unittextures/lego2skin_explorernormal.dds", 
		buckettex                = "unittextures/lego2skin_explorerbucket.dds",
		factionname	             = "Loz Alliance",
		
	}
}

weaponDefs                 = {
	heatraymk2           = {
		edgeeffectiveness        = 0.1,
		hardstop                 = true,
		avoidGround               = false,
		avoidFeature              = false,
		avoidFriendly             = false,
		collideFeature            = false,
		collideFriendly           = false,
		coreThickness             = 0.3,
		duration                  = 0.1,
		burst                     = 15,
		burstrate                 = 0.1,
		energypershot             = 120,
		edgeeffectiveness		  = 0,
		explosionGenerator        = "custom:genericshellexplosion-small",
		fallOffRate               = 0.1,
		fireStarter               = 100,
		impulseFactor             = 0,
		interceptedByShieldType   = 4,
		minintensity              = 0.1,
		name                      = "High Intensity WaveLaser",
		range                     = 600,
		reloadtime                = 9,
		WeaponType                = "LaserCannon",
		rgbColor                  = red,
		rgbColor2                 = "1 1 1",
		soundTrigger              = true,
		soundstart                = "flashpointheatray",
		soundHit                  = "phasegun1hit.wav",
		-- sprayangle				  = 500,
		texture1                 = "wave",
		texture2                 = "empty",
		thickness                 = 20,
		tolerance                 = 1000,
		turret                    = true,
		weaponVelocity            = 2000,
		waterweapon				 = false,
		noexplode                 = true,
		customparams              = {
			weaponguide = [[An upgraded high-intensity wave laser that fires in rapid bursts, stacking heat damage with every hit. Targets that absorb enough thermal energy malfunction and shut down entirely, a fate increasingly unavoidable the longer the Cauterizer stays on them.]],
			expl_light_color	= red, -- As a string, RGB
			expl_light_radius	= mediumExplosion, -- In Elmos
			expl_light_life		= mediumExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
			single_hit            = "true",
			heatweapon = "1",
			heatmult   = "1.0", -- optional; higher = heats faster per damage
		},
		damage                    = {
			default               = 225,
		},
	},
}
