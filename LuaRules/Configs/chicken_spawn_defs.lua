
local difficulties = {
	veryeasy = 0,
	easy 	 = 1,
	normal   = 2,
	hard     = 3,
	veryhard = 4,
	epic     = 5,
	survival = 6,
}

local difficulty = difficulties[Spring.GetModOptions().chicken_difficulty]
local burrowName = 'healstation_ai'

chickenTurrets = {
	-- Weapons
	["fedearthquakemine"] 	 = { minQueenAnger = 0, spawnedPerWave = 10, spawnOnBurrows = false, maxQueenAnger = 1000 },
	["fedmenlo"]             = { minQueenAnger = 0, spawnedPerWave = 2, spawnOnBurrows = true, maxQueenAnger = 60 },
	["lozjericho"]           = { minQueenAnger = 0, spawnedPerWave = 2, spawnOnBurrows = true, maxQueenAnger = 60 },
	["fedstinger"]           = { minQueenAnger = 0, spawnedPerWave = 4, spawnOnBurrows = false, maxQueenAnger = 60 },
	["lozrazor"]             = { minQueenAnger = 0, spawnedPerWave = 4, spawnOnBurrows = false, maxQueenAnger = 60 },
	["fedimmolator"]         = { minQueenAnger = 20, spawnedPerWave = 2, spawnOnBurrows = true, maxQueenAnger = 1000 },
	["lozinferno"]           = { minQueenAnger = 20, spawnedPerWave = 2, spawnOnBurrows = true, maxQueenAnger = 1000 },
	["fedjavelin"]           = { minQueenAnger = 20, spawnedPerWave = 4, spawnOnBurrows = false, maxQueenAnger = 1000 },
	["lozrattlesnake"]       = { minQueenAnger = 20, spawnedPerWave = 4, spawnOnBurrows = false, maxQueenAnger = 1000 },
	["fedguardian"]          = { minQueenAnger = 50, spawnedPerWave = 1, spawnOnBurrows = false, maxQueenAnger = 1000 },
	["lozannihilator"]       = { minQueenAnger = 50, spawnedPerWave = 1, spawnOnBurrows = false, maxQueenAnger = 1000 },

	-- Utility
	["cloakingtower"]        = { minQueenAnger = 20, spawnedPerWave = 2, spawnOnBurrows = true, maxQueenAnger = 60 },
	["largecloakingtower"]   = { minQueenAnger = 50, spawnedPerWave = 2, spawnOnBurrows = false, maxQueenAnger = 1000 },
	["smallshieldgenerator"] = { minQueenAnger = 20, spawnedPerWave = 2, spawnOnBurrows = true, maxQueenAnger = 60 },
	["largeshieldgenerator"] = { minQueenAnger = 50, spawnedPerWave = 2, spawnOnBurrows = false, maxQueenAnger = 1000 },

	["healstation"] 		 = { minQueenAnger = 20, spawnedPerWave = 5, spawnOnBurrows = false, maxQueenAnger = 1000 },

	-- Eco Fillers
	-- Power
	["fissionpowerplant"]    = { minQueenAnger = 0, spawnedPerWave = 1, spawnOnBurrows = false, maxQueenAnger = 20 },
	["fusionpowerplant"]     = { minQueenAnger = 20, spawnedPerWave = 1, spawnOnBurrows = false, maxQueenAnger = 50 },
	["coldfusionpowerplant"] = { minQueenAnger = 50, spawnedPerWave = 1, spawnOnBurrows = false, maxQueenAnger = 80 },
	["blackholepowerplant"]  = { minQueenAnger = 80, spawnedPerWave = 1, spawnOnBurrows = false, maxQueenAnger = 1000 },
	-- Storage
	["supplydepot"]          = { minQueenAnger = 0, spawnedPerWave = 1, spawnOnBurrows = false, maxQueenAnger = 20 },
	["mediumsupplydepot"]    = { minQueenAnger = 20, spawnedPerWave = 1, spawnOnBurrows = false, maxQueenAnger = 1000 },
	["mediumstorage"]        = { minQueenAnger = 20, spawnedPerWave = 1, spawnOnBurrows = false, maxQueenAnger = 50 },
	["largestorage"]         = { minQueenAnger = 50, spawnedPerWave = 1, spawnOnBurrows = false, maxQueenAnger = 1000 },
}

local chickenEggs = { -- Specify eggs dropped by unit here, requires useEggs to be true, if some unit is not specified here, it drops random egg colors.

}

