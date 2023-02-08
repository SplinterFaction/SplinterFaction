
local difficulties = {
	-- veryeasy = 0,
	-- easy     = 1,
	normal   = 0,
	hard     = 1,
	veryhard = 2,
	insane   = 3,
	epic     = 4,
	unbeatable = 5,
	survival = 6,
}

local difficulty = difficulties[Spring.GetModOptions().chicken_difficulty]
local burrowName = 'healstation_ai'

chickenTurrets = {
	-- Weapons
	["fedmenlo"] 					= { minQueenAnger = 0, 		spawnedPerWave = 3,		spawnOnBurrows = true	},
	["lozjericho"] 					= { minQueenAnger = 0, 		spawnedPerWave = 3,		spawnOnBurrows = true	},
	["fedstinger"] 					= { minQueenAnger = 0, 		spawnedPerWave = 3,		spawnOnBurrows = false	},
	["lozrazor"] 					= { minQueenAnger = 0, 		spawnedPerWave = 3,		spawnOnBurrows = false	},
	["fedimmolator"] 				= { minQueenAnger = 20, 	spawnedPerWave = 3,		spawnOnBurrows = true,	maxQueenAnger = 1000},
	["lozinferno"] 					= { minQueenAnger = 20, 	spawnedPerWave = 3,		spawnOnBurrows = true,	maxQueenAnger = 1000},
	["fedjavelin"] 					= { minQueenAnger = 20, 	spawnedPerWave = 3,		spawnOnBurrows = false,	maxQueenAnger = 1000},
	["lozrattlesnake"] 				= { minQueenAnger = 20, 	spawnedPerWave = 3,		spawnOnBurrows = false,	maxQueenAnger = 1000},
	["fedguardian"]					= { minQueenAnger = 40, 	spawnedPerWave = 1,		spawnOnBurrows = false,	maxQueenAnger = 1000},
	["lozannihilator"]				= { minQueenAnger = 40, 	spawnedPerWave = 1,		spawnOnBurrows = false,	maxQueenAnger = 1000},
	["fedbertha"]					= { minQueenAnger = 60, 	spawnedPerWave = 1,		spawnOnBurrows = false	},
	["lozintimidator"]				= { minQueenAnger = 60, 	spawnedPerWave = 1,		spawnOnBurrows = false	},

	-- Utility
	["cloakingtower"] 				= { minQueenAnger = 40, 	spawnedPerWave = 2,		spawnOnBurrows = true,	maxQueenAnger = 1000},
	["smallshieldgenerator"] 		= { minQueenAnger = 40, 	spawnedPerWave = 2,		spawnOnBurrows = true	},
	["largeshieldgenerator"] 		= { minQueenAnger = 60, 	spawnedPerWave = 2,		spawnOnBurrows = true	},

	-- Eco Fillers
	 -- Power
	["fissionpowerplant"] 			= { minQueenAnger = 0, 		spawnedPerWave = 1,		spawnOnBurrows = false	},
	["fusionpowerplant"] 			= { minQueenAnger = 20, 	spawnedPerWave = 1,		spawnOnBurrows = false	},
	["coldfusionpowerplant"] 		= { minQueenAnger = 40, 	spawnedPerWave = 1,		spawnOnBurrows = false	},
	["blackholepowerplant"] 		= { minQueenAnger = 60, 	spawnedPerWave = 1,		spawnOnBurrows = false	},
	 -- Storage
	["supplydepot"] 				= { minQueenAnger = 0, 		spawnedPerWave = 1,		spawnOnBurrows = false	},
	["mediumsupplydepot"] 			= { minQueenAnger = 20, 	spawnedPerWave = 1,		spawnOnBurrows = false	},
	["mediumstorage"] 				= { minQueenAnger = 20, 	spawnedPerWave = 1,		spawnOnBurrows = false	},
	["largestorage"] 				= { minQueenAnger = 40, 	spawnedPerWave = 1,		spawnOnBurrows = false	},
}

