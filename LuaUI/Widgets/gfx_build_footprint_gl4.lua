--------------------------------------------------------------------------------
-- gfx_build_footprint_gl4.lua
--
-- Replaces the engine's flat green/yellow/red build-placement grid (and the old
-- fixed-function facing arrow) with a GL4 instanced, terrain-conforming
-- footprint display:
--
--   * one instance per footprint cell, coloured by the engine's per-square
--     buildability status, with an animated scan sweep in the facing direction
--     and moving hatch stripes on blocked / occupied cells
--   * one "frame" instance per footprint: outline, corner brackets, soft outer
--     glow, spawn shock-ring, and a pulsing chevron on the facing side
--   * ease-in when placement starts, fade-out when it ends
--
-- Engine hooks (verified against Recoil master, rts/Rendering/Units/UnitDrawer.cpp):
--   Spring.SetEngineBuildSquareRendering(false)  -- suppress stock grid
--   DrawBuildSquare(unitDefID, x, z, facing, statuses)  -- unsynced callin fired
--     once per pending footprint from CUnitDrawerGLSL::ShowUnitBuildSquare.
--     statuses is a flat, row-major table (z outer, x inner), one entry per
--     footprint square: 0 blocked, 1 occupied, 2 reclaimable, 3 open.
--     NOTE: it can fire twice per frame (world pass + minimap pass) with the
--     same arguments, so we dedupe by key.
--
-- Requires widgets_custom.lua to forward the DrawBuildSquare callin (see the
-- accompanying handler patch: 'DrawBuildSquare' in flexCallIns + forwarder).
--
-- No LuaUI include dependencies: shader, VBOs and VAOs are built directly with
-- gl.CreateShader / gl.GetVBO / gl.GetVAO. Engine uniform buffers are pulled
-- in with gl.GetEngineUniformBufferDef.
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name    = "Build Footprint GL4",
		desc    = "Terrain-conforming animated build placement footprint + facing chevron",
		author  = "Scary le Poo",
		date    = "2026",
		license = "GNU GPL v2",
		layer   = 0,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

local CFG = {
	accent        = { 0.45, 0.92, 0.55 }, -- soft green: "can build" (open cells, frame, chevron)
	reclaimable   = { 1.00, 0.78, 0.22 },
	occupied      = { 1.00, 0.48, 0.16 },
	blocked       = { 1.00, 0.16, 0.22 },

	cellBase      = 0.62,  -- filled square size as fraction of the 8-elmo cell (buildable)
	cellBreathe   = 0.05,  -- breathing amplitude (buildable)
	cellFreq      = 2.4,   -- breathing rate, rad/s (buildable)
	badBase       = 0.80,  -- blocked cells: larger ...
	badBreathe    = 0.11,  -- ... and breathe harder ...
	badFreq       = 6.5,   -- ... and faster
	frameMargin   = 56,    -- elmos of extra quad around the footprint for glow + chevron
	frameSubdiv   = 16,    -- terrain-conforming subdivision of the frame quad
	groundLift    = 1.5,   -- elmos above heightmap
	fadeInTime    = 0.18,  -- seconds
	fadeOutTime   = 0.22,  -- seconds
	maxInstances  = 4096,  -- cells across all pending footprints (shift-drag lines)
	maxFrames     = 256,
}

--------------------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------------------

local SQUARE_SIZE = 8

local spGetTimer        = Spring.GetTimer
local spTestBuildOrder  = Spring.TestBuildOrder
local spGetGroundHeight = Spring.GetGroundHeight
local spDiffTimers      = Spring.DiffTimers
local floor             = math.floor

local glCreateShader    = gl.CreateShader
local glDeleteShader    = gl.DeleteShader
local glUseShader       = gl.UseShader
local glGetUniformLocation = gl.GetUniformLocation
local glUniform         = gl.Uniform
local glGetVBO          = gl.GetVBO
local glGetVAO          = gl.GetVAO
local glTexture         = gl.Texture
local glDepthTest       = gl.DepthTest
local glDepthMask       = gl.DepthMask
local glBlending        = gl.Blending
local glCulling         = gl.Culling

local GL_ARRAY_BUFFER         = GL.ARRAY_BUFFER
local GL_ELEMENT_ARRAY_BUFFER = GL.ELEMENT_ARRAY_BUFFER
local GL_TRIANGLES            = GL.TRIANGLES
local GL_SRC_ALPHA            = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA  = GL.ONE_MINUS_SRC_ALPHA

