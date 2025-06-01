function widget:GetInfo()
	return {
		name = "Build Order Splitter",
		desc = "Splits queued build orders evenly across selected builders",
		author = "",
		date = "2025-06-01",
		license = "GPLv2",
		layer = 0,
		enabled = true
	}
end

local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitDefID = Spring.GetUnitDefID
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetModKeyState = Spring.GetModKeyState
local CMD_INSERT = CMD.INSERT
local CMD_BUILD = -1

local function isBuilder(unitID)
	local ud = UnitDefs[spGetUnitDefID(unitID) or -1]
	return ud and ud.isBuilder
end

local buildQueue = {}

function widget:CommandNotify(cmdID, cmdParams, cmdOpts)
	-- Only intercept build commands when multiple builders are selected
	if cmdID >= 0 or not cmdParams or #cmdParams < 3 then return false end
	if not cmdOpts.shift then return false end -- only split with shift held

	local selectedUnits = spGetSelectedUnits()
	if #selectedUnits < 2 then return false end

	-- Filter to only builders
	local builders = {}
	for _, unitID in ipairs(selectedUnits) do
		if isBuilder(unitID) then
			builders[#builders + 1] = unitID
		end
	end

	if #builders < 2 then return false end

	-- Save build command
	buildQueue[#buildQueue + 1] = { cmdID = cmdID, params = cmdParams, opts = cmdOpts }
	return true -- block the original command
end

function widget:Update()
	if #buildQueue == 0 then return end

	local selectedUnits = spGetSelectedUnits()
	local builders = {}
	for _, unitID in ipairs(selectedUnits) do
		if isBuilder(unitID) then
			builders[#builders + 1] = unitID
		end
	end

	if #builders == 0 then return end

	local builderIndex = 1
	for _, buildCmd in ipairs(buildQueue) do
		local unitID = builders[builderIndex]
		Spring.GiveOrderToUnit(unitID, buildCmd.cmdID, buildCmd.params, buildCmd.opts)
		builderIndex = builderIndex + 1
		if builderIndex > #builders then builderIndex = 1 end
	end

	buildQueue = {} -- Clear the queue
end
