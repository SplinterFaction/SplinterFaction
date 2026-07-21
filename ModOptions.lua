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
		def="t1",
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
		key    = 'resourceplacement',
		name   = 'Resource Locations',
		desc   = 'Allows players to define how resource locations are placed',
		type   = 'section',
	},
	{
		key    = 'placementalgo',
		name   = 'Placement Algorithm',
		desc   = 'This setting changes how resource locations are placed. Most are randomly generated, but there is also a setting for Map Defined.',
		type   = "list",
		def    = "stratified_random",
		section= "resourceplacement",
		items={
			{key="stratified_random", name="Stratified Random", desc="Stratified Random is a random placement algorithm that is designed to evenly and randomly place resource locations around the map."},
			{key="mirrored_group", name="Mirrored Quadrants", desc="Mirrored Quadrants will place resource locations in one quadrant, then mirror to an adjacent quadrant, then mirror the half so that you get a perfectly symmetrical resource map."},
			{key="map_defined", name="Map Defined", desc="Map Defined resource locations used the locations that were originally defined by the map maker."},
		}
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

	-- AI Options
	{
		key    = 'aioptions',
		name   = 'AI Opponent Options',
		desc   = 'Allows you to adjust AI settings',
		type   = 'section',
	},
	{
		key    = 'ai_neverstall',
		name   = 'NeverStall',
		desc   = 'Makes it so that the AI will never stall out on resources',
		type="list",
		def="enabled",
		section= "aioptions",
		items={
			{key="disabled", name="Disabled", desc="Clean, non cheating AI"},
			{key="enabled", name="Enabled", desc="Laughs in hardcore"},
		}
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
		key="autoteamcolors",
		name="Automatic Teamcolors",
		type="list",
		def="enabled",
		section="gameplayoptions",
		items={
			{key="enabled", name="Enabled"},
			{key="disabled", name="Disabled"},
		}
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

------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------

	--------------------------------------------------------------------------------
	-- Survival AI Options
	--------------------------------------------------------------------------------

	{
		key    = 'survivalaioptions',
		name   = 'Survival AI Options',
		desc   = 'Allows you to control at a granular level the individual options for the Survival AI',
		type   = 'section',
	},

	{
		key="survivalaidifficulty",
		name="Survival AI Difficulty",
		desc="How hard should the Survival AI be?",
		type="list",
		def="normal",
		section="survivalaioptions",
		items={
			{key="easy", name="Easy", desc="Half budget, gentler growth curve, and waves arrive 25% slower."},
			{key="normal", name="Normal", desc="Baseline budget, growth, and wave cadence."},
			{key="hard", name="Hard", desc="Double budget, steeper growth, and waves arrive 10% faster."},
			{key="impossibru", name="Impossibru", desc="Triple budget, explosive growth, waves 25% faster. I'm sure someone out there can beat it, but that person isn't you."},
		}
	},

	--------------------------------------------------------------------------------
	-- Pacing
	--------------------------------------------------------------------------------

	{
		key     = "survivalai_graceperiod",
		name    = "Grace Period (seconds)",
		desc    = "Calm before the first wave arrives, counted from the end of placement.",
		type    = "number",
		def     = 180,
		min     = 0,
		max     = 900,
		step    = 30,
		section = "survivalaioptions",
	},

	{
		key     = "survivalai_waveinterval",
		name    = "Wave Interval (seconds)",
		desc    = "Seconds between waves. Lower = relentless pressure.",
		type    = "number",
		def     = 60,
		min     = 15,
		max     = 300,
		step    = 5,
		section = "survivalaioptions",
	},

	{
		key     = "survivalai_t2minutes",
		name    = "Tech 2 Unlock (minutes)",
		desc    = "Minutes on the wave clock before Tech 2 units join the waves.",
		type    = "number",
		def     = 10,
		min     = 0,
		max     = 60,
		step    = 1,
		section = "survivalaioptions",
	},

	{
		key     = "survivalai_t3minutes",
		name    = "Tech 3 Unlock (minutes)",
		desc    = "Minutes on the wave clock before Tech 3 units join the waves.",
		type    = "number",
		def     = 20,
		min     = 0,
		max     = 90,
		step    = 1,
		section = "survivalaioptions",
	},

	--------------------------------------------------------------------------------
	-- Budget curve (the difficulty preset multiplies on top of these)
	--------------------------------------------------------------------------------

	{
		key     = "survivalai_basebudget",
		name    = "Base Wave Budget (metal)",
		desc    = "Metal value of wave 1, before the difficulty multiplier.",
		type    = "number",
		def     = 400,
		min     = 100,
		max     = 5000,
		step    = 50,
		section = "survivalaioptions",
	},

	{
		key     = "survivalai_lineargrowth",
		name    = "Linear Budget Growth",
		desc    = "Fraction of the base budget added per wave (0.30 = +30% of base each wave).",
		type    = "number",
		def     = 0.30,
		min     = 0,
		max     = 2,
		step    = 0.05,
		section = "survivalaioptions",
	},

	{
		key     = "survivalai_compoundgrowth",
		name    = "Compound Budget Growth",
		desc    = "Per-wave compounding multiplier (1.06 = +6% compounding). This is what makes the late game a problem.",
		type    = "number",
		def     = 1.06,
		min     = 1.0,
		max     = 1.25,
		step    = 0.01,
		section = "survivalaioptions",
	},

	{
		key     = "survivalai_maxwaveunits",
		name    = "Max Units Per Wave",
		desc    = "Hard cap on units in a single wave per survival team. Raise for late-game spectacle, lower for performance.",
		type    = "number",
		def     = 40,
		min     = 10,
		max     = 200,
		step    = 5,
		section = "survivalaioptions",
	},

	--------------------------------------------------------------------------------
	-- Beacons
	--------------------------------------------------------------------------------

	{
		key     = "survivalai_beaconwaves",
		name    = "Beacon Creep Interval (waves)",
		desc    = "A new beacon spawns after every Nth wave.",
		type    = "number",
		def     = 3,
		min     = 1,
		max     = 10,
		step    = 1,
		section = "survivalaioptions",
	},

	{
		key     = "survivalai_beaconbonus",
		name    = "Beacon Budget Bonus",
		desc    = "Extra wave budget per live beacon beyond the first (0.15 = +15% each). The cost of ignoring the creep.",
		type    = "number",
		def     = 0.15,
		min     = 0,
		max     = 1,
		step    = 0.05,
		section = "survivalaioptions",
	},

	{
		key     = "survivalai_beaconrp",
		name    = "Beacon Kill Reward (RP)",
		desc    = "Research points awarded to the team that destroys a beacon.",
		type    = "number",
		def     = 250,
		min     = 0,
		max     = 2000,
		step    = 50,
		section = "survivalaioptions",
	},

	{
		key     = "survivalai_retaliationdelay",
		name    = "Retaliation Delay (seconds)",
		desc    = "A destroyed beacon pulls the next wave to this many seconds away. Set at or above the wave interval to effectively disable retaliation.",
		type    = "number",
		def     = 5,
		min     = 0,
		max     = 300,
		step    = 1,
		section = "survivalaioptions",
	},

	{
		key     = "survivalai_creepmin",
		name    = "Beacon Creep Min Distance",
		desc    = "Minimum distance (elmos) a new beacon spawns from its source beacon.",
		type    = "number",
		def     = 900,
		min     = 200,
		max     = 4000,
		step    = 100,
		section = "survivalaioptions",
	},

	{
		key     = "survivalai_creepmax",
		name    = "Beacon Creep Max Distance",
		desc    = "Maximum distance (elmos) a new beacon spawns from its source beacon -- the leash.",
		type    = "number",
		def     = 3000,
		min     = 400,
		max     = 8000,
		step    = 100,
		section = "survivalaioptions",
	},

	--------------------------------------------------------------------------------
	-- Flavor
	--------------------------------------------------------------------------------

	{
		key     = "survivalai_factionpure",
		name    = "Faction-Pure Wave Chance",
		desc    = "Chance a wave draws from a single faction only (0 = always mixed, 1 = always pure).",
		type    = "number",
		def     = 0.25,
		min     = 0,
		max     = 1,
		step    = 0.05,
		section = "survivalaioptions",
	},

	--------------------------------------------------------------------------------
	-- Phase 4: network behavior
	--------------------------------------------------------------------------------

	{
		key     = "survivalai_specialchance",
		name    = "Special Beacon Chance",
		desc    = "Chance a newly crept beacon is specialized (shield / jammer / accelerator / forge) instead of standard.",
		type    = "number",
		def     = 0.6,
		min     = 0,
		max     = 1,
		step    = 0.05,
		section = "survivalaioptions",
	},

	{
		key     = "survivalai_agingminutes",
		name    = "Beacon Dig-In Time (minutes)",
		desc    = "Beacons that survive this long fortify with garrison turrets. 0 disables aging.",
		type    = "number",
		def     = 4,
		min     = 0,
		max     = 30,
		step    = 1,
		section = "survivalaioptions",
	},

	{
		key     = "survivalai_surgewaves",
		name    = "Surge Wave Interval",
		desc    = "Every Nth wave is a surge: double budget and a dramatic archetype, announced one wave in advance. 0 disables surges.",
		type    = "number",
		def     = 10,
		min     = 0,
		max     = 50,
		step    = 1,
		section = "survivalaioptions",
	},

------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------
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
}

return options