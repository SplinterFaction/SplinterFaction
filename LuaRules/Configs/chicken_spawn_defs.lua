
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
local waves = {}
local basicWaves = {}
local specialWaves = {}
local superWaves = {}
local airWaves = {}

local burrowName = 'healstation_ai'

local chickenTurrets = {
	lightTurrets = { 					-- Spawn from the start
		"fedmenlo",
		"lozjericho",
		"fedstinger",
		"lozrazor",
	},
	heavyTurrets = { 					-- Spawn from 20% queen anger
		"fedimmolator",
		"lozinferno",
		"fedjavelin",
		"lozrattlesnake",
	},
	specialLightTurrets = { 			-- Spawn from 40% queen anger alongside lightTurrets
		"fedimmolator",
		"lozinferno",
		"fedjavelin",
		"lozrattlesnake",
	},
	specialHeavyTurrets = { 			-- Spawn from 60% queen anger alongside heavyTurrets
		"fedguardian",
		"lozannihilator",
	},
	burrowDefenders = {					-- Spawns connected to burrow
		"fedimmolator",
		"lozinferno",
	},
}

local chickenEggs = { -- Specify eggs dropped by unit here, requires useEggs to be true, if some unit is not specified here, it drops random egg colors.

}

chickenBehaviours = {
	SKIRMISH = { -- Run away from target after target gets hit -- This is for fast light units
		[UnitDefNames["fedak"].id] = { distance = 270, chance = 0.5 },
		[UnitDefNames["fedstorm"].id] = { distance = 270, chance = 0.5 },
		[UnitDefNames["fedthud"].id] = { distance = 270, chance = 0.5 },
		[UnitDefNames["fedcrasher"].id] = { distance = 270, chance = 0.5 },
		[UnitDefNames["lozdiamondback"].id] = { distance = 270, chance = 0.5 },
		[UnitDefNames["lozroach"].id] = { distance = 270, chance = 0.5 },
		[UnitDefNames["lozscorpion"].id] = { distance = 270, chance = 0.5 },
		[UnitDefNames["fedbear"].id] = { distance = 270, chance = 0.5 },
		[UnitDefNames["fedcobra"].id] = { distance = 270, chance = 0.5 },
		[UnitDefNames["fedavalanche"].id] = { distance = 270, chance = 0.5 },
		[UnitDefNames["fedphalanx"].id] = { distance = 270, chance = 0.5 },
		[UnitDefNames["lozreaper"].id] = { distance = 270, chance = 0.5 },
		[UnitDefNames["lozluger"].id] = { distance = 270, chance = 0.5 },


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
		[UnitDefNames["fedak"].id] = { distance = 270, chance = 0.5 },
		[UnitDefNames["fedstorm"].id] = { distance = 270, chance = 0.5 },
		[UnitDefNames["fedthud"].id] = { distance = 270, chance = 0.5 },
		[UnitDefNames["fedcrasher"].id] = { distance = 270, chance = 0.5 },
		[UnitDefNames["lozdiamondback"].id] = { distance = 270, chance = 0.5 },
		[UnitDefNames["lozroach"].id] = { distance = 270, chance = 0.5 },
		[UnitDefNames["lozscorpion"].id] = { distance = 270, chance = 0.5 },
		[UnitDefNames["fedbear"].id] = { distance = 270, chance = 0.5 },
		[UnitDefNames["fedcobra"].id] = { distance = 270, chance = 0.5 },
		[UnitDefNames["fedavalanche"].id] = { distance = 270, chance = 0.5 },
		[UnitDefNames["fedphalanx"].id] = { distance = 270, chance = 0.5 },
		[UnitDefNames["lozreaper"].id] = { distance = 270, chance = 0.5 },
		[UnitDefNames["lozluger"].id] = { distance = 270, chance = 0.5 },

	},
	BERSERK = { -- Run towards target after getting hit by enemy or after hitting the target-- This is for heavy slow units
		[UnitDefNames["fedgoliath"].id] = { distance = 270, chance = 0.5 },
		[UnitDefNames["fedjuggernaut"].id] = { distance = 270, chance = 0.5 },
		[UnitDefNames["lozmammoth"].id] = { distance = 270, chance = 0.5 },
		[UnitDefNames["lozsilverback"].id] = { distance = 270, chance = 0.5 },
		[UnitDefNames["fedanarchid"].id] = { distance = 270, chance = 0.5 },
	},
	HEALER = { -- Getting long max lifetime and always use Fight command. These units spawn as healers from burrows and queen
		"lozengineer_ai",
		--"lozengineer_up1",
		--"lozengineer_up2",
		--"lozengineer_up3",
		"fedengineer_ai",
		--"fedengineer_up1",
		--"fedengineer_up2",
		--"fedengineer_up3",

	},
	ARTILLERY = { -- Long lifetime and no regrouping, always uses Fight command to keep distance
		"fedavalanche",
		"lozluger",
	},
	KAMIKAZE = { -- Long lifetime and no regrouping, always uses Move command to rush into the enemy

	},
	PROBE_UNIT = UnitDefNames["lozreaper"].id, -- tester unit for picking viable spawn positions - use some medium sized unit
}

