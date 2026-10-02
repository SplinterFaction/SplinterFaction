--------------------------------------------------------------------------------
--
--  file:    s_beacons.lua  (Survival AI module)
--  brief:   Beacon registry and creep logic. Beacons are the survival team's
--           physical presence (commander-class "beacon" units): waves spawn
--           from them, lost ones are replaced by creeping toward the players, and
--           clearing all of them is the win condition (handled by the normal
--           commander-elimination flow).
--
--           The network is seeded around the master beacon at the start
--           (PickSeedSpot: home territory, any direction), and regrows one
--           beacon at a time through the creep logic when it has lost some.
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
local PLACE_ATTEMPTS   = 24           -- cone for the first third, then full circle
local SEED_ATTEMPTS    = 60           -- per starting beacon
local STAGE_SWAP_CHANCE = 0.35        -- chance the last staging slot goes to the next-nearest beacon
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

-- garrisonTier: 0 = no garrison yet. Pass the current tier when re-registering
-- beacons after a luarules reload so they are not fortified a second time.
function M.Register(teamID, unitID, x, z, kind, frame, garrisonTier)
	local t = byTeam[teamID]
	if not t then t = {} ; byTeam[teamID] = t end
	t[unitID] = { x = x, z = z, kind = kind or "standard", birth = frame or 0,
	              garrisonTier = garrisonTier or 0, turrets = {}, shieldID = nil }
	unitOwner[unitID] = teamID
end

local function Lookup(unitID)
	local teamID = unitOwner[unitID]
	local t = teamID and byTeam[teamID]
	return t and t[unitID]
end

-- Position of a tracked beacon, or nil.
function M.GetPos(unitID)
	local b = Lookup(unitID)
	if b then return b.x, b.z end
	return nil
end

-- Kind of a tracked beacon ("standard", "shield", "jammer", "accelerator",
-- "forge"), or nil for untracked units.
function M.GetKind(unitID)
	local teamID = unitOwner[unitID]
	local t = teamID and byTeam[teamID]
	local b = t and t[unitID]
	return b and b.kind
end

function M.CountKind(teamID, kind)
	local t = byTeam[teamID]
	if not t then return 0 end
	local n = 0
	for _, b in pairs(t) do
		if b.kind == kind then n = n + 1 end
	end
	return n
end

--------------------------------------------------------------------------------
-- Garrisons. A beacon holds a list of turret unitIDs at a given tier, plus at
-- most one shield generator. The core gadget creates and destroys the units;
-- this only remembers them so a tier upgrade can replace the right ones.
--------------------------------------------------------------------------------

-- M.GetGarrison(unitID) -> tier, turretIDs, shieldID   (nil for untracked)
function M.GetGarrison(unitID)
	local b = Lookup(unitID)
	if not b then return nil end
	return b.garrisonTier, b.turrets, b.shieldID
end

function M.SetGarrison(unitID, tier, turretIDs, shieldID)
	local b = Lookup(unitID)
	if not b then return end
	b.garrisonTier = tier
	b.turrets      = turretIDs or {}
	b.shieldID     = shieldID
end

-- One garrisoned beacon still below `tier`, oldest first (so upgrades roll
-- through the network in a stable order), or nil when none are left.
function M.NextUpgrade(teamID, tier)
	local t = byTeam[teamID]
	if not t then return nil end
	local best, bestID = nil, nil
	for unitID, b in pairs(t) do
		if b.garrisonTier > 0 and b.garrisonTier < tier then
			if (not best) or b.birth < best.birth
				or (b.birth == best.birth and unitID < bestID) then
				best, bestID = b, unitID
			end
		end
	end
	if best then return bestID, best.x, best.z end
	return nil
end

