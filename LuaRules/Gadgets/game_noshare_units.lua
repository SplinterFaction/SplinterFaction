function gadget:GetInfo()
	return {
		name    = "No-Share Units",
		desc    = "Blocks sharing/giving specific unit types",
		author  = "",
		date    = "2026-02-08",
		license = "GPLv2",
		layer   = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

-- =========================================================
-- CONFIG
-- =========================================================

-- List units (by unitDef name) that cannot be shared/given.
-- Example names: "armcom", "corcom", "fedharbinger", etc.
local NO_SHARE_UNITNAMES = {
	-- "armcom",
	-- "corcom",
	"lozcommander",
	"lozcommander_up1",
	"lozcommander_up2",
	"lozcommander_up3",
	"lozcommander_up4",
	"fedcommander",
	"fedcommander_up1",
	"fedcommander_up2",
	"fedcommander_up3",
	"fedcommander_up4",
}

-- Optional: also treat unitDefs with customParams.no_share = 1 / "1" / true as non-shareable.
local USE_CUSTOMPARAM_FLAG = true
local CUSTOMPARAM_KEY = "no_share"

-- =========================================================
-- INTERNALS
-- =========================================================

local CMD_GIVE = CMD.GIVE

local noShareDefID = {} -- [unitDefID] = true

local function ToBoolish(v)
	if v == nil then return false end
	if v == true then return true end
	if v == false then return false end
	if type(v) == "number" then return v ~= 0 end
	if type(v) == "string" then
		v = v:lower()
		return (v == "1" or v == "true" or v == "yes" or v == "y" or v == "on")
	end
	return false
end

function gadget:Initialize()
	-- From explicit list
	for _, udName in ipairs(NO_SHARE_UNITNAMES) do
		local ud = UnitDefNames[udName]
		if ud and ud.id then
			noShareDefID[ud.id] = true
		else
			Spring.Echo(("[No-Share Units] Warning: unitDef '%s' not found"):format(tostring(udName)))
		end
	end

	-- From customParams flag
	if USE_CUSTOMPARAM_FLAG then
		for udid, ud in pairs(UnitDefs) do
			local cp = ud.customParams
			if cp and ToBoolish(cp[CUSTOMPARAM_KEY]) then
				noShareDefID[udid] = true
			end
		end
	end
end

local function IsNoShare(unitDefID)
	return noShareDefID[unitDefID] == true
end

-- =========================================================
-- BLOCK THE SHARE/GIVE COMMAND
-- =========================================================

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	if cmdID == CMD_GIVE and IsNoShare(unitDefID) then
		-- Optional: message the player who tried to share it
		if playerID and playerID >= 0 then
			Spring.SendMessageToPlayer(playerID, "This unit cannot be shared.")
		end
		return false
	end
	return true
end

-- =========================================================
-- EXTRA SAFETY: BLOCK ANY TRANSFER THAT ISN'T A CAPTURE
-- =========================================================
-- callin signature (most common):
-- AllowUnitTransfer(unitID, unitDefID, oldTeam, newTeam, capture)
-- capture=true for capture mechanics; capture=false for give/share transfers.
function gadget:AllowUnitTransfer(unitID, unitDefID, oldTeam, newTeam, capture)
	if IsNoShare(unitDefID) and not capture then
		return false
	end
	return true
end
