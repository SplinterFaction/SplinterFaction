function gadget:GetInfo()
	return {
		name = "Explicit Attack Only",
		desc = "Units will only attack an explicit target",
		author = "",
		date = "2025",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then return end

local CMD_ATTACK = CMD.ATTACK

-- unitID -> targetID
local explicitTargets = {}

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	if cmdID == CMD_ATTACK and #cmdParams == 1 then
		local targetID = cmdParams[1]
		explicitTargets[unitID] = targetID
	elseif cmdID == CMD_STOP then
		explicitTargets[unitID] = nil
	end
	return true
end

function gadget:AllowWeaponTarget(unitID, targetID, weaponNum, attackerID, attackerDefID, weaponDefID, defaultPriority)
	local explicitTarget = explicitTargets[unitID]
	if explicitTarget then
		if targetID == explicitTarget then
			return true
		else
			return true -- block auto-targeting
		end
	end
	return true -- allow default targeting if no explicit target set
end

-- Spring Cleaning
function gadget:UnitDestroyed(unitID, unitDefID, teamID)
	explicitTargets[unitID] = nil
end

function gadget:UnitCmdDone(unitID, cmdID, cmdTag)
	if cmdID == CMD_ATTACK then
		explicitTargets[unitID] = nil
	end
end

function gadget:Initialize()
	for _, udef in pairs(UnitDefs) do
		if udef.weapons then
			for _, weapon in ipairs(udef.weapons) do
				local wDefID = weapon.weaponDef
				Script.SetWatchAllowTarget(wDefID, true)
			end
		end
	end
end