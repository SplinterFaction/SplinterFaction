--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Rank tracks of the RmlUi HUD. The game_rank_tracks gadget counts four
--  things per team (metal destroyed, sustained income, metal built,
--  extractors held) and hands out cosmetic ranks. This widget shows them:
--
--    the strip, top right: the viewed team's rank on each track with a bar
--    to the next one, read from the team rules params the gadget publishes;
--
--    the card, under the resource bar: a badge that slams in when a rank is
--    reached, holds a moment, and fades. Rank-ups arrive from the gadget as
--    RankUpEvent and are queued, so two reached in the same fight play one
--    after the other instead of on top of each other.
--
--  Players only: a spectator sees nothing of it, and neither does a replay.
--  Nothing here affects play. The widget can be switched off in Options.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name    = "Bastion Ranks",
		desc    = "Per-match rank tracks: the strip and the rank-up card (RmlUi)",
		author  = "SplinterFaction Team",
		date    = "2026-10-19",
		license = "GNU GPL, v2 or later",
		layer   = -1990,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- config
--------------------------------------------------------------------------------

local DOCUMENT_PATH = "LuaUI/rml/ranks.rml"
local CONFIG_PATH   = "LuaRules/Configs/rank_tracks.lua"

-- must match #ranks and #rankup in ranks.rml
local STRIP_WIDTH  = 372
local STRIP_HEIGHT = 48
local STRIP_MARGIN = 10   -- from the top edge, matching the menu button
local STRIP_GAP    = 8    -- between the strip and the menu button
-- the menu button's place, so the strip sits to its left: must match
-- BUTTON_WIDTH and MARGIN in gui_bastion_menu.lua
local MENU_BUTTON_WIDTH  = 84
local MENU_BUTTON_MARGIN = 10
local CARD_WIDTH   = 320
local CARD_HEIGHT  = 252
local CARD_TOP     = 92   -- below the resource bar, where the vote window goes

local LAYOUT_STRIP = "ranks"
local LAYOUT_CARD  = "rankup"

-- the card's timing, in seconds
local SLAM_TIME   = 0.22  -- coming in: from oversized and clear to in place
local HOLD_TIME   = 2.2   -- fully shown
local FADE_TIME   = 0.45  -- going away
local GAP_TIME    = 0.5   -- between two cards
local FADE_STEPS  = 20    -- opacity moves in this many steps (as the pause banner does)

local STRIP_PERIOD = 15   -- frames between strip refreshes; matches the gadget

-- a sound per rank; file paths, as Spring.PlaySoundFile takes them
local SOUNDS = {
	"sounds/ui/rankup/SD_Low+Hi_01.wav",
	"sounds/ui/rankup/SD_Low+Hi_01.wav",
	"sounds/ui/rankup/SD_Low+Hi_04.wav",
	"sounds/ui/rankup/SD_Low+Hi_04.wav",
	"sounds/ui/rankup/SD_Low+Hi_06.wav",
}
local SOUND_VOLUME = 0.8

local ROMAN = {"I", "II", "III", "IV", "V"}

--------------------------------------------------------------------------------
-- state
--------------------------------------------------------------------------------

local hud
local document
local view

local tracks = {}  -- from the config: id, name, unit, thresholds, titles

local queue = {}   -- rank-ups waiting to be shown: {track, level, value}
local card  = nil  -- the one being shown: {track, level, value, t0}
local cardShownAt = -1 -- when the last card ended, for the gap

local fresh = nil  -- track index with the latest rank-up, highlighted in the strip
local freshUntil = 0

local viewedTeam = Spring.GetMyTeamID()
local isSpec = Spring.GetSpectatingState()
local lastStripFrame = -1

--------------------------------------------------------------------------------
-- helpers
--------------------------------------------------------------------------------

local startTimer = Spring.GetTimer()

-- seconds since the widget started
local function Now()
	return Spring.DiffTimers(Spring.GetTimer(), startTimer)
end

-- 6300 -> "6.3k", 420 -> "420", 12.5 -> "12.5"
local function Short(n)
	if n >= 10000 then
		return string.format("%dk", math.floor(n / 1000 + 0.5))
	elseif n >= 1000 then
		return string.format("%.1fk", n / 1000)
	elseif n >= 100 or n == math.floor(n) then
		return tostring(math.floor(n + 0.5))
	end
	return string.format("%.1f", n)
end

local function WithCommas(n)
	local s = tostring(math.floor(n + 0.5))
	while true do
		local replaced
		s, replaced = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		if replaced == 0 then
			break
		end
	end
	return s
end

