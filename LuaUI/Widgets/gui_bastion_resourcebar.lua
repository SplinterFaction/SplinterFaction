--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Resource bar, the first piece of the RmlUi HUD.
--
--  One strip at the top center: metal, energy, supply and research points.
--  Replaces gui_static_resourcebar.lua (kept in Widgets/disabled/ until this
--  one has been playtested).
--
--  Metal and energy: stored / storage, net change, income and pull, and a
--  storage bar. Click or drag on a storage bar to set the share level: stock
--  above the marker is shared with allies.
--  Supply: used / maximum, as a bar that fills as you build.
--  Research: the balance, the income smoothed over five seconds, and a short
--  "-N" flash when points are spent.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name    = "Bastion Resource Bar",
		previousNames = {"Resource Bar"},
		desc    = "Top resource bar for metal, energy, supply and research (RmlUi)",
		author  = "SplinterFaction Team",
		date    = "2026-10-12",
		license = "GNU GPL, v2 or later",
		layer   = 1,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- config
--------------------------------------------------------------------------------

local DOCUMENT_PATH   = "LuaUI/rml/resourcebar.rml"
local UPDATE_INTERVAL = 0.1 -- seconds between refreshes

-- must match #resbar in resourcebar.rml
local BAR_WIDTH  = 940
local BAR_HEIGHT = 68
local TOP_MARGIN = 8

local LAYOUT_NAME = "resourcebar"

local DEFAULT_SHARE_LEVEL = 0.8

-- research points (RP): a pure accumulator, no storage cap, no share slider
local RP_RATE_WINDOW    = 150 -- frames (~5s) used to smooth the +/s readout
local RP_FLASH_DURATION = 1.5 -- seconds a spend "-N" stays visible
local GAME_SPEED        = 30  -- sim frames per second

--------------------------------------------------------------------------------
-- locals
--------------------------------------------------------------------------------

local spGetMyTeamID        = Spring.GetMyTeamID
local spGetTeamResources   = Spring.GetTeamResources
local spGetTeamRulesParam  = Spring.GetTeamRulesParam
local spGetSpectatingState = Spring.GetSpectatingState
local spGetGameFrame       = Spring.GetGameFrame
local spSetShareLevel      = Spring.SetShareLevel

local floor = math.floor
local format = string.format

local hud
local document
local view
local SetText, SetClass, SetStyle
local lastUpdate

local shareLevel = {metal = DEFAULT_SHARE_LEVEL, energy = DEFAULT_SHARE_LEVEL}
local dragging -- "metal" or "energy" while a share marker is being dragged

-- research point state
local rpPrevValue          -- last sampled balance (spend detection)
local rpSamples = {}       -- queue of {frame, value}
local rpLastFrame = -1
local rpRate = 0           -- +/s, smoothed over RP_RATE_WINDOW
local rpFlashAmount = 0    -- size of the most recent spend
local rpFlashTimer = 0     -- seconds remaining on the spend flash

--------------------------------------------------------------------------------
-- helpers
--------------------------------------------------------------------------------

local function Round(value)
	return floor(value + 0.5)
end

local function Signed(value)
	-- the rounding is done first so that -0.04 reads "+0.0", not "-0.0"
	value = floor(value * 10 + 0.5) / 10
	if value >= 0 then
		return format("+%.1f", value)
	end
	return format("%.1f", value)
end

local function Percent(fraction)
	if fraction < 0 then
		fraction = 0
	elseif fraction > 1 then
		fraction = 1
	end
	-- half-percent steps: about one pixel of bar, and no restyle for less
	return format("%.1f%%", floor(fraction * 200 + 0.5) / 2)
end

--------------------------------------------------------------------------------
-- metal and energy
--------------------------------------------------------------------------------

-- Bar colors carry a meaning, the same ones the old bar used:
--   metal   red below 20% (stalling), ember above 85% (about to waste it)
--   energy  red below 20% (stalling), green above 80% (plenty)
local THRESHOLDS = {
	metal  = {low = 0.20, high = 0.85},
	energy = {low = 0.20, high = 0.80},
}

