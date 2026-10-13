--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Chat of the RmlUi HUD: the newest chat lines, low in the middle of the
--  screen, with team-colored player names and a color per channel. Lines fade
--  out after a while. The engine's own console is switched off.
--
--  This widget is also where chat is read: every console line is parsed here
--  and kept (WG.Chatterbox) for the Log window, which shows the whole history.
--  Speed changes and pauses are shown as chat lines too; a burst of speed
--  steps is collapsed into one line.
--
--  Replaces gui_ChatterboxChat.lua (kept in Widgets/disabled/). The parsing is
--  carried over unchanged.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name    = "Chat",
		desc    = "Chat lines with team-colored player names and a color per channel; feeds the Log window (RmlUi)",
		author  = "SplinterFaction Team",
		date    = "2026-10-13",
		license = "GPL v2 or later",
		layer   = 0,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- config
--------------------------------------------------------------------------------

local DOCUMENT_PATH = "LuaUI/rml/chat.rml"

-- must match #chat in chat.rml
local BOX_WIDTH  = 650
local BOX_HEIGHT = 200
-- the bottom of the box, as a share of the screen's height from the bottom
local BOX_BOTTOM_FRAC = 0.10

local LAYOUT_NAME = "chat"

local MAX_LINES            = 6       -- messages shown at once
local LINE_LIFETIME        = 10      -- seconds before fade starts
local FADE_TIME            = 6       -- seconds of fadeout
local FADE_STEPS           = 20      -- the fade moves in this many steps, not every frame
local HIDE_DEFAULT_CONSOLE = true    -- hide the engine's console/chat

-- Persistent scrollback shared with the Log window (gui_rml_log.lua).
-- Every parsed line is appended here regardless of channel; the floating overlay
-- still only shows actual chat. MAX_LOG caps retained history.
local MAX_LOG  = 1000
local LOG_SLACK = 64   -- compact in chunks so trimming is amortized, not per-line

-- Game events (speed changes, pause/unpause) surfaced in chat as channel "event".
local SHOW_SPEED_CHANGES = true
local SHOW_PAUSE_EVENTS  = true

-- Rapid speed steps (e.g. dragging the speed slider) arrive as dozens of
-- "Speed set to X" lines in under a second. Collapse a burst into a single
-- message showing the final value once no new speed line has arrived for this
-- many real-time seconds.
local SPEED_DEBOUNCE     = 0.6

--------------------------------------------------------------------------------
-- speedups and state
--------------------------------------------------------------------------------

local spGetPlayerList   = Spring.GetPlayerList
local spGetPlayerInfo   = Spring.GetPlayerInfo
local spGetTeamColor    = Spring.GetTeamColor
local spSendCommands    = Spring.SendCommands
local spGetGameSeconds  = Spring.GetGameSeconds

local hud
local document
local view

local chatLines = {}   -- the lines on screen, oldest first
local fullLog   = {}   -- persistent scrollback (all channels); read by the Log panel
local serial    = 0    -- numbers the lines, for their element ids
local shownSignature = ""

local pendingSpeed  = nil   -- coalesced speed-change entry awaiting flush
local pendingSpeedT = 0     -- os.clock() of the last speed line seen

local myPlayerNames = {}      -- lowercase name -> true for local user(s)
local cachedPlayerData = {}   -- lowercase name -> {name=..., teamID=..., isSpec=..., color={r,g,b,1}}

--------------------------------------------------------------------------------
-- colors. The floating lines are colored by their channel's class in chat.rml;
-- these are what the Log window uses for the same lines.
--------------------------------------------------------------------------------

local COLOR_PUBLIC  = {0.94, 0.96, 0.97, 1.00}
local COLOR_ALLY    = {0.44, 0.86, 0.55, 1.00}
local COLOR_WHISPER = {1.00, 0.45, 0.40, 1.00}
local COLOR_SPEC    = {0.95, 0.84, 0.29, 1.00}
local COLOR_SYSTEM  = {0.52, 0.58, 0.63, 1.00}
local COLOR_EVENT   = {0.37, 0.82, 0.91, 1.00}   -- speed / pause game events

--------------------------------------------------------------------------------
-- helpers (carried over)
--------------------------------------------------------------------------------

local function Lower(s)
	return s and string.lower(s) or s
end

local function Trim(s)
	return (s and s:match("^%s*(.-)%s*$")) or ""
end

