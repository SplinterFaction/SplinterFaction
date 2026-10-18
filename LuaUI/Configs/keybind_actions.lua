--------------------------------------------------------------------------------
--
--  Vocabulary of the Keybinds window's bind editor and of the "sfselect"
--  action (gui_sf_select.lua). Data only, so new verbs and filters can be
--  added here without touching either widget.
--
--  Selection syntax
--  ----------------
--  The engine's own "select" action reads
--      select <source>+_<filter>+_<filter>+..._ClearSelection_<result>+
--  where a filter is e.g. Builder, Not_Aircraft, WeaponRange_300.
--
--  "sfselect" accepts the same parts, written more readably:
--      sfselect <source> + <filter> + Not <filter> + ClearSelection + <result>
--  with values after "=", quoted when they contain spaces:
--      sfselect AllMap + Role="Main Battle Tank" + Not Aircraft + ClearSelection + SelectAll
--  It knows every engine filter plus the custom ones below, which can look at
--  anything: unit def fields, customParams, rules params, the live unit.
--
--  The editor writes "select" when every chip used is engine-native and
--  "sfselect" as soon as a custom filter is in the mix.
--
--  Filter fields
--  -------------
--    key     name used in the action line
--    label   shown on the chip
--    engine  true when the engine's "select" knows this filter
--    arg     what value the filter takes, if any:
--              "number", "text", "unit" (a unit def name, picked from a list),
--              "param" (distinct values of a customParam, picked from a list)
--    param   for arg = "param": the customParams key whose values are offered
--    test    function(unitID, unitDefID, ud, value) -> boolean, for sfselect.
--            ud is UnitDefs[unitDefID]. value is the argument as a string.
--
--------------------------------------------------------------------------------

local spGetUnitCommandCount = Spring.GetUnitCommandCount
local spGetUnitCommands     = Spring.GetUnitCommands
local spGetUnitHealth       = Spring.GetUnitHealth
local spGetUnitIsCloaked    = Spring.GetUnitIsCloaked
local spGetUnitGroup        = Spring.GetUnitGroup
local spGetUnitRulesParam   = Spring.GetUnitRulesParam

local function Number(value, default)
	return tonumber(value) or default or 0
end

local function FirstCommand(unitID)
	local cmds = spGetUnitCommands(unitID, 1)
	return cmds and cmds[1] and cmds[1].id
end

local function Param(ud, key)
	local cp = ud.customParams
	return cp and cp[key]
end

local function Lower(s)
	return tostring(s or ""):lower()
end

local M = {}

--------------------------------------------------------------------------------
-- Commands the editor offers. "builder" verbs open the selection builder; the
-- rest take free text after the verb (or nothing).
--------------------------------------------------------------------------------

M.verbs = {
	{ key = "select",            label = "Select units",     builder = true },
	{ key = "sfselect",          label = "Select (SF)",      builder = true, hidden = true }, -- chosen automatically
	{ key = "buildunit_",        label = "Build unit",       arg = "unit", joined = true },
	{ key = "settarget",         label = "Set target" },
	{ key = "canceltarget",      label = "Cancel target" },
	{ key = "morph",             label = "Upgrade" },
	{ key = "morphpause",        label = "Pause upgrade" },
	{ key = "morphqueue",        label = "Queue upgrade" },
	{ key = "splitselection",    label = "Split selection" },
	{ key = "swapselectionhalf", label = "Swap half" },
	{ key = "recombineselection",label = "Recombine" },
	{ key = "pause",             label = "Pause" },
	{ key = "luaui",             label = "luaui ...",        arg = "text" },
	{ key = "",                  label = "Other",            arg = "text", free = true },
}

--------------------------------------------------------------------------------
-- Selection sources
--------------------------------------------------------------------------------

M.sources = {
	{ key = "AllMap",        label = "All map",            engine = true },
	{ key = "Visible",       label = "On screen",          engine = true },
	{ key = "FromMouse",     label = "Near mouse",         engine = true, arg = "number", argLabel = "radius" },
	{ key = "FromMouseC",    label = "Near mouse (cyl.)",  engine = true, arg = "number", argLabel = "radius" },
	{ key = "PrevSelection", label = "Current selection",  engine = true },
}

--------------------------------------------------------------------------------
-- Filters. The engine's set first, then SF's.
--------------------------------------------------------------------------------

