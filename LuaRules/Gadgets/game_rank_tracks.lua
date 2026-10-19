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

function gadget:UnitFinished(unitID, unitDefID, teamID)
	if not values[teamID] then
		return
	end
	if TRACK_INDUSTRY then
		Add(teamID, TRACK_INDUSTRY, metalCost[unitDefID] or 0)
	end
	if isExtractor[unitDefID] then
		extractors[teamID] = extractors[teamID] + 1
		if TRACK_TERRITORY then
			Report(teamID, TRACK_TERRITORY, extractors[teamID])
		end
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
	if not TRACK_COMBAT or not attackerTeamID or not values[attackerTeamID] then
		return
	end
	if attackerTeamID == teamID or teamID == gaiaID then
		return
	end
	if spAreTeamsAllied(attackerTeamID, teamID) then
		return
	end
	Add(attackerTeamID, TRACK_COMBAT, metalCost[unitDefID] or 0)
end

function gadget:UnitGiven(unitID, unitDefID, newTeamID, oldTeamID)
	LoseExtractor(unitID, unitDefID, oldTeamID)
	if isExtractor[unitDefID] and values[newTeamID] then
		local _, _, _, _, build = Spring.GetUnitHealth(unitID)
		if build and build >= 1 then
			extractors[newTeamID] = extractors[newTeamID] + 1
			if TRACK_TERRITORY then
				Report(newTeamID, TRACK_TERRITORY, extractors[newTeamID])
			end
		end
	end
end

function gadget:GameFrame(n)
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
