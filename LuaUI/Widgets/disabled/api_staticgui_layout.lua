function widget:GetInfo()
	return {
		name    = "Static GUI Layout",
		desc    = "Tweak-mode (Ctrl+F11) drag/reposition for every Static GUI panel. Owns anchor-relative position persistence so the panel widgets never have to.",
		author  = "Scary le Poo",
		date    = "2026-08-25",
		license = "GNU GPL, v2 or later",
		layer   = -99999,    -- after api_staticgui_shapes (-100000), before every panel widget
		enabled = true,
		handler = true,
	}
end

--------------------------------------------------------------------------------
--
-- HOW A PANEL WIDGET USES THIS
--
-- 1. Bind once (same shim pattern as BindDrawing):
--
--        local L = WG.StaticLayout
--        local LayoutPlace = L and L.Place or function(_, x, y) return x, y end
--
-- 2. In the geometry builder, right where the default origin is computed from
--    vsx/vsy, route it through Place. Pass the panel's default bottom-left
--    corner and its size; get back the effective bottom-left corner:
--
--        x1, y1 = LayoutPlace("playerslist", x1, y1, pw, ph)
--
--    Place records the live rect (for hit-testing and the tweak overlay) and
--    returns the user's stored position if one exists, otherwise the default.
--    Everything downstream of the origin works unchanged.
--
-- 3. In Initialize, register so the module can label the rect in the overlay
--    and tell the widget to rebuild after a drop:
--
--        if L then L.Register("playerslist", {
--            label  = "Players List",
--            onMove = function() widget:ViewResize(vsx, vsy) end,
--        }) end
--
--    and in Shutdown:  if L then L.Unregister("playerslist") end
--
-- That is the whole contract. The widget owns its geometry; this module owns
-- the *origin* of that geometry, and only when the user has moved it.
--
--
-- HOW POSITIONS ARE STORED
--
-- Not as pixels. Each moved rect is stored as (anchor corner, offset from
-- that corner) where the anchor is the screen corner nearest the rect's centre
-- at drop time and the offset is measured from the anchor corner to the
-- rect's matching corner, in units of uiScale (vsy / 1080). A panel dropped
-- 40 scaled pixels in from the bottom-right stays 40 scaled pixels in from
-- the bottom-right on every resolution, and a panel whose height varies
-- (players list) grows away from its anchor edge instead of drifting.
--
--
-- TWEAK MODE
--
-- The widget handler routes mouse input to the Tweak* callins when tweak
-- mode is on (Ctrl+F11). Only this widget defines them, so there is nothing
-- to arbitrate: it hit-tests against every rect that has been Placed, drags
-- a ghost outline, and on release stores the new anchor/offset and fires the
-- owner's onMove. Right-click on a rect resets it to its default.
-- /resetlayout resets all of them.
--
-- Dragging a ghost rather than the live panel is deliberate: TexCache blits
-- would follow a moved origin for free, but text drawn outside the cache and
-- every hit-rect would not, and SG.SetOffset does not reach font:Print. One
-- rebuild on drop is correct for every widget without touching a draw path.
--
--------------------------------------------------------------------------------

local spGetViewGeometry = Spring.GetViewGeometry
local spGetMouseState   = Spring.GetMouseState
local spEcho            = Spring.Echo
local math_floor        = math.floor
local math_max          = math.max
local math_min          = math.min
local math_abs          = math.abs

local BASE_RESOLUTION   = 1080
local FONT_FILE         = LUAUI_DIRNAME .. "fonts/" .. Spring.GetConfigString("ui_font", "Saira_SemiCondensed-SemiBold.ttf")

-- Overlay colours (guishader-agnostic; the overlay only exists in tweak mode)
local COL_DIM       = { 0.00, 0.00, 0.00, 0.35 }
local COL_FILL      = { 0.20, 0.55, 0.95, 0.18 }
local COL_FILL_HOT  = { 0.20, 0.55, 0.95, 0.32 }
local COL_FILL_MOVED= { 0.95, 0.70, 0.20, 0.18 }
local COL_OUTLINE   = { 0.45, 0.75, 1.00, 0.90 }
local COL_OUTLINE_MV= { 1.00, 0.80, 0.30, 0.90 }
local COL_GHOST     = { 1.00, 1.00, 1.00, 0.85 }
local COL_TEXT      = { 1.00, 1.00, 1.00, 1.00 }
local COL_TEXT_DIM  = { 0.85, 0.85, 0.85, 0.85 }

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local vsx, vsy = spGetViewGeometry()
local uiScale  = vsy / BASE_RESOLUTION

