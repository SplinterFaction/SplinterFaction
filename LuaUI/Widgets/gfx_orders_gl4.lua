local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name    = "Orders GL4",
		desc    = "Order marks and lines: an animated ground mark at every order target and a flowing line to it, per order kind, with a flash when the order is given",
		author  = "SplinterFaction",
		date    = "2026-10-19",
		license = "GNU GPL, v2 or later",
		layer   = 2,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
--
--  Replaces Commands FX (gui_commands_fx.lua, immediate-mode gl) and the
--  engine's own queue lines, which cmdcolors_mod.txt keeps at alpha 0.1.
--
--  Two instanced buffers, drawn in DrawWorldPreUnit so they sit on the ground
--  under units:
--    marks    one ground quad per order target. A signed-distance shape per
--             order kind (ring, sonar rings, reticle, dashed loop, beacon),
--             animated by a time uniform.
--    ribbons  the lines, as ground strips between waypoints, cut into short
--             pieces so they follow the heightmap, with a flow pattern per
--             kind scrolling along them.
--
--  What is shown: the queues of the selected units; any unit of yours given
--  an order in the last few seconds (the echo); allied units' latest order,
--  in their team color, quietly. On the frame an order is given its mark
--  starts oversized and collapses into place and its line draws itself in.
--  After that everything settles to a resting alpha so a big army does not
--  turn the ground into string.
--
--  Everything tunable is in STYLE and TUNE below, also reachable through
--  WG.orders for the options menu.
--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Tunables
--------------------------------------------------------------------------------

local version = 1

local TUNE = {
	flashTime     = 0.45,  -- seconds the mark takes to collapse into place
	flashScale    = 1.6,   -- the mark starts this many times its size
	drawInTime    = 0.18,  -- seconds the line takes to draw itself to the target
	settleTime    = 1.2,   -- seconds from full alpha down to the resting alpha
	restAlpha     = 0.38,  -- alpha of an order once it has settled
	queuedFlash   = 0.45,  -- a shift-queued order flashes this much of a fresh one
	echoTime      = 3.0,   -- seconds an unselected unit's new order stays shown
	allyTime      = 6.0,   -- seconds an ally's order stays shown
	allyAlpha     = 0.55,  -- allies' orders, relative to restAlpha
	heightOffset  = 2.0,   -- elmos above the heightmap
	zPull         = 24.0,  -- depth pull toward the camera, so terrain LOD does not swallow it
	segment       = 48,    -- elmos per ribbon piece
	maxUnits      = 300,   -- most units whose queues are drawn at once
	maxQueue      = 24,    -- orders read per unit
	fadeStart     = 5000,  -- camera distance where it all starts to fade
	fadeEnd       = 9000,
	showAllies    = true,
}

-- Per order kind, colors after cmdcolors_mod.txt. size: mark radius in
-- elmos. width: half width of the line's glow in elmos (the bright core is
-- about a quarter of it). flow: pattern and pulse speed. shape / pattern pick
-- the GLSL branch (see the fragment shaders). Allies' orders are drawn in
-- their team color whatever is set here.
local STYLE = {
	move    = { shape = 1, pattern = 1, color = {0.50, 1.00, 0.50}, size = 26, width = 7.0, flow = 1.0 },
	fight   = { shape = 2, pattern = 2, color = {0.55, 0.55, 1.00}, size = 30, width = 8.0, flow = 1.3 },
	attack  = { shape = 3, pattern = 3, color = {1.00, 0.25, 0.25}, size = 30, width = 8.5, flow = 2.0 },
	patrol  = { shape = 4, pattern = 4, color = {0.35, 0.35, 1.00}, size = 22, width = 6.5, flow = 0.9 },
	rally   = { shape = 5, pattern = 1, color = {0.50, 1.00, 0.50}, size = 22, width = 5.5, flow = 0.5 },
	guard   = { shape = 6, pattern = 1, color = {0.35, 0.35, 1.00}, size = 28, width = 5.5, flow = 0.6 },
	repair  = { shape = 6, pattern = 1, color = {0.30, 1.00, 1.00}, size = 26, width = 5.5, flow = 0.6 },
	capture = { shape = 6, pattern = 1, color = {1.00, 1.00, 0.30}, size = 26, width = 5.5, flow = 0.6 },
	reclaim = { shape = 7, pattern = 1, color = {1.00, 0.25, 1.00}, size = 26, width = 5.5, flow = 0.6 },
	restore = { shape = 7, pattern = 1, color = {0.10, 1.00, 0.10}, size = 26, width = 5.5, flow = 0.6 },
	resurrect = { shape = 7, pattern = 1, color = {0.25, 0.60, 1.00}, size = 26, width = 5.5, flow = 0.6 },
	load    = { shape = 1, pattern = 1, color = {0.30, 1.00, 1.00}, size = 22, width = 5.0, flow = 0.5 },
	unload  = { shape = 1, pattern = 1, color = {1.00, 1.00, 0.10}, size = 22, width = 5.0, flow = 0.5 },
	build   = { shape = 8, pattern = 5, color = {0.35, 0.75, 1.00}, size = 24, width = 4.5, flow = 0.4 },
	other   = { shape = 1, pattern = 1, color = {0.80, 0.80, 0.80}, size = 20, width = 4.5, flow = 0.5 },
}

