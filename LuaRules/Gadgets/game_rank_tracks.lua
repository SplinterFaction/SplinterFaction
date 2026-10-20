--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    game_rank_tracks.lua
--  brief:   Per-match rank tracks. Counts, for every team, four things the
--           game already produces in a steady stream (metal destroyed, income,
--           metal built, extractors held) and hands out cosmetic ranks as the
--           counts cross the thresholds in LuaRules/Configs/rank_tracks.lua.
--           Nothing in the game reads a rank: they exist so the HUD can
--           celebrate them (gui_bastion_ranks.lua).
--
--           Synced side: the counting, and the rank-up events. Values and
--           ranks are published as team rules params (allied-readable) so the
--           HUD can draw a progress strip without a message per frame.
--           Unsynced side: forwards a rank-up to LuaUI, only for a team the
--           local player may see.
--
--           At game over the same counts, plus a few kept only for this
--           (damage, losses, the first kill, army strength over time), become
--           the end-of-game awards listed in the config: one per player at
--           least, and alliance awards in team games. They are published as
--           game rules params (awards_count, awards_<i>_*) for the Awards tab
--           of the end graph, and the rank params are made public.
--
--  author:  SF
--  license: GNU GPL, v2 or later
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name    = "Rank Tracks",
		desc    = "Per-match cosmetic ranks: combat, economy, industry, territory",
		author  = "SF",
		date    = "2026-10-19",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true,
	}
end

local config = VFS.Include("LuaRules/Configs/rank_tracks.lua")
local TRACKS = config.tracks

-- team rules params, per track: rank_<id>_level and rank_<id>_value
local function LevelParam(track) return "rank_" .. track.id .. "_level" end
local function ValueParam(track) return "rank_" .. track.id .. "_value" end

--------------------------------------------------------------------------------
-- Unsynced: forward rank-ups to the HUD
--------------------------------------------------------------------------------

if not gadgetHandler:IsSyncedCode() then
	local spGetSpectatingState = Spring.GetSpectatingState
	local spGetMyTeamID        = Spring.GetMyTeamID
	local spAreTeamsAllied     = Spring.AreTeamsAllied

	-- the same visibility the rules params have: own team and allies, or
	-- everyone for a spectator
	local function MaySee(teamID)
		if spGetSpectatingState() then
			return true
		end
		local my = spGetMyTeamID()
		return teamID == my or spAreTeamsAllied(my, teamID) or spAreTeamsAllied(teamID, my)
	end

	local function OnRankUp(_, teamID, trackIndex, level, value)
		if MaySee(teamID) and Script.LuaUI("RankUpEvent") then
			Script.LuaUI.RankUpEvent(teamID, trackIndex, level, value)
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("rankUp", OnRankUp)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("rankUp")
	end

	return
end

--------------------------------------------------------------------------------
-- Synced: the counting
--------------------------------------------------------------------------------

local spGetTeamList       = Spring.GetTeamList
local spGetGaiaTeamID     = Spring.GetGaiaTeamID
local spGetTeamResources  = Spring.GetTeamResources
local spAreTeamsAllied    = Spring.AreTeamsAllied
local spSetTeamRulesParam = Spring.SetTeamRulesParam
local spGetGameFrame      = Spring.GetGameFrame

local floor = math.floor
local max   = math.max

local PARAM_OPTS = {allied = true}

local gaiaID = spGetGaiaTeamID()

local ECON          = config.economy
local SAMPLE_FRAMES = ECON.sampleFrames or 30
local SUSTAIN       = ECON.sustainWindow or 10
local ENERGY_WEIGHT = ECON.energyWeight or 0
local PUBLISH       = config.publishPeriod or 15

local TRACK_COMBAT, TRACK_ECONOMY, TRACK_INDUSTRY, TRACK_TERRITORY
for i, track in ipairs(TRACKS) do
	if track.id == "combat" then TRACK_COMBAT = i end
	if track.id == "economy" then TRACK_ECONOMY = i end
	if track.id == "industry" then TRACK_INDUSTRY = i end
	if track.id == "territory" then TRACK_TERRITORY = i end
end

-- per team: values[teamID][trackIndex], levels[teamID][trackIndex]
local values = {}
local levels = {}
-- per team: a ring of income samples, and the count of live extractors
local incomeSamples = {}
local extractors = {}

-- per team, for the awards: see Prepare
local stats = {}
-- per ally team: the smallest share of all army value it ever held
local minShare = {}
local ARMY_SAMPLE_FRAMES = 300 -- every ten seconds
local awardsGiven = false

