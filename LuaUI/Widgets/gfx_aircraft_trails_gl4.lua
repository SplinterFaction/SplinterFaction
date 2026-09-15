function widget:GetInfo()
	return {
		name      = "Aircraft Trails GL4",
		desc      = "Wingtip vortex ribbons for aircraft. Append-only GPU ring with shader-side expiry, heap-scheduled sampling with LOD, per-unitdef emitter pieces via customparams.trail_pieces.",
		author    = "SplinterFaction",
		date      = "2026-09-15",
		license   = "GNU GPL, v2 or later",
		layer     = 5,
		enabled   = true,
	}
end

--------------------------------------------------------------------------------
-- Unitdef hookup
--
--   customparams = {
--       trail_pieces = "wingtip_l,wingtip_r,tail_l:0.5,tail_r:0.5",
--       trail_width  = "3.5",   -- optional, base ribbon half-width in elmos
--   }
--
-- Entries are piece names, optionally suffixed with ":weight" (default 1.0).
-- At most cfg.maxPieces entries are used; extras are dropped with a warning.
-- Strafing aircraft with no trail_pieces get two emitters at the model radius.
-- Anything else gets nothing.
--
-- Architecture
--   * GPU instance buffer = [live-head region][append-only segment ring].
--     Ring segments are written once and expire in the vertex shader from a
--     gameTime uniform; nothing is rebuilt per frame. The live region holds one
--     segment per emitter (last stored point -> current wingtip) so the ribbon
--     stays glued to the wing between samples; it is small and re-uploaded
--     each Update.
--   * A min-heap schedules per-unit samples. Interval scales with camera
--     distance and total active count, and is capped per Update.
--   * Far / off-screen units go dormant and are polled with scalar calls only.
--   * Speed and turn rate come from sample-to-sample motion of the emitter
--     centroid; no GetUnitVelocity in the hot path.
--------------------------------------------------------------------------------

local cfg = {
	lifetime          = 0.9,    -- seconds a segment stays visible
	maxPieces         = 8,      -- hard cap on emitters per unit
	minSpeedFrac      = 0.35,   -- fraction of unitdef max speed where trails begin
	fullSpeedFrac     = 0.85,   -- fraction of max speed for full speed factor
	turnFullDegPerSec = 110,    -- turn rate that gives full turn factor
	turnSmoothing     = 14,     -- higher = snappier response to turn changes
	baseIntensity     = 0.25,   -- intensity while flying straight (times speed factor)
	minIntensity      = 0.06,   -- below this the emitter goes quiet and the run breaks
	minAltitude       = 25,     -- elmos above ground before trails appear
	minSpacing        = 6.0,    -- elmos between stored ring points (segment length)
	baseWidth         = 3.0,    -- ribbon half-width at birth
	widthGrow         = 1.2,    -- extra width fraction at end of life
	color             = { 1.0, 1.0, 1.0, 0.55 },
	fallbackTipFrac   = 0.8,    -- fallback tip offset = radius * this

	-- scheduling
	sampleInterval    = 1 / 30, -- base seconds between samples (near camera)
	lodMidDist        = 1400,   -- beyond this: interval * lodMidMul
	lodFarDist        = 2300,   -- beyond this: interval * lodFarMul
	cullDist          = 2900,   -- beyond this: dormant, no trail
	lodMidMul         = 1.6,
	lodFarMul         = 2.4,
	dormantPoll       = 0.25,   -- seconds between polls of far / off-screen units
	maxSamplesPerUpdate = 256,  -- catch-up cap after a hitch
	massLod           = {       -- { activeUnits, intervalMul } ascending
		{ 125, 1.25 }, { 225, 1.5 }, { 300, 2.0 },
	},
	liveHeadRefresh   = true,   -- refresh live heads every Update for near units

	-- GPU
	ringSegments      = 8192,   -- append-only ring capacity
	maxLive           = 512,    -- live-head slots (one per active emitter)
}

--------------------------------------------------------------------------------

