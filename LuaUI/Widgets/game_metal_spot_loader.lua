function widget:GetInfo()
	return {
		name    = "Metal Spot Loader",
		desc    = "Loads metal maker spots from GameRulesParams into WG",
		author  = "",
		date    = "2025-06-10",
		license = "GPLv2",
		layer   = 0,
		enabled = true,
	}
end

local GetGameRulesParam = Spring.GetGameRulesParam
local GetGroundHeight   = Spring.GetGroundHeight

function widget:Initialize()
	local metalSpots = {}
	local count = GetGameRulesParam("metalSpot_count") or 0

	for i = 1, count do
		local x = GetGameRulesParam("metalSpot_" .. i .. "_x")
		local z = GetGameRulesParam("metalSpot_" .. i .. "_z")
		if x and z then
			local y = GetGroundHeight(x, z)
			table.insert(metalSpots, {x = x, y = y, z = z})
		end
	end

	WG.metalMakerSpots = metalSpots
	Spring.Echo("[MetalSpotLoader] Loaded " .. #metalSpots .. " metal maker spots into WG.metalMakerSpots")
end