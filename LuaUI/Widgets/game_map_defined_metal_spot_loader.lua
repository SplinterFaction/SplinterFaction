function widget:GetInfo()
	return {
		name    = "Map Defined Metal Spots Loader",
		desc    = "Loads map metal spots from modRulesParams into WG.mapmetalspots",
		author  = "",
		date    = "2025-07-06",
		license = "GPLv2",
		layer   = 0,
		enabled = true,
	}
end

function widget:Initialize()
	local count = Spring.GetGameRulesParam("mapmetalspots_count")
	if not count then
		Spring.Echo("[MapMetalSpotsLoader] No metal spots found in modRulesParams.")
		return
	end

	WG.mapmetalspots = {}

	for i = 1, count do
		local x     = Spring.GetGameRulesParam("mapmetalspots_" .. i .. "_x")
		local z     = Spring.GetGameRulesParam("mapmetalspots_" .. i .. "_z")
		local metal = Spring.GetGameRulesParam("mapmetalspots_" .. i .. "_metal")
		if x and z and metal then
			table.insert(WG.mapmetalspots, { x = x, z = z, metal = metal })
		end
	end

	Spring.Echo("[MapMetalSpotsLoader] Loaded " .. #WG.mapmetalspots .. " metal spots into WG.")
end
