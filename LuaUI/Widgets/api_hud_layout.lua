--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Layout of the RmlUi HUD: where each panel is, when the player has moved
--  it, and the tweak mode (Ctrl+F11) in which panels are dragged around.
--
--  HOW A PANEL WIDGET USES THIS
--
--  Through LuaUI/rml/hud.lua: hud.PlacePanel(element, name, widthDp, heightDp,
--  defaultOrigin) asks WG.StaticLayout.Place for the panel's place (the
--  player's, if they moved it, or else the default passed in), and
--  hud.RegisterPanel(name, label, onMove, isVisible) gives the panel a label
--  in tweak mode and a function to call after it has been dropped somewhere
--  new. The widget owns its geometry; this module owns the origin of that
--  geometry, and only when the player has moved it.
--
--  HOW POSITIONS ARE STORED
--
--  Not as pixels. Each moved rect is stored as (anchor corner, offset from
--  that corner) where the anchor is the screen corner nearest the rect's centre
--  at drop time and the offset is measured from the anchor corner to the
--  rect's matching corner, in units of uiScale (vsy / 1080). A panel dropped
--  40 scaled pixels in from the bottom-right stays 40 scaled pixels in from
--  the bottom-right on every resolution, and a panel whose height varies
--  (players list) grows away from its anchor edge instead of drifting.
--
--  TWEAK MODE
--
--  While the widget handler is in tweak mode this widget shows an RmlUi
--  overlay over everything: one rectangle per panel, named, to drag. A right
--  click puts a panel back in its default place; "Reset all" (or
--  /resetlayout) does that for every panel. "Done" or Esc leaves tweak mode.
--
--  The overlay has to be RmlUi: the engine draws RmlUi over everything a
--  widget draws with gl and gives it the mouse first, so a gl overlay (as in
--  the old module) would sit under the panels it is meant to move.
--
--  Replaces api_staticgui_layout.lua (kept in Widgets/disabled/), whose saved
--  positions it takes over. The interface keeps its old name, WG.StaticLayout.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name    = "Bastion HUD Layout",
		previousNames = {"HUD Layout"},
		desc    = "Tweak mode (Ctrl+F11): drag any HUD panel to a new place. Remembers where panels were put. (RmlUi)",
		author  = "Scary le Poo; SplinterFaction Team",
		date    = "2026-10-13",
		license = "GNU GPL, v2 or later",
		layer   = -99999,    -- before every panel widget
		enabled = true,
		handler = true,
	}
end

local DOCUMENT_PATH = "LuaUI/rml/layout.rml"
local OLD_WIDGET    = "Static GUI Layout" -- whose saved positions this widget takes over

local spGetViewGeometry = Spring.GetViewGeometry
local spGetMouseState   = Spring.GetMouseState
local spEcho            = Spring.Echo

local math_floor        = math.floor
local math_max          = math.max
local math_min          = math.min
local math_abs          = math.abs

local BASE_RESOLUTION   = 1080

--------------------------------------------------------------------------------
-- state
--------------------------------------------------------------------------------

local vsx, vsy = spGetViewGeometry()
local uiScale  = vsy / BASE_RESOLUTION

-- rects[name]  = { x1, y1, x2, y2, w, h, defX, defY }
--   the live rect as of the last Place call, plus the default origin the
--   owning widget passed in (so Reset can put it back without a rebuild
--   round-trip).
local rects = {}
local rectOrder = {}     -- names in first-Place order

-- registry[name] = { label, onMove, isVisible }
local registry = {}

-- stored[name] = { ax, ay, ox, oy }   ax/ay in {0,1}: 0 = left/bottom, 1 = right/top
-- ox/oy are in uiScale units, measured from the anchor corner inward.
local stored = {}

local drag = nil         -- { name, grabDX, grabDY, x1, y1 } while a rectangle is being dragged

local hud
local document
local view
local tweaking = false   -- the overlay is up
local shownOrder = {}    -- names in the order of the overlay's rectangles: element i is "r<i>"
local shownSignature