local spGetUnitPiecePosDir  = Spring.GetUnitPiecePosDir
local spGetUnitPieceMap     = Spring.GetUnitPieceMap
local spGetUnitViewPosition = Spring.GetUnitViewPosition
local spGetUnitBasePosition = Spring.GetUnitBasePosition or Spring.GetUnitPosition
local spGetUnitVectors      = Spring.GetUnitVectors
local spGetGroundHeight     = Spring.GetGroundHeight
local spIsSphereInView      = Spring.IsSphereInView
local spGetCameraPosition   = Spring.GetCameraPosition
local spGetUnitDefID        = Spring.GetUnitDefID
local spGetUnitAllyTeam     = Spring.GetUnitAllyTeam
local spGetMyAllyTeamID     = Spring.GetMyAllyTeamID
local spGetSpectatingState  = Spring.GetSpectatingState
local spGetAllUnits         = Spring.GetAllUnits
local spGetGameSeconds      = Spring.GetGameSecondsInterpolated or Spring.GetGameSeconds
local spEcho                = Spring.Echo

local sqrt  = math.sqrt
local acos  = math.acos
local min   = math.min
local max   = math.max
local floor = math.floor

local TURN_FULL = math.rad(cfg.turnFullDegPerSec)
local FLOATS_PER_INSTANCE = 12
local LOD_MID_SQ  = cfg.lodMidDist * cfg.lodMidDist
local LOD_FAR_SQ  = cfg.lodFarDist * cfg.lodFarDist
local CULL_SQ     = cfg.cullDist * cfg.cullDist
local RING        = cfg.ringSegments
local MAX_LIVE    = cfg.maxLive
local EXPIRED_T   = -1e9

local defCache    = {}   -- unitDefID -> def info table, or false
local units       = {}   -- unitID -> unit state (tracked, may be inactive)
local emitterPool = {}
local warned      = {}

local myAllyTeamID = nil
local fullView     = false
local now          = 0

-- scheduler heap
local heapUnits = {}
local heapTimes = {}
local heapCount = 0

-- mass LOD
local activeCount = 0
local massMul     = 1.0

-- GPU ring state
local ringCursor  = 0   -- 0-based next write slot within the ring
local ringWritten = 0   -- total segments ever appended
local ringScratch = {}  -- batched appends this Update
local ringBatch   = 0   -- segments in scratch
local ringFloats  = 0

-- live-head region state
local liveScratch = {}
local liveCount   = 0
local livePrev    = 0

local shader, vao, vertVBO, indexVBO, instVBO
local LuaShader
local glReady = false

-- debug counters
local statSamples, statSegments, statUploads, statDormantPolls = 0, 0, 0, 0

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

local function WarnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	spEcho("[AircraftTrails] " .. msg)
end

--------------------------------------------------------------------------------
-- Unitdef resolution
--------------------------------------------------------------------------------

