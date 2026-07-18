--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    game_spawn.lua
--  brief:   pre-game phase manager: faction choice → start position placement → spawn
--  author:  Tobi Vollebregt (original); extended for placement phase
--
--  Copyright (C) 2010.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name      = "Spawn",
		desc      = "Pre-game faction + placement phases, then spawns start units",
		author    = "Tobi Vollebregt",
		date      = "January, 2010",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (not gadgetHandler:IsSyncedCode()) then
	return false
end

--------------------------------------------------------------------------------
-- Faction data (unchanged)
--------------------------------------------------------------------------------

local aiStartUnits = {
	["fedcommander"] = {
		"fedcommander",
	},
	["lozcommander"] = {
		"lozcommander",
	},
}

local factionDefComms = {
	[0] = "fedcommander",
	[1] = "lozcommander",
}

local validStartComm = {
	[UnitDefNames["fedcommander"].id] = true,
	[UnitDefNames["lozcommander"].id] = true,
}

local ACCESS_LEVEL = {
	private = true,
}

-- Spot selection / confirmation is visible to teammates and spectators only.
local ALLIED = {
	allied = true,
}

--------------------------------------------------------------------------------
-- Phase constants
--------------------------------------------------------------------------------

-- Frames to wait per phase (30 fps × 30 s = 900)
local CHOICE_TIMEOUT_FRAMES    = 900
local PLACEMENT_TIMEOUT_FRAMES = 900

-- 3-second advance when all players confirm (30 fps × 3 s = 90)
local ADVANCE_FRAMES = 90

-- Message bytes: \138 = faction choice (existing), \139 = spot select, \140 = confirm
local FACTION_BYTE  = "\138"
local SELECT_BYTE   = "\139"
local CONFIRM_BYTE  = "\140"

--------------------------------------------------------------------------------
-- Phase state
--------------------------------------------------------------------------------

local phase             = "faction"   -- "faction" | "placement" | "done"
local factionDeadline   = CHOICE_TIMEOUT_FRAMES
local placementDeadline = 0

local humanTeams      = {}   -- teams with at least one human player
local allNonGaiaTeams = {}   -- every non-gaia team

local factionChosen         = {}    -- teamID → true once faction is locked
local pendingFactionAdvance = false -- set when all humans chose faction

local placementConfirmed      = {}    -- teamID → true once spot confirmed
local pendingPlacementAdvance = false -- set when all humans confirmed placement
local claimedSpots  = {}   -- spotIdx → teamID (first claim wins)
local selectedSpots = {}   -- teamID → spotIdx (tentative selection)
local confirmedSpots = {}  -- teamID → spotIdx (final confirmed selection)

local mapSpots     = {}    -- spotIdx (1-based) → {x, z, allyteam}
local usePlacement = false -- true when mapSpots has valid data
local isFFA        = false

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local modOptions = Spring.GetModOptions()

local function IsTeamAI(teamID)
	local players = Spring.GetPlayerList(teamID, true)
	return not players or #players == 0
end

-- Survival AI teams get a beacon instead of a commander (matches the
-- "SurvivalAI" entries in LuaAI.lua / ai_survival.lua by prefix).
local function IsSurvivalTeam(teamID)
	local luaAI = Spring.GetTeamLuaAI(teamID)
	return (luaAI ~= nil) and (luaAI ~= "") and (string.sub(luaAI, 1, 10) == "SurvivalAI")
end

--------------------------------------------------------------------------------
-- Map spot loading and partition
--------------------------------------------------------------------------------

