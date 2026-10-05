--------------------------------------------------------------------------------
-- Game Recorder
--
-- Writes a compact, line-based log of a whole game so it can be analyzed after
-- the fact: who built what and when, every team's economy over time, where the
-- armies were, who killed what, and (for SimpleAI/AdaptiveAI teams) which
-- priority rung the AI's builders were taking and why.
--
-- HOW TO USE
--   Enable the widget (F11 list, "Game Recorder") while SPECTATING or while
--   watching a REPLAY. It can be enabled mid-game; units already alive are
--   logged as a baseline. As a player it only sees what you can see, and the
--   header says so (view=player).
--   Output: <write dir>/SFRecordings/sfrec_<date>_<time>_<map>.txt
--   One file per game. The path is echoed to the console at start and end.
--
-- TEAMS
--   Every line carries a team ID and the header lists every team with its
--   ally team, controller (human, LuaAI name, skirmish AI name) and side, so
--   any number of AIs in one game can be told apart and filtered afterward.
--   To keep a log small you can also restrict recording to some teams with
--   ONLY_TEAMS below (deaths still name the killer's team either way).
--
-- LINE FORMAT (space separated; first token is the record type)
--   #SFREC 1                                   format version
--   H <key> <value...>                         header facts (map, sizes, view...);
--                                              H geovents <n> <x,z> ... lists the vents
--   T <team> <ally> <kind> <ai> <side> <name>  team roster; kind = human|luaai|ai|gaia
--   C <f> <uid> <team> <def> <x> <z> <builder> unit created (nanoframe); builder uid or -
--   B <f> <uid> <team> <def> <x> <z> <fin>     baseline unit (alive when recording began)
--   F <f> <uid> <team>                         unit finished
--   D <f> <uid> <team> <def> <x> <z> <fin> <killerTeam> <killerDef>
--                                              unit destroyed; fin 0 = died as nanoframe;
--                                              killer fields are - when unknown
--   G <f> <uid> <oldTeam> <newTeam>            unit changed teams
--   S <f> <team> <mCur> <mStor> <mInc> <mExp> <eCur> <eStor> <eInc> <eExp>
--       <supUsed> <supMax> <units> <buildings> <army> <armyMetal> <lostMetal> <killedMetal>
--       <reclaimM> <reclaimE> <reclaimers>
--                                              team snapshot, every SNAPSHOT_FRAMES.
--                                              reclaimM/E = metal and energy per second the
--                                              team's mobile builders are bringing in right
--                                              now (what a builder "makes" beyond its own
--                                              def's output is reclaim); reclaimers = how
--                                              many of them have a reclaim order
--   P <f> <team> <cell>:<metal> ...            where the team's army is: metal value of
--                                              mobile armed units per grid cell,
--                                              cell = gx + gz * gridX (see H grid)
--   A <f> <team> <trace>                       SimpleAI decision trace for the interval
--                                              (tech, signals, rung:count list)
--   X <f> <what> <...>                         teamdied <team> | gameover <winning allyteams>
--   Z <team> <key>=<value> ...                 engine end-of-game team statistics
--   f is the game frame (30 per second).
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name    = "Game Recorder",
		desc    = "Records a compact log of the whole game (units, economy, army positions, AI decisions) for after-action analysis",
		author  = "SplinterFaction",
		date    = "2026",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = false,
	}
end

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

local SNAPSHOT_FRAMES = 300    -- team economy snapshot every 10s
local GRID_FRAMES     = 450    -- army position grid every 15s
local GRID_LONG_SIDE  = 24     -- grid cells along the map's longer side
local OUTPUT_DIR      = "SFRecordings"

-- nil = record every team. To record only some teams, list them:
--   local ONLY_TEAMS = { [2] = true, [5] = true }
local ONLY_TEAMS = nil

--------------------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------------------

local spGetGameFrame      = Spring.GetGameFrame
local spGetUnitPosition   = Spring.GetUnitPosition
local spGetTeamResources  = Spring.GetTeamResources
local spGetTeamRulesParam = Spring.GetTeamRulesParam
local spGetTeamUnits      = Spring.GetTeamUnits
local spGetUnitDefID      = Spring.GetUnitDefID
local floor               = math.floor

local file
local filePath
local teamList   = {}
local gaiaTeam   = Spring.GetGaiaTeamID()
local gridX, gridZ, cellSize = 1, 1, 1

-- defID-keyed, filled once
local defName, defMetal, defIsBuilding, defIsArmy = {}, {}, {}, {}
local defBuilderM, defBuilderE = {}, {}   -- mobile builders only: the def's own metal/energy make

-- unitID-keyed live state
local unitTeamOf, unitDefOf, unitFinished = {}, {}, {}

-- teamID-keyed tallies
local nUnits, nBuildings, nArmy = {}, {}, {}
local armyMetal, lostMetal, killedMetal = {}, {}, {}
local lastTrace = {}
local builders = {}   -- [teamID] = { [unitID] = unitDefID } mobile builders alive

local cellScratch, cellKeys = {}, {}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function Recording(teamID)
	return teamID and (not ONLY_TEAMS or ONLY_TEAMS[teamID]) and nUnits[teamID] ~= nil
end

local function Write(line)
	if file then file:write(line, "\n") end
end

local function Clean(s)
	-- one token, no whitespace
	s = tostring(s or "-")
	s = s:gsub("%s+", "_")
	if s == "" then s = "-" end
	return s
end

local function Pos(unitID)
	local x, _, z = spGetUnitPosition(unitID)
	if not x then return 0, 0 end
	return floor(x + 0.5), floor(z + 0.5)
end

-- Private team rules params come back as NO value (not nil) when unset or
-- unreadable, hence the extra parentheses.
local function TeamParam(teamID, key)
	return (spGetTeamRulesParam(teamID, key))
end

local function AddUnit(unitID, unitDefID, teamID, finished)
	unitTeamOf[unitID], unitDefOf[unitID], unitFinished[unitID] = teamID, unitDefID, finished
	if nUnits[teamID] == nil then return end
	if defBuilderM[unitDefID] then builders[teamID][unitID] = unitDefID end
	nUnits[teamID] = nUnits[teamID] + 1
	if defIsBuilding[unitDefID] then nBuildings[teamID] = nBuildings[teamID] + 1 end
	if defIsArmy[unitDefID] then
		nArmy[teamID]     = nArmy[teamID] + 1
		armyMetal[teamID] = armyMetal[teamID] + defMetal[unitDefID]
	end
end

local function RemoveUnit(unitID)
	local teamID, unitDefID = unitTeamOf[unitID], unitDefOf[unitID]
	unitTeamOf[unitID], unitDefOf[unitID], unitFinished[unitID] = nil, nil, nil
	if not teamID or nUnits[teamID] == nil then return end
	builders[teamID][unitID] = nil
	nUnits[teamID] = nUnits[teamID] - 1
	if defIsBuilding[unitDefID] then nBuildings[teamID] = nBuildings[teamID] - 1 end
	if defIsArmy[unitDefID] then
		nArmy[teamID]     = nArmy[teamID] - 1
		armyMetal[teamID] = armyMetal[teamID] - defMetal[unitDefID]
	end
end

--------------------------------------------------------------------------------
-- Header
--------------------------------------------------------------------------------

local function TeamKind(teamID)
	if teamID == gaiaTeam then return "gaia", "-" end
	local luaAI = Spring.GetTeamLuaAI(teamID)
	if luaAI and luaAI ~= "" then return "luaai", luaAI end
	-- GetTeamInfo's isAiTeam is unreliable; ask the AI interface instead.
	local ok, _, aiName, _, shortName = pcall(Spring.GetAIInfo, teamID)
	if ok and (shortName or aiName) then return "ai", shortName or aiName end
	return "human", "-"
end

local function TeamLabel(teamID)
	local names = {}
	local players = Spring.GetPlayerList(teamID) or {}
	for i = 1, #players do
		local name, _, isSpec = Spring.GetPlayerInfo(players[i], false)
		if name and not isSpec then names[#names + 1] = name end
	end
	if #names == 0 then return "-" end
	return table.concat(names, "+")
end

local function WriteHeader()
	local spec, fullView = Spring.GetSpectatingState()
	local view = (Spring.IsReplay() and "replay") or (spec and fullView and "spectator")
			or (spec and "spectator-limited") or "player"
	Write("#SFREC 1")
	Write("H game " .. Clean(Game.gameName) .. " " .. Clean(Game.gameVersion))
	Write("H engine " .. Clean(Engine and Engine.version or Game.version))
	Write("H map " .. Clean(Game.mapName))
	Write("H mapsize " .. Game.mapSizeX .. " " .. Game.mapSizeZ)
	Write("H grid " .. gridX .. " " .. gridZ .. " " .. cellSize)
	Write("H view " .. view)
	Write("H startframe " .. spGetGameFrame())
	Write("H date " .. os.date("%Y-%m-%d_%H:%M:%S"))
	Write("H snapshot " .. SNAPSHOT_FRAMES .. " " .. GRID_FRAMES)
	-- Geothermal vents placed by game_geovent_spot_generator (random per game).
	local vents = {}
	for i = 1, (Spring.GetGameRulesParam("customGeovent_count") or 0) do
		local x = Spring.GetGameRulesParam("customGeovent_" .. i .. "_x")
		local z = Spring.GetGameRulesParam("customGeovent_" .. i .. "_z")
		if x and z then vents[#vents + 1] = floor(x + 0.5) .. "," .. floor(z + 0.5) end
	end
	Write("H geovents " .. #vents .. ((#vents > 0) and (" " .. table.concat(vents, " ")) or ""))
	for i = 1, #teamList do
		local teamID = teamList[i]
		local _, _, _, _, side, allyTeam = Spring.GetTeamInfo(teamID, false)
		local kind, ai = TeamKind(teamID)
		Write(("T %d %d %s %s %s %s%s"):format(teamID, allyTeam or -1, kind, Clean(ai),
			Clean(side), Clean(TeamLabel(teamID)),
			(nUnits[teamID] == nil) and " (not recorded)" or ""))
	end
end

--------------------------------------------------------------------------------
-- Periodic records
--------------------------------------------------------------------------------

local lastSnapshot = -1
local function Snapshot(n)
	if n == lastSnapshot then return end
	lastSnapshot = n
	for i = 1, #teamList do
		local teamID = teamList[i]
		if Recording(teamID) then
			local mCur, mStor, _, mInc, mExp = spGetTeamResources(teamID, "metal")
			local eCur, eStor, _, eInc, eExp = spGetTeamResources(teamID, "energy")
			-- Reclaim income: the engine credits reclaimed resources to the
			-- builder that collected them, so whatever a mobile builder is
			-- "making" beyond its def's own output is reclaim.
			local recM, recE, recN = 0, 0, 0
			for unitID, unitDefID in pairs(builders[teamID]) do
				local mMake, _, eMake = Spring.GetUnitResources(unitID)
				if mMake then
					local m = mMake - defBuilderM[unitDefID]
					local e = (eMake or 0) - defBuilderE[unitDefID]
					if m > 0 then recM = recM + m end
					if e > 0 then recE = recE + e end
				end
				local queue = Spring.GetUnitCommands(unitID, 1)
				if queue and queue[1] and queue[1].id == CMD.RECLAIM then recN = recN + 1 end
			end
			if mCur then
				Write(("S %d %d %d %d %.1f %.1f %d %d %.1f %.1f %d %d %d %d %d %d %d %d %.1f %.1f %d"):format(
					n, teamID,
					mCur, mStor, mInc or 0, mExp or 0,
					eCur or 0, eStor or 0, eInc or 0, eExp or 0,
					TeamParam(teamID, "supplyUsed") or -1, TeamParam(teamID, "supplyMax") or -1,
					nUnits[teamID], nBuildings[teamID], nArmy[teamID],
					armyMetal[teamID], lostMetal[teamID], killedMetal[teamID],
					recM, recE, recN))
			end
			-- SimpleAI decision trace: one string per interval, published by
			-- ai_simpleai.lua. Logged once per new value.
			local trace = TeamParam(teamID, "simpleai_trace")
			if trace and trace ~= lastTrace[teamID] then
				lastTrace[teamID] = trace
				Write(("A %d %d %s"):format(n, teamID, trace))
			end
		end
	end
	if file then file:flush() end
end

local function ArmyGrid(n)
	for i = 1, #teamList do
		local teamID = teamList[i]
		if Recording(teamID) and nArmy[teamID] > 0 then
			local units = spGetTeamUnits(teamID)
			local nk = 0
			for u = 1, #units do
				local unitID    = units[u]
				local unitDefID = spGetUnitDefID(unitID)
				if unitDefID and defIsArmy[unitDefID] then
					local x, _, z = spGetUnitPosition(unitID)
					if x then
						local gx = floor(x / cellSize); if gx < 0 then gx = 0 elseif gx >= gridX then gx = gridX - 1 end
						local gz = floor(z / cellSize); if gz < 0 then gz = 0 elseif gz >= gridZ then gz = gridZ - 1 end
						local cell = gx + gz * gridX
						if not cellScratch[cell] then
							nk = nk + 1
							cellKeys[nk] = cell
							cellScratch[cell] = 0
						end
						cellScratch[cell] = cellScratch[cell] + defMetal[unitDefID]
					end
				end
			end
			if nk > 0 then
				for k = nk + 1, #cellKeys do cellKeys[k] = nil end
				table.sort(cellKeys)
				local parts = {}
				for k = 1, nk do
					local cell = cellKeys[k]
					parts[k] = cell .. ":" .. floor(cellScratch[cell] + 0.5)
					cellScratch[cell] = nil
				end
				Write(("P %d %d %s"):format(n, teamID, table.concat(parts, " ")))
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Callins
--------------------------------------------------------------------------------

function widget:Initialize()
	for unitDefID, ud in pairs(UnitDefs) do
		defName[unitDefID]       = ud.name
		defMetal[unitDefID]      = ud.metalCost or 0
		defIsBuilding[unitDefID] = (ud.isBuilding or ud.isImmobile) and true or false
		defIsArmy[unitDefID]     = (not ud.isBuilding and not ud.isImmobile and ud.canMove
				and not ud.isBuilder and ud.weapons and #ud.weapons > 0) and true or false
		if ud.isBuilder and ud.canMove and not ud.isBuilding and not ud.isImmobile and not ud.isFactory then
			defBuilderM[unitDefID] = ud.metalMake or 0
			defBuilderE[unitDefID] = ud.energyMake or 0
		end
	end

	local long = math.max(Game.mapSizeX, Game.mapSizeZ)
	cellSize = math.ceil(long / GRID_LONG_SIDE)
	gridX    = math.max(1, math.ceil(Game.mapSizeX / cellSize))
	gridZ    = math.max(1, math.ceil(Game.mapSizeZ / cellSize))

	teamList = Spring.GetTeamList()
	for i = 1, #teamList do
		local teamID = teamList[i]
		if not ONLY_TEAMS or ONLY_TEAMS[teamID] then
			nUnits[teamID], nBuildings[teamID], nArmy[teamID] = 0, 0, 0
			builders[teamID] = {}
			armyMetal[teamID], lostMetal[teamID], killedMetal[teamID] = 0, 0, 0
		end
	end

	Spring.CreateDir(OUTPUT_DIR)
	local mapToken = Clean(Game.mapName):gsub("[^%w_%-]", "")
	filePath = ("%s/sfrec_%s_%s.txt"):format(OUTPUT_DIR, os.date("%Y%m%d_%H%M%S"), mapToken)
	file = io.open(filePath, "w")
	if not file then
		Spring.Echo("[Game Recorder] could not open " .. filePath .. " for writing; disabling")
		widgetHandler:RemoveWidget(self)
		return
	end
	WriteHeader()

	-- Baseline: units already alive (recorder enabled mid-game).
	local n = spGetGameFrame()
	local all = Spring.GetAllUnits()
	for i = 1, #all do
		local unitID    = all[i]
		local unitDefID = spGetUnitDefID(unitID)
		local teamID    = Spring.GetUnitTeam(unitID)
		if unitDefID and teamID then
			local _, _, _, _, buildProgress = Spring.GetUnitHealth(unitID)
			local finished = (buildProgress == nil) or buildProgress >= 1
			AddUnit(unitID, unitDefID, teamID, finished)
			if Recording(teamID) then
				local x, z = Pos(unitID)
				Write(("B %d %d %d %s %d %d %d"):format(n, unitID, teamID, defName[unitDefID],
					x, z, finished and 1 or 0))
			end
		end
	end
	file:flush()
	Spring.Echo("[Game Recorder] recording to " .. filePath)
end

function widget:Shutdown()
	if file then
		file:close()
		file = nil
		Spring.Echo("[Game Recorder] saved " .. tostring(filePath))
	end
end

function widget:GameFrame(n)
	if n % SNAPSHOT_FRAMES == 0 then Snapshot(n) end
	if n % GRID_FRAMES == 0 then ArmyGrid(n) end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if unitTeamOf[unitID] then RemoveUnit(unitID) end   -- unit ID reuse safety
	AddUnit(unitID, unitDefID, unitTeam, false)
	if Recording(unitTeam) then
		local x, z = Pos(unitID)
		Write(("C %d %d %d %s %d %d %s"):format(spGetGameFrame(), unitID, unitTeam,
			defName[unitDefID] or "?", x, z, builderID and tostring(builderID) or "-"))
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if not unitTeamOf[unitID] then AddUnit(unitID, unitDefID, unitTeam, true) end
	unitFinished[unitID] = true
	if Recording(unitTeam) then
		Write(("F %d %d %d"):format(spGetGameFrame(), unitID, unitTeam))
	end
end

-- The attacker arguments are only supplied by newer engines; they are simply
-- logged as "-" when absent.
function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	local finished = unitFinished[unitID]
	local known    = unitTeamOf[unitID] ~= nil
	RemoveUnit(unitID)
	local cost = defMetal[unitDefID] or 0
	if finished and lostMetal[unitTeam] then
		lostMetal[unitTeam] = lostMetal[unitTeam] + cost
	end
	if finished and attackerTeam and attackerTeam ~= unitTeam and killedMetal[attackerTeam] then
		killedMetal[attackerTeam] = killedMetal[attackerTeam] + cost
	end
	if known and Recording(unitTeam) then
		local x, z = Pos(unitID)
		Write(("D %d %d %d %s %d %d %d %s %s"):format(spGetGameFrame(), unitID, unitTeam,
			defName[unitDefID] or "?", x, z, finished and 1 or 0,
			attackerTeam and tostring(attackerTeam) or "-",
			attackerDefID and (defName[attackerDefID] or "?") or "-"))
	end
end

-- A transfer fires UnitTaken (old owner) then UnitGiven (new owner); the log
-- line is written once, on UnitGiven.
function widget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	local finished = unitFinished[unitID]
	if finished == nil then finished = true end
	RemoveUnit(unitID)
	AddUnit(unitID, unitDefID, newTeam, finished)
	if Recording(newTeam) or Recording(oldTeam) then
		Write(("G %d %d %d %d"):format(spGetGameFrame(), unitID, oldTeam or -1, newTeam))
	end
end

function widget:TeamDied(teamID)
	Write(("X %d teamdied %d"):format(spGetGameFrame(), teamID))
end

function widget:GameOver(winningAllyTeams)
	local n = spGetGameFrame()
	Snapshot(n)
	local winners = {}
	for i = 1, #(winningAllyTeams or {}) do winners[i] = tostring(winningAllyTeams[i]) end
	Write(("X %d gameover %s"):format(n, (#winners > 0) and table.concat(winners, " ") or "-"))

	-- Engine team statistics (latest entry per team); spectators only.
	for i = 1, #teamList do
		local teamID = teamList[i]
		if Recording(teamID) then
			local ok, count = pcall(Spring.GetTeamStatsHistory, teamID)
			if ok and type(count) == "number" and count > 0 then
				local ok2, hist = pcall(Spring.GetTeamStatsHistory, teamID, count)
				local st = ok2 and type(hist) == "table" and hist[1]
				if st then
					local keys, parts = {}, {}
					for k, v in pairs(st) do
						if type(v) == "number" then keys[#keys + 1] = k end
					end
					table.sort(keys)
					for k = 1, #keys do
						parts[k] = keys[k] .. "=" .. floor(st[keys[k]] + 0.5)
					end
					Write(("Z %d %s"):format(teamID, table.concat(parts, " ")))
				end
			end
		end
	end
	if file then file:flush() end
end