local function ParsePieceList(str, udName)
	local out = {}
	for entry in string.gmatch(str, "[^,]+") do
		entry = entry:match("^%s*(.-)%s*$")
		if entry ~= "" then
			local name, w = entry:match("^([^:]+):%s*([%d%.]+)%s*$")
			if not name then
				name = entry
				w = nil
			end
			name = name:match("^%s*(.-)%s*$")
			out[#out + 1] = { name = name, weight = tonumber(w) or 1.0 }
		end
	end
	if #out > cfg.maxPieces then
		WarnOnce("cap:" .. udName, udName .. " lists " .. #out .. " trail pieces, capped to " .. cfg.maxPieces)
		for i = #out, cfg.maxPieces + 1, -1 do
			out[i] = nil
		end
	end
	return out
end

local function GetDefInfo(unitDefID)
	local cached = defCache[unitDefID]
	if cached ~= nil then
		return cached
	end

	local ud = UnitDefs[unitDefID]
	if not ud then
		defCache[unitDefID] = false
		return false
	end

	local cp = ud.customParams or {}
	local strafing = ud.isStrafingAirUnit
	if strafing == nil then
		strafing = ud.canFly and not ud.hoverAttack and not ud.isHoveringAirUnit
	end

	local info = false
	if cp.trail_pieces then
		info = {
			pieces   = ParsePieceList(tostring(cp.trail_pieces), ud.name),
			fallback = false,
		}
	elseif strafing then
		info = {
			pieces    = nil,
			fallback  = true,
			tipOffset = (ud.radius or 20) * cfg.fallbackTipFrac,
		}
	end

	if info then
		info.name = ud.name
		local maxSpeed = ud.speed or 0 -- elmo/sec, same unit as our derived speed
		info.minSpeed  = maxSpeed * cfg.minSpeedFrac
		info.fullSpeed = maxSpeed * cfg.fullSpeedFrac
		if info.fullSpeed <= info.minSpeed then
			info.fullSpeed = info.minSpeed + 0.1
		end
		info.width      = tonumber(cp.trail_width) or cfg.baseWidth
		info.viewRadius = max((ud.radius or 20) * 1.35, 24)
		info.resolved   = nil
	end

	defCache[unitDefID] = info
	return info
end

local function ResolvePieces(info, unitID)
	if info.resolved then
		return info.resolved
	end
	local map = spGetUnitPieceMap(unitID)
	if not map then
		return nil
	end
	local res = {}
	for _, p in ipairs(info.pieces) do
		local idx = map[p.name]
		if idx then
			res[#res + 1] = { piece = idx, weight = p.weight }
		else
			WarnOnce("piece:" .. info.name .. ":" .. p.name,
				info.name .. " has no piece named '" .. p.name .. "' (trail_pieces)")
		end
	end
	info.resolved = res
	return res
end

--------------------------------------------------------------------------------
-- Emitters
--------------------------------------------------------------------------------

local function NewEmitter(piece, weight, offset, seed)
	local e = emitterPool[#emitterPool]
	if e then
		emitterPool[#emitterPool] = nil
	else
		e = {}
	end
	e.piece   = piece
	e.weight  = weight
	e.offset  = offset
	e.seed    = seed
	e.hasPrev = false   -- have a stored ring point to chain from
	e.hasLive = false   -- current tip is emitting
	e.px, e.py, e.pz, e.pt, e.pi = 0, 0, 0, 0, 0
	e.lx, e.ly, e.lz, e.li = 0, 0, 0, 0
	e.runIdx  = 0
	return e
end

local function ReleaseEmitter(e)
	e.hasPrev = false
	e.hasLive = false
	emitterPool[#emitterPool + 1] = e
end

local function Quiet(e)
	e.hasLive = false
	e.hasPrev = false
end

--------------------------------------------------------------------------------
-- GPU ring append / upload
--------------------------------------------------------------------------------

local function WriteInstance(d, n, x0, y0, z0, t0, x1, y1, z1, t1, i0, i1, seed, runIdx)
	d[n + 1]  = x0
	d[n + 2]  = y0
	d[n + 3]  = z0
	d[n + 4]  = t0
	d[n + 5]  = x1
	d[n + 6]  = y1
	d[n + 7]  = z1
	d[n + 8]  = t1
	d[n + 9]  = i0
	d[n + 10] = i1
	d[n + 11] = seed
	d[n + 12] = runIdx
	return n + FLOATS_PER_INSTANCE
end

local function FlushRing()
	if ringBatch <= 0 then return end
	if instVBO then
		instVBO:Upload(ringScratch, -1, MAX_LIVE + ringCursor, 1, ringFloats)
		statUploads = statUploads + 1
	end
	ringCursor = ringCursor + ringBatch
	if ringCursor >= RING then
		ringCursor = ringCursor - RING
	end
	ringWritten = ringWritten + ringBatch
	ringBatch  = 0
	ringFloats = 0
end

local function AppendSegment(e, x, y, z)
	-- never let one contiguous upload cross the ring end
	if ringBatch >= RING - ringCursor then
		FlushRing()
	end
	ringFloats = WriteInstance(ringScratch, ringFloats,
		e.px, e.py, e.pz, e.pt, x, y, z, now, e.pi, e.li, e.seed, e.runIdx)
	ringBatch = ringBatch + 1
	statSegments = statSegments + 1
	e.runIdx = e.runIdx + 1
end

local function Feed(e, x, y, z, inten)
	if inten < cfg.minIntensity then
		Quiet(e)
		return
	end

	e.hasLive = true
	e.lx, e.ly, e.lz, e.li = x, y, z, inten

	if e.hasPrev then
		local dx, dy, dz = x - e.px, y - e.py, z - e.pz
		if dx * dx + dy * dy + dz * dz < cfg.minSpacing * cfg.minSpacing then
			return
		end
		AppendSegment(e, x, y, z)
	end

	e.hasPrev = true
	e.px, e.py, e.pz, e.pt, e.pi = x, y, z, now, inten
end

--------------------------------------------------------------------------------
-- Scheduler (binary min-heap keyed on next sample time)
--------------------------------------------------------------------------------

local function HeapSwap(a, b)
	local ua, ub = heapUnits[a], heapUnits[b]
	heapUnits[a], heapUnits[b] = ub, ua
	heapTimes[a], heapTimes[b] = heapTimes[b], heapTimes[a]
	local da, db = units[ua], units[ub]
	if da then da.heapIndex = b end
	if db then db.heapIndex = a end
end

local function HeapSiftUp(i)
	while i > 1 do
		local p = floor(i * 0.5)
		if heapTimes[p] <= heapTimes[i] then break end
		HeapSwap(i, p)
		i = p
	end
end

local function HeapSiftDown(i)
	while true do
		local l = i * 2
		if l > heapCount then break end
		local r = l + 1
		local s = l
		if r <= heapCount and heapTimes[r] < heapTimes[l] then s = r end
		if heapTimes[i] <= heapTimes[s] then break end
		HeapSwap(i, s)
		i = s
	end
end

local function HeapInsert(unitID, when)
	local u = units[unitID]
	if not u then return end
	if u.heapIndex then
		local i = u.heapIndex
		local old = heapTimes[i]
		heapTimes[i] = when
		if when < old then HeapSiftUp(i) else HeapSiftDown(i) end
		return
	end
	heapCount = heapCount + 1
	heapUnits[heapCount] = unitID
	heapTimes[heapCount] = when
	u.heapIndex = heapCount
	HeapSiftUp(heapCount)
end

local function HeapRemoveAt(i)
	if not i or i < 1 or i > heapCount then return end
	local removed = units[heapUnits[i]]
	local lastUnit, lastTime = heapUnits[heapCount], heapTimes[heapCount]
	heapUnits[heapCount] = nil
	heapTimes[heapCount] = nil
	heapCount = heapCount - 1
	if removed then removed.heapIndex = nil end
	if i <= heapCount then
		heapUnits[i], heapTimes[i] = lastUnit, lastTime
		local lu = units[lastUnit]
		if lu then lu.heapIndex = i end
		local p = floor(i * 0.5)
		if i > 1 and heapTimes[i] < heapTimes[p] then HeapSiftUp(i) else HeapSiftDown(i) end
	end
end

--------------------------------------------------------------------------------
-- Unit tracking
--------------------------------------------------------------------------------

local function UpdateMassLod()
	massMul = 1.0
	for i = 1, #cfg.massLod do
		local step = cfg.massLod[i]
		if activeCount > step[1] then massMul = step[2] end
	end
end

local function SetRelevant(u, rel)
	if u.relevant == rel then return end
	u.relevant = rel
	activeCount = rel and (activeCount + 1) or max(0, activeCount - 1)
	UpdateMassLod()
end

local function QuietAll(u)
	if not u.emitters then return end
	for i = 1, #u.emitters do
		Quiet(u.emitters[i])
	end
	u.hasKin = false
	u.near = false
end

local function RegisterUnit(unitID, unitDefID)
	if units[unitID] then
		return units[unitID]
	end
	local info = GetDefInfo(unitDefID)
	if not info then
		return nil
	end
	local u = {
		info      = info,
		emitters  = nil,
		active    = false,
		relevant  = false,
		dormant   = false,
		near      = false,
		heapIndex = nil,
		hasKin    = false,
		kx = 0, ky = 0, kz = 0, kt = 0,
		hasDir    = false,
		dx = 0, dy = 0, dz = 0,
		turn      = 0,
	}
	units[unitID] = u
	return u
end

local function ActivateUnit(unitID, u)
	if u.active then return end
	u.active  = true
	u.dormant = false
	u.turn    = 0
	QuietAll(u)
	local phase = (unitID * 0.61803398875) % 1.0
	HeapInsert(unitID, now + phase * cfg.sampleInterval)
end

local function DeactivateUnit(u)
	if not u.active then return end
	SetRelevant(u, false)
	if u.heapIndex then HeapRemoveAt(u.heapIndex) end
	u.active  = false
	u.dormant = false
	QuietAll(u)
end

local function RemoveUnit(unitID)
	local u = units[unitID]
	if not u then return end
	DeactivateUnit(u)
	if u.emitters then
		for i = 1, #u.emitters do ReleaseEmitter(u.emitters[i]) end
		u.emitters = nil
	end
	units[unitID] = nil
end

local function IsOwnSide(unitID)
	if fullView then return true end
	local at = spGetUnitAllyTeam(unitID)
	return at ~= nil and at == myAllyTeamID
end

local function EnsureEmitters(unitID, u)
	if u.emitters then return u.emitters end
	local info = u.info
	local list = {}
	local base = (unitID % 89) * 0.011
	if info.fallback then
		list[1] = NewEmitter(nil, 1.0, -info.tipOffset, base)
		list[2] = NewEmitter(nil, 1.0,  info.tipOffset, base + 0.5)
	else
		local res = ResolvePieces(info, unitID)
		if not res then return nil end
		for i, r in ipairs(res) do
			list[i] = NewEmitter(r.piece, r.weight, 0, base + i * 0.137)
		end
	end
	u.emitters = list
	return list
end

local function SeedUnits()
	for _, unitID in ipairs(spGetAllUnits()) do
		local udid = spGetUnitDefID(unitID)
		if udid then
			local u = RegisterUnit(unitID, udid)
			-- GetAllUnits only returns units this player can see, so activating
			-- everything it lists is safe; enemies out of LOS come via UnitEnteredLos.
			if u then ActivateUnit(unitID, u) end
		end
	end
end

--------------------------------------------------------------------------------
-- Sampling
--------------------------------------------------------------------------------

-- Reusable scratch for emitter positions within one sample
local sx, sy, sz = {}, {}, {}

-- Fills sx/sy/sz for every emitter; returns emitter count, or nil if unreadable.
local function QueryEmitterPositions(unitID, u, emitters)
	local n = #emitters
	if u.info.fallback then
		local mx, my, mz = spGetUnitViewPosition(unitID, true)
		if not mx then return nil end
		local _, _, right = spGetUnitVectors(unitID)
		if not right then return nil end
		for i = 1, n do
			local o = emitters[i].offset
			sx[i], sy[i], sz[i] = mx + right[1] * o, my + right[2] * o, mz + right[3] * o
		end
	else
		for i = 1, n do
			local x, y, z = spGetUnitPiecePosDir(unitID, emitters[i].piece)
			if not x then return nil end
			sx[i], sy[i], sz[i] = x, y, z
		end
	end
	return n
end

local function GoDormant(u)
	u.dormant = true
	SetRelevant(u, false)
	QuietAll(u)
	return now + cfg.dormantPoll
end

local function SampleUnit(unitID, u, camX, camY, camZ)
	local info = u.info

	if u.dormant then
		statDormantPolls = statDormantPolls + 1
		local x, y, z = spGetUnitBasePosition(unitID)
		if not x then return now + cfg.dormantPoll end
		local dx, dy, dz = x - camX, y - camY, z - camZ
		if dx * dx + dy * dy + dz * dz > CULL_SQ then return now + cfg.dormantPoll end
		if not spIsSphereInView(x, y, z, info.viewRadius) then return now + cfg.dormantPoll end
		u.dormant = false
	end

	local emitters = EnsureEmitters(unitID, u)
	if not emitters then
		return now + cfg.dormantPoll
	end

	local n = QueryEmitterPositions(unitID, u, emitters)
	if not n then
		QuietAll(u)
		SetRelevant(u, false)
		return now + cfg.dormantPoll
	end

	-- centroid
	local cx, cy, cz = 0, 0, 0
	for i = 1, n do cx, cy, cz = cx + sx[i], cy + sy[i], cz + sz[i] end
	cx, cy, cz = cx / n, cy / n, cz / n

	local ddx, ddy, ddz = cx - camX, cy - camY, cz - camZ
	local distSq = ddx * ddx + ddy * ddy + ddz * ddz
	if distSq > CULL_SQ then return GoDormant(u) end
	if not spIsSphereInView(cx, cy, cz, info.viewRadius) then return GoDormant(u) end

	SetRelevant(u, true)

	local lodMul = 1.0
	if distSq > LOD_FAR_SQ then
		lodMul = cfg.lodFarMul
	elseif distSq > LOD_MID_SQ then
		lodMul = cfg.lodMidMul
	end
	u.near = (lodMul == 1.0)
	local nextTime = now + cfg.sampleInterval * lodMul * massMul

	-- kinematics from centroid motion
	local speed, turnTarget = nil, 0
	if u.hasKin then
		local dt = now - u.kt
		if dt > 1e-4 then
			local mx, my, mz = cx - u.kx, cy - u.ky, cz - u.kz
			local dist = sqrt(mx * mx + my * my + mz * mz)
			speed = dist / dt
			if dist > 1e-3 then
				local ndx, ndy, ndz = mx / dist, my / dist, mz / dist
				if u.hasDir then
					local dot = clamp(ndx * u.dx + ndy * u.dy + ndz * u.dz, -1, 1)
					turnTarget = clamp((acos(dot) / dt) / TURN_FULL, 0, 1)
				end
				u.dx, u.dy, u.dz = ndx, ndy, ndz
				u.hasDir = true
			end
			local k = min(1, dt * cfg.turnSmoothing)
			u.turn = u.turn + (turnTarget - u.turn) * k
		else
			speed = nil
		end
	end
	u.hasKin = true
	u.kx, u.ky, u.kz, u.kt = cx, cy, cz, now

	if not speed then
		-- first sample after (re)activation: nothing to chain from yet
		for i = 1, n do Quiet(emitters[i]) end
		return nextTime
	end

	local speedFactor = clamp((speed - info.minSpeed) / (info.fullSpeed - info.minSpeed), 0, 1)
	local intensity = speedFactor * (cfg.baseIntensity + (1 - cfg.baseIntensity) * u.turn)
	if intensity > 0 and cy - spGetGroundHeight(cx, cz) < cfg.minAltitude then
		intensity = 0
	end

	for i = 1, n do
		local e = emitters[i]
		Feed(e, sx[i], sy[i], sz[i], intensity * e.weight)
	end
	return nextTime
end

local function SampleDue()
	if heapCount <= 0 or heapTimes[1] > now then return end
	local camX, camY, camZ = spGetCameraPosition()
	if not camX then return end

	local processed = 0
	while heapCount > 0 and heapTimes[1] <= now and processed < cfg.maxSamplesPerUpdate do
		local unitID = heapUnits[1]
		local u = units[unitID]
		if not u or not u.active or u.heapIndex ~= 1 then
			HeapRemoveAt(1)
		else
			local nextTime = SampleUnit(unitID, u, camX, camY, camZ)
			statSamples = statSamples + 1
			processed = processed + 1
			heapTimes[1] = nextTime
			HeapSiftDown(1)
		end
	end
end

-- Live heads: keep the ribbon attached to the wing between samples.
local function RefreshLiveHeads()
	local d = liveScratch
	local nfl = 0
	local count = 0
	local refresh = cfg.liveHeadRefresh

	for unitID, u in pairs(units) do
		local emitters = u.emitters
		if u.active and u.relevant and emitters then
			local refreshed = false
			if refresh and u.near then
				refreshed = QueryEmitterPositions(unitID, u, emitters) ~= nil
			end
			for i = 1, #emitters do
				local e = emitters[i]
				if e.hasLive and e.hasPrev then
					if count >= MAX_LIVE then break end
					if refreshed then
						e.lx, e.ly, e.lz = sx[i], sy[i], sz[i]
					end
					nfl = WriteInstance(d, nfl,
						e.px, e.py, e.pz, e.pt, e.lx, e.ly, e.lz, now, e.pi, e.li, e.seed, e.runIdx)
					count = count + 1
				end
			end
		end
	end

	-- expire slots that were live last frame but not this one
	for _ = count + 1, livePrev do
		nfl = WriteInstance(d, nfl, 0, 0, 0, EXPIRED_T, 0, 0, 0, EXPIRED_T, 0, 0, 0, 0)
	end
	local total = max(count, livePrev)
	livePrev  = count
	liveCount = count

	if total > 0 and instVBO then
		instVBO:Upload(d, -1, 0, 1, nfl)
		statUploads = statUploads + 1
	end
end

--------------------------------------------------------------------------------
-- Shaders
--------------------------------------------------------------------------------

local vsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack : require
#line 10000

layout (location = 0) in vec2 uv;      // x: 0..1 along segment, y: -1..1 across
layout (location = 1) in vec4 p0t0;    // xyz: segment start, w: birth time (game seconds)
layout (location = 2) in vec4 p1t1;    // xyz: segment end,   w: birth time
layout (location = 3) in vec4 misc;    // x: intensity0, y: intensity1, z: seed, w: run index

uniform float gameTime;
uniform float lifetime;
uniform float baseWidth;
uniform float widthGrow;

//__ENGINEUNIFORMBUFFERDEFS__

out DataVS {
	float across;
	float along;
	float alpha;
	float seed;
	float fog;
} vs;

void main() {
	// newest end expired, or nothing to show: collapse the quad off-screen
	if (gameTime - p1t1.w >= lifetime || max(misc.x, misc.y) <= 0.0) {
		gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
		vs.across = 0.0; vs.along = 0.0; vs.alpha = 0.0; vs.seed = 0.0; vs.fog = 0.0;
		return;
	}

	vec3 p0 = p0t0.xyz;
	vec3 p1 = p1t1.xyz;
	float age  = gameTime - mix(p0t0.w, p1t1.w, uv.x);
	float life = clamp(age / lifetime, 0.0, 1.0);
	float intensity = mix(misc.x, misc.y, uv.x);

	vec3 pos = mix(p0, p1, uv.x);
	vec3 camPos = cameraViewInv[3].xyz;
	vec3 toCam = camPos - pos;
	float dist = length(toCam);

	vec3 seg = p1 - p0;
	vec3 side = cross(seg, toCam);
	float sideLen = length(side);
	side = (sideLen > 1e-5) ? side / sideLen : vec3(0.0, 1.0, 0.0);

	float width = baseWidth * (1.0 + widthGrow * life);
	pos += side * (uv.y * width);

	vs.across = uv.y;
	vs.along  = misc.w + uv.x;
	vs.alpha  = intensity * pow(1.0 - life, 1.5);
	vs.seed   = misc.z;
	vs.fog    = clamp((fogParams.y - dist) / (fogParams.y - fogParams.x), 0.0, 1.0);

	gl_Position = cameraViewProj * vec4(pos, 1.0);
}
]]

local fsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack : require
#line 20000

uniform vec4 trailColor;

//__ENGINEUNIFORMBUFFERDEFS__

in DataVS {
	float across;
	float along;
	float alpha;
	float seed;
	float fog;
} vs;

out vec4 fragColor;

void main() {
	float edge = 1.0 - abs(vs.across);
	float profile = edge * edge;
	float wobble = 0.85 + 0.15 * sin(vs.along * 2.7 + vs.seed * 6.2831853);
	float a = trailColor.a * vs.alpha * profile * wobble;
	if (a < 0.002) discard;
	vec3 rgb = mix(fogColor.rgb, trailColor.rgb, vs.fog);
	fragColor = vec4(rgb, a * vs.fog);
}
]]

local function GetShaderSources(engineDefs)
	local vs = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineDefs)
	local fs = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineDefs)
	return vs, fs
