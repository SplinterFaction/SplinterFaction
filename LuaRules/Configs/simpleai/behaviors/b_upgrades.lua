--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    luarules/configs/simpleai/behaviors/b_upgrades.lua
--  brief:   Team-upgrade policy for the SimpleAI gadget. Spends Research
--           Points on the levelled Weapons / Armor upgrades exposed by
--           game_team_upgrades.lua (GG.TeamUpgrades).
--
--           Priority doctrine: TECHING FIRST, UPGRADES A CLOSE SECOND.
--           Encoded two ways, both of which must clear before RP is spent:
--             1. Tech gates -- upgrade level L is only purchasable once the
--                team's tech level has reached L+1 (level 1 at tech 2,
--                level 2 at tech 3, level 3 at tech 4). The AI therefore
--                never delays a morph to buy an upgrade it "outranks".
--                Levels 4 to 6 open at tech 4 as well: nothing is left to
--                morph into, so RP has nowhere better to go.
--             2. Morph reserve -- the same 150 RP the Build Boost policy
--                holds back for the commander's next morph is respected
--                here too, and waived once tech is maxed at 4.
--           Once a gate opens, purchases are EAGER: one buy per short
--           cooldown, so a flush bank converts into upgrades quickly while
--           still leaving windows for morphs and boosts to interleave.
--
--           Track choice keeps the two levels balanced (buy the lower one
--           first, weapons on ties); while the base is under attack the
--           preference flips to armor, since +effective-HP pays immediately
--           on units already taking fire.
--
--           COMMANDER LOST doctrine: teching up is the commander morphing,
--           so a team without one is locked at its tech level. Both rules
--           above exist to protect the morph, and neither applies any more:
--           tech gates and the morph reserve are dropped and the cooldown is
--           cut, so every Research Point goes into weapons and armor, all
--           six levels. A fully upgraded tier 1 army can hold off weaker
--           tier 2, which is the only way such a team stays in the game.
--
--           Owns ctx state: ctx.pacing.lastUpgrade.
--           Reads: ctx.techLevel, ctx.intel.underAttack, ctx.comm.lost.
--           Owns no units (TeamTick only; no unitFilter/UnitTick).
--
--  usage:   VFS.Include(path)(ctx, lib, cfg) -> handler table
--
--  license: GNU GPL, v2 or later
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return function(ctx, lib, cfg)

	--------------------------------------------------------------------------
	-- Tunables (owned by this behavior)
	--------------------------------------------------------------------------
	-- Buying upgrade level L requires team tech >= TECH_FOR_LEVEL[L].
	-- This is the "teching comes first" rule: each upgrade tier unlocks one
	-- morph behind the tech curve, so RP always flows to the morph first.
	local TECH_FOR_LEVEL = { 2, 3, 4, 4, 4, 4 }

	-- Keep in sync with b_economy's BOOST_RP_RESERVE: RP held back for the
	-- commander's next morph. Waived at tech 4 (nothing left to morph into).
	local MORPH_RP_RESERVE  = 150

	-- Min frames between purchases per team (~15s at 30Hz). Eager, but not a
	-- single-tick bank dump: morphs and boosts get windows in between.
	local UPGRADE_COOLDOWN  = 450

	-- Commander lost: min frames between purchases (~5s). The difficulty
	-- knob may speed this up but never slows it below stock.
	local COMM_LOST_COOLDOWN = 150

	--------------------------------------------------------------------------
	-- Shared state / config
	--------------------------------------------------------------------------
	local TeamTechLevel     = ctx.techLevel
	local SimpleUnderAttack = ctx.intel.underAttack
	local CommLost          = ctx.comm and ctx.comm.lost or {}
	local trace             = ctx.trace or {}

	-- Self-registering ctx slot (core declares pacing; this behavior owns
	-- the lastUpgrade key inside it).
	ctx.pacing.lastUpgrade  = ctx.pacing.lastUpgrade or {}
	local SimpleLastUpgrade = ctx.pacing.lastUpgrade

	local B = { name = "upgrades", order = 35 }

	function B.TeamInit(teamID)
		SimpleLastUpgrade[teamID] = 0
	end

	--------------------------------------------------------------------------
	-- Try to buy the next level of one track. Returns true only on an
	-- actual successful purchase.
	--------------------------------------------------------------------------
	local function TryBuy(teamID, track, tech, reserve, ungated)
		local lvl      = GG.TeamUpgrades.GetLevel(teamID, track)
		if not ungated then
			local needTech = TECH_FOR_LEVEL[lvl + 1]
			if not needTech or tech < needTech then return false end   -- maxed / tech-gated
		end

		local cost = GG.TeamUpgrades.GetNextCost(teamID, track)
		if not cost then return false end                          -- maxed (belt & braces)
		if not GG.Research.CanAfford(teamID, cost + reserve) then return false end

		if GG.TeamUpgrades.Purchase(teamID, track) == true then
			local t = trace[teamID]   -- decision trace: up.weapons / up.armor
			if t then t["up." .. track] = (t["up." .. track] or 0) + 1 end
			return true
		end
		return false
	end

	--------------------------------------------------------------------------
	-- Per-team tick: at most one purchase per cooldown window.
	--------------------------------------------------------------------------
	function B.TeamTick(tick)
		if not (GG.TeamUpgrades and GG.Research) then return end

		local n      = tick.frame
		local teamID = tick.teamID

		-- Adaptive cadence: low difficulty buys upgrades far more lazily
		-- (mult up to 3.0), high difficulty slightly faster (0.7). nil knobs
		-- (plain SimpleAI) -> stock cooldown.
		local K    = tick.knobs
		local mult = K and K.upgradeCdMult or 1
		-- Commander lost: no morph left to protect (see header).
		local lost = CommLost[teamID] == true
		local cd
		if lost then
			cd = COMM_LOST_COOLDOWN * math.min(mult, 1)
		else
			cd = UPGRADE_COOLDOWN * mult
		end
		if (n - (SimpleLastUpgrade[teamID] or 0)) < cd then return end

		local tech    = TeamTechLevel[teamID] or 1
		local reserve = (tech >= 4 or lost) and 0 or MORPH_RP_RESERVE

		-- Track preference: under attack -> armor first (immediate survival
		-- value); otherwise keep the two tracks level-balanced, buying the
		-- lower one first and breaking ties toward weapons. Whatever comes
		-- first may still be tech-gated one level above the other track, in
		-- which case the second candidate gets its chance the same tick.
		local first, second
		if SimpleUnderAttack[teamID] then
			first, second = "armor", "weapons"
		else
			local wl = GG.TeamUpgrades.GetLevel(teamID, "weapons")
			local al = GG.TeamUpgrades.GetLevel(teamID, "armor")
			if al < wl then
				first, second = "armor", "weapons"
			else
				first, second = "weapons", "armor"
			end
		end

		if TryBuy(teamID, first, tech, reserve, lost)
				or TryBuy(teamID, second, tech, reserve, lost) then
			SimpleLastUpgrade[teamID] = n
		end
	end

	return B
end
