function widget:GetInfo()
	return {
		name      = "Aircraft Trails GL4",
		desc      = "Wingtip vortex ribbons for aircraft. Per-unitdef emitter pieces via customparams.trail_pieces, GL4 instanced ribbon renderer.",
		author    = "SplinterFaction",
		date      = "2026-09-09",
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
--------------------------------------------------------------------------------

local cfg = {
	lifetime          = 0.9,    -- seconds a stored point stays visible
	points            = 24,     -- ring buffer size per emitter
	maxPieces         = 8,      -- hard cap on emitters per unit
	minSpeedFrac      = 0.35,   -- fraction of unitdef max speed where trails begin
	fullSpeedFrac     = 0.85,   -- fraction of max speed for full speed factor
	turnFullDegPerSec = 110,    -- turn rate that gives full turn factor
	turnSmoothing     = 14,     -- higher = snappier response to turn changes
	baseIntensity     = 0.25,   -- intensity while flying straight (times speed factor)
	minIntensity      = 0.06,   -- below this the emitter goes quiet and the run breaks
	minAltitude       = 25,     -- elmos above ground before trails appear
	minSpacing        = 1.5,    -- elmos between stored points
	baseWidth         = 3.0,    -- ribbon half-width at birth
	widthGrow         = 1.2,    -- extra width fraction at end of life
	color             = { 1.0, 1.0, 1.0, 0.55 },
	fallbackTipFrac   = 0.8,    -- fallback tip offset = radius * this
	maxInstances      = 4096,   -- hard cap on ribbon segments per frame
	sweepFrames       = 30,     -- GameFrame interval for stale unit sweep
}

--------------------------------------------------------------------------------

local spGetUnitPiecePosDir  = Spring.GetUnitPiecePosDir
local spGetUnitPieceMap     = Spring.GetUnitPieceMap
local spGetUnitVelocity     = Spring.GetUnitVelocity
local spGetUnitViewPosition = Spring.GetUnitViewPosition
local spGetUnitVectors      = Spring.GetUnitVectors
local spGetGroundHeight     = Spring.GetGroundHeight
local spIsUnitInView        = Spring.IsUnitInView
local spValidUnitID         = Spring.ValidUnitID
local spGetUnitDefID        = Spring.GetUnitDefID
local spGetAllUnits         = Spring.GetAllUnits
local spEcho                = Spring.Echo

local sqrt  = math.sqrt
local acos  = math.acos
local min   = math.min
local max   = math.max
local floor = math.floor

local POINTS      = cfg.points
local TURN_FULL   = math.rad(cfg.turnFullDegPerSec)
local FLOATS_PER_INSTANCE = 12

local defCache    = {}   -- unitDefID -> def info table, or false
local units       = {}   -- unitID -> unit state
local emitterPool = {}   -- recycled emitter tables
local warned      = {}   -- one-shot warning keys
local now         = 0    -- widget-local clock in seconds

local instanceData  = {} -- flat float table, reused
local instanceCount = 0

local shader, vao, vertVBO, indexVBO, instVBO
local LuaShader
local glReady = false   -- GL objects are created lazily in the first draw callin

--------------------------------------------------------------------------------
-- Small helpers
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
		local maxSpeed = (ud.speed or 0) / 30 -- unitdef speed is elmo/sec, velocity is elmo/frame
		info.minSpeed  = maxSpeed * cfg.minSpeedFrac
		info.fullSpeed = maxSpeed * cfg.fullSpeedFrac
		if info.fullSpeed <= info.minSpeed then
			info.fullSpeed = info.minSpeed + 0.01
		end
		info.width = tonumber(cp.trail_width) or cfg.baseWidth
		info.resolved = nil -- piece indices, filled on first sampled unit
	end

	defCache[unitDefID] = info
	return info
end

-- Piece names -> piece indices. Needs a live unitID for the piece map.
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
	local e = table.remove(emitterPool)
	if not e then
		e = { px = {}, py = {}, pz = {}, bt = {}, it = {}, brk = {} }
	end
	e.piece   = piece
	e.weight  = weight
	e.offset  = offset
	e.seed    = seed
	e.head    = 0
	e.count   = 0
	e.brkNext = true
	e.hasLive = false
	e.lx, e.ly, e.lz, e.li = 0, 0, 0, 0
	return e
end

local function ReleaseEmitter(e)
	e.count = 0
	e.hasLive = false
	emitterPool[#emitterPool + 1] = e
end

local function Quiet(e)
	e.hasLive = false
	e.brkNext = true
end

local function Feed(e, x, y, z, inten)
	if inten < cfg.minIntensity then
		Quiet(e)
		return
	end

	e.hasLive = true
	e.lx, e.ly, e.lz, e.li = x, y, z, inten

	if e.count > 0 and not e.brkNext then
		local h = e.head
		local dx, dy, dz = x - e.px[h], y - e.py[h], z - e.pz[h]
		if dx * dx + dy * dy + dz * dz < cfg.minSpacing * cfg.minSpacing then
			return
		end
	end

	local h = (e.head % POINTS) + 1
	e.px[h], e.py[h], e.pz[h] = x, y, z
	e.bt[h]  = now
	e.it[h]  = inten
	e.brk[h] = e.brkNext
	e.brkNext = false
	e.head  = h
	e.count = min(e.count + 1, POINTS)
end

local function Prune(e)
	local lifetime = cfg.lifetime
	while e.count > 0 do
		local oldest = ((e.head - e.count) % POINTS) + 1
		if now - e.bt[oldest] > lifetime then
			e.count = e.count - 1
		else
			break
		end
	end
end

--------------------------------------------------------------------------------
-- Unit tracking and sampling
--------------------------------------------------------------------------------

local function RegisterUnit(unitID, unitDefID)
	if units[unitID] then
		return
	end
	local info = GetDefInfo(unitDefID)
	if not info then
		return
	end
	units[unitID] = {
		info     = info,
		emitters = nil,
		alive    = true,
		turn     = 0,
		pdx = nil, pdy = nil, pdz = nil,
	}
end

local function EnsureEmitters(unitID, u)
	if u.emitters then
		return u.emitters
	end
	local info = u.info
	local list = {}
	if info.fallback then
		list[1] = NewEmitter(nil, 1.0, -info.tipOffset, (unitID % 89) * 0.011)
		list[2] = NewEmitter(nil, 1.0,  info.tipOffset, (unitID % 89) * 0.011 + 0.5)
	else
		local res = ResolvePieces(info, unitID)
		if not res then
			return nil
		end
		for i, r in ipairs(res) do
			list[i] = NewEmitter(r.piece, r.weight, 0, (unitID % 89) * 0.011 + i * 0.137)
		end
	end
	u.emitters = list
	return list
end

local function QuietAll(u)
	if not u.emitters then return end
	for i = 1, #u.emitters do
		Quiet(u.emitters[i])
	end
end

local function SampleUnit(unitID, u, dt)
	local info = u.info

	local vx, vy, vz = spGetUnitVelocity(unitID)
	if not vx then
		QuietAll(u)
		return
	end

	local speed = sqrt(vx * vx + vy * vy + vz * vz)

	-- turn factor from heading change, smoothed
	local turnTarget = 0
	if speed > 1e-3 then
		local dx, dy, dz = vx / speed, vy / speed, vz / speed
		if u.pdx and dt > 0 then
			local dot = clamp(dx * u.pdx + dy * u.pdy + dz * u.pdz, -1, 1)
			local rate = acos(dot) / dt
			turnTarget = clamp(rate / TURN_FULL, 0, 1)
		end
		u.pdx, u.pdy, u.pdz = dx, dy, dz
	else
		u.pdx = nil
	end
	local k = min(1, dt * cfg.turnSmoothing)
	u.turn = u.turn + (turnTarget - u.turn) * k

	local speedFactor = clamp((speed - info.minSpeed) / (info.fullSpeed - info.minSpeed), 0, 1)
	local intensity = speedFactor * (cfg.baseIntensity + (1 - cfg.baseIntensity) * u.turn)

	-- GetUnitViewPosition returns a single position; true selects the mid position
	local mx, my, mz = spGetUnitViewPosition(unitID, true)
	if not mx then
		QuietAll(u)
		return
	end
	if my - spGetGroundHeight(mx, mz) < cfg.minAltitude then
		intensity = 0
	end

	local emitters = EnsureEmitters(unitID, u)
	if not emitters then
		return
	end

	if info.fallback then
		local _, _, right = spGetUnitVectors(unitID)
		if not right then
			QuietAll(u)
			return
		end
		for i = 1, #emitters do
			local e = emitters[i]
			local o = e.offset
			Feed(e, mx + right[1] * o, my + right[2] * o, mz + right[3] * o, intensity * e.weight)
		end
	else
		for i = 1, #emitters do
			local e = emitters[i]
			local x, y, z = spGetUnitPiecePosDir(unitID, e.piece)
			if x then
				Feed(e, x, y, z, intensity * e.weight)
			else
				Quiet(e)
			end
		end
	end
end

local function SampleAll(dt)
	for unitID, u in pairs(units) do
		if u.alive then
			if spIsUnitInView(unitID) then
				SampleUnit(unitID, u, dt)
			else
				QuietAll(u)
				u.pdx = nil
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Instance building
--------------------------------------------------------------------------------

local function PushSegment(d, n, e, i, j, x1, y1, z1, age1, i1, runIdx)
	d[n + 1]  = e.px[i]
	d[n + 2]  = e.py[i]
	d[n + 3]  = e.pz[i]
	d[n + 4]  = now - e.bt[i]
	d[n + 5]  = x1
	d[n + 6]  = y1
	d[n + 7]  = z1
	d[n + 8]  = age1
	d[n + 9]  = e.it[i]
	d[n + 10] = i1
	d[n + 11] = e.seed
	d[n + 12] = runIdx
	return n + FLOATS_PER_INSTANCE
end

local function BuildInstances()
	local d = instanceData
	local n = 0
	local count = 0
	local cap = cfg.maxInstances

	for unitID, u in pairs(units) do
		local emitters = u.emitters
		local live = 0
		if emitters then
			for ei = 1, #emitters do
				local e = emitters[ei]
				Prune(e)
				local c = e.count
				if c > 0 then
					live = live + c
					local runIdx = 0
					for k = 0, c - 2 do
						if count >= cap then break end
						local i = ((e.head - c + k) % POINTS) + 1
						local j = (i % POINTS) + 1
						if not e.brk[j] then
							n = PushSegment(d, n, e, i, j,
							                e.px[j], e.py[j], e.pz[j], now - e.bt[j], e.it[j], runIdx)
							count = count + 1
						end
						runIdx = runIdx + 1
					end
					if e.hasLive and u.alive and count < cap then
						n = PushSegment(d, n, e, e.head, 0,
						                e.lx, e.ly, e.lz, 0, e.li, runIdx)
						count = count + 1
					end
				end
			end
		end

		if not u.alive and live == 0 then
			if emitters then
				for ei = 1, #emitters do
					ReleaseEmitter(emitters[ei])
				end
			end
			units[unitID] = nil
		end
	end

	instanceCount = count
	return count, n
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
layout (location = 1) in vec4 p0age0;  // xyz: segment start, w: age in seconds
layout (location = 2) in vec4 p1age1;  // xyz: segment end,   w: age in seconds
layout (location = 3) in vec4 misc;    // x: intensity0, y: intensity1, z: seed, w: run index

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
	vec3 p0 = p0age0.xyz;
	vec3 p1 = p1age1.xyz;
	float age = mix(p0age0.w, p1age1.w, uv.x);
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
-- GL setup
--------------------------------------------------------------------------------

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
	instVBO:Define(cfg.maxInstances, {
		{ id = 1, name = "p0age0", size = 4 },
		{ id = 2, name = "p1age1", size = 4 },
		{ id = 3, name = "misc",   size = 4 },
	})

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

function widget:Initialize()
	if not gl.GetVBO or not gl.GetVAO then
		spEcho("[AircraftTrails] GL4 VBO/VAO support missing, widget disabled")
		widgetHandler:RemoveWidget(self)
		return
	end
	-- Shader compile and UseShader are only legal inside draw callins,
	-- so GL setup happens on the first DrawWorldPreUnit instead.
	for _, unitID in ipairs(spGetAllUnits()) do
		local udid = spGetUnitDefID(unitID)
		if udid then
			RegisterUnit(unitID, udid)
		end
	end
end

function widget:Shutdown()
	ShutdownGL()
end

function widget:UnitCreated(unitID, unitDefID)
	RegisterUnit(unitID, unitDefID)
end

function widget:UnitEnteredLos(unitID, unitTeam, allyTeam, unitDefID)
	RegisterUnit(unitID, unitDefID or spGetUnitDefID(unitID))
end

function widget:UnitDestroyed(unitID)
	local u = units[unitID]
	if u then
		u.alive = false
		QuietAll(u)
	end
end

function widget:PlayerChanged()
	for _, unitID in ipairs(spGetAllUnits()) do
		local udid = spGetUnitDefID(unitID)
		if udid then
			RegisterUnit(unitID, udid)
		end
	end
end

function widget:GameFrame(f)
	if f % cfg.sweepFrames ~= 0 then return end
	for unitID, u in pairs(units) do
		if u.alive and not spValidUnitID(unitID) then
			u.alive = false
			QuietAll(u)
		end
	end
end

function widget:Update(dt)
	now = now + dt
	SampleAll(dt)
end

function widget:DrawWorldPreUnit()
	if not glReady then
		if not InitGL() then
			widgetHandler:RemoveWidget(self)
			return
		end
		glReady = true
	end
	local count, n = BuildInstances()
	if count > 0 then
		instVBO:Upload(instanceData, -1, 0, 1, n)
	end
end

function widget:DrawWorld()
	if not glReady or instanceCount == 0 then return end
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	gl.DepthTest(true)
	gl.DepthMask(false)
	gl.Culling(false)
	shader:Activate()
	vao:DrawElements(GL.TRIANGLES, 6, 0, instanceCount, 0)
	shader:Deactivate()
	gl.DepthMask(true)
	gl.DepthTest(false)
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
	SampleAll        = SampleAll,
	BuildInstances   = BuildInstances,
	GetShaderSources = GetShaderSources,
	GetInstanceData  = function() return instanceData, instanceCount end,
	SetNow           = function(t) now = t end,
	GetNow           = function() return now end,
	PoolSize         = function() return #emitterPool end,
}