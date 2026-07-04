--------------------------------------------------------------------------------
--
--  file:    scanner_probe.lua  (unitdef)
--  brief:   Invisible, unselectable, 5-second LOS ward spawned by the
--           Scanner Sweep gadget (game_scanner_sweep.lua). Grants normal
--           ground LOS in an 800 radius, exactly as if a unit stood there.
--
--           NOTE: this is deliberately a standalone def, NOT a faction
--           basedef wrapper -- it belongs to the game system, not to Kala
--           or Loz, and pulling faction identity vars into it would be
--           noise. If you'd rather keep the two-layer convention anyway,
--           it folds into a basedef trivially.
--
--           TODO(model): point `objectname` at ANY small model that already
--           ships with the game (the gadget calls SetUnitNoDraw immediately,
--           so it is never rendered). A 3-4 poly placeholder is ideal.
--
--------------------------------------------------------------------------------

return {
	scanner_probe = {
		name              = "Scanner Sweep",
		description       = "Temporary reconnaissance ward",
		objectname        = "emine.s3o",   -- TODO: any tiny existing model
		script            = "",                    -- no anim script needed

		-- Identity / bookkeeping
		unitname              = "scannerprobe",
		category          = "NOWEAPON NOTLAND",     -- keep out of targeting categories you use
		customparams = {
			is_dummy   = 1,     -- SimpleAI / stats / victory logic: skip me
			dontcount  = 1,     -- game-end unit counting: skip me
			nomorph    = 1,     -- just in case morph ever scans all units
		},

		-- The entire point:
		sightdistance     = 800,
		airsightdistance  = 800,    -- a unit standing there would see aircraft overhead
		losemitheight     = 500,     -- modest emit height, like a standing unit; raise for hilltop-style vision
		radardistance     = 0,
		sonardistance     = 0,

		-- Invisible to the enemy's sensors even if their LOS overlaps the spot
		stealth           = true,
		sonarstealth      = true,

		-- Inert physical presence
		maxdamage         = 50,
		blocking          = false,
		canmove           = false,
		canattack         = false,
		canpatrol         = false,
		canguard          = false,
		canrepeat         = false,
		cancloak          = false,
		upright           = true,
		floater           = true,   -- sit on the water surface, not the seafloor
		footprintx        = 1,
		footprintz        = 1,
		mass              = 10,
		idleautoheal      = 0,
		autoheal          = 0,

		-- Never built, never costs, never yields
		buildtime         = 1,
		buildcostmetal    = 0,
		buildcostenergy   = 0,
		metalstorage      = 0,
		energystorage     = 0,
		reclaimable       = false,
		capturable        = false,
		leavetracks       = false,

		-- No wreck
		corpse            = "",
		explodeas         = "",
		selfdestructas    = "",
	},
}