end

--------------------------------------------------------------------------------
-- GL setup (only legal inside draw callins)
--------------------------------------------------------------------------------

local function ZeroInstanceBuffer()
	local CHUNK = 1024
	local zeros = {}
	for i = 1, CHUNK * FLOATS_PER_INSTANCE do zeros[i] = 0 end
	local total = MAX_LIVE + RING
	local off = 0
	while off < total do
		local n = min(CHUNK, total - off)
		instVBO:Upload(zeros, -1, off, 1, n * FLOATS_PER_INSTANCE)
		off = off + n
	end
end

local function InitGL()
	local ok, lib = pcall(VFS.Include, "LuaUI/Widgets/Include/LuaShader.lua")
	if not ok or not lib then
		spEcho("[AircraftTrails] LuaShader.lua not found, widget disabled")
		return false
	end
	LuaShader = lib

	local vs, fs = GetShaderSources(LuaShader.GetEngineUniformBufferDefs())
	shader = LuaShader({
		vertex   = vs,
		fragment = fs,
		uniformFloat = {
			gameTime   = 0,
			lifetime   = cfg.lifetime,
			baseWidth  = cfg.baseWidth,
			widthGrow  = cfg.widthGrow,
			trailColor = cfg.color,
		},
	}, "AircraftTrailsGL4")
	if not shader:Initialize() then
		spEcho("[AircraftTrails] shader failed to compile, widget disabled")
		return false
	end

	vertVBO = gl.GetVBO(GL.ARRAY_BUFFER, false)
	vertVBO:Define(4, { { id = 0, name = "uv", size = 2 } })
	vertVBO:Upload({ 0, -1,  1, -1,  1, 1,  0, 1 })

	indexVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false)
	indexVBO:Define(6)
	indexVBO:Upload({ 0, 1, 2,  0, 2, 3 })

	instVBO = gl.GetVBO(GL.ARRAY_BUFFER, true)
	instVBO:Define(MAX_LIVE + RING, {
		{ id = 1, name = "p0t0", size = 4 },
		{ id = 2, name = "p1t1", size = 4 },
		{ id = 3, name = "misc", size = 4 },
	})
	ZeroInstanceBuffer()

	vao = gl.GetVAO()
	vao:AttachVertexBuffer(vertVBO)
	vao:AttachIndexBuffer(indexVBO)
	vao:AttachInstanceBuffer(instVBO)

	shader:Activate()
	shader:SetUniformFloat("lifetime", cfg.lifetime)
	shader:SetUniformFloat("baseWidth", cfg.baseWidth)
	shader:SetUniformFloat("widthGrow", cfg.widthGrow)
	shader:SetUniformFloat("trailColor", cfg.color[1], cfg.color[2], cfg.color[3], cfg.color[4])
	shader:Deactivate()
	return true
