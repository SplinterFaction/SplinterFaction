if not gadgetHandler:IsSyncedCode() then
	return
end

function gadget:GetInfo()
  return {
	name 	= "Remove Attack",
	desc	= "Removes the attack command from units with the customparam removeattack true.",
	author	= "GoogleFrog",
	date	= "3 April 2015",
	license	= "GNU GPL, v2 or later",
	layer	= 0,
	enabled = true,
  }
end

local spRemoveUnitCmdDesc = Spring.RemoveUnitCmdDesc
local spFindUnitCmdDesc   = Spring.FindUnitCmdDesc
local CMD_ATTACK = CMD.ATTACK

local removeCommands = {
	CMD.ATTACK,
}

local attackRemoveDefs = {}

for unitDefID = 1, #UnitDefs do
	local ud = UnitDefs[unitDefID]
	if ud.customParams and ud.customParams.removeattack == "true" then
		attackRemoveDefs[unitDefID] = true
	end
end

function gadget:AllowCommand_GetWantedCommand()
	return {[CMD_ATTACK] = true}
end

function gadget:AllowCommand_GetWantedUnitDefID()	
	return attackRemoveDefs
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	if (cmdID == CMD_ATTACK and attackRemoveDefs[unitDefID]) then
		return false
	end
	return true
end

function gadget:UnitCreated(unitID, unitDefID)
	if attackRemoveDefs[unitDefID] then
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