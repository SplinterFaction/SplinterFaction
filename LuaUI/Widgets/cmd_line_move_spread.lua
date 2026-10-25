function widget:GetInfo()
	return {
		name      = "Line Move Spread",
		desc      = "Spreads a single-point move order for a group into a short line abreast, facing the direction of travel",
		author    = "Scary le Poo",
		date      = "2026-10-24",
		license   = "GNU GPL, v2 or later",
		layer     = -5,
		enabled   = true,
	}
end

--------------------------------------------------------------------------------
-- Tuning
--------------------------------------------------------------------------------

local MIN_UNITS        = 2      -- do nothing for a single unit
local MAX_PER_RANK     = 8      -- more units than this wrap into a second rank behind the first
local MAX_RANK_WIDTH   = 520    -- elmos; hard cap on how wide a rank may get
local SPACING_MULT     = 1.7    -- gap between neighbors = largest radius in the rank * this
local MIN_SPACING      = 28     -- elmos
local RANK_DEPTH_MULT  = 2.0    -- distance between ranks = largest radius in the group * this
local MIN_RANK_DEPTH   = 40     -- elmos

-- Commands that get spread. Attack/patrol are left alone on purpose.
local HANDLED = {
	[CMD.MOVE]  = true,
	[CMD.FIGHT] = true,
}

--------------------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------------------

local spGetSelectedUnits  = Spring.GetSelectedUnits
local spGetUnitPosition   = Spring.GetUnitPosition
local spGetUnitDefID      = Spring.GetUnitDefID
local spGetUnitRadius     = Spring.GetUnitRadius
local spGetUnitCommands   = Spring.GetUnitCommands
local spGetGroundHeight   = Spring.GetGroundHeight
local spGiveOrderToUnit   = Spring.GiveOrderToUnit

local mapSizeX = Game.mapSizeX
local mapSizeZ = Game.mapSizeZ

local sqrt, floor, ceil, max, min = math.sqrt, math.floor, math.ceil, math.max, math.min

-- Immobile defs (factories, turrets) just receive the original point.
local immobileDef = {}
for udid, ud in pairs(UnitDefs) do
	if ud.isFactory or (ud.speed or 0) <= 0 then
		immobileDef[udid] = true
	end
end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

-- Where the unit will be when this order starts: its current position, or the
-- last queued waypoint when the order is being shift-queued.
local function GetStartPosition(unitID, queued)
	if queued then
		local cmds = spGetUnitCommands(unitID, -1)
		if cmds then
			for i = #cmds, 1, -1 do
				local p = cmds[i].params
				if p and #p >= 3 then
					return p[1], p[3]
				end
			end
		end
	end
	local x, _, z = spGetUnitPosition(unitID)
	return x, z
end

local function Clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

--------------------------------------------------------------------------------
-- Command handling
--------------------------------------------------------------------------------

function widget:CommandNotify(cmdID, cmdParams, cmdOptions)
	if not HANDLED[cmdID] then return false end
	if not cmdParams or #cmdParams < 3 then return false end -- unit target, not a point

	local selected = spGetSelectedUnits()
	if #selected < MIN_UNITS then return false end

	local tx, tz = cmdParams[1], cmdParams[3]
	local queued = cmdOptions.shift and true or false

	-- Split the selection into movers (spread) and immobiles (pass-through).
	local movers, immobiles = {}, {}
	local cx, cz = 0, 0
	for i = 1, #selected do
		local unitID = selected[i]
		local udid = spGetUnitDefID(unitID)
		if udid and immobileDef[udid] then
			immobiles[#immobiles + 1] = unitID
		else
			local x, z = GetStartPosition(unitID, queued)
			if x then
				local r = spGetUnitRadius(unitID) or 16
				movers[#movers + 1] = { id = unitID, x = x, z = z, r = r }
				cx, cz = cx + x, cz + z
			end
		end
	end

	local n = #movers
	if n < MIN_UNITS then return false end

	-- Direction of travel from the group's centroid to the ordered point.
	cx, cz = cx / n, cz / n
	local dx, dz = tx - cx, tz - cz
	local len = sqrt(dx * dx + dz * dz)
	if len < 1 then return false end -- ordered onto themselves; let the engine sort it out
	dx, dz = dx / len, dz / len
	local px, pz = -dz, dx -- perpendicular, the line's axis

	-- Project each mover onto the travel and lateral axes relative to the centroid.
	local maxR = 0
	for i = 1, n do
		local m = movers[i]
		local ox, oz = m.x - cx, m.z - cz
		m.fwd = ox * dx + oz * dz
		m.lat = ox * px + oz * pz
		if m.r > maxR then maxR = m.r end
	end

	-- Units nearest the destination take the front rank, so nobody has to cross.
	table.sort(movers, function(a, b) return a.fwd > b.fwd end)

	local rankCount = ceil(n / MAX_PER_RANK)
	local perRank   = ceil(n / rankCount) -- even out the ranks rather than leaving a straggler
	local rankDepth = max(MIN_RANK_DEPTH, maxR * RANK_DEPTH_MULT)

	local idx = 1
	for rank = 0, rankCount - 1 do
		local members = {}
		local rankMaxR = 0
		for _ = 1, perRank do
			local m = movers[idx]
			if not m then break end
			members[#members + 1] = m
			if m.r > rankMaxR then rankMaxR = m.r end
			idx = idx + 1
		end
		local mCount = #members
		if mCount == 0 then break end

		-- Keep left units on the left within the rank.
		table.sort(members, function(a, b) return a.lat < b.lat end)

		local spacing = max(MIN_SPACING, rankMaxR * SPACING_MULT)
		if mCount > 1 then
			spacing = min(spacing, MAX_RANK_WIDTH / (mCount - 1))
		end

		local backX = -dx * rank * rankDepth
		local backZ = -dz * rank * rankDepth
		local half  = (mCount - 1) * 0.5

		for j = 1, mCount do
			local off = (j - 1 - half) * spacing
			local x = Clamp(tx + px * off + backX, 8, mapSizeX - 8)
			local z = Clamp(tz + pz * off + backZ, 8, mapSizeZ - 8)
			local y = spGetGroundHeight(x, z)
			spGiveOrderToUnit(members[j].id, cmdID, { x, y, z }, cmdOptions.coded)
		end
	end

	for i = 1, #immobiles do
		spGiveOrderToUnit(immobiles[i], cmdID, cmdParams, cmdOptions.coded)
	end

	return true -- consumed; the engine's own group order is not issued
end
