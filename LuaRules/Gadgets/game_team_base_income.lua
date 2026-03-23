function gadget:GetInfo()
	return {
		name    = "Base Team Income",
		desc    = "Gives every team constant passive metal and energy income",
		author  = "",
		date    = "2026-03-22",
		license = "GPLv2",
		layer   = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local GetTeamList        = Spring.GetTeamList
local SetTeamRulesParam  = Spring.SetTeamRulesParam
local AddTeamResource    = Spring.AddTeamResource

local METAL_INCOME  = 6
local ENERGY_INCOME = 25

function gadget:GameFrame(frame)
	-- Add per-second income every 30 frames
	if frame % 30 ~= 0 then
		return
	end

	local teams = GetTeamList()
	for i = 1, #teams do
		local teamID = teams[i]
		AddTeamResource(teamID, "m", METAL_INCOME)
		AddTeamResource(teamID, "e", ENERGY_INCOME)
	end
end