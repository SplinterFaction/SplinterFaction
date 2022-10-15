unitDef                       = {
	acceleration                 = 0.25,
	airStrafe                    = true,
	brakeRate                    = 0.25,
	buildCostEnergy              = 0,
	buildCostMetal               = 20,
	buildTime                    = 2.5,
	buildpic                     = "neutralscoutdrone.png",
	canAttack                    = true,
	canDropFlare                 = false,
	canFly                       = true,

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	-- Fix Spring's Awful Defaults for Planes
	-- Flight Characteristics Settings
 --[[
	wingDrag                     = 0.07,
	wingAngle                    = 0.08,
	frontToSpeed                 = 0, -- New Default
	speedToFront                 = 0.1, -- New Default
	crashDrag                    = 0.005,
	maxBank                      = 0.7, -- New Default
	maxPitch                     = 0.65, -- New Default
	turnRadius                   = 200.0, -- New Default
	verticalSpeed                = 3.0,
	maxAileron                   = 0.025, -- New Default
	maxElevator                  = 0.01,
	maxRudder                    = 0.01, -- use this to control turn radius around Y axis - Best value for fighters is 0.01
	maxAcc                       = 1.2, -- OG Default was 0.065
]]--
	useSmoothMesh                = true,

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------

	canGuard                     = true,
	canLoopbackAttack            = false,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = true,
	category                     = "AIR",
	collide                      = false,
	cruiseAlt                    = 75,
	description                  = [[Scouting Drone]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = "smallExplosionGenericPurple",
	footprintX                   = 2,
	footprintZ                   = 2,
	hoverAttack                  = true,
	iconType                     = "drone",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	maxDamage                    = 220,
	maxSlope                     = 90,
	maxVelocity                  = 10,
	--verticalSpeed              = 15,
	maxWaterDepth                = 0,
	metalStorage                 = 0,
	name                         = humanName,
	objectName                   = objectName,
	script                       = script,
	radarDistance                = 0,
	repairable                   = false,
	selfDestructAs               = "smallExplosionGenericPurple",
	sightDistance                = 500,
	smoothAnim                   = true,
	stealth                      = true,
	turnRate                     = 200,
	unitname                     = unitName,
	sfxtypes                     = {
		pieceExplosionGenerators    = {
			"deathceg3",
			"deathceg4",
		},

		explosiongenerators         = {
			"custom:jetstrail",
			"custom:blacksmoke",
		},
	},
	sounds                       = {
		underattack                 = "other/unitsunderattack1",
		ok                          = {
			"ack",
		},
		select                      = {
			"unitselect",
		},
	},
	customParams                 = {
		unittype                    = "air",
		unitrole                    = "Scout",
		death_sounds                = "generic",
		RequireTech                 = tech,
		supply_cost                 = 1,
		normaltex                   = "unittextures/lego2skin_explorernormal.dds",
		buckettex                   = "unittextures/lego2skin_explorerbucket.dds",
		factionname                 = "Neutral",
	},
}

--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
