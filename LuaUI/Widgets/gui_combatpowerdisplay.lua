function widget:GetInfo()
	return {
		name    = "Combat Power Display",
		desc    = "Displays aggregated Combat Power and implements persistence (handled unsynced)",
		author  = "",
		date    = "2025-03-25",
		license = "GNU GPL v2",
		layer   = 0,
		enabled = false,
	}
end

--------------------------------------------------------------------------------
-- Persistent Data Setup (for local player's CP)
--------------------------------------------------------------------------------
local persistentDataFile = "LuaUI/data/combat_power_data.lua"
local persistentCP = {}   -- persistent CP values (keyed by player name)
local localCP = 0         -- current CP for the local player (loaded from persistent file)
local localBaseline = 0   -- starting CP for this game (for local player)

-- Utility: Convert a table to a Lua string for saving
local function TableToString(tbl)
	local s = "{"
	for k, v in pairs(tbl) do
		s = s .. "[" .. string.format("%q", k) .. "]=" .. tostring(v) .. ","
	end
	s = s .. "}"
	return s
end

local function loadPersistentData()
	local file = io.open(persistentDataFile, "r")
	if file then
		local contents = file:read("*a")
		file:close()
		local func = loadstring(contents)
		if func then
			persistentCP = func() or {}
		else
			persistentCP = {}
		end
	else
		persistentCP = {}
	end
end

local function savePersistentData()
	local file = io.open(persistentDataFile, "w")
	if file then
		file:write("return " .. TableToString(persistentCP))
		file:close()
	end
end

--------------------------------------------------------------------------------
-- Local Player Identification & Initialization
--------------------------------------------------------------------------------
local localPlayerID = Spring.GetLocalPlayerID()
local localPlayerName = select(1, Spring.GetPlayerInfo(localPlayerID)) or "Unknown"

loadPersistentData()
if persistentCP[localPlayerName] == nil then
	persistentCP[localPlayerName] = 0
	savePersistentData()
end
localCP = persistentCP[localPlayerName]
localBaseline = localCP

-- Send an initialization message to the gadget so it knows our starting CP.
Spring.SendLuaRulesMsg("CPINIT:" .. localPlayerName .. ":" .. localCP)

--------------------------------------------------------------------------------
-- GUI Setup using Chili
--------------------------------------------------------------------------------
local Chili
local cpPanel
local cpLabels = {}  -- table: playerName -> Chili label

local function createCPPanel()
	cpPanel = Chili.Window:New{
		parent    = Chili.Screen0,
		x         = "80%",
		y         = "10%",
		width     = "15%",
		height    = "30%",
		caption   = "Combat Power",
		draggable = true,
		resizable = false,
		backgroundColor = {0, 0, 0, 0.85},
		font = { color = {1,1,1,1}, size = 16 },
	}
end

-- Update the panel by iterating through active players.
local function updateCPPanel()
	local players = Spring.GetPlayerList()
	local yPos = 30
	for _, playerID in ipairs(players) do
		local name, active, spec, teamID = Spring.GetPlayerInfo(playerID)
		if active and not spec then
			-- Get team color (values from 0 to 1)
			local r, g, b, a = Spring.GetTeamColor(teamID)
			local ir = math.floor(r * 255)
			local ig = math.floor(g * 255)
			local ib = math.floor(b * 255)
			local colorCode = "\255" .. string.char(ir, ig, ib)
			local whiteCode = "\255" .. string.char(255,255,255)
			local cpValue = Spring.GetGameRulesParam("combatPower_" .. name) or 0
			local caption = colorCode .. name .. whiteCode .. ": " .. cpValue
			if not cpLabels[name] then
				cpLabels[name] = Chili.Label:New{
					parent  = cpPanel,
					caption = caption,
					x       = 5,
					y       = yPos,
					width   = "100%",
					height  = 25,
					font    = { color = {1, 1, 1, 1}, size = 24 },
				}
			else
				cpLabels[name]:SetCaption(caption)
				cpLabels[name]:SetPos(5, yPos)
			end
			yPos = yPos + 30
		end
	end
end


--------------------------------------------------------------------------------
-- Widget GameOver: Save final CP to persistent file.
--------------------------------------------------------------------------------
function widget:GameOver()
	-- Get final CP for our local player from game-rules params.
	local finalCP = Spring.GetGameRulesParam("combatPower_" .. localPlayerName) or localCP
	persistentCP[localPlayerName] = finalCP
	savePersistentData()
end

--------------------------------------------------------------------------------
-- Widget Initialization
--------------------------------------------------------------------------------
function widget:Initialize()
	Chili = WG.Chili
	if not Chili then
		widgetHandler:RemoveWidget(self)
		return
	end
	createCPPanel()
end

--------------------------------------------------------------------------------
-- Update: Refresh the panel every 0.5 seconds.
--------------------------------------------------------------------------------
local updateTimer = 0
function widget:Update(dt)
	updateTimer = updateTimer + dt
	if updateTimer >= 0.5 then
		updateCPPanel()
		updateTimer = 0
	end
end

function widget:Shutdown()
	persistentCP[localPlayerName] = Spring.GetGameRulesParam("combatPower_" .. localPlayerName) or localCP
	savePersistentData()
end
