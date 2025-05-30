return {
	lootboxbronze = {
		acceleration = 0,
		activatewhenbuilt = true,
		autoheal = 1,
		brakerate = 0,
		buildcostenergy = 25000,
		buildcostmetal = 375,
		buildtime = 5000,
		canfight = false,
		canguard = false,
		canhover = true,
		canmove = false,
		canpatrol = false,
		canrepeat = false,
		canselfdestruct = false,
		canstop = false,
		cantbetransported = false,
		capturable = true,
		category = "BUILDING",
		
		description = "Bronze Lootbox: While you maintain control of it, this lootbox will provide extra resources.",
		energymake = 20,
		explodeas = "lootboxExplosion1",
		floater = true,
		footprintx = 3,
		footprintz = 3,
		icontype = "lootbox",
		idleautoheal = 10,
		idletime = 1800,
		levelground = false,
		mass = 4000,
		maxdamage = 3000,
		maxslope = 10,
		maxvelocity = 0.00000001,
		maxwaterdepth = 0,
		metalmake = 1,
		movestate = 0,
		name = "Lootbox",
		noautofire = false,
		objectname = "lootboxes/lootbox3x3.s3o",
		pushResistant = true,
		script = "lootboxes/lootboxgold.cob",
		seismicsignature = 0,
		selfdestructas = "lootboxExplosion1",
		selfdestructcountdown = 9,
		sightdistance = 96,
		transportbyenemy = true,
		turninplace = false,
		turnrate = 0,
		unitname = "lootboxgold",
		upright = true,
		usebuildinggrounddecal = true,
		--waterline = 0,
		yardmap = "ooo ooo ooo",
		customparams = {
			normaltex = "unittextures/bfaction_normals.dds",
			subfolder = "lootboxes",
		},
		sfxtypes = {
			explosiongenerators = {
				[1] = "custom:LootboxLightGold",
				[2] = "custom:LootboxBeaconBronze",
			},
			pieceexplosiongenerators = {
				[1] = "deathceg3",
				[2] = "deathceg4",
			},
		},
	},
}