--------------------------------------------------------------------------------
-- Engine
--------------------------------------------------------------------------------

local CMD_MOVE       = CMD.MOVE
local CMD_RAW_MOVE   = 39812
local CMD_FIGHT      = CMD.FIGHT
local CMD_ATTACK     = CMD.ATTACK
local CMD_PATROL     = CMD.PATROL
local CMD_GUARD      = CMD.GUARD
local CMD_REPAIR     = CMD.REPAIR
local CMD_RECLAIM    = CMD.RECLAIM
local CMD_RESURRECT  = CMD.RESURRECT
local CMD_CAPTURE    = CMD.CAPTURE
local CMD_RESTORE    = CMD.RESTORE
local CMD_MANUALFIRE = CMD.MANUALFIRE
local CMD_SET_TARGET = 34923
local CMD_LOAD_UNITS = CMD.LOAD_UNITS
local CMD_UNLOAD_UNITS = CMD.UNLOAD_UNITS
local CMD_UNLOAD_UNIT = CMD.UNLOAD_UNIT
local CMD_INSERT     = CMD.INSERT

local KIND_OF_CMD = {
	[CMD_MOVE] = "move", [CMD_RAW_MOVE] = "move",
	[CMD_FIGHT] = "fight",
	[CMD_ATTACK] = "attack", [CMD_MANUALFIRE] = "attack", [CMD_SET_TARGET] = "attack",
	[CMD_PATROL] = "patrol",
	[CMD_GUARD] = "guard",
	[CMD_REPAIR] = "repair", [CMD_CAPTURE] = "capture",
	[CMD_RECLAIM] = "reclaim", [CMD_RESURRECT] = "resurrect", [CMD_RESTORE] = "restore",
	[CMD_LOAD_UNITS] = "load", [CMD_UNLOAD_UNITS] = "unload", [CMD_UNLOAD_UNIT] = "unload",
}

local spGetSelectedUnits  = Spring.GetSelectedUnits
local spGetUnitCommands   = Spring.GetUnitCommands
local spGetUnitPosition   = Spring.GetUnitPosition
local spGetUnitViewPosition = Spring.GetUnitViewPosition
local spGetFeaturePosition = Spring.GetFeaturePosition
local spValidUnitID       = Spring.ValidUnitID
local spValidFeatureID    = Spring.ValidFeatureID
local spGetUnitTeam       = Spring.GetUnitTeam
local spGetTeamColor      = Spring.GetTeamColor
local spGetMyTeamID       = Spring.GetMyTeamID
local spGetMyAllyTeamID   = Spring.GetMyAllyTeamID
local spGetUnitAllyTeam   = Spring.GetUnitAllyTeam
local spGetSpectatingState = Spring.GetSpectatingState
local spGetGroundHeight   = Spring.GetGroundHeight
local spGetTimer          = Spring.GetTimer
local spDiffTimers        = Spring.DiffTimers
local spGetUnitDefID      = Spring.GetUnitDefID
local spEcho              = Spring.Echo

local glTexture   = gl.Texture
local glCulling   = gl.Culling
local glDepthTest = gl.DepthTest
local glDepthMask = gl.DepthMask
local glBlending  = gl.Blending

local floor, sqrt, max, min = math.floor, math.sqrt, math.max, math.min

local MAX_UNITS = Game.maxUnits
local luaShaderDirs = { "LuaUI/Widgets/Include/", "LuaUI/Include/" }

--------------------------------------------------------------------------------
-- Shaders
--------------------------------------------------------------------------------

-- 12 floats per instance for both buffers
local INSTSTEP = 12

local commonVS = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack : require
#line 10000
//__ENGINEUNIFORMBUFFERDEFS__

uniform sampler2D heightmapTex;
uniform float now;
uniform float heightOffset;
uniform float zPull;
uniform float fadeStart;
uniform float fadeEnd;

vec2 HeightmapUV(vec2 wp) {
	vec2 inv = vec2(1.0) / mapSize.xy;
	wp += vec2(-8.0) * (wp * inv) + vec2(4.0);
	wp = clamp(wp, vec2(8.0), mapSize.xy - vec2(8.0));
	return wp * inv;
}
float GroundY(vec2 xz) {
	return texture(heightmapTex, HeightmapUV(xz)).x + heightOffset;
}
float DistFade(vec3 p) {
	float d = length(cameraViewInv[3].xyz - p);
	return 1.0 - smoothstep(fadeStart, fadeEnd, d);
}
]]

