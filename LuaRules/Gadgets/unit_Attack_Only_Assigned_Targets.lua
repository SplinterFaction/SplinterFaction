function gadget:GetInfo()
	return {
		name = "Attack Only Assigned Targets",
		desc = "Prevents units from engaging any targets except those given via explicit attack commands. Automatically disables auto-targeting behavior unless the target was assigned through a direct attack order. Useful for controlling unit focus and avoiding unwanted distractions in combat.",
		author = "",
		date = "2025",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- Attack Only Assigned Targets
--------------------------------------------------------------------------------
-- This gadget restricts unit behavior so that units will only fire at targets
-- they have been explicitly ordered to attack via the CMD.ATTACK command.
--
-- Units will:
--   - Only engage a specific enemy unit or ground position if it was the target
--     of a direct attack order.
--   - Ignore all other nearby enemies, including those in range.
--   - Stop attacking entirely once the assigned target is destroyed or the order
--     is canceled.
--
-- How it works:
--   - When a unit receives a CMD.ATTACK, its target (unit or ground position)
--     is stored in a table.
--   - While a target is stored, AllowWeaponTarget will block firing at any other
--     unit or position.
--   - If the unit is issued a different command (e.g., move, stop, patrol), the
--     target is cleared and normal targeting behavior resumes.
--   - If the assigned target is destroyed, the gadget will detect this and clear
--     the target so the unit can return to normal behavior.
--
-- This is useful for:
--   - Precise micro control in combat
--   - Preventing distractions or auto-targeting during coordinated attacks
--   - Forcing units to prioritize specific enemies or objectives
--
-- Weapons can be excluded from this behavior by setting:
--   customParams = { nonexplicittargeting = "true" }
-- in the weapon definition.
--------------------------------------------------------------------------------


if not gadgetHandler:IsSyncedCode() then return end

local CMD_ATTACK = CMD.ATTACK
local CMD_STOP = CMD.STOP
local CMD_MOVE = CMD.MOVE

-- unitID -> { type = "unit"|"ground", target = unitID or {x, z} }
local explicitTargets = {}


local function pushToArray(tablein, index, value)
	tablein[index] = tablein[index] or {}
	table.insert(tablein[index], value)
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	if cmdID == CMD_ATTACK then
		if #cmdParams == 1 then
			-- Attack a unit or feature
			explicitTargets[unitID] = { type = "unit", target = cmdParams[1] }
		elseif #cmdParams >= 3 then
			-- Attack ground location
			local x, z = cmdParams[1], cmdParams[3]
			explicitTargets[unitID] = { type = "ground", target = {x = x, z = z} }
		end
	elseif cmdID ~= CMD_ATTACK then
		explicitTargets[unitID] = nil
	end
	return true
end


local function arrayContains(array, value)
	for _,val in ipairs(array) do
		if val == value then return true end
	end
	return false
end

function gadget:AllowWeaponTarget(unitID, targetID, weaponNum, attackerID, attackerDefID, weaponDefID, defaultPriority)
	local targetInfo = explicitTargets[unitID]

	if targetInfo then
		--Spring.Echo("[ExplicitTarget] Unit", unitID, "still has explicit target:", targetInfo.type, targetInfo.target)
	else
		--Spring.Echo("[ExplicitTarget] Unit", unitID, "has no explicit target.")
	end

	-- existing logic...
	if not targetInfo then return true end

	if targetInfo.type == "unit" then
		return targetID == targetInfo.target
	end

	return false
end


-- Spring Cleaning
function gadget:UnitDestroyed(unitID, unitDefID, teamID)
	-- Clean up units that had explicit targets assigned to them
	explicitTargets[unitID] = nil

	-- Check if this destroyed unit was a target of any unit
	for ownerID, target in pairs(explicitTargets) do
		if target.type == "unit" and target.target == unitID then
			--Spring.Echo("[ExplicitTarget] Clearing dead target from unit", ownerID)
			explicitTargets[ownerID] = nil
		end
	end
end


--function gadget:UnitCmdDone(unitID, cmdID)
--	if cmdID == CMD_ATTACK then
--		local was = explicitTargets[unitID]
--		explicitTargets[unitID] = nil
--
--		Spring.Echo("[ExplicitTarget] CMD_ATTACK complete for unit", unitID, ". Previous target was:", was and was.type or "none")
--
--		if was and was.type == "ground" then
--			local x, _, z = Spring.GetUnitPosition(unitID)
--			if x and z then
--				Spring.GiveOrderToUnit(unitID, CMD.MOVE, {x, z, 0}, {"shift"})
--			end
--		end
--	end
--end


function gadget:Initialize()
	for weaponDefID,wDef in pairs(WeaponDefs) do
		if wDef.customParams.nonexplicittargeting == "true" then
			--Don't Bother watching this weapon
		else
			Script.SetWatchAllowTarget(weaponDefID, true)
		end
	end
end