local function RefreshResource(team, name, spectating)
	local current, storage, pull, income = spGetTeamResources(team, name)
	current, storage, pull, income = current or 0, storage or 0, pull or 0, income or 0

	local fraction = (storage > 0) and (current / storage) or 0
	local net = income - pull

	SetText(name .. "-cur", tostring(Round(current)))
	SetText(name .. "-max", "/ " .. Round(storage))
	SetText(name .. "-net", Signed(net))
	SetClass(name .. "-net", "good", net >= -0.05)
	SetClass(name .. "-net", "bad", net < -0.05)
	SetText(name .. "-in", format("+%.1f", income))
	SetText(name .. "-out", format("-%.1f", pull))

	SetStyle(name .. "-fill", "width", Percent(fraction))
	local limits = THRESHOLDS[name]
	SetClass(name .. "-fill", "low", fraction < limits.low)
	SetClass(name .. "-fill", "high", fraction > limits.high)

	-- a spectator cannot set anyone's share level
	SetClass(name .. "-share", "hidden", spectating)
	SetClass(name .. "-grab", "live", not spectating)
	SetStyle(name .. "-share", "left", Percent(shareLevel[name]))
	SetClass(name .. "-share", "dragging", dragging == name)
end

--------------------------------------------------------------------------------
-- supply
--------------------------------------------------------------------------------

local function RefreshSupply(team)
	local used = Round(spGetTeamRulesParam(team, "supplyUsed") or 0)
	local max = Round(spGetTeamRulesParam(team, "supplyMax") or 0)
	local free = math.max(0, max - used)
	-- used supply as a share of the maximum: the bar fills as you build, and
	-- gaining supply visibly drops the fill
	local fraction = (max > 0) and (used / max) or 0

	SetText("supply-used", tostring(used))
	SetText("supply-max", "/ " .. max)
	SetText("supply-free", free .. " free")
	SetClass("supply-free", "bad", free == 0 and max > 0)
	SetClass("supply-free", "warn", free > 0 and fraction >= 0.8)

	SetStyle("supply-fill", "width", Percent(fraction))
	-- green while comfortable, ember as it approaches the cap, red when capped
	SetClass("supply-fill", "full", fraction >= 1)
	SetClass("supply-fill", "high", fraction >= 0.8 and fraction < 1)
end

--------------------------------------------------------------------------------
-- research points
--------------------------------------------------------------------------------

