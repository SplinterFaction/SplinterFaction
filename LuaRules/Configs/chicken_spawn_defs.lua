
local difficulties = {
	veryeasy = 1,
	easy 	 = 2,
	normal   = 3,
	hard     = 4,
	veryhard = 5,
	epic     = 6,
	--survival = 6,
}

local difficulty = difficulties[Spring.GetModOptions().chicken_difficulty]
local burrowName = 'chickensbeacon'

chickenTurrets = {

	-- Weapons
	["fedearthquakemine"] 	 = { minQueenAnger = 0, spawnedPerWave = 10, spawnOnBurrows = false, maxQueenAnger = 1000 },
	["fedmenlo"]             = { minQueenAnger = 0, spawnedPerWave = 2, spawnOnBurrows = true, maxQueenAnger = 70 },
	["lozjericho"]           = { minQueenAnger = 0, spawnedPerWave = 2, spawnOnBurrows = true, maxQueenAnger = 70 },
	["fedstinger"]           = { minQueenAnger = 0, spawnedPerWave = 2, spawnOnBurrows = true, maxQueenAnger = 70 },
	["lozrazor"]             = { minQueenAnger = 0, spawnedPerWave = 2, spawnOnBurrows = true, maxQueenAnger = 70 },
	["fedimmolator"]         = { minQueenAnger = 30, spawnedPerWave = 2, spawnOnBurrows = true, maxQueenAnger = 1000 },
	["lozinferno"]           = { minQueenAnger = 30, spawnedPerWave = 2, spawnOnBurrows = true, maxQueenAnger = 1000 },
	["fedjavelin"]           = { minQueenAnger = 30, spawnedPerWave = 2, spawnOnBurrows = true, maxQueenAnger = 1000 },
	["lozrattlesnake"]       = { minQueenAnger = 30, spawnedPerWave = 2, spawnOnBurrows = true, maxQueenAnger = 1000 },
	["fedmenlomk2"]          = { minQueenAnger = 30, spawnedPerWave = 1, spawnOnBurrows = false, maxQueenAnger = 1000 },
	["fedguardian"]          = { minQueenAnger = 60, spawnedPerWave = 1, spawnOnBurrows = false, maxQueenAnger = 1000 },
	["lozannihilator"]       = { minQueenAnger = 60, spawnedPerWave = 1, spawnOnBurrows = false, maxQueenAnger = 1000 },
	["chickenemperormenlo"]  = { minQueenAnger = 90, spawnedPerWave = 1, spawnOnBurrows = false, maxQueenAnger = 1000 },

	-- Utility
	["cloakingtower"]        = { minQueenAnger = 60, spawnedPerWave = 1, spawnOnBurrows = false, maxQueenAnger = 99 },
	["largecloakingtower"]   = { minQueenAnger = 90, spawnedPerWave = 1, spawnOnBurrows = false, maxQueenAnger = 1000 },
	["smallshieldgenerator"] = { minQueenAnger = 30, spawnedPerWave = 2, spawnOnBurrows = true, maxQueenAnger = 1000 },
	["largeshieldgenerator"] = { minQueenAnger = 60, spawnedPerWave = 2, spawnOnBurrows = true, maxQueenAnger = 1000 },

	["healstation"] 		 = { minQueenAnger = 30, spawnedPerWave = 5, spawnOnBurrows = true, maxQueenAnger = 1000 },

	-- Eco Fillers
	-- Power
	["fissionpowerplant"]    = { minQueenAnger = 0, spawnedPerWave = 1, spawnOnBurrows = false, maxQueenAnger = 40 },
	["fusionpowerplant"]     = { minQueenAnger = 30, spawnedPerWave = 1, spawnOnBurrows = false, maxQueenAnger = 70 },
	["coldfusionpowerplant"] = { minQueenAnger = 60, spawnedPerWave = 1, spawnOnBurrows = false, maxQueenAnger = 99 },
	["blackholepowerplant"]  = { minQueenAnger = 90, spawnedPerWave = 1, spawnOnBurrows = false, maxQueenAnger = 1000 },
	-- Storage
	["supplydepot"]          = { minQueenAnger = 0, spawnedPerWave = 1, spawnOnBurrows = false, maxQueenAnger = 40 },
	["mediumstorage"]        = { minQueenAnger = 30, spawnedPerWave = 1, spawnOnBurrows = false, maxQueenAnger = 70 },
	["largestorage"]         = { minQueenAnger = 60, spawnedPerWave = 1, spawnOnBurrows = false, maxQueenAnger = 1000 },
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
		[UnitDefNames["chickeneurypterid"].id] = { distance = 500, chance = 1 },

		-- BOSS
		[UnitDefNames["chickenboss_veryeasy"].id] = { distance = 500, chance = 0.001 },
		[UnitDefNames["chickenboss_easy"].id] = { distance = 500, chance = 0.001 },
		[UnitDefNames["chickenboss_normal"].id] = { distance = 500, chance = 0.001 },
		[UnitDefNames["chickenboss_hard"].id] = { distance = 500, chance = 0.001 },
		[UnitDefNames["chickenboss_veryhard"].id] = { distance = 500, chance = 0.001 },
		[UnitDefNames["chickenboss_epic"].id] = { distance = 500, chance = 0.001 },
		
	},
	COWARD = { -- Run away from target after getting hit by enemy -- This is for fast light units
		-- T1
		[UnitDefNames["lozscorpion"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["fedcrasher"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["fedthud"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickenhealer_mk1"].id] = { distance = 500, chance = 1 },
		-- T2
		[UnitDefNames["lozluger"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["lozpulverizer"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["fedcobra"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["fedavalanche"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["fedphalanx"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickenhealer_mk2"].id] = { distance = 500, chance = 1 },
		-- T3
		[UnitDefNames["lozemperorscorpion"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["lozprotector"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["feddeleter"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickendroplet"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickenhealer_mk3"].id] = { distance = 500, chance = 1 },
		-- T4
		[UnitDefNames["chickeneurypterid"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickenhealer_mk4"].id] = { distance = 500, chance = 1 },

		[UnitDefNames["chickenboss_veryeasy"].id] = { distance = 500, chance = 0.001 },
		[UnitDefNames["chickenboss_easy"].id] = { distance = 500, chance = 0.001 },
		[UnitDefNames["chickenboss_normal"].id] = { distance = 500, chance = 0.001 },
		[UnitDefNames["chickenboss_hard"].id] = { distance = 500, chance = 0.001 },
		[UnitDefNames["chickenboss_veryhard"].id] = { distance = 500, chance = 0.001 },
		[UnitDefNames["chickenboss_epic"].id] = { distance = 500, chance = 0.001 },



	},
	BERSERK = { -- Run towards target after getting hit by enemy or after hitting the target-- This is for heavy slow units
		-- T1
		[UnitDefNames["lozflea"].id] = { distance = 3000, chance = 0.01 },
		[UnitDefNames["lozdiamondback"].id] = { distance = 3000, chance = 0.01 },
		[UnitDefNames["lozroach"].id] = { distance = 3000, chance = 0.01 },
		[UnitDefNames["fedak"].id] = { distance = 3000, chance = 0.01 },
		[UnitDefNames["fedstorm"].id] = { distance = 3000, chance = 0.01 },
		[UnitDefNames["chickenrecluse"].id] = { distance = 3000, chance = 0.01 },
		[UnitDefNames["chickenmossberg"].id] = { distance = 3000, chance = 0.01 },
		-- T2
		[UnitDefNames["lozreaper"].id] = { distance = 3000, chance = 0.01 },
		[UnitDefNames["fedbear"].id] = { distance = 3000, chance = 0.01 },
		[UnitDefNames["chickenbasher"].id] = { distance = 3000, chance = 0.01 },
		[UnitDefNames["chickensledge"].id] = { distance = 3000, chance = 0.01 },
		-- T3
		[UnitDefNames["lozmammoth"].id] = { distance = 3000, chance = 0.01 },
		[UnitDefNames["fedstriker"].id] = { distance = 3000, chance = 0.01 },
		[UnitDefNames["fedgoliath"].id] = { distance = 3000, chance = 0.01 },
		-- T4
		[UnitDefNames["lozsilverback"].id] = { distance = 3000, chance = 0.01 },
		[UnitDefNames["fedjuggernaut"].id] = { distance = 3000, chance = 1 },
		[UnitDefNames["chickenanarchid"].id] = { distance = 3000, chance = 1 },

		[UnitDefNames["chickenboss_veryeasy"].id] = { distance = 2000, chance = 0.001 },
		[UnitDefNames["chickenboss_easy"].id] = { distance = 2000, chance = 0.001 },
		[UnitDefNames["chickenboss_normal"].id] = { distance = 2000, chance = 0.001 },
		[UnitDefNames["chickenboss_hard"].id] = { distance = 2000, chance = 0.001 },
		[UnitDefNames["chickenboss_veryhard"].id] = { distance = 2000, chance = 0.001 },
		[UnitDefNames["chickenboss_epic"].id] = { distance = 2000, chance = 0.001 },
	},
	HEALER = { -- Getting long max lifetime and always use Fight command. These units spawn as healers from burrows and queen
		[UnitDefNames["lozflea"].id] = true,
		[UnitDefNames["chickenhealer_mk1"].id] = true,
		[UnitDefNames["chickenhealer_mk2"].id] = true,
		[UnitDefNames["chickenhealer_mk3"].id] = true,
		[UnitDefNames["chickenhealer_mk4"].id] = true,
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
		chickenSpawnRate  = 90, -- Time between Waves in seconds
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
		queenName         = 'chickenboss_veryeasy',
		queenResistanceMult   = 1.5*Spring.GetModOptions().chicken_queentimemult, -- Multipler for how quickly the queen will gain resistances for each weapon
	},

	[difficulties.easy] = {
		gracePeriod       = 6 * Spring.GetModOptions().chicken_graceperiodmult * 60,
		queenTime      	  = 60 * Spring.GetModOptions().chicken_queentimemult * 60, -- time at which the queen appears, frames
		chickenSpawnRate  = 75,
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
		queenName         = 'chickenboss_easy',
		queenResistanceMult   = 1.75*Spring.GetModOptions().chicken_queentimemult,
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
		queenName         = 'chickenboss_normal',
		queenResistanceMult   = 2*Spring.GetModOptions().chicken_queentimemult,
	},
	[difficulties.hard] = {
		gracePeriod       = 6 * Spring.GetModOptions().chicken_graceperiodmult * 60,
		queenTime      	  = 60 * Spring.GetModOptions().chicken_queentimemult * 60, -- time at which the queen appears, frames
		chickenSpawnRate  = 50,
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
		queenName         = 'chickenboss_hard',
		queenResistanceMult   = 2.5*Spring.GetModOptions().chicken_queentimemult,
	},
	[difficulties.veryhard] = {
		gracePeriod       = 6 * Spring.GetModOptions().chicken_graceperiodmult * 60,
		queenTime      	  = 60 * Spring.GetModOptions().chicken_queentimemult * 60, -- time at which the queen appears, frames
		chickenSpawnRate  = 40,
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
		queenName         = 'chickenboss_veryhard',
		queenResistanceMult   = 3*Spring.GetModOptions().chicken_queentimemult,
	},
	[difficulties.epic] = {
		gracePeriod       = 6 * Spring.GetModOptions().chicken_graceperiodmult * 60,
		queenTime      	  = 60 * Spring.GetModOptions().chicken_queentimemult * 60, -- time at which the queen appears, frames
		chickenSpawnRate  = 30,
		burrowSpawnRate   = 30,
		turretSpawnRate   = 90,
		queenSpawnMult    = 3,
		angerBonus        = 0.1,
		maxXP			  = 5,
		spawnChance       = 0.6,
		damageMod         = 1,
		maxBurrows        = 1000,
		chickenPerPlayerMultiplier = 1, -- This modifies the minimum and maximum number of chickens that will spawn for each player on the map
		minChickens		  = 10,
		maxChickens		  = 50,
		queenName         = 'chickenboss_epic',
		queenResistanceMult   = 3*Spring.GetModOptions().chicken_queentimemult,
	},
}

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local squadSpawnOptionsTable = {
	basic = {}, -- 67% spawn chance
	special = {}, -- 33% spawn chance, there's 1% chance of Special squad spawning Super squad, which is specials but 30% anger earlier.
	air = {}, -- Air waves
	healer = {},
}

local function addNewSquad(squadParams) -- params: {type = "basic", minAnger = 0, maxAnger = 100, units = {"1 chicken1"}, weight = 1}
	if squadParams then -- Just in case
		if not squadParams.units then return end
		if not squadParams.minAnger then squadParams.minAnger = 0 end
		if not squadParams.maxAnger then squadParams.maxAnger = squadParams.minAnger + 1000 end -- Eliminate squads 50% after they're introduced by default, can be overwritten
		if squadParams.maxAnger >= 1000 then squadParams.maxAnger = 1000 end -- basically infinite
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
		"chickenrecluse",
		"chickenmossberg",
	},
	t1support = {
		"lozscorpion",
		"fedcrasher",
		"fedthud",
	},

	t2assault = {
		"lozreaper",
		"fedbear",
		"chickenbasher",
		"chickensledge",
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
		"chickenanarchid",
	},
	t3support = {
		"lozemperorscorpion",
		"lozprotector",
		"feddeleter",
		"chickendroplet",
	},

	t4assault = {
		"lozsilverback",
		"fedjuggernaut",
	},
	t4support = {
		"chickeneurypterid",
		-- some T3 for balance
		"lozprotector",
		"feddeleter",
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
	t4air = {
		"chickenvulture",
		-- some T3 for balance
		"lozlocust",
		"loztitan",
		"fedfalcon",
		"fedeagle",
	},

	t1healer = {
		"chickenhealer_mk1",
	},
	t2healer = {
		"chickenhealer_mk2",
	},
	t3healer = {
		"chickenhealer_mk3",
	},
	t4healer = {
		"chickenhealer_mk4",
	},
}

local miniBosses = {} -- Units that spawn alongside queen
table.append(miniBosses, chickenSquadUnitTable.t3assault)
table.append(miniBosses, chickenSquadUnitTable.t3support)
table.append(miniBosses, chickenSquadUnitTable.t4assault)
table.append(miniBosses, chickenSquadUnitTable.t4support)


local chickenMinions = { -- Units spawning other units
	-- Artillery spawning here is a bit too strong and makes the battle somewhat unapproachable
	["chickenboss_veryeasy"] 	= chickenSquadUnitTable.t1assault,
	["chickenboss_easy"] 		= chickenSquadUnitTable.t1assault,
	["chickenboss_normal"] 		= chickenSquadUnitTable.t2assault,
	["chickenboss_hard"] 		= chickenSquadUnitTable.t2assault,
	["chickenboss_veryhard"] 	= chickenSquadUnitTable.t2assault,
	["chickenboss_epic"] 		= chickenSquadUnitTable.t3assault,
	["chickensbeacon"] 			= {"lozflea",}
}

------------------
-- Basic Squads --
------------------
------------------

for anger = 0,1000 do
	local cst = chickenSquadUnitTable
	if anger%5 == 0 then -- only add squads every 5 anger
		if anger < 30 then
			for i = 1,10 do
				addNewSquad({ type = "basic", minAnger = anger, units = { "3 " .. cst.t1assault[math.random(1,#cst.t1assault)] } })
			end
		elseif anger < 60 then
			for i = 1,10 do
				addNewSquad({ type = "basic", minAnger = anger, units = { "5 " .. cst.t1assault[math.random(1,#cst.t1assault)] } })
				addNewSquad({ type = "basic", minAnger = anger, units = { "5 " .. cst.t1support[math.random(1,#cst.t1support)] } })
			end
		elseif anger < 90 then
			for i = 1,5 do
				addNewSquad({ type = "basic", minAnger = anger, units = { "10 " .. cst.t1assault[math.random(1,#cst.t1assault)] } })
				addNewSquad({ type = "basic", minAnger = anger, units = { "10 " .. cst.t1support[math.random(1,#cst.t1support)] } })

				addNewSquad({ type = "basic", minAnger = anger, units = { "2 " .. cst.t2assault[math.random(1,#cst.t2assault)] } })
				addNewSquad({ type = "basic", minAnger = anger, units = { "2 " .. cst.t2support[math.random(1,#cst.t2support)] } })
			end
		else
			for i = 1,2 do

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

for anger = 0,1000 do
	local cst = chickenSquadUnitTable
	if anger%5 == 0 then -- only add squads every 5 anger
		if anger < 10 then
			for i = 1,10 do
				addNewSquad({ type = "special", minAnger = anger, units = { "5 " .. cst.t1assault[math.random(1,#cst.t1assault)] } })
			end
		elseif anger < 30 then
			for i = 1,10 do
				addNewSquad({ type = "special", minAnger = anger, units = { "10 " .. cst.t1assault[math.random(1,#cst.t1assault)] } })
				addNewSquad({ type = "special", minAnger = anger, units = { "5 " .. cst.t1assault[math.random(1,#cst.t1assault)], "5 " .. cst.t1assault[math.random(1,#cst.t1assault)] } })
				addNewSquad({ type = "special", minAnger = anger, units = { "5 "  .. cst.t1assault[math.random(1,#cst.t1assault)], "5 " .. cst.t1support[math.random(1,#cst.t1support)] } })
			end
		elseif anger < 60 then
			for i = 1,10 do
				addNewSquad({ type = "special", minAnger = anger, units = { "20 " .. cst.t1assault[math.random(1,#cst.t1assault)] } })
				addNewSquad({ type = "special", minAnger = anger, units = { "10 "  .. cst.t1assault[math.random(1,#cst.t1assault)], "10 " .. cst.t1assault[math.random(1,#cst.t1assault)] } })
				addNewSquad({ type = "special", minAnger = anger, units = { "10 "  .. cst.t1assault[math.random(1,#cst.t1assault)], "10 " .. cst.t1support[math.random(1,#cst.t1support)] } })

				addNewSquad({ type = "special", minAnger = anger, units = { "4 " .. cst.t2assault[math.random(1,#cst.t2assault)] } })
				addNewSquad({ type = "special", minAnger = anger, units = { "2 "  .. cst.t2assault[math.random(1,#cst.t2assault)], "2 " .. cst.t2assault[math.random(1,#cst.t2assault)] } })
				addNewSquad({ type = "special", minAnger = anger, units = { "2 "  .. cst.t2assault[math.random(1,#cst.t2assault)], "2 " .. cst.t2support[math.random(1,#cst.t2support)] } })
			end
		elseif anger < 90 then
			for i = 1,5 do
				addNewSquad({ type = "special", minAnger = anger, units = { "8 " .. cst.t2assault[math.random(1,#cst.t2assault)] } })
				addNewSquad({ type = "special", minAnger = anger, units = { "4 "  .. cst.t2assault[math.random(1,#cst.t2assault)], "4 " .. cst.t2assault[math.random(1,#cst.t2assault)] } })
				addNewSquad({ type = "special", minAnger = anger, units = { "4 "  .. cst.t2assault[math.random(1,#cst.t2assault)], "4 " .. cst.t2support[math.random(1,#cst.t2support)] } })

				addNewSquad({ type = "special", minAnger = anger, units = { "2 " .. cst.t3assault[math.random(1,#cst.t3assault)] } })
				addNewSquad({ type = "special", minAnger = anger, units = { "1 "  .. cst.t3assault[math.random(1,#cst.t3assault)], "1 " .. cst.t3assault[math.random(1,#cst.t3assault)] } })
				addNewSquad({ type = "special", minAnger = anger, units = { "1 "  .. cst.t3assault[math.random(1,#cst.t3assault)], "1 " .. cst.t3support[math.random(1,#cst.t3support)] } })
			end
		else
			for i = 1,2 do
				addNewSquad({ type = "special", minAnger = anger, units = { "1 " .. cst.t3assault[math.random(1,#cst.t3assault)] } })
				addNewSquad({ type = "special", minAnger = anger, units = { "1 "  .. cst.t3assault[math.random(1,#cst.t3assault)], "1 " .. cst.t3assault[math.random(1,#cst.t3assault)] } })
				addNewSquad({ type = "special", minAnger = anger, units = { "1 "  .. cst.t3assault[math.random(1,#cst.t3assault)], "1 " .. cst.t3support[math.random(1,#cst.t3support)] } })

				addNewSquad({ type = "special", minAnger = anger, units = { "1 " .. cst.t4assault[math.random(1,#cst.t4assault)] } })
				addNewSquad({ type = "special", minAnger = anger, units = { "1 "  .. cst.t4assault[math.random(1,#cst.t4assault)], "1 " .. cst.t4support[math.random(1,#cst.t4support)] } })
			end
		end
	end
end

----------------
-- Air Squads --
----------------
----------------

local airStartAnger = 15 -- needed for air waves to work correctly.

for anger = 0,1000 do
	local cst = chickenSquadUnitTable
	if anger%5 == 0 then -- only add squads every 5 anger
		if anger < 30 then
			for i = 1,10 do
				addNewSquad({ type = "air", minAnger = anger, units = { "1 " .. cst.t1air[math.random(1,#cst.t1air)] } })
			end
		elseif anger < 60 then
			for i = 1,10 do
				addNewSquad({ type = "air", minAnger = anger, units = { "2 " .. cst.t1air[math.random(1,#cst.t1air)] } })

				addNewSquad({ type = "air", minAnger = anger, units = { "1 " .. cst.t2air[math.random(1,#cst.t2air)] } })
			end
		elseif anger < 90 then
			for i = 1,5 do
				addNewSquad({ type = "air", minAnger = anger, units = { "2 " .. cst.t2air[math.random(1,#cst.t2air)] } })

				addNewSquad({ type = "air", minAnger = anger, units = { "1 " .. cst.t3air[math.random(1,#cst.t3air)] } })
			end
		else
			for i = 1,2 do
				addNewSquad({ type = "air", minAnger = anger, units = { "2 " .. cst.t3air[math.random(1,#cst.t3air)] } })

				addNewSquad({ type = "air", minAnger = anger, units = { "1 " .. cst.t4air[math.random(1,#cst.t4air)] } })
			end
		end
	end
end

for anger = 0,1000 do
	local cst = chickenSquadUnitTable
	if anger%5 == 0 then -- only add squads every 5 anger
		if anger < 30 then
			for i = 1,10 do
				addNewSquad({ type = "healer", minAnger = anger, maxAnger = anger+10, units = { "1 " .. cst.t1healer[math.random(1,#cst.t1healer)] } })
			end
		elseif anger < 60 then
			for i = 1,10 do
				addNewSquad({ type = "healer", minAnger = anger, maxAnger = anger+10, units = { "2 " .. cst.t1healer[math.random(1,#cst.t1healer)] } })

				addNewSquad({ type = "healer", minAnger = anger, maxAnger = anger+10, units = { "1 " .. cst.t2healer[math.random(1,#cst.t2healer)] } })
			end
		elseif anger < 90 then
			for i = 1,5 do
				addNewSquad({ type = "healer", minAnger = anger, maxAnger = anger+10, units = { "2 " .. cst.t2healer[math.random(1,#cst.t2healer)] } })

				addNewSquad({ type = "healer", minAnger = anger, maxAnger = anger+10, units = { "1 " .. cst.t3healer[math.random(1,#cst.t3healer)] } })
			end
		else
			for i = 1,2 do
				addNewSquad({ type = "healer", minAnger = anger, maxAnger = anger+10, units = { "2 " .. cst.t3healer[math.random(1,#cst.t3healer)] } })

				addNewSquad({ type = "healer", minAnger = anger, units = { "1 " .. cst.t4healer[math.random(1,#cst.t4healer)] } })
			end
		end
	end
end

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
local minBaseDistance = 256 -- Minimum distance of new burrows from players and other burrows
local burrowTurretSpawnRadius = 64
local bossFightWaveSizeScale = 50 -- Percentage
local defaultChickenFirestate = 2 -- 0 - Hold Fire | 1 - Return Fire | 2 - Fire at Will | 3 - Fire at everything

local config = { -- Don't touch this! ---------------------------------------------------------------------------------------------------------------------------------------------
	useEggs 				= useEggs,
	useScum					= useScum,
	difficulty             	= difficulty,
	difficulties           	= difficulties,
	chickenEggs			   	= table.copy(chickenEggs),
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
	bossFightWaveSizeScale  = bossFightWaveSizeScale,
	defaultChickenFirestate = defaultChickenFirestate,
}

for key, value in pairs(optionValues[difficulty]) do
	config[key] = value
end

return config