local function LoadMapSpots()
	local ok, mi = pcall(VFS.Include, "mapinfo.lua", nil, VFS.MAP)
	if not ok or type(mi) ~= "table" or type(mi.teams) ~= "table" then
		Spring.Echo("[Game Spawn] mapinfo.lua unavailable or has no teams table — skipping placement phase")
		return
	end

	-- Collect spots (mapinfo is 0-indexed; field is `startpos`, lowercase p)
	local idx = 1
	for i = 0, 999 do
		local t = mi.teams[i]
		if not t then break end
		local sp = t.startpos
		if type(sp) == "table" and sp.x and sp.z then
			mapSpots[idx] = { x = sp.x, z = sp.z, allyteam = -1 }
			idx = idx + 1
		end
	end

	if idx == 1 then
		Spring.Echo("[Game Spawn] No usable start positions in mapinfo — skipping placement phase")
		return
	end

	local spotTotal = idx - 1
	Spring.Echo("[Game Spawn] Loaded " .. spotTotal .. " map spots from mapinfo")

	-- FFA detection: more than 2 allyteams where every allyteam has exactly 1 team.
	-- A 1v1 duel (2 allyteams × 1 player each) is NOT considered FFA.
	local gaiaTeamID = Spring.GetGaiaTeamID()
	local allyteamList = Spring.GetAllyTeamList()
	local atTeamCounts = {}
	for _, atID in ipairs(allyteamList) do
		local count = 0
		for _, tID in ipairs(Spring.GetTeamList(atID)) do
			if tID ~= gaiaTeamID then count = count + 1 end
		end
		if count > 0 then atTeamCounts[atID] = count end
	end

	local totalAT, multiAT = 0, 0
	for _, count in pairs(atTeamCounts) do
		totalAT = totalAT + 1
		if count > 1 then multiAT = multiAT + 1 end
	end
	isFFA = (totalAT > 2 and multiAT == 0)

	if isFFA then
		Spring.Echo("[Game Spawn] FFA detected — all spots open to all players")
		-- all spots remain with allyteam = -1
	else
		-- Balanced, spatially-coherent spot partition.
		--
		-- Goals:
		--   1. Each team's spots should form a contiguous cluster — no teammate
		--      stranded in the middle of the enemy side.
		--   2. The split should be balanced (equal spot counts where possible).
		--
		-- For the common 2-team case we project every spot onto the axis that
		-- separates the two sides (the line between the engine-assigned team
		-- centroids), sort along it, and cut at the quota boundary.  This yields
		-- a clean half-space split (left/right, top/bottom, or whatever diagonal
		-- the map intends) that is both contiguous and balanced.
		--
		-- For 3+ allyteams (rare in sided play) we fall back to a balanced greedy
		-- auction by centroid distance.

		-- Centroid per allyteam from engine-assigned start positions
		local centroids = {}
		for atID in pairs(atTeamCounts) do
			local cx, cz, n = 0, 0, 0
			for _, tID in ipairs(Spring.GetTeamList(atID)) do
				if tID ~= gaiaTeamID then
					local tx, _, tz = Spring.GetTeamStartPosition(tID)
					if tx and tx ~= 0 then
						cx = cx + tx; cz = cz + tz; n = n + 1
					end
				end
			end
			if n > 0 then
				centroids[atID] = { x = cx / n, z = cz / n }
			end
		end

		-- Deterministic ordered list of participating allyteams
		local allyteamIDs = {}
		for atID in pairs(centroids) do
			allyteamIDs[#allyteamIDs + 1] = atID
		end
		table.sort(allyteamIDs)

		local numAT  = #allyteamIDs
		local base   = math.floor(spotTotal / numAT)
		local extras = spotTotal - base * numAT   -- first `extras` teams get base+1

		local quota = {}
		for i, atID in ipairs(allyteamIDs) do
			quota[atID] = base + (i <= extras and 1 or 0)
		end

		Spring.Echo(string.format("[Game Spawn] Partition: %d spots across %d allyteams (quota ~%d each)",
		                          spotTotal, numAT, base))

		if numAT == 2 then
			-- ── Axis-projection split (contiguous + balanced) ─────────────────
			local at1, at2 = allyteamIDs[1], allyteamIDs[2]
			local c1, c2   = centroids[at1], centroids[at2]

			-- Separating axis = direction from c1 to c2
			local ax, az = c2.x - c1.x, c2.z - c1.z
			local axisLen2 = ax * ax + az * az

			-- Degenerate centroids (both teams start at ~same point): fall back to
			-- the principal axis of the spot cloud (direction of maximum spread).
			if axisLen2 < 1 then
				local mx, mz, n = 0, 0, 0
				for _, spot in pairs(mapSpots) do
					mx = mx + spot.x; mz = mz + spot.z; n = n + 1
				end
				mx, mz = mx / n, mz / n
				local sxx, sxz, szz = 0, 0, 0
				for _, spot in pairs(mapSpots) do
					local dx, dz = spot.x - mx, spot.z - mz
					sxx = sxx + dx * dx
					sxz = sxz + dx * dz
					szz = szz + dz * dz
				end
				-- Dominant eigenvector angle of the 2×2 covariance matrix
				local theta = 0.5 * math.atan2(2 * sxz, sxx - szz)
				ax, az = math.cos(theta), math.sin(theta)
				Spring.Echo("[Game Spawn] Centroids degenerate — using principal axis of spot cloud")
			end

			-- Project every spot onto the axis and sort ascending.  Spots with
			-- lower projection lie nearer c1's side.
			local ordered = {}
			for spotIdx, spot in pairs(mapSpots) do
				ordered[#ordered + 1] = { s = spotIdx, p = spot.x * ax + spot.z * az }
			end
			table.sort(ordered, function(a, b) return a.p < b.p end)

			-- First quota[at1] spots → at1, remainder → at2
			for rank, item in ipairs(ordered) do
				local owner = (rank <= quota[at1]) and at1 or at2
				mapSpots[item.s].allyteam = owner
			end

			Spring.Echo(string.format("[Game Spawn] Axis split: dir=(%.2f, %.2f)  at%d gets first %d spots",
			                          ax, az, at1, quota[at1]))
		else
			-- ── Balanced greedy auction (3+ allyteams) ────────────────────────
			local candidates = {}
			for spotIdx, spot in pairs(mapSpots) do
				for _, atID in ipairs(allyteamIDs) do
					local c  = centroids[atID]
					local dx = spot.x - c.x
					local dz = spot.z - c.z
					candidates[#candidates + 1] = { s = spotIdx, a = atID, d = dx*dx + dz*dz }
				end
			end
			table.sort(candidates, function(a, b) return a.d < b.d end)

			local assigned   = {}
			local teamCounts = {}
			for _, atID in ipairs(allyteamIDs) do teamCounts[atID] = 0 end

			for _, cand in ipairs(candidates) do
				if not assigned[cand.s] and teamCounts[cand.a] < quota[cand.a] then
					mapSpots[cand.s].allyteam = cand.a
					assigned[cand.s]          = true
					teamCounts[cand.a]        = teamCounts[cand.a] + 1
				end
			end

			for spotIdx in pairs(mapSpots) do
				if not assigned[spotIdx] then
					mapSpots[spotIdx].allyteam = allyteamIDs[1]
				end
			end
		end

		for i, spot in pairs(mapSpots) do
			Spring.Echo(string.format("[Game Spawn]   spot[%d] (%.0f, %.0f) → allyteam %d",
			                          i, spot.x, spot.z, spot.allyteam))
		end
	end

	-- Broadcast spot positions and side assignments for widget display.
	-- Claim state is NOT broadcast globally — each team tracks its own via
	-- team rules params with allied-only visibility (see AssignSpot).
	Spring.SetGameRulesParam("spotCount", spotTotal)
	Spring.SetGameRulesParam("isFFA", isFFA and 1 or 0)
	for i, spot in pairs(mapSpots) do
		Spring.SetGameRulesParam("spot_" .. i .. "_x",  spot.x)
		Spring.SetGameRulesParam("spot_" .. i .. "_z",  spot.z)
		Spring.SetGameRulesParam("spot_" .. i .. "_at", spot.allyteam)
	end

	usePlacement = true
end

--------------------------------------------------------------------------------
-- Spot selection helpers
--------------------------------------------------------------------------------

-- Pick the best unclaimed spot for a team: for sided games, the spot on their
-- side farthest from any enemy-side spot.  For FFA, farthest from any claimed spot.
local function AutoSelectSpot(teamID)
	local _, _, _, _, _, allyID = Spring.GetTeamInfo(teamID)
	local bestSpot, bestScore = nil, -1

	for i, spot in pairs(mapSpots) do
		local available = isFFA or (spot.allyteam == allyID)
		if available and not claimedSpots[i] then
			local score

			if isFFA then
				-- Score: min distance to any claimed spot (maximize separation)
				local minDist = math.huge
				local anyClaimed = false
				for j in pairs(claimedSpots) do
					anyClaimed = true
					local es = mapSpots[j]
					if es then
						local dx = spot.x - es.x
						local dz = spot.z - es.z
						local d  = dx * dx + dz * dz
						if d < minDist then minDist = d end
					end
				end
				score = anyClaimed and minDist or 0
			else
				-- Score: min squared distance to any enemy-side spot (maximize)
				local minDist = math.huge
				for j, eSpot in pairs(mapSpots) do
					if eSpot.allyteam ~= allyID then
						local dx = spot.x - eSpot.x
						local dz = spot.z - eSpot.z
						local d  = dx * dx + dz * dz
						if d < minDist then minDist = d end
					end
				end
				score = (minDist == math.huge) and 0 or minDist
			end

			if score > bestScore then
				bestScore = score
				bestSpot  = i
			end
		end
	end

	return bestSpot
end

-- Claim and confirm a spot for a team, updating all relevant state.
-- Visibility: selectedSpot / confirmedSpot / claimedSpot are allied-only so
-- opposing teams cannot read where their enemies are placing.
local function AssignSpot(teamID, spotIdx)
	-- Release any previous tentative claim by this team
	local prev = selectedSpots[teamID]
	if prev and claimedSpots[prev] == teamID then
		claimedSpots[prev] = nil
		Spring.SetTeamRulesParam(teamID, "claimedSpot", -1, ALLIED)
	end

	claimedSpots[spotIdx]  = teamID
	selectedSpots[teamID]  = spotIdx
	confirmedSpots[teamID] = spotIdx

	Spring.SetTeamRulesParam(teamID, "claimedSpot",   spotIdx, ALLIED)
	Spring.SetTeamRulesParam(teamID, "selectedSpot",  spotIdx, ALLIED)
	Spring.SetTeamRulesParam(teamID, "confirmedSpot", spotIdx, ALLIED)

	Spring.Echo("[Game Spawn] Assigned spot " .. spotIdx .. " to team " .. teamID)
end

--------------------------------------------------------------------------------
-- Convenience checkers
--------------------------------------------------------------------------------

local function CheckAllFactionChosen()
	for _, tID in ipairs(humanTeams) do
		if not factionChosen[tID] then return false end
	end
	return true
end

local function CheckAllPlacementConfirmed()
	for _, tID in ipairs(humanTeams) do
		if not placementConfirmed[tID] then return false end
	end
	return true
end

--------------------------------------------------------------------------------
-- Start unit resolution (unchanged logic)
--------------------------------------------------------------------------------

local function GetStartUnit(teamID)
	-- Survival AI: always a beacon, regardless of any startUnit rules param the
	-- faction-timeout loop may have force-assigned.
	if IsSurvivalTeam(teamID) then
		return "beacon"
	end

	local reqStartUnit = Spring.GetTeamRulesParam(teamID, "startUnit")
	if reqStartUnit then
		return UnitDefs[reqStartUnit].name
	end

	local side = select(5, Spring.GetTeamInfo(teamID))

	if IsTeamAI(teamID) then
		Spring.Echo("[Game Spawn] AI team — picking random faction")
		math.random(); math.random(); math.random()
		local sidedata = factionDefComms[math.random(0, 1)]
		Spring.Echo("[Game Spawn] AI Faction: " .. tostring(sidedata))
		local aiCommData = aiStartUnits[sidedata] or {}
		return aiCommData[math.random(1, #aiCommData)]
	else
		if side ~= "" then
			return Spring.GetSideData(side)
		else
			Spring.Echo("[Game Spawn] No faction choice for team " .. teamID .. " — picking randomly")
			return factionDefComms[math.random(0, 1)]
		end
	end
end

--------------------------------------------------------------------------------
-- Unit spawning
--   spawnX, spawnZ: confirmed placement coordinates, or nil to fall back to
--   engine-assigned position (used when usePlacement == false).
--------------------------------------------------------------------------------

local function SpawnStartUnit(teamID, spawnX, spawnZ)
	local startUnit = GetStartUnit(teamID)
	if not startUnit or startUnit == "" then return end

	-- Resolve faction label and store it
	local playerFaction
	if startUnit == "fedcommander" then
		playerFaction = "Federation of Kala"
	elseif startUnit == "lozcommander" then
		playerFaction = "Loz Alliance"
	elseif startUnit == "beacon" then
		playerFaction = "Survival"
	else
		playerFaction = startUnit
		Spring.Echo("[Game Spawn] Unrecognised start unit: " .. tostring(startUnit))
	end
	Spring.Echo("[Game Spawn] TeamID " .. teamID .. " faction: " .. playerFaction)
	Spring.SetTeamRulesParam(teamID, "faction", playerFaction)

	-- Resolve t1 commander
	local newStartUnit
	if startUnit == "fedcommander" then
		newStartUnit = "fedcommander_up1"
	elseif startUnit == "lozcommander" then
		newStartUnit = "lozcommander_up1"
	else
		newStartUnit = startUnit
	end

	-- Determine spawn position
	local x, z
	if spawnX and spawnZ then
		-- Placement-chosen position
		x, z = spawnX, spawnZ
	else
		-- Fallback: engine-assigned position (also used for AI when usePlacement is false)
		local ex, _, ez = Spring.GetTeamStartPosition(teamID)
		x, z = ex, ez

		if IsTeamAI(teamID) then
			local _, _, _, _, _, allyID = Spring.GetTeamInfo(teamID)
			local bxMin, bzMin, bxMax, bzMax = Spring.GetAllyTeamStartBox(allyID)
			local mx, mz = Game.mapSizeX, Game.mapSizeZ
			if not (bxMin == 0 and bzMin == 0 and bxMax == mx and bzMax == mz) then
				math.random(); math.random(); math.random()
				x = math.random(bxMin, bxMax)
				z = math.random(bzMin, bzMax)
			end
		end
	end

	-- Snap to 16×16 grid
	x = 16 * math.floor((x + 8) / 16)
	z = 16 * math.floor((z + 8) / 16)
	local y = Spring.GetGroundHeight(x, z)

	-- Face toward map centre
	local facing = math.abs(Game.mapSizeX / 2 - x) > math.abs(Game.mapSizeZ / 2 - z)
			and ((x > Game.mapSizeX / 2) and "west" or "east")
			or  ((z > Game.mapSizeZ / 2) and "north" or "south")

	Spring.CreateUnit(newStartUnit, x, y, z, facing, teamID)
end

--------------------------------------------------------------------------------
-- Start resources (unchanged)
--------------------------------------------------------------------------------

local function SetStartResources(teamID)
	local teamOptions = select(8, Spring.GetTeamInfo(teamID))
	local m = teamOptions.startmetal  or modOptions.startmetal  or 1000
	local e = teamOptions.startenergy or modOptions.startenergy or 1000

	if m and tonumber(m) ~= 0 then
		Spring.SetTeamResource(teamID, "ms", tonumber(m))
		Spring.SetTeamResource(teamID, "m",  0)
		Spring.AddTeamResource(teamID, "m",  tonumber(m))
	end
	if e and tonumber(e) ~= 0 then
		Spring.SetTeamResource(teamID, "es", tonumber(e))
		Spring.SetTeamResource(teamID, "e",  0)
		Spring.AddTeamResource(teamID, "e",  tonumber(e))
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GameStart()
	if #Spring.GetAllUnits() > 0 then return end

	local gaiaTeamID = Spring.GetGaiaTeamID()
	local teams      = Spring.GetTeamList()

	for i = 1, #teams do
		local teamID = teams[i]
		if teamID ~= gaiaTeamID then
			allNonGaiaTeams[#allNonGaiaTeams + 1] = teamID
			if IsTeamAI(teamID) then
				-- AI doesn't send a message so mark as chosen immediately so it
				-- doesn't block the early-advance check.
				factionChosen[teamID] = true
			else
				humanTeams[#humanTeams + 1] = teamID
			end
			SetStartResources(teamID)
		end
	end

	-- Load and partition map spots before broadcasting phase so the game rules
	-- params are ready when widgets first read them.
	LoadMapSpots()

	-- Broadcast initial phase state
	factionDeadline = CHOICE_TIMEOUT_FRAMES
	Spring.SetGameRulesParam("phase",               "faction")
	Spring.SetGameRulesParam("factionDeadlineFrame", factionDeadline)
	Spring.SetGameRulesParam("placementDeadlineFrame", 0)

	Spring.Echo("[Game Spawn] Phase: faction  deadline=" .. factionDeadline)
	Spring.Echo("[Game Spawn] Human teams=" .. #humanTeams ..
			            "  AI teams=" .. (#allNonGaiaTeams - #humanTeams) ..
			            "  usePlacement=" .. tostring(usePlacement))

	-- Edge case: all-AI game, advance faction immediately
	if #humanTeams == 0 then
		pendingFactionAdvance = true
	end
end

--------------------------------------------------------------------------------

function gadget:RecvLuaMsg(msg, playerID)
	local firstByte = msg:sub(1, 1)

	-- ── Faction choice ────────────────────────────────────────────────────────
	if firstByte == FACTION_BYTE then
		if phase ~= "faction" then return end

		local commDefID = tonumber(msg:sub(2) or "-1")
		if not validStartComm[commDefID] then return end

		local teamID = select(4, Spring.GetPlayerInfo(playerID, false))
		Spring.SetTeamRulesParam(teamID, "startUnit", commDefID, ACCESS_LEVEL)
		factionChosen[teamID] = true
		Spring.Echo("[Game Spawn] Stored faction for team " .. teamID .. ": defID " .. commDefID)

		if CheckAllFactionChosen() then
			pendingFactionAdvance = true
		end

		-- ── Spot selection (tentative) ────────────────────────────────────────────
	elseif firstByte == SELECT_BYTE then
		if phase ~= "placement" then return end

		local spotIdx = tonumber(msg:sub(2) or "0")
		if not spotIdx or not mapSpots[spotIdx] then return end

		local teamID = select(4, Spring.GetPlayerInfo(playerID, false))
		if placementConfirmed[teamID] then return end   -- already locked

		local _, _, _, _, _, allyID = Spring.GetTeamInfo(teamID)
		local spot = mapSpots[spotIdx]

		-- Validate side (no crossing into enemy territory)
		if not isFFA and spot.allyteam ~= allyID then return end

		-- First-claim wins: reject silently if already taken by someone else
		if claimedSpots[spotIdx] and claimedSpots[spotIdx] ~= teamID then return end

		-- Release previous tentative claim
		local prev = selectedSpots[teamID]
		if prev and claimedSpots[prev] == teamID then
			claimedSpots[prev] = nil
			Spring.SetTeamRulesParam(teamID, "claimedSpot", -1, ALLIED)
		end

		claimedSpots[spotIdx] = teamID
		selectedSpots[teamID] = spotIdx
		Spring.SetTeamRulesParam(teamID, "claimedSpot",  spotIdx, ALLIED)
		Spring.SetTeamRulesParam(teamID, "selectedSpot", spotIdx, ALLIED)

		-- ── Placement confirm ─────────────────────────────────────────────────────
	elseif firstByte == CONFIRM_BYTE then
		if phase ~= "placement" then return end

		local teamID = select(4, Spring.GetPlayerInfo(playerID, false))
		if placementConfirmed[teamID] then return end

		local spotIdx = selectedSpots[teamID]
		if not spotIdx then return end   -- must select before confirming

		confirmedSpots[teamID] = spotIdx
		placementConfirmed[teamID] = true
		Spring.SetTeamRulesParam(teamID, "confirmedSpot", spotIdx, ALLIED)
		Spring.Echo("[Game Spawn] Team " .. teamID .. " confirmed spot " .. spotIdx)

		if CheckAllPlacementConfirmed() then
			pendingPlacementAdvance = true
		end
	end
end

--------------------------------------------------------------------------------

function gadget:GameFrame(n)
	-- ── Faction phase ─────────────────────────────────────────────────────────
	if phase == "faction" then

		-- All humans chose: collapse deadline to n + 3 s
		if pendingFactionAdvance then
			pendingFactionAdvance = false
			local target = n + ADVANCE_FRAMES
			if target < factionDeadline then
				factionDeadline = target
				Spring.SetGameRulesParam("factionDeadlineFrame", factionDeadline)
				Spring.Echo("[Game Spawn] All factions chosen — new deadline: frame " .. factionDeadline)
			end
		end

		if n >= factionDeadline then
			-- Force random for any team that never chose
			for _, teamID in ipairs(allNonGaiaTeams) do
				if not Spring.GetTeamRulesParam(teamID, "startUnit") then
					Spring.Echo("[Game Spawn] Team " .. teamID .. " timed out — forcing random faction")
					local forced = factionDefComms[math.random(0, 1)]
					Spring.SetTeamRulesParam(teamID, "startUnit", UnitDefNames[forced].id, ACCESS_LEVEL)
				end
			end

			if usePlacement then
				-- Advance to placement phase
				phase           = "placement"
				placementDeadline = n + PLACEMENT_TIMEOUT_FRAMES
				Spring.SetGameRulesParam("phase",                "placement")
				Spring.SetGameRulesParam("placementDeadlineFrame", placementDeadline)
				Spring.Echo("[Game Spawn] Phase: placement  deadline=" .. placementDeadline)

				-- AI teams: auto-place and confirm immediately
				for _, teamID in ipairs(allNonGaiaTeams) do
					if IsTeamAI(teamID) then
						local spotIdx = AutoSelectSpot(teamID)
						if spotIdx then
							AssignSpot(teamID, spotIdx)
						end
						placementConfirmed[teamID] = true
					end
				end

				-- Edge case: no human teams (or all confirmed somehow)
				if CheckAllPlacementConfirmed() then
					pendingPlacementAdvance = true
				end
			else
				-- No map spots — spawn at engine-assigned positions immediately
				for _, teamID in ipairs(allNonGaiaTeams) do
					SpawnStartUnit(teamID, nil, nil)
				end
				phase = "done"
				Spring.SetGameRulesParam("phase", "done")
			end
		end

		-- ── Placement phase ───────────────────────────────────────────────────────
	elseif phase == "placement" then

		-- All humans confirmed: collapse deadline to n + 3 s
		if pendingPlacementAdvance then
			pendingPlacementAdvance = false
			local target = n + ADVANCE_FRAMES
			if target < placementDeadline then
				placementDeadline = target
				Spring.SetGameRulesParam("placementDeadlineFrame", placementDeadline)
				Spring.Echo("[Game Spawn] All placements confirmed — new deadline: frame " .. placementDeadline)
			end
		end

		if n >= placementDeadline then
			-- Auto-place any human team that hasn't confirmed
			for _, teamID in ipairs(humanTeams) do
				if not placementConfirmed[teamID] then
					Spring.Echo("[Game Spawn] Team " .. teamID .. " placement timed out — auto-placing")
					local spotIdx = AutoSelectSpot(teamID)
					if spotIdx then
						AssignSpot(teamID, spotIdx)
					end
					placementConfirmed[teamID] = true
				end
			end

			-- Spawn everyone
			for _, teamID in ipairs(allNonGaiaTeams) do
				local spotIdx = confirmedSpots[teamID]
				local spot    = spotIdx and mapSpots[spotIdx]
				if spot then
					SpawnStartUnit(teamID, spot.x, spot.z)
				else
					SpawnStartUnit(teamID, nil, nil)
				end
			end

			phase = "done"
			Spring.SetGameRulesParam("phase", "done")
		end
	end
end