-- unitDefID -> true for every metal extractor
local isExtractor = {}
for unitDefID, def in pairs(UnitDefs) do
	local cp = def.customParams or {}
	if (def.extractsMetal or 0) > 0 or cp.metal_extractor then
		isExtractor[unitDefID] = true
	end
end

-- unitDefID -> metal cost, so a kill does not look it up again. Units priced
-- above the sanity cap (lootboxes, probes, drop pods) count as nothing.
local MAX_COST = config.maxCountedCost or 500000
local metalCost = {}
for unitDefID, def in pairs(UnitDefs) do
	local cost = def.metalCost or 0
	if cost >= MAX_COST then
		cost = 0
		isExtractor[unitDefID] = nil
	end
	metalCost[unitDefID] = cost
end

local function IsPlayerTeam(teamID)
	return teamID and teamID ~= gaiaID
end

-- Territory thresholds follow the map: a fraction of the fair share of metal
-- spots per team. The spot generator publishes the count at its start, which
-- may be after this gadget's, so this runs at game start (and again on a
-- reload). The result is published for the HUD as rank_territory_t<rank>.
local territoryScaled = false
local function ScaleTerritory()
	if territoryScaled or not TRACK_TERRITORY then
		return
	end
	local track = TRACKS[TRACK_TERRITORY]
	local fractions = track.shareFractions
	local spots = (Spring.GetGameRulesParam("metalSpot_count"))
	if not spots then
		spots = GG.metalMakerSpots and #GG.metalMakerSpots or nil
	end
	if not spots or spots <= 0 or not fractions then
		return
	end
	local teams = 0
	for _, teamID in ipairs(spGetTeamList()) do
		if IsPlayerTeam(teamID) then
			teams = teams + 1
		end
	end
	local share = spots / max(1, teams)
	local thresholds = {}
	for i, fraction in ipairs(fractions) do
		local t = floor(fraction * share + 0.5)
		if i > 1 and t <= thresholds[i - 1] then
			t = thresholds[i - 1] + 1
		end
		thresholds[i] = max(1, t)
	end
	track.thresholds = thresholds
	for i, t in ipairs(thresholds) do
		Spring.SetGameRulesParam("rank_territory_t" .. i, t)
	end
	territoryScaled = true
end

local function Prepare(teamID)
	if values[teamID] then
		return
	end
	values[teamID] = {}
	levels[teamID] = {}
	for i = 1, #TRACKS do
		values[teamID][i] = 0
		levels[teamID][i] = 0
	end
	incomeSamples[teamID] = {}
	extractors[teamID] = 0
	stats[teamID] = {
		lost        = 0,     -- metal cost of own finished units destroyed
		damagetaken = 0,
		damagedealt = 0,
		firstkill   = nil,   -- frame of the first enemy kill
		biggestkill = 0,     -- metal cost of the largest unit destroyed
		biggestdef  = nil,
		unittypes   = {},    -- unitDefID -> true, every type finished
		unittypecount = 0,
		unitsbuilt  = 0,
		weapons     = 0, weaponsframe = nil,
		armor       = 0, armorframe = nil,
		alivevalue  = 0,     -- metal cost of finished units alive now
		diedframe   = nil,
	}
end

local function Publish(teamID)
	local v, l = values[teamID], levels[teamID]
	for i, track in ipairs(TRACKS) do
		spSetTeamRulesParam(teamID, LevelParam(track), l[i], PARAM_OPTS)
		spSetTeamRulesParam(teamID, ValueParam(track), floor(v[i]), PARAM_OPTS)
	end
end

-- Raises a team's value on one track and announces every rank it crosses.
-- Values never go down for the counting tracks; the economy and territory
-- tracks pass their current reading, and the stored value keeps the peak.
local function Report(teamID, trackIndex, newValue)
	local v, l = values[teamID], levels[teamID]
	if newValue <= v[trackIndex] then
		return
	end
	v[trackIndex] = newValue
	local thresholds = TRACKS[trackIndex].thresholds
	local level = l[trackIndex]
	while level < #thresholds and newValue >= thresholds[level + 1] do
		level = level + 1
		l[trackIndex] = level
		SendToUnsynced("rankUp", teamID, trackIndex, level, floor(newValue))
	end
end

local function Add(teamID, trackIndex, amount)
	if amount > 0 then
		Report(teamID, trackIndex, values[teamID][trackIndex] + amount)
	end
