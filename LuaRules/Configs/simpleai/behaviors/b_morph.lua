--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    luarules/configs/simpleai/behaviors/b_morph.lua
--  brief:   Morph policy for the SimpleAI gadget: queues the commander's tech
--           morphs and the metal extractor upgrades through unit_morph's
--           team morph queue (CMD_MORPH_QUEUE).
--
--           Replaces the standalone gadgets ai_Commander_AutoUpgrade and
--           ai_MetalExtractor_AutoUpgrade with the same rules, so every
--           SimpleAI-family team (SimpleAI, AdaptiveAI, SimpleDefenderAI,
--           SimpleConstructorAI) morphs exactly as before:
--
--             Commander  Every 15 s after the first 15 s: a commander with a
--                        morph left is queued once the team holds that
--                        morph's research cost (150 / 300 / 600 / 1200 RP).
--                        Queued with shift, so it waits behind the
--                        commander's current orders.
--             Extractor  Every 60 s after the first 150 s: an extractor whose
--                        morph needs a tech level the team has already
--                        reached is queued. The morph cost (10 to 100 RP) is
--                        left to the morph queue, which waits for the RP.
--
--           Costs and tech requirements are read from gamedata/morph_defs.lua,
--           the same file unit_morph uses, so retuning a morph needs no
--           change here. Re-queueing a unit that is already queued or
--           morphing is a no-op in unit_morph.
--
--           Reads: ctx.techLevel (latest finished commander's techlevel).
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
	local CMD_MORPH_QUEUE   = 34410  -- unit_morph.lua

	local COMM_START_FRAME  = 450    -- 15 s
	local COMM_INTERVAL     = 450    -- 15 s
	local MEX_START_FRAME   = 4500   -- 150 s
	local MEX_INTERVAL      = 1800   -- 60 s

	--------------------------------------------------------------------------
	-- Morph data, per unitDefID: first (and only) morph option of each def.
	--------------------------------------------------------------------------
	local function TechStrToNum(s)
		local n = s and tonumber(string.match(s, "^tech(%d)$"))
		return n
	end

	local morphDefsByName = VFS.Include("gamedata/morph_defs.lua") or {}

	local commMorph = {}   -- [defID] = research cost
	local mexMorph  = {}   -- [defID] = tech level the morph requires
	for defID, ud in pairs(UnitDefs) do
		local md = morphDefsByName[ud.name]
		local opt = md and (md[1] or (md.into and md))
		if opt and opt.into and UnitDefNames[opt.into] then
			local cp = ud.customParams or {}
			if cp.unitrole == "Commander" then
				commMorph[defID] = tonumber(opt.research) or 0
			elseif cp.metal_extractor then
				mexMorph[defID] = TechStrToNum(opt.require) or 0
			end
		end
	end

	--------------------------------------------------------------------------
	-- Shared state / config
	--------------------------------------------------------------------------
	local TeamTechLevel = ctx.techLevel
	local trace         = ctx.trace or {}

	local nextComm = {}   -- [teamID] = frame of the next commander check
	local nextMex  = {}   -- [teamID] = frame of the next extractor check

	local spGetUnitDefID    = Spring.GetUnitDefID
	local spGiveOrderToUnit = Spring.GiveOrderToUnit

	local B = { name = "morph", order = 33 }

	function B.TeamInit(teamID)
		nextComm[teamID] = COMM_START_FRAME
		nextMex[teamID]  = MEX_START_FRAME
	end

	local function Count(teamID, key)
		local t = trace[teamID]   -- decision trace: morph.comm / morph.mex
		if t then t[key] = (t[key] or 0) + 1 end
	end

	local function CanAfford(teamID, cost)
		if cost <= 0 then return true end
		if GG.Research and GG.Research.CanAfford then
			return GG.Research.CanAfford(teamID, cost)
		end
		local rp = Spring.GetTeamRulesParam(teamID, "researchPoints")
		return (rp or 0) >= cost
	end

	--------------------------------------------------------------------------
	-- Per-team tick
	--------------------------------------------------------------------------
	function B.TeamTick(tick)
		local n      = tick.frame
		local teamID = tick.teamID
		local doComm = n >= (nextComm[teamID] or COMM_START_FRAME)
		local doMex  = n >= (nextMex[teamID] or MEX_START_FRAME)
		if not (doComm or doMex) then return end
		if doComm then nextComm[teamID] = n + COMM_INTERVAL end
		if doMex  then nextMex[teamID]  = n + MEX_INTERVAL end

		local teamTech = TeamTechLevel[teamID] or 0
		local units    = tick.units
		for i = 1, #units do
			local unitID = units[i]
			local defID  = spGetUnitDefID(unitID)
			if defID then
				local cost = doComm and commMorph[defID]
				if cost and CanAfford(teamID, cost) then
					spGiveOrderToUnit(unitID, CMD_MORPH_QUEUE, {}, {"shift"})
					Count(teamID, "morph.comm")
				end
				local needTech = doMex and mexMorph[defID]
				if needTech and needTech <= teamTech then
					spGiveOrderToUnit(unitID, CMD_MORPH_QUEUE, {}, {})
					Count(teamID, "morph.mex")
				end
			end
		end
	end

	return B
end