chickenBehaviours = {
	SKIRMISH = { -- Run away from target after target gets hit -- This is for fast light units
		-- T1
		[UnitDefNames["lozscorpion"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["fedcrasher"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["fedthud"].id] = { distance = 500, chance = 1 },
		-- T2
		[UnitDefNames["lozluger"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["lozpulverizer"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["fedcobra"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["fedavalanche"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["fedphalanx"].id] = { distance = 500, chance = 1 },
		-- T3
		[UnitDefNames["lozemperorscorpion"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["lozprotector"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["feddeleter"].id] = { distance = 500, chance = 1 },
		-- T4
		[UnitDefNames["lozeurypterid"].id] = { distance = 500, chance = 1 },
		
	},
	COWARD = { -- Run away from target after getting hit by enemy -- This is for fast light units
		-- T1
		[UnitDefNames["lozscorpion"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["fedcrasher"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["fedthud"].id] = { distance = 500, chance = 1 },
		-- T2
		[UnitDefNames["lozluger"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["lozpulverizer"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["fedcobra"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["fedavalanche"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["fedphalanx"].id] = { distance = 500, chance = 1 },
		-- T3
		[UnitDefNames["lozemperorscorpion"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["lozprotector"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["feddeleter"].id] = { distance = 500, chance = 1 },
		-- T4
		[UnitDefNames["lozeurypterid"].id] = { distance = 500, chance = 1 },

	},
	BERSERK = { -- Run towards target after getting hit by enemy or after hitting the target-- This is for heavy slow units
		-- T1
		[UnitDefNames["lozflea"].id] = { distance = 3000, chance = 0.01 },
		[UnitDefNames["lozdiamondback"].id] = { distance = 3000, chance = 0.01 },
		[UnitDefNames["lozroach"].id] = { distance = 3000, chance = 0.01 },
		[UnitDefNames["fedak"].id] = { distance = 3000, chance = 0.01 },
		[UnitDefNames["fedstorm"].id] = { distance = 3000, chance = 0.01 },
		-- T2
		[UnitDefNames["lozreaper"].id] = { distance = 3000, chance = 0.01 },
		[UnitDefNames["fedbear"].id] = { distance = 3000, chance = 0.01 },
		-- T3
		[UnitDefNames["lozmammoth"].id] = { distance = 3000, chance = 0.01 },
		[UnitDefNames["fedstriker"].id] = { distance = 3000, chance = 0.01 },
		[UnitDefNames["fedgoliath"].id] = { distance = 3000, chance = 0.01 },
		-- T4
		[UnitDefNames["lozsilverback"].id] = { distance = 3000, chance = 0.01 },
		[UnitDefNames["fedjuggernaut"].id] = { distance = 3000, chance = 0.01 },
		[UnitDefNames["fedanarchid"].id] = { distance = 3000, chance = 0.01 },
		-- Bosses
		[UnitDefNames["fedanarchid_normal"].id] = { distance = 3000, chance = 0.01 },
		[UnitDefNames["fedanarchid_hard"].id] = { distance = 3000, chance = 0.01 },
		[UnitDefNames["fedanarchid_veryhard"].id] = { distance = 3000, chance = 0.01 },
		[UnitDefNames["fedanarchid_insane"].id] = { distance = 3000, chance = 0.01 },
		[UnitDefNames["fedanarchid_epic"].id] = { distance = 3000, chance = 0.01 },
		[UnitDefNames["fedanarchid_unbeatable"].id] = { distance = 3000, chance = 0.01 },
	},
	HEALER = { -- Getting long max lifetime and always use Fight command. These units spawn as healers from burrows and queen
		[UnitDefNames["lozflea"].id] = true,
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

	[difficulties.veryeasy] = {
		gracePeriod       = 6 * Spring.GetModOptions().chicken_graceperiodmult * 60,
		queenTime      	  = 60 * Spring.GetModOptions().chicken_queentimemult * 60, -- time at which the queen appears, frames
		chickenSpawnRate  = 60, -- Time between Waves in seconds
		burrowSpawnRate   = 150, -- Time inbetween burrow spawns in seconds
		turretSpawnRate   = 360, -- Time inbetween turret spawns in seconds
		queenSpawnMult    = 1, -- Unused, don't touch (just in case)
		angerBonus        = 0.1, -- Multiplier for boss anger when you kill a burrow
		maxXP			  = 0.5, -- Random amount of XP given to spawned units
		spawnChance       = 0.2, -- What are the chances that a burrow will spawn units each wave (this check is performed on each burrow)
		damageMod         = 1, -- Multiplier for how much damage spawned units will deal to player units
		maxBurrows        = 1000, -- Maximum number of burrows that can be on the map
		chickenPerPlayerMultiplier = 1, -- This modifies the minimum and maximum number of chickens that will spawn for each player on the map
		minChickens		  = 10, -- Number of ai units spawned in the beginning stages of the game per wave
		maxChickens		  = 20, -- Number of ai units spawned in the end stages of the game per wave
		queenName         = 'chickensbeacon',
		queenResistanceMult   = 1.5, -- Multipler for how quickly the queen will gain resistances for each weapon
	},

	[difficulties.easy] = {
		gracePeriod       = 6 * Spring.GetModOptions().chicken_graceperiodmult * 60,
		queenTime      	  = 60 * Spring.GetModOptions().chicken_queentimemult * 60, -- time at which the queen appears, frames
		chickenSpawnRate  = 60,
		burrowSpawnRate   = 120,
		turretSpawnRate   = 300,
		queenSpawnMult    = 1,
		angerBonus        = 0.1,
		maxXP			  = 1,
		spawnChance       = 0.3,
		damageMod         = 1,
		maxBurrows        = 1000,
		chickenPerPlayerMultiplier = 1, -- This modifies the minimum and maximum number of chickens that will spawn for each player on the map
		minChickens		  = 10,
		maxChickens		  = 25,
		queenName         = 'chickensbeacon',
		queenResistanceMult   = 1.75,
	},
	[difficulties.normal] = {
		gracePeriod       = 6 * Spring.GetModOptions().chicken_graceperiodmult * 60,
		queenTime      	  = 60 * Spring.GetModOptions().chicken_queentimemult * 60, -- time at which the queen appears, frames
		chickenSpawnRate  = 60,
		burrowSpawnRate   = 90,
		turretSpawnRate   = 240,
		queenSpawnMult    = 3,
		angerBonus        = 0.1,
		maxXP			  = 1.5,
		spawnChance       = 0.4,
		damageMod         = 1,
		maxBurrows        = 1000,
		chickenPerPlayerMultiplier = 1, -- This modifies the minimum and maximum number of chickens that will spawn for each player on the map
		minChickens		  = 10,
		maxChickens		  = 30,
		queenName         = 'chickensbeacon',
		queenResistanceMult   = 2,
	},
	[difficulties.hard] = {
		gracePeriod       = 6 * Spring.GetModOptions().chicken_graceperiodmult * 60,
		queenTime      	  = 60 * Spring.GetModOptions().chicken_queentimemult * 60, -- time at which the queen appears, frames
		chickenSpawnRate  = 60,
		burrowSpawnRate   = 60,
		turretSpawnRate   = 180,
		queenSpawnMult    = 3,
		angerBonus        = 0.1,
		maxXP			  = 2,
		spawnChance       = 0.5,
		damageMod         = 1,
		maxBurrows        = 1000,
		chickenPerPlayerMultiplier = 1, -- This modifies the minimum and maximum number of chickens that will spawn for each player on the map
		minChickens		  = 10,
		maxChickens		  = 35,
		queenName         = 'chickensbeacon',
		queenResistanceMult   = 2.5,
	},
	[difficulties.veryhard] = {
		gracePeriod       = 6 * Spring.GetModOptions().chicken_graceperiodmult * 60,
		queenTime      	  = 60 * Spring.GetModOptions().chicken_queentimemult * 60, -- time at which the queen appears, frames
		chickenSpawnRate  = 60,
		burrowSpawnRate   = 40,
		turretSpawnRate   = 120,
		queenSpawnMult    = 3,
		angerBonus        = 0.1,
		maxXP			  = 5,
		spawnChance       = 0.6,
		damageMod         = 1,
		maxBurrows        = 1000,
		chickenPerPlayerMultiplier = 1, -- This modifies the minimum and maximum number of chickens that will spawn for each player on the map
		minChickens		  = 10,
		maxChickens		  = 40,
		queenName         = 'chickensbeacon',
		queenResistanceMult   = 3,
	},
	[difficulties.epic] = {
		gracePeriod       = 6 * Spring.GetModOptions().chicken_graceperiodmult * 60,
		queenTime      	  = 60 * Spring.GetModOptions().chicken_queentimemult * 60, -- time at which the queen appears, frames
		chickenSpawnRate  = 60,
		burrowSpawnRate   = 40,
		turretSpawnRate   = 120,
		queenSpawnMult    = 3,
		angerBonus        = 0.1,
		maxXP			  = 5,
		spawnChance       = 0.6,
		damageMod         = 1,
		maxBurrows        = 1000,
		chickenPerPlayerMultiplier = 1, -- This modifies the minimum and maximum number of chickens that will spawn for each player on the map
		minChickens		  = 10,
		maxChickens		  = 50,
		queenName         = 'chickensbeacon',
		queenResistanceMult   = 3,
	},

	[difficulties.survival] = {
		gracePeriod       = 6 * Spring.GetModOptions().chicken_graceperiodmult * 60,
		queenTime      	  = 60 * Spring.GetModOptions().chicken_queentimemult * 60, -- time at which the queen appears, frames
		chickenSpawnRate  = 60, -- Time between Waves in seconds
		burrowSpawnRate   = 150, -- Time inbetween burrow spawns in seconds
		turretSpawnRate   = 360, -- Time inbetween turret spawns in seconds
		queenSpawnMult    = 1, -- Unused, don't touch (just in case)
		angerBonus        = 0.1, -- Multiplier for boss anger when you kill a burrow
		maxXP			  = 0.5, -- Random amount of XP given to spawned units
		spawnChance       = 0.2, -- What are the chances that a burrow will spawn units each wave (this check is performed on each burrow)
		damageMod         = 1, -- Multiplier for how much damage spawned units will deal to player units
		maxBurrows        = 1000, -- Maximum number of burrows that can be on the map
		chickenPerPlayerMultiplier = 1, -- This modifies the minimum and maximum number of chickens that will spawn for each player on the map
		minChickens		  = 10, -- Number of ai units spawned in the beginning stages of the game per wave
		maxChickens		  = 20, -- Number of ai units spawned in the end stages of the game per wave
		queenName         = 'chickensbeacon',
		queenResistanceMult   = 1.5, -- Multipler for how quickly the queen will gain resistances for each weapon
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
		if not squadParams.maxAnger then squadParams.maxAnger = squadParams.minAnger + 100 end -- Eliminate squads 50% after they're introduced by default, can be overwritten
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
local chickenSquadUnitTable = {
	t1assault = {
		"lozdiamondback",
		"lozroach",
		"fedak",
		"fedstorm",
	},
	t1support = {
		"lozscorpion",
		"fedcrasher",
		"fedthud",
	},

	t2assault = {
		"lozreaper",
		"fedbear",
	},
	t2support = {
		"lozluger",
		"lozpulverizer",
		"fedcobra",
		"fedavalanche",
		"fedphalanx",
	},

	t3assault = {
		"lozmammoth",
		"fedstriker",
		"fedgoliath",
	},
	t3support = {
		"lozemperorscorpion",
		"lozprotector",
		"feddeleter",
		--some T2 for balance
		"lozluger",
		"lozpulverizer",
		"fedcobra",
		"fedavalanche",
		"fedphalanx",
	},

	t4assault = {
		"lozsilverback",
		"fedjuggernaut",
		"fedanarchid",
	},
	t4support = {
		"lozeurypterid",
		--some T3 for balance
		"lozprotector",
		"feddeleter",
		--some T2 for balance
		"lozluger",
		"lozpulverizer",
		"fedcobra",
		"fedavalanche",
		"fedphalanx",
	},

	t1air = {
		"lozwasp",
		"lozbumblebee",
		"fedsparrow",
		"fedcrow",
	},
	t2air = {
		"lozhornet",
		"lozcrane",
		"fedhawk",
		"fedcondor",
	},
	t3air = {
		"lozlocust",
		"loztitan",
		"fedfalcon",
		"fedeagle",
	},
	t4air = { -- no T4 air in the game :shrug:
		"lozlocust",
		"loztitan",
		"fedfalcon",
		"fedeagle",
	},
}

local miniBosses = { -- Units that spawn alongside queen
	"lozemperorscorpion",
	"lozmammoth",
	"lozsilverback",
	"fedstriker",
	"fedgoliath",
	"fedjuggernaut",
	-- chicken special
	"fedanarchid",
	"lozeurypterid",
}

local chickenMinions = { -- Units spawning other units
	["chickensbeacon"] = {
		-- T1
		"lozdiamondback",
		"lozroach",
		"fedak",
		"fedstorm",
		"lozscorpion",
		"fedcrasher",
		"fedthud",
		-- T2
		"lozreaper",
		"fedbear",
		"lozluger",
		"lozpulverizer",
		"fedcobra",
		"fedavalanche",
		"fedphalanx",
	}
}

local chickenHealers = { -- Spawn indepedently from squads in small numbers
	"lozflea",
}

------------------
-- Basic Squads --
------------------
------------------

for anger = 0,100 do
	local cst = chickenSquadUnitTable
	if anger%5 == 0 then -- only add squads every 5 anger
		if anger < 20 then
			for i = 1,10 do
				addNewSquad({ type = "basic", minAnger = anger, units = { "3 " .. cst.t1assault[math.random(1,#cst.t1assault)] } })
			end
		elseif anger < 50 then
			for i = 1,10 do
				addNewSquad({ type = "basic", minAnger = anger, units = { "5 " .. cst.t1assault[math.random(1,#cst.t1assault)] } })
				addNewSquad({ type = "basic", minAnger = anger, units = { "5 " .. cst.t1support[math.random(1,#cst.t1support)] } })
			end
		elseif anger < 80 then
			for i = 1,10 do
				addNewSquad({ type = "basic", minAnger = anger, units = { "10 " .. cst.t1assault[math.random(1,#cst.t1assault)] } })
				addNewSquad({ type = "basic", minAnger = anger, units = { "10 " .. cst.t1support[math.random(1,#cst.t1support)] } })

				addNewSquad({ type = "basic", minAnger = anger, units = { "2 " .. cst.t2assault[math.random(1,#cst.t2assault)] } })
				addNewSquad({ type = "basic", minAnger = anger, units = { "2 " .. cst.t2support[math.random(1,#cst.t2support)] } })
			end
		else
			for i = 1,10 do

				addNewSquad({ type = "basic", minAnger = anger, units = { "4 " .. cst.t2assault[math.random(1,#cst.t2assault)] } })
				addNewSquad({ type = "basic", minAnger = anger, units = { "4 " .. cst.t2support[math.random(1,#cst.t2support)] } })

				addNewSquad({ type = "basic", minAnger = anger, units = { "1 " .. cst.t3assault[math.random(1,#cst.t3assault)] } })
				addNewSquad({ type = "basic", minAnger = anger, units = { "1 " .. cst.t3support[math.random(1,#cst.t3support)] } })
			end
		end
	end
end

--------------------
-- Special Squads --
--------------------
--------------------

for anger = 0,100 do
	local cst = chickenSquadUnitTable
	if anger%5 == 0 then -- only add squads every 5 anger
		if anger < 10 then
			for i = 1,10 do
				addNewSquad({ type = "special", minAnger = anger, units = { "5 " .. cst.t1assault[math.random(1,#cst.t1assault)] } })
			end
		elseif anger < 20 then
			for i = 1,10 do
				addNewSquad({ type = "special", minAnger = anger, units = { "10 " .. cst.t1assault[math.random(1,#cst.t1assault)] } })
				addNewSquad({ type = "special", minAnger = anger, units = { "5 " .. cst.t1assault[math.random(1,#cst.t1assault)], "5 " .. cst.t1assault[math.random(1,#cst.t1assault)] } })
				addNewSquad({ type = "special", minAnger = anger, units = { "5 "  .. cst.t1assault[math.random(1,#cst.t1assault)], "5 " .. cst.t1support[math.random(1,#cst.t1support)] } })
			end
		elseif anger < 50 then
			for i = 1,10 do
				addNewSquad({ type = "special", minAnger = anger, units = { "20 " .. cst.t1assault[math.random(1,#cst.t1assault)] } })
				addNewSquad({ type = "special", minAnger = anger, units = { "10 "  .. cst.t1assault[math.random(1,#cst.t1assault)], "10 " .. cst.t1support[math.random(1,#cst.t1assault)] } })
				addNewSquad({ type = "special", minAnger = anger, units = { "10 "  .. cst.t1assault[math.random(1,#cst.t1assault)], "10 " .. cst.t1support[math.random(1,#cst.t1support)] } })

				addNewSquad({ type = "special", minAnger = anger, units = { "4 " .. cst.t2assault[math.random(1,#cst.t2assault)] } })
				addNewSquad({ type = "special", minAnger = anger, units = { "2 "  .. cst.t2assault[math.random(1,#cst.t2assault)], "2 " .. cst.t2assault[math.random(1,#cst.t2assault)] } })
				addNewSquad({ type = "special", minAnger = anger, units = { "2 "  .. cst.t2assault[math.random(1,#cst.t2assault)], "2 " .. cst.t2support[math.random(1,#cst.t2support)] } })
			end
		elseif anger < 80 then
			for i = 1,10 do
				addNewSquad({ type = "special", minAnger = anger, units = { "8 " .. cst.t2assault[math.random(1,#cst.t2assault)] } })
				addNewSquad({ type = "special", minAnger = anger, units = { "4 "  .. cst.t2assault[math.random(1,#cst.t2assault)], "4 " .. cst.t2support[math.random(1,#cst.t2assault)] } })
				addNewSquad({ type = "special", minAnger = anger, units = { "4 "  .. cst.t2assault[math.random(1,#cst.t2assault)], "4 " .. cst.t2support[math.random(1,#cst.t2support)] } })

				addNewSquad({ type = "special", minAnger = anger, units = { "2 " .. cst.t3assault[math.random(1,#cst.t3assault)] } })
				addNewSquad({ type = "special", minAnger = anger, units = { "1 "  .. cst.t3assault[math.random(1,#cst.t3assault)], "1 " .. cst.t3support[math.random(1,#cst.t3assault)] } })
				addNewSquad({ type = "special", minAnger = anger, units = { "1 "  .. cst.t3assault[math.random(1,#cst.t3assault)], "1 " .. cst.t3support[math.random(1,#cst.t3support)] } })
			end
		else
			for i = 1,10 do
				addNewSquad({ type = "special", minAnger = anger, units = { "4 " .. cst.t3assault[math.random(1,#cst.t3assault)] } })
				addNewSquad({ type = "special", minAnger = anger, units = { "2 "  .. cst.t3assault[math.random(1,#cst.t3assault)], "2 " .. cst.t3support[math.random(1,#cst.t3assault)] } })
				addNewSquad({ type = "special", minAnger = anger, units = { "2 "  .. cst.t3assault[math.random(1,#cst.t3assault)], "2 " .. cst.t3support[math.random(1,#cst.t3support)] } })

				addNewSquad({ type = "special", minAnger = anger, units = { "1 " .. cst.t4assault[math.random(1,#cst.t4assault)] } })
				addNewSquad({ type = "special", minAnger = anger, units = { "1 "  .. cst.t4assault[math.random(1,#cst.t4assault)], "1 " .. cst.t4support[math.random(1,#cst.t4assault)] } })
				addNewSquad({ type = "special", minAnger = anger, units = { "1 "  .. cst.t4assault[math.random(1,#cst.t4assault)], "1 " .. cst.t4support[math.random(1,#cst.t4support)] } })
			end
		end
	end
end
for j = 1,#miniBosses do
	addNewSquad({ type = "special", minAnger = 100, units = { "1 " .. miniBosses[j], "1 lozprotector" } })
	addNewSquad({ type = "special", minAnger = 100, units = { "1 " .. miniBosses[j], "1 feddeleter" } })
end

----------------
-- Air Squads --
----------------
----------------

local airStartAnger = 15 -- needed for air waves to work correctly.

for anger = 0,100 do
	local cst = chickenSquadUnitTable
	if anger%5 == 0 then -- only add squads every 5 anger
		if anger < 20 then
			for i = 1,10 do
				addNewSquad({ type = "air", minAnger = anger, units = { "3 " .. cst.t1air[math.random(1,#cst.t1air)] } })
			end
		elseif anger < 50 then
			for i = 1,10 do
				addNewSquad({ type = "air", minAnger = anger, units = { "6 " .. cst.t1air[math.random(1,#cst.t1air)] } })

				addNewSquad({ type = "air", minAnger = anger, units = { "3 " .. cst.t2air[math.random(1,#cst.t2air)] } })
			end
		elseif anger < 80 then
			for i = 1,10 do
				addNewSquad({ type = "air", minAnger = anger, units = { "6 " .. cst.t2air[math.random(1,#cst.t2air)] } })

				addNewSquad({ type = "air", minAnger = anger, units = { "3 " .. cst.t3air[math.random(1,#cst.t3air)] } })
			end
		else
			for i = 1,10 do
				addNewSquad({ type = "air", minAnger = anger, units = { "6 " .. cst.t3air[math.random(1,#cst.t3air)] } })

				addNewSquad({ type = "air", minAnger = anger, units = { "3 " .. cst.t4air[math.random(1,#cst.t4air)] } })
			end
		end
	end
end


--[[
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
addNewSquad({ type = "basic", minAnger = 10, units = { "5 lozroach" } })
addNewSquad({ type = "basic", minAnger = 10, units = { "5 lozscorpion" } })

addNewSquad({ type = "basic", minAnger = 30, units = { "5 fedstorm" } })
addNewSquad({ type = "basic", minAnger = 30, units = { "5 fedthud" } })
addNewSquad({ type = "basic", minAnger = 30, units = { "5 fedcrasher" } })
addNewSquad({ type = "basic", minAnger = 30, units = { "5 lozroach" } })
addNewSquad({ type = "basic", minAnger = 30, units = { "5 lozscorpion" } })

addNewSquad({ type = "basic", minAnger = 60, units = { "1 fedbear", "1 fedcobra", "1 fedphalanx" } })
addNewSquad({ type = "basic", minAnger = 60, units = { "2 lozreaper", "1 lozpulverizer" } })

addNewSquad({ type = "basic", minAnger = 75, units = { "2 fedbear", "2 fedcobra", "2 fedphalanx" } })
addNewSquad({ type = "basic", minAnger = 75, units = { "2 lozreaper", "2 lozpulverizer" } })

addNewSquad({ type = "basic", minAnger = 90, units = { "1 fedstriker"} })
addNewSquad({ type = "basic", minAnger = 90, units = { "1 lozemperorscorpion"} })
addNewSquad({ type = "basic", minAnger = 90, units = { "1 feddeleter"} })
addNewSquad({ type = "basic", minAnger = 90, units = { "1 lozprotector"} })
addNewSquad({ type = "basic", minAnger = 90, units = { "1 fedgoliath" } })
addNewSquad({ type = "basic", minAnger = 90, units = { "1 lozmammoth" } })


-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Special Squads -----------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

addNewSquad({ type = "special", minAnger = 0, units = { "15 fedak" } })
addNewSquad({ type = "special", minAnger = 0, units = { "15 lozdiamondback" } })
addNewSquad({ type = "special", minAnger = 0, units = { "10 fedstorm", "4 fedthud", "6 fedcrasher" } })
addNewSquad({ type = "special", minAnger = 0, units = { "10 lozroach", "8 lozscorpion" } })

addNewSquad({ type = "special", minAnger = 10, units = { "10 fedstorm", "4 fedthud", "6 fedcrasher" } })
addNewSquad({ type = "special", minAnger = 10, units = { "10 lozroach", "8 lozscorpion" } })

addNewSquad({ type = "special", minAnger = 20, units = { "10 fedstorm", "4 fedthud", "6 fedcrasher" } })
addNewSquad({ type = "special", minAnger = 20, units = { "10 lozroach", "8 lozscorpion" } })

addNewSquad({ type = "special", minAnger = 30, units = { "10 fedstorm", "4 fedthud", "6 fedcrasher" } })
addNewSquad({ type = "special", minAnger = 30, units = { "10 lozroach", "8 lozscorpion" } })

addNewSquad({ type = "special", minAnger = 40, units = { "1 fedbear", "1 fedcobra", "1 fedphalanx" }})
addNewSquad({ type = "special", minAnger = 40, units = { "1 lozreaper", "1 lozpulverizer" }})

addNewSquad({ type = "special", minAnger = 50, units = { "3 fedavalanche" } })
addNewSquad({ type = "special", minAnger = 50, units = { "3 lozluger" } })

addNewSquad({ type = "special", minAnger = 60, units = { "1 fedbear"} })
addNewSquad({ type = "special", minAnger = 60, units = { "1 lozreaper"} })
addNewSquad({ type = "special", minAnger = 60, units = { "5 fedavalanche" } })
addNewSquad({ type = "special", minAnger = 60, units = { "5 lozluger" } })

addNewSquad({ type = "special", minAnger = 70, units = { "1 fedbear"} })
addNewSquad({ type = "special", minAnger = 70, units = { "1 lozreaper"} })

addNewSquad({ type = "special", minAnger = 80, units = { "1 fedstriker"} })
addNewSquad({ type = "special", minAnger = 80, units = { "1 lozemperorscorpion"} })
addNewSquad({ type = "special", minAnger = 80, units = { "1 feddeleter"} })
addNewSquad({ type = "special", minAnger = 80, units = { "1 lozprotector"} })

addNewSquad({ type = "special", minAnger = 90, units = { "1 lozmammoth" } })
addNewSquad({ type = "special", minAnger = 90, units = { "1 fedgoliath" } })

addNewSquad({ type = "special", minAnger = 100, units = { "1 lozsilverback" } })
addNewSquad({ type = "special", minAnger = 100, units = { "1 fedjuggernaut" } })

for j = 1,#miniBosses do
	addNewSquad({ type = "special", minAnger = 100, units = { "1 " .. miniBosses[j], "1 lozprotector" } })
	addNewSquad({ type = "special", minAnger = 100, units = { "1 " .. miniBosses[j], "1 feddeleter" } })
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
addNewSquad({ type = "air", minAnger = 70, units = { "1 fedfalcon", "1 lozlocust" } })

addNewSquad({ type = "air", minAnger = 80, units = { "6 fedhawk", "10 lozbumblebee", "5 lozhornet", "10 fedcrow" } })
addNewSquad({ type = "air", minAnger = 80, units = { "4 fedcondor", "4 lozcrane" } })
addNewSquad({ type = "air", minAnger = 80, units = { "1 fedeagle", "1 loztitan" } })
addNewSquad({ type = "air", minAnger = 80, units = { "1 fedfalcon", "1 lozlocust" } })

addNewSquad({ type = "air", minAnger = 90, units = { "6 fedhawk", "10 lozbumblebee", "5 lozhornet", "10 fedcrow" } })
addNewSquad({ type = "air", minAnger = 90, units = { "10 fedhawk", "10 lozhornet" } })
addNewSquad({ type = "air", minAnger = 90, units = { "2 fedeagle", "2 loztitan" } })
addNewSquad({ type = "air", minAnger = 90, units = { "2 fedfalcon", "2 lozlocust" } })

addNewSquad({ type = "air", minAnger = 100, units = { "6 fedeagle", "6 loztitan" } })
addNewSquad({ type = "air", minAnger = 100, units = { "9 fedcrow", "9 lozbumblebee" } })
addNewSquad({ type = "air", minAnger = 100, units = { "3 fedfalcon", "3 lozlocust" } })

]]
local ecoBuildingsPenalty = { -- Additional queen hatch per second from eco buildup (for 60 minutes queen time. scales to queen time)
	--[[
	-- T1 Energy
	[UnitDefNames["armsolar"].id] 	= 0.0000001,
	[UnitDefNames["corsolar"].id] 	= 0.0000001,
	[UnitDefNames["armwin"].id] 	= 0.0000001,
	[UnitDefNames["corwin"].id] 	= 0.0000001,
	[UnitDefNames["armtide"].id] 	= 0.0000001,
	[UnitDefNames["cortide"].id] 	= 0.0000001,
	[UnitDefNames["armadvsol"].id] 	= 0.000005,
	[UnitDefNames["coradvsol"].id] 	= 0.000005,

	-- T2 Energy
	[UnitDefNames["armwint2"].id] 	= 0.000075,
	[UnitDefNames["corwint2"].id] 	= 0.000075,
	[UnitDefNames["armfus"].id] 	= 0.000125,
	[UnitDefNames["armckfus"].id] 	= 0.000125,
	[UnitDefNames["corfus"].id] 	= 0.000125,
	[UnitDefNames["armuwfus"].id] 	= 0.000125,
	[UnitDefNames["coruwfus"].id] 	= 0.000125,
	[UnitDefNames["armafus"].id] 	= 0.0005,
	[UnitDefNames["corafus"].id] 	= 0.0005,

	-- T1 Metal Makers
	[UnitDefNames["armmakr"].id] 	= 0.00005,
	[UnitDefNames["cormakr"].id] 	= 0.00005,
	[UnitDefNames["armfmkr"].id] 	= 0.00005,
	[UnitDefNames["corfmkr"].id] 	= 0.00005,
	
	-- T2 Metal Makers
	[UnitDefNames["armmmkr"].id] 	= 0.0005,
	[UnitDefNames["cormmkr"].id] 	= 0.0005,
	[UnitDefNames["armuwmmm"].id] 	= 0.0005,
	[UnitDefNames["coruwmmm"].id] 	= 0.0005,
	]]--
}

local highValueTargets = { -- Priority targets for Chickens. Must be immobile to prevent issues.
	--[[
	-- T2 Energy
	[UnitDefNames["armwint2"].id] 	= true,
	[UnitDefNames["corwint2"].id] 	= true,
	[UnitDefNames["armfus"].id] 	= true,
	[UnitDefNames["armckfus"].id] 	= true,
	[UnitDefNames["corfus"].id] 	= true,
	[UnitDefNames["armuwfus"].id] 	= true,
	[UnitDefNames["coruwfus"].id] 	= true,
	[UnitDefNames["armafus"].id] 	= true,
	[UnitDefNames["corafus"].id] 	= true,
	-- T2 Metal Makers
	[UnitDefNames["armmmkr"].id] 	= true,
	[UnitDefNames["cormmkr"].id] 	= true,
	[UnitDefNames["armuwmmm"].id] 	= true,
	[UnitDefNames["coruwmmm"].id] 	= true,

	[UnitDefNames["cormoho"].id] 	= true,
	[UnitDefNames["armmoho"].id] 	= true,
	]]
}

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Settings -- Adjust these
local useEggs = false -- Drop eggs (requires egg features from Beyond All Reason)
local useScum = false -- Use scum as space where turrets can spawn (requires scum gadget from Beyond All Reason)
local useWaveMsg = true -- Show dropdown message whenever new wave is spawning
local spawnSquare = 90 -- size of the chicken spawn square centered on the burrow
local spawnSquareIncrement = 2 -- square size increase for each unit spawned
local minBaseDistance = 1000 -- Minimum distance of new burrows from players and other burrows
local burrowTurretSpawnRadius = 48

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
	ecoBuildingsPenalty		= ecoBuildingsPenalty,
	highValueTargets		= highValueTargets,
}

for key, value in pairs(optionValues[difficulty]) do
	config[key] = value
end

return config