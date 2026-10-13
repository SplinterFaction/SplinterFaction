--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Messages of the RmlUi HUD: text from the game itself (missions, tutorials),
--  typed out letter by letter in a panel under the resource bar. A line stays
--  for a while after it has been typed, then goes; the panel goes with the
--  last line.
--
--  How to send one:
--    from a widget:  WG['messages'].addMessage(text)
--    from a gadget:  Script.LuaUI.GadgetAddMessage(text)   (unsynced)
--  A message may have several lines ("\n"), and may carry the engine's inline
--  color codes ("\255\r\g\b"), which color the text that follows them.
--
--  Replaces gui_messages.lua by Floris (kept in Widgets/disabled/). The old
--  widget's Ctrl-and-hover scrollback is gone.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name    = "Messages",
		desc    = "Typewrites messages from the game under the resource bar (missions, tutorials) (RmlUi)",
		author  = "Floris; SplinterFaction Team",
		date    = "2026-10-13",
		license = "GNU GPL, v2 or later",
		layer   = 30000,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- config
--------------------------------------------------------------------------------

local DOCUMENT_PATH = "LuaUI/rml/messages.rml"

-- must match #messages in messages.rml
local BOX_WIDTH  = 640
local BOX_HEIGHT = 190
local BOX_TOP    = 92 -- below the resource bar

local LAYOUT_NAME = "messages"

local CHAR_DELAY = 0.022 -- seconds per letter
local MAX_LINES  = 6     -- lines shown at once
local LINE_TTL   = 14    -- seconds a line stays after it has been typed

local hud
local document
local view

-- lines[i] = { runs = {{color = "#rrggbb" | nil, text = }, ...}, length = , start = }
-- start is when the line's first letter appears (os.clock)
local lines = {}
local shownSignature = ""

--------------------------------------------------------------------------------
-- messages
--------------------------------------------------------------------------------

-- Splits one line at the engine's color codes: "\255" and three bytes of
-- color. Returns the runs and the number of letters.
local function ParseLine(text)
	local runs, length = {}, 0
	local color = nil
	local position = 1
	while position <= #text do
		local code = text:find("\255", position, true)
		local chunk = text:sub(position, (code or (#text + 1)) - 1)
		if chunk ~= "" then
			runs[#runs + 1] = { color = color, text = chunk }
			length = length + #chunk
		end
		if not code then
			break
		end
		local r, g, b = text:byte(code + 1, code + 3)
		if b then
			color = string.format("#%02x%02x%02x", r, g, b)
		end
		position = code + 4
	end
	return runs, length
end

local function addMessage(text)
	if type(text) ~= "string" or text == "" then
		return
	end
	local now = os.clock()
	-- typing carries on where the line before stops
	local start = now
	local last = lines[#lines]
	if last then
		start = math.max(now, last.start + last.length * CHAR_DELAY)
	end
	for line in (text .. "\n"):gmatch("(.-)\r?\n") do
		local runs, length = ParseLine(line)
		lines[#lines + 1] = { runs = runs, length = length, start = start }
		start = start + length * CHAR_DELAY
	end
end

--------------------------------------------------------------------------------
-- showing
--------------------------------------------------------------------------------

-- the first `typed` letters of a line, as RML
local function LineRML(line, typed)
	local parts = {}
	local left = typed
	for _, run in ipairs(line.runs) do
		if left <= 0 then
			break
		end
		local text = hud.Escape(run.text:sub(1, left))
		left = left - #run.text
		if run.color then
			parts[#parts + 1] = '<span style="color: ' .. run.color .. ';">' .. text .. '</span>'
		else
			parts[#parts + 1] = text
		end
	end
	return '<div class="mline">' .. table.concat(parts) .. '</div>'
end

local function Refresh()
	local now = os.clock()
	-- drop the lines whose time is up
	while lines[1] and now >= lines[1].start + lines[1].length * CHAR_DELAY + LINE_TTL do
		table.remove(lines, 1)
	end
	-- the lines that have begun, the newest MAX_LINES of them
	local begun = 0
	for i = 1, #lines do
		if lines[i].start <= now then
			begun = i
		end
	end
	local first = math.max(1, begun - MAX_LINES + 1)
	local parts, signature = {}, {}
	for i = first, begun do
		local line = lines[i]
		local typed = math.min(line.length, math.floor((now - line.start) / CHAR_DELAY) + 1)
		parts[#parts + 1] = LineRML(line, typed)
		signature[#signature + 1] = tostring(line) .. typed
	end
	signature = table.concat(signature)
	if signature ~= shownSignature then
		shownSignature = signature
		view.SetClass("messages-panel", "hidden", #parts == 0)
		view.SetText("messages-lines", table.concat(parts))
	end
end

--------------------------------------------------------------------------------
-- widget api
--------------------------------------------------------------------------------

local function DefaultOrigin(vsx, vsy, w, h, scale)
	return (vsx - w) * 0.5, vsy - BOX_TOP * scale - h
end

local function Place()
	hud.PlacePanel(view.Element("messages"), LAYOUT_NAME, BOX_WIDTH, BOX_HEIGHT, DefaultOrigin)
end

function widget:Initialize()
	local helpers = include("rml/hud.lua")
	local result, reason = helpers.LoadDocument(DOCUMENT_PATH, widget)
	if not result then
		Spring.Echo("[Messages] " .. tostring(reason))
		widgetHandler:RemoveWidget(self)
		return
	end
	hud = helpers
	hud.showInPregame = true -- a mission may speak before the game proper
	document = result
	view = hud.NewView(document)
	view.Assume("messages-panel", "hidden", true) -- set in the markup

	widgetHandler:RegisterGlobal('GadgetAddMessage', addMessage)
	WG['messages'] = {
		addMessage = function(text) addMessage(text) end,
	}

	hud.RegisterPanel(LAYOUT_NAME, "Messages", Place, function() return #lines > 0 end)
	Place()
	hud.ShowPassive(document)
end

function widget:Shutdown()
	if document then
		widgetHandler:DeregisterGlobal('GadgetAddMessage')
		WG['messages'] = nil
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

function widget:Update()
	if not document then
		return
	end
	if hud.FollowGuiHidden(document) then
		return
	end
	-- idle cost stops here: nothing on screen and nothing waiting
	if #lines == 0 and shownSignature == "" then
		return
	end
	Refresh()
end