-- GPU state
local shader
local uNowLoc, uAccentLoc, uReclaimLoc, uOccupiedLoc, uBlockedLoc, uLiftLoc, uCellOKLoc, uCellBadLoc
local cellVAO, cellInstVBO, cellIdxCount
local frameVAO, frameInstVBO, frameIdxCount

-- Runtime state, consolidated (Lua 5.1 200-local limit)
local S = {
	t0            = nil,      -- Spring timer at Initialize
	pending       = {},       -- footprints received since last draw, keyed
	pendingCount  = 0,
	active        = {},       -- last drawn footprint set
	activeCount   = 0,
	sessionDefID  = nil,      -- unitDefID of current placement session
	sessionStart  = 0,        -- time placement started (for ease-in)
	lastSeen      = -1,       -- time a footprint was last received
	dying         = false,    -- fade-out in progress
	dieStart      = 0,
	cellData      = {},       -- flat float array, reused
	frameData     = {},
}

-- Instance layout (12 floats = 48 bytes per instance), shared by both VAOs:
--   attr1: rectCenterX, rectCenterZ, rectSizeX, rectSizeZ   (elmos)
--   attr2: mode (0 cell / 1 frame), status, facing, spawnTime
--   attr3: cell -> cellU, cellV, alpha, unused
--          frame -> halfX, halfZ, alpha, unused
local INSTANCE_FLOATS = 12

--------------------------------------------------------------------------------
-- Shaders
--------------------------------------------------------------------------------

local vsSrc = [[
#version 420
#line 10000

//__ENGINEUNIFORMBUFFERDEFS__

layout (location = 0) in vec2 meshUV;   // 0..1 over the instance rect
layout (location = 1) in vec4 iRect;    // cx, cz, sx, sz
layout (location = 2) in vec4 iInfo;    // mode, status, facing, spawnT
layout (location = 3) in vec4 iAux;     // cell: cellU, cellV, alpha, -  | frame: hx, hz, alpha, -

uniform sampler2D heightmapTex;
uniform float uLift;

out vec2 vUV;
out vec2 vLocal;        // elmos, centred on rect
flat out vec4 vRect;
flat out vec4 vInfo;
flat out vec4 vAux;

// $heightmap has (mapx+1) x (mapy+1) texels; texel i is centred on world x = i*8
vec2 heightmapUV(vec2 w) {
	return (w + vec2(4.0)) / (mapSize.xy + vec2(8.0));
}

void main() {
	vec2 local = (meshUV - vec2(0.5)) * iRect.zw;
	vec2 wxz   = iRect.xy + local;
	float h    = textureLod(heightmapTex, heightmapUV(wxz), 0.0).x;

	vUV    = meshUV;
	vLocal = local;
	vRect  = iRect;
	vInfo  = iInfo;
	vAux   = iAux;

	gl_Position = cameraViewProj * vec4(wxz.x, h + uLift, wxz.y, 1.0);
}
]]