--------------------------------------------------------------------------------
-- position maths (carried over)
--------------------------------------------------------------------------------

local function Clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

-- Clamp a rect origin so the rect stays fully on screen (or as fully as its
-- size allows).
local function ClampOrigin(x1, y1, w, h)
	x1 = Clamp(x1, 0, math_max(0, vsx - w))
	y1 = Clamp(y1, 0, math_max(0, vsy - h))
	return math_floor(x1), math_floor(y1)
end

-- Convert an absolute bottom-left origin into anchor + scaled offset.
local function Encode(x1, y1, w, h)
	local cx, cy = x1 + w * 0.5, y1 + h * 0.5
	local ax = (cx < vsx * 0.5) and 0 or 1
	local ay = (cy < vsy * 0.5) and 0 or 1
	local ox = (ax == 0) and x1 or (vsx - (x1 + w))
	local oy = (ay == 0) and y1 or (vsy - (y1 + h))
	return { ax = ax, ay = ay, ox = ox / uiScale, oy = oy / uiScale }
end

-- Resolve anchor + scaled offset back to an absolute bottom-left origin for
-- the given size on the current screen.
local function Decode(s, w, h)
	local ox, oy = s.ox * uiScale, s.oy * uiScale
	local x1 = (s.ax == 0) and ox or (vsx - ox - w)
	local y1 = (s.ay == 0) and oy or (vsy - oy - h)
	return ClampOrigin(x1, y1, w, h)
end

--------------------------------------------------------------------------------
-- public API (carried over)
--------------------------------------------------------------------------------

local L = {}