-- marks: a quad per order target
local markVS = commonVS .. [[
layout (location = 0) in vec2 quadPos;    // -1..1
layout (location = 1) in vec4 markPos;    // x, y(unused), z, radius
layout (location = 2) in vec4 markColor;  // rgb, restAlpha
layout (location = 3) in vec4 markParams; // shape, t0, flashAmount, queued(0/1)

out vec2 v_p;
flat out vec4 v_color;
flat out vec4 v_params;
flat out float v_age;
flat out float v_alpha;

void main() {
	float age = now - markParams.y;
	float flash = markParams.z;
	// collapse from flashScale to 1 with an ease-out
	float ft = clamp(age / ]] .. string.format("%.3f", TUNE.flashTime) .. [[, 0.0, 1.0);
	float ease = 1.0 - (1.0 - ft) * (1.0 - ft);
	float scale = 1.0 + flash * (]] .. string.format("%.3f", TUNE.flashScale - 1) .. [[) * (1.0 - ease);
	// alpha: full during the flash, then settling to rest
	float settle = clamp((age - ]] .. string.format("%.3f", TUNE.flashTime) .. [[) / ]] .. string.format("%.3f", TUNE.settleTime) .. [[, 0.0, 1.0);
	float alpha = mix(1.0, markColor.a, settle);

	float r = markPos.w * scale;
	vec2 xz = markPos.xz + quadPos * r;
	vec3 wp = vec3(xz.x, GroundY(xz), xz.y);

	v_p = quadPos;
	v_color = markColor;
	v_params = markParams;
	v_age = age;
	v_alpha = alpha * DistFade(vec3(markPos.x, wp.y, markPos.z));

	gl_Position = cameraViewProj * vec4(wp, 1.0);
	gl_Position.z -= zPull / gl_Position.w;
}
]]

local markFS = [[
#version 420
#line 20000
in vec2 v_p;
flat in vec4 v_color;
flat in vec4 v_params;
flat in float v_age;
flat in float v_alpha;
uniform float now;
out vec4 fragColor;

const float PI = 3.14159265;

float ring(float d, float r, float w) {
	return 1.0 - smoothstep(0.0, w, abs(d - r));
}
// 1 inside a soft-edged band between r0 and r1
float band(float d, float r0, float r1, float w) {
	return smoothstep(r0 - w, r0, d) * (1.0 - smoothstep(r1, r1 + w, d));
}

void main() {
	float d = length(v_p);
	if (d > 1.0) discard;
	float a = atan(v_p.y, v_p.x);
	float t = v_age;
	int shape = int(v_params.x + 0.5);
	float queued = v_params.w;
	float w = 0.06;
	float m = 0.0;

	if (shape == 1) {
		// move: one ring, a slow tick going round it
		m = ring(d, 0.80, w);
		float tick = smoothstep(0.85, 1.0, cos(a - t * 1.5)) * ring(d, 0.80, 0.14);
		m = max(m, tick);
		m += 0.10 * (1.0 - smoothstep(0.0, 0.25, d)); // a faint center dot
	} else if (shape == 2) {
		// fight: sonar, two rings pulsing outward
		float p0 = fract(t * 0.8);
		float p1 = fract(t * 0.8 + 0.5);
		m = ring(d, p0 * 0.95, w) * (1.0 - p0) + ring(d, p1 * 0.95, w) * (1.0 - p1);
		m = max(m, 0.55 * ring(d, 0.95, w));
	} else if (shape == 3) {
		// attack: four corner brackets closing in, and a thin rotating ring with gaps
		float close = 1.0 - 0.15 * clamp(1.0 - t * 2.0, 0.0, 1.0);
		vec2 q = abs(v_p) / close;
		// an L in each corner: along the outer edge of the square, only its outer half
		float onEdge = max(step(0.74, q.x) * step(0.50, q.y), step(0.74, q.y) * step(0.50, q.x));
		float corner = step(max(q.x, q.y), 0.82) * onEdge;
		float gaps = step(0.5, fract((a + t * 1.2) * 3.0 / (2.0 * PI)));
		m = max(corner, 0.7 * ring(d, 0.45, 0.04) * gaps);
		m = max(m, 0.9 * (1.0 - smoothstep(0.0, 0.08, d))); // center point
	} else if (shape == 4) {
		// patrol: a dashed ring, dashes walking round
		float dash = step(0.5, fract((a - t * 1.0) * 6.0 / (2.0 * PI)));
		m = ring(d, 0.72, w) * dash;
	} else if (shape == 5) {
		// rally: a solid beacon with a breathing ring
		m = 1.0 - smoothstep(0.18, 0.26, d);
		float breathe = 0.6 + 0.4 * sin(t * 2.5);
		m = max(m, ring(d, 0.55 + 0.1 * breathe, w) * (0.5 + 0.5 * breathe));
	} else if (shape == 6) {
		// guard / repair: an orbiting arc
		float arc = smoothstep(0.3, 0.9, cos(a - t * 2.2));
		m = ring(d, 0.78, w) * arc + 0.3 * ring(d, 0.78, w);
	} else if (shape == 7) {
		// reclaim: a ring pulling inward
		float p = 1.0 - fract(t * 0.9);
		m = ring(d, p * 0.9, w) * p + 0.4 * ring(d, 0.9, w);
	} else {
		// build: a hex outline drawing itself in
		float hex = max(abs(v_p.x) * 0.866 + abs(v_p.y) * 0.5, abs(v_p.y));
		float edge = ring(hex, 0.78, 0.05);
		float sweep = step(fract(a / (2.0 * PI) + 0.5), clamp(t * 2.0, 0.0, 1.0));
		m = edge * sweep;
	}

	m = clamp(m, 0.0, 1.0);
	if (m <= 0.002) discard;
	float alpha = v_alpha * mix(1.0, 0.6, queued);
	fragColor = vec4(v_color.rgb, m * alpha);
}
]]

