--------------------------------------------------------------------------------
-- API Unit Tracker GL4 (SplinterFaction port)
--
-- Maintains two authoritative sets for the local player's point of view:
--   visibleUnits[unitID] = unitDefID   -- alive, in LOS (or fullview), not ignored
--   alliedUnits[unitID]  = unitDefID   -- subset of the above that is allied to me
--
-- Why this exists: GL4 widgets that bind instances to a unitID (healthbars,
-- deferred lights, highlights, ...) corrupt their instance VBOs if a unitID
-- goes stale. Every such widget needs the exact same add/remove bookkeeping,
-- including the awkward cases (spectator switching, fullview toggles, units
-- captured between two *other* teams, cheat-spawned units that fire
-- UnitCreated and UnitFinished back to back). Centralising it here means that
-- logic is written once.
--
-- Differences from BAR's api_unit_tracker_gl4.lua:
--   * BAR broadcasts VisibleUnitAdded/Removed/Changed through its widget
--     handler as custom callins. SF's handler does not have those, and
--     Script.LuaUI.X can only target a single global function. So listeners
--     register themselves explicitly:
--
--         function widget:Initialize()
--             WG.unittrackerapi.RegisterListener(widget)
--         end
--         function widget:Shutdown()
--             WG.unittrackerapi.UnregisterListener(widget)
--         end
--
--     and implement any of:
--         widget:VisibleUnitAdded(unitID, unitDefID, unitTeam, reason)
--         widget:VisibleUnitRemoved(unitID, unitDefID, unitTeam, reason)
--         widget:VisibleUnitsChanged(visibleUnits, numVisibleUnits)
--         widget:AlliedUnitAdded(unitID, unitDefID, unitTeam)
--         widget:AlliedUnitRemoved(unitID, unitDefID, unitTeam)
--         widget:AlliedUnitsChanged(alliedUnits, numAlliedUnits)
--
--     VisibleUnitsChanged is the "resync everything" signal: it is sent on
--     Initialize, on spectator/fullview/allyteam changes, and on Shutdown
--     (with empty tables). Listeners should drop all unit-bound state and
--     rebuild from the table they are handed.
--
--   * BAR's telemetry, desync reporting, and /execute debug commands are
--     removed. The debug overlay (DrawPrimitiveAtUnit) is removed as well;
--     SF's copy of that include carries a stale SSBO struct.
--
-- Original: Beherith, 2022, GNU GPL v2.
--------------------------------------------------------------------------------

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "API Unit Tracker GL4",
		desc = "Maintains visible/allied unit sets and notifies listener widgets",
		author = "Beherith (SF port)",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = -828888,
		enabled = true,
	}
end

--------------------------------------------------------------------------------

local spGetGameFrame = Spring.GetGameFrame
local spGetMyTeamID = Spring.GetLocalTeamID
local spGetMyAllyTeamID = Spring.GetLocalAllyTeamID
local spGetLocalPlayerID = Spring.GetLocalPlayerID
local spGetSpectatingState = Spring.GetSpectatingState
local spGetAllUnits = Spring.GetAllUnits
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitDefID = Spring.GetUnitDefID
local spValidUnitID = Spring.ValidUnitID
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetUnitLosState = Spring.GetUnitLosState
local spAreTeamsAllied = Spring.AreTeamsAllied
local spGetUnitHealth = Spring.GetUnitHealth
local spEcho = Spring.Echo

-- 0 = off, 1 = warn on inconsistencies, 2 = verbose
local debuglevel = 0

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local alliedUnits = {}
local alliedUnitsTeam = {}
local numAlliedUnits = 0

local visibleUnits = {}
local visibleUnitsTeam = {}
local numVisibleUnits = 0

-- unitDefIDs that should never be tracked. Anything listed here must also
-- never be pushed into a unit-bound VBO by a listener, because it will never
-- receive a Removed notification.
local unitDefIgnore = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams and unitDef.customParams.unittracker_ignore then
		unitDefIgnore[unitDefID] = true
	end
end

local gameFrame = spGetGameFrame()
local spec, fullview = spGetSpectatingState()
local myTeamID = spGetMyTeamID()
local myAllyTeamID = spGetMyAllyTeamID()
local myPlayerID = spGetLocalPlayerID()

--------------------------------------------------------------------------------
-- Listener dispatch
--------------------------------------------------------------------------------

local listeners = {} -- array of widget tables, in registration order
local listenerIndex = {} -- widget -> true

