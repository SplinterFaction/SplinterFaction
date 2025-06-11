function widget:GetInfo()
	return {
		name      = "Metal Maker Spot Drawer (Minimap)",
		desc      = "Draws green circles at all metal maker spots on the minimap",
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

local radius = 80  -- in world units
local circleDivs = 16  -- number of segments per circle
local metalSpots = nil

local function drawCircle(x, z)
	for i = 1, circleDivs do
		local angle = (2 * math.pi) * (i / circleDivs)
		local dx = math.cos(angle) * radius
		local dz = math.sin(angle) * radius
		glVertex(x + dx, 0, z + dz)
	end
end

function widget:Update()
	if not metalSpots and WG.metalMakerSpots then
		metalSpots = WG.metalMakerSpots
		Spring.Echo("[Minimap Metal Circles] Loaded " .. #metalSpots .. " metal spots.")
	end
end

function widget:DrawInMiniMap()
	if not metalSpots then return end

	glLoadIdentity()
	glTranslate(0, 1, 0)
	glScale(mapXinv, -mapZinv, 1)
	glRotate(270, 1, 0, 0)

	glLineWidth(2)
	glColor(0, 1, 0, 1)  -- green

	for i = 1, #metalSpots do
		local spot = metalSpots[i]
		glBeginEnd(GL_LINE_LOOP, drawCircle, spot.x, spot.z)
	end

	glLineWidth(1)
end
