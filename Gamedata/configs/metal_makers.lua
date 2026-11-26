--------------------------------------------------------------------------------
--
--  The E->M converters' numbers, by unit name.
--
--  Read by LuaRules/Gadgets/game_metal_maker_output_scaler.lua, which sets
--  each converter's output and upkeep from them, and by Gamedata/alldefs_post.lua,
--  which writes the multiplier into the converter's description. Change a
--  number here and both follow.
--
--------------------------------------------------------------------------------

return {
	-- Tier multipliers: output is the map's metalSpot_value times this
	multipliers = {
		lozmetalextractor     = 1,
		fedmetalextractor     = 1,
	
		lozmetalextractor_up1 = 2,
		fedmetalextractor_up1 = 2,
	
		lozmetalextractor_up2 = 6.5,
		fedmetalextractor_up2 = 6.5,
	
		lozmetalextractor_up3 = 14,
		fedmetalextractor_up3 = 14,
	
		lozmetalextractor_up4 = 28,
		fedmetalextractor_up4 = 28,
	
		geometalmaker         = 35,
	},

	-- Base energy upkeep by tier (these are the numbers for metalSpot_value == 3)
	energyBase = {
		lozmetalextractor     = 12.5,
		fedmetalextractor     = 12.5,
	
		lozmetalextractor_up1 = 25,
		fedmetalextractor_up1 = 25,
	
		lozmetalextractor_up2 = 108,
		fedmetalextractor_up2 = 108,
	
		lozmetalextractor_up3 = 233,
		fedmetalextractor_up3 = 233,
	
		lozmetalextractor_up4 = 583,
		fedmetalextractor_up4 = 583,
	
		geometalmaker         = 700,
	},
}