local function RegisterListener(w)
	if type(w) ~= "table" or listenerIndex[w] then
		return false
	end
	listeners[#listeners + 1] = w
	listenerIndex[w] = true
	return true
end

local function UnregisterListener(w)
	if not listenerIndex[w] then
		return false
	end
	listenerIndex[w] = nil
	for i = #listeners, 1, -1 do
		if listeners[i] == w then
			table.remove(listeners, i)
		end
	end
	return true
end

local function Dispatch(callinName, a, b, c, d)
	for i = 1, #listeners do
		local w = listeners[i]
		local fn = w[callinName]
		if fn then
			local ok, err = pcall(fn, w, a, b, c, d)
			if not ok then
				local info = w.GetInfo and w:GetInfo()
				spEcho(
					"[api_unit_tracker_gl4] listener error in "
						.. tostring(info and info.name or "?")
						.. ":"
						.. callinName
						.. ": "
						.. tostring(err)
				)
			end
		end
	end
end

local function visibleUnitsChanged()
	Dispatch("VisibleUnitsChanged", visibleUnits, numVisibleUnits)
end

local function alliedUnitsChanged()
	Dispatch("AlliedUnitsChanged", alliedUnits, numAlliedUnits)
end

--------------------------------------------------------------------------------
-- Set maintenance
--------------------------------------------------------------------------------

local function alliedUnitsAdd(unitID, unitDefID, unitTeam, silent)
	if alliedUnits[unitID] then
		return
	end
	alliedUnits[unitID] = unitDefID
	alliedUnitsTeam[unitID] = unitTeam
	numAlliedUnits = numAlliedUnits + 1
	if silent then
		return
	end
	Dispatch("AlliedUnitAdded", unitID, unitDefID, unitTeam)
end

local function alliedUnitsRemove(unitID, reason)
	if alliedUnits[unitID] then
		local unitDefID = alliedUnits[unitID]
		alliedUnits[unitID] = nil
		local unitTeam = alliedUnitsTeam[unitID]
		alliedUnitsTeam[unitID] = nil
		numAlliedUnits = numAlliedUnits - 1
		Dispatch("AlliedUnitRemoved", unitID, unitDefID, unitTeam, reason)
	end
end

local function visibleUnitsAdd(unitID, unitDefID, unitTeam, silent, reason)
	if visibleUnits[unitID] then
		return
	end
	visibleUnits[unitID] = unitDefID
	visibleUnitsTeam[unitID] = unitTeam
	numVisibleUnits = numVisibleUnits + 1
	if silent then
		return
	end
	Dispatch("VisibleUnitAdded", unitID, unitDefID, unitTeam, reason)
end

local function visibleUnitsRemove(unitID, reason)
	if visibleUnits[unitID] then
		local unitDefID = visibleUnits[unitID]
		visibleUnits[unitID] = nil
		local unitTeam = visibleUnitsTeam[unitID]
		visibleUnitsTeam[unitID] = nil
		numVisibleUnits = numVisibleUnits - 1
		Dispatch("VisibleUnitRemoved", unitID, unitDefID, unitTeam, reason)
	end
end

local function isValidLivingSeenUnit(unitID, unitDefID)
	if unitDefID == nil then
		return false
	end
	if spValidUnitID(unitID) ~= true then
		return false
	end
	if spGetUnitIsDead(unitID) == true then
		return false
	end
	if unitDefIgnore[unitDefID] then
		return false
	end
	-- LOS state bit 1 = in LOS
	if (not fullview) and (spGetUnitLosState(unitID, myAllyTeamID, true) % 2 == 0) then
		return false
	end
	return true
end

--------------------------------------------------------------------------------
-- Engine callins
--------------------------------------------------------------------------------

function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID, reason, silent)
	-- On game start the engine may reset our allyteam without a PlayerChanged.
	if gameFrame <= 0 and not fullview then
		if myAllyTeamID ~= spGetMyAllyTeamID() then
			widget:PlayerChanged()
		end
	end

	unitDefID = unitDefID or spGetUnitDefID(unitID)
	if not isValidLivingSeenUnit(unitID, unitDefID) then
		return
	end

	-- Cheated/spawned units fire UnitCreated then UnitFinished immediately,
	-- at full health with buildProgress 0. Skip the Created half; the
	-- Finished half (which does a remove+add) will register the unit.
	local health, maxhealth, _, _, buildProgress = spGetUnitHealth(unitID)
	if health == maxhealth and buildProgress == 0 then
		return
	end

	if spAreTeamsAllied(unitTeam, myTeamID) then
		alliedUnitsAdd(unitID, unitDefID, unitTeam, silent)
	end
	if visibleUnits[unitID] == nil then
		visibleUnitsAdd(unitID, unitDefID, unitTeam, silent, reason)
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID, reason)
	visibleUnitsRemove(unitID, reason or "UnitDestroyed")
	alliedUnitsRemove(unitID, reason or "UnitDestroyed")
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	widget:UnitDestroyed(unitID, unitDefID, unitTeam, nil, nil, nil, nil, "UnitFinished")
	widget:UnitCreated(unitID, unitDefID, unitTeam, nil, "UnitFinished")
