function widget:GetInfo()
	return {
		name      = "Geovent Spot Drawer (Minimap)",
		desc      = "Draws yellow circles at all geovent spots on the minimap",
		author    = "",
		date      = "2025-06-10",
		license   = "GPLv2",
		layer     = 0,
		enabled   = true,
	}
end

local glColor      = gl.Color
local glVertex     = gl.Vertex
local glBeginEnd   = gl.BeginEnd
local glLineWidth  = gl.LineWidth
local glLoadIdentity = gl.LoadIdentity
local glTranslate  = gl.Translate
local glScale      = gl.Scale
local glRotate     = gl.Rotate
local GL_LINE_LOOP = GL.LINE_LOOP

local mapX = Game.mapSizeX
local mapZ = Game.mapSizeZ
local mapXinv = 1 / mapX
local mapZinv = 1 / mapZ

local radius = 200  -- in world units
local geoSpots = nil

local function drawX(x, z, size)
	local halfSize = size * 0.5

	-- Line from top-left to bottom-right
	glVertex(x - halfSize, 0, z - halfSize)
	glVertex(x + halfSize, 0, z + halfSize)

	-- Line from top-right to bottom-left
	glVertex(x - halfSize, 0, z + halfSize)
	glVertex(x + halfSize, 0, z - halfSize)
end


function widget:Update()
	if not geoSpots and WG.customGeoventSpots then
		geoSpots = WG.customGeoventSpots
		Spring.Echo("[Minimap Metal Circles] Loaded " .. #geoSpots .. " metal spots.")
	end
end

function widget:DrawInMiniMap()
	if not geoSpots then return end

	glLoadIdentity()
	glTranslate(0, 1, 0)
	glScale(mapXinv, -mapZinv, 1)
	glRotate(270, 1, 0, 0)

	glLineWidth(2)
	glColor(1, 1, 0, 1)  -- green

	for i = 1, #geoSpots do
		local spot = geoSpots[i]
		gl.BeginEnd(GL.LINES, function()
			drawX(spot.x, spot.z, radius) -- draws an X centered at (200, 200) with a size of 20
		end)

	end

	glLineWidth(1)
end
