--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    game_start_spots.lua
--  brief:   builds the list of start spots used by the placement phase
--
--  Reads start positions from the map's mapinfo.lua, throws them away if they
--  overlap (a sure sign they're placeholder data), synthesises spots from
--  resource clusters when the map is short, and partitions the result between
--  allyteams.  Publishes the result through GG.StartSpots and game rules params.
--
--  Consumer: game_spawn.lua calls GG.StartSpots.Get() in GameStart.
--
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name      = "Start Spots",
		desc      = "Loads, validates, synthesises and partitions start positions",
		author    = "SplinterFaction",
		date      = "2026",
		license   = "GNU GPL, v2 or later",
		layer     = -5,          -- before Spawn (layer 0)
		enabled   = true
	}
end

if (not gadgetHandler:IsSyncedCode()) then
	return false
end

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local mapSpots = {}     -- spotIdx (1-based) → {x, z, allyteam, synthetic}
local isFFA    = false
local built    = false  -- Build() has run (result may still be empty)

local function CountNonGaiaTeams()
	local gaia = Spring.GetGaiaTeamID()
	local n = 0
	for _, tID in ipairs(Spring.GetTeamList()) do
		if tID ~= gaia then n = n + 1 end
	end
	return n
end
--------------------------------------------------------------------------------
-- Synthetic start positions
--
-- Some maps ship start positions that sit on top of one another (or none at
-- all).  Those are useless for placement, so after loading mapinfo we:
--   1. Collapse any spots closer than DUPLICATE_RADIUS into one.
--   2. If fewer distinct spots remain than there are teams, invent new ones.
--
-- Invented spots prefer clusters of resource locations (3+ ideal, 2 is fine),
-- and are spread as far apart as possible from every existing spot and from
-- each other.  Farthest-point spreading naturally puts them along the long
-- axis of a non-square map.
--------------------------------------------------------------------------------

local DUPLICATE_RADIUS  = 128   -- elmos; spots closer than this are one spot
local MIN_SPOTS         = 2     -- always keep at least this many usable spots
local SYNTH_SPOTS_PER_TEAM = 2  -- when the whole set is invented, spots per team (gives a choice)
local CLUSTER_RADIUS    = 384   -- elmos; resource points within this form a cluster
local IDEAL_CLUSTER     = 3     -- clusters this big or bigger score full marks
local MIN_SEPARATION    = 512   -- elmos; never invent a spot closer than this to another
local EDGE_MARGIN       = 256   -- elmos; keep invented spots off the map edge
local GRID_CANDIDATES   = 8     -- N×N geometric fallback grid across the map

