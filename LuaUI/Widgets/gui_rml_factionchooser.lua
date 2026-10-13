--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Faction chooser of the RmlUi HUD: the screen before the game proper, where
--  each player picks a faction. The choice is sent to the game_spawn gadget.
--
--  The screen is dimmed, with one card per faction and a countdown above
--  them. A click on a card is final. A player who has not chosen when the
--  time runs out gets a faction at random. Spectators see the dim, the
--  heading and the countdown only.
--
--  The countdown is driven by game frames, not the wall clock, so it respects
--  game speed and pause. The gadget broadcasts the real deadline in the
--  "factionDeadlineFrame" game rules param (it is shortened once everyone has
--  chosen) and the current phase in "phase"; the widget removes itself when
--  the phase is no longer "faction".
--
--  Replaces gui_static_factionchooser.lua (kept in Widgets/disabled/).
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name    = "Faction Chooser",
		desc    = "Pregame faction choice; sends the choice to the game_spawn gadget (RmlUi)",
		author  = "SplinterFaction Team",
		date    = "2026-10-13",
		license = "GNU GPL, v2 or later",
		layer   = 2000, -- the placement widget keeps everything at 1800 and up running in pregame
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- config
--------------------------------------------------------------------------------

local DOCUMENT_PATH = "LuaUI/rml/factionchooser.rml"

-- the byte game_spawn.lua's RecvLuaMsg listens for
local SPAWN_MSG_BYTE = "\138"

-- must match #chooser in factionchooser.rml: two cards of 420 and the 40 between
local GROUP_WIDTH  = 880
local GROUP_HEIGHT = 500

local LAYOUT_NAME = "factionchooser" -- same as the old widget, so a saved position carries over

local DEADLINE_FRAME    = 900 -- fallback, matching CHOICE_TIMEOUT_FRAMES in game_spawn.lua
local COUNTDOWN_TOTAL   = 30  -- seconds the full bar stands for
local COUNTDOWN_BEEP_AT = 10  -- tick sound, and red, for the last seconds

local BORDER_IDLE = "#232d38"

-- accent: the faction's color, for the line on top of its card and the card's
-- border while the mouse is on it or it has been chosen
local FACTION_DATA = {
	{
		commName    = "fedcommander",
		heroImg     = "unitpics-hero/fedcommander_up1-hero.png",
		label       = "Federation of Kala",
		description = [[Fast, aggressive, and relentless. They favor mobility and area-of-effect firepower, using walkers, missiles, and plasma cannons to overwhelm enemies. Instead of shields, they have rapid hull regeneration, allowing them to recover between fights. Their cloaking technology makes them unpredictable, striking from unexpected angles.]],
		accent      = "#2e85fa",
	},
	{
		commName    = "lozcommander",
		heroImg     = "unitpics-hero/lozcommander_up1-hero.png",
		label       = "Loz Alliance",
		description = [[Slow, heavily shielded, and hard-hitting. Their massive tanks dominate the battlefield with long-range firepower, relying on personal energy shields that regenerate quickly after combat. While their units lack innate health regeneration, their shields and defensive structures keep them standing.]],
		accent      = "#d93838",
	},
}

local spPlaySoundFile   = Spring.PlaySoundFile
local spSendLuaRulesMsg = Spring.SendLuaRulesMsg

local hud
local document
local view

local chosen         = false -- true once the local player's choice has been sent
local chosenCommName = nil
local hovered        = nil   -- index of the card under the mouse
local gameStarted    = false -- true once the game frame is past 0
local isSpectator    = false
local secondsLeft    = COUNTDOWN_TOTAL
local lastBeepSecond = nil

--------------------------------------------------------------------------------
-- showing
--------------------------------------------------------------------------------

local function CardsRML()
	local parts = {}
	for i, fd in ipairs(FACTION_DATA) do
		parts[i] = string.format(
			'<div id="card%d" class="card panel%s" data-card="%d">'
			.. '<div class="accent" style="background-color: %s;"/>'
			.. '<div class="cname title">%s</div>'
			.. '<img class="hero" src="/%s"/>'
			.. '<div class="cdesc">%s</div>'
			.. '<div id="card%d-state" class="cstate label">Choose</div>'
			.. '</div>',
			i, (i > 1) and " second" or "", i, fd.accent, hud.Escape(fd.label), fd.heroImg, hud.Escape(fd.description), i)
	end
	return table.concat(parts)
end

