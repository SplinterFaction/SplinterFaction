--------------------------------------------------------------------------------
--  Rank tracks: the four per-match tracks and their rank thresholds.
--
--  Read by game_rank_tracks.lua (synced counting) and gui_bastion_ranks.lua
--  (the HUD). Ranks are cosmetic: nothing in the game reads them.
--
--  Each track has five ranks. A team is at rank N once its value reaches
--  thresholds[N]; rank 0 is "nothing yet". Thresholds roughly double so the
--  first rank comes in the opening minutes and the fifth is a real feat.
--  Tune from recorded games (sfrec) rather than by feel: a typical 25-minute
--  game should hand out eight to twelve rank-ups across the four tracks.
--------------------------------------------------------------------------------

return {
	-- how often the synced side publishes values to the HUD (frames)
	publishPeriod = 15,

	-- Economy: income is sampled every sampleFrames and averaged over
	-- sustainWindow samples, so a brief spike does not rank anyone up.
	economy = {
		sampleFrames  = 30,  -- one sample a second
		sustainWindow = 10,  -- ten seconds of income must hold
		energyWeight  = 0.05, -- one metal of income counts as this much energy
	},

	tracks = {
		{
			id     = "combat",
			name   = "Combat",
			unit   = "metal",            -- how the HUD words "x to next"
			desc   = "Metal value of enemy units destroyed",
			thresholds = {300, 900, 2400, 5600, 12000},
			titles = {"Skirmisher", "Raider", "Vanguard", "Warlord", "Annihilator"},
		},
		{
			id     = "economy",
			name   = "Economy",
			unit   = "income",
			desc   = "Sustained income, metal and weighted energy",
			thresholds = {8, 16, 32, 60, 110},
			titles = {"Prospector", "Tycoon", "Magnate", "Baron", "Sovereign"},
		},
		{
			id     = "industry",
			name   = "Industry",
			unit   = "metal",
			desc   = "Metal value of your own production",
			thresholds = {500, 1500, 4000, 9000, 18000},
			titles = {"Machinist", "Foreman", "Fabricator", "Foundry Master", "Warmaker"},
		},
		{
			id     = "territory",
			name   = "Territory",
			unit   = "extractors",
			desc   = "Metal extractors held",
			thresholds = {3, 6, 10, 15, 22},
			titles = {"Scout", "Claimant", "Holdfast", "Occupier", "Dominion"},
		},
	},
}
