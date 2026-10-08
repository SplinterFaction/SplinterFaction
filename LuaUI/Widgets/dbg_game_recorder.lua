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
-- THE FEED
--   The gadget LuaRules/Gadgets/dbg_game_recorder_feed.lua sees what a widget
--   cannot (killers, damage, orders, other gadgets' state) and hands it to
--   this widget, which writes it into the same file (records K V O Y M L).
--   Without the gadget the recorder still works; those records are absent.
--
-- LINE FORMAT, version 2 (space separated; first token is the record type)
--   The file describes itself: every record type's columns are listed in a
--   "@" line in the header, and every unit type in a "U" line, so a reader
--   needs nothing but the file.
--   #SFREC 2                                   format version
--   H <key> <value...>                         header facts (map, sizes, view, vents...)
--   @ <type> <column names...>                 the columns of a record type
--   U <def> <metal> <energy> <footX> <footZ> <speed> <flags> <weapons> <role> <energyMake>
--     <metalStorage> <energyStorage>
--                                              one per unit type. flags: b building,
--                                              f factory, c mobile builder, a army, - none.
--                                              weapons: direct | heat | disrupt | shield | none
--   T <team> <ally> <kind> <ai> <side> <name>  team roster; kind = human|luaai|ai|gaia
--   C <f> <uid> <team> <def> <x> <z> <builder> unit created (nanoframe); builder uid or -
--   B <f> <uid> <team> <def> <x> <z> <fin>     baseline unit (alive when recording began)
--   F <f> <uid> <team>                         unit finished
--   D <f> <uid> <team> <def> <x> <z> <fin> <killerTeam> <killerDef>
--                                              unit gone; fin 0 = died as nanoframe. The
--                                              killer fields here are only what the engine
--                                              tells widgets (usually -); see K.
--   K <f> <uid> <team> <def> <fin> <killerUid> <killerTeam> <killerDef>
--                                              (feed) the same death with its killer;
--                                              - when there was none (self-destruct, morph,
--                                              reclaim)
--   M <f> <oldUid> <newUid> <team> <oldDef> <newDef>
--                                              (feed) a morph: oldUid's D line is an upgrade,
--                                              not a loss
--   G <f> <uid> <oldTeam> <newTeam>            unit changed teams
--   S <f> <team> ...                           team snapshot every SNAPSHOT_FRAMES; columns in
--                                              "@ S". reclaimM/E = metal and energy per second
--                                              the team's mobile builders are bringing in
--                                              (what a builder makes beyond its def's own
--                                              output is reclaim)
--   Y <f> <team> <rp> <weapons> <armor> <tech> (feed) research points, upgrade levels, tech
--   V <f> <attackerTeam> <victimTeam> <damage> <paralyze> <aDef>><vDef>:<dmg> ...
--                                              (feed) damage dealt in the last interval, with
--                                              the unit-type pairs that did most of it
--   O <f> <team> <CMD>:<count> ...             (feed) orders given in the last interval
--   L <f> <team> <tag> <text...>               (feed) a line logged by a gadget through
--                                              GG.Recorder.Log; tag "simpleai" is the AI
--                                              decision trace
--   Q <f> <team> <uid>:<x>,<z> ...             where every mobile unit of the team is,
--                                              every POSITION_FRAMES (buildings never move:
--                                              their place is on their C or B line)
--   W <f> <cell>:<metal>:<energy> ...          the reclaim field every WRECK_FRAMES: metal and
--                                              energy lying in each grid cell,
--                                              cell = gx + gz * nx (see H wreckgrid)
--   E <row> <height> ...                       header: ground height grid, one line per row
--                                              from north to south (see H heightgrid);
--                                              H metalspots and H start give the rest of the map
--   J <f> <team> <units> <metal> <energy> <hash>
--                                              sync fingerprint of a team every SYNC_FRAMES:
--                                              unit count, exact metal and energy, and one
--                                              hash over all its units. Two runs of the same
--                                              game must produce identical J lines; the first
--                                              one that differs is where they diverged
--                                              (sfrec_report.py --sync a.txt b.txt)
--   I <f> <team> <uid>:<motion>:<health> ... -<uid> ...
--                                              the units behind that J line, as CHANGES since
--                                              the team's previous I line: a unit is listed
--                                              when its motion hash (exact position, velocity,
--                                              heading) or health hash (health, paralysis,
--                                              build progress) changed, and as -uid when it
--                                              is gone. A unit not listed is unchanged. The
--                                              first I line of a team lists every unit.
--                                              Hashes use every bit of the values, so a
--                                              difference far below one elmo shows. Written
--                                              only for teams this viewer sees in full (all
--                                              teams in a replay or as a spectator; your own
--                                              allies as a player)
--   A <f> <team> <trace>                       SimpleAI decision trace read directly from the
--                                              AI (only written when the feed is absent)
--   X <f> <what> <...>                         teamdied <team> | gameover <winning allyteams>
--                                              | feed (first record received from the gadget)
--                                              | stopped (recording ended after game over)
--   Z <team> <key>=<value> ...                 engine end-of-game team statistics
--   f is the game frame (30 per second). Team -1 means "no team".
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name    = "Game Recorder",
		desc    = "Records the whole game to a text file (units, kills, damage, orders, economy, army positions, AI decisions) for after-action analysis",
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
local POSITION_FRAMES = 300    -- every mobile unit's position every 10s
local WRECK_FRAMES    = 900    -- reclaim field snapshot every 30s
local SYNC_FRAMES     = 30     -- sync fingerprint every second; 0 turns it off
local HEIGHT_CELL     = 128    -- map height grid resolution (elmos)
local WRECK_CELL      = 512    -- reclaim field grid resolution (elmos)
local WRECK_MIN       = 20     -- ignore cells holding less than this much metal + energy
local OUTPUT_DIR      = "SFRecordings"
local STOP_AT_GAME_OVER = true   -- close the file shortly after the game ends
local STOP_GRACE      = 60     -- frames to keep recording after game over (lets final tallies arrive)

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
local wreckNX = 1

-- defID-keyed, filled once
local defName, defMetal, defIsBuilding, defIsArmy = {}, {}, {}, {}
local defBuilderM, defBuilderE = {}, {}   -- mobile builders only: the def's own metal/energy make

-- unitID-keyed live state
local unitTeamOf, unitDefOf, unitFinished = {}, {}, {}

-- teamID-keyed tallies
local nUnits, nBuildings, nArmy = {}, {}, {}
local armyMetal, lostMetal, killedMetal = {}, {}, {}
local lastTrace = {}
local stopAtFrame           -- set at game over: the frame recording ends
local feedSeen = false      -- has the gadget feed delivered anything yet?
local feedTrace = {}        -- [teamID] = true once the AI trace for that team arrives through the feed
local morphedAway = {}      -- [unitID] = true: this unit's coming death is a morph, not a loss
local builders = {}   -- [teamID] = { [unitID] = unitDefID } mobile builders alive
local mobiles  = {}   -- [teamID] = { [unitID] = true } every mobile unit alive
local reclaimable = {} -- [featureDefID] = true/false (cached)


--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function Recording(teamID)
	return teamID and (not ONLY_TEAMS or ONLY_TEAMS[teamID]) and nUnits[teamID] ~= nil
end

local function Write(line)
	if file then file:write(line, "\n") end
end

local function CloseFile()
	if file then
		file:close()
		file = nil
		Spring.Echo("[Game Recorder] saved " .. tostring(filePath))
	end
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
	if not defIsBuilding[unitDefID] then mobiles[teamID][unitID] = true end
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
	mobiles[teamID][unitID] = nil
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

local startWritten = {}   -- [teamID] = true once its start position is in the file
local function WriteStarts()
	for i = 1, #teamList do
		local teamID = teamList[i]
		if not startWritten[teamID] then
			local sx, _, sz = Spring.GetTeamStartPosition(teamID)
			if sx and (sx > 0 or (sz or 0) > 0) then
				startWritten[teamID] = true
				Write(("H start %d %d %d"):format(teamID, floor(sx + 0.5), floor(sz + 0.5)))
			end
		end
	end
end

local function WriteHeader()
	local spec, fullView = Spring.GetSpectatingState()
	local view = (Spring.IsReplay() and "replay") or (spec and fullView and "spectator")
			or (spec and "spectator-limited") or "player"
	Write("#SFREC 2")
	Write("H game " .. Clean(Game.gameName) .. " " .. Clean(Game.gameVersion))
	Write("H engine " .. Clean(Engine and Engine.version or Game.version))
	Write("H map " .. Clean(Game.mapName))
	Write("H mapsize " .. Game.mapSizeX .. " " .. Game.mapSizeZ)
	Write("H view " .. view)
	Write("H startframe " .. spGetGameFrame())
	Write("H date " .. os.date("%Y-%m-%d_%H:%M:%S"))
	Write("H snapshot " .. SNAPSHOT_FRAMES)
	Write("H positions " .. POSITION_FRAMES)
	Write("H wreckgrid " .. WRECK_FRAMES .. " " .. wreckNX .. " " .. WRECK_CELL)
	Write("H fingerprint " .. SYNC_FRAMES)
	-- Geothermal vents placed by game_geovent_spot_generator (random per game).
	local vents = {}
	for i = 1, (Spring.GetGameRulesParam("customGeovent_count") or 0) do
		local x = Spring.GetGameRulesParam("customGeovent_" .. i .. "_x")
		local z = Spring.GetGameRulesParam("customGeovent_" .. i .. "_z")
		if x and z then vents[#vents + 1] = floor(x + 0.5) .. "," .. floor(z + 0.5) end
	end
	Write("H geovents " .. #vents .. ((#vents > 0) and (" " .. table.concat(vents, " ")) or ""))
	-- Metal spots, as published by game_metal_maker_spot_generator.
	local spots = {}
	for i = 1, (Spring.GetGameRulesParam("metalSpot_count") or 0) do
		local x = Spring.GetGameRulesParam("metalSpot_" .. i .. "_x")
		local z = Spring.GetGameRulesParam("metalSpot_" .. i .. "_z")
		if x and z then spots[#spots + 1] = floor(x + 0.5) .. "," .. floor(z + 0.5) end
	end
	Write("H metalspots " .. #spots .. ((#spots > 0) and (" " .. table.concat(spots, " ")) or ""))
	-- Start positions (again at game start: before that they are not chosen
	-- yet and the engine reports 0,0).
	WriteStarts()
	-- Terrain: ground height at the center of every HEIGHT_CELL square, one
	-- "E" line per row (north to south), so slopes, plateaus and chokes can be
	-- worked out from the file alone.
	local nx = math.max(1, math.ceil(Game.mapSizeX / HEIGHT_CELL))
	local nz = math.max(1, math.ceil(Game.mapSizeZ / HEIGHT_CELL))
	Write(("H heightgrid %d %d %d"):format(nx, nz, HEIGHT_CELL))
	local row = {}
	for gz = 0, nz - 1 do
		for gx = 0, nx - 1 do
			row[gx + 1] = floor(Spring.GetGroundHeight((gx + 0.5) * HEIGHT_CELL, (gz + 0.5) * HEIGHT_CELL) + 0.5)
		end
		Write("E " .. gz .. " " .. table.concat(row, " ", 1, nx))
	end
	-- Schema: the columns of every record type.
	Write("@ T team ally kind ai side name")
	Write("@ U def metal energy footX footZ speed flags weapons role energyMake metalStorage energyStorage")
	Write("@ C f uid team def x z builder")
	Write("@ B f uid team def x z fin")
	Write("@ F f uid team")
	Write("@ D f uid team def x z fin killerTeam killerDef")
	Write("@ K f uid team def fin killerUid killerTeam killerDef")
	Write("@ M f oldUid newUid team oldDef newDef")
	Write("@ G f uid oldTeam newTeam")
	Write("@ S f team mCur mStor mInc mExp eCur eStor eInc eExp supUsed supMax units buildings army armyMetal lostMetal killedMetal reclaimM reclaimE reclaimers")
	Write("@ Y f team rp weapons armor tech")
	Write("@ V f attackerTeam victimTeam damage paralyze pairs...")
	Write("@ O f team orders...")
	Write("@ L f team tag text...")
	Write("@ Q f team uid:x,z...")
	Write("@ W f cell:metal:energy...")
	Write("@ E row heights...")
	Write("@ J f team units metal energy hash")
	Write("@ I f team uid:motionHash:healthHash... -goneUid...  (changes since the team's previous I line)")
	Write("@ A f team trace")
	Write("@ X f what args...")
	Write("@ Z team stats...")

	-- Unit table: what every unit type is, so the file can be read alone.
	local defIDs = {}
	for unitDefID in pairs(UnitDefs) do defIDs[#defIDs + 1] = unitDefID end
	table.sort(defIDs)
	for i = 1, #defIDs do
		local unitDefID = defIDs[i]
		local ud = UnitDefs[unitDefID]
		local flags = (defIsBuilding[unitDefID] and "b" or "") .. (ud.isFactory and "f" or "")
				.. (defBuilderM[unitDefID] and "c" or "") .. (defIsArmy[unitDefID] and "a" or "")
		if flags == "" then flags = "-" end
		-- weapon class: what its weapons do (every weapon heat -> heat, and so on)
		local class = "none"
		local weapons = ud.weapons
		if weapons and #weapons > 0 then
			local heat, disrupt, shield = 0, 0, 0
			for k = 1, #weapons do
				local wd  = WeaponDefs[weapons[k].weaponDef]
				local wcp = wd and (wd.customParams or wd.customparams)
				if wd and (wd.type == "Shield" or wd.isShield) then shield = shield + 1
				elseif wcp and wcp.heatweapon and wcp.heatweapon ~= "0" then heat = heat + 1
				elseif wcp and wcp.disruptionweapon and wcp.disruptionweapon ~= "0" then disrupt = disrupt + 1 end
			end
			if shield == #weapons then class = "shield"
			elseif heat == #weapons then class = "heat"
			elseif disrupt == #weapons then class = "disrupt"
			else class = "direct" end
		end
		local cp = ud.customParams or {}
		Write(("U %s %d %d %d %d %d %s %s %s %d %d %d"):format(ud.name or "?", ud.metalCost or 0, ud.energyCost or 0,
			(ud.xsize or 0) / 2, (ud.zsize or 0) / 2, ud.speed or 0, flags, class, Clean(cp.unitrole),
			ud.energyMake or 0, ud.metalStorage or 0, ud.energyStorage or 0))
	end

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
		if Recording(teamID) and (teamID ~= gaiaTeam or nUnits[teamID] > 0) then
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
			local trace = (not feedTrace[teamID]) and TeamParam(teamID, "simpleai_trace")
			if trace and trace ~= lastTrace[teamID] then
				lastTrace[teamID] = trace
				Write(("A %d %d %s"):format(n, teamID, trace))
			end
		end
	end
	if file then file:flush() end
end

-- Where every mobile unit is. Buildings never move; their place is on their
-- C or B line.
local posParts = {}
local function Positions(n)
	for i = 1, #teamList do
		local teamID = teamList[i]
		if Recording(teamID) then
			local count = 0
			for unitID in pairs(mobiles[teamID]) do
				local x, _, z = spGetUnitPosition(unitID)
				if x then
					count = count + 1
					posParts[count] = unitID .. ":" .. floor(x + 0.5) .. "," .. floor(z + 0.5)
				end
			end
			if count > 0 then
				Write(("Q %d %d %s"):format(n, teamID, table.concat(posParts, " ", 1, count)))
			end
		end
	end
end

-- The reclaim field: metal and energy lying on the map, per WRECK_CELL square.
local wreckM, wreckE, wreckKeys = {}, {}, {}
local function Wrecks(n)
	local features = Spring.GetAllFeatures()
	local nk = 0
	for i = 1, #features do
		local fid    = features[i]
		local fDefID = Spring.GetFeatureDefID(fid)
		local ok = reclaimable[fDefID]
		if ok == nil then
			local fDef = FeatureDefs[fDefID]
			ok = (fDef and fDef.reclaimable and not fDef.geoThermal) and true or false
			reclaimable[fDefID] = ok
		end
		if ok then
			local metal, _, energy = Spring.GetFeatureResources(fid)
			metal, energy = metal or 0, energy or 0
			if metal + energy > 0 then
				local x, _, z = Spring.GetFeaturePosition(fid)
				if x then
					local cell = floor(x / WRECK_CELL) + floor(z / WRECK_CELL) * wreckNX
					if not wreckM[cell] then
						nk = nk + 1
						wreckKeys[nk] = cell
						wreckM[cell], wreckE[cell] = 0, 0
					end
					wreckM[cell] = wreckM[cell] + metal
					wreckE[cell] = wreckE[cell] + energy
				end
			end
		end
	end
	for k = nk + 1, #wreckKeys do wreckKeys[k] = nil end
	table.sort(wreckKeys)
	local parts, np = {}, 0
	for k = 1, nk do
		local cell = wreckKeys[k]
		if wreckM[cell] + wreckE[cell] >= WRECK_MIN then
			np = np + 1
			parts[np] = cell .. ":" .. floor(wreckM[cell] + 0.5) .. ":" .. floor(wreckE[cell] + 0.5)
		end
		wreckM[cell], wreckE[cell] = nil, nil
	end
	Write(("W %d %s"):format(n, table.concat(parts, " ")))
end

--------------------------------------------------------------------------------
-- Sync fingerprint
--
-- A hash of the exact simulation state, so two runs of one game (the live game
-- and a replay, or two replays) can be compared to the second. Read-only.
--------------------------------------------------------------------------------

local HASH_MOD = 65521   -- keeps every intermediate value far below 2^24, so
                         -- the arithmetic is exact in single-precision Lua
local frexp, huge = math.frexp, math.huge
local spGetUnitVelocity = Spring.GetUnitVelocity
local spGetUnitHeading  = Spring.GetUnitHeading
local spGetUnitHealth   = Spring.GetUnitHealth

local function Mix(a, b, v)
	a = (a + (v % HASH_MOD) + 1) % HASH_MOD
	b = (b + a) % HASH_MOD
	return a, b
end

-- Folds every bit of a single-precision float into the hash.
local function MixFloat(a, b, x)
	if x == nil then return Mix(a, b, 3) end
	if x ~= x then return Mix(a, b, 5) end
	if x == huge then return Mix(a, b, 7) end
	if x == -huge then return Mix(a, b, 11) end
	local m, e = frexp(x)
	local neg = 0
	if m < 0 then m = -m; neg = 1 end
	local mant = floor(m * 16777216)
	a, b = Mix(a, b, floor(mant / 4096))
	a, b = Mix(a, b, mant % 4096)
	return Mix(a, b, e + 200 + neg * 1000)
end

local syncParts = {}
local syncSig  = {}   -- [teamID] = { [unitID] = "motion:health" as last written }
local syncSeen = {}   -- [teamID] = { [unitID] = frame last sampled }
local function Fingerprint(n)
	local _, fullView = Spring.GetSpectatingState()
	local seeAll = fullView or Spring.IsReplay()
	local myTeam = Spring.GetMyTeamID()
	for i = 1, #teamList do
		local teamID = teamList[i]
		-- Only teams whose state this viewer reads in full; a partly visible
		-- enemy would hash differently from the same team seen whole.
		if Recording(teamID) and (seeAll or Spring.AreTeamsAllied(myTeam, teamID)) then
			local units = spGetTeamUnits(teamID) or {}
			table.sort(units)
			local sigs, seen = syncSig[teamID], syncSeen[teamID]
			if not sigs then
				sigs, seen = {}, {}
				syncSig[teamID], syncSeen[teamID] = sigs, seen
			end
			local ta, tb = 1, 0
			local count, parts = 0, 0
			for k = 1, #units do
				local unitID = units[k]
				local x, y, z = spGetUnitPosition(unitID)
				if x then
					local vx, vy, vz = spGetUnitVelocity(unitID)
					local ma, mb = 1, 0
					ma, mb = MixFloat(ma, mb, x)
					ma, mb = MixFloat(ma, mb, y)
					ma, mb = MixFloat(ma, mb, z)
					ma, mb = MixFloat(ma, mb, vx)
					ma, mb = MixFloat(ma, mb, vy)
					ma, mb = MixFloat(ma, mb, vz)
					ma, mb = Mix(ma, mb, (spGetUnitHeading(unitID) or 0) + 40000)

					local hp, _, para, _, build = spGetUnitHealth(unitID)
					local ha, hb = 1, 0
					ha, hb = MixFloat(ha, hb, hp)
					ha, hb = MixFloat(ha, hb, para)
					ha, hb = MixFloat(ha, hb, build)

					ta, tb = Mix(ta, tb, unitID)
					ta, tb = Mix(ta, tb, ma)
					ta, tb = Mix(ta, tb, mb)
					ta, tb = Mix(ta, tb, ha)
					ta, tb = Mix(ta, tb, hb)

					count = count + 1
					seen[unitID] = n
					-- The team hash above carries every bit; these short per-unit
					-- hashes only have to name which unit differs.
					local sig = ("%04x:%03x"):format(mb, hb % 4096)
					if sigs[unitID] ~= sig then
						sigs[unitID] = sig
						parts = parts + 1
						syncParts[parts] = unitID .. ":" .. sig
					end
				end
			end
			for unitID, last in pairs(seen) do
				if last ~= n then
					seen[unitID], sigs[unitID] = nil, nil
					parts = parts + 1
					syncParts[parts] = "-" .. unitID
				end
			end
			if count > 0 or teamID ~= gaiaTeam then
				local metal  = spGetTeamResources(teamID, "metal")
				local energy = spGetTeamResources(teamID, "energy")
				ta, tb = MixFloat(ta, tb, metal)
				ta, tb = MixFloat(ta, tb, energy)
				Write(("J %d %d %d %.9g %.9g %04x%04x"):format(n, teamID, count, metal or -1, energy or -1, ta, tb))
				if parts > 0 then
					Write(("I %d %d %s"):format(n, teamID, table.concat(syncParts, " ", 1, parts)))
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Feed from the gadget (dbg_game_recorder_feed.lua)
--------------------------------------------------------------------------------

local function Name(unitDefID)
	return (unitDefID and unitDefID >= 0 and defName[unitDefID]) or "-"
end

local function Feed(kind, f, a, b, c, d, e, g, h)
	if not file then return end
	if not feedSeen then
		feedSeen = true
		Write(("X %d feed"):format(f or 0))
	end

	if kind == "kill" then
		-- f, uid, team, defID, fin, killerUid, killerTeam, killerDefID
		local uid, team, defID, fin, kUid, kTeam, kDef = a, b, c, d, e, g, h
		if fin == 1 and kTeam and kTeam >= 0 and kTeam ~= team and killedMetal[kTeam]
				and not morphedAway[uid] then
			killedMetal[kTeam] = killedMetal[kTeam] + (defMetal[defID] or 0)
		end
		if Recording(team) or Recording(kTeam) then
			Write(("K %d %d %d %s %d %s %s %s"):format(f, uid, team, Name(defID), fin,
				(kUid and kUid >= 0) and tostring(kUid) or "-",
				(kTeam and kTeam >= 0) and tostring(kTeam) or "-", Name(kDef)))
		end

	elseif kind == "morph" then
		-- f, oldUid, newUid
		local oldUid, newUid = a, b
		morphedAway[oldUid] = true
		local team = unitTeamOf[newUid] or unitTeamOf[oldUid] or Spring.GetUnitTeam(newUid) or -1
		if team == -1 or Recording(team) then
			Write(("M %d %d %d %d %s %s"):format(f, oldUid, newUid, team,
				Name(unitDefOf[oldUid] or spGetUnitDefID(oldUid)),
				Name(unitDefOf[newUid] or spGetUnitDefID(newUid))))
		end

	elseif kind == "dmg" then
		-- f, attackerTeam, victimTeam, damage, paralyze, pairs
		if Recording(a) or Recording(b) then
			Write(("V %d %d %d %d %d %s"):format(f, a, b, c, d, e or ""))
		end

	elseif kind == "ord" then
		-- f, team, orders
		if Recording(a) then Write(("O %d %d %s"):format(f, a, b or "")) end

	elseif kind == "sys" then
		-- f, team, rp, weapons, armor, tech
		if Recording(a) then Write(("Y %d %d %d %d %d %d"):format(f, a, b, c, d, e)) end

	elseif kind == "log" then
		-- f, team, tag, text
		if a == -1 or Recording(a) then
			if b == "simpleai" then feedTrace[a] = true end
			Write(("L %d %d %s %s"):format(f, a, Clean(b), tostring(c or "")))
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

	wreckNX = math.max(1, math.ceil(Game.mapSizeX / WRECK_CELL))

	teamList = Spring.GetTeamList()
	for i = 1, #teamList do
		local teamID = teamList[i]
		if not ONLY_TEAMS or ONLY_TEAMS[teamID] then
			nUnits[teamID], nBuildings[teamID], nArmy[teamID] = 0, 0, 0
			builders[teamID] = {}
			mobiles[teamID] = {}
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
	widgetHandler:RegisterGlobal("SFRecFeed", Feed)

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
	widgetHandler:DeregisterGlobal("SFRecFeed")
	CloseFile()
end

function widget:GameFrame(n)
	if not file then return end
	-- The game is over: stop a moment later (so the gadget's last tallies
	-- land) instead of logging hours of an abandoned game.
	if stopAtFrame and n >= stopAtFrame then
		Write(("X %d stopped"):format(n))
		CloseFile()
		return
	end
	if n % SNAPSHOT_FRAMES == 0 then Snapshot(n) end
	if n % POSITION_FRAMES == 0 then Positions(n) end
	if n % WRECK_FRAMES == 0 then Wrecks(n) end
	if SYNC_FRAMES > 0 and n % SYNC_FRAMES == 0 then Fingerprint(n) end
end

function widget:GameStart()
	if file then WriteStarts() end
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
	local cost    = defMetal[unitDefID] or 0
	local morphed = morphedAway[unitID]
	morphedAway[unitID] = nil
	if finished and not morphed and lostMetal[unitTeam] then
		lostMetal[unitTeam] = lostMetal[unitTeam] + cost
	end
	-- Kill credit comes from the feed (K) when it is running; this is the
	-- fallback for engines that pass the attacker to widgets and no feed.
	if finished and not feedSeen and attackerTeam and attackerTeam ~= unitTeam and killedMetal[attackerTeam] then
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
	if STOP_AT_GAME_OVER then stopAtFrame = n + STOP_GRACE end
end