local function Refresh()
	view.SetClass("root", "hidden", not gameStarted)
	if not gameStarted then
		return
	end
	view.SetClass("dim", "spectator", isSpectator)
	view.SetClass("cards", "hidden", isSpectator)
	view.SetText("title", isSpectator and "Players Are Choosing Their Factions" or "Choose Your Faction")

	local urgent = secondsLeft <= COUNTDOWN_BEEP_AT
	view.SetText("timer", secondsLeft .. "s")
	view.SetClass("timer", "urgent", urgent)
	view.SetClass("timer-fill", "urgent", urgent)
	local fraction = math.max(0, math.min(1, secondsLeft / COUNTDOWN_TOTAL))
	view.SetStyle("timer-fill", "width", string.format("%.1f%%", fraction * 100))

	if isSpectator then
		return
	end
	for i, fd in ipairs(FACTION_DATA) do
		local id = "card" .. i
		local isChosen = chosen and fd.commName == chosenCommName
		-- once a faction is chosen the other card no longer answers the mouse
		local lit = isChosen or (not chosen and hovered == i)
		view.SetStyle(id, "border-color", lit and fd.accent or BORDER_IDLE)
		view.SetClass(id, "chosen", isChosen)
		view.SetClass(id, "passed", chosen and not isChosen)
		view.SetText(id .. "-state", isChosen and "Chosen" or "Choose")
	end
end

--------------------------------------------------------------------------------
-- choosing
--------------------------------------------------------------------------------

-- Sends the choice. Returns true when it went out.
local function Choose(index)
	local fd = FACTION_DATA[index]
	local def = fd and UnitDefNames[fd.commName]
	if not def or not def.id then
		return false
	end
	spSendLuaRulesMsg(SPAWN_MSG_BYTE .. def.id)
	chosen         = true
	chosenCommName = fd.commName
	return true
end

local function AutoPickFaction()
	Choose(math.random(1, #FACTION_DATA))
end

--------------------------------------------------------------------------------
-- widget api
--------------------------------------------------------------------------------

local function DefaultOrigin(vsx, vsy, w, h, scale)
	return (vsx - w) * 0.5, (vsy - h) * 0.5
end

local function Place()
	hud.PlacePanel(view.Element("chooser"), LAYOUT_NAME, GROUP_WIDTH, GROUP_HEIGHT, DefaultOrigin)
end

function widget:Initialize()
	local helpers = include("rml/hud.lua")
	local result, reason = helpers.LoadDocument(DOCUMENT_PATH, widget)
	if not result then
		Spring.Echo("[Faction Chooser] " .. tostring(reason))
		widgetHandler:RemoveWidget(self)
		return
	end
	hud = helpers
	document = result
	isSpectator = Spring.GetSpectatingState()

	view = hud.NewView(document)
	view.Assume("root", "hidden", true) -- set in the markup
	view.Element("cards").inner_rml = CardsRML()

	local cards = view.Element("cards")
	cards:AddEventListener("mousedown", function(event)
		if chosen or isSpectator or not gameStarted then
			return
		end
		local index = hud.EventAttribute(event, "data-card")
		if index and event.parameters and event.parameters.button == 0 and Choose(index) then
			spPlaySoundFile("leftclick", 1.0, "ui")
			Refresh()
		end
	end)
	cards:AddEventListener("mouseover", function(event)
		local index = hud.EventAttribute(event, "data-card")
		if index ~= hovered then
			hovered = index
			if index and not chosen then
				spPlaySoundFile("hover", 1.0, "ui")
			end
			Refresh()
		end
	end)
	cards:AddEventListener("mouseout", function()
		if hovered then
			hovered = nil
			Refresh()
		end
	end)

	hud.RegisterPanel(LAYOUT_NAME, "Faction Chooser", Place)
	Place()
	hud.ShowPassive(document)
end

function widget:Shutdown()
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

function widget:GameStart()
	isSpectator = Spring.GetSpectatingState()
end

function widget:Update()
	if not document then
		return
	end
	-- nothing ticks until the game has started
	if not gameStarted then
		if Spring.GetGameFrame() > 0 then
			gameStarted = true
		end
		return
	end

	-- Once the phase is no longer "faction" (placement has started, or the
	-- game is already under way), the job here is done.
	local currentPhase = Spring.GetGameRulesParam("phase")
	if currentPhase ~= nil and currentPhase ~= "faction" then
		widgetHandler:RemoveWidget(self)
		return
	end

	-- The gadget's deadline is the one that counts; it is shortened when
	-- every player has chosen early.
	local frame = Spring.GetGameFrame()
	local deadline = Spring.GetGameRulesParam("factionDeadlineFrame") or DEADLINE_FRAME
	local framesLeft = math.max(0, deadline - frame)
	local gameSpeed = Spring.GetGameSpeed() or 1
	secondsLeft = math.ceil(framesLeft / (30 * gameSpeed))

	if secondsLeft <= COUNTDOWN_BEEP_AT and secondsLeft ~= lastBeepSecond and secondsLeft > 0 then
		spPlaySoundFile("hover", 0.6, "ui")
		lastBeepSecond = secondsLeft
	end

	if framesLeft == 0 then
		-- out of time: a player who has not chosen gets a faction at random
		if not isSpectator and not chosen then
			AutoPickFaction()
		end
		-- (the phase change above is the usual way out; this is the fallback)
		widgetHandler:RemoveWidget(self)
		return
	end

	Refresh()
end
