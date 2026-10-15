if addon.InGetInfo then
	return {
		name    = "Main",
		desc    = "The loading panel: a tip, quote or unit note, the load message and a progress bar, in the Bastion style",
		author  = "jK; SplinterFaction Team",
		date    = "2012,2013; 2026",
		license = "GPL2",
		layer   = 0,
		depend  = {"LoadProgress"},
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- settings the engine reads while loading
--------------------------------------------------------------------------------

local defaultFont = 'Saira_SemiCondensed-SemiBold.ttf'
local fontfile = 'luaui/fonts/'..Spring.GetConfigString("ui_font", defaultFont)
if not VFS.FileExists(fontfile) then
	Spring.SetConfigString('ui_font', defaultFont)
	fontfile = 'luaui/fonts/'..defaultFont
end
-- Deferred G-buffer passes are required by gfx_deferred_rendering_gl4.lua
-- (and gfx_bloom_shader_deferred.lua). The engine reads these at load, so
-- LuaIntro is early enough to enforce them for fresh installs.
Spring.SetConfigInt('AllowDeferredMapRendering', 1)
Spring.SetConfigInt('AllowDeferredModelRendering', 1)
-- The engine's own grass stays off: SplinterFaction draws grass with the
-- "Map Grass GL4" widget, which reads the same grass map, so with both on a
-- map that has one gets two kinds of grass on top of each other. The engine
-- reads GrassDetail once, when it builds its grass drawer during loading
-- (GrassDetail 0 turns it off for the match; changing it later does not), so
-- this has to happen here. Until 2026-09-27 the old options widget did the
-- same on every launch.
Spring.SetConfigInt('GrassDetail', 0)

local defaultFont2 = 'Saira_SemiCondensed-SemiBold.ttf'
local fontfile2 = 'luaui/fonts/'..Spring.GetConfigString("ui_font2", defaultFont2)
if not VFS.FileExists(fontfile2) then
	Spring.SetConfigString('ui_font2', defaultFont2)
end

-- headings and figures are set in the bold face
local boldfile = 'luaui/fonts/Saira_SemiCondensed-Bold.ttf'
if not VFS.FileExists(boldfile) then
	boldfile = fontfile
end

--------------------------------------------------------------------------------
-- what the panel can show above the bar: one of these, a different one each
-- launch. image (optional) is a path inside the game; title, text and author
-- are plain text.
--------------------------------------------------------------------------------

local showTips = true

local tips = {
	{ image = "unitpics/loadingpics/xtadeus.dds", title = "Xtadeus",
	  text = "Composer of all of the music in the game. Check out his channel on YouTube!",
	  link = "www.youtube.com/@xtadeus4777" },
	{ title = "Press Enter to chat",
	  text = "Ctrl+Enter switches to All Chat\nAlt+Enter switches to Ally Chat\nShift+Enter switches to Spectator Chat" },
}

local unit_descs = {
	{ image = "unitpics/fedmenlo.png", title = "Menlo", text = "The penultimate in defense matrices." },
	{ image = "unitpics/loadingpics/defensematrix.dds", title = "Menlo", text = "The penultimate in defense matrices." },
}

local quotes = {
	{"Strategy without tactics is the slowest route to victory. Tactics without strategy is the noise before defeat.", "Sun Tzu"},
	{"He will win who knows when to fight and when not to fight.", "Sun Tzu"},
	{"When I have won a victory I do not repeat my tactics but respond to circumstances in an infinite variety of ways.", "Sun Tzu"},
	{"The art of war is the art of deception.", "Sun Tzu"},
	{"Brains will always conquer brawn, in the end. The soldiers can flex their muscles all they want, but the well-thought-out tactics of the generals are what win the war.", "Patrick Hall"},
	{"The best defense is a confusing offense.", "Kimberly Pauley"},
	{"When your opponent is making a mistake, do nothing to interfere.", "Napoleon Bonaparte"},
	{"Effective strategy considers and plans for its own failure.", "Eric Engle"},
	{"No campaign plan survives first contact with the enemy.", "Carl von Clausewitz"},
	{"Tactics is the art of using troops in battle; strategy is the art of using battles to win the war.", "Carl von Clausewitz"},
	{"The enemy of a good plan is the dream of a perfect plan.", "Carl von Clausewitz"},
	{"Where absolute superiority is not attainable, you must produce a relative one at the decisive point by making skillful use of what you have.", "Carl von Clausewitz"},
	{"The best form of defense is attack.", "Carl von Clausewitz"},
}

-- math.random gives the same sequence every launch here, so a counter kept in
-- a file decides what is shown: it moves on by one each time the game loads.
local filename = "LuaUI/Config/randomseed.data"
local k = os.time() % 1500
if VFS.FileExists(filename) then
	k = tonumber(VFS.LoadFile(filename)) or k
end
k = k + 1
do
	local file = io.open(filename, 'w')
	if file then
		file:write(k)
		file:close()
	end
end

-- odd launches: a tip. Even launches: a quote on some, a unit note on the rest.
local card
if k % 2 == 1 then
	local tip = tips[(math.ceil(k / 2) % #tips) + 1]
	card = { kind = "TIP", image = tip.image, title = tip.title, text = tip.text, link = tip.link }
elseif k % 3 == 2 then
	local quote = quotes[(math.ceil(k / 3) % #quotes) + 1]
	card = { kind = "QUOTE", text = quote[1], author = quote[2] }
else
	local desc = unit_descs[(math.floor(k / 2) % #unit_descs) + 1]
	card = { kind = "UNIT", image = desc.image, title = desc.title, text = desc.text }
end
if card.image and not VFS.FileExists(card.image) then
	card.image = nil
end

--------------------------------------------------------------------------------
-- look: the Bastion palette of the website and the in-game HUD
-- (LuaUI/rml/theme.rcss). Everything is square; a panel is marked by two ember
-- corner brackets.
--------------------------------------------------------------------------------

local COLOR = {
	panel   = {0.043, 0.055, 0.071, 0.93}, -- #0b0e12
	raised  = {0.102, 0.133, 0.169, 1},    -- #1a222b
	border  = {0.137, 0.176, 0.220, 1},    -- #232d38
	firm    = {0.208, 0.263, 0.310, 1},    -- #35434f
	ember   = {1.000, 0.608, 0.129, 1},    -- #ff9b21
}
-- inline text colors
local function TextColor(r, g, b)
	return "\255" .. string.char(math.max(1, r), math.max(1, g), math.max(1, b))
end
local TEXT = {
	body    = TextColor(194, 204, 214), -- #c2ccd6
	heading = TextColor(240, 244, 248), -- #f0f4f8
	muted   = TextColor(133, 147, 161), -- #8593a1
	ember   = TextColor(255, 155, 33),  -- #ff9b21
	dimEmber = TextColor(201, 118, 26), -- #c9761a
	signal  = TextColor(95, 208, 232),  -- #5fd0e8
}

-- Sizes are in pixels of a 1080-pixel-high screen and scale from there.
local PANEL_WIDTH_FRAC = 0.60  -- share of the screen's width...
local PANEL_MIN_WIDTH  = 760   -- ...but not narrower than this
local PANEL_BOTTOM_FRAC = 0.075 -- gap under the panel, as a share of the screen's height
local CARD_HEIGHT = 152  -- the tip, quote or unit note
local BAR_HEIGHT  = 66   -- the load message, percentage and bar
local PAD         = 18
local IMAGE_SIZE  = 96
local MAX_TEXT_LINES = 4

local LOADED_FONT_SIZE = 48
local font     = gl.LoadFont(fontfile, LOADED_FONT_SIZE, 2, 1)
local boldFont = gl.LoadFont(boldfile, LOADED_FONT_SIZE, 2, 1)
if not boldFont then
	boldFont = font
end

--------------------------------------------------------------------------------
-- progress
--------------------------------------------------------------------------------

local lastLoadMessage = ""
local lastProgress = {0, 0}

-- The engine reports stages, not a percentage. Each stage is given a range,
-- and the time the last load of this map took (LoadProgress) moves the bar
-- inside it.
local progressByLastLine = {
	["Parsing Map Information"] = {0, 20},
	["Loading Weapon Definitions"] = {10, 50},
	["Loading LuaRules"] = {40, 80},
	["Loading LuaUI"] = {70, 95},
	["Finalizing"] = {100, 100}
}
for name,val in pairs(progressByLastLine) do
	progressByLastLine[name] = {val[1]*0.01, val[2]*0.01}
end

function addon.LoadProgress(message, replaceLastLine)
	lastLoadMessage = message
	if message:find("Path") then -- pathing has no rigid messages so cant use the table
		lastProgress = {0.8, 1.0}
	end
	lastProgress = progressByLastLine[message] or lastProgress
end

--------------------------------------------------------------------------------
-- drawing, in screen pixels (y up)
--------------------------------------------------------------------------------

local function Rect(x1, y1, x2, y2, color, alpha)
	gl.Color(color[1], color[2], color[3], alpha or color[4] or 1)
	gl.Rect(x1, y1, x2, y2)
end

-- a one-pixel-wide outline, drawn inside the rectangle
local function Outline(x1, y1, x2, y2, color, width)
	Rect(x1, y1, x2, y1 + width, color)
	Rect(x1, y2 - width, x2, y2, color)
	Rect(x1, y1, x1 + width, y2, color)
	Rect(x2 - width, y1, x2, y2, color)
end

-- the two ember corner brackets: top left and bottom right
local function Brackets(x1, y1, x2, y2, length, width)
	Rect(x1, y2 - width, x1 + length, y2, COLOR.ember)
	Rect(x1, y2 - length, x1 + width, y2, COLOR.ember)
	Rect(x2 - length, y1, x2, y1 + width, COLOR.ember)
	Rect(x2 - width, y1, x2, y1 + length, COLOR.ember)
end

-- Wraps text to a width in pixels at a font size; keeps at most maxLines lines.
local function Wrap(useFont, text, width, size, maxLines)
	local wrapped = useFont:WrapText(text, width * (LOADED_FONT_SIZE / size))
	local lines = {}
	for line in (wrapped .. "\n"):gmatch("(.-)\r?\n") do
		lines[#lines + 1] = line
		if #lines == maxLines then
			break
		end
	end
	return lines
end

local function DrawCard(x1, y1, x2, y2, s)
	local pad = PAD * s
	local left = x1 + pad
	local top = y2 - pad

	-- what kind of card this is, and the map being loaded
	font:Print(TEXT.ember .. card.kind, left, top, 12 * s, "a")
	if Game and Game.mapName then
		font:Print(TEXT.muted .. string.upper(Game.mapName), x2 - pad, top, 12 * s, "ar")
	end
	top = top - 22 * s

	if card.image then
		local size = IMAGE_SIZE * s
		Rect(left, top - size, left + size, top, COLOR.raised)
		gl.Color(1, 1, 1, 1)
		gl.Texture(":n:" .. card.image)
		gl.TexRect(left, top - size, left + size, top, false, false)
		gl.Texture(false)
		Outline(left, top - size, left + size, top, COLOR.firm, math.max(1, math.floor(s)))
		left = left + size + pad
	end

	local width = (x2 - pad) - left
	if card.title then
		boldFont:Print(TEXT.heading .. card.title, left, top, 20 * s, "a")
		top = top - 28 * s
	end
	local size = (card.kind == "QUOTE") and 18 * s or 16 * s
	local lineHeight = size * 1.35
	local lines = Wrap(font, card.text, width, size, card.title and (MAX_TEXT_LINES - 1) or MAX_TEXT_LINES)
	for i, line in ipairs(lines) do
		font:Print(((card.kind == "QUOTE") and TEXT.heading or TEXT.body) .. line, left, top - (i - 1) * lineHeight, size, "a")
	end
	top = top - #lines * lineHeight
	if card.link then
		font:Print(TEXT.signal .. card.link, left, top - 2 * s, 15 * s, "a")
	end
	if card.author then
		font:Print(TEXT.dimEmber .. card.author, x2 - pad, y1 + pad * 0.6 + 15 * s, 15 * s, "ar")
	end
end

local function DrawBar(x1, y1, x2, y2, s, loadProgress)
	local pad = PAD * s
	local top = y2 - 14 * s

	local message = lastLoadMessage
	if message == "" then
		message = "Loading"
	end
	font:Print(TEXT.muted .. message, x1 + pad, top, 15 * s, "a")
	if loadProgress > 0 then
		boldFont:Print(TEXT.heading .. ("%.0f%%"):format(loadProgress * 100), x2 - pad, top + 3 * s, 20 * s, "ar")
	end

	local barH = math.max(4, math.floor(6 * s))
	local barY1 = math.floor(y1 + 16 * s)
	local barX1, barX2 = x1 + pad, x2 - pad
	Rect(barX1, barY1, barX2, barY1 + barH, COLOR.raised)
	local fill = math.max(0, math.min(1, loadProgress))
	if fill > 0 then
		Rect(barX1, barY1, barX1 + (barX2 - barX1) * fill, barY1 + barH, COLOR.ember)
	end
end

function addon.DrawLoadScreen()
	local loadProgress = SG.GetLoadProgress()
	if loadProgress == 0 then
		loadProgress = lastProgress[1]
	else
		loadProgress = math.min(math.max(loadProgress, lastProgress[1]), lastProgress[2])
	end

	local vsx, vsy = gl.GetViewSizes()
	local s = vsy / 1080

	local width = math.floor(math.min(vsx - 2 * PAD * s, math.max(vsx * PANEL_WIDTH_FRAC, PANEL_MIN_WIDTH * s)))
	local barH = math.floor(BAR_HEIGHT * s)
	local cardH = showTips and math.floor(CARD_HEIGHT * s) or 0
	local x1 = math.floor((vsx - width) * 0.5)
	local x2 = x1 + width
	local y1 = math.floor(vsy * PANEL_BOTTOM_FRAC)
	local y2 = y1 + barH + cardH
	local line = math.max(1, math.floor(s))

	-- the load screen is drawn in 0..1 coordinates; work in pixels instead
	gl.PushMatrix()
	gl.Scale(1 / vsx, 1 / vsy, 1)
	gl.Texture(false)

	Rect(x1, y1, x2, y2, COLOR.panel)
	Outline(x1, y1, x2, y2, COLOR.border, line)
	if showTips then
		Rect(x1 + line, y1 + barH, x2 - line, y1 + barH + line, COLOR.border) -- between the card and the bar
	end
	Brackets(x1, y1, x2, y2, math.floor(11 * s), math.max(2, math.floor(2 * s)))

	if showTips then
		DrawCard(x1, y1 + barH, x2, y2, s)
	end
	DrawBar(x1, y1, x2, y1 + barH, s, loadProgress)

	gl.Color(1, 1, 1, 1)
	gl.PopMatrix()
end


function addon.MousePress(...)
	--Spring.Echo(...)
end


function addon.Shutdown()
	gl.DeleteFont(font)
	if boldFont ~= font then
		gl.DeleteFont(boldFont)
	end
end