-- ribbons: a strip per piece of line
local ribbonVS = commonVS .. [[
layout (location = 0) in vec2 quadPos;     // x 0..1 along, y -1..1 across
layout (location = 1) in vec4 segA;        // ax, az, bx, bz
layout (location = 2) in vec4 ribColor;    // rgb, restAlpha
layout (location = 3) in vec4 ribParams;   // pattern + 10*halfWidth (packed), t0, uvStart (elmos from the line's start), flow/drawIn packed: drawFraction*100 + queued

out vec2 v_uv;      // along (elmos), across (-1..1)
flat out vec4 v_color;
flat out vec3 v_params; // pattern, age, queued
flat out float v_alpha;

void main() {
	vec2 a = segA.xy;
	vec2 b = segA.zw;
	vec2 dir = b - a;
	float len = max(length(dir), 0.001);
	dir /= len;
	vec2 nrm = vec2(-dir.y, dir.x);

	float pattern = floor(ribParams.x / 10.0);
	float halfWidth = ribParams.x - pattern * 10.0;
	float age = now - ribParams.y;
	float queued = ribParams.w;
	// the draw-in (the line revealing itself from its start) is cut in the
	// fragment shader from the age and the along-line uv

	float settle = clamp((age - ]] .. string.format("%.3f", TUNE.flashTime) .. [[) / ]] .. string.format("%.3f", TUNE.settleTime) .. [[, 0.0, 1.0);
	float alpha = mix(1.0, ribColor.a, settle);

	vec2 xz = a + dir * (quadPos.x * len) + nrm * (quadPos.y * halfWidth);
	vec3 wp = vec3(xz.x, GroundY(xz), xz.y);

	v_uv = vec2(ribParams.z + quadPos.x * len, quadPos.y);
	v_color = ribColor;
	v_params = vec3(pattern, age, queued);
	v_alpha = alpha * DistFade(wp);
	gl_Position = cameraViewProj * vec4(wp, 1.0);
	gl_Position.z -= zPull / gl_Position.w;
}
]]

local ribbonFS = [[
#version 420
#line 30000
in vec2 v_uv;
flat in vec4 v_color;
flat in vec3 v_params;
flat in float v_alpha;
uniform float now;
uniform float drawInLength; // elmos the line reveals per second while drawing in
out vec4 fragColor;

void main() {
	int pattern = int(v_params.x + 0.5);
	float age = v_params.y;
	float queued = v_params.z;
	float x = v_uv.x;
	float a = abs(v_uv.y);           // 0 at the center line, 1 at the glow's edge
	// draw-in: nothing beyond how far the line has drawn
	if (x > age * drawInLength) discard;

	// a wide, soft pulse travelling down the line: the glow swells as it passes
	float speed = (pattern == 3) ? 2.0 : ((pattern == 2) ? 1.3 : ((pattern == 4) ? 0.9 : 1.0));
	float ph = fract(x / 260.0 - age * speed * 0.55);
	float pulse = exp(-pow((ph - 0.5) * 3.2, 2.0));

	// the bright core, and the glow that fades out to the edge
	float coreW = 0.22;
	float glowW = 0.55 + 0.45 * pulse;
	float core = exp(-(a * a) / (coreW * coreW) * 1.4);
	float glow = exp(-(a * a) / (glowW * glowW) * 1.4) * (1.0 - a);
	float m = core + glow * (0.35 + 0.55 * pulse);

	// the pattern rides on the core only
	if (pattern == 1) {
		// move: a gentle forward flow
		core *= 0.6 + 0.4 * (0.5 + 0.5 * sin(x * 0.08 - age * 7.0));
	} else if (pattern == 2) {
		// fight: chevrons marching forward, points first
		float chev = fract((x + a * 16.0) / 46.0 - age * 1.6);
		core *= 0.3 + 0.7 * (smoothstep(0.35, 0.5, chev) * (1.0 - smoothstep(0.5, 0.65, chev)));
	} else if (pattern == 3) {
		// attack: fast hot flow
		core *= 0.55 + 0.45 * (0.5 + 0.5 * sin(x * 0.14 - age * 14.0));
	} else if (pattern == 4) {
		// patrol: dashes walking along
		core *= 0.15 + 0.85 * step(0.5, fract(x / 40.0 - age * 1.0));
	} else {
		// build: thin and still
		core *= 0.7;
	}
	m = core + glow * (0.35 + 0.55 * pulse);

	float alpha = v_alpha * mix(1.0, 0.6, queued);
	// the core overshoots to white a little, the glow stays in color
	vec3 rgb = v_color.rgb + vec3(0.35) * core * core;
	if (m * alpha <= 0.003) discard;
	fragColor = vec4(rgb, clamp(m, 0.0, 1.0) * alpha);
}
]]

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local LuaShader
local markShader, ribbonShader
local markVAO, ribbonVAO
local markTemplate, ribbonTemplate, markIndex, ribbonIndex
local markVBO, ribbonVBO
local markCapacity, ribbonCapacity = 512, 2048
local resourcesReady = false

local timer0 = spGetTimer()
local function Now() return spDiffTimers(spGetTimer(), timer0) end

-- per unit: {kind, t0, flash, queued(bool), x, z, target}, read from the queue
-- orders[unitID] = {n = count, [i] = order}, cached and refreshed on change
local orders = {}
local orderTime = {}     -- unitID -> when its queue was last read
-- unitID -> seconds until which it is shown though not selected
local echoUntil = {}
-- unitID -> {t0, flash} for the freshest order, for the flash
local freshAt = {}
local allyUntil = {}     -- allied unitID -> seconds