-- Collapse near-duplicate spots in mapSpots (keeps the first of each group and
-- re-packs indices so they stay contiguous 1..N).  Returns the number removed.
local function DedupeMapSpots()
	local kept = {}
	local removed = 0
	local r2 = DUPLICATE_RADIUS * DUPLICATE_RADIUS
	for i = 1, #mapSpots do
		local s = mapSpots[i]
		local dup = false
		for _, k in ipairs(kept) do
			local dx, dz = s.x - k.x, s.z - k.z
			if dx * dx + dz * dz < r2 then dup = true; break end
		end
		if dup then
			removed = removed + 1
			Spring.Echo(string.format("[Start Spots]   dropping duplicate start position (%.0f, %.0f)", s.x, s.z))
		else
			kept[#kept + 1] = s
		end
	end
	mapSpots = kept
	return removed
end

-- Gather resource locations as a flat list of {x, z}.  Sources, in order:
--   a) a list published by the metal-spot gadget in GG (any of the names below)
--   b) a scan of the engine metal map, blobs merged into points
--   c) geothermal features (always appended — a vent is a resource too)
local function CollectResourcePoints()
	local pts = {}
	local source = "none"

	-- (a) gadget-published spot lists
	local ggNames = { "metalSpots", "metalMakerSpots", "mexSpots" }
	for _, key in ipairs(ggNames) do
		local list = GG and GG[key]
		if type(list) == "table" then
			for _, s in ipairs(list) do
				if type(s) == "table" and s.x and s.z then
					pts[#pts + 1] = { x = s.x, z = s.z }
				end
			end
			if #pts > 0 then source = "GG." .. key; break end
		end
	end

	-- (b) metal map scan (16 elmos per metal-map cell)
	if #pts == 0 and Spring.GetMetalAmount then
		local cellsX = math.floor(Game.mapSizeX / 16)
		local cellsZ = math.floor(Game.mapSizeZ / 16)
		local STEP   = 1
		local cells  = {}
		local maxM   = 0
		for cz = 0, cellsZ - 1, STEP do
			for cx = 0, cellsX - 1, STEP do
				local m = Spring.GetMetalAmount(cx, cz) or 0
				if m > 0 then
					cells[#cells + 1] = { x = cx * 16 + 8, z = cz * 16 + 8, m = m }
					if m > maxM then maxM = m end
				end
			end
		end
		-- Ignore faint background metal; keep cells that are clearly "a spot".
		local threshold = maxM * 0.25
		local MERGE_R2  = 80 * 80
		for _, c in ipairs(cells) do
			if c.m >= threshold then
				local merged = false
				for _, p in ipairs(pts) do
					local dx, dz = c.x - p.x, c.z - p.z
					if dx * dx + dz * dz < MERGE_R2 then
						-- metal-weighted running centroid
						local w = p.w + c.m
						p.x = (p.x * p.w + c.x * c.m) / w
						p.z = (p.z * p.w + c.z * c.m) / w
						p.w = w
						merged = true
						break
					end
				end
				if not merged then
					pts[#pts + 1] = { x = c.x, z = c.z, w = c.m }
				end
			end
		end
		if #pts > 0 then source = "metal map" end
	end

	-- (c) geothermal features
	local geoCount = 0
	for _, fID in ipairs(Spring.GetAllFeatures()) do
		local fd = FeatureDefs[Spring.GetFeatureDefID(fID)]
		if fd and fd.geoThermal then
			local fx, _, fz = Spring.GetFeaturePosition(fID)
			if fx then
				pts[#pts + 1] = { x = fx, z = fz }
				geoCount = geoCount + 1
			end
		end
	end
	if geoCount > 0 then
		source = (source == "none") and "geothermal" or (source .. " + geothermal")
	end

	return pts, source
end

-- Is this a sane place to put a commander?  Dry land, inside the margin.
local function IsUsableGround(x, z)
	if x < EDGE_MARGIN or z < EDGE_MARGIN
	or x > Game.mapSizeX - EDGE_MARGIN or z > Game.mapSizeZ - EDGE_MARGIN then
		return false
	end
	return Spring.GetGroundHeight(x, z) > 0
end

-- Build the candidate list for synthetic spots.
-- Each candidate is {x, z, q} where q ∈ [0,1] is resource quality.
local function BuildSpotCandidates()
	local cands = {}
	local pts, source = CollectResourcePoints()
	Spring.Echo(string.format("[Start Spots] Resource points for synthetic spots: %d (%s)", #pts, source))

	-- Resource clusters: for every point, gather neighbours within
	-- CLUSTER_RADIUS and use the cluster centroid as a candidate.
	local cr2 = CLUSTER_RADIUS * CLUSTER_RADIUS
	for i, p in ipairs(pts) do
		local cx, cz, n = 0, 0, 0
		for j, q in ipairs(pts) do
			local dx, dz = p.x - q.x, p.z - q.z
			if dx * dx + dz * dz <= cr2 then
				cx = cx + q.x; cz = cz + q.z; n = n + 1
			end
		end
		cx, cz = cx / n, cz / n
		if IsUsableGround(cx, cz) then
			-- Quality: 1 point = weak, 2 = acceptable, IDEAL_CLUSTER+ = full marks
			local q = math.min(n, IDEAL_CLUSTER) / IDEAL_CLUSTER
			cands[#cands + 1] = { x = cx, z = cz, q = q, n = n }
		end
	end

	-- Geometric fallback grid.  Quality 0 so any resource candidate beats it,
	-- but it guarantees we can always place *something* on any map.
	local N = GRID_CANDIDATES
	local function AddGrid(checkGround)
		for gz = 1, N do
			for gx = 1, N do
				local x = EDGE_MARGIN + (Game.mapSizeX - 2 * EDGE_MARGIN) * (gx - 0.5) / N
				local z = EDGE_MARGIN + (Game.mapSizeZ - 2 * EDGE_MARGIN) * (gz - 0.5) / N
				if not checkGround or IsUsableGround(x, z) then
					cands[#cands + 1] = { x = x, z = z, q = 0, n = 0, grid = true }
				end
			end
		end
	end
	AddGrid(true)
	if #cands == 0 then
		-- Every grid point is underwater (or the map is tiny): take them anyway.
		AddGrid(false)
	end

	return cands
end

-- Invent `count` new spots and append them to mapSpots (allyteam = -1).
-- Greedy farthest-point selection weighted by resource quality:
--   score = minDistToAnySpot × (0.35 + 0.65 × quality)
-- so a 3-resource cluster wins over empty ground unless the empty ground is
-- ~3× farther from everyone.  Candidates within MIN_SEPARATION of an existing
-- spot are skipped outright; if that leaves nothing, the constraint is relaxed.
local function GenerateSyntheticSpots(count)
	if count <= 0 then return 0 end
	local cands = BuildSpotCandidates()
	if #cands == 0 then return 0 end

	local mapCX, mapCZ = Game.mapSizeX / 2, Game.mapSizeZ / 2
	local minSep2 = MIN_SEPARATION * MIN_SEPARATION
	local added = 0

	for _ = 1, count do
		local best, bestScore = nil, -1
		local relaxed = false

		local function Evaluate(allowClose)
			for _, c in ipairs(cands) do
				if not c.used then
					-- Distance to the nearest existing spot (real or synthetic).
					-- With no spots at all, use distance from map centre so the
					-- first pick lands toward an edge/corner instead of mid-map.
					local minD2 = math.huge
					for _, s in ipairs(mapSpots) do
						local dx, dz = c.x - s.x, c.z - s.z
						local d2 = dx * dx + dz * dz
						if d2 < minD2 then minD2 = d2 end
					end
					local ok = true
					if minD2 == math.huge then
						local dx, dz = c.x - mapCX, c.z - mapCZ
						minD2 = dx * dx + dz * dz
					elseif minD2 < minSep2 and not allowClose then
						ok = false
					end
					if ok then
						local score = math.sqrt(minD2) * (0.35 + 0.65 * c.q)
						if score > bestScore then
							bestScore = score
							best = c
						end
					end
				end
			end
		end

		Evaluate(false)
		if not best then
			relaxed = true
			Evaluate(true)
		end
		if not best then break end

		best.used = true
		mapSpots[#mapSpots + 1] = { x = best.x, z = best.z, allyteam = -1, synthetic = true }
		added = added + 1
		Spring.Echo(string.format(
			"[Start Spots]   synthetic spot %d at (%.0f, %.0f)  resources=%d  %s%s",
			#mapSpots, best.x, best.z, best.n,
			best.grid and "[grid fallback]" or "[resource cluster]",
			relaxed and " (separation relaxed)" or ""))
	end

	return added
end

--------------------------------------------------------------------------------
-- Map spot loading and partition
--------------------------------------------------------------------------------

local function Build()
	local ok, mi = pcall(VFS.Include, "mapinfo.lua", nil, VFS.MAP)
	if ok and type(mi) == "table" and type(mi.teams) == "table" then
		-- Collect spots (mapinfo is 0-indexed; field is `startpos`, lowercase p)
		for i = 0, 999 do
			local t = mi.teams[i]
			if not t then break end
			local sp = t.startpos
			if type(sp) == "table" and sp.x and sp.z then
				mapSpots[#mapSpots + 1] = { x = sp.x, z = sp.z, allyteam = -1 }
			end
		end
	else
		Spring.Echo("[Start Spots] mapinfo.lua unavailable or has no teams table — will synthesise start positions")
	end

	local loaded  = #mapSpots
	local removed = DedupeMapSpots()
	Spring.Echo("[Start Spots] Loaded " .. loaded .. " map spots from mapinfo (" .. removed .. " duplicate(s) dropped)")

	-- Make sure there is one distinct spot per team (and never fewer than
	-- MIN_SPOTS).  Anything missing is invented from resource clusters.
	local teamCount = CountNonGaiaTeams()
	if removed > 0 then
		-- Overlapping starts mean the map's start data is bogus, not merely
		-- short.  Throw the whole set away and build a fresh one with room to
		-- choose (SYNTH_SPOTS_PER_TEAM each side, at least MIN_SPOTS).
		Spring.Echo("[Start Spots] Overlapping start positions — discarding mapinfo spots, synthesising a full set")
		mapSpots = {}
		GenerateSyntheticSpots(math.max(teamCount * SYNTH_SPOTS_PER_TEAM, MIN_SPOTS))
	else
		local needed = math.max(teamCount, MIN_SPOTS)
		if #mapSpots < needed then
			Spring.Echo(string.format("[Start Spots] Only %d spot(s) for %d team(s) — synthesising %d",
			                          #mapSpots, teamCount, needed - #mapSpots))
			GenerateSyntheticSpots(needed - #mapSpots)
		end
	end

	if #mapSpots == 0 then
		Spring.Echo("[Start Spots] No usable start positions and synthesis failed — skipping placement phase")
		return
	end

	local spotTotal = #mapSpots

	-- FFA detection: more than 2 allyteams where every allyteam has exactly 1 team.
	-- A 1v1 duel (2 allyteams × 1 player each) is NOT considered FFA.
	local gaiaTeamID = Spring.GetGaiaTeamID()
	local allyteamList = Spring.GetAllyTeamList()
	local atTeamCounts = {}
	for _, atID in ipairs(allyteamList) do
		local count = 0
		for _, tID in ipairs(Spring.GetTeamList(atID)) do
			if tID ~= gaiaTeamID then count = count + 1 end
		end
		if count > 0 then atTeamCounts[atID] = count end
	end

	local totalAT, multiAT = 0, 0
	for _, count in pairs(atTeamCounts) do
		totalAT = totalAT + 1
		if count > 1 then multiAT = multiAT + 1 end
	end
	isFFA = (totalAT > 2 and multiAT == 0)

	if isFFA then
		Spring.Echo("[Start Spots] FFA detected — all spots open to all players")
		-- all spots remain with allyteam = -1
	else
		-- Balanced, spatially-coherent spot partition.
		--
		-- Goals:
		--   1. Each team's spots should form a contiguous cluster — no teammate
		--      stranded in the middle of the enemy side.
		--   2. The split should be balanced (equal spot counts where possible).
		--
		-- For the common 2-team case we project every spot onto the axis that
		-- separates the two sides (the line between the engine-assigned team
		-- centroids), sort along it, and cut at the quota boundary.  This yields
		-- a clean half-space split (left/right, top/bottom, or whatever diagonal
		-- the map intends) that is both contiguous and balanced.
		--
		-- For 3+ allyteams (rare in sided play) we fall back to a balanced greedy
		-- auction by centroid distance.

		-- Centroid per allyteam from engine-assigned start positions
		local centroids = {}
		for atID in pairs(atTeamCounts) do
			local cx, cz, n = 0, 0, 0
			for _, tID in ipairs(Spring.GetTeamList(atID)) do
				if tID ~= gaiaTeamID then
					local tx, _, tz = Spring.GetTeamStartPosition(tID)
					if tx and tx ~= 0 then
						cx = cx + tx; cz = cz + tz; n = n + 1
					end
				end
			end
			if n > 0 then
				centroids[atID] = { x = cx / n, z = cz / n }
			end
		end

		-- Deterministic ordered list of participating allyteams
		local allyteamIDs = {}
		for atID in pairs(centroids) do
			allyteamIDs[#allyteamIDs + 1] = atID
		end
		table.sort(allyteamIDs)

		local numAT  = #allyteamIDs
		local base   = math.floor(spotTotal / numAT)
		local extras = spotTotal - base * numAT   -- first `extras` teams get base+1

		local quota = {}
		for i, atID in ipairs(allyteamIDs) do
			quota[atID] = base + (i <= extras and 1 or 0)
		end

		Spring.Echo(string.format("[Start Spots] Partition: %d spots across %d allyteams (quota ~%d each)",
		                          spotTotal, numAT, base))

		if numAT == 2 then
			-- ── Gap-search split (contiguous + balanced + barrier-aware) ──────
			--
			-- A straight cut perpendicular to the centroid axis works only when
			-- the two team start positions happen to line up with the map's
			-- intended divide.  When the engine drops the 1v1 starts diagonally,
			-- that cut slices a corner off the wrong side — stranding teammates
			-- across a river in team games.
			--
			-- Instead we search many candidate cut directions and pick the one
			-- whose *balanced* cut falls in the largest natural gap in the spot
			-- distribution (a river, chokepoint, or empty band).  The centroid
			-- axis is used as the default and is only overridden when another
			-- direction separates the two halves markedly more cleanly.  The
			-- team centroids then decide which half belongs to which team.

			local at1, at2 = allyteamIDs[1], allyteamIDs[2]
			local c1, c2   = centroids[at1], centroids[at2]

			-- Flat spot list for repeated projection
			local spotList = {}
			for spotIdx, spot in pairs(mapSpots) do
				spotList[#spotList + 1] = { s = spotIdx, x = spot.x, z = spot.z }
			end

			-- Cut rank for the balance point (mid split; exact per-team quota is
			-- applied at assignment time below).
			local kCut = math.floor(spotTotal / 2)

			-- Score a direction: normalised gap between the two balanced halves.
			-- Larger = the halves are separated by more empty space along dir.
			local function ScoreDir(dx, dz)
				local proj = {}
				for i = 1, #spotList do
					proj[i] = spotList[i].x * dx + spotList[i].z * dz
				end
				table.sort(proj)
				local span = proj[#proj] - proj[1]
				if span < 1 then return -1 end
				return (proj[kCut + 1] - proj[kCut]) / span
			end

			-- Default direction: the centroid axis (engine intent).
			local cax, caz = c2.x - c1.x, c2.z - c1.z
			local clen = math.sqrt(cax * cax + caz * caz)
			if clen < 1 then
				-- Degenerate centroids: seed with the map's horizontal axis; the
				-- search below will still find the best separating direction.
				cax, caz, clen = 1, 0, 1
			end
			cax, caz = cax / clen, caz / clen

			local bestDx, bestDz = cax, caz
			local bestScore      = ScoreDir(cax, caz)
			local centroidScore  = bestScore

			-- Sample directions across a half-circle (a line is undirected, so
			-- 0..π covers every distinct cut orientation).  Override the default
			-- only when a direction is clearly better, so uniform maps with no
			-- real barrier keep the sensible engine-intended axis.
			local STEPS  = 36     -- 5° resolution
			local MARGIN = 0.03   -- required improvement over the centroid axis
			for step = 0, STEPS - 1 do
				local theta  = math.pi * step / STEPS
				local dx, dz = math.cos(theta), math.sin(theta)
				local sc     = ScoreDir(dx, dz)
				if sc > bestScore + MARGIN then
					bestScore = sc
					bestDx, bestDz = dx, dz
				end
			end

			-- Project all spots along the chosen direction and sort ascending.
			local ordered = {}
			for i = 1, #spotList do
				ordered[i] = {
					s = spotList[i].s,
					p = spotList[i].x * bestDx + spotList[i].z * bestDz,
				}
			end
			table.sort(ordered, function(a, b) return a.p < b.p end)

			-- Which team owns the low-projection half?  The one whose centroid
			-- projects lower along the cut direction.
			local c1p = c1.x * bestDx + c1.z * bestDz
			local c2p = c2.x * bestDx + c2.z * bestDz
			local lowTeam, highTeam
			if c1p <= c2p then
				lowTeam, highTeam = at1, at2
			else
				lowTeam, highTeam = at2, at1
			end

			-- Assign: first quota[lowTeam] spots to the low side, rest to the high.
			local lowQuota = quota[lowTeam]
			for rank, item in ipairs(ordered) do
				mapSpots[item.s].allyteam = (rank <= lowQuota) and lowTeam or highTeam
			end

			Spring.Echo(string.format(
				"[Start Spots] Gap split: dir=(%.2f, %.2f)  centroidScore=%.3f  bestScore=%.3f  lowTeam=%d gets %d",
				bestDx, bestDz, centroidScore, bestScore, lowTeam, lowQuota))
		else
			-- ── Balanced greedy auction (3+ allyteams) ────────────────────────
			local candidates = {}
			for spotIdx, spot in pairs(mapSpots) do
				for _, atID in ipairs(allyteamIDs) do
					local c  = centroids[atID]
					local dx = spot.x - c.x
					local dz = spot.z - c.z
					candidates[#candidates + 1] = { s = spotIdx, a = atID, d = dx*dx + dz*dz }
				end
			end
			table.sort(candidates, function(a, b) return a.d < b.d end)

			local assigned   = {}
			local teamCounts = {}
			for _, atID in ipairs(allyteamIDs) do teamCounts[atID] = 0 end

			for _, cand in ipairs(candidates) do
				if not assigned[cand.s] and teamCounts[cand.a] < quota[cand.a] then
					mapSpots[cand.s].allyteam = cand.a
					assigned[cand.s]          = true
					teamCounts[cand.a]        = teamCounts[cand.a] + 1
				end
			end

			for spotIdx in pairs(mapSpots) do
				if not assigned[spotIdx] then
					mapSpots[spotIdx].allyteam = allyteamIDs[1]
				end
			end
		end

		for i, spot in pairs(mapSpots) do
			Spring.Echo(string.format("[Start Spots]   spot[%d] (%.0f, %.0f) → allyteam %d",
			                          i, spot.x, spot.z, spot.allyteam))
		end
	end

	-- Broadcast spot positions and side assignments for widget display.
	-- Claim state is NOT broadcast globally — each team tracks its own via
	-- team rules params with allied-only visibility (see AssignSpot).
	Spring.SetGameRulesParam("spotCount", spotTotal)
	Spring.SetGameRulesParam("isFFA", isFFA and 1 or 0)
	for i, spot in pairs(mapSpots) do
		Spring.SetGameRulesParam("spot_" .. i .. "_x",  spot.x)
		Spring.SetGameRulesParam("spot_" .. i .. "_z",  spot.z)
		Spring.SetGameRulesParam("spot_" .. i .. "_at", spot.allyteam)
		Spring.SetGameRulesParam("spot_" .. i .. "_synth", spot.synthetic and 1 or 0)
	end

	built = true
end

--------------------------------------------------------------------------------
-- Public interface
--------------------------------------------------------------------------------

GG.StartSpots = {
	-- Returns spots (array, may be empty) and isFFA.  Builds on first call so
	-- callers don't depend on gadget callin ordering.  Must be called at or
	-- after GameStart: partitioning reads engine-assigned team start positions.
	Get = function()
		if not built then Build() end
		return mapSpots, isFFA
	end,
}

function gadget:GameStart()
	if not built then Build() end
end