-- what the card says under the title, in the track's own units
local function Achievement(track, value)
	if track.unit == "metal" then
		if track.id == "combat" then
			return WithCommas(value) .. " metal of enemy units destroyed"
		end
		return WithCommas(value) .. " metal of units built"
	elseif track.unit == "income" then
		return "+" .. Short(value) .. " sustained income"
	elseif track.unit == "extractors" then
		return value .. " extractors held"
	end
	return tostring(value)
end

-- what the strip says under the bar: how far to the next rank
local function ToNext(track, level, value)
	local thresholds = track.thresholds
	if level >= #thresholds then
		return "max"
	end
	local gap = math.max(0, thresholds[level + 1] - value)
	local target = ROMAN[level + 1] or tostring(level + 1)
	if track.unit == "income" then
		return "+" .. Short(gap) .. " to " .. target
	end
	return Short(gap) .. " to " .. target
end

local function Progress(track, level, value)
	local thresholds = track.thresholds
	if level >= #thresholds then
		return 1
	end
	local from = level > 0 and thresholds[level] or 0
	local to = thresholds[level + 1]
	if to <= from then
		return 1
	end
	return math.max(0, math.min(1, (value - from) / (to - from)))
end

-- Spring.GetTeamRulesParam returns no values for an unset param, so the
-- double parentheses turn that into nil
local function TeamParam(teamID, name)
	return (Spring.GetTeamRulesParam(teamID, name))
end

--------------------------------------------------------------------------------
-- the strip
--------------------------------------------------------------------------------

local function RefreshStrip()
	if isSpec then
		view.SetClass("ranks", "hidden", true)
		return
	end
	local teamID = viewedTeam
	local any = false
	for i, track in ipairs(tracks) do
		local level = TeamParam(teamID, "rank_" .. track.id .. "_level")
		local value = TeamParam(teamID, "rank_" .. track.id .. "_value")
		if level then
			any = true
			level = tonumber(level) or 0
			value = tonumber(value) or 0
			local max = level >= #track.thresholds
			view.SetText("lvl-" .. i, level > 0 and (ROMAN[level] or tostring(level)) or "-")
			view.SetClass("lvl-" .. i, "max", max)
			view.SetStyle("fill-" .. i, "width", string.format("%d%%", math.floor(Progress(track, level, value) * 100 + 0.5)))
			view.SetText("next-" .. i, ToNext(track, level, value))
		end
		view.SetClass("cell-" .. i, "fresh", fresh == i)
	end
	view.SetClass("ranks", "hidden", not any)
end

--------------------------------------------------------------------------------
-- the card
--------------------------------------------------------------------------------

