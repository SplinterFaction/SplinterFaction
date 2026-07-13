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
--           Owns ctx state: ctx.pacing.lastUpgrade.
--           Reads: ctx.techLevel, ctx.intel.underAttack.
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
	local TECH_FOR_LEVEL = { 2, 3, 4 }

	-- Keep in sync with b_economy's BOOST_RP_RESERVE: RP held back for the
	-- commander's next morph. Waived at tech 4 (nothing left to morph into).
	local MORPH_RP_RESERVE  = 150

	-- Min frames between purchases per team (~15s at 30Hz). Eager, but not a
	-- single-tick bank dump: morphs and boosts get windows in between.
	local UPGRADE_COOLDOWN  = 450

	--------------------------------------------------------------------------
	-- Shared state / config
	--------------------------------------------------------------------------
	local TeamTechLevel     = ctx.techLevel
	local SimpleUnderAttack = ctx.intel.underAttack

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
	local function TryBuy(teamID, track, tech, reserve)
		local lvl      = GG.TeamUpgrades.GetLevel(teamID, track)
		local needTech = TECH_FOR_LEVEL[lvl + 1]
		if not needTech or tech < needTech then return false end   -- maxed / tech-gated

		local cost = GG.TeamUpgrades.GetNextCost(teamID, track)
		if not cost then return false end                          -- maxed (belt & braces)
		if not GG.Research.CanAfford(teamID, cost + reserve) then return false end

		return GG.TeamUpgrades.Purchase(teamID, track) == true
	end

	--------------------------------------------------------------------------
	-- Per-team tick: at most one purchase per cooldown window.
	--------------------------------------------------------------------------
	function B.TeamTick(tick)
		if not (GG.TeamUpgrades and GG.Research) then return end

		local n      = tick.frame
		local teamID = tick.teamID

		if (n - (SimpleLastUpgrade[teamID] or 0)) < UPGRADE_COOLDOWN then return end

		local tech    = TeamTechLevel[teamID] or 1
		local reserve = (tech >= 4) and 0 or MORPH_RP_RESERVE

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

		if TryBuy(teamID, first, tech, reserve)
				or TryBuy(teamID, second, tech, reserve) then
			SimpleLastUpgrade[teamID] = n
		end
	end

	return B
end
