function gadget:GetInfo()
	return {
		name = "CombatPowerGadget",
		desc = "Tracks and calculates combat power for each player, with persistence initialization",
		author = "ChatGPT",
		date = "2025-03-25",
		license = "GNU GPL v2",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

-- Table for storing combat power (CP) per player (keyed by player name)
local cp = {}
local baseline = {}  -- baseline CP (starting value) per player
local teamToPlayer = {}  -- mapping: teamID -> player name

-- Helper: Retrieve a player name from a team.
local function getPlayerName(teamID)
	local _, teamLeader, _, isAI = Spring.GetTeamInfo(teamID)
	local playerName = "Team" .. teamID
	if teamLeader then
		local name = select(1, Spring.GetPlayerInfo(teamLeader))
		if name then
			playerName = name
		end
	end
	if isAI then
		playerName = playerName .. " (AI)"
	end
	return playerName
end

-- On initialization, set up a baseline for every team/player.
function gadget:Initialize()
	local teams = Spring.GetTeamList()
	for _, teamID in ipairs(teams) do
		local name = getPlayerName(teamID)
		teamToPlayer[teamID] = name
		-- For human players, wait for CPINIT message to set their starting CP.
		-- For AI, initialize to 0.
		if name:find("%(AI%)") then
			cp[name] = 0
			baseline[name] = 0
			Spring.SetGameRulesParam("combatPower_" .. name, 0)
		else
			-- For now, initialize human players to 0 until they send CPINIT.
			cp[name] = 0
			baseline[name] = 0
			Spring.SetGameRulesParam("combatPower_" .. name, 0)
		end
	end
end

-- Receive initialization messages from unsynced widgets.
function gadget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,7) == "CPINIT:" then
		local playerName, initValue = msg:match("CPINIT:(.-):(.*)")
		initValue = tonumber(initValue) or 0
		if playerName then
			cp[playerName] = initValue
			baseline[playerName] = initValue
			Spring.SetGameRulesParam("combatPower_" .. playerName, initValue)
		end
	end
end

-- Handle unit destruction events.
function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	local metalCost = 0
	local energyCost = 0
	if UnitDefs[unitDefID] then
		metalCost = UnitDefs[unitDefID].metalCost or 0
		energyCost = UnitDefs[unitDefID].energyCost or 0
	end

	-- Calculate total unit value (energy converted to metal: 10 energy = 1 metal)
	local totalCost = metalCost + (energyCost / 10)

	local victimName = teamToPlayer[unitTeam]
	local attackerName = nil
	if attackerTeam then
		attackerName = teamToPlayer[attackerTeam]
	end

	if victimName then
		if attackerName then
			if victimName == attackerName then
				-- Friendly fire: subtract cost twice.
				cp[victimName] = cp[victimName] - (totalCost * 2)
			else
				cp[attackerName] = cp[attackerName] + totalCost
				cp[victimName] = cp[victimName] - totalCost
			end
		else
			-- No attacker (suicide, environmental, etc.)
			cp[victimName] = cp[victimName] - totalCost
		end

		-- Clamp victim's CP so it never falls below the baseline.
		if cp[victimName] < baseline[victimName] then
			cp[victimName] = baseline[victimName]
		end

		Spring.SetGameRulesParam("combatPower_" .. victimName, cp[victimName])
		if attackerName and attackerName ~= victimName then
			Spring.SetGameRulesParam("combatPower_" .. attackerName, cp[attackerName])
		end
	end
end

-- At game over, award bonus CP.
function gadget:GameOver()
	local teams = Spring.GetTeamList()
	if #teams == 2 then
		local name1 = teamToPlayer[teams[1]]
		local name2 = teamToPlayer[teams[2]]
		if cp[name1] >= cp[name2] then
			cp[name1] = cp[name1] + 2000
			cp[name2] = cp[name2] + 750
		else
			cp[name1] = cp[name1] + 750
			cp[name2] = cp[name2] + 2000
		end
		Spring.SetGameRulesParam("combatPower_" .. name1, cp[name1])
		Spring.SetGameRulesParam("combatPower_" .. name2, cp[name2])
	else
		for _, teamID in ipairs(teams) do
			local name = teamToPlayer[teamID]
			cp[name] = cp[name] + 750
			Spring.SetGameRulesParam("combatPower_" .. name, cp[name])
		end
	end
end
