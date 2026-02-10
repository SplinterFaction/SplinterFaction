function widget:GetInfo()
	return {
		name    = "Map Defined Metal Spot Drawer",
		desc    = "Draws an engine decal at each map metal spot spot from WG.mapmetalspots",
		author  = "",
		date    = "2025-06-10",
		license = "GPLv2",
		layer   = 0,
		enabled = false,
	}
end

-- The purpose of this widget is to draw a decal over the built in metal map spots.

-- This is just debug code so that we can see what decals are in the index
-- for k,v in pairs(Spring.GetGroundDecalTextures()) do Spring.Echo("[Metal Spot Drawer] ",k,v) end
-- for k,v in pairs(Spring.GetGroundDecalTextures(nil,false)) do Spring.Echo("[Metal Spot Drawer] ",k,v) end

-- NOTE: Texture must be part of the decal atlas (e.g., used in unitdefs or sfx)
local decalTexture = "maindecal_3"
local decalTextureNormal = "normdecal_3"
local decalSize = 85

local decalIDs = {}

function widget:Initialize()
	if not WG.mapmetalspots then return end

	local offsetX = 42
	local offsetZ = 42

	for _, spot in ipairs(WG.mapmetalspots) do
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
