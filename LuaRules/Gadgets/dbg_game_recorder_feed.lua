--------------------------------------------------------------------------------
-- Game Recorder Feed
--
-- The gadget half of the game recorder (LuaUI/Widgets/dbg_game_recorder.lua).
-- A widget only sees what the engine chooses to tell LuaUI; this gadget sits
-- inside the simulation and sees the rest: who killed what, who damaged whom,
-- every order given, and the state of game systems that live in other gadgets.
-- It collects that and hands it to the recorder widget, which writes the file.
--
-- WHAT IT PROVIDES
--   kill     every unit death with its killer (unit, type, team)
--   dmg      damage dealt, per attacker team -> victim team, with the unit-type
--            pairs that did most of it; tallied and sent every FLUSH frames,
--            never per hit
--   ord      orders given, counted by command per team, every FLUSH frames
--   sys      per team every FLUSH frames: research points, weapon and armor
--            upgrade levels, tech level
--   morph    unit A became unit B (so an upgrade is not read as a death)
--   log      free-form lines from any other gadget, through GG.Recorder.Log
--
-- LOGGING FROM ANOTHER GADGET (synced code)
--   if GG.Recorder then GG.Recorder.Log(teamID, "mytag", "any text") end
--   teamID may be nil for lines that belong to no team. The line lands in the
--   recording as:  L <frame> <team> <tag> <text>
--
-- WHO RECEIVES IT
--   Only a spectator with full view, or anyone watching a replay. A player in
--   a live game gets nothing, so this cannot be used to see through the fog.
--
-- COST
--   Always on, so that any replay of any game can be recorded after the fact.
--   The simulation side only bumps counters; strings are built once per FLUSH.
--   Nothing here changes the simulation. Set ENABLED = false to remove it.
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name    = "Game Recorder Feed",
		desc    = "Feeds kills, damage, orders and game-system state to the Game Recorder widget",
		author  = "SplinterFaction",
		date    = "2026",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true,
	}
end

local ENABLED    = true
local FLUSH      = 300   -- frames between tally flushes (~10s)
local TOP_PAIRS  = 12    -- unit-type pairs listed per team pair in a damage flush
local PAIR_BASE  = 100000   -- attackerDef * PAIR_BASE + victimDef packs a pair into one number

if not ENABLED then return false end

