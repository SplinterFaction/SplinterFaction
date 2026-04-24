function widget:GetInfo()
	return {
		name    = "ChatterboxChat",
		desc    = "Custom chat renderer with teamcolored player names and per-channel message colors",
		author  = "",
		date    = "2026-03-20",
		license = "GPL v2 or later",
		layer   = 0,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

local FONT_FILE            = "LuaUI/Fonts/Saira_SemiCondensed-SemiBold.ttf"
local FONT_SIZE            = 20
local FONT_OUTLINE_SIZE    = 0       -- Not Used
local MAX_LINES            = 6
local LINE_LIFETIME        = 10      -- seconds before fade starts
local FADE_TIME            = 6       -- seconds of fadeout
local PADDING_X            = 18
local PADDING_Y            = 500
local LINE_SPACING         = 25
local BG_PADDING           = 20
local NAME_BODY_GAP        = 6
local MAX_BOX_WIDTH        = 650
local DRAW_BACKGROUND      = false
local HIDE_DEFAULT_CONSOLE = true -- set true if you want to hide engine console/chat

--------------------------------------------------------------------------------
-- Speedups
--------------------------------------------------------------------------------

local spGetViewGeometry = Spring.GetViewGeometry
local spGetPlayerList   = Spring.GetPlayerList
local spGetPlayerInfo   = Spring.GetPlayerInfo
local spGetTeamColor    = Spring.GetTeamColor
local spIsGUIHidden     = Spring.IsGUIHidden
local spSendCommands    = Spring.SendCommands

local glColor = gl.Color
local glRect  = gl.Rect

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local font
local vsx, vsy = 0, 0
local chatLines = {}

local myPlayerNames = {}      -- lowercase name -> true for local user(s)
local cachedPlayerData = {}   -- lowercase name -> {name=..., teamID=..., isSpec=..., color={r,g,b,1}}

--------------------------------------------------------------------------------
-- Colors
--------------------------------------------------------------------------------

local COLOR_PUBLIC  = {1.00, 1.00, 1.00, 1.00}
local COLOR_ALLY    = {0.00, 1.00, 0.00, 1.00}
local COLOR_WHISPER = {1.00, 0.35, 0.35, 1.00}
local COLOR_SPEC    = {1.00, 1.00, 0.00, 1.00}
local COLOR_SYSTEM  = {0.75, 0.75, 0.75, 1.00}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function Lower(s)
	return s and string.lower(s) or s
end

local function Trim(s)
	return (s and s:match("^%s*(.-)%s*$")) or ""
end

local function RefreshViewGeometry()
	vsx, vsy = spGetViewGeometry()
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

local function MeasureText(text, size)
	return font:GetTextWidth(text) * size
end

local function WrapTextToWidth(text, maxWidth, size)
	if not text or text == "" then
		return {""}
	end

	local lines = {}
	local current = ""

	for word in text:gmatch("%S+") do
		local testLine
		if current == "" then
			testLine = word
		else
			testLine = current .. " " .. word
		end

		if MeasureText(testLine, size) <= maxWidth then
			current = testLine
		else
			if current ~= "" then
				lines[#lines + 1] = current
				current = word
			else
				-- single very long word fallback
				lines[#lines + 1] = word
				current = ""
			end
		end
	end

	if current ~= "" then
		lines[#lines + 1] = current
	end

	if #lines == 0 then
		lines[1] = ""
	end

	return lines
end

local function BuildWrappedEntry(entry)
	if not entry.player then
		local bodyLines = WrapTextToWidth(entry.body or "", MAX_BOX_WIDTH, FONT_SIZE)
		return {
			entry = entry,
			nameText = nil,
			separatorText = nil,
			bodyLines = bodyLines,
			nameWidth = 0,
			separatorWidth = 0,
			bodyX = 0,
			width = MAX_BOX_WIDTH,
			height = #bodyLines,
		}
	end

	local nameText = entry.player
	local separatorText = ":"

	local nameWidth = MeasureText(nameText, FONT_SIZE)
	local separatorWidth = MeasureText(separatorText, FONT_SIZE)
	local prefixWidth = nameWidth + separatorWidth + NAME_BODY_GAP

	local firstLineBodyWidth = math.max(40, MAX_BOX_WIDTH - prefixWidth)
	local wrappedBody = WrapTextToWidth(entry.body or "", firstLineBodyWidth, FONT_SIZE)

	-- re-wrap continuation lines to full continued width if desired
	-- here we keep continuation aligned under the message start
	local bodyX = prefixWidth
	local continuedWidth = math.max(40, MAX_BOX_WIDTH - bodyX)

	if #wrappedBody > 1 then
		local rebuilt = {wrappedBody[1]}
		local remaining = table.concat(wrappedBody, " ", 2)
		local continuationLines = WrapTextToWidth(remaining, continuedWidth, FONT_SIZE)
		for i = 1, #continuationLines do
			rebuilt[#rebuilt + 1] = continuationLines[i]
		end
		wrappedBody = rebuilt
	end

	local longestBodyWidth = 0
	for i = 1, #wrappedBody do
		local lineWidth = MeasureText(wrappedBody[i], FONT_SIZE)
		if lineWidth > longestBodyWidth then
			longestBodyWidth = lineWidth
		end
	end

	local totalWidth = math.min(
			MAX_BOX_WIDTH,
			math.max(
					prefixWidth + MeasureText(wrappedBody[1] or "", FONT_SIZE),
					bodyX + longestBodyWidth
			)
	)

	return {
		entry = entry,
		nameText = nameText,
		separatorText = separatorText,
		bodyLines = wrappedBody,
		nameWidth = nameWidth,
		separatorWidth = separatorWidth,
		bodyX = bodyX,
		width = totalWidth,
		height = #wrappedBody,
	}
end

local function PushChatLine(data)
	data.time    = os.clock()
	data.wrapped = BuildWrappedEntry(data)   -- compute once, reuse forever
	chatLines[#chatLines + 1] = data
end

--------------------------------------------------------------------------------
-- Chat parsing
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
				channel   = "system",
				player    = player,
				nameColor = GetPlayerColorByName(player),
				bodyColor = COLOR_ALLY,
				body      = body,
				raw       = raw,
			}
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
-- Engine Callins
--------------------------------------------------------------------------------

function widget:ViewResize()
	RefreshViewGeometry()
end

function widget:PlayerChanged(playerID)
	RefreshPlayerCache()
end

function widget:TeamDied(teamID)
	RefreshPlayerCache()
end

function widget:Initialize()
	RefreshViewGeometry()
	RefreshPlayerCache()

	font = gl.LoadFont(FONT_FILE, FONT_SIZE, FONT_OUTLINE_SIZE, 1.9)
	if not font then
		Spring.Echo("[ChatterboxChat] Failed to load font: " .. tostring(FONT_FILE))
	end

	if HIDE_DEFAULT_CONSOLE then
		spSendCommands("console 0")
	end
end

function widget:Shutdown()
	if font then
		gl.DeleteFont(font)
		font = nil
	end

	if HIDE_DEFAULT_CONSOLE then
		spSendCommands("console 1")
	end
end

function widget:AddConsoleLine(line, priority)
	local parsed = ParseChatLine(line)
	if parsed then
		PushChatLine(parsed)
		if parsed.player then
			if parsed.channel == "whisper" then
				Spring.PlaySoundFile("chat", 1.0, ui)
			elseif parsed.channel == "ally" then
				Spring.PlaySoundFile("allychat", 1.0, ui)
			elseif parsed.channel == "spectator" then
				Spring.PlaySoundFile("specchat", 1.0, ui)
			elseif parsed.channel == "public" then
				Spring.PlaySoundFile("chat", 1.0, ui)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Draw
--------------------------------------------------------------------------------


local function GetLineAlpha(entry, now)
	local age = now - entry.time
	if age <= LINE_LIFETIME then
		return 1
	end
	if age >= (LINE_LIFETIME + FADE_TIME) then
		return 0
	end
	return 1 - ((age - LINE_LIFETIME) / FADE_TIME)
end

local function DrawTextStyled(text, x, y, size, r, g, b, a, glowStrength)
	-- optional colored glow
	if glowStrength and glowStrength > 0 then
		local ga = a * glowStrength

		font:SetTextColor(r, g, b, ga * 0.35)
		font:Print(text, x - 1, y,     size, "n")
		font:Print(text, x + 1, y,     size, "n")
		font:Print(text, x,     y - 1, size, "n")
		font:Print(text, x,     y + 1, size, "n")

		font:SetTextColor(r, g, b, ga * 0.18)
		font:Print(text, x - 2, y,     size, "n")
		font:Print(text, x + 2, y,     size, "n")
		font:Print(text, x,     y - 2, size, "n")
		font:Print(text, x,     y + 2, size, "n")
	end

	-- shadow
	font:SetTextColor(0, 0, 0, a * 0.6)
	font:Print(text, x + 1, y - 1, size, "o")

	-- main text
	font:SetTextColor(r, g, b, a)
	font:Print(text, x, y, size, "o")
end

local function DrawWrappedEntry(x, y, wrapped, alpha)
	local entry = wrapped.entry

	if entry.player then
		local nc = entry.nameColor or COLOR_PUBLIC
		DrawTextStyled(wrapped.nameText, x, y, FONT_SIZE, nc[1], nc[2], nc[3], alpha, 0.00)

		local sepX = x + wrapped.nameWidth
		DrawTextStyled(wrapped.separatorText, sepX, y, FONT_SIZE, 1, 1, 1, alpha, 0.0)

		local bc = entry.bodyColor or COLOR_PUBLIC
		local glow = 0.0
		if entry.channel == "ally" or entry.channel == "spectator" or entry.channel == "whisper" then
			glow = 0.28
		end

		for i = 1, #wrapped.bodyLines do
			local lineY = y - ((i - 1) * LINE_SPACING)
			local lineX = x + wrapped.bodyX
			DrawTextStyled(wrapped.bodyLines[i], lineX, lineY, FONT_SIZE, bc[1], bc[2], bc[3], alpha, glow)
		end
	else
		local bc = entry.bodyColor or COLOR_SYSTEM
		for i = 1, #wrapped.bodyLines do
			local lineY = y - ((i - 1) * LINE_SPACING)
			DrawTextStyled(wrapped.bodyLines[i], x, lineY, FONT_SIZE, bc[1], bc[2], bc[3], alpha, 0.0)
		end
	end
end

local function TrimAliveToMaxRenderedLines(alive, maxRenderedLines)
	local total = 0
	local keptReversed = {}

	-- walk newest to oldest, keeping only as many rendered lines as fit
	for i = #alive, 1, -1 do
		local item = alive[i]
		local h = item.wrapped.height or 1

		if total + h <= maxRenderedLines then
			total = total + h
			keptReversed[#keptReversed + 1] = item
		else
			break
		end
	end

	-- reverse back into oldest -> newest draw order
	local kept = {}
	for i = #keptReversed, 1, -1 do
		kept[#kept + 1] = keptReversed[i]
	end

	return kept
end

function widget:DrawScreen()
	if spIsGUIHidden() then return end
	if not font then return end
	if #chatLines == 0 then return end

	local now = os.clock()
	local alive = {}
	local maxWidth = 0

	for i = 1, #chatLines do
		local entry = chatLines[i]
		local alpha = GetLineAlpha(entry, now)
		if alpha > 0 then
			-- wrapped is pre-computed in PushChatLine; never rebuild here
			alive[#alive + 1] = {
				entry   = entry,
				alpha   = alpha,
				wrapped = entry.wrapped,
			}
		end
	end

	if #alive == 0 then
		chatLines = {}
		return
	end

	alive = TrimAliveToMaxRenderedLines(alive, MAX_LINES)

	-- Rebuild backing chatLines from trimmed visible entries only
	chatLines = {}
	for i = 1, #alive do
		chatLines[i] = alive[i].entry
		if alive[i].wrapped.width > maxWidth then
			maxWidth = alive[i].wrapped.width
		end
	end

	if #alive == 0 then return end

	local totalLineCount = 0
	for i = 1, #alive do
		totalLineCount = totalLineCount + alive[i].wrapped.height
	end

	local totalHeight = math.max(FONT_SIZE, ((totalLineCount - 1) * LINE_SPACING) + FONT_SIZE)

	local boxWidth = MAX_BOX_WIDTH
	local x    = (vsx * 0.5) - (boxWidth * 0.5)
	local yTop = (vsy * 0.15) + (totalHeight * 0.5)

	if DRAW_BACKGROUND then
		glColor(0, 0, 0, 0.22)
		glRect(
				x - BG_PADDING,
				yTop - totalHeight - BG_PADDING,
				x + boxWidth + BG_PADDING,
				yTop + BG_PADDING
		)
	end

	-- Single font batch for all lines -- eliminates per-draw Begin/End overhead
	font:Begin()
	local currentY = yTop
	for i = 1, #alive do
		DrawWrappedEntry(x, currentY, alive[i].wrapped, alive[i].alpha)
		currentY = currentY - (alive[i].wrapped.height * LINE_SPACING)
	end
	font:End()

	font:SetTextColor(1, 1, 1, 1)
	glColor(1, 1, 1, 1)
end