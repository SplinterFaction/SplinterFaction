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
		key    		= 'fixedallies',
		name   		= 'Disabled dynamic alliances',
		desc   		= 'Disables the possibility of players to dynamically change alliances ingame',
		type   		= 'bool',
		def    		= false,
		section		= "restrictions",
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
		key    = 'allowmexesinwater',
		name   = 'Allow metal spots to be placed in water?',
		desc   = 'Should metal spots be placed in water? Sometimes turning this off can be beneficial if the water on map does damage',
		type="list",
		def="enabled",
		section= "resourcing",
		items={
			{key="disabled", name="Disabled", desc="Disallow metal spots from being placed in water."},
			{key="enabled", name="Enabled", desc="Allow metal spots to be placed in water."},
		}
	},
	{
		key    = 'allowgeosinwater',
		name   = 'Allow geo spots to be placed in water?',
		desc   = 'Should geo spots be placed in water? Generally you want geos to only spawn on land.',
		type="list",
		def="disabled",
		section= "resourcing",
		items={
			{key="disabled", name="Disabled", desc="Disallow geo spots from being placed in water."},
			{key="enabled", name="Enabled", desc="Allow geo spots to be placed in water."},
		}
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
		def    = 10000,
		min    = 50,
		max    = 10000,
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
	{
		key="map_waterlevel",
		name="Water Level",
		desc=" <0 = Decrease water level, >0 = Increase water level",
		type="number",
		section="gameplayoptions",
		def    = 0,
		min    = -10000,
		max    = 10000,
		step   = 1,
	},


	{
		key="ruins",
		name="Ruins",
		type="list",
		def="scav_only",
		section="gameplayoptions",
		items={
			{key="enabled", name="Enabled"},
			{key="scav_only", name="Enabled for Scavengers only"},
			{key="disabled", name="Disabled"},
		}
	},

	{
		key="ruins_density",
		name="Ruins: Density",
		type="list",
		def="normal",
		section="gameplayoptions",
		items={
			{key="veryrare", name="Very Rare"},
			{key="rarer", name="Rare"},
			{key="normal", name="Normal"},
			{key="dense", name="Dense"},
			{key="verydense", name="Very Dense"},
		}
	},

	{
		key    = 'ruins_only_t1',
		name   = 'Ruins: Only T1',
		type   = 'bool',
		def    = false,
		section= "gameplayoptions",
	},

	{
		key    = 'ruins_civilian_disable',
		name   = 'Ruins: Disable Civilian (Not Implemented Yet)',
		type   = 'bool',
		def    = false,
		section= "gameplayoptions",
		hidden = true,
	},

	{
		key="lootboxes",
		name="Lootboxes",
		type="list",
		def="chicken_only",
		section="gameplayoptions",
		items={
			{key="enabled", name="Enabled"},
			{key="chicken_only", name="Enabled for Corruptors only"},
			{key="disabled", name="Disabled"},
		}
	},

	{
		key="lootboxes_density",
		name="Lootboxes: Density",
		type="list",
		def="normal",
		section="gameplayoptions",
		items={
			{key="veryrare", name="Very Rare"},
			{key="rarer", name="Rare"},
			{key="normal", name="Normal"},
			{key="dense", name="Dense"},
			{key="verydense", name="Very Dense"},
		}
	},

	-- Control Victory Options
	{
		key    = 'controlvictoryoptions',
		name   = 'Control Victory Options',
		desc   = 'Allows you to control at a granular level the individual options for Control Point Victory',
		type   = 'section',
	},
	{
		key="scoremode",
		name="Scoring Mode (Control Victory Points)",
		desc="Defines how the game is played",
		type="list",
		def="disabled",
		section="controlvictoryoptions",
		items={
			{key="disabled", name="Disabled", desc="Disable Control Points as a victory condition."},
			{key="countdown", name="Countdown", desc="A Control Point decreases all opponents' scores, zero means defeat."},
			{key="tugofwar", name="Tug of War", desc="A Control Point steals enemy score, zero means defeat."},
			{key="domination", name="Domination", desc="Holding all Control Points will grant 1000 score, first to reach the score limit wins."},
		}
	},
	{
		key    = 'limitscore',
		name   = 'Total Score',
		desc   = 'Total score amount available.',
		type   = 'number',
		section= 'controlvictoryoptions',
		def    = 3500,
		min    = 500,
		max    = 5000,
		step   = 1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},
	{
		key    = "numberofcontrolpoints",
		name   = "Set number of Control Points on the map",
		desc   = "Sets the number of control points on the map and scales the total score amount to match. Has no effect if Preset map configs are enabled.",
		section= "controlvictoryoptions",
		type="list",
		def="7",
		section= "controlvictoryoptions",
		items={
			{key="7", name="7", desc=""},
			{key="13", name="13", desc=""},
			{key="19", name="19", desc=""},
			{key="25", name="25", desc=""},
		}
	},
	{
		key    = "usemapconfig",
		name   = "Use preset map-specific Control Point locations?",
		desc   = "Should the control point config for this map be used instead of autogenerated control points?",
		type="list",
		def="disabled",
		section= "controlvictoryoptions",
		items={
			{key="disabled", name="Disabled", desc="This will tell the game to use autogenerated control points."},
			{key="enabled", name="Enabled", desc="This will tell the game to use preset map control points (Set via map config)."},
		}
	},
	{
		key    = 'captureradius',
		name   = 'Capture Radius',
		desc   = 'Radius around a point in which to capture it.',
		type   = 'number',
		section= 'controlvictoryoptions',
		def    = 500,
		min    = 100,
		max    = 1000,
		step   = 25,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},
	{
		key    = 'capturetime',
		name   = 'Capture Time',
		desc   = 'Time to capture a point.',
		type   = 'number',
		section= 'controlvictoryoptions',
		def    = 30,
		min    = 1,
		max    = 60,
		step   = 1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},
	{
		key    = 'capturebonus',
		name   = 'Capture Bonus',
		desc   = 'Percentage of how much faster capture takes place by adding more units.',
		type   = 'number',
		section= 'controlvictoryoptions',
		def    = 5,
		min    = 1,
		max    = 100,
		step   = 1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},
	{
		key    = 'decapspeed',
		name   = 'De-Cap Speed',
		desc   = 'Speed multiplier for neutralizing an enemy point.',
		type   = 'number',
		section= 'controlvictoryoptions',
		def    = 2,
		min    = 1,
		max    = 3,
		step   = 1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},
	{
		key    = 'starttime',
		name   = 'Start Time',
		desc   = 'Number of seconds until control points can be captured.',
		type   = 'number',
		section= 'controlvictoryoptions',
		def    = 180,
		min    = 0,
		max    = 300,
		step   = 1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},
	{
		key    = 'metalperpoint',
		name   = 'Metal given to each player per captured point',
		desc   = 'Each player on an allyteam that has captured a point will receive this amount of resources per point captured per second',
		type   = 'number',
		section= 'controlvictoryoptions',
		def    = 0,
		min    = 0,
		max    = 20,
		step   = 0.1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},
	{
		key    = 'energyperpoint',
		name   = 'Energy given to each player per captured point',
		desc   = 'Each player on an allyteam that has captured a point will receive this amount of resources per point captured per second',
		type   = 'number',
		section= 'controlvictoryoptions',
		def    = 0,
		min    = 0,
		max    = 20,
		step   = 0.1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},
	{
		key    = 'dominationscoretime',
		name   = 'Domination Score Time',
		desc   = 'Time needed holding all points to score in multi domination.',
		type   = 'number',
		section= 'controlvictoryoptions',
		def    = 30,
		min    = 1,
		max    = 60,
		step   = 1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},
	{
		key    = 'tugofwarmodifier',
		name   = 'Tug of War Modifier',
		desc   = 'The amount of score transfered between opponents when points are captured is multiplied by this amount.',
		type   = 'number',
		section= 'controlvictoryoptions',
		def    = 2,
		min    = 0,
		max    = 6,
		step   = 1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},
	{
		key    = 'dominationscore',
		name   = 'Score awarded for Domination',
		desc   = 'The amount of score awarded when you have scored a domination.',
		type   = 'number',
		section= 'controlvictoryoptions',
		def    = 1000,
		min    = 500,
		max    = 1000,
		step   = 1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},
	-- End Control Victory Options

	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Scavengers
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	{
		key		= "options_scavengers",
		name	= "Scavengers",
		desc	= "Gameplay options for Scavengers gamemode",
		type	= "section",
		hidden = true,
	},
	{
		key    = 'scavdifficulty',
		name   = 'Base Difficulty',
		desc   = 'Scavengers Base Difficulty Level',
		type   = 'list',
		section = 'options_scavengers',
		def  = "veryeasy",
		hidden = true,
		items={
			{key="noob", name="Noob", desc="Noob"},
			{key="veryeasy", name="Very Easy", desc="Very Easy"},
			{key="easy", name="Easy", desc="Easy"},
			{key="medium", name="Medium", desc="Medium"},
			{key="hard", name="Hard", desc="Hard"},
			{key="veryhard", name="Very Hard", desc="Very Hard"},
			{key="expert", name="Expert", desc="Expert"},
			{key="brutal", name="Brutal", desc="You'll die"},
		}
	},
	{
		key    = 'scavgraceperiod',
		name   = 'Grace Period',
		desc   = 'Time before Scavengers start sending attacks (in minutes).',
		type   = 'number',
		section= 'options_scavengers',
		def    = 5,
		min    = 1,
		max    = 20,
		step   = 1,
		hidden = true,
	},
	{
		key    = 'scavmaxtechlevel',
		name   = 'Maximum Scavengers Tech Level',
		desc   = 'Caps Scav tech level at specific point.',
		type   = 'list',
		section = 'options_scavengers',
		def  = "tech4",
		hidden = true,
		items={
			{key="tech4", name="Tech 4", desc="Tech 4"},
			{key="tech3", name="Tech 3", desc="Tech 3"},
			{key="tech2", name="Tech 2", desc="Tech 2"},
			{key="tech1", name="Tech 1", desc="Tech 1"},
		}
	},
	{
		key    = 'scavendless',
		name   = 'Endless Mode',
		desc   = 'Disables final boss fight, turning Scavengers into an endless survival mode',
		type   = 'bool',
		section = 'options_scavengers',
		def  = false,
		hidden = true,
	},
	{
		key    = 'scavtechcurve',
		name   = 'Game Lenght Multiplier',
		desc   = 'Higher than 1 - Longer, Lower than 1 - Shorter',
		type   = 'number',
		section= 'options_scavengers',
		def    = 1,
		min    = 0.01,
		max    = 10,
		step   = 0.01,
		hidden = true,
	},
	{
		key    = 'scavbosshealth',
		name   = 'Final Boss Health Multiplier',
		--desc   = '',
		type   = 'number',
		section= 'options_scavengers',
		def    = 1,
		min    = 0.01,
		max    = 10,
		step   = 0.01,
		hidden = true,
	},
	{
		key    = 'scavevents',
		name   = 'Random Events',
		desc   = 'Random Events System',
		type   = 'bool',
		section = 'options_scavengers',
		def  = true,
		hidden = true,
	},
	{
		key    = 'scaveventsamount',
		name   = 'Random Events Amount',
		desc   = 'Modifies frequency of random events',
		type   = 'list',
		section = 'options_scavengers',
		def  = "normal",
		hidden = true,
		items={
			{key="normal", name="Normal", desc="Normal"},
			{key="lower", name="Lower", desc="Halved"},
			{key="higher", name="Higher", desc="Doubled"},
		}
	},
	{
		key    = 'scavconstructors',
		name   = 'Scavenger Commanders',
		desc   = "When disabled, Scavengers won't build bases but will spawn more unit waves to balance it out.",
		type   = 'bool',
		section = 'options_scavengers',
		def  = true,
		hidden = true,
	},
	{
		key    = 'scavstartboxcloud',
		name   = 'Scavenger Startbox Cloud (Requires Startbox for Scavenger team)',
		desc   = "Spawns purple cloud in Scav startbox area, giving them safe space.",
		type   = 'bool',
		section = 'options_scavengers',
		def  = true,
		hidden = true,
	},
	{
		key    = 'scavspawnarea',
		name   = 'Scavenger Spawn Area (Requires Startbox for Scavenger team)',
		desc   = "When enabled, Scavengers will only spawn beacons within an area that starts in their startbox and grows up with time. When disabled, they will spawn freely around the map",
		type   = 'bool',
		section = 'options_scavengers',
		def  = true,
		hidden = true,
	},


	-- Hidden
	{
		key    = 'scavunitcountmultiplier',
		name   = 'Spawn Wave Size Multiplier',
		desc   = '',
		type   = 'number',
		section= 'options_scavengers',
		def    = 1,
		min    = 0.01,
		max    = 10,
		step   = 0.01,
		hidden = true,
	},
	{
		key    = 'scavunitspawnmultiplier',
		name   = 'Frequency of Spawn Waves Multiplier',
		desc   = '',
		type   = 'number',
		section= 'options_scavengers',
		def    = 1,
		min    = 0.01,
		max    = 10,
		step   = 0.01,
		hidden = true,
	},
	{
		key    = 'scavbuildspeedmultiplier',
		name   = 'Scavenger Build Speed Multiplier',
		desc   = '',
		type   = 'number',
		section= 'options_scavengers',
		def    = 1,
		min    = 0.01,
		max    = 10,
		step   = 0.01,
		hidden = true,
	},
	{
		key    = 'scavunitveterancymultiplier',
		name   = 'Scavenger Unit Experience Level Multiplier',
		desc   = 'Higher means stronger Scav units',
		type   = 'number',
		section= 'options_scavengers',
		def    = 1,
		min    = 0.01,
		max    = 10,
		step   = 0.01,
		hidden = true,
	},

	-- Chickens
	{
		key 	= 'chicken_defense_options',
		name 	= 'Corruptors',
		desc 	= 'Various gameplay options that will change how the Corruptors mode is played.',
		type 	= 'section',
	},
	{
		key="chicken_difficulty",
		name="Base Difficulty",
		desc="Corruptors difficulty",
		type="list",
		def="normal",
		section="chicken_defense_options",
		items={
			{key="veryeasy", name="Very Easy", desc="Very Easy"},
			{key="easy", name="Easy", desc="Easy"},
			{key="normal", name="Normal", desc="Normal"},
			{key="hard", name="Hard", desc="Hard"},
			{key="veryhard", name="Very Hard", desc="Very Hard"},
			{key="epic", name="Epic", desc="Epic"},

			--{key="survival", name="Endless", desc="Endless Mode"}
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
			{key="avoid", name="Avoid Players", desc="Burrows avoid player units"},
			{key="initialbox", name="Initial Start Box", desc="First wave spawns in chicken start box, following burrows avoid players"},
			{key="alwaysbox", name="Always Start Box", desc="Burrows always spawn in chicken start box"},
		}
	},
	{
		key    = "chicken_endless",
		name   = "Endless Mode",
		desc   = "When you kill the queen, the game doesn't end, but loops around at higher difficulty instead, infinitely.",
		type   = "bool",
		def    = false,
		section= "chicken_defense_options",
	},
	{
		key    = "chicken_queentimemult",
		name   = "Boss Anger Multiplier",
		desc   = "How quickly Boss Anger goes from 0 to 100% (Range: 0.1 - 3). The default timing for this is 20 minutes. A 'full' run would be 60 minutes (a value of 1)",
		type   = "number",
		def    = 1,
		min    = 0.1,
		max    = 3,
		step   = 0.1,
		section= "chicken_defense_options",
	},
	{
		key    = "chicken_spawncountmult",
		name   = "Unit Spawn Per Wave Multiplier",
		desc   = "How many times more corrupted units will spawn per wave. (Range: 1 - 5)",
		type   = "number",
		def    = 1,
		min    = 0.1,
		max    = 5,
		step   = 0.1,
		section= "chicken_defense_options",
	},
	{
		key    = "chicken_spawntimemult",
		name   = "Time Between Waves Multiplier",
		desc   = "How often new waves will spawn. (Range: 0.1 - 3)",
		type   = "number",
		def    = 1,
		min    = 0.1,
		max    = 3,
		step   = 0.1,
		section= "chicken_defense_options",
	},
	{
		key    = "chicken_graceperiodmult",
		name   = "Grace Period Time Multiplier",
		desc   = "Time before Corruptors become active (Range: 0.1 - 3). Default is 6 minutes.",
		type   = "number",
		def    = 1,
		min    = 0.1,
		max    = 3,
		step   = 0.1,
		section= "chicken_defense_options",
	},
}

return options