-- rects[name]  = { x1, y1, x2, y2, w, h, defX, defY, placedFrame }
--   the live rect as of the last Place call, plus the default origin the
--   owning widget passed in (so Reset can put it back without a rebuild
--   round-trip).
local rects = {}
local rectOrder = {}     -- names in first-Place order, for stable overlay draw

-- registry[name] = { label, onMove, isVisible }
local registry = {}

-- stored[name] = { ax, ay, ox, oy }   ax/ay in {0,1}: 0 = left/bottom, 1 = right/top
-- ox/oy are in uiScale units, measured from the anchor corner inward.
local stored = {}

-- Drag state
local drag = nil         -- { name, grabDX, grabDY, x1, y1 }
local hover = nil

local font = nil
local fontSize = 14

--------------------------------------------------------------------------------
-- Drawing shim
--------------------------------------------------------------------------------

local SG = nil
local function BindDrawing()
	SG = WG.StaticGUI
	if SG and not SG.RoundedRect then SG = nil end
end

local function FillRect(x1, y1, x2, y2, col, radius)
	if SG then
		SG.RoundedRect(x1, y1, x2, y2, radius or 0, col)
	else
		gl.Color(col[1], col[2], col[3], col[4])
		gl.Rect(x1, y1, x2, y2)
	end
end

local function OutlineRect(x1, y1, x2, y2, col, width, radius)
	if SG then
		SG.RoundedOutline(x1, y1, x2, y2, radius or 0, col, width or 2)
	else
		gl.Color(col[1], col[2], col[3], col[4])
		gl.LineWidth(width or 2)
		gl.Shape(GL.LINE_LOOP, {
			{ v = { x1, y1 } }, { v = { x2, y1 } },
			{ v = { x2, y2 } }, { v = { x1, y2 } },
		})
		gl.LineWidth(1)
	end
end

local function FlushShapes()
	if SG and SG.Flush then SG.Flush() end
end

local function LoadOverlayFont()
	if font then
		gl.DeleteFont(font)
		font = nil
	end
	fontSize = math_max(11, math_floor(14 * uiScale))
	font = gl.LoadFont(FONT_FILE, fontSize, math_max(1, math_floor(3 * uiScale)), 1.6)
end

--------------------------------------------------------------------------------
-- Position maths
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
-- Public API
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
-- Hit testing
--------------------------------------------------------------------------------

-- Smallest rect under the cursor wins, so a small panel sitting on top of a
-- large one is still grabbable.
local function RectAt(x, y)
	local best, bestArea = nil, math.huge
	for _, name in ipairs(rectOrder) do
		local r = rects[name]
		if r and x >= r.x1 and x <= r.x2 and y >= r.y1 and y <= r.y2 then
			local area = r.w * r.h
			if area < bestArea then
				best, bestArea = name, area
			end
		end
	end
	return best
end

--------------------------------------------------------------------------------
-- Widget lifecycle
--------------------------------------------------------------------------------

function widget:Initialize()
	BindDrawing()
	vsx, vsy = spGetViewGeometry()
	uiScale  = vsy / BASE_RESOLUTION
	LoadOverlayFont()

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
end

function widget:Shutdown()
	local ah = widgetHandler.actionHandler
	if ah then
		ah:RemoveAction(widget, "resetlayout")
	elseif widgetHandler.RemoveAction then
		widgetHandler:RemoveAction("resetlayout")
	end
	if font then gl.DeleteFont(font) end
	font = nil
	WG.StaticLayout = nil
end

function widget:ViewResize(nx, ny)
	vsx, vsy = nx, ny
	uiScale  = vsy / BASE_RESOLUTION
	LoadOverlayFont()
	-- Panel widgets re-Place themselves from their own ViewResize; nothing to
	-- do here. Stored positions are resolution-independent by construction.
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

--------------------------------------------------------------------------------
-- Tweak-mode input
--------------------------------------------------------------------------------

function widget:TweakIsAbove(x, y)
	return RectAt(x, y) ~= nil
end

function widget:TweakGetTooltip(x, y)
	local name = RectAt(x, y)
	if not name then return nil end
	local reg = registry[name]
	local label = reg and reg.label or name
	if stored[name] then
		return label .. "\nDrag to move. Right-click to reset."
	end
	return label .. "\nDrag to move."
end

function widget:TweakMousePress(x, y, button)
	local name = RectAt(x, y)
	if not name then return false end
	local r = rects[name]

	if button == 3 then
		L.Reset(name)
		return true
	end
	if button ~= 1 then return false end

	drag = {
		name   = name,
		grabDX = x - r.x1,
		grabDY = y - r.y1,
		x1     = r.x1,
		y1     = r.y1,
	}
	return true