-- The sole survivor (unitID, x, z) when exactly one beacon remains.
function M.GetLast(teamID)
	local t = byTeam[teamID]
	if not t then return nil end
	local only, count = nil, 0
	for unitID, b in pairs(t) do
		only  = { unitID = unitID, x = b.x, z = b.z }
		count = count + 1
		if count > 1 then return nil end
	end
	return only and only.unitID, only and only.x, only and only.z
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
			list[#list + 1] = { unitID = unitID, x = pos.x, z = pos.z, kind = pos.kind }
		end
	end
	-- pairs() order is not stable across clients; everything downstream makes
	-- synced random picks from this list, so give it a deterministic order.
	table.sort(list, function(a, b) return a.unitID < b.unitID end)
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

--------------------------------------------------------------------------------
-- M.PickSeedSpot(env, teamID, cx, cz, homeRadius, minDist, maxDist) -> x, z | nil
--
-- A spot for one of the starting beacons. Unlike creep there is no bearing:
-- the network grows as a cluster, stepping minDist..maxDist in any direction
-- from a random existing beacon, and never leaves the home circle around the
-- master at (cx, cz). Same validation as creep otherwise.
--------------------------------------------------------------------------------

function M.PickSeedSpot(env, teamID, cx, cz, homeRadius, minDist, maxDist)
	local list = M.GetAll(teamID)
	if #list == 0 then return nil end

	local maxX = env.mapSizeX - EDGE_MARGIN
	local maxZ = env.mapSizeZ - EDGE_MARGIN
	local home2 = homeRadius * homeRadius

	for attempt = 1, SEED_ATTEMPTS do
		local src = list[env.random(1, #list)]
		local ang = env.random() * 2 * pi
		local d   = minDist + env.random() * (maxDist - minDist)
		local x   = clamp(src.x + cos(ang) * d, EDGE_MARGIN, maxX)
		local z   = clamp(src.z + sin(ang) * d, EDGE_MARGIN, maxZ)

		local ok = dist2(x, z, cx, cz) <= home2

		if ok then
			for i = 1, #list do
				if dist2(x, z, list[i].x, list[i].z) < MIN_SPACING * MIN_SPACING then
					ok = false
					break
				end
			end
		end

		if ok and env.CanPlace and not env.CanPlace(x, z) then ok = false end
		if ok and env.EnemyNear and env.EnemyNear(teamID, x, z, ENEMY_CLEARANCE) then ok = false end

		if ok then return x, z end
	end

	return nil
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
		local jitter = (attempt <= PLACE_ATTEMPTS / 3) and ANGLE_JITTER or pi
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
-- Staging
--
-- M.PickStaging(teamID, tx, tz, count, random) -> { {unitID, x, z, kind}, ... }
--
-- The beacons that launch a wave: the `count` nearest the target ("all" = the
-- whole network), nearest first. With `random`, the last slot sometimes goes
-- to the next-nearest beacon instead, so the same beacons are not the answer
-- every single wave. Pass random = nil for a strict nearest-N.
--------------------------------------------------------------------------------

function M.PickStaging(teamID, tx, tz, count, random)
	local beacons = M.GetAll(teamID)
	if #beacons == 0 then return {} end

	for i = 1, #beacons do
		local b = beacons[i]
		b.d2 = dist2(b.x, b.z, tx or b.x, tz or b.z)
	end
	table.sort(beacons, function(a, b)
		if a.d2 ~= b.d2 then return a.d2 < b.d2 end
		return a.unitID < b.unitID
	end)

	if count == "all" or count >= #beacons then return beacons end
	if count < 1 then count = 1 end

	if random and random() < STAGE_SWAP_CHANCE then
		beacons[count], beacons[count + 1] = beacons[count + 1], beacons[count]
	end

	local out = {}
	for i = 1, count do out[i] = beacons[i] end
	return out
end

--------------------------------------------------------------------------------
-- M.SplitAmong(staging, unitList, even) -> { {x=, z=, beaconID=, kind=, list={}}, ... }
--
-- Deals a composed wave out to its staging beacons. By default the nearest
-- beacon carries the most (weights 1, 1/2, 1/3, ... down the list); `even`
-- gives every beacon an equal share (raids, surges). Units go one at a time to
-- whichever beacon is furthest below its share, so the split is exact and
-- deterministic, and no beacon is left empty while there are units to give.
--------------------------------------------------------------------------------

function M.SplitAmong(staging, unitList, even)
	local n = #staging
	if n == 0 then return {} end

	local weights, total = {}, 0
	for i = 1, n do
		weights[i] = even and 1 or (1 / i)
		total = total + weights[i]
	end

	local groups, given = {}, {}
	for i = 1, n do
		groups[i] = { x = staging[i].x, z = staging[i].z,
		              beaconID = staging[i].unitID, kind = staging[i].kind,
		              list = {} }
		given[i] = 0
	end

	for u = 1, #unitList do
		local pick, bestDeficit = 1, -math.huge
		for i = 1, n do
			local deficit = weights[i] / total * u - given[i]
			if deficit > bestDeficit then bestDeficit = deficit ; pick = i end
		end
		given[pick] = given[pick] + 1
		local list = groups[pick].list
		list[#list + 1] = unitList[u]
	end

	-- Drop beacons that got nothing (more beacons than units)
	local out = {}
	for i = 1, n do
		if #groups[i].list > 0 then out[#out + 1] = groups[i] end
	end
	return out
end

return M
