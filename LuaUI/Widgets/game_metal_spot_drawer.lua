function widget:GetInfo()
	return {
		name    = "Metal Spot Drawer",
		desc    = "Draws an image at each metal maker spot from WG.metalMakerSpots",
		author  = "",
		date    = "2025-06-10",
		license = "GPLv2",
		layer   = 0,
		enabled = true,
	}
end

local imageFile = "bitmaps/default/mexspots1.dds"
local imageSize = 85

function widget:DrawWorldPreUnit()
	if not WG.metalMakerSpots then return end

	gl.Texture(imageFile)
	gl.Color(1, 1, 1, 1)

	local offsetX = 7
	local offsetY = 0
	local offsetZ = 7

	for _, spot in ipairs(WG.metalMakerSpots) do
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
