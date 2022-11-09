function gadget:GetInfo()
    return {
        name = "Set Map Feature Reclaimtime and NonBlocking",
        desc = "Resets reclaimtime of all map features based upon their value. Also sets map features to be nonblocking.",
        author = "Sprung",
        date = "2022",
        license = "GPL",
        layer = 1,
        enabled = true
    }
end

if (gadgetHandler:IsSyncedCode()) then
    ---synced----
    if (gadgetHandler:IsSyncedCode()) then
        function gadget:GameFrame(f) -- GamePreload would've likely been fine and not have incorrect values in the startpoint phase, but w/e, since it's just reclaim time and not resources
            if f ~= 30 then
                return
            end
            local features = Spring.GetAllFeatures ()
            for i = 1, #features do
                local featureID = features[i]
                local featureDefID = Spring.GetFeatureDefID(featureID)

                local metalAsModifiedBySpringboard, metalInTheDef, energyAsModifiedBySpringboard, energyInTheDef = Spring.GetFeatureResources(featureID)
                local reclaimTime = metalAsModifiedBySpringboard * 0.2 + energyAsModifiedBySpringboard * 0.25
                Spring.SetFeatureResources(featureID, metalAsModifiedBySpringboard, energyAsModifiedBySpringboard, reclaimTime)
                Spring.SetFeatureBlocking(featureID, false)
            end
            gadgetHandler:RemoveGadget()
        end
    end
end