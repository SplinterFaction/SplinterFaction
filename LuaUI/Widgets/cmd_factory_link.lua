function widget:GetInfo()
	return {
		name    = "Factory Link",
		desc    = "Link factories so they share one build queue: what you order from any of them is built by whichever comes free first",
		author  = "SplinterFaction Team",
		date    = "2026-11-22",
		license = "GNU GPL, v2 or later",
		layer   = -6,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
--
--  Linked factories share a queue.
--
--    Select two or more factories and press Link (order panel, or Alt+L).
--    Linking a factory that is already linked joins the two groups. Unlink
--    (order panel, or Alt+Shift+L) takes the selected factories out again.
--
--    What the factories already had queued goes into the shared queue, all
--    but the unit each is working on. From then on, a unit ordered from any
--    linked factory is ordered from the group: "5 tanks" is five in all, not
--    five each. Left and right click, Shift (5) and Ctrl (20) and Alt (to the
--    front) work as they always do. Hold Space to order from the selected
--    factory alone.
--
--    A factory holds only the unit it is building, and takes the next thing
--    in the shared queue that it can build when that one is nearly done. So
--    nothing is promised to a factory ahead of time, a faster factory simply
--    takes more, and a factory that is lost gives back what it held.
--
--    Repeat belongs to the group: a finished unit goes back on the end of the
--    shared queue, unless it was ordered with Alt: that one is built once. Rally points stay each factory's own, unless shared rally
--    is on (WG.factoryLink.tune.sharedRally), in which case a move, fight,
--    patrol or guard order to one is given to all.
--
--    Linked factories are joined by a line on the ground in the group's
--    colour, bright while one of them is selected.
--
--  The links are this player's own: allies and spectators do not see them.
--  They are saved with the widget, so they survive /luaui reload.
--
--  WG.factoryLink: Link, Unlink, GroupOf, GetGroups, SelectionPool, Counts,
--  Remove, tune. See widget:Initialize.
--
--------------------------------------------------------------------------------

local CMD_FACTORY_LINK   = 39701
local CMD_FACTORY_UNLINK = 39702

local TUNE = {
	ahead       = 1.5,   -- seconds before a unit is done that its factory takes the next
	graceTime   = 1.5,   -- seconds an order may take to show up in a factory's queue...
	graceFrames = 45,    -- ...and game frames; both must pass before it counts as lost
	retryTime   = 5,     -- seconds before a factory is offered again what it failed to take
	sharedRally = false, -- rally orders to one linked factory go to all of its group
	period      = 0.1,   -- seconds between looks at the factories
}

local COLORS = {
	{ 0.30, 0.85, 1.00 },
	{ 0.50, 1.00, 0.45 },
	{ 1.00, 0.40, 0.75 },
	{ 0.72, 0.55, 1.00 },
	{ 1.00, 0.90, 0.30 },
	{ 1.00, 0.61, 0.13 },
}

local RESTORE_WINDOW = 120 -- seconds after which saved links are taken to be from another game

local RALLY = {
	[CMD.MOVE] = true, [CMD.FIGHT] = true, [CMD.PATROL] = true, [CMD.GUARD] = true,
}

--------------------------------------------------------------------------------

local spGetUnitDefID        = Spring.GetUnitDefID
local spGetUnitTeam         = Spring.GetUnitTeam
local spGetUnitPosition     = Spring.GetUnitPosition
local spGetSelectedUnits    = Spring.GetSelectedUnits
local spGetFactoryCommands  = Spring.GetFactoryCommands
local spGetFullBuildQueue   = Spring.GetFullBuildQueue
local spGetUnitIsBuilding   = Spring.GetUnitIsBuilding
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetUnitHealth       = Spring.GetUnitHealth
local spGetUnitStates       = Spring.GetUnitStates
local spGiveOrderToUnit     = Spring.GiveOrderToUnit
local spGetGameFrame        = Spring.GetGameFrame
local spGetGroundHeight     = Spring.GetGroundHeight
local spValidUnitID         = Spring.ValidUnitID
local spEcho                = Spring.Echo

local sqrt, floor, max, min = math.sqrt, math.floor, math.max, math.min

-- unitDefID -> {can = {[unitDefID] = true}, buildSpeed, radius} for factories
local factoryDefs = {}
local buildTime = {}
for unitDefID, ud in pairs(UnitDefs) do
	if ud.isFactory and ud.buildOptions and #ud.buildOptions > 0 then
		local can = {}
		for i = 1, #ud.buildOptions do
			can[ud.buildOptions[i]] = true
		end
		factoryDefs[unitDefID] = {
			can = can,
			buildSpeed = max(0.01, ud.buildSpeed or 0.01),
			radius = max(ud.xsize or 4, ud.zsize or 4) * 4 + 10,
		}
	end
	buildTime[unitDefID] = ud.buildTime or 1
end

local myTeam = Spring.GetMyTeamID()
local spectating = Spring.GetSpectatingState()

local groups = {}     -- list of {id, members = {unitID...}, pool = {{def, count}...}, rep, color, edges}
local groupOf = {}    -- unitID -> its group
local held = {}       -- unitID -> {{def, time, frame}...}: what the shared queue has given it and it has not finished
local cool = {}       -- unitID -> {[def] = time}: not to be offered this again before then
local nextGroupID = 1
local savedData       -- what SetConfigData brought, until Initialize looks at it
local clock = 0       -- seconds since the widget started
local sinceLook = 0
local selectedGroups = {} -- [group] = true for the groups with a selected member

--------------------------------------------------------------------------------
-- factories
--------------------------------------------------------------------------------

local function FactoryInfo(unitID)
	local unitDefID = spGetUnitDefID(unitID)
	return unitDefID and factoryDefs[unitDefID] or nil
end

local function IsMine(unitID)
	return spValidUnitID(unitID) and spGetUnitTeam(unitID) == myTeam
end

-- whether this factory may build the unit right now (it is on its menu and not greyed out)
local function CanBuildNow(unitID, info, def)
	if not info.can[def] then
		return false
	end
	local index = Spring.FindUnitCmdDesc(unitID, -def)
	if not index then
		return false
	end
	local descs = Spring.GetUnitCmdDescs(unitID, index, index)
	local desc = descs and descs[1]
	return desc ~= nil and not desc.disabled
end

local function GroupCan(group, def)
	for i = 1, #group.members do
		local info = FactoryInfo(group.members[i])
		if info and info.can[def] then
			return true
		end
	end
	return false
end

--------------------------------------------------------------------------------
-- the shared queue
--------------------------------------------------------------------------------

-- once: built one time and not put back by repeat (an Alt order, as in a
-- factory of its own)
local function PoolAdd(group, def, count, front, once)
	local pool = group.pool
	if count <= 0 then
		return
	end
	once = once and true or nil
	if front then
		if pool[1] and pool[1].def == def and pool[1].once == once then
			pool[1].count = pool[1].count + count
		else
			table.insert(pool, 1, { def = def, count = count, once = once })
		end
	else
		local last = pool[#pool]
		if last and last.def == def and last.once == once then
			last.count = last.count + count
		else
			pool[#pool + 1] = { def = def, count = count, once = once }
		end
	end
end

-- takes up to count of def out, from the back; returns how many it could not find
local function PoolRemove(group, def, count)
	local pool = group.pool
	for i = #pool, 1, -1 do
		if count <= 0 then
			break
		end
		local entry = pool[i]
		if entry.def == def then
			local take = min(count, entry.count)
			entry.count = entry.count - take
			count = count - take
			if entry.count <= 0 then
				table.remove(pool, i)
			end
		end
	end
	return count
end

-- the first thing in the queue that this factory can build, taken out of it
local function PoolTake(group, unitID, info)
	local pool = group.pool
	local wait = cool[unitID]
	for i = 1, #pool do
		local entry = pool[i]
		if not (wait and wait[entry.def] and wait[entry.def] > clock) and CanBuildNow(unitID, info, entry.def) then
			entry.count = entry.count - 1
			if entry.count <= 0 then
				table.remove(pool, i)
			end
			return entry.def, entry.once
		end
	end
	return nil
end

local function GiveBuild(unitID, def, count, remove)
	-- the engine counts in the factory's own way: Shift is 5, Ctrl 20, both 100
	local steps = { { 100, { "shift", "ctrl" } }, { 20, { "ctrl" } }, { 5, { "shift" } }, { 1, {} } }
	for s = 1, #steps do
		local size, opts = steps[s][1], steps[s][2]
		while count >= size do
			local o = {}
			for i = 1, #opts do o[i] = opts[i] end
			if remove then o[#o + 1] = "right" end
			spGiveOrderToUnit(unitID, -def, {}, o)
			count = count - size
		end
	end
end

--------------------------------------------------------------------------------
-- groups
--------------------------------------------------------------------------------

local function Relayout()
	Spring.ForceLayoutUpdate() -- the Link and Unlink buttons depend on who is linked
end

local function NewGroup()
	local used = {}
	for i = 1, #groups do
		used[groups[i].color] = true
	end
	local color = 1
	for c = 1, #COLORS do
		if not used[c] then
			color = c
			break
		end
		color = (nextGroupID - 1) % #COLORS + 1
	end
	local group = { id = nextGroupID, members = {}, pool = {}, rep = false, color = color }
	nextGroupID = nextGroupID + 1
	groups[#groups + 1] = group
	return group
end

local function DropGroup(group)
	for i = #groups, 1, -1 do
		if groups[i] == group then
			table.remove(groups, i)
		end
	end
end

local function RemoveMember(group, unitID)
	for i = #group.members, 1, -1 do
		if group.members[i] == unitID then
			table.remove(group.members, i)
		end
	end
	groupOf[unitID] = nil
	group.edges = nil
end

-- A group of one is no group: the last factory gets what is left of the queue
-- as its own, and repeat if the group had it.
local function Dissolve(group)
	local last = group.members[1]
	if last and IsMine(last) then
		local info = FactoryInfo(last)
		for i = 1, #group.pool do
			local entry = group.pool[i]
			if info and info.can[entry.def] then
				GiveBuild(last, entry.def, entry.count, false)
			end
		end
		if group.rep then
			spGiveOrderToUnit(last, CMD.REPEAT, { 1 }, 0)
		end
		groupOf[last] = nil
		held[last] = nil
		cool[last] = nil
	end
	DropGroup(group)
end

-- everything a factory has queued but the first unit goes into the shared queue
local function Absorb(group, unitID)
	local queue = spGetFullBuildQueue(unitID) or {}
	local first
	for i = 1, #queue do
		for def, count in pairs(queue[i]) do
			if not first then
				first = def
				count = count - 1
			end
			if count > 0 then
				PoolAdd(group, def, count)
				GiveBuild(unitID, def, count, true)
			end
		end
	end
	held[unitID] = first and { { def = first, time = clock, frame = spGetGameFrame() } } or {}
	local states = spGetUnitStates(unitID)
	if states and states["repeat"] then
		group.rep = true
		spGiveOrderToUnit(unitID, CMD.REPEAT, { 0 }, 0)
	end
end

local function Link(units)
	if spectating then
		return false
	end
	local list, seen = {}, {}
	for i = 1, #units do
		local unitID = units[i]
		if not seen[unitID] and IsMine(unitID) and FactoryInfo(unitID) then
			seen[unitID] = true
			list[#list + 1] = unitID
		end
	end
	if #list < 2 then
		return false
	end

	-- the group to join: the first one any of them is in, or a new one
	local target
	for i = 1, #list do
		target = target or groupOf[list[i]]
	end
	target = target or NewGroup()

	local changed = false
	for i = 1, #list do
		local unitID = list[i]
		local group = groupOf[unitID]
		if group and group ~= target then
			-- the whole of the other group comes over
			for m = 1, #group.members do
				local member = group.members[m]
				target.members[#target.members + 1] = member
				groupOf[member] = target
			end
			for p = 1, #group.pool do
				PoolAdd(target, group.pool[p].def, group.pool[p].count, false, group.pool[p].once)
			end
			target.rep = target.rep or group.rep
			DropGroup(group)
			changed = true
		elseif not group then
			target.members[#target.members + 1] = unitID
			groupOf[unitID] = target
			Absorb(target, unitID)
			changed = true
		end
	end
	target.edges = nil
	if changed then
		Relayout()
	end
	return changed, target.id
end

local function Unlink(units)
	local changed = false
	for i = 1, #units do
		local unitID = units[i]
		local group = groupOf[unitID]
		if group then
			-- it keeps what it holds, as its own queue
			RemoveMember(group, unitID)
			held[unitID] = nil
			cool[unitID] = nil
			if #group.members < 2 then
				Dissolve(group)
			end
			changed = true
		end
	end
	if changed then
		Relayout()
	end
	return changed
end

-- a factory that is gone: what it held goes back to the front of the queue
local function Lost(unitID)
	local group = groupOf[unitID]
	if not group then
		return
	end
	local h = held[unitID] or {}
	for i = #h, 1, -1 do
		PoolAdd(group, h[i].def, 1, true, h[i].once)
	end
	held[unitID] = nil
	cool[unitID] = nil
	RemoveMember(group, unitID)
	if #group.members < 2 then
		Dissolve(group)
	end
	Relayout()
end

--------------------------------------------------------------------------------
-- feeding the factories
--------------------------------------------------------------------------------

local function Feed(group, unitID)
	local info = FactoryInfo(unitID)
	if not info or spGetUnitIsBeingBuilt(unitID) then
		return
	end
	local h = held[unitID]
	if not h then
		h = {}
		held[unitID] = h
	end
	local queued = #(spGetFactoryCommands(unitID, 3) or {})

	if queued == 0 and #h > 0 then
		local oldest = h[1]
		if clock - oldest.time < TUNE.graceTime or spGetGameFrame() - oldest.frame < TUNE.graceFrames then
			return -- the order is on its way
		end
		-- it never arrived, or the factory turned it down: back it goes
		cool[unitID] = cool[unitID] or {}
		for i = #h, 1, -1 do
			PoolAdd(group, h[i].def, 1, true, h[i].once)
			cool[unitID][h[i].def] = clock + TUNE.retryTime
			h[i] = nil
		end
		return
	end

	local want = false
	if queued == 0 then
		want = true
	elseif queued == 1 and #h == 1 then
		-- nearly done with the one it has: line up the next so it never stands idle
		local nanoframe = spGetUnitIsBuilding(unitID)
		if nanoframe then
			local _, _, _, _, progress = spGetUnitHealth(nanoframe)
			local def = spGetUnitDefID(nanoframe)
			if progress and def then
				want = (1 - progress) * (buildTime[def] or 1) / info.buildSpeed < TUNE.ahead
			end
		end
	end
	if not want or #group.pool == 0 then
		return
	end

	local def, once = PoolTake(group, unitID, info)
	if def then
		spGiveOrderToUnit(unitID, -def, {}, 0)
		h[#h + 1] = { def = def, once = once, time = clock, frame = spGetGameFrame() }
	end
end

function widget:Update(dt)
	clock = clock + dt
	sinceLook = sinceLook + dt
	if sinceLook < TUNE.period or spectating then
		return
	end
	sinceLook = 0

	for g = #groups, 1, -1 do
		local group = groups[g]
		for m = #group.members, 1, -1 do
			local unitID = group.members[m]
			if not IsMine(unitID) then
				Lost(unitID)
			end
		end
	end
	for g = 1, #groups do
		local group = groups[g]
		for m = 1, #group.members do
			Feed(group, group.members[m])
		end
	end

	selectedGroups = {}
	local selected = spGetSelectedUnits() or {}
	for i = 1, #selected do
		local group = groupOf[selected[i]]
		if group then
			selectedGroups[group] = true
		end
	end
end

function widget:UnitFromFactory(unitID, unitDefID, unitTeam, factID)
	local group = groupOf[factID]
	local h = held[factID]
	if not group or not h then
		return
	end
	for i = 1, #h do
		if h[i].def == unitDefID then
			local once = h[i].once
			table.remove(h, i)
			if group.rep and not once then
				PoolAdd(group, unitDefID, 1)
			end
			return
		end
	end
end

function widget:UnitDestroyed(unitID)
	if groupOf[unitID] then
		Lost(unitID)
	end
end

function widget:UnitTaken(unitID)
	if groupOf[unitID] then
		Lost(unitID)
	end
end

--------------------------------------------------------------------------------
-- orders
--------------------------------------------------------------------------------

local function SelectedFactories()
	local selected = spGetSelectedUnits() or {}
	local factories = {}
	for i = 1, #selected do
		if FactoryInfo(selected[i]) and IsMine(selected[i]) then
			factories[#factories + 1] = selected[i]
		end
	end
	return factories, selected
end

local function OptionList(opts)
	local list = {}
	for _, name in ipairs({ "alt", "ctrl", "shift", "right", "meta" }) do
		if opts[name] then
			list[#list + 1] = name
		end
	end
	return list
end

-- takes count of def away from a group: from the queue first, then from what its factories hold
local function RemoveFromGroup(group, def, count)
	count = PoolRemove(group, def, count)
	for m = #group.members, 1, -1 do
		if count <= 0 then
			break
		end
		local unitID = group.members[m]
		local h = held[unitID] or {}
		for i = #h, 1, -1 do
			if count > 0 and h[i].def == def then
				table.remove(h, i)
				GiveBuild(unitID, def, 1, true)
				count = count - 1
			end
		end
	end
end

function widget:CommandNotify(cmdID, cmdParams, cmdOpts)
	if spectating then
		return false
	end
	if cmdID == CMD_FACTORY_LINK then
		local factories = SelectedFactories()
		local ok, id = Link(factories)
		if ok then
			spEcho("[Factory Link] " .. #groupOf[factories[1]].members .. " factories share a queue")
		end
		return true
	elseif cmdID == CMD_FACTORY_UNLINK then
		if Unlink(SelectedFactories()) then
			spEcho("[Factory Link] unlinked")
		end
		return true
	end

	local selected = spGetSelectedUnits() or {}
	local linked, others, inGroups = {}, {}, {}
	for i = 1, #selected do
		local group = groupOf[selected[i]]
		if group then
			if not linked[group] then
				linked[group] = true
				inGroups[#inGroups + 1] = group
			end
		else
			others[#others + 1] = selected[i]
		end
	end
	if #inGroups == 0 then
		return false
	end

	if cmdID < 0 and #cmdParams == 0 then
		if cmdOpts.meta then
			return false -- Space: from the selected factories alone
		end
		local def = -cmdID
		local count = 1
		if cmdOpts.shift then count = count * 5 end
		if cmdOpts.ctrl then count = count * 20 end
		for g = 1, #inGroups do
			local group = inGroups[g]
			if cmdOpts.right then
				RemoveFromGroup(group, def, count)
			elseif GroupCan(group, def) then
				PoolAdd(group, def, count, cmdOpts.alt, cmdOpts.alt)
			end
		end
		if #others > 0 then
			Spring.GiveOrderToUnitArray(others, cmdID, cmdParams, OptionList(cmdOpts))
		end
		sinceLook = TUNE.period -- hand it out at once
		return true
	end

	if cmdID == CMD.REPEAT then
		local on = not inGroups[1].rep
		for g = 1, #inGroups do
			inGroups[g].rep = on
		end
		if #others > 0 then
			Spring.GiveOrderToUnitArray(others, cmdID, { on and 1 or 0 }, 0)
		end
		spEcho("[Factory Link] repeat " .. (on and "on" or "off"))
		Relayout()
		return true
	end

	if TUNE.sharedRally and RALLY[cmdID] then
		local isSelected = {}
		for i = 1, #selected do
			isSelected[selected[i]] = true
		end
		local rest = {}
		for g = 1, #inGroups do
			for m = 1, #inGroups[g].members do
				local unitID = inGroups[g].members[m]
				if not isSelected[unitID] then
					rest[#rest + 1] = unitID
				end
			end
		end
		if #rest > 0 then
			Spring.GiveOrderToUnitArray(rest, cmdID, cmdParams, OptionList(cmdOpts))
		end
	end
	return false
end

function widget:CommandsChanged()
	if spectating then
		return
	end
	local factories = SelectedFactories()
	if #factories == 0 then
		return
	end
	local anyLinked, oneGroup = false, true
	local first = groupOf[factories[1]]
	for i = 1, #factories do
		local group = groupOf[factories[i]]
		anyLinked = anyLinked or (group ~= nil)
		if group == nil or group ~= first then
			oneGroup = false
		end
	end
	if #factories >= 2 and not oneGroup then
		widgetHandler:AddLayoutCommand({
			id = CMD_FACTORY_LINK, type = CMDTYPE.ICON, name = "Link", action = "factorylink",
			tooltip = "Link the selected factories: they share one build queue, and each takes the next unit from it as it comes free",
		})
	end
	if anyLinked then
		widgetHandler:AddLayoutCommand({
			id = CMD_FACTORY_UNLINK, type = CMDTYPE.ICON, name = "Unlink", action = "factoryunlink",
			tooltip = "Take the selected factories out of their shared queue",
		})
	end
end

function widget:PlayerChanged()
	local team = Spring.GetMyTeamID()
	spectating = Spring.GetSpectatingState()
	if team ~= myTeam or spectating then
		groups, groupOf, held, cool = {}, {}, {}, {}
	end
	myTeam = team
end

--------------------------------------------------------------------------------
-- what the build menu asks
--------------------------------------------------------------------------------

-- The shared queue of the selection, or nil when no linked factory is selected:
-- {factories, rep, items = {{def, count, building}...}}. What the factories
-- are building comes first, then the queue in order.
local function SelectionPool()
	local selected = spGetSelectedUnits() or {}
	local seen, list = {}, {}
	for i = 1, #selected do
		local group = groupOf[selected[i]]
		if group and not seen[group] then
			seen[group] = true
			list[#list + 1] = group
		end
	end
	if #list == 0 then
		return nil
	end
	local result = { factories = 0, rep = false, items = {} }
	local items = result.items
	local building, order = {}, {}
	for g = 1, #list do
		local group = list[g]
		result.factories = result.factories + #group.members
		result.rep = result.rep or group.rep
		for m = 1, #group.members do
			local h = held[group.members[m]] or {}
			for i = 1, #h do
				if not building[h[i].def] then
					building[h[i].def] = 0
					order[#order + 1] = h[i].def
				end
				building[h[i].def] = building[h[i].def] + 1
			end
		end
	end
	for i = 1, #order do
		items[#items + 1] = { def = order[i], count = building[order[i]], building = true }
	end
	for g = 1, #list do
		local pool = list[g].pool
		for p = 1, #pool do
			items[#items + 1] = { def = pool[p].def, count = pool[p].count, building = false }
		end
	end
	return result
end

-- [unitDefID] = how many the selected groups have queued or in hand, or nil when no linked factory is selected
local function Counts()
	local pool = SelectionPool()
	if not pool then
		return nil
	end
	local counts = {}
	for i = 1, #pool.items do
		local item = pool.items[i]
		counts[item.def] = (counts[item.def] or 0) + item.count
	end
	return counts, pool
end

-- takes count of this unit out of the selected groups' queues
local function Remove(def, count)
	local selected = spGetSelectedUnits() or {}
	local seen = {}
	for i = 1, #selected do
		local group = groupOf[selected[i]]
		if group and not seen[group] then
			seen[group] = true
			RemoveFromGroup(group, def, count or 1)
		end
	end
end

--------------------------------------------------------------------------------
-- drawing: a line between linked factories, a ring around each
--------------------------------------------------------------------------------

-- the shortest set of lines that joins every factory of the group
local function Edges(group)
	local points = {}
	for m = 1, #group.members do
		local x, _, z = spGetUnitPosition(group.members[m])
		if x then
			local info = FactoryInfo(group.members[m])
			points[#points + 1] = { x = x, z = z, r = info and info.radius or 40 }
		end
	end
	local edges = { points = points }
	if #points < 2 then
		return edges
	end
	local joined = { [1] = true }
	for _ = 2, #points do
		local best, from, to
		for a = 1, #points do
			if joined[a] then
				for b = 1, #points do
					if not joined[b] then
						local dx, dz = points[a].x - points[b].x, points[a].z - points[b].z
						local d = dx * dx + dz * dz
						if not best or d < best then
							best, from, to = d, a, b
						end
					end
				end
			end
		end
		joined[to] = true
		-- from the edge of one ring to the edge of the other, following the ground
		local a, b = points[from], points[to]
		local length = sqrt(best)
		if length > a.r + b.r + 8 then
			local ux, uz = (b.x - a.x) / length, (b.z - a.z) / length
			local x1, z1 = a.x + ux * a.r, a.z + uz * a.r
			local run = length - a.r - b.r
			local steps = max(1, floor(run / 40))
			local line = { length = run }
			for s = 0, steps do
				local x, z = x1 + ux * run * s / steps, z1 + uz * run * s / steps
				line[#line + 1] = { x, spGetGroundHeight(x, z) + 4, z }
			end
			edges[#edges + 1] = line
		end
	end
	return edges
end

local function LineVertices(line)
	for i = 1, #line - 1 do
		gl.Vertex(line[i][1], line[i][2], line[i][3])
		gl.Vertex(line[i + 1][1], line[i + 1][2], line[i + 1][3])
	end
end

-- a short bright stretch at fraction t of the line
local function PulseVertices(line, t, size)
	local n = #line - 1
	local from, to = max(0, t - size) * n, min(1, t + size) * n
	local function At(f)
		local i = min(n - 1, floor(f))
		local k = f - i
		local a, b = line[i + 1], line[i + 2]
		return a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k, a[3] + (b[3] - a[3]) * k
	end
	local f = from
	while f < to do
		local g = min(to, floor(f) + 1)
		gl.Vertex(At(f))
		gl.Vertex(At(g))
		f = g
	end
end

function widget:DrawWorldPreUnit()
	if #groups == 0 or spectating then
		return
	end
	gl.DepthTest(false)
	local now = clock
	for g = 1, #groups do
		local group = groups[g]
		if not group.edges then
			group.edges = Edges(group)
		end
		local edges = group.edges
		local c = COLORS[group.color] or COLORS[1]
		local bright = selectedGroups[group]
		local alpha = bright and 1 or 0.45
		local core = bright and 3.5 or 2

		for e = 1, #edges do
			local line = edges[e]
			-- a dark edge under the colour, so it reads on any ground
			gl.LineWidth(core + 4)
			gl.Color(0, 0, 0, alpha * 0.45)
			gl.BeginEnd(GL.LINES, LineVertices, line)
			gl.LineWidth(core)
			gl.Color(c[1], c[2], c[3], alpha)
			gl.BeginEnd(GL.LINES, LineVertices, line)
			-- pulses running both ways: the queue is shared, not sent
			local size = min(0.5, 20 / line.length)
			local t = (now * 90 / line.length) % 1
			gl.LineWidth(core + 2)
			gl.Color(1, 1, 1, alpha * 0.9)
			gl.BeginEnd(GL.LINES, PulseVertices, line, t, size)
			gl.BeginEnd(GL.LINES, PulseVertices, line, 1 - t, size)
		end

		for p = 1, #edges.points do
			local point = edges.points[p]
			gl.LineWidth(core + 3)
			gl.Color(0, 0, 0, alpha * 0.35)
			gl.DrawGroundCircle(point.x, 0, point.z, point.r, 40)
			gl.LineWidth(core)
			gl.Color(c[1], c[2], c[3], alpha)
			gl.DrawGroundCircle(point.x, 0, point.z, point.r, 40)
		end
	end
	gl.LineWidth(1)
	gl.Color(1, 1, 1, 1)
end

--------------------------------------------------------------------------------
-- saving: the links outlive /luaui reload, within one game
--------------------------------------------------------------------------------

function widget:GetConfigData()
	local data = {
		sharedRally = TUNE.sharedRally, groups = {},
		-- what tells Restore that this is still the same game
		map = Game.mapName, frame = spGetGameFrame(), time = os.time(),
	}
	for g = 1, #groups do
		local group = groups[g]
		local saved = { members = {}, defs = {}, pool = {}, rep = group.rep, held = {} }
		for m = 1, #group.members do
			local unitID = group.members[m]
			saved.members[m] = unitID
			saved.defs[m] = spGetUnitDefID(unitID)
			local defs = {}
			for i, item in ipairs(held[unitID] or {}) do
				defs[i] = item.def
			end
			saved.held[m] = defs
		end
		for p = 1, #group.pool do
			saved.pool[p] = { def = group.pool[p].def, count = group.pool[p].count, once = group.pool[p].once }
		end
		data.groups[g] = saved
	end
	return data
end

function widget:SetConfigData(data)
	if type(data) == "table" then
		savedData = data
		if data.sharedRally ~= nil then
			TUNE.sharedRally = data.sharedRally and true or false
		end
	end
end

local function Restore(data)
	-- Only what was saved moments ago, in this game: the widget's data is also
	-- written when a game ends, and unit ids mean nothing in the next one.
	local frame = spGetGameFrame()
	if not data or not data.frame or data.frame <= 0 or frame < data.frame or data.map ~= Game.mapName
		or not data.time or math.abs(os.time() - data.time) > RESTORE_WINDOW then
		return
	end
	for _, saved in ipairs(data.groups or {}) do
		local group = NewGroup()
		group.rep = saved.rep and true or false
		for m, unitID in ipairs(saved.members or {}) do
			if IsMine(unitID) and FactoryInfo(unitID) and not groupOf[unitID]
				and spGetUnitDefID(unitID) == (saved.defs or {})[m] then
				group.members[#group.members + 1] = unitID
				groupOf[unitID] = group
				local h = {}
				for i, def in ipairs((saved.held or {})[m] or {}) do
					h[i] = { def = def, time = clock, frame = spGetGameFrame() }
				end
				held[unitID] = h
			end
		end
		for _, entry in ipairs(saved.pool or {}) do
			if UnitDefs[entry.def] then
				PoolAdd(group, entry.def, entry.count, false, entry.once)
			end
		end
		if #group.members < 2 then
			Dissolve(group)
		end
	end
end

--------------------------------------------------------------------------------

function widget:Initialize()
	Restore(savedData)
	savedData = nil

	WG.factoryLink = {
		-- links these factories (two or more, yours); true and the group's id if anything changed
		Link    = Link,
		Unlink  = Unlink,
		-- the id of the group a factory is in, or nil
		GroupOf = function(unitID) return groupOf[unitID] and groupOf[unitID].id or nil end,
		-- {id, members, rep, pool = {{def, count}...}, held = {[unitID] = {def...}}} for every group
		GetGroups = function()
			local list = {}
			for g = 1, #groups do
				local group = groups[g]
				local copy = { id = group.id, rep = group.rep, members = {}, pool = {}, held = {} }
				for m = 1, #group.members do
					local unitID = group.members[m]
					copy.members[m] = unitID
					local defs = {}
					for i, item in ipairs(held[unitID] or {}) do defs[i] = item.def end
					copy.held[unitID] = defs
				end
				for p = 1, #group.pool do
					copy.pool[p] = { def = group.pool[p].def, count = group.pool[p].count, once = group.pool[p].once }
				end
				list[g] = copy
			end
			return list
		end,
		-- the selection's shared queue, for the build menu (see above)
		SelectionPool = SelectionPool,
		Counts        = Counts,
		Remove        = Remove,
		-- adds to a factory's group as an order from the menu would
		Add = function(unitID, def, count, front)
			local group = groupOf[unitID]
			if group and GroupCan(group, def) then
				PoolAdd(group, def, count or 1, front, front)
				return true
			end
			return false
		end,
		SetRepeat = function(unitID, on)
			if groupOf[unitID] then groupOf[unitID].rep = on and true or false end
		end,
		GetSharedRally = function() return TUNE.sharedRally end,
		SetSharedRally = function(on) TUNE.sharedRally = on and true or false end,
		tune = TUNE,
	}
	Relayout()
end

function widget:Shutdown()
	WG.factoryLink = nil
	Relayout()
end