local chickenEggs = { -- Specify eggs dropped by unit here, requires useEggs to be true, if some unit is not specified here, it drops random egg colors.

}

chickenBehaviours = {
	SKIRMISH = { -- Run away from target after target gets hit -- This is for fast light units
		[UnitDefNames["fedak"].id] = { distance = 500, chance = 0.5 },
		[UnitDefNames["fedstorm"].id] = { distance = 500, chance = 0.5 },
		[UnitDefNames["fedthud"].id] = { distance = 500, chance = 0.5 },
		[UnitDefNames["fedcrasher"].id] = { distance = 500, chance = 0.5 },
		[UnitDefNames["lozdiamondback"].id] = { distance = 500, chance = 0.5 },
		[UnitDefNames["lozroach"].id] = { distance = 500, chance = 0.5 },
		[UnitDefNames["lozscorpion"].id] = { distance = 500, chance = 0.5 },
		[UnitDefNames["fedbear"].id] = { distance = 500, chance = 0.5 },
		[UnitDefNames["fedcobra"].id] = { distance = 500, chance = 0.5 },
		[UnitDefNames["fedavalanche"].id] = { distance = 500, chance = 0.5 },
		[UnitDefNames["fedphalanx"].id] = { distance = 500, chance = 0.5 },
		[UnitDefNames["lozreaper"].id] = { distance = 500, chance = 0.5 },
		[UnitDefNames["lozluger"].id] = { distance = 500, chance = 0.5 },
		[UnitDefNames["fedengineer_ai"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["lozengineer_ai"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["lozeurypterid"].id] = { distance = 500, chance = 1 },
		

		--[[
		[UnitDefNames["chickens2"].id] = { distance = 250, chance = 0.5 },
		[UnitDefNames["chickenr1"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickenr2"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickene1"].id] = { distance = 300, chance = 1 },
		[UnitDefNames["chickene2"].id] = { distance = 200, chance = 0.01 },	
		[UnitDefNames["chickenelectricallterrainassault"].id] = { distance = 200, chance = 0.01 },
		[UnitDefNames["chickenearty1"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickenelectricallterrain"].id] = { distance = 300, chance = 1 },
		[UnitDefNames["chickenacidswarmer"].id] = { distance = 300, chance = 1 },
		[UnitDefNames["chickenacidassault"].id] = { distance = 200, chance = 1 },
		[UnitDefNames["chickenacidallterrainassault"].id] = { distance = 200, chance = 1 },
		[UnitDefNames["chickenacidarty"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickenacidallterrain"].id] = { distance = 300, chance = 1 },
		[UnitDefNames["chickenh2"].id] = { distance = 500, chance = 0.25 },
		[UnitDefNames["chicken1x_spectre"].id] = { distance = 500, chance = 0.25, teleport = true, teleportcooldown = 2,},
		[UnitDefNames["chicken2_spectre"].id] = { distance = 500, chance = 0.25, teleport = true, teleportcooldown = 2,},
		[UnitDefNames["chickens2_spectre"].id] = { distance = 500, chance = 0.25, teleport = true, teleportcooldown = 2,},
		]]--
	},
	COWARD = { -- Run away from target after getting hit by enemy -- This is for fast light units
		[UnitDefNames["fedak"].id] = { distance = 500, chance = 0.5 },
		[UnitDefNames["fedstorm"].id] = { distance = 500, chance = 0.5 },
		[UnitDefNames["fedthud"].id] = { distance = 500, chance = 0.5 },
		[UnitDefNames["fedcrasher"].id] = { distance = 500, chance = 0.5 },
		[UnitDefNames["lozdiamondback"].id] = { distance = 500, chance = 0.5 },
		[UnitDefNames["lozroach"].id] = { distance = 500, chance = 0.5 },
		[UnitDefNames["lozscorpion"].id] = { distance = 500, chance = 0.5 },
		[UnitDefNames["fedbear"].id] = { distance = 500, chance = 0.5 },
		[UnitDefNames["fedcobra"].id] = { distance = 500, chance = 0.5 },
		[UnitDefNames["fedavalanche"].id] = { distance = 500, chance = 0.5 },
		[UnitDefNames["fedphalanx"].id] = { distance = 500, chance = 0.5 },
		[UnitDefNames["lozreaper"].id] = { distance = 500, chance = 0.5 },
		[UnitDefNames["lozluger"].id] = { distance = 500, chance = 0.5 },
		[UnitDefNames["fedengineer_ai"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["lozengineer_ai"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["lozeurypterid"].id] = { distance = 500, chance = 0.5 },

	},
	BERSERK = { -- Run towards target after getting hit by enemy or after hitting the target-- This is for heavy slow units
		[UnitDefNames["fedgoliath"].id] = { distance = 3000, chance = 0.5 },
		[UnitDefNames["fedjuggernaut"].id] = { distance = 3000, chance = 0.5 },
		[UnitDefNames["lozmammoth"].id] = { distance = 3000, chance = 0.5 },
		[UnitDefNames["lozsilverback"].id] = { distance = 3000, chance = 0.5 },
		[UnitDefNames["fedanarchid"].id] = { distance = 3000, chance = 0.5 },
		[UnitDefNames["fedanarchid_normal"].id] = { distance = 3000, chance = 0.01 },
		[UnitDefNames["fedanarchid_hard"].id] = { distance = 3000, chance = 0.01 },
		[UnitDefNames["fedanarchid_veryhard"].id] = { distance = 3000, chance = 0.01 },
		[UnitDefNames["fedanarchid_insane"].id] = { distance = 3000, chance = 0.01 },
		[UnitDefNames["fedanarchid_epic"].id] = { distance = 3000, chance = 0.01 },
		[UnitDefNames["fedanarchid_unbeatable"].id] = { distance = 3000, chance = 0.01 },
	},
	HEALER = { -- Getting long max lifetime and always use Fight command. These units spawn as healers from burrows and queen
		[UnitDefNames["lozengineer_ai"].id] = true,
		[UnitDefNames["fedengineer_ai"].id] = true,
	},
	ARTILLERY = { -- Long lifetime and no regrouping, always uses Fight command to keep distance
		[UnitDefNames["fedavalanche"].id] = true,
		[UnitDefNames["lozluger"].id] = true,
	},
	KAMIKAZE = { -- Long lifetime and no regrouping, always uses Move command to rush into the enemy

	},
	PROBE_UNIT = UnitDefNames["lozreaper"].id, -- tester unit for picking viable spawn positions - use some medium sized unit
}

local optionValues = {

	[difficulties.normal] = {
		chickenSpawnRate  = 30, -- Time between Waves in seconds
		burrowSpawnRate   = 75, -- Time inbetween burrow spawns in seconds
		turretSpawnRate   = 180, -- Time inbetween turret spawns in seconds
		queenSpawnMult    = 1, -- Unused, don't touch (just in case)
		angerBonus        = 0.2, -- Multiplier for boss anger when you kill a burrow
		maxXP			  = 0.5, -- Random amount of XP given to spawned units
		spawnChance       = 0.2, -- What are the chances that a burrow will spawn units each wave (this check is performed on each burrow)
		damageMod         = 1, -- Multiplier for how much damage spawned units will deal to player units
		maxBurrows        = 1000, -- Maximum number of burrows that can be on the map
		chickenPerPlayerMultiplier = 1, -- This modifies the minimum and maximum number of chickens that will spawn for each player on the map
		minChickens		  = 10, -- Number of ai units spawned in the beginning stages of the game per wave
		maxChickens		  = 40, -- Number of ai units spawned in the end stages of the game per wave
		queenName         = 'fedanarchid_normal',
		queenResistanceMult   = 1.5, -- Multipler for how quickly the queen will gain resistances for each weapon
	},

	[difficulties.hard] = {
		chickenSpawnRate  = 30,
		burrowSpawnRate   = 60,
		turretSpawnRate   = 120,
		queenSpawnMult    = 1,
		angerBonus        = 0.2,
		maxXP			  = 1,
		spawnChance       = 0.3,
		damageMod         = 1,
		maxBurrows        = 1000,
		minChickens		  = 10,
		maxChickens		  = 50,
		queenName         = 'fedanarchid_hard',
		queenResistanceMult   = 1.5,
	},
	[difficulties.veryhard] = {
		chickenSpawnRate  = 30,
		burrowSpawnRate   = 45,
		turretSpawnRate   = 90,
		queenSpawnMult    = 3,
		angerBonus        = 0.2,
		maxXP			  = 1.5,
		spawnChance       = 0.4,
		damageMod         = 1,
		maxBurrows        = 1000,
		minChickens		  = 10,
		maxChickens		  = 75,
		queenName         = 'fedanarchid_veryhard',
		queenResistanceMult   = 2,
	},
	[difficulties.insane] = {
		chickenSpawnRate  = 30,
		burrowSpawnRate   = 30,
		turretSpawnRate   = 60,
		queenSpawnMult    = 3,
		angerBonus        = 0.2,
		maxXP			  = 2,
		spawnChance       = 0.5,
		damageMod         = 1,
		maxBurrows        = 1000,
		minChickens		  = 10,
		maxChickens		  = 100,
		queenName         = 'fedanarchid_insane',
		queenResistanceMult   = 2.5,
	},
	[difficulties.epic] = {
		chickenSpawnRate  = 30,
		burrowSpawnRate   = 20,
		turretSpawnRate   = 40,
		queenSpawnMult    = 3,
		angerBonus        = 0.2,
		maxXP			  = 5,
		spawnChance       = 0.6,
		damageMod         = 1,
		maxBurrows        = 1000,
		minChickens		  = 10,
		maxChickens		  = 125,
		queenName         = 'fedanarchid_epic',
		queenResistanceMult   = 3,
	},
	[difficulties.unbeatable] = {
		chickenSpawnRate  = 30,
		burrowSpawnRate   = 10,
		turretSpawnRate   = 20,
		queenSpawnMult    = 3,
		angerBonus        = 0.2,
		maxXP			  = 10,
		spawnChance       = 0.8,
		damageMod         = 1,
		maxBurrows        = 1000,
		minChickens		  = 10,
		maxChickens		  = 150,
		queenName         = 'fedanarchid_unbeatable',
		queenResistanceMult   = 3,
	},

	[difficulties.survival] = {
		chickenSpawnRate  = 30,
		burrowSpawnRate   = 75,
		turretSpawnRate   = 150,
		queenSpawnMult    = 1,
		angerBonus        = 0.2,
		maxXP			  = 0.5,
		spawnChance       = 0.2,
		damageMod         = 1,
		maxBurrows        = 1000,
		minChickens		  = 10,
		maxChickens		  = 25,
		queenName         = 'fedanarchid_unbeatable',
		queenResistanceMult   = 1,
	},
}

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local squadSpawnOptionsTable = {
	basic = {}, -- 67% spawn chance
	special = {}, -- 33% spawn chance, there's 1% chance of Special squad spawning Super squad, which is specials but 30% anger earlier.
	air = {}, -- Air waves
}

local function addNewSquad(squadParams) -- params: {type = "basic", minAnger = 0, maxAnger = 100, units = {"1 chicken1"}, weight = 1}
	if squadParams then -- Just in case
		if not squadParams.units then return end
		if not squadParams.minAnger then squadParams.minAnger = 0 end
		if not squadParams.maxAnger then squadParams.maxAnger = squadParams.minAnger + 50 end -- Eliminate squads 50% after they're introduced by default, can be overwritten
		if squadParams.maxAnger >= 100 then squadParams.maxAnger = 1000 end -- basically infinite
		if not squadParams.weight then squadParams.weight = 1 end

		for _ = 1,squadParams.weight do
			table.insert(squadSpawnOptionsTable[squadParams.type], {minAnger = squadParams.minAnger, maxAnger = squadParams.maxAnger, units = squadParams.units, weight = squadParams.weight})
		end
	end
end

-- addNewSquad({type = "basic", minAnger = 0, units = {"1 chicken1"}}) -- Minimum
-- addNewSquad({type = "basic", minAnger = 0, units = {"1 chicken1"}, weight = 1, maxAnger = 100}) -- Full


-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- MiniBoss Squads ----------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local miniBosses = { -- Units that spawn alongside queen
	"fedanarchid",
	"lozeurypterid",
}

local chickenMinions = { -- Units spawning other units
	["fedanarchid_normal"] = {
		"fedbear",
		"fedcobra",
		"lozreaper",
		"lozpulverizer",
	},
	["fedanarchid_hard"] = {
		"fedbear",
		"fedcobra",
		"lozreaper",
	},
	["fedanarchid_veryhard"] = {
		"fedbear",
		"fedcobra",
		"fedavalanche",
		"lozreaper",
		"fedgoliath",
		"lozmammoth",
	},
	["fedanarchid_insane"] = {
		"fedbear",
		"lozreaper",
		"fedgoliath",
		"lozmammoth",
		"fedjuggernaut",
		"lozsilverback",
	},
	["fedanarchid_epic"] = {
		"fedjuggernaut",
		"lozsilverback",
	},
	["fedanarchid_unbeatable"] = {
		"fedjuggernaut",
		"lozsilverback",
	},
}

local chickenHealers = { -- Spawn indepedently from squads in small numbers
	"lozengineer_ai",
	"fedengineer_ai",
},

------------------
-- Basic Squads --
------------------
------------------

addNewSquad({ type = "basic", minAnger = 0, units = { "5 fedak" } })
addNewSquad({ type = "basic", minAnger = 0, units = { "5 fedstorm" } })
addNewSquad({ type = "basic", minAnger = 0, units = { "5 fedcrasher" } })
addNewSquad({ type = "basic", minAnger = 0, units = { "5 lozdiamondback" } })
addNewSquad({ type = "basic", minAnger = 0, units = { "5 lozroach" } })
addNewSquad({ type = "basic", minAnger = 0, units = { "5 lozscorpion" } })

addNewSquad({ type = "basic", minAnger = 10, units = { "5 fedstorm" } })
addNewSquad({ type = "basic", minAnger = 10, units = { "5 fedthud" } })
addNewSquad({ type = "basic", minAnger = 10, units = { "5 fedcrasher" } })
addNewSquad({ type = "basic", minAnger = 10, units = { "5 fedbear", "3 fedphalanx" }, weight = 2 })
addNewSquad({ type = "basic", minAnger = 10, units = { "5 lozroach" } })
addNewSquad({ type = "basic", minAnger = 10, units = { "5 lozscorpion" } })
addNewSquad({ type = "basic", minAnger = 10, units = { "5 lozreaper", "3 lozpulverizer" }, weight = 2 })

addNewSquad({ type = "basic", minAnger = 30, units = { "5 fedstorm" } })
addNewSquad({ type = "basic", minAnger = 30, units = { "5 fedthud" } })
addNewSquad({ type = "basic", minAnger = 30, units = { "5 fedcrasher" } })
addNewSquad({ type = "basic", minAnger = 30, units = { "10 fedbear", "5 fedcobra", "5 fedphalanx" }, weight = 3 })
addNewSquad({ type = "basic", minAnger = 30, units = { "5 lozroach" } })
addNewSquad({ type = "basic", minAnger = 30, units = { "5 lozscorpion" } })
addNewSquad({ type = "basic", minAnger = 30, units = { "10 lozreaper", "5 lozpulverizer" }, weight = 3 })

addNewSquad({ type = "basic", minAnger = 50, units = { "10 fedbear", "5 fedcobra", "5 fedphalanx" } })
addNewSquad({ type = "basic", minAnger = 50, units = { "10 lozreaper", "5 lozpulverizer" } })
addNewSquad({ type = "basic", minAnger = 50, units = { "2 fedgoliath" }, weight = 2 })
addNewSquad({ type = "basic", minAnger = 50, units = { "2 lozmammoth" }, weight = 2 })

addNewSquad({ type = "basic", minAnger = 70, units = { "5 fedbear", "5 fedcobra", "5 fedphalanx" } })
addNewSquad({ type = "basic", minAnger = 70, units = { "10 lozreaper", "5 lozpulverizer" } })
addNewSquad({ type = "basic", minAnger = 70, units = { "2 fedgoliath" }, weight = 2 })
addNewSquad({ type = "basic", minAnger = 70, units = { "2 lozmammoth" }, weight = 2 })

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Special Squads -----------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

addNewSquad({ type = "special", minAnger = 0, units = { "15 fedak" } })
addNewSquad({ type = "special", minAnger = 0, units = { "15 lozdiamondback" } })
addNewSquad({ type = "special", minAnger = 0, units = { "10 fedstorm", "4 fedthud", "6 fedcrasher" } })
addNewSquad({ type = "special", minAnger = 0, units = { "10 lozroach", "8 lozscorpion" } })

addNewSquad({ type = "special", minAnger = 10, units = { "10 fedstorm", "4 fedthud", "6 fedcrasher" } })
addNewSquad({ type = "special", minAnger = 10, units = { "10 lozroach", "8 lozscorpion" } })
addNewSquad({ type = "special", minAnger = 10, units = { "1 fedbear", "1 fedcobra", "1 fedphalanx" }, weight = 2 })
addNewSquad({ type = "special", minAnger = 10, units = { "1 lozreaper", "1 lozpulverizer" }, weight = 2 })

addNewSquad({ type = "special", minAnger = 20, units = { "10 fedstorm", "4 fedthud", "6 fedcrasher" } })
addNewSquad({ type = "special", minAnger = 20, units = { "10 lozroach", "8 lozscorpion" } })
addNewSquad({ type = "special", minAnger = 20, units = { "3 fedbear", "1 fedcobra", "1 fedphalanx" }, weight = 2 })
addNewSquad({ type = "special", minAnger = 20, units = { "3 lozreaper", "1 lozpulverizer" }, weight = 2 })

addNewSquad({ type = "special", minAnger = 30, units = { "10 fedstorm", "4 fedthud", "6 fedcrasher" } })
addNewSquad({ type = "special", minAnger = 30, units = { "10 lozroach", "8 lozscorpion" } })
addNewSquad({ type = "special", minAnger = 30, units = { "5 fedbear", "5 fedcobra", "5 fedphalanx" }, weight = 4 })
addNewSquad({ type = "special", minAnger = 30, units = { "5 lozreaper", "5 lozpulverizer" }, weight = 4 })

addNewSquad({ type = "special", minAnger = 40, units = { "10 fedbear", "8 fedcobra", "5 fedphalanx" }, weight = 3 })
addNewSquad({ type = "special", minAnger = 40, units = { "10 lozreaper", "8 lozpulverizer" }, weight = 3 })

addNewSquad({ type = "special", minAnger = 50, units = { "10 fedavalanche" } })
addNewSquad({ type = "special", minAnger = 50, units = { "10 lozluger" } })
addNewSquad({ type = "special", minAnger = 50, units = { "1 lozmammoth" } })
addNewSquad({ type = "special", minAnger = 50, units = { "1 fedgoliath" } })

addNewSquad({ type = "special", minAnger = 60, units = { "10 fedbear", "8 fedcobra", "5 fedphalanx" } })
addNewSquad({ type = "special", minAnger = 60, units = { "10 lozreaper", "8 lozpulverizer" } })
addNewSquad({ type = "special", minAnger = 60, units = { "10 fedavalanche" } })
addNewSquad({ type = "special", minAnger = 60, units = { "10 lozluger" } })
addNewSquad({ type = "special", minAnger = 60, units = { "1 lozmammoth" }, weight = 2 })
addNewSquad({ type = "special", minAnger = 60, units = { "1 fedgoliath" }, weight = 2 })

addNewSquad({ type = "special", minAnger = 70, units = { "10 fedbear", "8 fedcobra", "5 fedphalanx" } })
addNewSquad({ type = "special", minAnger = 70, units = { "10 lozreaper", "8 lozpulverizer" } })
addNewSquad({ type = "special", minAnger = 70, units = { "10 fedavalanche" } })
addNewSquad({ type = "special", minAnger = 70, units = { "10 lozluger" } })
addNewSquad({ type = "special", minAnger = 70, units = { "1 lozmammoth" }, weight = 2 })
addNewSquad({ type = "special", minAnger = 70, units = { "1 fedgoliath" }, weight = 2 })

addNewSquad({ type = "special", minAnger = 80, units = { "1 lozmammoth" } })
addNewSquad({ type = "special", minAnger = 80, units = { "1 fedgoliath" } })

addNewSquad({ type = "special", minAnger = 90, units = { "1 lozsilverback" } })
addNewSquad({ type = "special", minAnger = 90, units = { "1 fedjuggernaut" } })

for j = 1,#miniBosses do
	addNewSquad({ type = "special", minAnger = 100, units = { "1 " .. miniBosses[j] }, weight = 3 })
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Air Squads ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local airStartAnger = 30 -- needed for air waves to work correctly.

addNewSquad({ type = "air", minAnger = 30, units = { "4 fedsparrow" } })
addNewSquad({ type = "air", minAnger = 30, units = { "4 lozwasp" } })
addNewSquad({ type = "air", minAnger = 30, units = { "4 fedhawk", "4 lozhornet" } })
addNewSquad({ type = "air", minAnger = 30, units = { "5 fedcrow" } })
addNewSquad({ type = "air", minAnger = 30, units = { "3 fedhawk", "5 lozbumblebee" } })
addNewSquad({ type = "air", minAnger = 30, units = { "2 fedcondor" } })
addNewSquad({ type = "air", minAnger = 30, units = { "2 lozcrane" } })

addNewSquad({ type = "air", minAnger = 40, units = { "3 fedhawk", "4 lozhornet" } })
addNewSquad({ type = "air", minAnger = 40, units = { "2 lozhornet", "5 fedcrow" } })
addNewSquad({ type = "air", minAnger = 40, units = { "3 fedhawk", "5 lozbumblebee" } })
addNewSquad({ type = "air", minAnger = 40, units = { "2 fedcondor", "5 lozcrane" } })

addNewSquad({ type = "air", minAnger = 50, units = { "3 fedhawk", "3 lozhornet" } })
addNewSquad({ type = "air", minAnger = 50, units = { "3 lozhornet", "5 fedcrow" } })
addNewSquad({ type = "air", minAnger = 50, units = { "3 fedhawk", "5 lozbumblebee" } })
addNewSquad({ type = "air", minAnger = 50, units = { "3 fedcondor", "3 lozcrane" } })
addNewSquad({ type = "air", minAnger = 50, units = { "1 fedeagle", "1 loztitan" } })

addNewSquad({ type = "air", minAnger = 60, units = { "6 fedhawk", "6 lozhornet" } })
addNewSquad({ type = "air", minAnger = 60, units = { "5 lozhornet", "10 fedcrow" } })
addNewSquad({ type = "air", minAnger = 60, units = { "5 fedhawk", "10 lozbumblebee" } })
addNewSquad({ type = "air", minAnger = 60, units = { "3 fedcondor", "3 lozcrane" } })

addNewSquad({ type = "air", minAnger = 70, units = { "6 fedhawk", "10 lozbumblebee", "6 lozhornet", "10 fedcrow" } })
addNewSquad({ type = "air", minAnger = 70, units = { "3 fedcondor", "3 lozcrane" } })

addNewSquad({ type = "air", minAnger = 80, units = { "6 fedhawk", "10 lozbumblebee", "5 lozhornet", "10 fedcrow" } })
addNewSquad({ type = "air", minAnger = 80, units = { "4 fedcondor", "4 lozcrane" } })
addNewSquad({ type = "air", minAnger = 80, units = { "1 fedeagle", "1 loztitan" } })

addNewSquad({ type = "air", minAnger = 90, units = { "6 fedhawk", "10 lozbumblebee", "5 lozhornet", "10 fedcrow" } })
addNewSquad({ type = "air", minAnger = 90, units = { "10 fedhawk", "10 lozhornet" } })
addNewSquad({ type = "air", minAnger = 90, units = { "2 fedeagle", "2 loztitan" } })

addNewSquad({ type = "air", minAnger = 100, units = { "6 fedeagle", "6 loztitan" } })
addNewSquad({ type = "air", minAnger = 100, units = { "9 fedcrow", "9 lozbumblebee" } })

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Settings -- Adjust these
local useEggs = false -- Drop eggs (requires egg features from Beyond All Reason)
local useScum = false -- Use scum as space where turrets can spawn (requires scum gadget from Beyond All Reason)
local useWaveMsg = true -- Show dropdown message whenever new wave is spawning
local spawnSquare = 90 -- size of the chicken spawn square centered on the burrow
local spawnSquareIncrement = 2 -- square size increase for each unit spawned
local minBaseDistance = 1000 -- Minimum distance of new burrows from players and other burrows
local burrowTurretSpawnRadius = 64

local config = { -- Don't touch this! ---------------------------------------------------------------------------------------------------------------------------------------------
	useEggs 				= useEggs,
	useScum					= useScum,
	difficulty             	= difficulty,
	difficulties           	= difficulties,
	chickenEggs			   	= table.copy(chickenEggs),
	chickenHealers			= table.copy(chickenHealers),
	burrowName             	= burrowName,   -- burrow unit name
	burrowDef              	= UnitDefNames[burrowName].id,
	chickenSpawnMultiplier 	= Spring.GetModOptions().chicken_spawncountmult,
	gracePeriod            	= Spring.GetModOptions().chicken_graceperiod * 60,  -- no chicken spawn in this period, frames
	queenTime              	= Spring.GetModOptions().chicken_queentime * 60, -- time at which the queen appears, frames
	addQueenAnger          	= Spring.GetModOptions().chicken_queenanger,
	burrowSpawnType        	= Spring.GetModOptions().chicken_chickenstart,
	swarmMode			   	= Spring.GetModOptions().chicken_swarmmode,
	spawnSquare            	= spawnSquare,       
	spawnSquareIncrement   	= spawnSquareIncrement,         
	minBaseDistance        	= minBaseDistance,
	chickenTurrets			= table.copy(chickenTurrets),
	miniBosses			   	= miniBosses,
	chickenMinions			= chickenMinions,
	chickenBehaviours 		= chickenBehaviours,
	difficultyParameters   	= optionValues,
	useWaveMsg 				= useWaveMsg,
	burrowTurretSpawnRadius = burrowTurretSpawnRadius,
	squadSpawnOptionsTable	= squadSpawnOptionsTable,
	airStartAnger			= airStartAnger,
}

for key, value in pairs(optionValues[difficulty]) do
	config[key] = value
end

return config