local selected = {}      -- unitID -> true
local selectedList = {}
local dirty = true

local markData, ribbonData = {}, {}
local numMarks, numRibbons = 0, 0

local teamColorCache = {}

local myTeam = spGetMyTeamID()
local myAlly = spGetMyAllyTeamID()
local spectating = spGetSpectatingState()

local function TeamColor(teamID)
	local c = teamColorCache[teamID]
	if not c then
		local r, g, b = spGetTeamColor(teamID)
		-- lift dark team colors so the line reads on the ground
		local lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
		if lum < 0.35 then
			local k = (0.35 - lum) / max(0.001, 1 - lum)
			r, g, b = r + (1 - r) * k, g + (1 - g) * k, b + (1 - b) * k
		end
		c = { r, g, b }
		teamColorCache[teamID] = c
	end
	return c
end

--------------------------------------------------------------------------------
-- Reading orders
--------------------------------------------------------------------------------

local function TargetPosition(cmdID, params)
	local n = #params
	if n >= 3 then
		return params[1], params[3]
	elseif n >= 1 then
		local id = params[1]
		if id >= MAX_UNITS then
			local x, _, z = spGetFeaturePosition(id - MAX_UNITS)
			return x, z, nil
		elseif spValidUnitID(id) then
			local x, _, z = spGetUnitPosition(id)
			return x, z, id
		end
	end
	return nil
end

local function KindOf(cmdID)
	if cmdID < 0 then return "build" end
	return KIND_OF_CMD[cmdID]
end

-- the unit's queue as a list of orders; nil when it has none worth drawing
local function ReadQueue(unitID)
	local q = spGetUnitCommands(unitID, TUNE.maxQueue)
	if not q then
		return nil
	end
	local list = { n = 0 }
	for i = 1, #q do
		local cmd = q[i]
		local kind = KindOf(cmd.id)
		if kind then
			local x, z, target = TargetPosition(cmd.id, cmd.params)
			if x then
				local k = list.n + 1
				list.n = k
				list[k] = { kind = kind, x = x, z = z, target = target, cmdID = cmd.id, index = i }
			end
		end
	end
	if list.n == 0 then
		return nil
	end
	return list
end

local function Refresh(unitID)
	orders[unitID] = ReadQueue(unitID)
	orderTime[unitID] = Now()
	dirty = true
end

--------------------------------------------------------------------------------
-- Building the instance data
--------------------------------------------------------------------------------

local function PushMark(x, z, style, color, restAlpha, t0, flash, queued)
	local i = numMarks * INSTSTEP
	local d = markData
	d[i + 1], d[i + 2], d[i + 3], d[i + 4] = x, 0, z, style.size
	d[i + 5], d[i + 6], d[i + 7], d[i + 8] = color[1], color[2], color[3], restAlpha
	d[i + 9], d[i + 10], d[i + 11], d[i + 12] = style.shape, t0, flash, queued and 1 or 0
	numMarks = numMarks + 1
end

-- a line from (ax, az) to (bx, bz), cut into pieces; uvStart carries on along
-- a multi-waypoint path so the pattern and the draw-in run through
local function PushRibbon(ax, az, bx, bz, style, color, restAlpha, t0, queued, uvStart)
	local dx, dz = bx - ax, bz - az
	local len = sqrt(dx * dx + dz * dz)
	if len < 1 then
		return uvStart
	end
	local pieces = max(1, floor(len / TUNE.segment + 0.999))
	local packed = style.pattern * 10 + min(style.width, 9.99)
	for p = 0, pieces - 1 do
		local f0, f1 = p / pieces, (p + 1) / pieces
		local i = numRibbons * INSTSTEP
		local d = ribbonData
		d[i + 1], d[i + 2] = ax + dx * f0, az + dz * f0
		d[i + 3], d[i + 4] = ax + dx * f1, az + dz * f1
		d[i + 5], d[i + 6], d[i + 7], d[i + 8] = color[1], color[2], color[3], restAlpha
		d[i + 9], d[i + 10], d[i + 11], d[i + 12] = packed, t0, uvStart + len * f0, queued and 1 or 0
		numRibbons = numRibbons + 1
	end
	return uvStart + len
end

-- draws one unit's queue
local function PushUnit(unitID, restAlpha, isAlly)
	local list = orders[unitID]
	if not list then
		return
	end
	-- the drawn (interpolated) position, so the line's start does not stutter
	local ux, _, uz = spGetUnitViewPosition(unitID)
	if not ux then
		return
	end
	local fresh = freshAt[unitID]
	local t0 = fresh and fresh.t0 or 0
	local flash = fresh and fresh.flash or 0
	if isAlly then
		flash = 0
	end
	local teamID = spGetUnitTeam(unitID)
	local tc = (isAlly and teamID) and TeamColor(teamID) or nil
	local px, pz = ux, uz
	local uv = 0
	for i = 1, list.n do
		local o = list[i]
		local style = STYLE[o.kind] or STYLE.other
		local color = tc or style.color
		local queued = i > 1
		-- a tracked target moves: follow it
		local x, z = o.x, o.z
		if o.target then
			if spValidUnitID(o.target) then
				local tx, _, tz = spGetUnitViewPosition(o.target)
				if tx then x, z = tx, tz end
			end
		end
		-- the flash belongs to the newest order; earlier ones in the queue are settled
		local ot0, oflash = t0, flash
		if i < list.n then
			ot0, oflash = 0, 0
		elseif queued then
			oflash = flash * TUNE.queuedFlash
		end
		-- patrol loops: the line goes back to the start
		uv = PushRibbon(px, pz, x, z, style, color, restAlpha, ot0, queued, uv)
		PushMark(x, z, style, color, restAlpha, ot0, oflash, queued)
		px, pz = x, z
	end
	-- a patrol queue closes its loop
	local last = list[list.n]
	if last and last.kind == "patrol" and list.n >= 2 then
		local first = list[1]
		PushRibbon(px, pz, first.x, first.z, STYLE.patrol, tc or STYLE.patrol.color, restAlpha, 0, true, uv)
	end
