--------------------------------------------------------------------------------
--
--  file:    s_spawner.lua  (Survival AI module)
--  brief:   Places wave units in a ring around the spawn point and marches them
--           at a weighted-random enemy target (buildings weigh more than
--           mobiles, so waves gravitate toward bases without being perfectly
--           predictable).
--
--           Engine access goes through an injected `env` table so the module
--           can be smoke-tested with a stubbed engine under plain lua5.1.
--           env = { GetTeamList, GetTeamInfo, AreTeamsAllied, GetTeamUnits,
--                   GetUnitDefID, GetUnitPosition, GetTeamStartPosition,
--                   GetGroundHeight, CreateUnit, GiveOrderToUnit,
--                   mapSizeX, mapSizeZ, CMD_FIGHT, gaiaID, random }
--
--------------------------------------------------------------------------------

local M = {}

local BUILDING_WEIGHT   = 4     -- buildings this many times likelier as targets
local MOBILE_WEIGHT     = 1
local SPAWN_RADIUS_MIN  = 120   -- elmos from the spawn point
local SPAWN_RADIUS_MAX  = 320
local SPAWN_ATTEMPTS    = 6     -- placement retries before giving up on a unit
local TARGET_SCATTER    = 180   -- per-unit scatter around the wave target
local EDGE_MARGIN       = 48    -- keep spawns off the literal map edge

local floor, cos, sin, pi = math.floor, math.cos, math.sin, math.pi

local function clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

--------------------------------------------------------------------------------
-- M.SelectTarget(env, survivalTeamID, isBuildingByDef) -> tx, tz | nil
--
-- Weighted random over every visible-to-synced enemy unit. Falls back to an
-- enemy start position if no enemy units exist (should not happen in play).
--------------------------------------------------------------------------------

function M.SelectTarget(env, survivalTeamID, isBuildingByDef)
	local candidates, weights, total = {}, {}, 0
	local fallbackX, fallbackZ

	for _, teamID in ipairs(env.GetTeamList()) do
		if teamID ~= env.gaiaID and teamID ~= survivalTeamID
			and not env.AreTeamsAllied(survivalTeamID, teamID) then

			local isDead = select(3, env.GetTeamInfo(teamID, false))
			if not isDead then
				if not fallbackX then
					local sx, _, sz = env.GetTeamStartPosition(teamID)
					if sx and sx > 0 then fallbackX, fallbackZ = sx, sz end
				end
				local units = env.GetTeamUnits(teamID)
				for i = 1, #units do
					local uid  = units[i]
					local udid = env.GetUnitDefID(uid)
					local w    = (udid and isBuildingByDef[udid]) and BUILDING_WEIGHT or MOBILE_WEIGHT
					local n = #candidates + 1
					candidates[n] = uid
					weights[n]    = w
					total         = total + w
				end
			end
		end
	end

	if total > 0 then
		local roll, acc = env.random() * total, 0
		for i = 1, #candidates do
			acc = acc + weights[i]
			if roll <= acc then
				local x, _, z = env.GetUnitPosition(candidates[i])
				if x then return x, z end
				break
			end
		end
	end

	return fallbackX, fallbackZ
end

--------------------------------------------------------------------------------
-- M.SpawnWave(env, teamID, sx, sz, unitList, tx, tz) -> createdUnitIDs
--
-- Ring placement with retry, then a FIGHT order toward a scattered point
-- around the wave target so the wave arrives as a loose front, not a conga.
--------------------------------------------------------------------------------