local function RefreshPlayerCache()
	cachedPlayerData = {}
	myPlayerNames = {}

	local players = spGetPlayerList()
	for i = 1, #players do
		local playerID = players[i]
		local name, active, isSpec, teamID = spGetPlayerInfo(playerID, false)
		if name then
			local r, g, b = 1, 1, 1
			if teamID then
				r, g, b = spGetTeamColor(teamID)
			end
			local key = Lower(name)
			cachedPlayerData[key] = {
				name   = name,
				active = active,
				isSpec = isSpec,
				teamID = teamID,
				color  = {r, g, b, 1},
			}
		end
	end

	local myPlayerID = Spring.GetMyPlayerID()
	if myPlayerID then
		local myName = spGetPlayerInfo(myPlayerID, false)
		if myName then
			myPlayerNames[Lower(myName)] = true
		end
	end
end

local function GetPlayerColorByName(name)
	local entry = cachedPlayerData[Lower(name or "")]
	if entry and entry.color then
		return entry.color
	end
	return {1, 1, 1, 1}
end

local function PushChatLine(data)
	serial = serial + 1
	data.time = os.clock()
	data.id   = serial
	chatLines[#chatLines + 1] = data
end

-- A line counts as "chat" (shown in the floating overlay and the Log panel's
-- Chat tab) when it is anything other than raw console output. Only the
-- fallback "system" channel is non-chat; map markers use their own "marker"
-- channel so they remain chat while still being distinguishable from console.
local function IsChat(entry)
	return entry ~= nil and entry.channel ~= "system"
end

local function AppendFullLog(entry)
	fullLog[#fullLog + 1] = entry
	local n = #fullLog
	if n >= MAX_LOG + LOG_SLACK then
		local drop = n - MAX_LOG
		for i = 1, n - drop do
			fullLog[i] = fullLog[i + drop]
		end
		for i = n - drop + 1, n do
			fullLog[i] = nil
		end
	end
end

-- Stamp, log, and (for chat) push to the floating overlay + play its sound.
-- Single choke point so both the console callin and the deferred speed flush
-- behave identically.
local function EmitEntry(entry)
	entry.gtime = spGetGameSeconds and math.floor(spGetGameSeconds()) or 0
	AppendFullLog(entry)

	if not IsChat(entry) then return end

	PushChatLine(entry)

	if entry.player then
		if entry.channel == "whisper" then
			Spring.PlaySoundFile("chat", 1.0, "ui")
		elseif entry.channel == "ally" then
			Spring.PlaySoundFile("allychat", 1.0, "ui")
		elseif entry.channel == "spectator" then
			Spring.PlaySoundFile("specchat", 1.0, "ui")
		elseif entry.channel == "public" then
			Spring.PlaySoundFile("chat", 1.0, "ui")
		end
	end
end

--------------------------------------------------------------------------------
-- chat parsing (carried over)
--------------------------------------------------------------------------------

local function ParseChatLine(line)
	if not line or line == "" then
		return nil
	end

	local raw = line
	local text = Trim(line)

	-- <Player> Spectators: message
	do
		local player, body = text:match("^<([^>]+)>%s*Spectators:%s*(.*)$")
		if player then
			return {
				channel   = "spectator",
				player    = player,
				nameColor = GetPlayerColorByName(player),
				bodyColor = COLOR_SPEC,
				body      = body,
				raw       = raw,
			}
		end
	end

	-- <Player> Allies: message
	do
		local player, body = text:match("^<([^>]+)>%s*Allies:%s*(.*)$")
		if player then
			return {
				channel   = "ally",
				player    = player,
				nameColor = GetPlayerColorByName(player),
				bodyColor = COLOR_ALLY,
				body      = body,
				raw       = raw,
			}
		end
	end

	-- Whisper examples
	do
		local player, body

		-- <Player> Whispers: message
		player, body = text:match("^<([^>]+)>%s*Whispers:%s*(.*)$")
		if player then
			return {
				channel   = "whisper",
				player    = player,
				nameColor = GetPlayerColorByName(player),
				bodyColor = COLOR_WHISPER,
				body      = body,
				raw       = raw,
			}
		end

		-- Whisper from Player: message
		player, body = text:match("^Whisper from ([^:]+):%s*(.*)$")
		if player then
			return {
				channel   = "whisper",
				player    = Trim(player),
				nameColor = GetPlayerColorByName(player),
				bodyColor = COLOR_WHISPER,
				body      = body,
				raw       = raw,
			}
		end

		-- To Player: message
		player, body = text:match("^To ([^:]+):%s*(.*)$")
		if player then
			return {
				channel   = "whisper",
				player    = Trim(player),
				nameColor = GetPlayerColorByName(player),
				bodyColor = COLOR_WHISPER,
				body      = body,
				raw       = raw,
			}
		end
	end

	-- Normal public chat: <Player> message
	do
		local player, body = text:match("^<([^>]+)>%s*(.*)$")
		if player then
			return {
				channel   = "public",
				player    = player,
				nameColor = GetPlayerColorByName(player),
				bodyColor = COLOR_PUBLIC,
				body      = body,
				raw       = raw,
			}
		end
	end

	-- Map marker: "playername added point:" / "playername added point: label text"
	do
		local player, label = text:match("^(.+) added point:%s*(.*)$")
		if player then
			local body = label ~= "" and "added point: " .. label or "added point:"
			return {
				channel   = "marker",
				player    = player,
				nameColor = GetPlayerColorByName(player),
				bodyColor = COLOR_ALLY,
				body      = body,
				raw       = raw,
			}
		end
	end

	-- Speed change: "Speed set to N [player]" (the trailing [player] is optional).
	-- The bracket is at the END here, so it never collides with the leading-[name]
	-- spectator form below.
	do
		local n, player = text:match("^Speed set to%s+([%d%.]+)%s+%[([^%]]+)%]%s*$")
		if not n then
			n = text:match("^Speed set to%s+([%d%.]+)%s*$")
		end
		if n then
			if player and player ~= "" then
				return {
					channel   = "event",
					eventKind = "speed",
					player    = Trim(player),
					nameColor = GetPlayerColorByName(player),
					bodyColor = COLOR_EVENT,
					separator = "",
					body      = "set speed to " .. n .. "x",
					raw       = raw,
				}
			end
			return {
				channel   = "event",
				eventKind = "speed",
				player    = nil,
				nameColor = nil,
				bodyColor = COLOR_EVENT,
				body      = "Speed set to " .. n .. "x",
				raw       = raw,
			}
		end
	end

	-- Pause / unpause: "<player> paused the game" / "<player> unpaused the game".
	-- Check unpaused first so it is never mistaken for a paused match.
	do
		local player = text:match("^(.-)%s+unpaused the game%s*$")
		if player and player ~= "" then
			return {
				channel   = "event",
				eventKind = "pause",
				player    = Trim(player),
				nameColor = GetPlayerColorByName(player),
				bodyColor = COLOR_EVENT,
				separator = "",
				body      = "unpaused the game",
				raw       = raw,
			}
		end
		player = text:match("^(.-)%s+paused the game%s*$")
		if player and player ~= "" then
			return {
				channel   = "event",
				eventKind = "pause",
				player    = Trim(player),
				nameColor = GetPlayerColorByName(player),
				bodyColor = COLOR_EVENT,
				separator = "",
				body      = "paused the game",
				raw       = raw,
			}
		end
	end

	-- Spectator chat: this engine renders it as "[PlayerName] message".
	-- The engine also emits bracketed status tags (e.g. "[com_ends] ...") that
	-- are NOT chat, so only accept the bracket form when the name matches a
	-- known player/spectator in the cache. Unknown tags fall through to system.
	do
		local player, body = text:match("^%[([^%]]+)%]%s*(.*)$")
		if player then
			local key = Lower(Trim(player))
			if cachedPlayerData[key] then
				return {
					channel   = "spectator",
					player    = Trim(player),
					nameColor = GetPlayerColorByName(player),
					bodyColor = COLOR_SPEC,
					body      = body,
					raw       = raw,
				}
			end
		end
	end

	-- Fallback/system line
	return {
		channel   = "system",
		player    = nil,
		nameColor = nil,
		bodyColor = COLOR_SYSTEM,
		body      = raw,
		raw       = raw,
	}
end

--------------------------------------------------------------------------------
-- showing
--------------------------------------------------------------------------------

-- 1 while a line is fresh, then down to 0 in FADE_STEPS steps
local function LineAlpha(entry, now)
	local age = now - entry.time
	if age <= LINE_LIFETIME then
		return 1
	end
	if age >= (LINE_LIFETIME + FADE_TIME) then
		return 0
	end
	return math.ceil((1 - ((age - LINE_LIFETIME) / FADE_TIME)) * FADE_STEPS) / FADE_STEPS
end

local function LineRML(entry)
	local body = hud.Escape(entry.body or "")
	if entry.player then
		local c = entry.nameColor or COLOR_PUBLIC
		return string.format('<div id="c%d" class="line %s"><span class="name" style="color: %s;">%s%s</span> %s</div>',
			entry.id, entry.channel, hud.ReadableColor(c[1], c[2], c[3]), hud.Escape(entry.player), hud.Escape(entry.separator or ":"), body)
	end
	return string.format('<div id="c%d" class="line %s">%s</div>', entry.id, entry.channel, body)
end

local function Refresh()
	local now = os.clock()
	-- drop what has faded out, keep the newest MAX_LINES
	local alive = {}
	for i = 1, #chatLines do
		if LineAlpha(chatLines[i], now) > 0 then
			alive[#alive + 1] = chatLines[i]
		end
	end
	while #alive > MAX_LINES do
		table.remove(alive, 1)
	end
	chatLines = alive

	-- the markup changes only when a line comes or goes
	local ids = {}
	for i = 1, #alive do
		ids[i] = alive[i].id
	end
	local signature = table.concat(ids, ",")
	if signature ~= shownSignature then
		shownSignature = signature
		local parts = {}
		for i = 1, #alive do
			parts[i] = LineRML(alive[i])
		end
		view.Element("chat").inner_rml = table.concat(parts)
		view.Forget()
	end
	for i = 1, #alive do
		view.SetStyle("c" .. alive[i].id, "opacity", string.format("%.2f", LineAlpha(alive[i], now)))
	end
end

--------------------------------------------------------------------------------
-- widget api
--------------------------------------------------------------------------------

local function DefaultOrigin(vsx, vsy, w, h, scale)
	return (vsx - w) * 0.5, vsy * BOX_BOTTOM_FRAC
end

local function Place()
	hud.PlacePanel(view.Element("chat"), LAYOUT_NAME, BOX_WIDTH, BOX_HEIGHT, DefaultOrigin)
end

function widget:PlayerChanged(playerID)
	RefreshPlayerCache()
end

function widget:TeamDied(teamID)
	RefreshPlayerCache()
end

function widget:Initialize()
	RefreshPlayerCache()

	if HIDE_DEFAULT_CONSOLE then
		spSendCommands("console 0")
	end

	-- Shared interface for the Log window (gui_rml_log.lua). It is offered even
	-- if the document below fails to load: the log does not need the overlay.
	WG.Chatterbox = {
		GetLog = function() return fullLog end,
		IsChat = IsChat,
	}

	local helpers = include("rml/hud.lua")
	local result, reason = helpers.LoadDocument(DOCUMENT_PATH, widget)
	if not result then
		Spring.Echo("[Chat] " .. tostring(reason))
		return
	end
	hud = helpers
	document = result
	view = hud.NewView(document)

	hud.RegisterPanel(LAYOUT_NAME, "Chat", Place)
	Place()
	hud.ShowPassive(document)
end

function widget:Shutdown()
	WG.Chatterbox = nil
	if HIDE_DEFAULT_CONSOLE then
		spSendCommands("console 1")
	end
	if hud then
		hud.UnregisterPanel(LAYOUT_NAME)
	end
	if document then
		document:Close()
		document = nil
	end
end

function widget:ViewResize()
	if hud and document then
		hud.UpdateScale()
		Place()
	end
end

function widget:AddConsoleLine(line, priority)
	local parsed = ParseChatLine(line)
	if not parsed then return end

	if parsed.channel == "event" then
		if parsed.eventKind == "speed" then
			if not SHOW_SPEED_CHANGES then
				-- Keep it in the log as plain console output, off the overlay.
				parsed.channel = "system"
				parsed.body    = parsed.raw
				EmitEntry(parsed)
				return
			end
			-- Coalesce a burst of rapid speed steps into one final message.
			pendingSpeed  = parsed
			pendingSpeedT = os.clock()
			return
		elseif parsed.eventKind == "pause" and not SHOW_PAUSE_EVENTS then
			parsed.channel = "system"
			parsed.body    = parsed.raw
			EmitEntry(parsed)
			return
		end
	end

	EmitEntry(parsed)
end

function widget:Update(dt)
	if pendingSpeed and (os.clock() - pendingSpeedT) >= SPEED_DEBOUNCE then
		local entry = pendingSpeed
		pendingSpeed = nil
		EmitEntry(entry)
	end
	if not document then
		return
	end
	-- chat stays on screen during the pregame flow: it matters in multiplayer
	if Spring.IsGUIHidden() then
		if shownSignature ~= "hidden" then
			shownSignature = "hidden"
			view.Element("chat").inner_rml = ""
		end
		return
	end
	-- idle cost stops here: nothing on screen and nothing to put there
	if #chatLines == 0 and shownSignature == "" then
		return
	end
	Refresh()
end
