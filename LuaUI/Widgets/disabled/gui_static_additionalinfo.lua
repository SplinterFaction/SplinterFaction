function widget:GetInfo()
	return {
		name    = "Static Additional Info",
		desc    = "Spacebar-toggled additional info panel. Thin satellite of the Static Tooltip Panel: all section rendering and panel data come through WG.StaticTooltip; this widget owns only visibility, scrolling and its own texture cache.",
		author  = "Scary le Poo",
		date    = "2026-08-14",
		license = "GPL v2 or later",
		layer   = 2,
		enabled = true,
	}
end

include("keysym.h.lua")

--------------------------------------------------------------------------------
-- Speedups
--------------------------------------------------------------------------------

local spIsGUIHidden     = Spring.IsGUIHidden
local spGetMouseState   = Spring.GetMouseState
local spPlaySoundFile   = Spring.PlaySoundFile
local math_floor        = math.floor
local math_max          = math.max
local math_abs          = math.abs

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local show          = false   -- spacebar toggle
local scrollOffset  = 0
local contentH      = 0
local viewH         = 0
local scrollbarInfo = nil
local dragging      = false
local dragOffset    = 0

local cache         = nil     -- SG.TexCache handle (or legacy display list)
local cacheDirty    = true
local lastVersion   = -1
local lastX1, lastY1, lastX2, lastY2 = 0, 0, 0, 0

--------------------------------------------------------------------------------
-- Drawing shim (see api_staticgui_shapes.lua). The heavy rendering happens in
-- the tooltip widget's exported baker; this widget only needs the cache API
-- and a flush.
--------------------------------------------------------------------------------

local TexCache, DrawCache, FreeCache, Flush

local function NoOp() end

local function BindDrawing()
	local SG = WG.StaticGUI
	if SG and SG.TexCache then
		TexCache  = SG.TexCache
		DrawCache = SG.DrawCache
		FreeCache = SG.FreeCache
		Flush     = SG.Flush
	else
		-- No FBO textures without the shape module: a legacy cache handle is a
		-- real display list id, built the way the tooltip always did.
		TexCache  = function(c, _, _, _, _, fn)
			if c then gl.DeleteList(c) end
			return gl.CreateList(fn)
		end
		DrawCache = function(c) if c then gl.CallList(c) end end
		FreeCache = function(c) if c then gl.DeleteList(c) end end
		Flush     = NoOp
	end
end

BindDrawing()

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function Clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

local function PlayToggleSound()
	spPlaySoundFile("leftclick", 1.0, "ui")
end

local function FreeCacheNow()
	FreeCache(cache)
	cache = nil
	cacheDirty = true
end

--------------------------------------------------------------------------------
-- Widget lifecycle
--------------------------------------------------------------------------------

function widget:Initialize()
	BindDrawing()
end

function widget:Shutdown()
	FreeCacheNow()
end

function widget:ViewResize()
	-- Geometry comes from the tooltip widget; the rect comparison in
	-- DrawScreen catches the change, this just makes it immediate.
	cacheDirty = true
end

--------------------------------------------------------------------------------
-- Input
--------------------------------------------------------------------------------

function widget:KeyPress(key, mods, isRepeat)
	if isRepeat then return false end
	if key == KEYSYMS.SPACE then
		show = not show
		scrollOffset = 0
		cacheDirty = true
		PlayToggleSound()
		return true
	end
	return false
end

function widget:IsAbove(x, y)
	if show and scrollbarInfo then
		local i = scrollbarInfo
		if x >= i.x1 and x <= i.x2 and y >= i.y1 and y <= i.y2 then return true end
	end
	return false
end

function widget:MousePress(x, y, button)
	if button ~= 1 or not show then return false end
	local ST = WG.StaticTooltip
	if not ST then return false end

	if scrollbarInfo and contentH > viewH then
		local info = scrollbarInfo
		if x >= info.x1 and x <= info.x2 and y >= info.y1 and y <= info.y2 then
			local _, _, _, _, uiScale = ST.GetAdditionalRect()
			dragging = true
			local trackH = info.y2 - info.y1
			local thumbH = math_max(math_floor(20 * (uiScale or 1)), trackH * (viewH / math_max(contentH, 1)))
			local range  = trackH - thumbH
			local frac   = Clamp(scrollOffset / math_max(1, contentH - viewH), 0, 1)
			local ty2    = info.y2 - range * frac
			dragOffset = ty2 - y
			return true
		end
	end
	return false
end

function widget:MouseRelease(x, y, button)
	if dragging then
		dragging = false
		return true
	end
	return false
end

function widget:MouseWheel(up, value)
	if not show then return false end
	local ST = WG.StaticTooltip
	if not (ST and ST.HasAdditional()) then return false end

	local ax1, ay1, ax2, ay2, uiScale = ST.GetAdditionalRect()
	local mx, my = spGetMouseState()
	if mx >= ax1 and mx <= ax2 and my >= ay1 and my <= ay2 and contentH > viewH then
		local step   = math_floor(40 * (uiScale or 1))
		local delta  = up and -step or step
		local newOff = Clamp(scrollOffset + delta, 0, math_max(0, contentH - viewH))
		if newOff ~= scrollOffset then
			scrollOffset = newOff
			cacheDirty = true
		end
		return true
	end
	return false
end

--------------------------------------------------------------------------------
-- Draw
--------------------------------------------------------------------------------

function widget:DrawScreen()
	if spIsGUIHidden() then return end

	local ST = WG.StaticTooltip
	if not (show and ST and ST.HasAdditional()) then
		scrollbarInfo = nil
		return
	end

	local ax1, ay1, ax2, ay2, uiScale = ST.GetAdditionalRect()
	if ax2 - ax1 <= 0 or ay2 - ay1 <= 0 then return end

	-- Scrollbar dragging (immediate, each frame).
	if dragging and scrollbarInfo and contentH > viewH then
		local mx, my = spGetMouseState()
		local info   = scrollbarInfo
		local trackH = info.y2 - info.y1
		local thumbH = math_max(math_floor(20 * (uiScale or 1)), trackH * (viewH / math_max(contentH, 1)))
		local range  = trackH - thumbH
		if range > 0 then
			local ty2    = Clamp(my + dragOffset, info.y1 + thumbH, info.y2)
			local frac   = (info.y2 - ty2) / range
			local newOff = Clamp(frac * (contentH - viewH), 0, contentH - viewH)
			if math_abs(newOff - scrollOffset) > 0.5 then
				scrollOffset = newOff
				cacheDirty = true
			end
		end
	end

	-- Data changed under us: reset scroll, rebuild.
	local ver = ST.GetDataVersion()
	if ver ~= lastVersion then
		lastVersion = ver
		scrollOffset = 0
		cacheDirty = true
	end

	-- Geometry changed (resize, tooltip layout): rebuild.
	if ax1 ~= lastX1 or ay1 ~= lastY1 or ax2 ~= lastX2 or ay2 ~= lastY2 then
		lastX1, lastY1, lastX2, lastY2 = ax1, ay1, ax2, ay2
		cacheDirty = true
	end

	if cacheDirty then
		cache = TexCache(cache, ax1, ay1, ax2, ay2, function()
			contentH, scrollOffset, viewH, _, scrollbarInfo = ST.BakeAdditional(scrollOffset)
		end)
		cacheDirty = false
	end

	DrawCache(cache, ax1, ay1)

	if scrollbarInfo and contentH > viewH then
		local mx, my = spGetMouseState()
		ST.DrawThumb(scrollbarInfo, contentH, viewH, scrollOffset, mx, my)
	end

	Flush()
end