--------------------------------------------------------------------------------
if gadgetHandler:IsSyncedCode() then
--------------------------------------------------------------------------------

	local spGetGameFrame = Spring.GetGameFrame

	-- Shared logging hook. Defined at load, not in Initialize, so it exists
	-- for every other gadget regardless of load order.
	GG.Recorder = GG.Recorder or {}
	function GG.Recorder.Log(teamID, tag, text)
		SendToUnsynced("sfrec_log", spGetGameFrame(), teamID or -1, tostring(tag), tostring(text))
	end

	local gaiaTeam = Spring.GetGaiaTeamID()

	-- damage[attackerTeam][victimTeam] = { total =, para =, pairs = { [packedPair] = damage } }
	local damage = {}
	-- orders[teamID] = { [cmdKey] = count }
	local orders = {}

	-- [cmdID] = short name (cached). Custom commands from other gadgets have no
	-- engine name; the ones worth reading are named here, the rest show as CMD<id>.
	local cmdName = {
		[34410] = "MORPH",         -- unit_morph.lua CMD_MORPH_QUEUE
		[35410] = "BUILD_BOOST",   -- unit_research_buildboost.lua CMD_BUILD_BOOST
	}
	local function CmdKey(cmdID)
		if cmdID < 0 then return "BUILD" end
		local name = cmdName[cmdID]
		if not name then
			name = CMD[cmdID]
			if type(name) ~= "string" then name = "CMD" .. cmdID end
			cmdName[cmdID] = name
		end
		return name
	end

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
		local finished = not Spring.GetUnitIsBeingBuilt(unitID)
		SendToUnsynced("sfrec_kill", spGetGameFrame(), unitID, unitTeam, unitDefID, finished and 1 or 0,
			attackerID or -1, attackerTeam or -1, attackerDefID or -1)
	end

	function gadget:UnitDamaged(unitID, unitDefID, unitTeam, dmg, paralyzer, weaponDefID, projectileID,
	                            attackerID, attackerDefID, attackerTeam)
		if not dmg or dmg <= 0 then return end
		local aTeam = attackerTeam or -1
		local byAttacker = damage[aTeam]
		if not byAttacker then byAttacker = {}; damage[aTeam] = byAttacker end
		local cell = byAttacker[unitTeam]
		if not cell then cell = { total = 0, para = 0, pairs = {} }; byAttacker[unitTeam] = cell end
		if paralyzer then
			cell.para = cell.para + dmg
		else
			cell.total = cell.total + dmg
		end
		local key = (attackerDefID or 0) * PAIR_BASE + unitDefID
		cell.pairs[key] = (cell.pairs[key] or 0) + dmg
	end

	function gadget:UnitCommand(unitID, unitDefID, unitTeam, cmdID)
		local t = orders[unitTeam]
		if not t then t = {}; orders[unitTeam] = t end
		local key = CmdKey(cmdID)
		t[key] = (t[key] or 0) + 1
	end

	local function TechLevel(teamID)
		local level = 0
		for n = 1, 4 do
			local v = Spring.GetTeamRulesParam(teamID, "technology:tech" .. n)
			if v and v > 0 then level = n end
		end
		return level
	end

	local sortScratch = {}
	local function FlushDamage(n)
		for aTeam, byAttacker in pairs(damage) do
			for vTeam, cell in pairs(byAttacker) do
				if cell.total > 0 or cell.para > 0 then
					local count = 0
					for key, dmg in pairs(cell.pairs) do
						count = count + 1
						local e = sortScratch[count]
						if not e then e = {}; sortScratch[count] = e end
						e.key, e.dmg = key, dmg
					end
					for i = count + 1, #sortScratch do sortScratch[i] = nil end
					table.sort(sortScratch, function(a, b)
						if a.dmg ~= b.dmg then return a.dmg > b.dmg end
						return a.key < b.key
					end)
					local parts = {}
					for i = 1, math.min(TOP_PAIRS, count) do
						local e = sortScratch[i]
						local aDef = math.floor(e.key / PAIR_BASE)
						local vDef = e.key - aDef * PAIR_BASE
						local aName = (UnitDefs[aDef] and UnitDefs[aDef].name) or "?"
						local vName = (UnitDefs[vDef] and UnitDefs[vDef].name) or "?"
						parts[i] = aName .. ">" .. vName .. ":" .. math.floor(e.dmg + 0.5)
					end
					SendToUnsynced("sfrec_dmg", n, aTeam, vTeam,
						math.floor(cell.total + 0.5), math.floor(cell.para + 0.5), table.concat(parts, " "))
					cell.total, cell.para = 0, 0
					for key in pairs(cell.pairs) do cell.pairs[key] = nil end
				end
			end
		end
	end

	local keyScratch = {}
	local function FlushOrders(n)
		for teamID, t in pairs(orders) do
			local count = 0
			for key in pairs(t) do count = count + 1; keyScratch[count] = key end
			if count > 0 then
				for i = count + 1, #keyScratch do keyScratch[i] = nil end
				table.sort(keyScratch)
				for i = 1, count do
					local key = keyScratch[i]
					keyScratch[i] = key .. ":" .. t[key]
					t[key] = nil
				end
				SendToUnsynced("sfrec_ord", n, teamID, table.concat(keyScratch, " "))
			end
		end
	end

	local function FlushSystems(n)
		local teams = Spring.GetTeamList()
		for i = 1, #teams do
			local teamID = teams[i]
			if teamID ~= gaiaTeam then
				local rp = (GG.Research and GG.Research.Get and GG.Research.Get(teamID)) or -1
				local w, a = -1, -1
				if GG.TeamUpgrades and GG.TeamUpgrades.GetLevel then
					w = GG.TeamUpgrades.GetLevel(teamID, "weapons") or -1
					a = GG.TeamUpgrades.GetLevel(teamID, "armor") or -1
				end
				SendToUnsynced("sfrec_sys", n, teamID, math.floor(rp), w, a, TechLevel(teamID))
			end
		end
	end

	function gadget:GameFrame(n)
		if n % FLUSH ~= 0 then return end
		FlushDamage(n)
		FlushOrders(n)
		FlushSystems(n)
	end

	function gadget:GameOver()
		local n = spGetGameFrame()
		FlushDamage(n)
		FlushOrders(n)
		FlushSystems(n)
	end

--------------------------------------------------------------------------------
else  -- UNSYNCED
--------------------------------------------------------------------------------

	-- Hand a record to the recorder widget, if one is listening and this
	-- viewer is allowed to see everything.
	local function Forward(kind, ...)
		if not Script.LuaUI("SFRecFeed") then return end
		local _, fullView = Spring.GetSpectatingState()
		if not (fullView or Spring.IsReplay()) then return end
		Script.LuaUI.SFRecFeed(kind, ...)
	end

	local function OnKill(_, ...)  Forward("kill", ...) end
	local function OnDmg(_, ...)   Forward("dmg", ...)  end
	local function OnOrd(_, ...)   Forward("ord", ...)  end
	local function OnSys(_, ...)   Forward("sys", ...)  end
	local function OnLog(_, ...)   Forward("log", ...)  end
	-- unit_morph.lua announces a finished morph as ("unit_morph_finished", oldID, newID)
	local function OnMorph(_, oldID, newID)
		if oldID and newID and oldID ~= newID then
			Forward("morph", Spring.GetGameFrame(), oldID, newID)
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("sfrec_kill", OnKill)
		gadgetHandler:AddSyncAction("sfrec_dmg",  OnDmg)
		gadgetHandler:AddSyncAction("sfrec_ord",  OnOrd)
		gadgetHandler:AddSyncAction("sfrec_sys",  OnSys)
		gadgetHandler:AddSyncAction("sfrec_log",  OnLog)
		gadgetHandler:AddSyncAction("unit_morph_finished", OnMorph)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("sfrec_kill")
		gadgetHandler:RemoveSyncAction("sfrec_dmg")
		gadgetHandler:RemoveSyncAction("sfrec_ord")
		gadgetHandler:RemoveSyncAction("sfrec_sys")
		gadgetHandler:RemoveSyncAction("sfrec_log")
		gadgetHandler:RemoveSyncAction("unit_morph_finished")
	end

end
