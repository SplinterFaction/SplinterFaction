local lozSquadDefs = {
	 ----------------------------
	 -- Arm kBot Squads --
	 ----------------------------

	--["armpw"] =
	--{
	--	members = {
	--		"armpw",
	--		"armpw",
	--		"armpw",
	--	},
	--	name = "Peewee Squad",
	--	description = "3 x Peewee Group",
	--	--buildCostMetal = 150, --2500
	--	buildPic = "ARMPW.DDS",
     --   size = 3,
     --   delay = 7,
	--},

--	["us_platoon_lct"] =
--	{
--		members = {
--			"usm4a4sherman",
--			"usm4a4sherman",
--			"usm4a4sherman",
--			"usm4a4sherman",
--			"usm3halftrack",
--		},
--		-- other fields not needed for transport squads
--	},

	----------------------------
	-- Loz Tech 1 Squads --
	----------------------------

	["lozdiamondback"] =
	{
		members = {
			"lozflea",
			"lozflea",
			"lozdiamondback",
			"lozdiamondback",
			"lozdiamondback",
		},
		name = "Skirmish Squad",
		description = "Mixed Group optimal for Skirmishes",
		--buildCostMetal = 150, --2500
		buildPic = "lozdiamondback.ssd",
		size = 5,
		delay = 7,
	},

	["lozroach"] =
	{
		members = {
			"lozflea",
			"lozdiamondback",
			"lozroach",
			"lozroach",
			"lozroach",
			"lozscorpion",
			"lozscorpion",
		},
		name = "Assault Squad",
		description = "Mixed Group optimal for Assaults",
		--buildCostMetal = 150, --2500
		buildPic = "lozroach.ssd",
		size = 7,
		delay = 7,
	},

	["lozscorpion"] =
	{
		members = {
			"lozscorpion",
			"lozscorpion",
			"lozscorpion",
			"lozdiamondback",
			"lozdiamondback",
			"lozflea",
			"lozflea",
		},
		name = "Artillery Squad",
		description = "Mixed Group optimal for Artillery Purposes",
		--buildCostMetal = 150, --2500
		buildPic = "lozscorpion.ssd",
		size = 7,
		delay = 7,
	},

}

return lozSquadDefs
