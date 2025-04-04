return {
	lootdroppod_gold = {
		acceleration = 0,
		activatewhenbuilt = true,
		autoheal = 1.8,
		bmcode = "0",
		brakerate = 0,
		buildcostenergy = 25000,
		buildcostmetal = 400,
		builddistance = 90,
		buildtime = 10500,
		canmove = false,
		capturable = false,
		category = "ALL NOTLAND NOTSUB NOWEAPON NOTSHIP NOTAIR NOTHOVER SURFACE EMPABLE",
		collisionvolumeoffsets = "0 0 0",
		collisionvolumescales = "0 0 0",
		collisionvolumetype = "box",
		description = "Drops LOOT in your battle",
		energystorage = 1000,
		explodeas = "",
		footprintx = 0,
		footprintz = 0,
		idleautoheal = 10,
		idletime = 90,
		levelground = false,
		mass = 165.75,
		maxdamage = 1800,
		maxvelocity = 0,
		name = "Lootbox Droppod",
		noautofire = false,
		objectname = "scavs/cube.s3o",
		pushResistant = true,
		radardistance = 900,
		script = "scavs/droppod.cob",
		seismicsignature = 4,
		selfdestructas = "",
		selfdestructcountdown = 0,
		side = "ARM",
		sightdistance = 450,
		smoothanim = true,
		tedclass = "ENERGY",
		turninplace = true,
		turninplaceanglelimit = 90,
		turnrate = 0,
		unitname = "lootdroppod_gold",
		upright = false,
		waterline = 0,
		workertime = 1500,
		yardmap = "",
		customparams = {
			isairbase = true,
			normaltex = "unittextures/bfaction_normals.dds",
			subfolder = "lootboxes",
		},
		featuredefs = {},
		sfxtypes = {
			explosiongenerators = {
				-- [1] = "custom:dirtpoof",
			},
		},
		weapondefs = {
			weapon = {
				alwaysvisible = true,
				areaofeffect = 500,
				avoidfriendly = 0,
				cegtag = "lootbox-trail",
				collidefriendly = 0,
				craterboost = 0,
				cratermult = 0,
				edgeeffectiveness = 0.3,
				-- explosiongenerator = "custom:dirtpoof",
				firestarter = 70,
				flighttime = 800,
				impulsefactor = 0.1,
				interceptedbyshieldtype = 4,
				metalpershot = 0,
				--model = "Lootboxes/lootbox.s3o",
				name = "Lootbox",
				range = 59999,
				reloadtime = 5,
				rgbcolor = "0.95 0.78 0",
				smoketrail = 1,
				soundhit = "voice/scavengers/scavspawn",
				startvelocity = 1,
				targetborder = 0.75,
				turret = 1,
				weaponacceleration = 50,
				weapontimer = 2,
				weapontype = "MissileLauncher",
				weaponvelocity = 100,
				wobble = 50,
				customparams = {
					expl_light_color = "0.95 0.78 0",
					expl_light_life_mult = 2.4,
					expl_light_mult = 1.4,
					expl_light_radius_mult = 1.6,
				},
				damage = {
					chicken = 1,
					default = 1,
				},
			},
		},
		weapons = {
			[1] = {
				def = "WEAPON",
			},
		},
	},
}
