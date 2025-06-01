function gadget:GetInfo()
	return {
		name      = "Single Builder Construction Restriction",
		desc      = "Enforces one-builder-per-nanoframe. Reimplementation of canbeassisted = false ",
		author    = "",
		date      = "2025-05-31",
		license   = "GPL-v2 or later",
		layer     = 0,
		enabled   = true,
	}
end

if not gadgetHandler:IsSyncedCode() then return end

local CMD_STOP   = CMD.STOP
local CMD_REPAIR = CMD.REPAIR
local CMD_GUARD  = CMD.GUARD
local CMD_PATROL = CMD.PATROL
local CMD_FIGHT  = CMD.FIGHT

-- nanoframeID -> builderID
local activeBuilders = {}

-- builderID -> true
local trackedBuilders = {}

local function IsUnderConstruction(unitID)
	local _, _, _, _, buildProgress = Spring.GetUnitHealth(unitID)
	return buildProgress and buildProgress < 1
end

function gadget:UnitCreated(unitID, unitDefID, teamID, builderID)
	local def = UnitDefs[unitDefID]
	if def and def.isBuilder then
		trackedBuilders[unitID] = true
	end
end

function gadget:UnitDestroyed(unitID)
	trackedBuilders[unitID] = nil
	for frameID, builderID in pairs(activeBuilders) do
		if unitID == frameID or unitID == builderID then
			activeBuilders[frameID] = nil
		end
	end
end

function gadget:UnitFinished(unitID)
	activeBuilders[unitID] = nil
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams)
	if (cmdID == CMD_REPAIR or cmdID == CMD_GUARD or cmdID == CMD_PATROL or cmdID == CMD_FIGHT) and cmdParams and #cmdParams >= 1 then
		local targetID = cmdParams[1]
		if targetID and IsUnderConstruction(targetID) then
			local assigned = activeBuilders[targetID]
			if assigned and assigned ~= unitID then
				--Spring.Echo("[Single Builder Construction Restriction] BLOCKED CMD: Builder", unitID, "attempted to command nanoframe", targetID, "already assigned to", assigned)
				return false
			end
		end
	end
	if cmdID == CMD_REPAIR and cmdParams then
		if #cmdParams == 4 then
			-- This is an area repair command
			--Spring.Echo("[Single Builder Construction Restriction] BLOCKED: Area repair from builder", unitID, "-> area x/z/r", cmdParams[1], cmdParams[3], cmdParams[4])
			return false
		end
	end
	return true
end

function gadget:GameFrame(f)
	--if f % 3 ~= 0 then return end

	-- Step 1: Clear assignments if builder has stopped building
	for nanoID, builderID in pairs(activeBuilders) do
		if not Spring.ValidUnitID(builderID) or Spring.GetUnitIsDead(builderID) then
			--Spring.Echo("[Single Builder Construction Restriction] Builder", builderID, "is gone — releasing nanoframe", nanoID)
			activeBuilders[nanoID] = nil
		else
			local currentBuildTarget = Spring.GetUnitIsBuilding(builderID)
			if currentBuildTarget ~= nanoID then
				--Spring.Echo("[Single Builder Construction Restriction] Builder", builderID, "is no longer building", nanoID, "— releasing")
				activeBuilders[nanoID] = nil
			end
		end
	end

	-- Step 2: Assign builders currently building unassigned nanoframes
	for builderID in pairs(trackedBuilders) do
		if Spring.ValidUnitID(builderID) and not Spring.GetUnitIsDead(builderID) then
			local targetID = Spring.GetUnitIsBuilding(builderID)
			if targetID and IsUnderConstruction(targetID) then
				local currentBuilder = activeBuilders[targetID]
				if not currentBuilder then
					activeBuilders[targetID] = builderID
					--Spring.Echo("[Single Builder Construction Restriction] Builder", builderID, "has taken over nanoframe", targetID)
				elseif currentBuilder ~= builderID then
					--Spring.Echo("[Single Builder Construction Restriction] FORCING STOP: Builder", builderID, "attempted to build", targetID, "assigned to", currentBuilder)
					Spring.GiveOrderToUnit(builderID, CMD_STOP, {}, {})
				end
			end
		end
	end
end

--[[
🧭 Purpose
This gadget enforces a "one builder per nanoframe" rule — a custom reimplementation of the canbeassisted = false behavior, which is broken or unreliable in the engine.

⚙️ Core Behavior
✅ 1. Only one builder can work on a nanoframe at a time
    When a builder starts constructing a nanoframe, they are registered as the active builder for that frame.
    If another builder tries to assist (via repair/guard/patrol/fight), the command is blocked.

✅ 2. Builder assignments are released when they stop building
    If the assigned builder finishes, dies, or stops building that nanoframe (e.g., due to new orders or being idle), the nanoframe is freed up for another builder to take over.

✅ 3. New builders can take over unclaimed frames
    If a builder finds an unassigned nanoframe and begins constructing it, they automatically become the new assigned builder.

✅ 4. Area repair commands are completely blocked
    Any area repair command (i.e. drag-circle repair with {x, y, z, radius}) is denied to prevent bypassing the one-builder limit.

🚫 What It Blocks
    Assisting an in-progress nanoframe already claimed by another builder
    Area repair orders, regardless of whether they would touch claimed nanoframes or not

💡 Implementation Details
    activeBuilders[frameID] = builderID keeps track of who’s building what.
    AllowCommand blocks invalid assist commands before units move.

    GameFrame regularly:
        Clears assignments if builders walk away or die.
        Assigns builders to new unclaimed frames.
        Issues CMD_STOP to builders trying to override an assignment.
--]]