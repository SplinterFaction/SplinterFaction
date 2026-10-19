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
			thresholds = {3, 5, 8, 12, 18},
			titles = {"Scout", "Claimant", "Holdfast", "Occupier", "Dominion"},
		},
	},
}