end

--------------------------------------------------------------------------------
-- events
--------------------------------------------------------------------------------

function gadget:Initialize()
	for _, teamID in ipairs(spGetTeamList()) do
		if IsPlayerTeam(teamID) then
			Prepare(teamID)
			Publish(teamID)
		end
	end
	if spGetGameFrame() > 0 then
		ScaleTerritory()
	end
	-- extractors already standing (a /luarules reload mid-game)
	if spGetGameFrame() > 0 then
		for _, unitID in ipairs(Spring.GetAllUnits()) do
			local unitDefID = Spring.GetUnitDefID(unitID)
			local teamID = Spring.GetUnitTeam(unitID)
			local _, _, _, _, build = Spring.GetUnitHealth(unitID)
			if isExtractor[unitDefID] and values[teamID] and build and build >= 1 then
				extractors[teamID] = extractors[teamID] + 1
			end
		end
	end
end

function gadget:GameStart()
	ScaleTerritory()
end

function gadget:UnitFinished(unitID, unitDefID, teamID)
	if not values[teamID] then
		return
	end
	local cost = metalCost[unitDefID] or 0
	if TRACK_INDUSTRY then
		Add(teamID, TRACK_INDUSTRY, cost)
	end
	if isExtractor[unitDefID] then
		extractors[teamID] = extractors[teamID] + 1
		if TRACK_TERRITORY then
			Report(teamID, TRACK_TERRITORY, extractors[teamID])
		end
	end
	local st = stats[teamID]
	st.unitsbuilt = st.unitsbuilt + 1
	st.alivevalue = st.alivevalue + cost
	if not st.unittypes[unitDefID] then
		st.unittypes[unitDefID] = true
		st.unittypecount = st.unittypecount + 1
	end
end

local function LoseExtractor(unitID, unitDefID, teamID)
	if isExtractor[unitDefID] and values[teamID] then
		local _, _, _, _, build = Spring.GetUnitHealth(unitID)
		if build and build >= 1 then
			extractors[teamID] = max(0, extractors[teamID] - 1)
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
	LoseExtractor(unitID, unitDefID, teamID)
	local cost = metalCost[unitDefID] or 0
	local victim = stats[teamID]
	if victim then
		local _, _, _, _, build = Spring.GetUnitHealth(unitID)
		if build and build >= 1 then
			victim.alivevalue = max(0, victim.alivevalue - cost)
			-- a loss is a finished unit of yours that an enemy destroyed
			if attackerTeamID and attackerTeamID ~= teamID and not spAreTeamsAllied(attackerTeamID, teamID) then
				victim.lost = victim.lost + cost
			end
		end
	end
	if not attackerTeamID or not values[attackerTeamID] then
		return
	end
	if attackerTeamID == teamID or teamID == gaiaID then
		return
	end
	if spAreTeamsAllied(attackerTeamID, teamID) then
		return
	end
	if TRACK_COMBAT then
		Add(attackerTeamID, TRACK_COMBAT, cost)
	end
	local st = stats[attackerTeamID]
	if not st.firstkill then
		st.firstkill = spGetGameFrame()
	end
	if cost > st.biggestkill then
		st.biggestkill = cost
		st.biggestdef = unitDefID
	end
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if paralyzer or not damage or damage <= 0 then
		return
	end
	local st = stats[unitTeam]
	if st then
		st.damagetaken = st.damagetaken + damage
	end
	if attackerTeam and attackerTeam ~= unitTeam and stats[attackerTeam] and not spAreTeamsAllied(attackerTeam, unitTeam) then
		stats[attackerTeam].damagedealt = stats[attackerTeam].damagedealt + damage
	end
end

function gadget:UnitGiven(unitID, unitDefID, newTeamID, oldTeamID)
	local cost = metalCost[unitDefID] or 0
	local _, _, _, _, build = Spring.GetUnitHealth(unitID)
	if build and build >= 1 then
		if stats[oldTeamID] then
			stats[oldTeamID].alivevalue = max(0, stats[oldTeamID].alivevalue - cost)
		end
		if stats[newTeamID] then
			stats[newTeamID].alivevalue = stats[newTeamID].alivevalue + cost
		end
	end
	LoseExtractor(unitID, unitDefID, oldTeamID)
	if isExtractor[unitDefID] and values[newTeamID] and build and build >= 1 then
		extractors[newTeamID] = extractors[newTeamID] + 1
		if TRACK_TERRITORY then
			Report(newTeamID, TRACK_TERRITORY, extractors[newTeamID])
		end
	end