function M.SpawnWave(env, teamID, sx, sz, unitList, tx, tz)
	local created = {}
	local maxX = env.mapSizeX - EDGE_MARGIN
	local maxZ = env.mapSizeZ - EDGE_MARGIN

	for i = 1, #unitList do
		local entry = unitList[i]
		local uid

		for attempt = 1, SPAWN_ATTEMPTS do
			local ang = env.random() * 2 * pi
			local r   = SPAWN_RADIUS_MIN + env.random() * (SPAWN_RADIUS_MAX - SPAWN_RADIUS_MIN)
			-- widen the ring a little on retries so a crowded spot still resolves
			r = r + (attempt - 1) * 40
			local x = clamp(floor(sx + cos(ang) * r), EDGE_MARGIN, maxX)
			local z = clamp(floor(sz + sin(ang) * r), EDGE_MARGIN, maxZ)
			local y = env.GetGroundHeight(x, z)
			uid = env.CreateUnit(entry.name, x, y, z, 0, teamID)
			if uid then break end
		end

		if uid then
			created[#created + 1] = uid
			if tx then
				local ox = (env.random() * 2 - 1) * TARGET_SCATTER
				local oz = (env.random() * 2 - 1) * TARGET_SCATTER
				local fx = clamp(tx + ox, EDGE_MARGIN, maxX)
				local fz = clamp(tz + oz, EDGE_MARGIN, maxZ)
				env.GiveOrderToUnit(uid, env.CMD_FIGHT,
					{ fx, env.GetGroundHeight(fx, fz), fz }, 0)
			end
		end
	end

	return created
end

--------------------------------------------------------------------------------
-- M.SpawnDropWave(env, teamID, sx, sz, drop, tx, tz) -> group | nil
--
-- Spawns a ComposeDrop result: riders and carriers in the ring, load orders
-- queued per carrier (first order plain, the rest shifted), walkers marched at
-- the target immediately. Loading, transit dispatch and unload ordering are
-- the core gadget's job -- this only sets the stage.
--
-- group = {
--   carriers   = { unitID, ... },
--   passengers = { [unitID] = true },      -- riders awaiting pickup
--   byCarrier  = { [carrierID] = {pids} },
--   walkers    = { unitID, ... },
-- }
-- Requires env.CMD_LOAD and env.OPT_SHIFT in addition to the usual bridge.
--------------------------------------------------------------------------------

function M.SpawnDropWave(env, teamID, sx, sz, drop, tx, tz)
	local group = { carriers = {}, passengers = {}, byCarrier = {}, walkers = {} }

	-- Riders first (no orders yet: they wait for pickup)
	local groundIDs = {}
	for i = 1, #drop.ground do
		local ids = M.SpawnWave(env, teamID, sx, sz, { drop.ground[i] }, nil, nil)
		groundIDs[i] = ids[1]   -- nil if placement failed; tolerated below
	end

	-- Carriers, each with its load queue
	for p = 1, #drop.plan do
		local row = drop.plan[p]
		local ids = M.SpawnWave(env, teamID, sx, sz, { row.entry }, nil, nil)
		local cid = ids[1]
		if cid then
			group.carriers[#group.carriers + 1] = cid
			group.byCarrier[cid] = {}
			local first = true
			for _, gIdx in ipairs(row.passengers) do
				local pid = groundIDs[gIdx]
				if pid then
					group.passengers[pid] = true
					local list = group.byCarrier[cid]
					list[#list + 1] = pid
					env.GiveOrderToUnit(cid, env.CMD_LOAD, { pid },
						first and 0 or env.OPT_SHIFT)
					first = false
				end
			end
		else
			-- Carrier failed to place: its riders walk
			for _, gIdx in ipairs(row.passengers) do
				if groundIDs[gIdx] then
					drop.walkers[#drop.walkers + 1] = gIdx
				end
			end
		end
	end

	-- Walkers march now
	local walkerIDs = {}
	for i = 1, #drop.walkers do
		local pid = groundIDs[drop.walkers[i]]
		if pid then walkerIDs[#walkerIDs + 1] = pid end
	end
	if #walkerIDs > 0 and tx then
		M.OrderToTarget(env, walkerIDs, tx, tz)
	end
	group.walkers = walkerIDs

	return group
end

--------------------------------------------------------------------------------
-- M.OrderToTarget(env, unitIDs, tx, tz)
--
-- Re-march a set of (idle) wave units at a target. Used by the core gadget's
-- idle sweep so stragglers keep pressure on instead of napping mid-map.
--------------------------------------------------------------------------------

function M.OrderToTarget(env, unitIDs, tx, tz)
	local maxX = env.mapSizeX - EDGE_MARGIN
	local maxZ = env.mapSizeZ - EDGE_MARGIN
	for i = 1, #unitIDs do
		local ox = (env.random() * 2 - 1) * TARGET_SCATTER
		local oz = (env.random() * 2 - 1) * TARGET_SCATTER
		local fx = clamp(tx + ox, EDGE_MARGIN, maxX)
		local fz = clamp(tz + oz, EDGE_MARGIN, maxZ)
		env.GiveOrderToUnit(unitIDs[i], env.CMD_FIGHT,
			{ fx, env.GetGroundHeight(fx, fz), fz }, 0)
	end
end

return M
