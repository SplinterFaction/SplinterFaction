--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Minimap placement and frame of the RmlUi HUD. Puts the engine's minimap in
--  the top left corner, sized to the map's proportions, and draws a frame
--  around it. The minimap itself stays the engine's.
--
--  Replaces gui_minimap_top_left.lua (kept in Widgets/disabled/).
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name    = "Minimap Top Left",
		desc    = "Places the default minimap in the top-left corner with a frame around it (RmlUi)",
		author  = "SplinterFaction Team",
		date    = "2026-10-13",
		license = "GPL v2 or later",
		layer   = 1000,
		enabled = true,
	}
end

local DOCUMENT_PATH = "LuaUI/rml/minimap.rml"

local MINIMAP_HEIGHT_RATIO = 400 / 1440 -- share of the screen's height; tuned at 1440p
local PADDING = 8     -- pixels between the screen's edge and the minimap
local FRAME_DP = 3    -- the frame's thickness (must match the borders in minimap.rml: 2 + 1)
local SETTLE_FRAMES = 30 -- the engine may move the minimap again while loading; repeat for this long

local spSendCommands       = Spring.SendCommands
local spGetMiniMapGeometry = Spring.GetMiniMapGeometry

local hud
local document
local view
local frames = 0
local shown = "" -- the geometry the frame was last given

local function round(x)
	return math.floor(x + 0.5)
end

local function SetMinimap()
	local vsx, vsy = Spring.GetViewGeometry()
	local aspect = Game.mapSizeZ / Game.mapSizeX
	local h = round(vsy * MINIMAP_HEIGHT_RATIO)
	local w = round(h / aspect)
	spSendCommands("minimap geo " .. PADDING .. " " .. PADDING .. " " .. w .. " " .. h)
	spSendCommands("minimap border 0")
end

-- wraps the frame around wherever the minimap is now
local function PlaceFrame()
	if not document then
		return
	end
	local x, y, w, h = spGetMiniMapGeometry() -- y from the bottom of the screen
	if not x or not w or w <= 0 or h <= 0 then
		return
	end
	local _, vsy = Spring.GetViewGeometry()
	local pad = math.max(1, round(FRAME_DP * hud.GetScale()))
	local key = x .. " " .. y .. " " .. w .. " " .. h .. " " .. vsy .. " " .. pad
	if key ~= shown then
		shown = key
		local element = view.Element("minimap-frame")
		element.style["left"] = (x - pad) .. "px"
		element.style["top"] = (vsy - (y + h) - pad) .. "px"
		element.style["width"] = (w + 2 * pad) .. "px"
		element.style["height"] = (h + 2 * pad) .. "px"
	end
end

function widget:Initialize()
	SetMinimap()
	local helpers = include("rml/hud.lua")
	local result, reason = helpers.LoadDocument(DOCUMENT_PATH, widget)
	if not result then
		Spring.Echo("[Minimap Top Left] " .. tostring(reason))
		return -- the minimap is still placed, only without a frame
	end
	hud = helpers
	hud.showInPregame = true -- the minimap is used to pick a start spot
	document = result
	view = hud.NewView(document)
	PlaceFrame()
	hud.ShowPassive(document)
end

function widget:Shutdown()
	if document then
		document:Close()
		document = nil
	end
end

function widget:ViewResize()
	SetMinimap()
	frames = 0
	if hud and document then
		hud.UpdateScale()
	end
end

function widget:Update()
	if frames < SETTLE_FRAMES then
		frames = frames + 1
		SetMinimap()
	end
	if document and not hud.FollowGuiHidden(document) then
		PlaceFrame() -- four numbers compared; the frame is touched only when they change
	end
end
