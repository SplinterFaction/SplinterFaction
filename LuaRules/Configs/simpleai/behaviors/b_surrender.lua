--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    luarules/configs/simpleai/behaviors/b_surrender.lua
--  brief:   Surrender behavior for the SimpleAI gadget. When a side's game is
--           obviously lost, each AI team on it says "gg" and self-destructs
--           instead of making the winner grind out the last commander.
--
--           "Obviously lost" is judged for the whole SIDE (ally team), never
--           for one team, and only when every living team on the side is an
--           AI, so an AI never walks out on a human ally. All of these must
--           hold, continuously, for GG_HOLD:
--             * the game is at least GG_MIN_TIME old;
--             * the side's army is worth at most GG_ARMY_RATIO of the
--               strongest enemy side's army, and that enemy army is a real
--               one (at least GG_MIN_ENEMY metal);
--             * the side cannot rebuild: it has no factories left, or its
--               metal income is at most GG_INCOME_RATIO of that enemy's.
--           Armies are counted as the metal value of mobile combat units,
--           air included, commanders excluded.
--
--           Set GG_ENABLED = false to turn the whole thing off.
--
--           Events go to the game recording (tag "gg") when the recorder
--           feed gadget is present.
--
--  license: GNU GPL, v2 or later
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return function(ctx, lib, cfg, services)

	--------------------------------------------------------------------------
	-- Tunables (owned by this behavior)
	--------------------------------------------------------------------------
	local GG_ENABLED      = true
	local GG_MIN_TIME     = 14400   -- frames (8 min): no surrender before this
	-- (0.35, raised from 0.20: a recorded 52-minute game was plainly lost from about 48:00,
	-- with a third of the enemy's army and a fifth of its income, and never reached 0.20
	-- before the last commander died at 51:59.)
	local GG_ARMY_RATIO   = 0.35    -- side army at most this x the strongest enemy side's army
	local GG_MIN_ENEMY    = 5000    -- ...and that enemy army is worth at least this much metal
	local GG_INCOME_RATIO = 0.30    -- side metal income at most this x that enemy's (or no factories at all)
	local GG_HOLD         = 2700    -- frames (90s) the verdict must hold without a break
	local GG_RECOUNT      = 150     -- frames between recounts of the sides
	local GG_MESSAGE      = "gg"

	local IsCombat    = ctx.IsCombat    or {}
	local IsCommander = ctx.IsCommander or {}
	local IsFactory   = ctx.IsFactory   or {}

	local B = { name = "surrender", order = 90 }

	local sides      = nil      -- [allyTeamID] = { army, income, factories, teams = {...}, allAI }
	local sidesFrame = -99999
	local lostSince  = {}       -- [allyTeamID] = frame the verdict first held
	local done       = {}       -- [teamID] = true once it has said gg

	local valueOf = {}
	local function UnitValue(unitDefID)
		local v = valueOf[unitDefID]
		if not v then
			local ud = UnitDefs[unitDefID]
			v = (ud and ud.metalCost) or 0
			valueOf[unitDefID] = v
		end
		return v
	end

	local function Recount(frame)
		local gaia = Spring.GetGaiaTeamID()
		local out = {}
		local teamList = Spring.GetTeamList()
		for i = 1, #teamList do
			local t = teamList[i]
			if t ~= gaia then
				local _, _, isDead, isAiTeam, _, ally = Spring.GetTeamInfo(t, false)
				local tUnits = Spring.GetTeamUnits(t)
				if not isDead and #tUnits > 0 then
					local s = out[ally]
					if not s then s = { army = 0, income = 0, factories = 0, teams = {}, allAI = true }; out[ally] = s end
					s.teams[#s.teams + 1] = t
					local luaAI = Spring.GetTeamLuaAI(t)
					if not (isAiTeam or (luaAI and luaAI ~= "")) then s.allAI = false end
					for k = 1, #tUnits do
						local d = Spring.GetUnitDefID(tUnits[k])
						if d then
							if IsFactory[d] then
								s.factories = s.factories + 1
							elseif IsCombat[d] and not IsCommander[d] then
								s.army = s.army + UnitValue(d)
							end
						end
					end
					local _, _, _, income = Spring.GetTeamResources(t, "metal")
					s.income = s.income + (income or 0)
				end
			end
		end
		sides, sidesFrame = out, frame
	end

	-- Is this side's game obviously lost right now?
	local function Lost(allyTeamID, frame)
		local mine = sides[allyTeamID]
		if not mine or not mine.allAI then return false end
		local foe
		for ally, s in pairs(sides) do
			if ally ~= allyTeamID and (not foe or s.army > foe.army
					or (s.army == foe.army and ally < foe.ally)) then
				foe = s
				foe.ally = ally
			end
		end
		if not foe or foe.army < GG_MIN_ENEMY then return false end
		if mine.army > foe.army * GG_ARMY_RATIO then return false end
		return mine.factories == 0 or mine.income <= foe.income * GG_INCOME_RATIO
	end

	function B.TeamTick(tick)
		if not GG_ENABLED then return end
		local frame      = tick.frame
		local teamID     = tick.teamID
		local allyTeamID = tick.allyTeamID
		if done[teamID] or frame < GG_MIN_TIME then return end

		if (frame - sidesFrame) >= GG_RECOUNT then
			Recount(frame)
			-- the verdict clock for every side is kept here, once per recount
			for ally in pairs(sides) do
				if Lost(ally, frame) then
					lostSince[ally] = lostSince[ally] or frame
				else
					lostSince[ally] = nil
				end
			end
		end

		local since = lostSince[allyTeamID]
		if not since or (frame - since) < GG_HOLD then return end

		-- It is over. Say so, and go.
		done[teamID] = true
		local name = Spring.GetTeamLuaAI(teamID)
		if not name or name == "" then name = "AI" end
		Spring.SendMessage(("<%s, team %d> %s"):format(name, teamID, GG_MESSAGE))
		local mine = sides[allyTeamID]
		if GG.Recorder and GG.Recorder.Log then
			GG.Recorder.Log(teamID, "gg", ("army=%d;factories=%d;income=%d"):format(
				mine and mine.army or 0, mine and mine.factories or 0, mine and mine.income or 0))
		end
		local units = tick.units
		if units and #units > 0 then
			Spring.GiveOrderToUnitArray(units, CMD.SELFD, {}, 0)
		end
	end

	return B
end
