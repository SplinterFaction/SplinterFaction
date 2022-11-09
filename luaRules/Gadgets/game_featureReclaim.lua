function gadget:GetInfo()
  return {
    name      = "Feature Reclaimed Sound/CEG",
    desc      = "Play a sound and CEG when a feature is reclaimed",
    author    = "Tobi and Nemo, based on a bit by lurker, Reformed by Forboding Angel",
    date      = "December, 2008",
    license   = "public domain",
    layer     = 0,
    enabled   = false  --  loaded by default?
  }
end

if gadgetHandler:IsSyncedCode() then
-- SYNCED

	-- The code below mimics Spring's internal reclaiming code

	local reclaimLeft = {}
	local SpawnCEG = Spring.SpawnCEG
	local GetFeaturePosition = Spring.GetFeaturePosition	

	function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, part)
		reclaimLeft[featureID] = (reclaimLeft[featureID] or 0.1) + part
		if (reclaimLeft[featureID] <= 0) then
			Spring.DestroyFeature(featureID)
			--Spring.AddTeamResource(builderTeam, "e", 1)
			local fx, fy, fz = GetFeaturePosition(featureID)
			Spring.PlaySoundFile("sounds/miscfx/reclaimed.wav", 0.5, fx, fy, fz)
			SpawnCEG("sparklegreen", fx, fy, fz)
		end
		return false
	end

	function gadget:FeatureDestroyed(featureID, allyTeam)
		reclaimLeft[featureID] = nil
	end
end