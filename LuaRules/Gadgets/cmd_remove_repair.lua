if not gadgetHandler:IsSyncedCode() then
	return
end

function gadget:GetInfo()
  return {
	name 	= "Remove Repair",
	desc	= "Removes the repair command from units with the customparam removerepair true.",
	author	= "GoogleFrog",
	date	= "3 April 2015",
	license	= "GNU GPL, v2 or later",
	layer	= 0,
	enabled = true,
  }
end

local spRemoveUnitCmdDesc = Spring.RemoveUnitCmdDesc
local spFindUnitCmdDesc   = Spring.FindUnitCmdDesc
local CMD_REPAIR = CMD.REPAIR

local removeCommands = {
	CMD.REPAIR,
}

local repairRemoveDefs = {}

for unitDefID = 1, #UnitDefs do
	local ud = UnitDefs[unitDefID]
	if ud.customParams and ud.customParams.removerepair == "true" then
		repairRemoveDefs[unitDefID] = true
	end
end

function gadget:AllowCommand_GetWantedCommand()
	return {[CMD_REPAIR] = true}
end

function gadget:AllowCommand_GetWantedUnitDefID()	
	return repairRemoveDefs
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	if (cmdID == CMD_REPAIR and repairRemoveDefs[unitDefID]) then
		return false
	end
	return true
end

function gadget:UnitCreated(unitID, unitDefID)
	if repairRemoveDefs[unitDefID] then
		for i = 1, #removeCommands do
			local cmdDesc = spFindUnitCmdDesc(unitID, removeCommands[i])
			if cmdDesc then
				spRemoveUnitCmdDesc(unitID, cmdDesc)
			end
		end
	end
end

function gadget:Initialize()
	-- load active units
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		gadget:UnitCreated(unitID, unitDefID)
	end
end