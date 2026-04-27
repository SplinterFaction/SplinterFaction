function gadget:GetInfo()
	return {
		name    = "Disable AI Resource Sharing",
		desc    = "Forces all AI teams to share level 0",
		author  = "SF",
		version = "1.0",
		layer   = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then return end

function gadget:GameStart()
	for _, teamID in ipairs(Spring.GetTeamList()) do
		local luaAI = Spring.GetTeamRulesParam(teamID, "LuaAI")
		local _, _, _, isAI = Spring.GetTeamInfo(teamID)
		if isAI then
			Spring.SetShareLevel(teamID, 1, 1)  -- metal share, energy share both 0
		end
	end
end