function gadget:GetInfo()
	return {
		name      = 'Metal Feature Placer',
		desc      = 'Places a Metal Spot Feature on every mex spot',
		author    = '',
		version   = '',
		date      = '',
		license   = '',
		layer     = 0,
		enabled   = true
	}
end

----------------------------------------------------------------
-- Synced only
----------------------------------------------------------------
if gadgetHandler:IsSyncedCode() then

	function gadget:Initialize()
		local metalSpots = GG.metalSpots
		for i = 1,#metalSpots do
			local spot = metalSpots[i]
			local x = spot.x
			local y = spot.y
			local z = spot.z
			Spring.CreateFeature("metal",x,y,z)
		end
	end
end