local function FillCard(entry)
	local track = tracks[entry.track]
	local level = entry.level
	view.SetText("rankup-track-text", hud.Escape(track.name) .. " · Rank " .. (ROMAN[level] or tostring(level)))
	view.SetText("rankup-title", hud.Escape(track.titles[level] or ("Rank " .. level)))
	view.SetText("rankup-sub", hud.Escape(Achievement(track, entry.value)))
	local emblem = view.Element("rankup-emblem")
	if emblem then
		emblem:SetAttribute("src", "/LuaUI/Images/rml/rank_" .. track.id .. ".png")
	end
	for t = 1, 5 do
		view.SetClass("rankup-frame", "t" .. t, t == level)
	end
	local chevron = level >= 5 and "rank_chevron_ember.png" or "rank_chevron.png"
	local rml = {}
	for _ = 1, level do
		rml[#rml + 1] = '<img src="/LuaUI/Images/rml/' .. chevron .. '"/>'
	end
	local tally = view.Element("rankup-chevrons")
	if tally then
		tally.inner_rml = table.concat(rml)
	end
end

local function StartCard(entry)
	card = entry
	card.t0 = Now()
	FillCard(entry)
	fresh = entry.track
	freshUntil = card.t0 + HOLD_TIME + FADE_TIME + 6
	local sound = SOUNDS[math.min(entry.level, #SOUNDS)]
	if sound then
		Spring.PlaySoundFile(sound, SOUND_VOLUME, "ui")
	end
	pcall(function() document:PullToFront() end)
	view.SetClass("rankup", "hidden", false)
	lastStripFrame = -1 -- so the strip shows the new rank at once
end

local function EndCard()
	card = nil
	cardShownAt = Now()
	view.SetClass("rankup", "hidden", true)
end

-- opacity and position over the card's life. Stepped like the pause banner,
-- so the document is not restyled every frame for a change nobody can see.
local function AnimateCard()
	local t = Now() - card.t0
	local opacity, lift
	if t < SLAM_TIME then
		local p = t / SLAM_TIME
		p = 1 - (1 - p) * (1 - p) -- ease out
		opacity = p
		lift = (1 - p) * 20 -- starts a little high and settles
	elseif t < SLAM_TIME + HOLD_TIME then
		opacity, lift = 1, 0
	elseif t < SLAM_TIME + HOLD_TIME + FADE_TIME then
		opacity = 1 - (t - SLAM_TIME - HOLD_TIME) / FADE_TIME
		lift = 0
	else
		EndCard()
		return
	end
	view.SetStyle("rankup", "opacity", string.format("%.2f", math.ceil(opacity * FADE_STEPS) / FADE_STEPS))
	view.SetStyle("rankup", "margin-top", string.format("%ddp", -math.floor(lift + 0.5)))
end

--------------------------------------------------------------------------------
-- events from the gadget
--------------------------------------------------------------------------------

local function RankUpEvent(teamID, trackIndex, level, value)
	if isSpec or teamID ~= viewedTeam or not tracks[trackIndex] then
		return
	end
	queue[#queue + 1] = {track = trackIndex, level = level, value = value}
end

--------------------------------------------------------------------------------
-- widget api
--------------------------------------------------------------------------------

local function StripOrigin(vsx, vsy, w, h, scale)
	local x = vsx - (MENU_BUTTON_MARGIN + MENU_BUTTON_WIDTH + STRIP_GAP) * scale - w
	return x, vsy - STRIP_MARGIN * scale - h
end

local function CardOrigin(vsx, vsy, w, h, scale)
	return (vsx - w) * 0.5, vsy - CARD_TOP * scale - h
end

local function Place()
	hud.PlacePanel(view.Element("ranks"), LAYOUT_STRIP, STRIP_WIDTH, STRIP_HEIGHT, StripOrigin)
	hud.PlacePanel(view.Element("rankup"), LAYOUT_CARD, CARD_WIDTH, CARD_HEIGHT, CardOrigin)
	view.ForgetStyles()
end

function widget:Initialize()
	if Spring.IsReplay() then
		widgetHandler:RemoveWidget(self)
		return
	end
	local ok, config = pcall(VFS.Include, CONFIG_PATH)
	if not ok or type(config) ~= "table" or type(config.tracks) ~= "table" then
		Spring.Echo("[Bastion Ranks] could not read " .. CONFIG_PATH)
		widgetHandler:RemoveWidget(self)
		return
	end
	tracks = config.tracks

	local helpers = include("rml/hud.lua")
	local result, reason = helpers.LoadDocument(DOCUMENT_PATH, widget)
	if not result then
		Spring.Echo("[Bastion Ranks] " .. tostring(reason))
		widgetHandler:RemoveWidget(self)
		return
	end
	hud = helpers
	document = result
	view = hud.NewView(document)
	view.Assume("ranks", "hidden", true)
	view.Assume("rankup", "hidden", true)
	view.Assume("rankup-frame", "t1", true)

	widgetHandler:RegisterGlobal("RankUpEvent", RankUpEvent)

	hud.RegisterPanel(LAYOUT_STRIP, "Ranks", Place)
	hud.RegisterPanel(LAYOUT_CARD, "Rank-up", Place, function() return card ~= nil end)
	Place()
	hud.ShowPassive(document)
	viewedTeam = Spring.GetMyTeamID()
	isSpec = Spring.GetSpectatingState()
	RefreshStrip()
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal("RankUpEvent")
	if hud then
		hud.UnregisterPanel(LAYOUT_STRIP)
		hud.UnregisterPanel(LAYOUT_CARD)
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

-- a player who resigns or dies becomes a spectator: the strip goes away and
-- pending cards are dropped
function widget:PlayerChanged(playerID)
	local teamID = Spring.GetMyTeamID()
	local spec = Spring.GetSpectatingState()
	if teamID ~= viewedTeam or spec ~= isSpec then
		viewedTeam = teamID
		isSpec = spec
		queue = {}
		if card then
			EndCard()
		end
		fresh = nil
		lastStripFrame = -1
	end
end

function widget:GameFrame(n)
	if n - lastStripFrame >= STRIP_PERIOD or lastStripFrame < 0 then
		lastStripFrame = n
		if document and not Spring.IsGUIHidden() then
			if fresh and Now() > freshUntil then
				fresh = nil
			end
			RefreshStrip()
		end
	end
end

function widget:Update()
	if not document then
		return
	end
	if hud.FollowGuiHidden(document) then
		return
	end
	if card then
		AnimateCard()
	elseif #queue > 0 and Now() - cardShownAt >= GAP_TIME then
		StartCard(table.remove(queue, 1))
	end
end