-- The one call every panel widget makes from its geometry builder.
function L.Place(name, defX1, defY1, w, h)
	w = math_max(1, math_floor(w or 1))
	h = math_max(1, math_floor(h or 1))
	local r = rects[name]
	if not r then
		r = {}
		rects[name] = r
		rectOrder[#rectOrder + 1] = name
	end
	r.defX, r.defY, r.w, r.h = math_floor(defX1), math_floor(defY1), w, h

	local x1, y1 = r.defX, r.defY
	local s = stored[name]
	if s then
		x1, y1 = Decode(s, w, h)
	end
	r.x1, r.y1, r.x2, r.y2 = x1, y1, x1 + w, y1 + h
	return x1, y1
end

function L.Register(name, opts)
	opts = opts or {}
	registry[name] = {
		label     = opts.label or name,
		onMove    = opts.onMove,
		isVisible = opts.isVisible,
	}
end

function L.Unregister(name)
	registry[name] = nil
	rects[name] = nil
	for i = #rectOrder, 1, -1 do
		if rectOrder[i] == name then table.remove(rectOrder, i) end
	end
end

-- Live rect as of the last Place. Returns x1, y1, x2, y2 or nil.
function L.GetRect(name)
	local r = rects[name]
	if not r then return nil end
	return r.x1, r.y1, r.x2, r.y2
end

function L.IsMoved(name)
	return stored[name] ~= nil
end

local function NotifyMove(name)
	local reg = registry[name]
	if reg and reg.onMove then
		local ok, err = pcall(reg.onMove)
		if not ok then
			spEcho("[StaticLayout] onMove for '" .. name .. "' failed: " .. tostring(err))
		end
	end
end

-- Programmatic set from a widget that has its own normal-mode drag (survival
-- panel). Absolute bottom-left; size comes from the last Place.
function L.Set(name, x1, y1)
	local r = rects[name]
	if not r then return end
	x1, y1 = ClampOrigin(x1, y1, r.w, r.h)
	stored[name] = Encode(x1, y1, r.w, r.h)
	r.x1, r.y1, r.x2, r.y2 = x1, y1, x1 + r.w, y1 + r.h
end

function L.Reset(name)
	if not stored[name] then return end
	stored[name] = nil
	local r = rects[name]
	if r then
		r.x1, r.y1, r.x2, r.y2 = r.defX, r.defY, r.defX + r.w, r.defY + r.h
	end
	NotifyMove(name)
end

function L.ResetAll()
	local any = false
	for name in pairs(stored) do any = true end
	stored = {}
	if not any then return end
	for _, name in ipairs(rectOrder) do
		local r = rects[name]
		if r then
			r.x1, r.y1, r.x2, r.y2 = r.defX, r.defY, r.defX + r.w, r.defY + r.h
		end
		NotifyMove(name)
	end
	spEcho("[StaticLayout] all panel positions reset")
end

--------------------------------------------------------------------------------
-- the overlay
--------------------------------------------------------------------------------

-- Largest first, so that a small panel lying on a large one is drawn over it
-- and gets the mouse.
local function OverlayOrder()
	local names = {}
	for _, name in ipairs(rectOrder) do
		if rects[name] then
			names[#names + 1] = name
		end
	end
	table.sort(names, function(a, b)
		local areaA, areaB = rects[a].w * rects[a].h, rects[b].w * rects[b].h
		if areaA ~= areaB then
			return areaA > areaB
		end
		return a < b
	end)
	return names
end

local function Refresh()
	view.SetClass("tweak", "hidden", not tweaking)
	if not tweaking then
		return
	end
	-- the rectangles are rebuilt only when panels come, go or are renamed
	local names = OverlayOrder()
	local parts, signature = {}, {}
	for i, name in ipairs(names) do
		local reg = registry[name]
		local label = hud.Escape(reg and reg.label or name)
		parts[i] = string.format('<div id="r%d" class="rect" data-r="%d"><div class="rlabel">%s</div></div>', i, i, label)
		signature[i] = name .. "=" .. label
	end
	signature = table.concat(signature, "|")
	if signature ~= shownSignature then
		shownSignature = signature
		shownOrder = names
		view.Element("rects").inner_rml = table.concat(parts)
		view.Forget()
		view.SetClass("tweak", "hidden", false)
	end
	for i, name in ipairs(shownOrder) do
		local r = rects[name]
		if r then
			local id = "r" .. i
			local x1, y1 = r.x1, r.y1
			local dragging = drag and drag.name == name
			if dragging then
				x1, y1 = drag.x1, drag.y1
			end
			view.SetStyle(id, "left", x1 .. "px")
			view.SetStyle(id, "top", (vsy - (y1 + r.h)) .. "px")
			view.SetStyle(id, "width", r.w .. "px")
			view.SetStyle(id, "height", r.h .. "px")
			local reg = registry[name]
			view.SetClass(id, "moved", stored[name] ~= nil)
			view.SetClass(id, "off", (reg and reg.isVisible and not reg.isVisible()) and true or false)
			view.SetClass(id, "dragging", dragging and true or false)
		end
	end
end

-- RmlUi numbers the buttons left 0, right 1
local function OnRectMouseDown(event)
	local index = hud.EventAttribute(event, "data-r")
	local name = index and shownOrder[index]
	local r = name and rects[name]
	if not r then
		return
	end
	local button = event.parameters and event.parameters.button
	if button == 1 then
		drag = nil
		L.Reset(name)
		Refresh()
	elseif button == 0 then
		local mx, my = spGetMouseState()
		drag = { name = name, grabDX = mx - r.x1, grabDY = my - r.y1, x1 = r.x1, y1 = r.y1 }
		Refresh()
	end
end

-- The drop. (The engine does not report the button as held once RmlUi has
-- taken the press, so the release has to come from RmlUi: "mouseup", or
-- "dragend" when RmlUi saw the movement as a drag. Whichever comes first
-- ends the drag; the other finds nothing to do.)
local function OnRelease()
	if not drag then
		return
	end
	local d = drag
	drag = nil
	local r = rects[d.name]
	-- a click without movement is not a move
	if r and (math_abs(d.x1 - r.x1) >= 1 or math_abs(d.y1 - r.y1) >= 1) then
		L.Set(d.name, d.x1, d.y1)
		NotifyMove(d.name)
	end
	Refresh()
end

local function LeaveTweakMode()
	drag = nil
	widgetHandler.tweakMode = false
end

--------------------------------------------------------------------------------
-- widget api
--------------------------------------------------------------------------------

function widget:Initialize()
	vsx, vsy = spGetViewGeometry()
	uiScale  = vsy / BASE_RESOLUTION

	-- positions saved by the old module, the first time this one runs
	if next(stored) == nil then
		local old = widgetHandler.configData and widgetHandler.configData[OLD_WIDGET]
		if type(old) == "table" then
			widget:SetConfigData(old)
		end
	end

	WG.StaticLayout = L

	-- With handler=true this widget holds the real widgetHandler, which has no
	-- AddAction proxy; register through actionHandler directly and fall back
	-- to the proxy form for handlers that only expose that.
	local ah = widgetHandler.actionHandler
	if ah then
		ah:AddAction(widget, "resetlayout", function() L.ResetAll() end, nil, "t")
	elseif widgetHandler.AddAction then
		widgetHandler:AddAction("resetlayout", function() L.ResetAll() end, nil, "t")
	end

	-- The overlay. Positions are kept and served without it, so a document
	-- that fails to load costs only the dragging.
	local helpers = include("rml/hud.lua")
	local result, reason = helpers.LoadDocument(DOCUMENT_PATH, widget)
	if not result then
		spEcho("[HUD Layout] " .. tostring(reason))
		return
	end
	hud = helpers
	document = result
	view = hud.NewView(document)
	view.Assume("tweak", "hidden", true) -- set in the markup

	local container = view.Element("rects")
	container:AddEventListener("mousedown", OnRectMouseDown)
	local root = view.Element("tweak")
	root:AddEventListener("mouseup", OnRelease)
	root:AddEventListener("dragend", OnRelease)
	hud.OnClick(view, "tweak-reset", function()
		Spring.PlaySoundFile("leftclick", 1.0, "ui")
		L.ResetAll()
		Refresh()
	end)
	hud.OnClick(view, "tweak-done", function()
		Spring.PlaySoundFile("leftclick", 1.0, "ui")
		LeaveTweakMode()
	end)
	hud.ShowPassive(document)
end

function widget:Shutdown()
	local ah = widgetHandler.actionHandler
	if ah then
		ah:RemoveAction(widget, "resetlayout")
	elseif widgetHandler.RemoveAction then
		widgetHandler:RemoveAction("resetlayout")
	end
	WG.StaticLayout = nil
	if document then
		document:Close()
		document = nil
	end
end

function widget:ViewResize(nx, ny)
	vsx, vsy = spGetViewGeometry()
	uiScale  = vsy / BASE_RESOLUTION
	-- Panel widgets re-Place themselves from their own ViewResize; nothing to
	-- do here. Stored positions are resolution-independent by construction.
	if hud and document then
		hud.UpdateScale()
		view.ForgetStyles()
	end
end

function widget:Update()
	if not document then
		return
	end
	local on = widgetHandler.tweakMode and true or false
	if on ~= tweaking then
		tweaking = on
		drag = nil
		if on then
			pcall(function() document:PullToFront() end)
		end
		Refresh()
	end
	if not tweaking then
		return -- idle cost stops here
	end
	if drag then
		local r = rects[drag.name]
		if r then
			local mx, my = spGetMouseState()
			drag.x1, drag.y1 = ClampOrigin(mx - drag.grabDX, my - drag.grabDY, r.w, r.h)
		else
			drag = nil
		end
	end
	Refresh() -- a few dozen comparisons; windows open and close while tweaking
end

function widget:GetConfigData()
	local out = {}
	for name, s in pairs(stored) do
		out[name] = { ax = s.ax, ay = s.ay, ox = s.ox, oy = s.oy }
	end
	return { version = 1, rects = out }
end

function widget:SetConfigData(data)
	if type(data) ~= "table" or type(data.rects) ~= "table" then return end
	stored = {}
	for name, s in pairs(data.rects) do
		if type(s) == "table" and type(s.ox) == "number" and type(s.oy) == "number" then
			stored[name] = {
				ax = (s.ax == 1) and 1 or 0,
				ay = (s.ay == 1) and 1 or 0,
				ox = s.ox, oy = s.oy,
			}
		end
	end
end
