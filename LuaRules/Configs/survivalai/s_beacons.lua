--------------------------------------------------------------------------------
--
--  file:    s_beacons.lua  (Survival AI module)
--  brief:   Beacon registry and creep logic. Beacons are the survival team's
--           physical presence (commander-class "beacon" units): waves spawn
--           from them, new ones creep toward the players at intervals, and
--           clearing all of them is the win condition (handled by the normal
--           commander-elimination flow).
--
--           Creep placement: pick a source beacon (usually the forward-most,
--           sometimes a random one so the network spreads), step 500-800 elmos
--           in a jittered cone toward the current wave target, and validate
--           the spot (bounds, spacing from own beacons, buildable ground, not
--           inside an enemy base).
--
--           Engine access is injected via `env` for lua5.1 smoke testing:
--           env = { random, mapSizeX, mapSizeZ,
--                   CanPlace(x, z) -> bool          [optional],
--                   EnemyNear(teamID, x, z, r) -> bool [optional] }
--
--------------------------------------------------------------------------------

local M = {}

local CREEP_MIN_DIST   = 500          -- elmos from the source beacon
local CREEP_MAX_DIST   = 800
local ANGLE_JITTER     = math.rad(75) -- cone half-angle around the target bearing
local SPREAD_CHANCE    = 0.35         -- chance to creep from a random (not forward) beacon
local MIN_SPACING      = 400          -- min distance between own beacons
local ENEMY_CLEARANCE  = 500          -- don't place with enemies this close
local PLACE_ATTEMPTS   = 12           -- attempts 7+ widen to a full circle
local EDGE_MARGIN      = 96

local sqrt, cos, sin, atan2, pi = math.sqrt, math.cos, math.sin, math.atan2, math.pi

local byTeam    = {}   -- [teamID] = { [unitID] = {x=, z=} }
local unitOwner = {}   -- [unitID] = teamID

local function clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

local function dist2(x1, z1, x2, z2)
	local dx, dz = x1 - x2, z1 - z2
	return dx * dx + dz * dz
end

--------------------------------------------------------------------------------
-- Registry
--------------------------------------------------------------------------------

function M.Reset()
	byTeam, unitOwner = {}, {}
end

function M.Register(teamID, unitID, x, z)
	local t = byTeam[teamID]
	if not t then t = {} ; byTeam[teamID] = t end
	t[unitID] = { x = x, z = z }
	unitOwner[unitID] = teamID
end

-- Returns the owning teamID (or nil if the unit wasn't a tracked beacon).
function M.Remove(unitID)
	local teamID = unitOwner[unitID]
	if not teamID then return nil end
	unitOwner[unitID] = nil
	local t = byTeam[teamID]
	if t then t[unitID] = nil end
	return teamID
end

function M.Count(teamID)
	local t = byTeam[teamID]
	if not t then return 0 end
	local n = 0
	for _ in pairs(t) do n = n + 1 end
	return n
end

function M.GetAll(teamID)
	local list, t = {}, byTeam[teamID]
	if t then
		for unitID, pos in pairs(t) do
			list[#list + 1] = { unitID = unitID, x = pos.x, z = pos.z }
		end
	end
	return list
end

--------------------------------------------------------------------------------
-- Creep placement
--------------------------------------------------------------------------------

local function ForwardMost(list, tx, tz)
	local best, bestD = nil, math.huge
	for i = 1, #list do
		local d = dist2(list[i].x, list[i].z, tx, tz)
		if d < bestD then bestD = d ; best = list[i] end
	end
	return best
end

-- M.PickCreepSpot(env, teamID, tx, tz, minDist, maxDist) -> x, z | nil
-- minDist/maxDist override the leash (elmos from the source beacon); omitted,
-- the CREEP_*_DIST defaults below apply.
function M.PickCreepSpot(env, teamID, tx, tz, minDist, maxDist)
	minDist = minDist or CREEP_MIN_DIST
	maxDist = maxDist or CREEP_MAX_DIST
	local list = M.GetAll(teamID)
	if #list == 0 then return nil end
	if not tx then tx, tz = env.mapSizeX * 0.5, env.mapSizeZ * 0.5 end

	-- Source: forward-most beacon, with a spread chance to grow sideways
	local src
	if #list > 1 and env.random() < SPREAD_CHANCE then
		src = list[env.random(1, #list)]
	else
		src = ForwardMost(list, tx, tz)
	end

	local bearing = atan2(tz - src.z, tx - src.x)
	local maxX = env.mapSizeX - EDGE_MARGIN
	local maxZ = env.mapSizeZ - EDGE_MARGIN

	for attempt = 1, PLACE_ATTEMPTS do
		-- If the forward cone keeps failing (cliff, water, enemy base), open up
		-- to a full circle so the network can route around obstacles.
		local jitter = (attempt <= PLACE_ATTEMPTS / 2) and ANGLE_JITTER or pi
		local ang    = bearing + (env.random() * 2 - 1) * jitter
		local d      = minDist + env.random() * (maxDist - minDist)
		local x      = clamp(src.x + cos(ang) * d, EDGE_MARGIN, maxX)
		local z      = clamp(src.z + sin(ang) * d, EDGE_MARGIN, maxZ)

		local ok = true

		for i = 1, #list do
			if dist2(x, z, list[i].x, list[i].z) < MIN_SPACING * MIN_SPACING then
				ok = false
				break
			end
		end

		if ok and env.CanPlace and not env.CanPlace(x, z) then ok = false end
		if ok and env.EnemyNear and env.EnemyNear(teamID, x, z, ENEMY_CLEARANCE) then ok = false end

		if ok then return x, z end
	end

	return nil   -- crowded map; try again next cycle
end

--------------------------------------------------------------------------------
-- Wave splitting
--
-- M.SplitWave(teamID, unitList, tx, tz, random) -> { {x=, z=, list={}}, ... }
--
-- Units are assigned to beacons with weight falling off by distance to the
-- target, so forward beacons carry most of the wave -- captured territory is
-- what hurts you -- while rear beacons still contribute a trickle.
--------------------------------------------------------------------------------

function M.SplitWave(teamID, unitList, tx, tz, random)
	local beacons = M.GetAll(teamID)
	if #beacons == 0 then return {} end

	local weights, total = {}, 0
	for i = 1, #beacons do
		local d = sqrt(dist2(beacons[i].x, beacons[i].z, tx or beacons[i].x, tz or beacons[i].z))
		local w = 1 / (1 + (d / 800) ^ 2)
		weights[i] = w
		total = total + w
	end

	local groups = {}
	for u = 1, #unitList do
		local roll, acc, pick = random() * total, 0, #beacons
		for i = 1, #beacons do
			acc = acc + weights[i]
			if roll <= acc then pick = i break end
		end
		local g = groups[pick]
		if not g then
			g = { x = beacons[pick].x, z = beacons[pick].z, list = {} }
			groups[pick] = g
		end
		g.list[#g.list + 1] = unitList[u]
	end

	-- Compact to an array
	local out = {}
	for _, g in pairs(groups) do out[#out + 1] = g end
	return out
end

return M
