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

-- NOTE: Texture must be part of the decal atlas (e.g., used in unitdefs or sfx)
local decalTexture = "mexspots1"
local decalSize = 85

local decalIDs = {}

function widget:Initialize()
	if not WG.metalMakerSpots then return end

	for _, spot in ipairs(WG.metalMakerSpots) do
		local x, z = spot.x, spot.z

		local decalID = Spring.CreateGroundDecal()
		if decalID then
			Spring.SetGroundDecalPosAndDims(decalID, x, z, decalSize, decalSize)
			Spring.SetGroundDecalTexture(decalID, decalTexture, true)
			Spring.SetGroundDecalAlpha(decalID, 1.0, 0.0)
			Spring.SetGroundDecalTint(decalID, 0.5, 0.5, 0.5, 0.5) -- neutral tint
			table.insert(decalIDs, decalID)
		end
	end
end

function widget:Shutdown()
	for _, id in ipairs(decalIDs) do
		Spring.DestroyGroundDecal(id)
	end
end
