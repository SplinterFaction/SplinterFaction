function gadget:GetInfo()
	return {
		name      = 'Geokiller',
		desc      = 'Destroys map geovents so that we can place geothermal features manually with lua in random positions',
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
		local features = Spring.GetAllFeatures()
		for i = 1, #features do
			local fID = features[i]
			local fDefID = Spring.GetFeatureDefID(fID)
			local fDef = FeatureDefs[fDefID]

			if fDef.geoThermal and Spring.GetFeatureRulesParam(fID, "customGeovent") ~= 1 then
				Spring.DestroyFeature(fID)
			end
		end

	end

end