function gadget:GetInfo()
	return {
		name = "Chicken Nuke Spawner",
		desc = "Spawns a capturable nuke facility in the center of the map",
		author = "",
		date = "",
		license = "",
		layer = 0,
		enabled = true
	}
end

if Spring.Utilities.Gametype.IsChickens() then

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	if gadgetHandler:IsSyncedCode() then
		-- SYNCED CODE
		--------------------------------------------------------------------------------
		--------------------------------------------------------------------------------
		local nearbyCaptureLibrary = VFS.Include("luarules/utilities/damgam_lib/nearby_capture.lua")
		local MAP_SIZE_X = Game.mapSizeX
		local MAP_SIZE_Z = Game.mapSizeZ
		local MAP_CENTER_X = Game.mapSizeX * 0.5
		local MAP_CENTER_Z = Game.mapSizeZ * 0.5

		local teams = Spring.GetTeamList()
		for _, teamID in ipairs(teams) do
			local teamLuaAI = Spring.GetTeamLuaAI(teamID)
			if (teamLuaAI and string.find(teamLuaAI, "Chickens")) then
				chickenTeamID = teamID
				chickenAllyTeamID = select(6, Spring.GetTeamInfo(chickenTeamID))
				break
			end
		end

		function gadget:GameFrame(frame)
			if frame == 30 then
				nukeFacilityID = Spring.CreateUnit("nukesilo", MAP_CENTER_X, 0, MAP_CENTER_Z, 0, chickenTeamID)
				Spring.SetUnitNeutral(nukeFacilityID, true)
				Spring.SetUnitAlwaysVisible(nukeFacilityID,true)
			end
			if frame%30 == 16 and nukeFacilityID then
				nearbyCaptureLibrary.NearbyCapture(nukeFacilityID, 16, 256)
			end
		end

		function gadget:UnitDestroyed(unitID)
			if unitID == nukeFacilityID then
				nukeFacilityID = nil
			end
		end
	end

end