end

local function ShutdownGL()
	if shader then shader:Finalize() end
	if vao then vao:Delete() end
	if vertVBO then vertVBO:Delete() end
	if indexVBO then indexVBO:Delete() end
	if instVBO then instVBO:Delete() end
	shader, vao, vertVBO, indexVBO, instVBO = nil, nil, nil, nil, nil
	glReady = false
end

--------------------------------------------------------------------------------
-- Callins
--------------------------------------------------------------------------------

local function RefreshViewState()
	myAllyTeamID = spGetMyAllyTeamID()
	local spec, fv = spGetSpectatingState()
	fullView = (spec and fv) or false
end

function widget:Initialize()
	if not gl.GetVBO or not gl.GetVAO then
		spEcho("[AircraftTrails] GL4 VBO/VAO support missing, widget disabled")
		widgetHandler:RemoveWidget(self)
		return
	end
	RefreshViewState()
	now = spGetGameSeconds() or 0
	SeedUnits()
end

function widget:Shutdown()
	ShutdownGL()
end

function widget:PlayerChanged()
	RefreshViewState()
	for unitID, u in pairs(units) do
		if not IsOwnSide(unitID) then DeactivateUnit(u) end
	end
	SeedUnits()
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	if not IsOwnSide(unitID) then return end
	local u = RegisterUnit(unitID, unitDefID)
	if u then ActivateUnit(unitID, u) end