local optionValues = {
	-- [difficulties.veryeasy] = {
	-- 	chickenSpawnRate  = 120,
	-- 	burrowSpawnRate   = 105,
	-- 	turretSpawnRate   = 210,
	-- 	queenSpawnMult    = 0,
	-- 	angerBonus        = 1,
	-- 	maxXP			  = 0.1,
	-- 	spawnChance       = 0.25,
	-- 	damageMod         = 0.1,
	-- 	maxBurrows        = 2,
	-- 	minChickens		  = 5,
	-- 	maxChickens		  = 75,
	-- 	queenName         = 've_chickenq',
	-- 	queenResistanceMult   = 0.25,
	-- },
	-- [difficulties.easy] = {
	-- 	chickenSpawnRate  = 120,
	-- 	burrowSpawnRate   = 90,
	-- 	turretSpawnRate   = 180,
	-- 	queenSpawnMult    = 0,
	-- 	angerBonus        = 1,
	-- 	maxXP			  = 0.25,
	-- 	spawnChance       = 0.33,
	-- 	damageMod         = 0.2,
	-- 	maxBurrows        = 3,
	-- 	minChickens		  = 10,
	-- 	maxChickens		  = 100,
	-- 	queenName         = 'e_chickenq',
	-- 	queenResistanceMult   = 0.5,
	-- },

	[difficulties.normal] = {
		chickenSpawnRate  = 30, -- Time between Waves in seconds
		burrowSpawnRate   = 75, -- Time inbetween burrow spawns in seconds
		turretSpawnRate   = 60, -- Time inbetween turret spawns in seconds
		queenSpawnMult    = 1, -- Unused, don't touch (just in case)
		angerBonus        = 0.2, -- Multiplier for boss anger when you kill a burrow
		maxXP			  = 0.5, -- Random amount of XP given to spawned units
		spawnChance       = 0.2, -- What are the chances that a burrow will spawn units each wave (this check is performed on each burrow)
		damageMod         = 1, -- Multiplier for how much damage spawned units will deal to player units
		maxBurrows        = 1000, -- Maximum number of burrows that can be on the map
		chickenPerPlayerMultiplier = 1, -- This modifies the minimum and maximum number of chickens that will spawn for each player on the map
		minChickens		  = 10, -- Number of ai units spawned in the beginning stages of the game per wave
		maxChickens		  = 50, -- Number of ai units spawned in the end stages of the game per wave
		queenName         = 'fedanarchid_insane',
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

local wavesAmount = 10
if difficulty >= 3 then
	wavesAmount = 12
end

-- local function addSquad(wave, unitList, weight) -- unused
-- 	if not weight then weight = 1 end
--     for i = 1, weight do 
-- 		for j = wave,wavesAmount do
-- 			if not waves[j] then
-- 				waves[j] = {}
-- 			end
-- 			table.insert(waves[j], unitList)
-- 		end
--     end
-- end

local function addSuperSquad(tier, unitList, weight)
	if not weight then weight = 1 end
    for i = 1, weight do 
		for j = tier,wavesAmount do
			--tier = math.max(math.min(tier+math.random(-1,1), wavesAmount), 1)
			if not superWaves[j] then
				superWaves[j] = {}
			end
			table.insert(superWaves[j], unitList)
		end
    end
end

local function addSpecialSquad(tier, unitList, weight)
	if not weight then weight = 1 end
	-- addSuperSquad(math.max(tier-3, 1), unitList, weight)
    for i = 1, weight do 
		for j = tier,wavesAmount do
			--tier = math.max(math.min(tier+math.random(-1,1), wavesAmount), 1)
			if not specialWaves[j] then
				specialWaves[j] = {}
			end
			table.insert(specialWaves[j], unitList)
		end
    end
end

local function addBasicSquad(tier, unitList, weight)
	if not weight then weight = 1 end
    for i = 1, weight do 
		for j = tier,wavesAmount do
			if not basicWaves[j] then
				basicWaves[j] = {}
			end
			table.insert(basicWaves[j], unitList)
		end
    end
end

local function addAirSquad(tier, unitList, weight)
	if not weight then weight = 1 end
    for i = 1, weight do 
		for j = tier,wavesAmount do
			--tier = math.max(math.min(tier+math.random(-1,1), wavesAmount), 1)
			if not airWaves[j] then
				airWaves[j] = {}
			end
			table.insert(airWaves[j], unitList)
		end
    end
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- MiniBoss Squads ----------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local miniBosses = { -- Units that spawn alongside queen
	"fedjuggernaut",
	"lozsilverback",
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

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Special Squads -----------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Each Tier is representative of 10% of Queen Anger. Tier 1 is 0 - 10 queen anger, where tier 10 is 90 - 100 queen anger.

	addSpecialSquad(1, {"15 fedak"}, 1)
	addSpecialSquad(1, {"15 lozdiamondback"}, 1)
	addSpecialSquad(1, {"10 fedstorm", "4 fedthud"}, 1)
	addSpecialSquad(1, {"10 lozroach", "8 lozscorpion"}, 1)

	addSpecialSquad(2, {"10 fedstorm", "4 fedthud"}, 1)
	addSpecialSquad(2, {"10 lozroach", "8 lozscorpion"}, 1)
	addSpecialSquad(2, {"1 fedbear", "1 fedcobra"}, 2)
	addSpecialSquad(2, {"1 lozreaper", "1 lozpulverizer"}, 2)

	addSpecialSquad(3, {"10 fedstorm", "4 fedthud"}, 1 )
	addSpecialSquad(3, {"10 lozroach", "8 lozscorpion"}, 1)
	addSpecialSquad(3, {"3 fedbear", "1 fedcobra"}, 2)
	addSpecialSquad(3, {"3 lozreaper", "1 lozpulverizer"}, 2)

	addSpecialSquad(4, {"10 fedstorm", "4 fedthud"}, 1)
	addSpecialSquad(4, {"10 lozroach", "8 lozscorpion"}, 1)
	addSpecialSquad(4, {"5 fedbear", "5 fedcobra"}, 4)
	addSpecialSquad(4, {"5 lozreaper", "5 lozpulverizer"}, 4)

	addSpecialSquad(5, {"10 fedbear", "8 fedcobra"}, 3)
	addSpecialSquad(5, {"10 lozreaper", "8 lozpulverizer"}, 3)

	addSpecialSquad(6, {"10 fedavalanche"}, 1)
	addSpecialSquad(6, {"10 lozluger"}, 1)
	addSpecialSquad(6, {"1 lozmammoth"}, 1)
	addSpecialSquad(6, {"1 fedgoliath"}, 1)

	addSpecialSquad(7, {"10 fedbear", "8 fedcobra"}, 1)
	addSpecialSquad(7, {"10 lozreaper", "8 lozpulverizer"}, 1)
	addSpecialSquad(7, {"10 fedavalanche"}, 1)
	addSpecialSquad(7, {"10 lozluger"}, 1)
	addSpecialSquad(7, {"2 lozmammoth"}, 2)
	addSpecialSquad(7, {"2 fedgoliath"}, 2)

	addSpecialSquad(8, {"10 fedbear", "8 fedcobra"}, 1)
	addSpecialSquad(8, {"10 lozreaper", "8 lozpulverizer"}, 1)
	addSpecialSquad(8, {"10 fedavalanche"}, 1)
	addSpecialSquad(8, {"10 lozluger"}, 1)
	addSpecialSquad(8, {"2 lozmammoth"}, 2)
	addSpecialSquad(8, {"2 fedgoliath"}, 2)
	addSpecialSquad(8, {"1 lozsilverback", "5 lozreaper", "5 lozpulverizer"}, 3)
	addSpecialSquad(8, {"1 fedjuggernaut", "5 fedbear", "5 fedcobra"}, 3)

	addSpecialSquad(9, {"1 lozsilverback", "5 lozreaper", "5 lozpulverizer"}, 1)
	addSpecialSquad(9, {"1 fedjuggernaut", "5 fedbear", "5 fedcobra"}, 1)
	addSpecialSquad(9, {"1 lozsilverback", "2 lozmammoth", "5 lozreaper", "5 lozpulverizer", "10 lozluger"}, 2)
	addSpecialSquad(9, {"1 fedjuggernaut", "2 fedgoliath", "5 fedbear", "5 fedcobra", "10 fedavalanche"}, 2)

	addSpecialSquad(10, {"2 lozsilverback", "5 lozreaper", "5 lozpulverizer"}, 1)
	addSpecialSquad(10, {"2 fedjuggernaut", "5 fedbear", "5 fedcobra"}, 1)
	addSpecialSquad(10, {"2 lozsilverback", "4 lozmammoth", "5 lozreaper", "5 lozpulverizer"}, 4)
	addSpecialSquad(10, {"2 fedjuggernaut", "4 fedgoliath", "5 fedbear", "5 fedcobra"}, 4)

--[[
if difficulty >= 3 then
	for i = 11,wavesAmount do
	addSpecialSquad(i, { "5 chickenapexallterrainassault", "5 chickenapexallterrainassaultb"			})
	addSpecialSquad(i, { "10 chickena2_spectre"															})
	addSpecialSquad(i, { "3 chickenr1", "3 chickenearty1", "3 chickenacidarty" 							})
	if not Spring.GetModOptions().unit_restrictions_nonukes then
		addSpecialSquad(i, { "1 chickenr2" 																})
	end
	addSpecialSquad(i, { "2 chickenh2" 																	})
	addSpecialSquad(i, { "3 chickene2" 																    })
	addSpecialSquad(i, { "3 chickenelectricallterrainassault" 											})
	addSpecialSquad(i, { "3 chickenacidassault" 														})
	addSpecialSquad(i, { "3 chickenacidallterrainassault" 												})
	addSpecialSquad(i, { "25 chicken_dodo2" 															})
	addSpecialSquad(i, { "10 chickenp2" 																})
	addSpecialSquad(i, { "10 chickens2" 																}, 2)
	addSpecialSquad(i, { "10 chickens2_spectre" 														}, 2)
	end
end
]]--


------------------
-- Basic Squads --
------------------
------------------

for i = 1,wavesAmount do
	if i <= 2 then -- Basic Swarmer
		addBasicSquad(i, {"5 fedak"}, 1)
		addBasicSquad(i, {"5 fedstorm"}, 1)
		addBasicSquad(i, {"5 lozdiamondback"}, 1)
		addBasicSquad(i, {"5 lozroach"}, 1)
	elseif i <= 4 then
		addBasicSquad(i, {"5 fedstorm"}, 1)
		addBasicSquad(i, {"5 fedthud"}, 1)
		addBasicSquad(i, {"5 fedbear"}, 2)
		addBasicSquad(i, {"5 lozroach"}, 1)
		addBasicSquad(i, {"5 lozscorpion"}, 1)
		addBasicSquad(i, {"5 lozreaper"}, 2)
	elseif i <= 6 then
		addBasicSquad(i, {"5 fedstorm"}, 1)
		addBasicSquad(i, {"5 fedthud"}, 1)
		addBasicSquad(i, {"10 fedbear", "5 fedcobra"}, 3)
		addBasicSquad(i, {"5 lozroach"}, 1)
		addBasicSquad(i, {"5 lozscorpion"}, 1)
		addBasicSquad(i, {"10 lozreaper", "5 lozpulverizer"}, 3)
	elseif i <= 8 then
		addBasicSquad(i, {"10 fedbear", "5 fedcobra"}, 1)
		addBasicSquad(i, {"10 lozreaper", "5 lozpulverizer"}, 1)
		addBasicSquad(i, {"2 fedgoliath"}, 2)
		addBasicSquad(i, {"2 lozmammoth"}, 2)
	elseif i <= 10 then
		addBasicSquad(i, {"5 fedbear", "5 fedcobra"}, 1)
		addBasicSquad(i, {"10 lozreaper", "5 lozpulverizer" }, 1)
		addBasicSquad(i, {"2 fedgoliath"}, 2)
		addBasicSquad(i, {"2 lozmammoth"}, 2)
	end
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Air Squads ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

addAirSquad(5, {"4 fedsparrow"})
addAirSquad(5, {"4 lozwasp"})
addAirSquad(5, {"4 fedhawk", "4 lozhornet" })
addAirSquad(5, {"5 fedcrow"})
addAirSquad(5, {"3 fedhawk", "5 lozbumblebee"})
addAirSquad(5, {"2 fedcondor" })
addAirSquad(5, {"2 lozcrane" })

addAirSquad(5, {"3 fedhawk", "4 lozhornet" })
addAirSquad(5, {"2 lozhornet", "5 fedcrow"})
addAirSquad(5, {"3 fedhawk", "5 lozbumblebee"})
addAirSquad(5, {"2 fedcondor", "5 lozcrane"})

addAirSquad(6, {"3 fedhawk", "3 lozhornet" })
addAirSquad(6, {"3 lozhornet", "5 fedcrow"})
addAirSquad(6, {"3 fedhawk", "5 lozbumblebee"})
addAirSquad(6, {"3 fedcondor", "3 lozcrane"})
addAirSquad(6, { "1 fedeagle", "1 loztitan" })

addAirSquad(7, {"6 fedhawk", "6 lozhornet" })
addAirSquad(7, {"5 lozhornet", "10 fedcrow"})
addAirSquad(7, {"5 fedhawk", "10 lozbumblebee"})
addAirSquad(7, {"3 fedcondor", "3 lozcrane"})
addAirSquad(7, { "1 fedeagle", "1 loztitan" })

addAirSquad(8, {"6 fedhawk", "10 lozbumblebee", "6 lozhornet", "10 fedcrow"})
addAirSquad(8, {"3 fedcondor", "3 lozcrane"})
addAirSquad(8, { "2 fedeagle", "2 loztitan" })

addAirSquad(9, {"6 fedhawk", "10 lozbumblebee", "5 lozhornet", "10 fedcrow"})
addAirSquad(9, {"4 fedcondor", "4 lozcrane"})
addAirSquad(9, {"3 fedeagle", "3 loztitan" })

addAirSquad(10, {"6 fedhawk", "10 lozbumblebee", "5 lozhornet", "10 fedcrow"})
addAirSquad(10, {"10 fedhawk", "10 lozhornet"})
addAirSquad(10, {"5 fedeagle", "5 loztitan" })




if difficulty >= 3 then
	for i = 11,wavesAmount do
		addAirSquad(i, { "6 fedeagle", "6 loztitan" })
		addAirSquad(i, { "9 fedcrow", "9 lozbumblebee" })
	end
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Settings -- Adjust these
local useEggs = false -- Drop eggs (requires egg features from Beyond All Reason)
local useScum = false -- Use scum as space where turrets can spawn (requires scum gadget from Beyond All Reason)
local useWaveMsg = true -- Show dropdown message whenever new wave is spawning
local spawnSquare = 90 -- size of the chicken spawn square centered on the burrow
local spawnSquareIncrement = 2 -- square size increase for each unit spawned
local minBaseDistance = 750 -- Minimum distance of new burrows from players and other burrows
local burrowTurretSpawnRadius = 100

local config = { -- Don't touch this! ---------------------------------------------------------------------------------------------------------------------------------------------
	useEggs 				= useEggs,
	useScum					= useScum,
	difficulty             	= difficulty,
	difficulties           	= difficulties,
	chickenEggs			   	= table.copy(chickenEggs),
	burrowName             	= burrowName,   -- burrow unit name
	burrowDef              	= UnitDefNames[burrowName].id,
	burrowTurretSpawnRadius = burrowTurretSpawnRadius,
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
	waves                  	= waves,
	wavesAmount            	= wavesAmount,
	basicWaves		   	   	= basicWaves,
	specialWaves           	= specialWaves,
	superWaves             	= superWaves,
	airWaves			   	= airWaves,
	miniBosses			   	= miniBosses,
	chickenMinions			= chickenMinions,
	chickenBehaviours 		= chickenBehaviours,
	difficultyParameters   	= optionValues,
	useWaveMsg				= useWaveMsg,
}

for key, value in pairs(optionValues[difficulty]) do
	config[key] = value
end

return config