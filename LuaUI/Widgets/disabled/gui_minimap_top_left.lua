function widget:GetInfo()
	return {
		name    = "Minimap Top Left",
		desc    = "Places the default minimap in the top-left corner with a custom outer border, and allows custom height setting on load.",
		author  = "",
		date    = "2026-03-21",
		license = "GPL v2 or later",
		layer   = 1000,
		enabled = true,
	}
end

local spSendCommands       = Spring.SendCommands
local spGetViewGeometry    = Spring.GetViewGeometry
local spGetMiniMapGeometry = Spring.GetMiniMapGeometry

local MINIMAP_HEIGHT_RATIO = 400 / 1440  -- tuned at 1440p
local PADDING = 8
local COVER_PAD = 2
local BORDER_SIZE = 2

local function round(x)
	return math.floor(x + 0.5)
end

local function SetMinimap()
	local vsx, vsy = spGetViewGeometry()

	local aspect = Game.mapSizeZ / Game.mapSizeX
	local h = round(vsy * MINIMAP_HEIGHT_RATIO)
	local w = round(h / aspect)

	local x = PADDING
	local y = PADDING

	spSendCommands("minimap geo " .. x .. " " .. y .. " " .. w .. " " .. h)
	spSendCommands("minimap border 0")
end

function widget:Initialize()
	SetMinimap()
end

function widget:ViewResize()
	SetMinimap()
end

function widget:Update()
	self._frames = (self._frames or 0) + 1
	if self._frames <= 30 then
		SetMinimap()
	else
		widgetHandler:RemoveCallIn("Update")
	end
end

function widget:DrawScreen()
	local x, y, w, h = spGetMiniMapGeometry()
	if not x or not y or not w or not h then
		return
	end

	local ox1 = x - COVER_PAD
	local oy1 = y - COVER_PAD
	local ox2 = x + w + COVER_PAD
	local oy2 = y + h + COVER_PAD

	-- outer dark cover strips
	gl.Color(0.02, 0.02, 0.02, 0.95)
	gl.Rect(ox1, oy1, ox2, y)       -- top strip
	gl.Rect(ox1, y + h, ox2, oy2)   -- bottom strip
	gl.Rect(ox1, y, x, y + h)       -- left strip
	gl.Rect(x + w, y, ox2, y + h)   -- right strip

	-- border on top of the cover strips
	gl.Color(0, 0, 0, 0.90)
	gl.Rect(ox1, oy1, ox2, oy1 + BORDER_SIZE)               -- top
	gl.Rect(ox1, oy2 - BORDER_SIZE, ox2, oy2)               -- bottom
	gl.Rect(ox1, oy1, ox1 + BORDER_SIZE, oy2)               -- left
	gl.Rect(ox2 - BORDER_SIZE, oy1, ox2, oy2)               -- right

	gl.Color(1, 1, 1, 1)
end