end

function widget:UnitEnteredLos(unitID, unitTeam, allyTeam, unitDefID)
	local u = RegisterUnit(unitID, unitDefID or spGetUnitDefID(unitID))
	if u then ActivateUnit(unitID, u) end
end

function widget:UnitLeftLos(unitID, unitTeam, allyTeam)
	local u = units[unitID]
	if u and not IsOwnSide(unitID) then DeactivateUnit(u) end
end

function widget:UnitDestroyed(unitID)
	RemoveUnit(unitID)
end

function widget:UnitTaken(unitID, unitDefID)
	RemoveUnit(unitID)
end

function widget:UnitGiven(unitID, unitDefID)
	RemoveUnit(unitID)
	if IsOwnSide(unitID) then
		local u = RegisterUnit(unitID, unitDefID)
		if u then ActivateUnit(unitID, u) end
	end
end

function widget:Update()
	if not glReady then return end
	now = spGetGameSeconds() or now
	SampleDue()
	FlushRing()
	RefreshLiveHeads()
end

function widget:DrawWorldPreUnit()
	if glReady then return end
	if not InitGL() then
		widgetHandler:RemoveWidget(self)
		return
	end
	glReady = true
end

function widget:DrawWorld()
	if not glReady then return end
	local ringUsed = min(ringWritten, RING)
	local total = MAX_LIVE + ringUsed
	if liveCount == 0 and ringUsed == 0 then return end

	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	gl.DepthTest(true)
	gl.DepthMask(false)
	gl.Culling(false)
	shader:Activate()
	shader:SetUniformFloat("gameTime", now)
	vao:DrawElements(GL.TRIANGLES, 6, 0, total, 0)
	shader:Deactivate()
	gl.DepthMask(true)
	gl.DepthTest(false)
