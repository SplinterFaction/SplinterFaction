local fedSquadDefs = {
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
	-- Fed Tech 1 Squads --
	----------------------------

	["fedak"] =
	{
		members = {
			"fedak",
			"fedak",
			"fedak",
		},
		name = "A.K. Squad",
		description = "A.K. Group",
		--buildCostMetal = 150, --2500
		buildPic = "fedak.ssd",
		size = 3,
		delay = 7,
	},

	["fedstorm"] =
	{
		members = {
			"fedstorm",
			"fedstorm",
		},
		name = "Storm Squad",
		description = "Storm Group",
		--buildCostMetal = 150, --2500
		buildPic = "fedstorm.ssd",
		size = 2,
		delay = 7,
	},

	["fedthud"] =
	{
		members = {
			"fedthud",
		},
		name = "Thud Squad",
		description = "Storm Group",
		--buildCostMetal = 150, --2500
		buildPic = "fedthud.ssd",
		size = 1,
		delay = 7,
	},

	["fedcrasher"] =
	{
		members = {
			"fedcrasher",
		},
		name = "Crasher Squad",
		description = "Storm Group",
		--buildCostMetal = 150, --2500
		buildPic = "fedthud.ssd",
		size = 1,
		delay = 7,
	},
}

return fedSquadDefs
