--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    game_spawn.lua
--  brief:   spawns start unit and sets storage levels
--  author:  Tobi Vollebregt
--
--  Copyright (C) 2010.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name      = "Spawn",
		desc      = "spawns start unit and sets storage levels",
		author    = "Tobi Vollebregt",
		date      = "January, 2010",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- synced only
if (not gadgetHandler:IsSyncedCode()) then
	return false
end

--------------------------------------------------------------------------------
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
	-- pick one of the two below to choose whether enemies can see faction choice
	private = true,
	-- public = true,
}

-- human teams waiting on a faction choice before spawning
local pendingTeams = {}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local modOptions = Spring.GetModOptions()

local function IsTeamAI(teamID)
	-- GetTeamInfo's isAiTeam field is unreliable in Recoil.
	-- If no human (non-spectator) player is on this team, treat it as AI.
	local players = Spring.GetPlayerList(teamID, true)
	return not players or #players == 0
end

local function GetStartUnit(teamID)
	local reqStartUnit = Spring.GetTeamRulesParam(teamID, "startUnit")
	if reqStartUnit then
		return UnitDefs[reqStartUnit].name
	end

	-- No choice stored — fall back to side from script, or random
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
			Spring.Echo("[Game Spawn] No faction choice received for team " .. teamID .. " — picking randomly")
			return factionDefComms[math.random(0, 1)]
		end
	end
end

local function SpawnStartUnit(teamID)
	local startUnit = GetStartUnit(teamID)

	if startUnit and startUnit ~= "" then

		-- Resolve faction label
		local playerFaction
		if startUnit == "fedcommander" then
			playerFaction = "Federation of Kala"
		elseif startUnit == "lozcommander" then
			playerFaction = "Loz Alliance"
		else
			playerFaction = startUnit
			Spring.Echo("[Game Spawn] Unrecognised start unit: " .. tostring(startUnit))
		end

		Spring.Echo("[Game Spawn] TeamID " .. teamID .. "'s starting faction is " .. playerFaction)
		Spring.SetTeamRulesParam(teamID, "faction", playerFaction)

		-- Resolve t1 commander — starting tech is always t1
		local newStartUnit
		if startUnit == "fedcommander" then
			newStartUnit = "fedcommander_up1"
		elseif startUnit == "lozcommander" then
			newStartUnit = "lozcommander_up1"
		else
			newStartUnit = startUnit   -- AI-specific or fallback units pass through unchanged
		end

		-- Determine spawn position
		local x, y, z = Spring.GetTeamStartPosition(teamID)
		if IsTeamAI(teamID) then
			local _, _, _, _, _, allyID = Spring.GetTeamInfo(teamID)
			local startBoxXmin, startBoxZmin, startBoxXmax, startBoxZmax = Spring.GetAllyTeamStartBox(allyID)
			local mx = Game.mapSizeX
			local mz = Game.mapSizeZ
			if not (startBoxXmin == 0 and startBoxZmin == 0 and startBoxXmax == mx and startBoxZmax == mz) then
				math.random(); math.random(); math.random()
				x = math.random(startBoxXmin, startBoxXmax)
				z = math.random(startBoxZmin, startBoxZmax)
			end
		end

		-- Snap to 16x16 grid
		x = 16 * math.floor((x + 8) / 16)
		z = 16 * math.floor((z + 8) / 16)
		y = Spring.GetGroundHeight(x, z)

		-- Face toward map center
		local facing = math.abs(Game.mapSizeX / 2 - x) > math.abs(Game.mapSizeZ / 2 - z)
				and ((x > Game.mapSizeX / 2) and "west" or "east")
				or  ((z > Game.mapSizeZ / 2) and "north" or "south")

		Spring.CreateUnit(newStartUnit, x, y, z, facing, teamID)
	end

	-- Set start resources from mod options or custom team keys
	local teamOptions = select(8, Spring.GetTeamInfo(teamID))
	local m = teamOptions.startmetal  or modOptions.startmetal  or 1000
	local e = teamOptions.startenergy or modOptions.startenergy or 1000

	if m and tonumber(m) ~= 0 then
		Spring.SetTeamResource(teamID, "ms", tonumber(m))
		Spring.SetTeamResource(teamID, "m", 0)
		Spring.AddTeamResource(teamID, "m", tonumber(m))
	end
	if e and tonumber(e) ~= 0 then
		Spring.SetTeamResource(teamID, "es", tonumber(e))
		Spring.SetTeamResource(teamID, "e", 0)
		Spring.AddTeamResource(teamID, "e", tonumber(e))
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Frames to wait for a human faction choice before forcing a random spawn.
-- 30 seconds at 30 fps = 900 frames.
local CHOICE_TIMEOUT_FRAMES = 900

function gadget:RecvLuaMsg(msg, playerID)
	if msg:find("\138") ~= 1 then
		return
	end

	local requestedCommDefID = tonumber(msg:sub(2) or "-1")
	if not validStartComm[requestedCommDefID] then
		return
	end

	local teamID = select(4, Spring.GetPlayerInfo(playerID, false))
	Spring.SetTeamRulesParam(teamID, "startUnit", requestedCommDefID, ACCESS_LEVEL)
	Spring.Echo("[Game Spawn] Stored faction choice for team " .. teamID .. ": defID " .. requestedCommDefID)
end

function gadget:GameStart()
	-- Only activate if engine didn't already spawn units (compatibility)
	if #Spring.GetAllUnits() > 0 then
		return
	end

	local gaiaTeamID = Spring.GetGaiaTeamID()
	local teams = Spring.GetTeamList()

	for i = 1, #teams do
		local teamID = teams[i]
		if teamID ~= gaiaTeamID then
			if IsTeamAI(teamID) then
				-- AI has no player to choose — spawn immediately
				SpawnStartUnit(teamID)
			else
				-- Human team: defer, but record the deadline frame
				pendingTeams[teamID] = CHOICE_TIMEOUT_FRAMES
				Spring.Echo("[Game Spawn] TeamID " .. teamID .. " waiting for faction choice (timeout: " .. CHOICE_TIMEOUT_FRAMES .. " frames)")
			end
		end
	end
end

function gadget:GameFrame(n)
	if next(pendingTeams) == nil then return end

	for teamID, deadline in pairs(pendingTeams) do
		local choice = Spring.GetTeamRulesParam(teamID, "startUnit")
		if choice then
			-- Player made a choice
			SpawnStartUnit(teamID)
			pendingTeams[teamID] = nil
		elseif n >= deadline then
			-- Timed out — pick randomly and spawn regardless
			Spring.Echo("[Game Spawn] TeamID " .. teamID .. " timed out — forcing random faction")
			local factionIndex = math.random(0, 1)
			local forcedComm   = factionDefComms[factionIndex]
			Spring.SetTeamRulesParam(teamID, "startUnit", UnitDefNames[forcedComm].id, ACCESS_LEVEL)
			SpawnStartUnit(teamID)
			pendingTeams[teamID] = nil
		end
	end
end