end

local function PushRally(unitID, restAlpha)
	-- the rally point of a factory is its own (non-factory) queue: the first
	-- move order in GetUnitCommands is where new units go
	local list = orders[unitID]
	if not list or list.n == 0 then
		return
	end
	local o = list[1]
	if o.kind ~= "move" then
		return
	end
	local ux, _, uz = spGetUnitPosition(unitID)
	if not ux then
		return
	end
	local color = STYLE.rally.color
	local fresh = freshAt[unitID]
	local t0 = fresh and fresh.t0 or 0
	local flash = fresh and fresh.flash or 0
	PushRibbon(ux, uz, o.x, o.z, STYLE.rally, color, restAlpha, t0, false, 0)
	PushMark(o.x, o.z, STYLE.rally, color, restAlpha, t0, flash, false)
end

local isFactory = {}
for unitDefID, ud in pairs(UnitDefs) do
	isFactory[unitDefID] = ud.isFactory or false
end

local function Rebuild()
	numMarks, numRibbons = 0, 0
	local now = Now()
	local rest = TUNE.restAlpha
	local count = 0

	-- selected units: everything in their queues
	for i = 1, #selectedList do
		local unitID = selectedList[i]
		if count < TUNE.maxUnits and spValidUnitID(unitID) then
			count = count + 1
			if orders[unitID] == nil and orderTime[unitID] == nil then
				Refresh(unitID)
			end
			local udid = spGetUnitDefID(unitID)
			if udid and isFactory[udid] then
				PushRally(unitID, rest)
			else
				PushUnit(unitID, rest, false)
			end
		end
	end
	-- echoes: own units just ordered, not selected
	for unitID, until_ in pairs(echoUntil) do
		if until_ < now or not spValidUnitID(unitID) then
			echoUntil[unitID] = nil
		elseif not selected[unitID] and count < TUNE.maxUnits then
			count = count + 1
			local udid = spGetUnitDefID(unitID)
			if udid and isFactory[udid] then
				PushRally(unitID, rest)
			else
				PushUnit(unitID, rest, false)
			end
		end
	end
	-- allies: their latest orders, quietly
	if TUNE.showAllies then
		for unitID, until_ in pairs(allyUntil) do
			if until_ < now or not spValidUnitID(unitID) then
				allyUntil[unitID] = nil
			elseif count < TUNE.maxUnits then
				count = count + 1
				PushUnit(unitID, rest * TUNE.allyAlpha, true)
			end
		end
	end
	-- trim the tails so a stale upload never shows old data
	for i = numMarks * INSTSTEP + 1, #markData do markData[i] = nil end
	for i = numRibbons * INSTSTEP + 1, #ribbonData do ribbonData[i] = nil end
end

--------------------------------------------------------------------------------
-- GL resources
--------------------------------------------------------------------------------

local function DestroyResources()
	if markVAO then markVAO:Delete() end
	if ribbonVAO then ribbonVAO:Delete() end
	if markTemplate then markTemplate:Delete() end
	if ribbonTemplate then ribbonTemplate:Delete() end
	if markIndex then markIndex:Delete() end
	if ribbonIndex then ribbonIndex:Delete() end
	if markVBO then markVBO:Delete() end
	if ribbonVBO then ribbonVBO:Delete() end
	markVAO, ribbonVAO, markTemplate, ribbonTemplate, markIndex, ribbonIndex, markVBO, ribbonVBO = nil, nil, nil, nil, nil, nil, nil, nil
	if markShader then markShader:Finalize() end
	if ribbonShader then ribbonShader:Finalize() end
	markShader, ribbonShader = nil, nil
	resourcesReady = false
end

local function Fail(msg)
	spEcho("[Orders GL4] " .. msg .. ", removing widget")
	DestroyResources()
	widgetHandler:RemoveWidget(widget)
	return false
end