local fsSrc = [[
#version 420
#line 20000

//__ENGINEUNIFORMBUFFERDEFS__

uniform float uNow;
uniform vec3 uAccent;
uniform vec3 uReclaim;
uniform vec3 uOccupied;
uniform vec3 uBlocked;
uniform vec4 uCellOK;    // base, breathe, freq, -
uniform vec4 uCellBad;

in vec2 vUV;
in vec2 vLocal;
flat in vec4 vRect;
flat in vec4 vInfo;
flat in vec4 vAux;

out vec4 fragColor;

vec3 statusColor(float s) {
	if (s > 2.5) return uAccent;
	if (s > 1.5) return uReclaim;
	if (s > 0.5) return uOccupied;
	return uBlocked;
}

// forward direction for engine build facing: 0 south(+z) 1 east(+x) 2 north(-z) 3 west(-x)
vec2 forwardDir(float f) {
	int fi = int(f + 0.5);
	if (fi == 0) return vec2( 0.0,  1.0);
	if (fi == 1) return vec2( 1.0,  0.0);
	if (fi == 2) return vec2( 0.0, -1.0);
	return vec2(-1.0, 0.0);
}

float band(float x, float w) {          // 1 at x=0 falling to 0 at |x|=w
	return 1.0 - smoothstep(0.0, w, abs(x));
}

void main() {
	float mode   = vInfo.x;
	float status = vInfo.y;
	float facing = vInfo.z;
	float age    = max(uNow - vInfo.w, 0.0);
	float alpha  = vAux.z;
	vec2  fwd    = forwardDir(facing);

	vec3  col = vec3(0.0);
	float a   = 0.0;

	if (mode < 0.5) {
		// ---------------------------------------------------------------- cell
		// position of this cell along the facing axis, 0 (back) .. 1 (front)
		vec2  cuv   = vAux.xy;
		float along = dot(cuv - vec2(0.5), fwd) + 0.5;
		bool  bad   = status < 1.5;
		vec4  cp    = bad ? uCellBad : uCellOK;

		// staggered spawn: cells grow from their centre, back to front
		float k = clamp((age - along * 0.12) * 7.0, 0.0, 1.0);
		if (k <= 0.001) discard;

		// breathing: size ripples through the footprint in the facing direction
		float breath = sin(uNow * cp.z - along * 2.2 + cuv.x * 0.7);
		float size   = (cp.x + cp.y * breath) * k;          // fraction of cell
		float hs     = size * 0.5;

		// rounded filled square (SDF in cell-uv space, 1 uv = 8 elmo)
		vec2  d  = abs(vUV - vec2(0.5)) - vec2(hs - 0.07);
		float sd = length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - 0.07;
		float fillMask = 1.0 - smoothstep(-0.05, 0.02, sd);
		if (fillMask <= 0.002) discard;

		// gentle scan sweep travelling in the facing direction
		float p     = fract(along * 0.9 - uNow * 0.55);
		float sweep = smoothstep(0.0, 0.18, p) * (1.0 - smoothstep(0.18, 0.55, p));

		vec3  base  = statusColor(status);
		float glowB = 0.5 + 0.5 * breath;                    // brighter at full inhale
		float lum   = 0.55 + 0.25 * glowB + 0.35 * sweep + (bad ? 0.35 * glowB : 0.0);
		col = base * lum + vec3(0.12) * sweep;
		a   = fillMask * (0.42 + 0.18 * glowB + 0.2 * sweep + (bad ? 0.2 : 0.0));
	} else {
		// --------------------------------------------------------------- frame
		vec2  hs   = vAux.xy;                                      // footprint half extents
		vec2  q    = abs(vLocal) - hs;
		float dOut = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0); // signed dist to rect

		vec3  base = statusColor(status);
		float spawn = clamp(age * 5.0, 0.0, 1.0);

		// outline + heavier corner brackets
		float outline = band(dOut, 1.4);
		float bl      = max(min(hs.x, hs.y) * 0.45, 10.0);
		float corner  = max(step(hs.x - bl, abs(vLocal.x)), step(hs.y - bl, abs(vLocal.y)));
		float bracket = band(dOut, 3.0) * corner;

		// soft glow outside the rect, breathing slowly
		float breathe = 0.85 + 0.15 * sin(uNow * 2.2);
		float glow    = (dOut > 0.0) ? exp(-dOut / 12.0) * 0.32 * breathe : 0.0;

		// spawn shock ring expanding outward
		float ring = 0.0;
		if (age < 0.55) {
			float r = age * 140.0;
			ring = band(dOut - r, 5.0) * (1.0 - age / 0.55) * 0.9;
		}

		// facing chevrons in front of the footprint
		float frontEdge = (mod(facing, 2.0) < 0.5) ? hs.y : hs.x;   // extent along the facing axis
		float along  = dot(vLocal, fwd);
		float across = dot(vLocal, vec2(-fwd.y, fwd.x));
		float chevW  = clamp(min(hs.x, hs.y) * 0.7, 10.0, 40.0);
		float chev   = 0.0;
		for (int i = 0; i < 2; i++) {
			float c   = frontEdge + 16.0 + float(i) * 13.0;
			float v   = (along - c) + abs(across) * 0.75;           // V pointing forward
			float lim = step(abs(across), chevW) * step(along, c + 1.0);
			chev += band(v, 2.6) * lim;
		}
		float travel = 0.55 + 0.45 * sin(uNow * 7.0 - along * 0.35);
		chev = clamp(chev, 0.0, 1.0) * travel * spawn;

		float lum = outline * 0.95 + bracket * 1.2 + glow + ring + chev * 1.15;
		col = base * lum + vec3(0.3) * (bracket * 0.4 + ring * 0.5 + chev * 0.35);
		a   = clamp(outline * 0.85 + bracket + glow + ring + chev, 0.0, 1.0) * spawn;
	}

	a *= alpha;
	if (a < 0.004) discard;
	fragColor = vec4(col, a);
}
]]

