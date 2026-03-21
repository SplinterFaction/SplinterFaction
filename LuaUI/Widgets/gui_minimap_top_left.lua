function widget:GetInfo()
	return {
		name    = "Minimap Top Left",
		desc    = "Places the default minimap in the top-left corner",
		author  = "",
		date    = "2026-03-20",
		license = "GPL v2 or later",
		layer   = 0,
		enabled = true,
	}
end

local spSendCommands = Spring.SendCommands
local spGetViewGeometry = Spring.GetViewGeometry

local MINIMAP_WIDTH = 275
local PADDING = 2

local function round(x)
	return math.floor(x + 0.5)
end

local function SetMinimap()
	local vsx, vsy = spGetViewGeometry()

	local aspect = Game.mapSizeX / Game.mapSizeZ
	local w = MINIMAP_WIDTH
	local h = round(w / aspect)

	local x = PADDING
	local y = PADDING   -- ✅ THIS is the fix

	spSendCommands("minimap geo " .. x .. " " .. y .. " " .. w .. " " .. h)
end

function widget:Initialize()
	SetMinimap()
end

function widget:ViewResize()
	SetMinimap()
end

function widget:Update()
	if not self._frames then self._frames = 0 end

	if self._frames < 30 then
		SetMinimap()
		self._frames = self._frames + 1
	else
		widgetHandler:RemoveCallIn("Update")
	end
end