end

function gadget:TeamDied(teamID)
	if stats[teamID] and not stats[teamID].diedframe then
		stats[teamID].diedframe = spGetGameFrame()
	end
end

-- army strength share per alliance, for the Comeback award
local function SampleArmy()
	local total = 0
	local byAlly = {}
	for teamID, st in pairs(stats) do
		local ally = select(6, Spring.GetTeamInfo(teamID, false))
		if ally then
			byAlly[ally] = (byAlly[ally] or 0) + st.alivevalue
			total = total + st.alivevalue
		end
	end
	if total <= 0 then
		return
	end
	for ally, value in pairs(byAlly) do
		local share = value / total
		if minShare[ally] == nil or share < minShare[ally] then
			minShare[ally] = share
		end
	end
end

local function PollUpgrades()
	local api = GG.TeamUpgrades
	if not api or not api.GetLevel then
		return
	end
	local n = spGetGameFrame()
	for teamID, st in pairs(stats) do
		local w = api.GetLevel(teamID, "weapons") or 0
		if w > st.weapons then
			st.weapons, st.weaponsframe = w, n
		end
		local a = api.GetLevel(teamID, "armor") or 0
		if a > st.armor then
			st.armor, st.armorframe = a, n
		end
	end
end

function gadget:GameFrame(n)
	if n % ARMY_SAMPLE_FRAMES == 0 then
		SampleArmy()
		PollUpgrades()
	end
	if TRACK_ECONOMY and n % SAMPLE_FRAMES == 0 then
		local slot = (n / SAMPLE_FRAMES) % SUSTAIN + 1
		for teamID, samples in pairs(incomeSamples) do
			local _, _, _, mIncome = spGetTeamResources(teamID, "metal")
			local _, _, _, eIncome = spGetTeamResources(teamID, "energy")
			samples[slot] = (mIncome or 0) + (eIncome or 0) * ENERGY_WEIGHT
			samples.count = (samples.count or 0) + 1
			if samples.count >= SUSTAIN then
				local lowest = samples[1]
				for i = 2, SUSTAIN do
					if samples[i] < lowest then
						lowest = samples[i]
					end
				end
				-- sustained income: the worst second of the window
				Report(teamID, TRACK_ECONOMY, lowest)
			end
		end
	end
	if n % PUBLISH == 0 then
		for teamID in pairs(values) do
			Publish(teamID)
		end
	end
end

--------------------------------------------------------------------------------
-- Awards, at game over
--------------------------------------------------------------------------------

local AWARDS = config.awards or {}

-- A team's figure for an award's stat, or nil when it has none. Alliance
-- awards are computed over all the alliance's teams by AllianceStat below.
local function TeamStat(teamID, name, gameFrame)
	local st = stats[teamID]
	local v = values[teamID]
	if name == "combat" then
		return TRACK_COMBAT and v[TRACK_COMBAT] or nil
	elseif name == "industry" then
		return TRACK_INDUSTRY and v[TRACK_INDUSTRY] or nil
	elseif name == "economy" then
		return TRACK_ECONOMY and v[TRACK_ECONOMY] or nil
	elseif name == "territory" then
		return TRACK_TERRITORY and v[TRACK_TERRITORY] or nil
	elseif name == "efficiency" then
		local killed = TRACK_COMBAT and v[TRACK_COMBAT] or 0
		if killed < 2000 then
			return nil -- too little fought to call it efficient
		end
		return killed / max(1, st.lost)
	elseif name == "biggestkill" then
		return st.biggestkill
	elseif name == "weapons" then
		return st.weapons
	elseif name == "armor" then
		return st.armor
	elseif name == "unitsbuilt" then
		return st.unitsbuilt
	elseif name == "lost" then
		return st.lost
	elseif name == "firstkill" then
		return st.firstkill
	elseif name == "damagetaken" then
		return st.damagetaken
	elseif name == "unittypes" then
		return st.unittypecount
	elseif name == "survived" then
		return st.diedframe and (st.diedframe) or nil
	end
	return nil
end

-- the frame a team reached its figure, for tiebreaks (earlier wins)
local function TeamStatFrame(teamID, name)
	local st = stats[teamID]
	if name == "weapons" then return st.weaponsframe end
	if name == "armor" then return st.armorframe end
	return nil
end

