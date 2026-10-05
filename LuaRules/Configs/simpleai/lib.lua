--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    luarules/configs/simpleai/lib.lua
--  brief:   Stateless helper library for the SimpleAI gadget (stage 2 of the
--           modular split). Every function here is a QUERY: it may read ctx
--           and call Spring, but it never mutates ctx and never registers
--           callins. Behavior modules and the core both call through this.
--
--  usage:   local lib = VFS.Include("luarules/configs/simpleai/lib.lua")(ctx, cfg)
--           cfg carries the map/game constants listed below; ctx is the shared
--           AI context owned by the core gadget.
--
--  license: GNU GPL, v2 or later
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return function(ctx, cfg)

	local L = {}

	-- config constants (owned by the core, passed in)
	local mapsizeX           = cfg.mapsizeX
	local mapsizeZ           = cfg.mapsizeZ
	local gaiaTeamID         = cfg.gaiaTeamID
	local ATTACK_SCAN_R      = cfg.ATTACK_SCAN_R
	local ATTACK_DIST_W      = cfg.ATTACK_DIST_W
	local COMBAT_ROLE_WEIGHT = cfg.COMBAT_ROLE_WEIGHT

	-- shared state (read-only from here)
	local ShieldMax          = ctx.ShieldMax
	local IsTurret           = ctx.IsTurret
	local TeamTechLevel      = ctx.techLevel
	local TeamBuildLists     = ctx.buildLists
	local SimpleMusterPos    = ctx.squad.muster
	local SimpleEnemyBasePos = ctx.intel.enemyBase

	-- Effective hp ratio in [0,1]: hull + personal shield over the combined pool.
	-- For unshielded (Fed) units this is plain hull fraction.
	function L.EffectiveRatio(unitID, unitDefID, hp, maxhp)
		local smax = ShieldMax[unitDefID]
		if smax then
			local s = Spring.GetUnitRulesParam(unitID, "personalShield") or 0
			return (hp + s) / (maxhp + smax)
		end
		return hp / maxhp
	end

	-- ============================================================
	-- GET BUILDABLE LIST
	-- Returns all defIDs in a category available at or below
	-- the team's current tech level.
	-- ============================================================
	function L.GetBuildable(teamID, cat)
		local techLevel = TeamTechLevel[teamID] or 1
		local result    = {}
		local lists     = TeamBuildLists[teamID]
		if not lists then return result end
		for t = 0, techLevel do
			local bucket = lists[t] and lists[t][cat]
			if bucket then
				for _, id in ipairs(bucket) do
					result[#result + 1] = id
				end
			end
		end
		return result
	end

	-- ============================================================
	-- GET BUILDABLE LIST (TECH-WEIGHTED)
	-- Like GetBuildable, but repeats higher-tech defIDs more often so the
	-- downstream shuffle-and-pick favours advanced units/factories while
	-- still occasionally choosing cheaper lower-tier options.
	-- biasPow controls the skew: weight per unit = (techTier + 1) ^ biasPow.
	-- ============================================================
	function L.GetBuildableTechBiased(teamID, cat, biasPow)
		local techLevel = TeamTechLevel[teamID] or 1
		local result    = {}
		local lists     = TeamBuildLists[teamID]
		if not lists then return result end
		biasPow = biasPow or 1.8
		for t = 0, techLevel do
			local bucket = lists[t] and lists[t][cat]
			if bucket and #bucket > 0 then
				local weight = math.max(1, math.floor((t + 1) ^ biasPow + 0.5))
				for _, id in ipairs(bucket) do
					for _ = 1, weight do
						result[#result + 1] = id
					end
				end
			end
		end
		return result
	end

	-- ============================================================
	-- COMBAT ROLE WEIGHT
	-- Looks up a unit's build-menu category and returns the composition weight
	-- (skirmishers high, support/scout/utility lower). Used to skew which combat
	-- units the factories produce without ever fully excluding a role.
	-- ============================================================
	-- "heat" if every weapon on the def is a heat weapon, "disrupt" if every
	-- one is a disruption weapon, false otherwise (any direct-damage weapon,
	-- or a mix, makes it an ordinary combat unit). Cached per def.
	local nonDirect = {}
	local function NonDirectClass(defID)
		local c = nonDirect[defID]
		if c ~= nil then return c end
		c = false
		local ud = UnitDefs[defID]
		local weapons = ud and ud.weapons
		if weapons and #weapons > 0 then
			local heat, disrupt = 0, 0
			for i = 1, #weapons do
				local wd  = WeaponDefs[weapons[i].weaponDef]
				local wcp = wd and (wd.customParams or wd.customparams)
				local h   = wcp and wcp.heatweapon
				local d   = wcp and wcp.disruptionweapon
				if h and h ~= "0" and h ~= "false" then heat = heat + 1
				elseif d and d ~= "0" and d ~= "false" then disrupt = disrupt + 1 end
			end
			if heat == #weapons then c = "heat"
			elseif disrupt == #weapons then c = "disrupt" end
		end
		nonDirect[defID] = c
		return c
	end
	L.NonDirectClass = NonDirectClass

	function L.CombatRoleWeight(defID)
		local ud  = UnitDefs[defID]
		local cat = ud and ud.customParams and ud.customParams.buildmenucategory
		local w   = COMBAT_ROLE_WEIGHT[cat] or COMBAT_ROLE_WEIGHT.default
		-- No direct damage: capped, whatever the build menu calls it (see
		-- COMBAT_ROLE_WEIGHT.HeatOnly / DisruptOnly in the core).
		local class = NonDirectClass(defID)
		local cap = (class == "heat" and COMBAT_ROLE_WEIGHT.HeatOnly)
				or (class == "disrupt" and COMBAT_ROLE_WEIGHT.DisruptOnly)
		if cap and w > cap then w = cap end
		return w
	end

	-- ============================================================
	-- GET WEIGHTED BUILDABLE  ->  { {id=defID, w=weight}, ... }
	-- Combines tech weight (advanced tiers favoured) with an optional per-unit
	-- weight function (e.g. combat role). Returns weighted pairs for a weighted
	-- random pick, so we get composition control without duplicating list entries.
	-- ============================================================
	function L.GetWeightedBuildable(teamID, cat, biasPow, weightFn)
		local techLevel = TeamTechLevel[teamID] or 1
		local out       = {}
		local lists     = TeamBuildLists[teamID]
		if not lists then return out end
		biasPow = biasPow or 1.8
		for t = 0, techLevel do
			local bucket = lists[t] and lists[t][cat]
			if bucket then
				local techW = (t + 1) ^ biasPow
				for _, id in ipairs(bucket) do
					local w = techW
					if weightFn then w = w * weightFn(id) end
					if w > 0 then
						out[#out + 1] = { id = id, w = w }
					end
				end
			end
		end
		return out
	end

	function L.GetClosestMexSpot(x, z, maxRange)
		local bestSpot
		local bestDist  = maxRange and (maxRange * maxRange) or math.huge
		local metalSpots = GG.metalMakerSpots
		if metalSpots then
			for i = 1, #metalSpots do
				local spot = metalSpots[i]
				local dx, dz = x - spot.x, z - spot.z
				local dist = dx * dx + dz * dz
				local units = Spring.GetUnitsInCylinder(spot.x, spot.z, 128)
				if dist < bestDist and #units == 0 then
					bestSpot = spot
					bestDist = dist
				end
			end
		end
		return bestSpot
	end

	function L.EstimateEnemyBase(teamID)
		local allUnits = Spring.GetAllUnits()
		local ex, ez, count = 0, 0, 0
		for i = 1, #allUnits do
			local uid    = allUnits[i]
			local uteam  = Spring.GetUnitTeam(uid)
			-- Allies and gaia are NOT enemies: without this guard the "enemy base"
			-- centroid gets dragged toward allied bases in team games, and builder
			-- reclaim roams (which aim at this point) wander into friendly territory.
			if uteam ~= teamID and uteam ~= gaiaTeamID
					and not Spring.AreTeamsAllied(teamID, uteam) then
				local uDefID = Spring.GetUnitDefID(uid)
				if uDefID and UnitDefs[uDefID] and UnitDefs[uDefID].isBuilding then
					local ux, _, uz = Spring.GetUnitPosition(uid)
					ex = ex + ux
					ez = ez + uz
					count = count + 1
				end
			end
		end
		if count > 0 then
			local cx, cz = ex / count, ez / count
			return { x = cx, z = cz, y = Spring.GetGroundHeight(cx, cz) }
		end
		return nil
	end

	-- Compute a muster (staging) position for ground forces.
	-- We pick a spot 600-900 units in front of the team's base,
	-- angled toward the map centre so units don't stage in a wall.
	function L.ComputeMusterPos(teamID)
		local units = Spring.GetTeamUnits(teamID)
		-- Find centroid of friendly buildings as "base centre"
		local bx, bz, bcount = 0, 0, 0
		for i = 1, #units do
			local uid    = units[i]
			local uDefID = Spring.GetUnitDefID(uid)
			if uDefID and UnitDefs[uDefID] and UnitDefs[uDefID].isBuilding then
				local ux, _, uz = Spring.GetUnitPosition(uid)
				bx = bx + ux
				bz = bz + uz
				bcount = bcount + 1
			end
		end
		if bcount == 0 then return nil end
		bx = bx / bcount
		bz = bz / bcount

		-- Direction from base toward map centre
		local cx, cz = mapsizeX / 2, mapsizeZ / 2
		local dx, dz = cx - bx, cz - bz
		local len = math.sqrt(dx * dx + dz * dz)
		if len < 1 then return nil end
		dx, dz = dx / len, dz / len

		-- Stage 700 units out from the base centroid toward the centre
		local stageDist = 700
		local mx = bx + dx * stageDist
		local mz = bz + dz * stageDist
		mx = math.max(256, math.min(mapsizeX - 256, mx))
		mz = math.max(256, math.min(mapsizeZ - 256, mz))
		return { x = mx, z = mz, y = Spring.GetGroundHeight(mx, mz) }
	end

	-- ============================================================
	-- COMMANDER HAVEN SELECTION
	-- Deterministically picks ONE safe spot to flee to: a friendly building
	-- that is far from the threat but not absurdly far from the commander,
	-- with a strong bonus for turret cover. No randomness, so repeated calls
	-- return a stable destination (prevents retreat-order thrashing).
	-- ============================================================
	function L.FindCommanderHaven(unitID, teamID, enemyID)
		local ux, uy, uz = Spring.GetUnitPosition(unitID)
		local ex, ez
		if enemyID then
			local x, _, z = Spring.GetUnitPosition(enemyID)
			ex, ez = x, z
		end

		local teamUnits = Spring.GetTeamUnits(teamID)
		local best, bestScore
		for i = 1, #teamUnits do
			local cand = teamUnits[i]
			if cand ~= unitID then
				local cDefID = Spring.GetUnitDefID(cand)
				if cDefID and UnitDefs[cDefID] and UnitDefs[cDefID].isBuilding then
					local bx, by, bz = Spring.GetUnitPosition(cand)
					local cdx, cdz = bx - ux, bz - uz
					local distComm = math.sqrt(cdx * cdx + cdz * cdz)
					local distEnemy = 100000
					if ex then
						local edx, edz = bx - ex, bz - ez
						distEnemy = math.sqrt(edx * edx + edz * edz)
					end
					-- Want: far from enemy, close-ish to commander, prefer turret cover
					local score = distEnemy - distComm * 0.5
					if IsTurret[cDefID] then score = score + 1000 end
					if not bestScore or score > bestScore then
						bestScore = score
						best = { x = bx, y = by, z = bz }
					end
				end
			end
		end

		if best then return best end

		-- No buildings left: flee directly away from the enemy.
		if ex then
			local fx = ux + (ux - ex)
			local fz = uz + (uz - ez)
			fx = math.max(256, math.min(mapsizeX - 256, fx))
			fz = math.max(256, math.min(mapsizeZ - 256, fz))
			return { x = fx, y = Spring.GetGroundHeight(fx, fz), z = fz }
		end
		return nil
	end

	-- ============================================================
	-- WEAK-POINT ATTACK TARGETING
	-- Scans all enemy structures and tallies the defensive strength near each
	-- (combat units + armed turrets within ATTACK_SCAN_R, weighted by their HP).
	-- Returns the lowest-defended structure, lightly penalised by distance from
	-- our muster so we don't trek across the map for a marginally softer target.
	-- ============================================================
	function L.FindWeakestEnemyTarget(teamID)
		local allUnits = Spring.GetAllUnits()
		local enemyBuildings = {}
		local threats = {}

		for i = 1, #allUnits do
			local uid = allUnits[i]
			local ut  = Spring.GetUnitTeam(uid)
			if ut ~= teamID and ut ~= gaiaTeamID then
				local allied = Spring.AreTeamsAllied(teamID, ut)
				if not allied then   -- nil (unallied) or false both count as enemy
					local dID = Spring.GetUnitDefID(uid)
					local ud  = dID and UnitDefs[dID]
					if ud then
						local x, _, z = Spring.GetUnitPosition(uid)
						if ud.isBuilding then
							enemyBuildings[#enemyBuildings + 1] = { x = x, z = z }
						end
						if ud.weapons and #ud.weapons > 0 then
							local _, maxHP = Spring.GetUnitHealth(uid)
							threats[#threats + 1] = { x = x, z = z, w = (maxHP or 100) }
						end
					end
				end
			end
		end

		if #enemyBuildings == 0 then return nil end

		local origin = SimpleMusterPos[teamID] or SimpleEnemyBasePos[teamID]
		local scanR2 = ATTACK_SCAN_R * ATTACK_SCAN_R

		local best, bestScore
		for _, b in ipairs(enemyBuildings) do
			local defense = 0
			for _, t in ipairs(threats) do
				local dx, dz = t.x - b.x, t.z - b.z
				if dx * dx + dz * dz < scanR2 then
					defense = defense + t.w
				end
			end
			local distPen = 0
			if origin then
				local dx, dz = b.x - origin.x, b.z - origin.z
				distPen = math.sqrt(dx * dx + dz * dz) * ATTACK_DIST_W
			end
			local score = defense + distPen
			if not bestScore or score < bestScore then
				bestScore = score
				best = b
			end
		end

		if best then
			return { x = best.x, z = best.z, y = Spring.GetGroundHeight(best.x, best.z) }
		end
		return nil
	end

	-- Why the most recent BuildOrder call did or did not find a site. Reset on
	-- every call; read by the construction behavior for its diagnostics.
	--   sites    = candidate positions tested
	--   blocked  = engine said blocked (terrain, slope, a building, map edge)
	--   occupied = a mobile unit was standing on the site
	--   crowded  = site was buildable but too close to another structure
	--              (would close a lane or a factory's surroundings)
	--   noAnchor = search rings that held no friendly unit to build next to
	L.placeStats = { sites = 0, blocked = 0, occupied = 0, crowded = 0, noAnchor = 0 }

	-- Base layout rules. The AI used to drop each building right beside
	-- another with a small random gap and only checked a little box around
	-- the new building's CENTER, so big buildings ended up touching and whole
	-- armies were walled in behind rows of supply depots. Now every site must
	-- leave a real lane to every other structure, measured edge to edge, and
	-- a wider apron around factories so their output can get out.
	local LANE          = 112   -- min gap between any two structures (elmos)
	local FACTORY_APRON = 256   -- min gap between a factory and anything else
	local GAP_JITTER    = 96    -- extra random gap so bases do not form a perfect grid
	local QUERY_PAD     = 420   -- how far past a site to look for neighbors (largest half-footprint + apron)
	local PENDING_FOR   = 1800  -- frames an ordered-but-unstarted site keeps its claim (~60s)
	local PENDING_MAX   = 32

	-- Sites ordered recently that may not have a nanoframe yet. Without this,
	-- two builders choosing in the same few seconds can pick neighboring spots.
	local pending, pendingNext = {}, 1

	local function IsStructure(ud)
		return ud and (ud.isBuilding or ud.isImmobile) and true or false
	end

	-- Half extents (elmos) of a def's footprint for a build facing.
	local function HalfSize(ud, facing)
		local hx, hz = (ud.xsize or 2) * 4, (ud.zsize or 2) * 4
		if facing == 1 or facing == 3 then hx, hz = hz, hx end
		return hx, hz
	end

	-- True if a structure of half-size hx,hz at bx,bz keeps the required gap
	-- to every structure already there or on order.
	local function SiteHasLanes(bx, bz, hx, hz, isFactory, ignoreID)
		local nearby = Spring.GetUnitsInRectangle(bx - hx - QUERY_PAD, bz - hz - QUERY_PAD,
		                                          bx + hx + QUERY_PAD, bz + hz + QUERY_PAD)
		for i = 1, #nearby do
			local other = nearby[i]
			if other ~= ignoreID then
				local ud = UnitDefs[Spring.GetUnitDefID(other) or 0]
				if IsStructure(ud) then
					local ox, _, oz = Spring.GetUnitPosition(other)
					-- the neighbor's facing is not known cheaply: use its longer side both ways
					local oh  = math.max(ud.xsize or 2, ud.zsize or 2) * 4
					local gap = (isFactory or ud.isFactory) and FACTORY_APRON or LANE
					if math.abs(ox - bx) < hx + oh + gap and math.abs(oz - bz) < hz + oh + gap then
						return false
					end
				end
			end
		end
		local now = Spring.GetGameFrame()
		for i = 1, #pending do
			local p = pending[i]
			if p.untilFrame > now then
				local gap = (isFactory or p.isFactory) and FACTORY_APRON or LANE
				if math.abs(p.x - bx) < hx + p.hx + gap and math.abs(p.z - bz) < hz + p.hz + gap then
					return false
				end
			end
		end
		return true
	end
	L.SiteHasLanes = SiteHasLanes

	function L.BuildOrder(cUnitID, building)
		local ps = L.placeStats
		ps.sites, ps.blocked, ps.occupied, ps.crowded, ps.noAnchor = 0, 0, 0, 0, 0
		local team = Spring.GetUnitTeam(cUnitID)
		local cx, _, cz = Spring.GetUnitPosition(cUnitID)
		local newDef = UnitDefs[building]
		if not newDef or not cx then return false end
		local newIsFactory = newDef.isFactory and true or false

		-- Compute a "safe interior" direction: push away from whichever map edge
		-- is closest so buildings never pile up against a wall.
		local edgePushX = 0
		local edgePushZ = 0
		local edgeMargin = 1500
		if cx < edgeMargin then edgePushX =  1
		elseif cx > mapsizeX - edgeMargin then edgePushX = -1
		end
		if cz < edgeMargin then edgePushZ =  1
		elseif cz > mapsizeZ - edgeMargin then edgePushZ = -1
		end

		local searchRange = 0
		for b2 = 1, 30 do
			searchRange = searchRange + 150

			local units = Spring.GetUnitsInCylinder(cx, cz, searchRange, team)
			if #units > 1 then
				-- Prefer a building as the reference anchor, but exclude the builder itself
				local buildnear = nil
				for attempt = 1, 8 do
					local candidate = units[math.random(1, #units)]
					if candidate ~= cUnitID then
						local cDefID = Spring.GetUnitDefID(candidate)
						if cDefID and UnitDefs[cDefID].isBuilding then
							buildnear = candidate
							break
						end
					end
				end
				-- Fall back to any nearby unit that isn't the builder
				if not buildnear then
					for attempt = 1, 8 do
						local candidate = units[math.random(1, #units)]
						if candidate ~= cUnitID then
							buildnear = candidate
							break
						end
					end
				end
				if not buildnear then ps.noAnchor = ps.noAnchor + 1; break end

				local refDefID = Spring.GetUnitDefID(buildnear)
				if not refDefID then ps.noAnchor = ps.noAnchor + 1; break end
				local refDef = UnitDefs[refDefID]
				local refx, _, refz = Spring.GetUnitPosition(buildnear)
				local refIsStructure = IsStructure(refDef)
				local refHalf = refIsStructure and math.max(refDef.xsize or 2, refDef.zsize or 2) * 4 or 0

				-- Gap to the anchor, edge to edge: a lane (an apron if either
				-- side is a factory) plus a little jitter. Next to a mobile
				-- anchor there is nothing to keep clear of.
				local gap = math.random(0, GAP_JITTER)
				if refIsStructure then
					gap = gap + ((newIsFactory or refDef.isFactory) and FACTORY_APRON or LANE)
				end

				-- Build a direction priority list: prefer directions that move
				-- away from map edges, shuffle the rest.
				local dirs = {0, 1, 2, 3}
				-- Simple bubble: put edge-biased directions first
				if edgePushX > 0 then -- prefer +X (dir 1)
					table.remove(dirs, 2); table.insert(dirs, 1, 1)
				elseif edgePushX < 0 then -- prefer -X (dir 3)
					table.remove(dirs, 4); table.insert(dirs, 1, 3)
				end
				if edgePushZ > 0 then -- prefer +Z (dir 0)
					table.remove(dirs, 1); table.insert(dirs, 1, 0)
				elseif edgePushZ < 0 then -- prefer -Z (dir 2)
					for di = 1, #dirs do
						if dirs[di] == 2 then table.remove(dirs, di); break end
					end
					table.insert(dirs, 1, 2)
				end

				for _, r in ipairs(dirs) do
					local hx, hz = HalfSize(newDef, r)
					local bposx, bposz
					if     r == 0 then bposx = refx;                        bposz = refz + refHalf + hz + gap
					elseif r == 1 then bposx = refx + refHalf + hx + gap;   bposz = refz
					elseif r == 2 then bposx = refx;                        bposz = refz - refHalf - hz - gap
					else               bposx = refx - refHalf - hx - gap;   bposz = refz
					end

					-- Keep well inside map bounds
					bposx = math.max(256, math.min(mapsizeX - 256, bposx))
					bposz = math.max(256, math.min(mapsizeZ - 256, bposz))

					local bposy   = Spring.GetGroundHeight(bposx, bposz)
					local testpos = Spring.TestBuildOrder(building, bposx, bposy, bposz, r)
					ps.sites = ps.sites + 1
					if testpos == 2 then
						if SiteHasLanes(bposx, bposz, hx, hz, newIsFactory, cUnitID) then
							Spring.GiveOrderToUnit(cUnitID, -building, { bposx, bposy, bposz, r }, { "shift" })
							local p = pending[pendingNext]
							if not p then p = {}; pending[pendingNext] = p end
							p.x, p.z, p.hx, p.hz = bposx, bposz, hx, hz
							p.isFactory  = newIsFactory
							p.untilFrame = Spring.GetGameFrame() + PENDING_FOR
							pendingNext = (pendingNext % PENDING_MAX) + 1
							return true
						end
						ps.crowded = ps.crowded + 1
					elseif testpos == 0 then ps.blocked = ps.blocked + 1
					else ps.occupied = ps.occupied + 1 end
				end
			else
				ps.noAnchor = ps.noAnchor + 1
			end
		end
		return false
	end

	return L
end
