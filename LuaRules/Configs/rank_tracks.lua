--------------------------------------------------------------------------------
--  Rank tracks: the four per-match tracks and their rank thresholds.
--
--  Read by game_rank_tracks.lua (synced counting) and gui_bastion_ranks.lua
--  (the HUD). Ranks are cosmetic: nothing in the game reads them.
--
--  Each track has five ranks. A team is at rank N once its value reaches
--  thresholds[N]; rank 0 is "nothing yet". Thresholds roughly double so the
--  first rank comes in the opening minutes and the fifth is a real feat.
--  Tuned from recorded games (sfrec). Reference points, Altored Divide, Oct
--  2026: a low-economy T1 game held ~50 M/s and 5 extractors and built ~57k
--  metal in 21 minutes (Economy II, Territory II, Industry IV-V); the
--  AdaptiveAI on the same team reached 1400 M/s, 25 extractors and 300k
--  built (V on all three). The replay of the same game put the player at 75k
--  metal destroyed (Combat V at 16 minutes), the AIs at 36k to 117k.
--------------------------------------------------------------------------------

return {
	-- how often the synced side publishes values to the HUD (frames)
	publishPeriod = 15,

	-- Economy: income is sampled every sampleFrames and averaged over
	-- sustainWindow samples, so a brief spike does not rank anyone up.
	economy = {
		sampleFrames  = 30,  -- one sample a second
		sustainWindow = 10,  -- ten seconds of income must hold
		energyWeight  = 0.02, -- energy income counts this much; SF energy runs in the thousands
	},

	-- Units whose metal cost is this or more are not counted anywhere: lootboxes,
	-- scanner probes and drop pods carry a 518,181,504 sentinel cost.
	maxCountedCost = 500000,

	-- Team upgrades (game_team_upgrades.lua) get a card too, though no place in
	-- the strip: the HUD watches the level params that gadget mirrors. The
	-- multipliers are repeated here only for the card's wording; the gadget's
	-- table is the one that matters.
	upgrades = {
		{
			id     = "weapons",
			name   = "Weapons",
			param  = "upgrade_weapons_level",
			effect = "weapon damage",
			mults  = {1.15, 1.30, 1.50, 1.65, 1.80, 2.00},
			titles = {"Calibrated", "Hardened", "Overcharged", "Lethal", "Devastating", "Annihilating"},
		},
		{
			id     = "armor",
			name   = "Armor",
			param  = "upgrade_armor_level",
			effect = "hit points",
			mults  = {1.15, 1.30, 1.50, 1.65, 1.80, 2.00},
			titles = {"Plated", "Reinforced", "Hardened", "Fortified", "Bulwark", "Impregnable"},
		},
	},

	-- End-of-game awards, handed out by game_rank_tracks.lua when the game is
	-- over and shown by the Awards tab of the end graph. Two kinds:
	--   player   one per team slot (a commander: human or AI). Every player
	--            gets at least one: the awards are drafted in this order, the
	--            best team taking each, and whoever is left empty-handed gets
	--            their best remaining award.
	--   alliance one per ally team, only when some alliance has two or more
	--            players; otherwise these fall into the player draft.
	-- stat names the per-team figure the gadget keeps; better says which way
	-- wins; min is the least a team needs for the award to be given at all;
	-- unit is how the HUD words the figure. winnersOnly: only the winning
	-- alliance can take it.
	awards = {
		{ id = "warlord",      kind = "player",   name = "Warlord",       stat = "combat",     better = "max", min = 1,   unit = "metal",   emblem = "combat",
		  desc = "Most enemy metal destroyed" },
		{ id = "industrialist", kind = "player",  name = "Industrialist", stat = "industry",   better = "max", min = 1,   unit = "metal",   emblem = "industry",
		  desc = "Most metal built" },
		{ id = "magnate",      kind = "player",   name = "Magnate",       stat = "economy",    better = "max", min = 1,   unit = "income",  emblem = "economy",
		  desc = "Highest sustained income" },
		{ id = "landgrab",     kind = "player",   name = "Landgrab",      stat = "territory",  better = "max", min = 1,   unit = "extractors", emblem = "territory",
		  desc = "Most extractors held" },
		{ id = "comeback",     kind = "alliance", name = "Comeback",      stat = "comeback",   better = "max", min = 0.15, unit = "share", emblem = "comeback", winnersOnly = true,
		  desc = "Biggest recovery in army strength" },
		{ id = "firstblood",   kind = "alliance", name = "First Blood",   stat = "firstkill",  better = "min", unit = "time",  emblem = "firstblood",
		  desc = "The first kill of the game" },
		{ id = "efficient",    kind = "player",   name = "Efficient",     stat = "efficiency", better = "max", min = 1.0, unit = "ratio", emblem = "efficient",
		  desc = "Best kill to loss ratio" },
		{ id = "juggernaut",   kind = "player",   name = "Juggernaut",    stat = "biggestkill", better = "max", min = 1, unit = "metal", emblem = "juggernaut",
		  desc = "The largest unit destroyed" },
		{ id = "fortress",     kind = "alliance", name = "Fortress",      stat = "damagetaken", better = "max", min = 1, unit = "damage", emblem = "armor", aliveOnly = true,
		  desc = "Most damage taken and still standing" },
		{ id = "armsdealer",   kind = "player",   name = "Arms Dealer",   stat = "weapons",    better = "max", min = 1,   unit = "level",   emblem = "weapons",
		  desc = "Highest weapons upgrade, first to reach it" },
		{ id = "ironclad",     kind = "player",   name = "Ironclad",      stat = "armor",      better = "max", min = 1,   unit = "level",   emblem = "armor",
		  desc = "Highest armor upgrade, first to reach it" },
		{ id = "combinedarms", kind = "alliance", name = "Combined Arms", stat = "unittypes",  better = "max", min = 2,   unit = "types",   emblem = "industry",
		  desc = "Most different unit types fielded" },
		{ id = "lockstep",     kind = "alliance", name = "Lockstep",      stat = "lockstep",   better = "max", min = 0.3, unit = "ratio", emblem = "economy", needsPartners = true,
		  desc = "Closest-matched economies within an alliance" },
		{ id = "assemblyline", kind = "player",   name = "Assembly Line", stat = "unitsbuilt", better = "max", min = 1,   unit = "units",   emblem = "industry",
		  desc = "Most units built" },
		{ id = "survivor",     kind = "player",   name = "Survivor",      stat = "survived",   better = "max", min = 1,   unit = "time",    emblem = "armor",
		  desc = "Held out the longest after the first loss" },
		{ id = "bloodbath",    kind = "player",   name = "Bloodbath",     stat = "lost",       better = "max", min = 1,   unit = "metal",   emblem = "combat",
		  desc = "Most metal thrown into the fight" },
	},

	tracks = {
		{
			id     = "combat",
			name   = "Combat",
			unit   = "metal",            -- how the HUD words "x to next"
			desc   = "Metal value of enemy units destroyed",
			thresholds = {750, 2500, 7000, 20000, 50000},
			titles = {"Skirmisher", "Raider", "Vanguard", "Warlord", "Annihilator"},
		},
		{
			id     = "economy",
			name   = "Economy",
			unit   = "income",
			desc   = "Sustained income, metal and weighted energy",
			thresholds = {20, 45, 100, 250, 600},
			titles = {"Prospector", "Tycoon", "Magnate", "Baron", "Sovereign"},
		},
		{
			id     = "industry",
			name   = "Industry",
			unit   = "metal",
			desc   = "Metal value of your own production",
			thresholds = {1000, 3000, 8000, 20000, 50000},
			titles = {"Machinist", "Foreman", "Fabricator", "Foundry Master", "Warmaker"},
		},
		{
			id     = "territory",
			name   = "Territory",
			unit   = "extractors",
			desc   = "Metal extractors held",
			-- Maps differ: 40 spots on Altored Divide, 120 on Flats and Forests.
			-- So the ranks are fractions of a fair share (the map's metal spots
			-- divided by the number of teams); 40 spots and 4 teams give
			-- 3/4/6/9/14, 120 spots give 8/12/18/27/42. thresholds is the fallback when the spot
			-- count is unknown.
			shareFractions = {0.25, 0.4, 0.6, 0.9, 1.4},
			thresholds = {3, 4, 6, 9, 14},
			titles = {"Scout", "Claimant", "Holdfast", "Occupier", "Dominion"},
		},
	},
}
