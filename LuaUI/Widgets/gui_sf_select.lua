function widget:GetInfo()
	return {
		name    = "SF Select",
		desc    = "The sfselect action: the engine's select with SF's own filters (unit role, type, faction, customParams...). Bind it to keys like select; the Keybinds window builds the lines.",
		author  = "SplinterFaction Team",
		date    = "2026-10-18",
		license = "GNU GPL, v2 or later",
		layer   = -900,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
--
--  sfselect <source> + <filter> + Not <filter> + ... + ClearSelection + <result>
--
--  Sources, filters and results come from LuaUI/Configs/keybind_actions.lua,
--  which also parses the line (both this grammar and the engine's own
--  select grammar are accepted). Semantics follow the engine's
--  SelectionKeyHandler: SelectOne and SelectNum cycle through the matches on
--  repeated presses, SelectOne also moves the camera to the unit.
--
--------------------------------------------------------------------------------

local ACTIONS_FILE = "LuaUI/Configs/keybind_actions.lua"

local spGetTeamUnits          = Spring.GetTeamUnits
local spGetVisibleUnits       = Spring.GetVisibleUnits
local spGetSelectedUnits      = Spring.GetSelectedUnits
local spGetUnitsInSphere      = Spring.GetUnitsInSphere
local spGetUnitsInCylinder    = Spring.GetUnitsInCylinder
local spGetUnitDefID          = Spring.GetUnitDefID
local spGetUnitTeam           = Spring.GetUnitTeam
local spGetUnitPosition       = Spring.GetUnitPosition
local spSelectUnitArray       = Spring.SelectUnitArray
local spGetMouseState         = Spring.GetMouseState
local spTraceScreenRay        = Spring.TraceScreenRay
local spSetCameraTarget       = Spring.SetCameraTarget
local spGetMyTeamID           = Spring.GetMyTeamID
local spEcho                  = Spring.Echo

local actions                 -- the config module
local cycle = {}              -- spec line -> last index used by SelectOne/SelectNum

--------------------------------------------------------------------------------

local function MouseGroundPos()
	local mx, my = spGetMouseState()
	local kind, pos = spTraceScreenRay(mx, my, true)
	if kind == "ground" and pos then
		return pos[1], pos[2], pos[3]
	end
	return nil
end

local function GatherSource(source)
	local team = spGetMyTeamID()
	local key = source.key:lower()
	if key == "allmap" then
		return spGetTeamUnits(team) or {}
	elseif key == "visible" then
		return spGetVisibleUnits(team, nil, false) or {}
	elseif key == "prevselection" then
		return spGetSelectedUnits() or {}
	elseif key == "frommouse" or key == "frommousec" then
		local x, y, z = MouseGroundPos()
		if not x then return {} end
		local radius = tonumber(source.arg) or 0
		local list
		if key == "frommouse" then
			list = spGetUnitsInSphere(x, y, z, radius, team)
		else
			list = spGetUnitsInCylinder(x, z, radius, team)
		end
		return list or {}
	end
	return {}
end

-- unit def ids of the current selection, for InPrevSel
local function SelectedTypes()
	local types = {}
	for _, unitID in ipairs(spGetSelectedUnits() or {}) do
		local udid = spGetUnitDefID(unitID)
		if udid then types[udid] = true end
	end
	return types
end

local function Matches(unitID, spec, prevTypes)
	local udid = spGetUnitDefID(unitID)
	local ud = udid and UnitDefs[udid]
	if not ud then return false end
	for _, f in ipairs(spec.filters) do
		local def = actions.filterByKey[f.key:lower()]
		if not def then return false end
		local ok
		if def.test == "prevsel" then
			ok = prevTypes[udid] == true
		else
			ok = def.test(unitID, udid, ud, f.arg)
		end
		if f.isNot then ok = not ok end
		if not ok then return false end
	end
	return true
end

local function Conclude(line, spec, matches)
	local result = spec.result or { key = "SelectAll" }
	local key = result.key:lower()
	local current = {}
	if not spec.clear then
		current = spGetSelectedUnits() or {}
	end
	local out, seen = {}, {}
	for _, u in ipairs(current) do out[#out + 1] = u; seen[u] = true end
	local function add(u)
		if u and not seen[u] then out[#out + 1] = u; seen[u] = true end
	end

	if #matches == 0 then
		if spec.clear then spSelectUnitArray(out) end
		return
	end
	table.sort(matches)

	if key == "selectall" then
		for _, u in ipairs(matches) do add(u) end
	elseif key == "selectone" then
		local n = (cycle[line] or 0) + 1
		if n > #matches then n = 1 end
		cycle[line] = n
		local u = matches[n]
		add(u)
		local x, y, z = spGetUnitPosition(u)
		if x then spSetCameraTarget(x, y, z, 0.8) end
	elseif key == "selectnum" then
		local count = tonumber(result.arg) or 1
		local n = cycle[line] or 0
		if n >= #matches then n = 0 end
		for _ = 1, count do
			n = n + 1
			if n > #matches then n = 1 end
			add(matches[n])
		end
		cycle[line] = n
	elseif key == "selectpart" then
		local pct = tonumber(result.arg) or 100
		local count = math.max(1, math.floor(#matches * pct / 100 + 0.5))
		for i = 1, count do add(matches[i]) end
	elseif key == "selectclosesttocursor" then
		local x, _, z = MouseGroundPos()
		local best, bestD
		for _, u in ipairs(matches) do
			local ux, _, uz = spGetUnitPosition(u)
			if ux then
				local d = x and ((ux - x) ^ 2 + (uz - z) ^ 2) or 0
				if not best or d < bestD then best, bestD = u, d end
			end
		end
		add(best)
	else
		for _, u in ipairs(matches) do add(u) end
	end
	spSelectUnitArray(out)
end

local function Run(rest)
	local line = "sfselect " .. (rest or "")
	local _, spec = actions.Parse(line)
	if not spec then
		spEcho("[sfselect] could not parse: " .. line)
		return true
	end
	local prevTypes = SelectedTypes()
	local matches = {}
	for _, unitID in ipairs(GatherSource(spec.source)) do
		if Matches(unitID, spec, prevTypes) then
			matches[#matches + 1] = unitID
		end
	end
	Conclude(rest, spec, matches)
	return true
end

-- (cmd, line, words, data, isRepeat, release): line is everything after the
-- verb, spaces and quotes intact
local function Action(_, line, _, _, isRepeat, release)
	if release or isRepeat then return true end
	return Run(line)
end

--------------------------------------------------------------------------------

function widget:Initialize()
	actions = VFS.Include(ACTIONS_FILE, nil, VFS.ZIP)
	widgetHandler:AddAction("sfselect", Action, nil, "tp") -- key press and /sfselect from the console
	WG.SFSelect = { Run = Run, actions = actions }
end

function widget:Shutdown()
	widgetHandler:RemoveAction("sfselect", "tp")
	WG.SFSelect = nil
end