-- a strip from x0 to x1, -1..1 across, with sub steps along it (each
-- vertex samples the heightmap, so a strip with steps follows the ground)
local RIBBON_SUB = 6
local function Strip(x0, x1, sub)
	local vbo = gl.GetVBO(GL.ARRAY_BUFFER, false)
	local ibo = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false)
	if not (vbo and ibo) then return nil end
	local verts, idx = {}, {}
	for i = 0, sub do
		local x = x0 + (x1 - x0) * i / sub
		verts[#verts + 1] = x; verts[#verts + 1] = -1
		verts[#verts + 1] = x; verts[#verts + 1] = 1
	end
	for i = 0, sub - 1 do
		local a = i * 2
		idx[#idx + 1] = a; idx[#idx + 1] = a + 1; idx[#idx + 1] = a + 3
		idx[#idx + 1] = a; idx[#idx + 1] = a + 3; idx[#idx + 1] = a + 2
	end
	vbo:Define((sub + 1) * 2, { { id = 0, name = "quadPos", size = 2 } })
	vbo:Upload(verts)
	ibo:Define(#idx)
	ibo:Upload(idx)
	return vbo, ibo, #idx
end
local ribbonIndices = 6

local markLayout = {
	{ id = 1, name = "markPos",    size = 4 },
	{ id = 2, name = "markColor",  size = 4 },
	{ id = 3, name = "markParams", size = 4 },
}
local ribbonLayout = {
	{ id = 1, name = "segA",      size = 4 },
	{ id = 2, name = "ribColor",  size = 4 },
	{ id = 3, name = "ribParams", size = 4 },
}

local function BuildInstanceBuffer(which, capacity)
	local vbo = gl.GetVBO(GL.ARRAY_BUFFER, true)
	if not vbo then return nil end
	vbo:Define(capacity, which == "mark" and markLayout or ribbonLayout)
	local vao = gl.GetVAO()
	if not vao then return nil end
	vao:AttachVertexBuffer(which == "mark" and markTemplate or ribbonTemplate)
	vao:AttachInstanceBuffer(vbo)
	vao:AttachIndexBuffer(which == "mark" and markIndex or ribbonIndex)
	return vbo, vao
end

local function UpdateUniforms()
	local function set(shader)
		if not shader then return end
		shader:ActivateWith(function()
			shader:SetUniform("heightOffset", TUNE.heightOffset)
			shader:SetUniform("zPull", TUNE.zPull)
			shader:SetUniform("fadeStart", TUNE.fadeStart)
			shader:SetUniform("fadeEnd", TUNE.fadeEnd)
		end)
	end
	set(markShader)
	set(ribbonShader)
	if ribbonShader then
		ribbonShader:ActivateWith(function()
			-- a 1500 elmo line draws in over drawInTime
			ribbonShader:SetUniform("drawInLength", 1500 / TUNE.drawInTime)
		end)
	end
end

local function CreateResources()
	DestroyResources()
	local engineDefs = LuaShader.GetEngineUniformBufferDefs and LuaShader.GetEngineUniformBufferDefs()
	if not engineDefs then return Fail("LuaShader.GetEngineUniformBufferDefs missing") end

	markShader = LuaShader({
		vertex = markVS:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineDefs),
		fragment = markFS,
		uniformInt = { heightmapTex = 0 },
		uniformFloat = { now = 0 },
	}, "Orders GL4 marks")
	if not markShader:Initialize() then return Fail("mark shader failed to compile") end

	ribbonShader = LuaShader({
		vertex = ribbonVS:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineDefs),
		fragment = ribbonFS,
		uniformInt = { heightmapTex = 0 },
		uniformFloat = { now = 0, drawInLength = 1 },
	}, "Orders GL4 ribbons")
	if not ribbonShader:Initialize() then return Fail("ribbon shader failed to compile") end

	markTemplate, markIndex = Strip(-1, 1, 1)
	ribbonTemplate, ribbonIndex, ribbonIndices = Strip(0, 1, RIBBON_SUB)
	if not (markTemplate and ribbonTemplate) then return Fail("could not create templates") end
	markVBO, markVAO = BuildInstanceBuffer("mark", markCapacity)
	ribbonVBO, ribbonVAO = BuildInstanceBuffer("ribbon", ribbonCapacity)
	if not (markVBO and ribbonVBO) then return Fail("could not create instance buffers") end

	resourcesReady = true
	UpdateUniforms()
	return true
end

local function Upload()
	if numMarks > markCapacity then
		markCapacity = max(markCapacity * 2, numMarks)
		if markVAO then markVAO:Delete() end
		if markVBO then markVBO:Delete() end
		markVBO, markVAO = BuildInstanceBuffer("mark", markCapacity)
	end
	if numRibbons > ribbonCapacity then
		ribbonCapacity = max(ribbonCapacity * 2, numRibbons)
		if ribbonVAO then ribbonVAO:Delete() end
		if ribbonVBO then ribbonVBO:Delete() end
		ribbonVBO, ribbonVAO = BuildInstanceBuffer("ribbon", ribbonCapacity)
	end
	if numMarks > 0 then markVBO:Upload(markData, nil, 0) end
	if numRibbons > 0 then ribbonVBO:Upload(ribbonData, nil, 0) end
end

--------------------------------------------------------------------------------
-- Callins
--------------------------------------------------------------------------------

function widget:SelectionChanged(sel)
	selected = {}
	selectedList = sel or {}
	for i = 1, #selectedList do
		selected[selectedList[i]] = true
	end
	dirty = true
end

-- an order was given: remember it so the queue is read again next frame
-- (the queue is not yet updated inside this callin) and the flash plays
local pendingRead = {}

function widget:UnitCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOpts)
	if cmdID == CMD_INSERT then
		cmdID = cmdParams and cmdParams[2] or cmdID
	end
	local kind = cmdID and KindOf(cmdID)
	if not kind then
		return
	end
	pendingRead[unitID] = true
	local now = Now()
	if teamID == myTeam and not spectating then
		-- a shift-queued order lands behind others in the queue, and PushUnit
		-- scales the flash of anything but the first order down by queuedFlash
		freshAt[unitID] = { t0 = now, flash = 1 }
		if not selected[unitID] then
			echoUntil[unitID] = now + TUNE.echoTime
		end
	elseif TUNE.showAllies and teamID ~= myTeam then
		local ally = spGetUnitAllyTeam(unitID)
		if ally == myAlly or spectating then
			freshAt[unitID] = { t0 = now, flash = 0 }
			allyUntil[unitID] = now + TUNE.allyTime
		end
	end
end

function widget:UnitDestroyed(unitID)
	orders[unitID], orderTime[unitID], echoUntil[unitID], allyUntil[unitID], freshAt[unitID] = nil, nil, nil, nil, nil
	dirty = true
end

function widget:UnitIdle(unitID)
	if orders[unitID] then
		orders[unitID] = nil
		dirty = true
	end
end

function widget:PlayerChanged()
	myTeam = spGetMyTeamID()
	myAlly = spGetMyAllyTeamID()
	spectating = spGetSpectatingState()
	teamColorCache = {}
	dirty = true
end

local sinceQueueRead = 0

function widget:Update(dt)
	-- queues of units with a pending order, and a periodic re-read of the
	-- selected units' queues (they shrink as orders complete)
	local any = false
	for unitID in pairs(pendingRead) do
		if spValidUnitID(unitID) then
			Refresh(unitID)
		end
		any = true
	end
	if any then
		pendingRead = {}
	end
	sinceQueueRead = sinceQueueRead + dt
	if sinceQueueRead > 0.25 then
		sinceQueueRead = 0
		for i = 1, min(#selectedList, TUNE.maxUnits) do
			local unitID = selectedList[i]
			if spValidUnitID(unitID) then
				Refresh(unitID)
			end
		end
		for unitID in pairs(echoUntil) do
			if spValidUnitID(unitID) then Refresh(unitID) end
		end
		for unitID in pairs(allyUntil) do
			if spValidUnitID(unitID) then Refresh(unitID) end
		end
	end
	-- positions move every frame, so the instance data is rebuilt every frame;
	-- it is small (selected units' queues) and the upload is one call
	Rebuild()
end

function widget:DrawWorldPreUnit()
	if not resourcesReady then
		if not CreateResources() then return end
	end
	if numMarks == 0 and numRibbons == 0 then
		return
	end
	Upload()
	local now = Now()

	glTexture(0, "$heightmap")
	glCulling(false)
	glDepthTest(GL.LEQUAL)
	glDepthMask(false)
	glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	if numRibbons > 0 then
		ribbonShader:Activate()
		ribbonShader:SetUniform("now", now)
		ribbonVAO:DrawElements(GL.TRIANGLES, ribbonIndices, 0, numRibbons, 0)
		ribbonShader:Deactivate()
	end
	if numMarks > 0 then
		markShader:Activate()
		markShader:SetUniform("now", now)
		markVAO:DrawElements(GL.TRIANGLES, 6, 0, numMarks, 0)
		markShader:Deactivate()
	end

	glTexture(0, false)
	glDepthTest(false)
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function widget:Initialize()
	if not gl.GetVBO or not gl.GetVAO then
		spEcho("[Orders GL4] GL4 VBO API unavailable, removing widget")
		widgetHandler:RemoveWidget(widget)
		return
	end
	LuaShader = gl.LuaShader
	if not LuaShader then
		for _, dir in ipairs(luaShaderDirs) do
			if VFS.FileExists(dir .. "LuaShader.lua") then
				LuaShader = VFS.Include(dir .. "LuaShader.lua")
				break
			end
		end
	end
	if not LuaShader then
		spEcho("[Orders GL4] LuaShader not found, removing widget")
		widgetHandler:RemoveWidget(widget)
		return
	end
	widget:SelectionChanged(spGetSelectedUnits())

	WG.orders = {
		getRestAlpha  = function() return TUNE.restAlpha end,
		setRestAlpha  = function(v) TUNE.restAlpha = v end,
		getShowAllies = function() return TUNE.showAllies end,
		setShowAllies = function(v) TUNE.showAllies = v and true or false; if not v then allyUntil = {} end end,
		getEchoTime   = function() return TUNE.echoTime end,
		setEchoTime   = function(v) TUNE.echoTime = v end,
		getFlashScale = function() return TUNE.flashScale end,
		setFlashScale = function(v) TUNE.flashScale = v; resourcesReady = false end, -- baked into the shader
	}
end

function widget:Shutdown()
	DestroyResources()
	WG.orders = nil
end

function widget:GetConfigData()
	return {
		version    = version,
		restAlpha  = TUNE.restAlpha,
		showAllies = TUNE.showAllies,
		echoTime   = TUNE.echoTime,
		flashScale = TUNE.flashScale,
	}
end

function widget:SetConfigData(data)
	if data.version ~= version then return end
	if data.restAlpha  ~= nil then TUNE.restAlpha  = data.restAlpha end
	if data.showAllies ~= nil then TUNE.showAllies = data.showAllies end
	if data.echoTime   ~= nil then TUNE.echoTime   = data.echoTime end
	if data.flashScale ~= nil then TUNE.flashScale = data.flashScale end
end