local function TeamsOfAlliance(ally)
	local list = {}
	for teamID in pairs(stats) do
		if select(6, Spring.GetTeamInfo(teamID, false)) == ally then
			list[#list + 1] = teamID
		end
	end
	return list
end

local function IsTeamAlive(teamID)
	return not stats[teamID].diedframe
end

local function AllianceStat(ally, name, gameFrame, winners)
	local members = TeamsOfAlliance(ally)
	if #members == 0 then
		return nil
	end
	if name == "comeback" then
		if not winners[ally] then
			return nil
		end
		local low = minShare[ally]
		if low == nil then
			return nil
		end
		-- final share, from the last sample
		local total, mine = 0, 0
		for teamID, st in pairs(stats) do
			total = total + st.alivevalue
			if select(6, Spring.GetTeamInfo(teamID, false)) == ally then
				mine = mine + st.alivevalue
			end
		end
		local final = total > 0 and mine / total or 1
		return final - low
	elseif name == "firstkill" then
		local first
		for _, teamID in ipairs(members) do
			local f = stats[teamID].firstkill
			if f and (not first or f < first) then
				first = f
			end
		end
		return first
	elseif name == "damagetaken" then
		local sum, anyAlive = 0, false
		for _, teamID in ipairs(members) do
			if IsTeamAlive(teamID) then
				anyAlive = true
				sum = sum + stats[teamID].damagetaken
			end
		end
		return anyAlive and sum or nil
	elseif name == "unittypes" then
		local seen, count = {}, 0
		for _, teamID in ipairs(members) do
			for unitDefID in pairs(stats[teamID].unittypes) do
				if not seen[unitDefID] then
					seen[unitDefID] = true
					count = count + 1
				end
			end
		end
		return count
	elseif name == "lockstep" then
		if #members < 2 or not TRACK_ECONOMY then
			return nil
		end
		local lo, hi
		for _, teamID in ipairs(members) do
			local e = values[teamID][TRACK_ECONOMY]
			lo = (lo == nil or e < lo) and e or lo
			hi = (hi == nil or e > hi) and e or hi
		end
		if not hi or hi <= 0 then
			return nil
		end
		return lo / hi -- 1 means everyone earned the same
	end
	return nil
end

-- Picks the best of the candidates for an award. candidates: a list of
-- {id = teamID or allyID, value = figure, frame = tiebreak frame}
local function Best(award, candidates)
	local best
	for _, c in ipairs(candidates) do
		if c.value ~= nil and (not award.min or c.value >= award.min) then
			if not best then
				best = c
			else
				local better
				if award.better == "min" then
					better = c.value < best.value
				else
					better = c.value > best.value
				end
				if c.value == best.value and c.frame and best.frame then
					better = c.frame < best.frame
				end
				if better then
					best = c
				end
			end
		end
	end
	return best
end

-- Where a team places for an award, 1 being best; nil when it does not
-- qualify. Used to give an empty-handed player their best remaining award.
local function Placing(award, candidates, id)
	local mine
	for _, c in ipairs(candidates) do
		if c.id == id then
			mine = c
		end
	end
	if not mine or mine.value == nil or (award.min and mine.value < award.min) then
		return nil
	end
	local place = 1
	for _, c in ipairs(candidates) do
		if c.id ~= id and c.value ~= nil and (not award.min or c.value >= award.min) then
			local ahead
			if award.better == "min" then
				ahead = c.value < mine.value
			else
				ahead = c.value > mine.value
			end
			if ahead then
				place = place + 1
			end
		end
	end
	return place
end

local function GiveAwards(winningAllyTeams)
	if awardsGiven then
		return
	end
	awardsGiven = true
	local gameFrame = spGetGameFrame()

	local winners = {}
	for _, ally in ipairs(winningAllyTeams or {}) do
		winners[ally] = true
	end

	-- the players and alliances in the game
	local teams = {}
	for teamID in pairs(stats) do
		teams[#teams + 1] = teamID
	end
	table.sort(teams)
	local alliances, allianceSize = {}, {}
	for _, teamID in ipairs(teams) do
		local ally = select(6, Spring.GetTeamInfo(teamID, false))
		if ally then
			if not allianceSize[ally] then
				alliances[#alliances + 1] = ally
				allianceSize[ally] = 0
			end
			allianceSize[ally] = allianceSize[ally] + 1
		end
	end
	table.sort(alliances)
	local teamGame = false
	for _, n in pairs(allianceSize) do
		if n >= 2 then
			teamGame = true
		end
	end

	-- every award's candidates, in config order
	local playerAwards, allianceAwards = {}, {}
	for _, award in ipairs(AWARDS) do
		local asAlliance = award.kind == "alliance" and teamGame
		if asAlliance then
			if not award.needsPartners or teamGame then
				local candidates = {}
				for _, ally in ipairs(alliances) do
					candidates[#candidates + 1] = {id = ally, value = AllianceStat(ally, award.stat, gameFrame, winners)}
				end
				allianceAwards[#allianceAwards + 1] = {award = award, candidates = candidates}
			end
		elseif not award.needsPartners then
			local candidates = {}
			for _, teamID in ipairs(teams) do
				local value
				if award.kind == "alliance" then
					-- an alliance award in a game without alliances: the team's own
					local ally = select(6, Spring.GetTeamInfo(teamID, false))
					if award.winnersOnly and not winners[ally] then
						value = nil
					elseif award.stat == "comeback" then
						value = AllianceStat(ally, "comeback", gameFrame, winners)
					else
						value = TeamStat(teamID, award.stat, gameFrame)
						if award.aliveOnly and not IsTeamAlive(teamID) then
							value = nil
						end
					end
				else
					value = TeamStat(teamID, award.stat, gameFrame)
				end
				candidates[#candidates + 1] = {id = teamID, value = value, frame = TeamStatFrame(teamID, award.stat)}
			end
			playerAwards[#playerAwards + 1] = {award = award, candidates = candidates}
		end
	end

	-- the draft: each award to its best; then everyone left empty gets their
	-- best remaining placing; alliance awards go to their best, no fallback
	local given = {}
	local order = {}
	for i, award in ipairs(AWARDS) do
		order[award.id] = i
	end
	local function Give(entry, winner, kind)
		given[#given + 1] = {award = entry.award, kind = kind, id = winner.id, value = winner.value}
		entry.taken = true
	end
	local has = {}
	for _, entry in ipairs(playerAwards) do
		local best = Best(entry.award, entry.candidates)
		if best then
			Give(entry, best, "player")
			has[best.id] = (has[best.id] or 0) + 1
		end
	end
	for _, teamID in ipairs(teams) do
		if not has[teamID] then
			local bestEntry, bestPlace, bestCandidate
			for _, entry in ipairs(playerAwards) do
				if not entry.taken then
					local place = Placing(entry.award, entry.candidates, teamID)
					if place and (not bestPlace or place < bestPlace) then
						bestEntry, bestPlace = entry, place
						for _, c in ipairs(entry.candidates) do
							if c.id == teamID then bestCandidate = c end
						end
					end
				end
			end
			if bestEntry then
				Give(bestEntry, bestCandidate, "player")
				has[teamID] = 1
			end
		end
	end
	for _, entry in ipairs(allianceAwards) do
		local best = Best(entry.award, entry.candidates)
		if best then
			Give(entry, best, "alliance")
		end
	end

	-- publish: alliance awards first, then in config order
	table.sort(given, function(a, b)
		if a.kind ~= b.kind then
			return a.kind == "alliance"
		end
		return order[a.award.id] < order[b.award.id]
	end)
	local i = 0
	for _, g in ipairs(given) do
		i = i + 1
		local prefix = "awards_" .. i .. "_"
		Spring.SetGameRulesParam(prefix .. "id", g.award.id)
		Spring.SetGameRulesParam(prefix .. "kind", g.kind)
		Spring.SetGameRulesParam(prefix .. "who", g.id)
		local value = g.value
		if g.award.stat == "biggestkill" then
			local st = stats[g.id]
			if st and st.biggestdef and UnitDefs[st.biggestdef] then
				Spring.SetGameRulesParam(prefix .. "unit", UnitDefs[st.biggestdef].name)
			end
		end
		Spring.SetGameRulesParam(prefix .. "value", type(value) == "number" and value or 0)
	end
	Spring.SetGameRulesParam("awards_count", i)

	-- the ranks become everyone's business
	for _, teamID in ipairs(teams) do
		local v, l = values[teamID], levels[teamID]
		for t, track in ipairs(TRACKS) do
			spSetTeamRulesParam(teamID, LevelParam(track), l[t], {public = true})
			spSetTeamRulesParam(teamID, ValueParam(track), floor(v[t]), {public = true})
		end
	end
end

function gadget:GameOver(winningAllyTeams)
	SampleArmy()
	PollUpgrades()
	GiveAwards(winningAllyTeams)
end
