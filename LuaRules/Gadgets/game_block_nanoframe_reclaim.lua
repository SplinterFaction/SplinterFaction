function gadget:GetInfo()
	return {
		name      = "Nanoframe Reclaim Blocker",
		desc      = "Blocks reclaim of nanoframes owned by other teams",
		author    = "",
		date      = "2025-05-26",
		license   = "",
		layer     = 0,
		enabled   = true,
	}
end

if not gadgetHandler:IsSyncedCode() then return end

local CMD_RECLAIM = CMD.RECLAIM
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitDefID = Spring.GetUnitDefID
local spValidUnitID = Spring.ValidUnitID

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	if cmdID ~= CMD_RECLAIM then return true end

	local targetID = cmdParams[1]
	if not spValidUnitID(targetID) then return true end

	local targetDefID = spGetUnitDefID(targetID)
	if not targetDefID then return true end

	local _, _, _, buildProgress = spGetUnitHealth(targetID)
	if buildProgress and buildProgress < 1 then
		local targetTeam = spGetUnitTeam(targetID)
		if targetTeam ~= teamID then
			return false -- block reclaim of someone else's nanoframe
		end
	end

	return true
end
