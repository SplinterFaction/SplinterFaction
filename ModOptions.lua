local options= {
	{
		key    = 'startingtechlevel',
		name   = 'Starting Tech Level',
		desc   = '',
		type   = 'section',
	},
	{
		key    = 't0ort1',
		name   = 'Start at Tech 0 or Tech 1',
		desc   = 'Allows the option to start the game at Tech 0 or Tech 1',
		type="list",
		def="t0",
		section= "startingtechlevel",
		items={
			{key="t0", name="Tech 0", desc="Start the game at Tech 0"},
			{key="t1", name="Tech 1", desc="Start the game at Tech 1"},
		}
	},
	{
		key    = 'startingresources',
		name   = 'Starting Resources',
		desc   = 'Sets the storage and amount of resources with which each player will start',
		type   = 'section',
	},
	{
		key    = 'startmetal',
		name   = 'Starting Metal',
		desc   = 'Determines the amount of metal and metal storage with which each player will start',
		type   = 'number',
		section= 'startingresources',
		def    = 1000,
		min    = 0,
		max    = 1000,
		step   = 1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},
	{
		key    = 'startenergy',
		name   = 'Starting Energy',
		desc   = 'Determines the amount of energy and energy storage with which each player will start',
		type   = 'number',
		section= 'startingresources',
		def    = 1000,
		min    = 0,
		max    = 1000,
		step   = 1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},
	
	{
		key    = 'restrictions',
		name   = 'Restrictions',
		desc   = 'Engine limitations on game behavior',
		type   = 'section',
	},
	{
        key    = 'maxunits',
        name   = 'Max units',
        desc   = 'Maximum number of units (including buildings) for each team allowed at the same time',
        type   = 'number',
        def    = 2000,
        min    = 500,
        max    = 10000, --- engine caps at lower limit if more than 3 team are ingame
        step   = 1,  -- quantization is aligned to the def value, (step <= 0) means that there is no quantization
        section= "restrictions",
    },

-- Shard AI Options
	{
		key    = 'aioptions',
		name   = 'AI Opponent Options',
		desc   = 'Allows you to adjust AI settings',
		type   = 'section',
	},
	{
		key    = 'ai_enableincomemultiplier',
		name   = 'Enable AI resource cheats',
		desc   = 'Enable AI resource cheats',
		type="list",
		def="disabled",
		section= "aioptions",
		items={
			{key="disabled", name="Disabled", desc="Clean, non cheating AI"},
			{key="enabled", name="Enabled", desc="Laughs in hardcore"},
		}
	},
	{
		key    = 'ai_incomemultiplier',
		name   = 'AI Income Percentage',
		desc   = 'Percentage of AI resource income compared to the default (100 = 100%, I.E. Normal. 200 = 200%, which would mean that the AI income would be double the player income)',
		type   = 'number',
		section= 'aioptions',
		def    = 100,
		min    = 1,
		max    = 1000,
		step   = 1,
	},
	
-- Resourcing
	{
		key    = 'resourcing',
		name   = 'Resourcing Options',
		desc   = 'Allows you to adjust how metal income is handled and how it is distributed',
		type   = 'section',
	},
	{
		key    = 'mexlayout',
		name   = 'Default Metal Spot Layout',
		desc   = 'If enabled, the default layout for metal spots will be used, if disabled, the metal spots defined by the map will be used.',
		type="list",
		def="enabled",
		section= "resourcing",
		items={
			{key="disabled", name="Disabled", desc="Use the Metal Map Layout defined in the map"},
			{key="enabled", name="Enabled", desc="Default Metal Map Layout"},
		}
	},
	{
		key    = 'mexrandomlayout',
		name   = 'Metal Spot Layout to use',
		desc   = 'This allows you to choose between the different metal spot layouts that are available.',
		type="list",
		def="standard",
		section= "resourcing",
		items={
			{key="standard", name="Standard", desc="Random placing that is mirrored. Has various methods for different map shapes and is more careful with metal spot placement."},
			{key="ffa", name="Free For All", desc=""},
			{key="legacy1", name="Legacy 1", desc="Most uniform layout. Max metal ~49.1, Max metal spots 56."},
			{key="legacy2", name="Legacy 2", desc="Less uniform, more clustered layout. Max metal ~50, Max metal spots 56."},
			{key="legacy3", name="Legacy 3", desc="The Pitchfork! Dense metal layout with lower output per metal spot. Max metal ~51.1, Max metal spots 94."},
			{key="legacy4", name="Legacy 4", desc=""},
		}
	},
	{
		key    = 'maximummexelevationdifference',
		name   = 'Standard Metal Spot Layout: Maximum elevation difference for Metal Spot locations',
		desc   = 'This is used as an attempt to avoid placement on cliffs (only works on Standard Metal Spot Layout)',
		type   = 'number',
		section= 'resourcing',
		def    = 50,
		min    = 0,
		max    = 200,
		step   = 1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},
	{
		key    = 'allowmexesinwater',
		name   = 'Standard Metal Spot Layout: Allow metal spots to be placed in water?',
		desc   = 'Should metal spots be placed in water? Sometimes turning this off can be beneficial if the water on a map does damage. (only works on Standard Metal Spot Layout)',
		type="list",
		def="enabled",
		section= "resourcing",
		items={
			{key="disabled", name="Disabled", desc="Disallow metal spots being placed in water."},
			{key="enabled", name="Enabled", desc="Allow metal spots to be placed in water."},
		}
	},
	{
		key    = 'dynamicmexoutput',
		name   = 'Should metal spot output values be dynamic?',
		desc   = 'Uses a sine to determine metal spot values based upon distance from the edge of the map and distance to the center.',
		type="list",
		def="disabled",
		section= "resourcing",
		items={
			{key="disabled", name="Disabled", desc="All metal spot output values will be set to 1.0"},
			{key="enabled", name="Enabled", desc="All metal spot output values will be automatically calculated"},
		}
	},
	{
		key    = 'mexspotspersidemultiplier',
		name   = 'Metal spot per side percentage modifier',
		desc   = 'This is a percentage modifier for the amount of metal spots on a map. A setting of 100 is literally 100%, so increasing to 200% will double the amount of metal spots that are placed on the map. Remember that the amount of metal spots is already scaled according to how many players are in the game.',
		type   = 'number',
		section= 'resourcing',
		def    = 100,
		min    = 1,
		max    = 200,
		step   = 1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},
	{
		key    = 'metalextractorcommunism',
		name   = 'Metal Extractor Communism',
		desc   = 'If enabled, then all metal income from Metal Extractors is split between allies. This means that it does not matter which ally owns the metal extractor, the entire team will benefit.',
		type="list",
		def="disabled",
		section= "resourcing",
		items={
			{key="disabled", name="Disabled", desc="Metal Extractor income will NOT be split between allies."},
			{key="enabled", name="Enabled", desc="Metal Extractor income will be split between allies."},
		}
	},
	{
		key    = 'mincome',
		name   = 'Automatic Metal Income',
		desc   = 'Determines the amount of metal income you start with per second. It increases every <Basic Metal Income Increase Interval> (2.5 minutes, is the default) by this amount until it hits <Maximum Basic Income> income.',
		type="list",
		def="disabled",
		section= "resourcing",
		items={
			{key="disabled", name="Disabled", desc="Turn off the automatic metal income"},
			{key="enabled", name="Enabled", desc="Metal income is automatic and graduates as the game goes along."},
		}
	},
	{
		key    = 'basicincome',
		name   = 'Basic Metal Income Amount',
		desc   = 'Determines the amount of metal income you start with per second.',
		type   = 'number',
		section= 'resourcing',
		def    = 1,
		min    = 0,
		max    = 5,
		step   = 1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},
	{
		key    = 'basicincomeinterval',
		name   = 'Basic Metal Income Increase Interval',
		desc   = 'Determines how often your basic metal income is increased.',
		type   = 'number',
		section= 'resourcing',
		def    = 2.5,
		min    = 0.5,
		max    = 5,
		step   = 0.5,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},
	{
		key    = 'basicincomeincrease',
		name   = 'Basic Metal Income Increase',
		desc   = 'Your basic metal income increases every <Basic Metal Income Increase Interval> (1 minutes, is the default) by this amount until it hits <Maximum Basic Income> income.',
		type   = 'number',
		section= 'resourcing',
		def    = 1,
		min    = 0,
		max    = 5,
		step   = 1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},
	{
		key    = 'maxbasicincome',
		name   = 'Maximum Basic Metal Income',
		desc   = 'Determines the maximum amount that your basic metal income level can reach.',
		type   = 'number',
		section= 'resourcing',
		def    = 10,
		min    = 0,
		max    = 30,
		step   = 1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},

	{
		key    = 'supplyoptions',
		name   = 'Supply Options',
		desc   = 'Allows you to set options that effect Supply',
		type   = 'section',
	},
	{
		key    = 'supplycap',
		name   = 'Maximum Army Supply',
		desc   = 'Determines the maximum army supply that is allowed.',
		type   = 'number',
		section= 'supplyoptions',
		def    = 999,
		min    = 50,
		max    = 999,
		step   = 25,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},
	{
		key    = 'intrinsicsupply',
		name   = 'Intrinsic Army Supply',
		desc   = 'How much supply is available from the beginning of the game without needing supply depots?',
		type   = 'number',
		section= 'supplyoptions',
		def    = 10,
		min    = 10,
		max    = 400,
		step   = 1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},
	
	{
		key    = 'mexcost',
		name   = 'Metal Extractor Costs',
		desc   = 'Allows you to set the cost of Metal Extractors',
		type   = 'section',
	},
	{
		key    = 'metalextractorcostateran',
		name   = 'Ateran Metal Extractor Cost',
		desc   = 'How much metal does an Ateran Metal Extractor cost?',
		type   = 'number',
		section= 'mexcost',
		def    = 50,
		min    = 1,
		max    = 500,
		step   = 1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},
	{
		key    = 'metalextractorcostzaal',
		name   = 'Zaal Metal Extractor Cost',
		desc   = 'How much metal does an Zaal Metal Extractor cost?',
		type   = 'number',
		section= 'mexcost',
		def    = 65,
		min    = 1,
		max    = 500,
		step   = 1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},
	
-- Gameplay Options	
	{
		key    = 'gameplayoptions',
		name   = 'Gameplay Options',
		desc   = 'Various gameplay options that will change how the game is played.',
		type   = 'section',
	},
	{
		key    = 'unithealthmodifier',
		name   = 'Unit Health Modifier',
		desc   = 'This acts as a percentage of base unit health. Setting to 200 would double unit hitpoints.',
		type   = 'number',
		section= 'gameplayoptions',
		def    = 100,
		min    = 1,
		max    = 2000,
		step   = 1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},
	{
		key="deathmode",
		name="Game End Mode",
		desc="What it takes to eliminate a team",
		type="list",
		def="com",
		section="gameplayoptions",
		items={
			{key="neverend", name="None", desc="Teams are never eliminated"},
			{key="com", name="Kill all enemy Overseers", desc="When a team has no Overseers left, it loses"},
			{key="killall", name="Kill everything", desc="Every last unit must be eliminated, no exceptions!"},
		}
	},
	{
		key    = "shareddynamicalliancevictory",
		name   = "Dynamic Alliance Victory?",
		desc   = "Should dynamic alliance teams share in a victory, or should they be forced to turn on one another?",
		type   = "bool",
		def    = true,
		section= "gameplayoptions",
    },
	{
		key    = 'unitheat',
		name   = 'Unit Heat Amount',
		desc   = 'How much heat does each unit generate when it moves through an area?',
		type   = 'number',
		section= 'gameplayoptions',
		def    = 42,
		min    = 0,
		max    = 100,
		step   = 1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},

-- Chickens
	{
		key 	= 'chicken_defense_options',
		name 	= 'Corruptors',
		desc 	= 'Various gameplay options that will change how Corruptor Defense is played.',
		type 	= 'section',
	},
	{
		key="chicken_difficulty",
		name="Difficulty",
		desc="Corruptor difficulty",
		type="list",
		def="normal",
		section="chicken_defense_options",
		items={
			-- {key="veryeasy", name="Very Easy", desc="Very Easy"},
			-- {key="easy", name="Easy", desc="Easy"},
			{key="normal", name="Normal", desc="Normal"},
			{key="hard", name="Hard", desc="Hard"},
			{key="veryhard", name="Very Hard", desc="Very Hard"},
			{key="insane", name="Insane", desc="Insane"},
			{key="epic", name="Epic", desc="Epic"},
			{key="unbeatable", name="Unbeatable", desc="Unbeatable"},

			{key="survival", name="Endless", desc="Endless Mode"}
		}
	},
	{
		key="chicken_chickenstart",
		name="Burrow Placement",
		desc="Control where burrows spawn",
		type="list",
		def="initialbox",
		section="chicken_defense_options",
		items={
			--{key="anywhere", name="Anywhere", desc="Burrows can spawn anywhere"},
			{key="avoid", name="Avoid Players", desc="Burrows do not spawn on player units"},
			{key="initialbox", name="Initial Start Box", desc="First wave spawns in chicken start box, following burrows avoid players"},
			{key="alwaysbox", name="Always Start Box", desc="Burrows always spawn in chicken start box"},
		}
	},
	{
		key    = "chicken_queentime",
		name   = "Boss Arrival Time (Maximum)",
		desc   = "",
		type   = "number",
		def    = 40,
		min    = 1,
		max    = 120,
		step   = 1,
		section= "chicken_defense_options",
	},
	{
		key    = "chicken_maxchicken",
		name   = "Corruptor Limit",
		desc   = "Maximum number of Corruptors on map.",
		type   = "number",
		def    = 300,
		min    = 50,
		max    = 5000,
		step   = 25,
		section= "chicken_defense_options",
		hidden = true,
	},
	{
		key    = "chicken_spawncountmult",
		name   = "Corruptor Spawn Multiplier",
		desc   = "How many times more Corruptors spawn than normal.",
		type   = "number",
		def    = 1,
		min    = 1,
		max    = 20,
		step   = 1,
		section= "chicken_defense_options",
	},
	{
		key    = "chicken_swarmmode",
		name   = "Swarm Mode",
		desc   = "10 times bigger waves that spawn 10 times less often",
		type   = "bool",
		def    = false,
		section= "chicken_defense_options",
	},
	{
		key    = "chicken_graceperiod",
		name   = "Grace Period (Minutes)",
		desc   = "Time before Corruptors become active.",
		type   = "number",
		def    = 5,
		min    = 1,
		max    = 20,
		step   = 1,
		section= "chicken_defense_options",
	},
	{
		key    = "chicken_queenanger",
		name   = "Does killing burrow make the boss angry?",
		desc   = "If players kill the burrows, will the Boss come sooner?",
		type   = "bool",
		def    = true,
		section= "chicken_defense_options",
		hidden = true,
	},

}

return options