-- Samples the RP balance once per sim frame, smooths the income over a window,
-- and detects spends (only a spend lowers the balance).
local function SampleResearch(team, dt)
	local value = spGetTeamRulesParam(team, "researchPoints") or 0

	if rpPrevValue and value < rpPrevValue then
		rpFlashAmount = rpPrevValue - value
		rpFlashTimer = RP_FLASH_DURATION
		-- the spend is not income: restart the window so the rate does not
		-- go negative for the next five seconds
		rpSamples = {}
	end
	rpPrevValue = value

	if rpFlashTimer > 0 then
		rpFlashTimer = math.max(0, rpFlashTimer - (dt or 0))
	end

	local frame = spGetGameFrame()
	if frame ~= rpLastFrame then
		rpLastFrame = frame
		rpSamples[#rpSamples + 1] = {frame, value}
		while #rpSamples > 1 and (frame - rpSamples[1][1]) > RP_RATE_WINDOW do
			table.remove(rpSamples, 1)
		end
		local first = rpSamples[1]
		local span = frame - first[1]
		if span > 0 then
			rpRate = (value - first[2]) / (span / GAME_SPEED)
		end
	end
	return value
end

local function RefreshResearch(value)
	SetText("research-cur", tostring(Round(value)))
	SetText("research-rate", format("+%.1f/s", math.max(0, rpRate)))
	local flashing = rpFlashTimer > 0 and rpFlashAmount > 0
	if flashing then
		SetText("research-spent", "-" .. Round(rpFlashAmount))
	end
	SetClass("research-spent", "hidden", not flashing)
end

--------------------------------------------------------------------------------

local researchValue = 0

local function Refresh()
	local team = spGetMyTeamID()
	if not team then
		return
	end
	local spectating = spGetSpectatingState() and true or false
	RefreshResource(team, "metal", spectating)
	RefreshResource(team, "energy", spectating)
	RefreshSupply(team)
	RefreshResearch(researchValue)
end

--------------------------------------------------------------------------------
-- share level
--------------------------------------------------------------------------------

local function SetShare(name, level)
	if level < 0 then
		level = 0
	elseif level > 1 then
		level = 1
	end
	level = floor(level * 100 + 0.5) / 100
	if shareLevel[name] ~= level then
		shareLevel[name] = level
		spSetShareLevel(name, level)
	end
end

local function StartDrag(name)
	if spGetSpectatingState() then
		return
	end
	dragging = name
	local level = hud.MouseFraction(view.Element(name .. "-grab"))
	if level then
		SetShare(name, level)
	end
	Refresh()
end

-- called every frame while a marker is held
local function FollowDrag()
	local name = dragging
	local level = hud.MouseFraction(view.Element(name .. "-grab"))
	if level then
		SetShare(name, level)
	end
	Refresh()
end

local function EndDrag()
	if dragging then
		dragging = nil
		Refresh()
	end
end

--------------------------------------------------------------------------------
-- placement
--------------------------------------------------------------------------------

local function DefaultOrigin(vsx, vsy, w, h, scale)
	return (vsx - w) * 0.5, vsy - h - TOP_MARGIN * scale
end

local function Place()
	hud.PlacePanel(view.Element("resbar"), LAYOUT_NAME, BAR_WIDTH, BAR_HEIGHT, DefaultOrigin)
end

--------------------------------------------------------------------------------
-- widget api
--------------------------------------------------------------------------------

function widget:Initialize()
	local helpers = include("rml/hud.lua")
	local result, reason = helpers.LoadDocument(DOCUMENT_PATH, widget)
	if not result then
		Spring.Echo("[Resource Bar] " .. tostring(reason))
		widgetHandler:RemoveWidget()
		return
	end
	hud = helpers
	document = result

	view = hud.NewView(document)
	SetText, SetClass, SetStyle = view.SetText, view.SetClass, view.SetStyle
	view.Assume("research-spent", "hidden", true) -- set in the markup
	view.Assume("metal-net", "good", true)
	view.Assume("energy-net", "good", true)

	Spring.SendCommands("resbar 0") -- this bar replaces the engine's

	spSetShareLevel("metal", shareLevel.metal)
	spSetShareLevel("energy", shareLevel.energy)

	for _, name in ipairs({"metal", "energy"}) do
		hud.OnDrag(view, name .. "-grab", function() StartDrag(name) end, EndDrag)
	end

	hud.RegisterPanel(LAYOUT_NAME, "Resources", Place)
	Place()

	local team = spGetMyTeamID()
	if team then
		researchValue = SampleResearch(team, 0)
	end
	Refresh()
	hud.ShowPassive(document)
	lastUpdate = Spring.GetTimer()
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

function widget:Update(dt)
	if not document then
		return
	end

	-- research is sampled every frame, shown or not, so the rate stays right
	local team = spGetMyTeamID()
	if team then
		researchValue = SampleResearch(team, dt)
	end

	if hud.FollowGuiHidden(document) then
		dragging = nil
		return -- hidden with the rest of the GUI (F5)
	end

	if dragging then
		FollowDrag()
		return
	end

	local now = Spring.GetTimer()
	if Spring.DiffTimers(now, lastUpdate) >= UPDATE_INTERVAL then
		lastUpdate = now
		Refresh()
	end
end

-- the share levels are the player's choice: keep them across sessions
function widget:GetConfigData()
	return {metalShare = shareLevel.metal, energyShare = shareLevel.energy}
end

function widget:SetConfigData(data)
	if type(data) ~= "table" then
		return
	end
	if type(data.metalShare) == "number" then
		shareLevel.metal = math.max(0, math.min(1, data.metalShare))
	end
	if type(data.energyShare) == "number" then
		shareLevel.energy = math.max(0, math.min(1, data.energyShare))
	end
end