end

function widget:TextCommand(command)
	if command == "airtrails_debug" then
		spEcho(string.format(
			"[AircraftTrails] active=%d heap=%d massMul=%.2f ring=%d/%d live=%d samples=%d segments=%d uploads=%d dormantPolls=%d",
			activeCount, heapCount, massMul, min(ringWritten, RING), RING, liveCount,
			statSamples, statSegments, statUploads, statDormantPolls))
		return true
	end
end

--------------------------------------------------------------------------------
-- Test hooks (stubbed-engine smoke tests only)
--------------------------------------------------------------------------------

widget.__trailsTest = {
	cfg              = cfg,
	units            = units,
	defCache         = defCache,
	GetDefInfo       = GetDefInfo,
	RegisterUnit     = RegisterUnit,
	ActivateUnit     = ActivateUnit,
	GetShaderSources = GetShaderSources,
	SetGLReady       = function(v) glReady = v end,
	GetRingState     = function() return ringCursor, ringWritten end,
	GetLiveState     = function() return liveCount, liveScratch end,
	GetHeapCount     = function() return heapCount end,
	GetActiveCount   = function() return activeCount, massMul end,
	GetStats         = function() return statSamples, statSegments, statUploads, statDormantPolls end,
	PoolSize         = function() return #emitterPool end,
}