end

function widget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
	-- One of my units was captured. UnitEnteredLos follows if we still see it.
	widget:UnitDestroyed(unitID, unitDefID, oldTeam, nil, nil, nil, nil, "UnitTaken")
end

function widget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	-- My team captured a unit. Remove + add so team-coloured listeners refresh.
	widget:UnitDestroyed(unitID, unitDefID, oldTeam, nil, nil, nil, nil, "UnitGiven")
	widget:UnitCreated(unitID, unitDefID, newTeam, nil, "UnitGiven")
end

function widget:UnitEnteredLos(unitID, unitTeam, allyTeam, unitDefID)
	if not fullview then
		widget:UnitCreated(unitID, unitDefID, unitTeam, nil, "UnitEnteredLos")
	end
end

function widget:UnitLeftLos(unitID, unitTeam, allyTeam, unitDefID)
	if not fullview then
		widget:UnitDestroyed(unitID, unitDefID, unitTeam, nil, nil, nil, nil, "UnitLeftLos")
	end
end

function widget:GameFrame(n)
	gameFrame = n
	if debuglevel >= 1 and n % 60 == 0 then
		local cnt = 0
		for unitID, unitDefID in pairs(visibleUnits) do
			if isValidLivingSeenUnit(unitID, unitDefID) then
				cnt = cnt + 1
			else
				spEcho("[api_unit_tracker_gl4] stale unit in visibleUnits:", unitID, UnitDefs[unitDefID] and UnitDefs[unitDefID].name)
			end
		end
		if cnt ~= numVisibleUnits then
			spEcho("[api_unit_tracker_gl4] visible count mismatch", cnt, numVisibleUnits)
		end
	end
end

--------------------------------------------------------------------------------
-- (Re)initialisation
--------------------------------------------------------------------------------

local function publishTables()
	WG.unittrackerapi.visibleUnits = visibleUnits
	WG.unittrackerapi.visibleUnitsTeam = visibleUnitsTeam
	WG.unittrackerapi.alliedUnits = alliedUnits
	WG.unittrackerapi.alliedUnitsTeam = alliedUnitsTeam
end

local function initializeAllUnits()
	alliedUnits = {}
	alliedUnitsTeam = {}
	numAlliedUnits = 0
	visibleUnits = {}
	visibleUnitsTeam = {}
	numVisibleUnits = 0

	local allunits = spGetAllUnits()
	for i = 1, #allunits do
		local unitID = allunits[i]
		widget:UnitCreated(unitID, spGetUnitDefID(unitID), spGetUnitTeam(unitID), nil, "initializeAllUnits", true)
	end

	publishTables()
	visibleUnitsChanged()
	alliedUnitsChanged()
end

function widget:PlayerChanged(playerID)
	local currentspec, currentfullview = spGetSpectatingState()
	local currentAllyTeamID = spGetMyAllyTeamID()
	local currentTeamID = spGetMyTeamID()
	local currentPlayerID = spGetLocalPlayerID()

	local reinit = (currentspec ~= spec)
		or (currentfullview ~= fullview)
		or ((currentAllyTeamID ~= myAllyTeamID) and not currentfullview)

	spec = currentspec
	fullview = currentfullview
	myAllyTeamID = currentAllyTeamID
	myTeamID = currentTeamID
	myPlayerID = currentPlayerID

	if reinit then
		initializeAllUnits()
	end
end

function widget:Initialize()
	gameFrame = spGetGameFrame()
	spec, fullview = spGetSpectatingState()
	myTeamID = spGetMyTeamID()
	myAllyTeamID = spGetMyAllyTeamID()
	myPlayerID = spGetLocalPlayerID()

	WG.unittrackerapi = {
		RegisterListener = RegisterListener,
		UnregisterListener = UnregisterListener,
		GetVisibleUnits = function()
			return visibleUnits, numVisibleUnits
		end,
		GetAlliedUnits = function()
			return alliedUnits, numAlliedUnits
		end,
		IsIgnoredUnitDef = function(unitDefID)
			return unitDefIgnore[unitDefID] == true
		end,
	}
	initializeAllUnits()
end

function widget:Shutdown()
	-- Hand listeners empty tables so they release every unit-bound instance.
	alliedUnits = {}
	alliedUnitsTeam = {}
	numAlliedUnits = 0
	visibleUnits = {}
	visibleUnitsTeam = {}
	numVisibleUnits = 0
	if WG.unittrackerapi then
		publishTables()
	end
	visibleUnitsChanged()
	alliedUnitsChanged()
	listeners = {}
	listenerIndex = {}
	WG.unittrackerapi = nil
end
