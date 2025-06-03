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

if not gadgetHandler:IsSyncedCode() then return end

local CMD_ATTACK = CMD.ATTACK
local CMD_STOP = CMD.STOP

-- unitID -> targetID
local explicitTargets = {}


local function pushToArray(tablein, index, value)
	tablein[index] = tablein[index] or {}
	table.insert(tablein[index], value)
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	if cmdID == CMD_ATTACK and #cmdParams == 1 then
		local targetID = cmdParams[1]
		pushToArray(explicitTargets, unitID, targetID)
		--Spring.Echo("[Explicit Attack Only] We have a new Explicit target! ", targetID)
	elseif cmdID ~= CMD_ATTACK then
		explicitTargets[unitID] = nil
		--Spring.Echo("[Explicit Attack Only] Target has been cleared! ", explicitTargets[unitID])
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
	local targets = explicitTargets[unitID]

	if targets then
		--Spring.Echo("[Explicit Attack Only] Explicit Target is set! ", targets)
		return arrayContains(targets, targetID)
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
	for weaponDefID,wDef in pairs(WeaponDefs) do
		if wDef.customParams.nonexplicittargeting == "true" then
			--Don't Bother watching this weapon
		else
			Script.SetWatchAllowTarget(weaponDefID, true)
		end
	end
end

--[[
Attack Only Assigned Targets
============================

Overview:
---------
This gadget enforces strict fire discipline by disabling auto-targeting behavior
for units. Units affected by this gadget will **only fire on targets that were
explicitly ordered via a CMD.ATTACK command**. They will ignore any nearby enemies
unless those targets match the command history.

Purpose:
--------
- Improves tactical control during combat by preventing units from being distracted.
- Ideal for micro-intensive scenarios where maintaining focus on a specific enemy is important.
- Supports use cases where unit behavior must be deterministic or scripted.

How It Works:
-------------
1. When a unit receives a CMD.ATTACK with a unitID as its target, that target is
   stored in a per-unit table called `explicitTargets`.

2. While a unit has one or more explicit targets stored, the engine will call
   `AllowWeaponTarget` every time the unit tries to fire at something.

3. The `AllowWeaponTarget` function checks:
   - If the targetID matches one of the explicitly commanded targets for that unit.
   - If it matches, the shot is allowed.
   - If not, the target is rejected and the unit will not fire.

4. Once the command completes (via UnitCmdDone) or is interrupted (by a non-attack
   command), the explicit target list is cleared, restoring default behavior.

5. During gadget initialization, the gadget enables `AllowWeaponTarget` monitoring
   on all weaponDefs **except those explicitly excluded** using the
   `customParams.nonexplicittargeting` tag in weaponDefs.

Key Features:
-------------
- Uses `Script.SetWatchAllowTarget()` during `gadget:Initialize()` to register
  all relevant weapons for targeting logic.
- Cleans up stored state when units are destroyed or their attack command completes.
- Supports multiple simultaneous targets per unit (e.g., if using queued commands).

Customization:
--------------
You can add `customParams = { nonexplicittargeting = "true" }` to any weaponDef
to exempt it from this logic (e.g., for defensive weapons, AA, etc).

--]]
