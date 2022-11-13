local options= {
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
		def="scav_only",
		section="gameplayoptions",
		items={
			{key="enabled", name="Enabled"},
			{key="scav_only", name="Enabled for Scavengers only"},
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
	},
	{
		key    = 'scavdifficulty',
		name   = 'Base Difficulty',
		desc   = 'Scavengers Base Difficulty Level',
		type   = 'list',
		section = 'options_scavengers',
		def  = "veryeasy",
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
	},
	{
		key    = 'scavmaxtechlevel',
		name   = 'Maximum Scavengers Tech Level',
		desc   = 'Caps Scav tech level at specific point.',
		type   = 'list',
		section = 'options_scavengers',
		def  = "tech4",
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
	},
	{
		key    = 'scavevents',
		name   = 'Random Events',
		desc   = 'Random Events System',
		type   = 'bool',
		section = 'options_scavengers',
		def  = true,
	},
	{
		key    = 'scaveventsamount',
		name   = 'Random Events Amount',
		desc   = 'Modifies frequency of random events',
		type   = 'list',
		section = 'options_scavengers',
		def  = "normal",
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
	},
	{
		key    = 'scavstartboxcloud',
		name   = 'Scavenger Startbox Cloud (Requires Startbox for Scavenger team)',
		desc   = "Spawns purple cloud in Scav startbox area, giving them safe space.",
		type   = 'bool',
		section = 'options_scavengers',
		def  = true,
	},
	{
		key    = 'scavspawnarea',
		name   = 'Scavenger Spawn Area (Requires Startbox for Scavenger team)',
		desc   = "When enabled, Scavengers will only spawn beacons within an area that starts in their startbox and grows up with time. When disabled, they will spawn freely around the map",
		type   = 'bool',
		section = 'options_scavengers',
		def  = true,
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
}

return options