end

function widget:TweakMouseMove(x, y, dx, dy, button)
	if not drag then return false end
	local r = rects[drag.name]
	if not r then drag = nil ; return false end
	drag.x1, drag.y1 = ClampOrigin(x - drag.grabDX, y - drag.grabDY, r.w, r.h)
	return true
end

function widget:TweakMouseRelease(x, y, button)
	if not drag then return false end
	local d = drag
	drag = nil
	local r = rects[d.name]
	if not r then return true end

	-- A click without movement is not a move.
	if math_abs(d.x1 - r.x1) < 1 and math_abs(d.y1 - r.y1) < 1 then
		return true
	end

	L.Set(d.name, d.x1, d.y1)
	NotifyMove(d.name)
	return true
end

--------------------------------------------------------------------------------
-- Tweak-mode overlay
--------------------------------------------------------------------------------

-- The handler has no separate TweakDrawScreen list: it walks DrawScreenList
-- and calls w:TweakDrawScreen() after w:DrawScreen() when tweak mode is on
-- (cont/LuaUI/widgets.lua, DrawScreen). A widget without DrawScreen is
-- never asked to draw its tweak overlay, so this stub must exist.
function widget:DrawScreen()
end

local function DrawLabel(x1, y1, x2, y2, text, col)
	if not font then return end
	local cx = (x1 + x2) * 0.5
	local cy = (y1 + y2) * 0.5 - fontSize * 0.35
	font:Begin()
	font:SetTextColor(col[1], col[2], col[3], col[4])
	font:Print(text, cx, cy, fontSize, "co")
	font:End()
end

function widget:TweakDrawScreen()
	BindDrawing()   -- the shapes module can be toggled; cheap to re-resolve
	local mx, my = spGetMouseState()
	hover = drag and drag.name or RectAt(mx, my)

	FillRect(0, 0, vsx, vsy, COL_DIM)

	for _, name in ipairs(rectOrder) do
		local r = rects[name]
		if r then
			local reg    = registry[name]
			local moved  = stored[name] ~= nil
			local isHot  = (name == hover)
			local isDrag = drag and drag.name == name
			local fill   = isHot and COL_FILL_HOT or (moved and COL_FILL_MOVED or COL_FILL)
			local line   = moved and COL_OUTLINE_MV or COL_OUTLINE
			local hidden = reg and reg.isVisible and not reg.isVisible()

			if hidden then
				fill = { fill[1], fill[2], fill[3], fill[4] * 0.5 }
				line = { line[1], line[2], line[3], line[4] * 0.5 }
			end

			if not isDrag then
				FillRect(r.x1, r.y1, r.x2, r.y2, fill, 3 * uiScale)
				OutlineRect(r.x1, r.y1, r.x2, r.y2, line, 2, 3 * uiScale)
			end
		end
	end

	if drag then
		local r = rects[drag.name]
		if r then
			local gx1, gy1 = drag.x1, drag.y1
			local gx2, gy2 = gx1 + r.w, gy1 + r.h
			FillRect(gx1, gy1, gx2, gy2, COL_FILL_HOT, 3 * uiScale)
			OutlineRect(gx1, gy1, gx2, gy2, COL_GHOST, 2, 3 * uiScale)
		end
	end

	FlushShapes()

	-- Labels after the flush so text sits on top of the batched shapes.
	for _, name in ipairs(rectOrder) do
		local r = rects[name]
		if r and not (drag and drag.name == name) then
			local reg = registry[name]
			local hidden = reg and reg.isVisible and not reg.isVisible()
			local label = reg and reg.label or name
			if r.h >= fontSize * 1.4 and r.w >= fontSize * 4 then
				DrawLabel(r.x1, r.y1, r.x2, r.y2, label, hidden and COL_TEXT_DIM or COL_TEXT)
			end
		end
	end
	if drag then
		local r = rects[drag.name]
		if r then
			local reg = registry[drag.name]
			DrawLabel(drag.x1, drag.y1, drag.x1 + r.w, drag.y1 + r.h, reg and reg.label or drag.name, COL_TEXT)
		end
	end

	-- Hint line along the bottom edge
	if font then
		font:Begin()
		font:SetTextColor(1, 1, 1, 0.8)
		font:Print("Tweak mode: drag panels to move, right-click to reset one, /resetlayout to reset all",
		           vsx * 0.5, math_floor(8 * uiScale), fontSize, "co")
		font:End()
	end

	gl.Color(1, 1, 1, 1)
end