M.filters = {
	-- engine
	{ key = "Builder",        label = "Builder",        engine = true, test = function(_, _, ud) return ud.isBuilder end },
	{ key = "Buildoptions",   label = "Has build menu", engine = true, test = function(_, _, ud) return ud.buildOptions and #ud.buildOptions > 0 end },
	{ key = "Building",       label = "Building",       engine = true, test = function(_, _, ud) return ud.isBuilding end },
	{ key = "Aircraft",       label = "Aircraft",       engine = true, test = function(_, _, ud) return ud.canFly end },
	{ key = "Transport",      label = "Transport",      engine = true, test = function(_, _, ud) return ud.isTransport end },
	{ key = "Weapons",        label = "Armed",          engine = true, test = function(_, _, ud) return ud.weapons and #ud.weapons > 0 end },
	{ key = "ManualFireUnit", label = "Manual fire",    engine = true, test = function(_, _, ud) return ud.canManualFire end },
	{ key = "Radar",          label = "Radar/sonar",    engine = true, test = function(_, _, ud) return (ud.radarDistance or 0) > 0 or (ud.sonarDistance or 0) > 0 end },
	{ key = "Jammer",         label = "Jammer",         engine = true, test = function(_, _, ud) return (ud.radarDistanceJam or 0) > 0 end },
	{ key = "Cloak",          label = "Can cloak",      engine = true, test = function(_, _, ud) return ud.canCloak end },
	{ key = "Stealth",        label = "Stealth",        engine = true, test = function(_, _, ud) return ud.stealth end },
	{ key = "Resurrect",      label = "Can resurrect",  engine = true, test = function(_, _, ud) return ud.canResurrect end },
	{ key = "Cloaked",        label = "Cloaked now",    engine = true, test = function(unitID) return spGetUnitIsCloaked(unitID) end },
	{ key = "Idle",           label = "Idle",           engine = true, test = function(unitID) return (spGetUnitCommandCount(unitID) or 0) == 0 end },
	{ key = "Waiting",        label = "Waiting",        engine = true, test = function(unitID) return FirstCommand(unitID) == CMD.WAIT end },
	{ key = "Guarding",       label = "Guarding",       engine = true, test = function(unitID) return FirstCommand(unitID) == CMD.GUARD end },
	{ key = "Patrolling",     label = "Patrolling",     engine = true, test = function(unitID)
		local cmds = spGetUnitCommands(unitID, 4) or {}
		for i = 1, #cmds do
			if cmds[i].id == CMD.PATROL then return true end
		end
		return false
	end },
	{ key = "InHotkeyGroup",  label = "In a group",     engine = true, test = function(unitID) return spGetUnitGroup(unitID) ~= nil end },
	{ key = "InGroup",        label = "In group #",     engine = true, arg = "number", test = function(unitID, _, _, v) return spGetUnitGroup(unitID) == Number(v, -1) end },
	{ key = "InPrevSel",      label = "Same type as selected", engine = true, test = "prevsel" },
	{ key = "WeaponRange",    label = "Range over",     engine = true, arg = "number", test = function(_, _, ud, v) return (ud.maxWeaponRange or 0) > Number(v) end },
	{ key = "AbsoluteHealth", label = "Health over",    engine = true, arg = "number", test = function(unitID, _, _, v) return (spGetUnitHealth(unitID) or 0) > Number(v) end },
	{ key = "RelativeHealth", label = "Health % over",  engine = true, arg = "number", test = function(unitID, _, _, v)
		local h, mh = spGetUnitHealth(unitID)
		return h and mh and mh > 0 and (h / mh) > Number(v) * 0.01
	end },
	{ key = "NameContain",    label = "Name contains",  engine = true, arg = "text", test = function(_, _, ud, v) return Lower(ud.humanName):find(Lower(v), 1, true) ~= nil end },
	{ key = "IdMatches",      label = "Unit",           engine = true, arg = "unit", test = function(_, _, ud, v) return ud.name == v end },
	{ key = "Category",       label = "Category",       engine = true, arg = "text", test = function(_, _, ud, v) return ud.categories and ud.categories[Lower(v)] == true end },
	{ key = "RulesParamEquals", label = "Rules param", engine = true, arg = "text", argLabel = "param_value", test = function(unitID, _, _, v)
		local param, value = tostring(v):match("^([^_]+)_(.*)$")
		if not param then return false end
		return tostring(spGetUnitRulesParam(unitID, param)) == value
	end },

	-- SF: customParams on the unit def
	{ key = "Type",     label = "Unit type",   arg = "param", param = "unittype",          test = function(_, _, ud, v) return Lower(Param(ud, "unittype")) == Lower(v) end },
	{ key = "Role",     label = "Unit role",   arg = "param", param = "unitrole",          test = function(_, _, ud, v) return Lower(Param(ud, "unitrole")) == Lower(v) end },
	{ key = "RoleLike", label = "Role contains", arg = "text",                             test = function(_, _, ud, v) return Lower(Param(ud, "unitrole")):find(Lower(v), 1, true) ~= nil end },
	{ key = "Faction",  label = "Faction",     arg = "param", param = "factionname",       test = function(_, _, ud, v) return Lower(Param(ud, "factionname")) == Lower(v) end },
	{ key = "Tech",     label = "Tech",        arg = "param", param = "requiretech",       test = function(_, _, ud, v) return Lower(Param(ud, "requiretech")) == Lower(v) end },
	{ key = "Menu",     label = "Build menu",  arg = "param", param = "buildmenucategory", test = function(_, _, ud, v) return Lower(Param(ud, "buildmenucategory")) == Lower(v) end },
	{ key = "Armor",    label = "Armor type",  arg = "param", param = "armortype",         test = function(_, _, ud, v) return Lower(Param(ud, "armortype")) == Lower(v) end },
	{ key = "Upgraded", label = "Upgraded",                                                test = function(_, _, ud) local p = Param(ud, "isupgraded"); return p == "1" or p == 1 or p == "true" end },
	{ key = "Param",    label = "Custom param", arg = "text", argLabel = "key=value",      test = function(_, _, ud, v)
		local key, value = tostring(v):match("^([^=]+)=(.*)$")
		if not key then return false end
		return Lower(Param(ud, Lower(key))) == Lower(value)
	end },
}

--------------------------------------------------------------------------------
-- What to do with the matches. ClearSelection is a separate toggle; one of
-- these is picked.
--------------------------------------------------------------------------------

M.results = {
	{ key = "SelectAll",            label = "Select all",        engine = true },
	{ key = "SelectOne",            label = "Select one (cycle)",engine = true },
	{ key = "SelectNum",            label = "Select N",          engine = true, arg = "number", argLabel = "count" },
	{ key = "SelectPart",           label = "Select %",          engine = true, arg = "number", argLabel = "percent" },
	{ key = "SelectClosestToCursor",label = "Closest to cursor", engine = true },
}

--------------------------------------------------------------------------------
-- lookups
--------------------------------------------------------------------------------

M.sourceByKey, M.filterByKey, M.resultByKey, M.verbByKey = {}, {}, {}, {}
for _, s in ipairs(M.sources) do M.sourceByKey[s.key:lower()] = s end
for _, f in ipairs(M.filters) do M.filterByKey[f.key:lower()] = f end
for _, r in ipairs(M.results) do M.resultByKey[r.key:lower()] = r end
for _, v in ipairs(M.verbs)   do M.verbByKey[v.key] = v end

--------------------------------------------------------------------------------
-- Parsing and writing selection lines
--
-- A parsed selection ("spec"):
--   { source = {key=, arg=}, filters = { {key=, isNot=, arg=}, ... },
--     clear = bool, result = {key=, arg=} }
-- Keys are the canonical ones from the tables above.
--------------------------------------------------------------------------------

local function Trim(s) return (tostring(s):match("^%s*(.-)%s*$")) end

local function SplitPlus(s)
	-- split on "+" outside quotes
	local parts, cur, inQuote = {}, {}, false
	for i = 1, #s do
		local c = s:sub(i, i)
		if c == '"' then
			inQuote = not inQuote
			cur[#cur + 1] = c
		elseif c == "+" and not inQuote then
			parts[#parts + 1] = table.concat(cur)
			cur = {}
		else
			cur[#cur + 1] = c
		end
	end
	parts[#parts + 1] = table.concat(cur)
	return parts
end

local function Unquote(v)
	v = Trim(v)
	if v:sub(1, 1) == '"' and v:sub(-1) == '"' then
		v = v:sub(2, -2)
	end
	return v
end

-- engine grammar: AllMap+_Not_Aircraft+_WeaponRange_300+_ClearSelection_SelectOne+
local function ParseEngine(body)
	local spec = { filters = {}, clear = false }
	local parts = SplitPlus(body)
	-- source
	local src = Trim(parts[1] or "")
	local sname, sarg = src:match("^([%a]+)_?(.*)$")
	local source = sname and M.sourceByKey[sname:lower()]
	if not source then return nil end
	spec.source = { key = source.key, arg = (sarg ~= "" and sarg) or nil }

	for i = 2, #parts do
		local part = Trim(parts[i])
		if part ~= "" then
			local pieces = {}
			for piece in part:gmatch("[^_]+") do pieces[#pieces + 1] = piece end
			local j = 1
			while j <= #pieces do
				local piece = pieces[j]
				local lower = piece:lower()
				if lower == "clearselection" then
					spec.clear = true
					j = j + 1
				elseif M.resultByKey[lower] then
					local r = M.resultByKey[lower]
					local arg
					if r.arg then arg = pieces[j + 1]; j = j + 1 end
					spec.result = { key = r.key, arg = arg }
					j = j + 1
				else
					local isNot = false
					if lower == "not" then
						isNot = true
						j = j + 1
						piece = pieces[j]
						lower = piece and piece:lower()
					end
					local f = lower and M.filterByKey[lower]
					if not f then return nil end
					local arg
					if f.arg then
						-- the value is the rest of this part (RulesParamEquals_a_b keeps its "_")
						arg = table.concat(pieces, "_", j + 1)
						j = #pieces
					end
					spec.filters[#spec.filters + 1] = { key = f.key, isNot = isNot, arg = arg }
					j = j + 1
				end
			end
		end
	end
	return spec
end

-- sfselect grammar: AllMap + Role="Main Battle Tank" + Not Aircraft + ClearSelection + SelectAll
local function ParseSF(body)
	local spec = { filters = {}, clear = false }
	local parts = SplitPlus(body)
	for i, raw in ipairs(parts) do
		local part = Trim(raw)
		if part ~= "" then
			local isNot = false
			local notless = part:match("^[Nn][Oo][Tt]%s+(.+)$") or part:match("^[Nn][Oo][Tt]_(.+)$")
			if notless then isNot = true; part = notless end
			local name, value = part:match("^([%a]+)%s*=%s*(.+)$")
			if not name then name = part:match("^([%a]+)$") end
			if not name then return nil end
			local lower = name:lower()
			value = value and Unquote(value)
			if i == 1 and M.sourceByKey[lower] then
				spec.source = { key = M.sourceByKey[lower].key, arg = value }
			elseif lower == "clearselection" then
				spec.clear = true
			elseif M.resultByKey[lower] then
				spec.result = { key = M.resultByKey[lower].key, arg = value }
			elseif M.filterByKey[lower] then
				spec.filters[#spec.filters + 1] = { key = M.filterByKey[lower].key, isNot = isNot, arg = value }
			else
				return nil
			end
		end
	end
	if not spec.source then return nil end
	return spec
end

-- Parses a full action line. Returns verb, spec (spec nil when the verb is
-- not a selection or the line does not parse).
function M.Parse(line)
	line = Trim(line or "")
	local verb, rest = line:match("^(%S+)%s*(.*)$")
	if not verb then return nil end
	local lower = verb:lower()
	if lower == "select" then
		return "select", ParseEngine(rest)
	elseif lower == "sfselect" then
		return "sfselect", ParseSF(rest) or ParseEngine(rest)
	end
	return verb, nil
end

-- True when the engine's own "select" can run this spec.
function M.IsEngineNative(spec)
	if not spec or not spec.source then return false end
	local s = M.sourceByKey[spec.source.key:lower()]
	if not (s and s.engine) then return false end
	for _, f in ipairs(spec.filters) do
		local def = M.filterByKey[f.key:lower()]
		if not (def and def.engine) then return false end
	end
	if spec.result then
		local r = M.resultByKey[spec.result.key:lower()]
		if not (r and r.engine) then return false end
	end
	return true
end

local function Quote(v)
	v = tostring(v)
	if v:find("[%s%+=]") then return '"' .. v .. '"' end
	return v
end

-- Writes a spec as an action line. verb is "select", "sfselect" or nil to
-- pick: select when engine-native, sfselect otherwise.
function M.Format(spec, verb)
	if not spec or not spec.source then return nil end
	if not verb then
		verb = M.IsEngineNative(spec) and "select" or "sfselect"
	end
	local src = spec.source
	if verb == "select" then
		local parts = { src.key .. ((src.arg and src.arg ~= "") and ("_" .. src.arg) or "") }
		for _, f in ipairs(spec.filters) do
			local t = "_" .. (f.isNot and "Not_" or "") .. f.key
			if f.arg and f.arg ~= "" then t = t .. "_" .. f.arg end
			parts[#parts + 1] = t
		end
		local tail = "_"
		if spec.clear then tail = tail .. "ClearSelection_" end
		if spec.result then
			tail = tail .. spec.result.key
			if spec.result.arg and spec.result.arg ~= "" then tail = tail .. "_" .. spec.result.arg end
		else
			tail = tail .. "SelectAll"
		end
		parts[#parts + 1] = tail
		return "select " .. table.concat(parts, "+") .. "+"
	end

	local parts = { src.key .. ((src.arg and src.arg ~= "") and ("=" .. Quote(src.arg)) or "") }
	for _, f in ipairs(spec.filters) do
		local t = (f.isNot and "Not " or "") .. f.key
		if f.arg and f.arg ~= "" then t = t .. "=" .. Quote(f.arg) end
		parts[#parts + 1] = t
	end
	if spec.clear then parts[#parts + 1] = "ClearSelection" end
	local r = spec.result or { key = "SelectAll" }
	parts[#parts + 1] = r.key .. ((r.arg and r.arg ~= "") and ("=" .. Quote(r.arg)) or "")
	return "sfselect " .. table.concat(parts, " + ")
end

return M
