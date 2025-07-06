function widget:GetInfo()
	return {
		name    = "Geovent Spot Drawer",
		desc    = "Places an engine decal at each geovent spot from WG.customGeoventSpots",
		author  = "",
		date    = "2025-06-10",
		license = "GPLv2",
		layer   = 0,
		enabled = true,
	}
end

-- Texture must already be part of the engine decal atlas
local decalTexture = "maindecal_3"
local decalTextureNormal = "normdecal_3"
local decalSize = 15

-- Optional offsets (for alignment tweak)
local offsetX = 0
local offsetZ = 0

local decalIDs = {}

function widget:Initialize()
	if not WG.customGeoventSpots then return end

	for _, spot in ipairs(WG.customGeoventSpots) do
		local x, z = spot.x + offsetX, spot.z + offsetZ

		local decalID = Spring.CreateGroundDecal()
		if decalID then
			Spring.SetGroundDecalPosAndDims(decalID, x, z, decalSize, decalSize)

			--Random Rotation
			--local angle = math.random() * 2 * math.pi
			--Spring.SetGroundDecalRotation(decalID, angle)

			Spring.SetGroundDecalTexture(decalID, decalTexture, true)
			Spring.SetGroundDecalTexture(decalID, decalTextureNormal, false)
			Spring.SetGroundDecalAlpha(decalID, 1.0, 0.0)
			Spring.SetGroundDecalTint(decalID, 0.5, 0.5, 0.5, 0.5) -- no tint
			table.insert(decalIDs, decalID)
		end
	end
end

function widget:Shutdown()
	for _, id in ipairs(decalIDs) do
		Spring.DestroyGroundDecal(id)
	end
end
