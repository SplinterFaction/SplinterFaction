function gadget:GetInfo()
	return {
		name    = "Unit Sharing Preserve Orders",
		desc    = "Re-issues command queues on units transferred via the Static Share Menu widget if the shared unit comes from an ally.",
		author  = "",
		date    = "2026-05-09",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- Only runs server-side
--------------------------------------------------------------------------------

if not gadgetHandler:IsSyncedCode() then return end

--------------------------------------------------------------------------------
-- Speedups
--------------------------------------------------------------------------------

local spGiveOrderToUnit  = Spring.GiveOrderToUnit
local spGetUnitTeam      = Spring.GetUnitTeam

--------------------------------------------------------------------------------
-- Pending queue
-- Populated by the widget via Spring.SetUnitRulesParam / SendLuaUIMsg bridge.
-- Format: pendingOrders[unitID] = { teamID=N, cmds={ {id,params,options}, ... } }
--
-- Because synced gadgets can't read WG directly, the widget sends a LuaUI
-- message that we receive here via RecvLuaMsg, then store locally.
--------------------------------------------------------------------------------

local pendingOrders = {}   -- unitID (number) -> {teamID, cmds}

--------------------------------------------------------------------------------
-- Message protocol
--
-- The widget sends a string via Spring.SendMessageToTeam / LuaUI channel:
--   "ShareOrders:<unitID>:<teamID>:<cmd1_id>:<cmd1_params_json>:<cmd1_opts>|<cmd2_...>|..."
--
-- We use a simple pipe-delimited flat format to avoid JSON dependency:
--   Each command token:  id,p1,p2,...,pN,OPTS:optBits
--   Fields within a command are comma-separated; OPTS: prefix marks the option bits.
--
-- Example for a Move + Attack command:
--   "ShareOrders:42:3:105,1000,0,2000,OPTS:0|20,99,OPTS:0"
--------------------------------------------------------------------------------

local MSG_PREFIX = "ShareOrders:"

local function ParseOrders(msg)
	-- strip prefix
	local body = msg:sub(#MSG_PREFIX + 1)

	-- split: unitID : teamID : cmd_tokens
	local unitID, teamID, cmdBlock = body:match("^(%d+):(%d+):(.*)$")
	if not unitID then return nil end

	unitID = tonumber(unitID)
	teamID = tonumber(teamID)

	local cmds = {}
	if cmdBlock and cmdBlock ~= "" then
		for token in cmdBlock:gmatch("[^|]+") do
			-- split token on commas
			local fields = {}
			for f in token:gmatch("[^,]+") do
				fields[#fields + 1] = f
			end

			-- last field is OPTS:<bits>
			local optBits = 0
			if #fields > 0 and fields[#fields]:sub(1, 5) == "OPTS:" then
				optBits = tonumber(fields[#fields]:sub(6)) or 0
				fields[#fields] = nil
			end

			local cmdID = tonumber(fields[1])
			if cmdID then
				local params = {}
				for k = 2, #fields do
					params[#params + 1] = tonumber(fields[k]) or 0
				end
				cmds[#cmds + 1] = {id = cmdID, params = params, options = optBits}
			end
		end
	end

	return unitID, teamID, cmds
end

--------------------------------------------------------------------------------
-- Gadget callins
--------------------------------------------------------------------------------

function gadget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, #MSG_PREFIX) ~= MSG_PREFIX then return end

	local unitID, teamID, cmds = ParseOrders(msg)
	if not unitID then return end

	-- Store for when UnitGiven fires
	pendingOrders[unitID] = {teamID = teamID, cmds = cmds}
end

function gadget:UnitGiven(unitID, unitDefID, newTeamID, oldTeamID)
	local pending = pendingOrders[unitID]
	if not pending then return end

	pendingOrders[unitID] = nil

	-- Only re-issue orders if the old and new teams are allied.
	-- This prevents shenanigans where an enemy transfer could carry
	-- orders that cause problems for the receiving team.
	local oldAllyTeam = select(6, Spring.GetTeamInfo(oldTeamID, false))
	local newAllyTeam = select(6, Spring.GetTeamInfo(newTeamID, false))
	if oldAllyTeam ~= newAllyTeam then
		Spring.Echo(string.format(
				"[SharePreserveOrders] Skipping order re-issue: unit %d transferred between non-allied teams (%d -> %d)",
				unitID, oldTeamID, newTeamID))
		return
	end

	local cmds = pending.cmds
	if not cmds or #cmds == 0 then return end

	for i, cmd in ipairs(cmds) do
		local opts = cmd.options or 0
		if i > 1 then
			opts = bit.bor(opts, CMD.OPT_SHIFT)
		else
			opts = bit.band(opts, bit.bnot(CMD.OPT_SHIFT))
		end
		spGiveOrderToUnit(unitID, cmd.id, cmd.params, opts)
	end

	Spring.Echo(string.format(
			"[SharePreserveOrders] Re-issued %d order(s) to unit %d (team %d)",
			#cmds, unitID, newTeamID))
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID)
	-- Clean up if the unit dies before the transfer completes
	pendingOrders[unitID] = nil
end