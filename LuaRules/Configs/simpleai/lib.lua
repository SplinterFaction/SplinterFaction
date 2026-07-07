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
	function L.CombatRoleWeight(defID)
		local ud  = UnitDefs[defID]
		local cat = ud and ud.customParams and ud.customParams.buildmenucategory
		return COMBAT_ROLE_WEIGHT[cat] or COMBAT_ROLE_WEIGHT.default
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

	function L.BuildOrder(cUnitID, building)
		local team = Spring.GetUnitTeam(cUnitID)
		local cx, _, cz = Spring.GetUnitPosition(cUnitID)

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
				if not buildnear then break end

				local refDefID = Spring.GetUnitDefID(buildnear)
				if not refDefID then break end
				local refx, _, refz = Spring.GetUnitPosition(buildnear)
				local reffootx = UnitDefs[refDefID].xsize * 8
				local reffootz = UnitDefs[refDefID].zsize * 8

				-- Use a larger minimum spacing to stop units being walled in.
				-- If near the map edge, also add the edge push to the offset.
				local spacing = math.random(96, 256)

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
					local bposx, bposz
					if     r == 0 then bposx = refx;                    bposz = refz + reffootz + spacing
					elseif r == 1 then bposx = refx + reffootx + spacing; bposz = refz
					elseif r == 2 then bposx = refx;                    bposz = refz - reffootz - spacing
					else              bposx = refx - reffootx - spacing; bposz = refz
					end

					-- Apply edge push as an additional offset nudge
					bposx = bposx + edgePushX * spacing * 0.5
					bposz = bposz + edgePushZ * spacing * 0.5

					-- Keep well inside map bounds (larger margin than before)
					bposx = math.max(256, math.min(mapsizeX - 256, bposx))
					bposz = math.max(256, math.min(mapsizeZ - 256, bposz))

					local bposy   = Spring.GetGroundHeight(bposx, bposz)
					local testpos = Spring.TestBuildOrder(building, bposx, bposy, bposz, r)
					-- Use spacing as clearance check radius — avoids packing too tight
					local nearby  = Spring.GetUnitsInRectangle(
							bposx - spacing * 0.5, bposz - spacing * 0.5,
							bposx + spacing * 0.5, bposz + spacing * 0.5)
					if testpos == 2 and #nearby <= 0 then
						Spring.GiveOrderToUnit(cUnitID, -building, { bposx, bposy, bposz, r }, { "shift" })
						return true
					end
				end
			end
		end
		return false
	end

	return L
end
