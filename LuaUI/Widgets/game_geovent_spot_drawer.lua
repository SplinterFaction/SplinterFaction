function widget:GetInfo()
	return {
		name    = "Geovent Spot Drawer",
		desc    = "Draws an image at each geovent spot from WG.customGeoventSpots",
		author  = "",
		date    = "2025-06-10",
		license = "GPLv2",
		layer   = 0,
		enabled = true,
	}
end

local imageFile = "bitmaps/default/geovent4.png"
local imageSize = 15

function widget:DrawWorldPreUnit()
	if not WG.customGeoventSpots then return end

	gl.Texture(imageFile)
	gl.Color(1, 1, 1, 1)

	local offsetX = 0
	local offsetY = 1
	local offsetZ = 0

	for _, spot in ipairs(WG.customGeoventSpots) do
		local x, z = spot.x, spot.z
		local y = Spring.GetGroundHeight(x, z)

		gl.PushMatrix()
		gl.Translate(x + offsetX, y + offsetY, z + offsetZ)
		gl.BeginEnd(GL.QUADS, function()
			gl.TexCoord(0, 0); gl.Vertex(-imageSize, 0, -imageSize)
			gl.TexCoord(1, 0); gl.Vertex( imageSize, 0, -imageSize)
			gl.TexCoord(1, 1); gl.Vertex( imageSize, 0,  imageSize)
			gl.TexCoord(0, 1); gl.Vertex(-imageSize, 0,  imageSize)
		end)
		gl.PopMatrix()
	end


	gl.Texture(false)
end
