function widget:GetInfo()
	return {
		name      = "Geovent Spot Loader",
		desc      = "Loads custom geovent positions from GameRulesParams into WG for widget use",
		author    = "",
		date      = "2025",
		license   = "GPLv2 or later",
		layer     = 0,
		enabled   = true,
	}
end

local GetGameRulesParam = Spring.GetGameRulesParam
local GetGroundHeight   = Spring.GetGroundHeight

function widget:Initialize()
	local geoSpots = {}
	local count = GetGameRulesParam("customGeovent_count") or 0

	for i = 1, count do
		local x = GetGameRulesParam("customGeovent_" .. i .. "_x")
		local z = GetGameRulesParam("customGeovent_" .. i .. "_z")
		if x and z then
			local y = GetGroundHeight(x, z)
			table.insert(geoSpots, {x = x, y = y, z = z})
		end
	end

	WG.customGeoventSpots = geoSpots
	Spring.Echo("[GeoventSpotLoader] Loaded " .. #geoSpots .. " custom geovent spots into WG.customGeoventSpots")
end

function widget:Shutdown()
	WG.customGeoventSpots = nil
end