--------------------------------------------------------------------------------
-- GPU setup
--------------------------------------------------------------------------------

local function makeGridMesh(subdiv)
	local verts, idx = {}, {}
	for j = 0, subdiv do
		for i = 0, subdiv do
			verts[#verts + 1] = i / subdiv
			verts[#verts + 1] = j / subdiv
		end
	end
	local stride = subdiv + 1
	for j = 0, subdiv - 1 do
		for i = 0, subdiv - 1 do
			local a = j * stride + i
			local b = a + 1
			local c = a + stride
			local d = c + 1
			idx[#idx + 1] = a; idx[#idx + 1] = c; idx[#idx + 1] = b
			idx[#idx + 1] = b; idx[#idx + 1] = c; idx[#idx + 1] = d
		end
	end
	local vbo = glGetVBO(GL_ARRAY_BUFFER, false)
	vbo:Define(#verts / 2, { { id = 0, name = "meshUV", size = 2 } })
	vbo:Upload(verts)
	local ibo = glGetVBO(GL_ELEMENT_ARRAY_BUFFER, false)
	ibo:Define(#idx)
	ibo:Upload(idx)
	return vbo, ibo, #idx
end

local function makeInstanceVBO(maxInstances)
	local vbo = glGetVBO(GL_ARRAY_BUFFER, true)
	vbo:Define(maxInstances, {
		{ id = 1, name = "iRect", size = 4 },
		{ id = 2, name = "iInfo", size = 4 },
		{ id = 3, name = "iAux",  size = 4 },
	})
	return vbo
end

local function initGL()
	local ubo0 = gl.GetEngineUniformBufferDef(0)
	local ubo1 = gl.GetEngineUniformBufferDef(1)
	if not ubo0 or not ubo1 then
		Spring.Echo("[BuildFootprintGL4] engine uniform buffer defs unavailable (no GL4?)")
		return false
	end
	local defs = ubo0 .. "\n" .. ubo1
	local vs = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", defs)
	local fs = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", defs)

	shader = glCreateShader({
		vertex   = vs,
		fragment = fs,
		uniformInt = { heightmapTex = 0 },
	})
	if not shader then
		Spring.Echo("[BuildFootprintGL4] shader compile failed: " .. tostring(gl.GetShaderLog()))
		return false
	end
	uNowLoc      = glGetUniformLocation(shader, "uNow")
	uAccentLoc   = glGetUniformLocation(shader, "uAccent")
	uReclaimLoc  = glGetUniformLocation(shader, "uReclaim")
	uOccupiedLoc = glGetUniformLocation(shader, "uOccupied")
	uBlockedLoc  = glGetUniformLocation(shader, "uBlocked")
	uLiftLoc     = glGetUniformLocation(shader, "uLift")
	uCellOKLoc   = glGetUniformLocation(shader, "uCellOK")
	uCellBadLoc  = glGetUniformLocation(shader, "uCellBad")

	local cellMesh, cellIbo
	cellMesh, cellIbo, cellIdxCount = makeGridMesh(1)
	cellInstVBO = makeInstanceVBO(CFG.maxInstances)
	cellVAO = glGetVAO()
	cellVAO:AttachVertexBuffer(cellMesh)
	cellVAO:AttachIndexBuffer(cellIbo)
	cellVAO:AttachInstanceBuffer(cellInstVBO)

	local frameMesh, frameIbo
	frameMesh, frameIbo, frameIdxCount = makeGridMesh(CFG.frameSubdiv)
	frameInstVBO = makeInstanceVBO(CFG.maxFrames)
	frameVAO = glGetVAO()
	frameVAO:AttachVertexBuffer(frameMesh)
	frameVAO:AttachIndexBuffer(frameIbo)
	frameVAO:AttachInstanceBuffer(frameInstVBO)
	return true
end

--------------------------------------------------------------------------------
-- Footprint bookkeeping
--------------------------------------------------------------------------------

local function now()
	return spDiffTimers(spGetTimer(), S.t0)
end

-- Footprint sizes as the engine sees them (BuildInfo::GetXSize swaps on odd facing)
local function footprintSize(unitDefID, facing)
	local ud = UnitDefs[unitDefID]
	if not ud then return 0, 0 end
	if facing % 2 == 0 then
		return ud.xsize, ud.zsize
	end
	return ud.zsize, ud.xsize
end

-- Callin from the engine (via widget handler). May fire twice per frame.
function widget:DrawBuildSquare(unitDefID, x, z, facing, statuses)
	local key = unitDefID .. ":" .. x .. ":" .. z .. ":" .. facing
	if S.pending[key] then return end
	local nx, nz = footprintSize(unitDefID, facing)
	if nx == 0 or #statuses ~= nx * nz then return end
	-- Whole-footprint rules (geothermal vents, water/land restrictions, ...) are
	-- not reflected in the per-square statuses, so ask the engine separately.
	-- TestBuildOrder: 0 blocked, 1 feature in the way (reclaimable), 2 ok.
	local overall = spTestBuildOrder(unitDefID, x, spGetGroundHeight(x, z), z, facing)
	S.pending[key] = {
		defID = unitDefID, x = x, z = z, facing = facing,
		nx = nx, nz = nz, statuses = statuses, overall = overall,
	}
	S.pendingCount = S.pendingCount + 1

	local t = now()
	if S.sessionDefID ~= unitDefID or S.dying then
		S.sessionDefID = unitDefID
		S.sessionStart = t
		S.dying = false
	end
	S.lastSeen = t
end

-- Fill the flat instance arrays from a footprint set. Pure; used by the smoke test.
local function buildInstances(footprints, alpha, spawnT, cellOut, frameOut)
	local ci, fi = 0, 0
	local nCells, nFrames = 0, 0
	for _, fp in pairs(footprints) do
		local nx, nz = fp.nx, fp.nz
		-- engine cell origin: sx1 = int(pos.x / 8) - (numX >> 1)
		local sx1 = floor(fp.x / SQUARE_SIZE) - floor(nx / 2)
		local sz1 = floor(fp.z / SQUARE_SIZE) - floor(nz / 2)
		local allOK = 1
		local st = fp.statuses
		local forceBlocked = (fp.overall == 0)
		for zi = 0, nz - 1 do
			for xi = 0, nx - 1 do
				local status = st[zi * nx + xi + 1]
				if forceBlocked then status = 0 end
				if status < 2 then allOK = 0 end
				if nCells < CFG.maxInstances then
					cellOut[ci + 1]  = (sx1 + xi) * SQUARE_SIZE + SQUARE_SIZE * 0.5
					cellOut[ci + 2]  = (sz1 + zi) * SQUARE_SIZE + SQUARE_SIZE * 0.5
					cellOut[ci + 3]  = SQUARE_SIZE
					cellOut[ci + 4]  = SQUARE_SIZE
					cellOut[ci + 5]  = 0            -- mode: cell
					cellOut[ci + 6]  = status
					cellOut[ci + 7]  = fp.facing
					cellOut[ci + 8]  = spawnT
					cellOut[ci + 9]  = (xi + 0.5) / nx
					cellOut[ci + 10] = (zi + 0.5) / nz
					cellOut[ci + 11] = alpha
					cellOut[ci + 12] = 0
					ci = ci + INSTANCE_FLOATS
					nCells = nCells + 1
				end
			end
		end
		if nFrames < CFG.maxFrames then
			local hx = nx * SQUARE_SIZE * 0.5
			local hz = nz * SQUARE_SIZE * 0.5
			local cx = (sx1 * SQUARE_SIZE) + hx
			local cz = (sz1 * SQUARE_SIZE) + hz
			frameOut[fi + 1]  = cx
			frameOut[fi + 2]  = cz
			frameOut[fi + 3]  = (hx + CFG.frameMargin) * 2
			frameOut[fi + 4]  = (hz + CFG.frameMargin) * 2
			frameOut[fi + 5]  = 1               -- mode: frame
			frameOut[fi + 6]  = allOK == 1 and 3 or 0
			frameOut[fi + 7]  = fp.facing
			frameOut[fi + 8]  = spawnT
			frameOut[fi + 9]  = hx
			frameOut[fi + 10] = hz
			frameOut[fi + 11] = alpha
			frameOut[fi + 12] = 0
			fi = fi + INSTANCE_FLOATS
			nFrames = nFrames + 1
		end
	end
	return nCells, nFrames
end

-- Decide what to draw this frame and with what alpha. Pure; used by the smoke test.
local function frameState(t)
	if S.pendingCount > 0 then
		S.active, S.activeCount = S.pending, S.pendingCount
		S.pending, S.pendingCount = {}, 0
		S.dying = false
		local fade = math.min((t - S.sessionStart) / CFG.fadeInTime, 1)
		return S.active, fade
	end
	if S.activeCount == 0 then return nil, 0 end
	if not S.dying then
		S.dying = true
		S.dieStart = t
	end
	local k = 1 - (t - S.dieStart) / CFG.fadeOutTime
	if k <= 0 then
		S.active, S.activeCount = {}, 0
		S.dying = false
		S.sessionDefID = nil
		return nil, 0
	end
	return S.active, k
end

--------------------------------------------------------------------------------
-- Callins
--------------------------------------------------------------------------------

function widget:Initialize()
	S.t0 = spGetTimer()
	if not Spring.SetEngineBuildSquareRendering then
		Spring.Echo("[BuildFootprintGL4] engine too old: Spring.SetEngineBuildSquareRendering / DrawBuildSquare missing, widget removed")
		widgetHandler:RemoveWidget(self)
		return
	end
	if not gl.GetEngineUniformBufferDef or not initGL() then
		Spring.Echo("[BuildFootprintGL4] GL4 unavailable, widget removed")
		widgetHandler:RemoveWidget(self)
		return
	end
	Spring.SetEngineBuildSquareRendering(false)
end

function widget:Shutdown()
	if Spring.SetEngineBuildSquareRendering then
		Spring.SetEngineBuildSquareRendering(true)
	end
	if cellVAO then cellVAO:Delete() end
	if frameVAO then frameVAO:Delete() end
	if cellInstVBO then cellInstVBO:Delete() end
	if frameInstVBO then frameInstVBO:Delete() end
	if shader then glDeleteShader(shader) end
end

function widget:DrawWorldPreUnit()
	local t = now()
	local footprints, alpha = frameState(t)
	if not footprints then return end

	local cellData, frameData = S.cellData, S.frameData
	local nCells, nFrames = buildInstances(footprints, alpha, S.sessionStart, cellData, frameData)
	if nCells == 0 then return end

	cellInstVBO:Upload(cellData, -1, 0, 1, nCells * INSTANCE_FLOATS)
	frameInstVBO:Upload(frameData, -1, 0, 1, nFrames * INSTANCE_FLOATS)

	glTexture(0, "$heightmap")
	glDepthTest(false)      -- matches the engine's own build-square drawing
	glDepthMask(false)
	glCulling(false)
	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

	glUseShader(shader)
	glUniform(uNowLoc, t)
	glUniform(uLiftLoc, CFG.groundLift)
	glUniform(uAccentLoc,   CFG.accent[1],      CFG.accent[2],      CFG.accent[3])
	glUniform(uReclaimLoc,  CFG.reclaimable[1], CFG.reclaimable[2], CFG.reclaimable[3])
	glUniform(uOccupiedLoc, CFG.occupied[1],    CFG.occupied[2],    CFG.occupied[3])
	glUniform(uBlockedLoc,  CFG.blocked[1],     CFG.blocked[2],     CFG.blocked[3])
	glUniform(uCellOKLoc,  CFG.cellBase, CFG.cellBreathe, CFG.cellFreq, 0)
	glUniform(uCellBadLoc, CFG.badBase,  CFG.badBreathe,  CFG.badFreq,  0)

	-- frame first (glow underneath), cells on top
	frameVAO:DrawElements(GL_TRIANGLES, frameIdxCount, 0, nFrames, 0)
	cellVAO:DrawElements(GL_TRIANGLES, cellIdxCount, 0, nCells, 0)

	glUseShader(0)
	glTexture(0, false)
	glDepthMask(true)
	glDepthTest(true)
	glBlending(true)
end

--------------------------------------------------------------------------------
-- Test hooks (no effect in-game)
--------------------------------------------------------------------------------

widget.__test = {
	S = S,
	CFG = CFG,
	buildInstances = buildInstances,
	frameState = frameState,
	footprintSize = footprintSize,
	vsSrc = vsSrc,
	fsSrc = fsSrc,
	INSTANCE_FLOATS = INSTANCE_FLOATS,
}
