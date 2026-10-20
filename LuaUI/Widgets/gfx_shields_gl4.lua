--------------------------------------------------------------------------------
-- Shields GL4 (SplinterFaction)
--
-- Instanced shield bubbles with impact response, replacing the LUPS
-- ShieldSphereColor / ShieldJitter pair for engine Shield weapons, and adding a
-- hit flash for the Loz personal overshield (unit_protoss_style_shields.lua).
--
-- Rendering, per instance (one sphere, back faces then front faces):
--   * fresnel rim in the shield's good color, tinted toward the bad color as
--     charge runs down, with a slow procedural cell pattern across the surface
--   * up to 8 live impacts: a bright core that fades and an expanding ring
--     along the sphere surface, both sized by damage relative to capacity;
--     nearby cells light up under the impact
--   * intersection glow where the sphere passes through terrain or models
--     (reconstructed from the G-buffer depth, like gfx_distortion_gl4)
--   * charge state: opacity and pattern density follow the shield's power,
--     a near-empty shield flickers, a collapse expands and dissolves
--   * personal shields draw nothing at rest; a hit paints the impact and a
--     short whole-body flash on a sphere hugging the unit, then it vanishes
--   * cloak fields (unit_cloak_shield.lua area cloak): a dim veil of flowing
--     noise that slightly darkens what is behind it, a soft ring where the
--     dome meets the ground, smooth grow/shrink, and a faint edge refraction
--     through the distortion widget; allies and spectators only
--
-- Data sources (all unsynced-gadget to LuaUI globals, see lups_shield.lua and
-- unit_protoss_style_shields.lua):
--   ShieldGL4_Add(unitID, unitDefID)            shield carrier appeared
--   ShieldGL4_Remove(unitID)                    carrier gone / shield removed
--   ShieldGL4_Visible(unitID, visible)          airLOS visibility from the gadget
--   ShieldGL4_State(unitID, x, y, z, charge)    fallback pos/charge for carriers
--                                               the player cannot read directly
--   ShieldGL4_Hit(unitID, damage, hx, hy, hz)   engine shield absorbed a hit
--   ShieldGL4_PersonalHit(unitID, dmg, max, hx, hy, hz) overshield absorbed a hit
--   ShieldGL4_Cloak(unitID, radius)             area cloak field radius (0 = off)
--   ShieldGL4_Active()                          lets the gadget suppress LUPS
--
-- Big hits also spawn a point distortion through WG.distortionsgl4.
--
-- Tuning lives in the `cfg` table and in WG.shieldsgl4 setters.
--------------------------------------------------------------------------------

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Shields GL4",
		desc      = "Instanced shield bubbles with impact ripples, intersection glow and charge state",
		author    = "SplinterFaction",
		date      = "2026-10-19",
		license   = "GNU GPL, v2 or later",
		layer     = -35, -- after units, with the other translucent world effects
		enabled   = true,
	}
end

--------------------------------------------------------------------------------
-- Tuning
--------------------------------------------------------------------------------

local cfg = {
	-- bubble look
	rimPower          = 2.2,   -- fresnel exponent; higher = thinner rim
	rimAlphaSmall     = 0.55,  -- rim opacity for personal-size / small bubbles (r < 250)
	rimAlphaLarge     = 0.30,  -- rim opacity for big projected shields
	fillAlpha         = 0.045, -- flat tint across the whole bubble
	backFaceMult      = 0.45,  -- back face brightness relative to front
	cellScale         = 0.14,  -- cells per elmo (scaled by radius in shader)
	cellAlpha         = 0.10,  -- idle visibility of the cell edges
	cellScroll        = 0.08,  -- cell drift, elmos per second as a fraction of radius

	-- impacts
	hitCoreFrames     = 10,    -- core flash e-fold time, frames
	hitRingFrames     = 18,    -- ring fade e-fold time, frames
	hitRingSpeed      = 0.09,  -- ring expansion, radians per frame on the sphere
	hitRingWidth      = 0.10,  -- ring thickness, radians
	hitCoreSize       = 0.22,  -- core angular size at strength 1, radians
	hitStrengthMult   = 6.0,   -- strength = damage / capacity * this, clamped to 1
	hitStrengthMin    = 0.12,
	hitMergeAngle     = 0.18,  -- hits closer than this (radians) within hitMergeFrames merge
	hitMergeFrames    = 8,
	hitDistortionMin  = 0.55,  -- strength needed to also spawn a screen distortion

	-- charge
	lowChargeFlicker  = 0.22,  -- charge fraction below which the bubble flickers
	popFrames         = 16,    -- collapse animation length
	spawnFrames       = 12,    -- fade-in length when a shield (re)appears

	-- intersection with world
	intersectRange    = 0.045, -- as a fraction of radius (plus a floor of 6 elmos)
	intersectAlpha    = 0.9,

	-- personal (overshield) flash
	personalRadiusMult = 1.12,
	personalFlashFrames = 7,
	personalLife       = 28,   -- frames an instance stays after its last hit
	personalColor      = { 0.40, 0.70, 1.00 },
	personalStrengthMult = 4.0,

	-- cloak fields
	cloakColor        = { 0.42, 0.62, 0.70 }, -- veil tint (customparams area_cloak_color overrides)
	cloakVeilAlpha    = 0.11,  -- flat darkening veil across the dome
	cloakRimAlpha     = 0.16,  -- faint edge
	cloakRingAlpha    = 0.55,  -- ground contact ring
	cloakNoiseScale   = 2.6,   -- noise cells per radius
	cloakNoiseSpeed   = 0.35,  -- noise drift
	cloakGrowSmooth   = 0.12,  -- per draw frame interpolation toward the target radius
	cloakDistortion   = 0.9,   -- effectStrength of the edge refraction (0 = none)

	maxDistance       = 9000,  -- camera distance beyond which bubbles are skipped
}

--------------------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------------------

local spEcho                 = Spring.Echo
local spGetGameFrame         = Spring.GetGameFrame
local spGetUnitViewPosition  = Spring.GetUnitViewPosition
local spGetUnitPosition      = Spring.GetUnitPosition
local spGetUnitShieldState   = Spring.GetUnitShieldState
local spValidUnitID          = Spring.ValidUnitID
local spGetUnitIsDead        = Spring.GetUnitIsDead
local spGetCameraPosition    = Spring.GetCameraPosition
local spGetUnitDefID         = Spring.GetUnitDefID
local spIsSphereInView       = Spring.IsSphereInView

local glTexture   = gl.Texture
local glCulling   = gl.Culling
local glDepthTest = gl.DepthTest
local glDepthMask = gl.DepthMask
local glBlending  = gl.Blending

local mathSqrt, mathAcos, mathAtan2 = math.sqrt, math.acos, math.atan2
local mathMin, mathMax, mathAbs, mathHuge = math.min, math.max, math.abs, math.huge

local MAX_HITS = 8
local INSTSTEP = 5 * 4 + MAX_HITS * 4 -- 52 floats

local luaShaderDirs = { "LuaUI/Widgets/Include/", "LuaUI/Include/" }

--------------------------------------------------------------------------------
-- Shaders
--------------------------------------------------------------------------------

local vsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack : require
#line 10000

layout (location = 0) in vec3 meshPos;      // unit sphere
layout (location = 1) in vec4 shieldParams; // radius, kind (0 bubble, 1 personal), rimAlpha, spare
layout (location = 2) in vec4 colorGood;    // rgb, a = color mult
layout (location = 3) in vec4 colorBad;     // rgb, cellScale
layout (location = 4) in vec4 state;        // spawnFrame, charge, popFrame, visibility
layout (location = 5) in vec4 center;       // world xyz, lastHitFrame
layout (location = 6) in vec4 hit0;         // theta, phi, frame, strength
layout (location = 7) in vec4 hit1;
layout (location = 8) in vec4 hit2;
layout (location = 9) in vec4 hit3;
layout (location = 10) in vec4 hit4;
layout (location = 11) in vec4 hit5;
layout (location = 12) in vec4 hit6;
layout (location = 13) in vec4 hit7;

//__ENGINEUNIFORMBUFFERDEFS__

uniform float popFrames;
uniform float spawnFrames;
uniform float backFace; // 1 when drawing back faces

out vec3 v_worldPos;
out vec3 v_normal;
flat out vec4 v_params;
flat out vec4 v_good;
flat out vec4 v_bad;
flat out vec4 v_state;
flat out vec4 v_center;
flat out vec4 v_hits[8];
flat out float v_fade;

void main() {
	float frame = timeInfo.x + timeInfo.w;
	float radius = shieldParams.x;
	float fade = state.w;

	// spawn fade-in, slight overshoot on the radius
	float spawnT = clamp((frame - state.x) / spawnFrames, 0.0, 1.0);
	fade *= spawnT;
	radius *= 1.0 + 0.08 * (1.0 - spawnT);

	// collapse: expand and dissolve
	if (state.z > 0.5) {
		float popT = clamp((frame - state.z) / popFrames, 0.0, 1.0);
		radius *= 1.0 + 0.35 * popT;
		fade *= (1.0 - popT) * (1.0 - popT);
	}

	vec3 n = meshPos;
	vec3 wp = center.xyz + n * radius;

	v_worldPos = wp;
	v_normal = n;
	v_params = vec4(radius, shieldParams.y, shieldParams.z, backFace);
	v_good = colorGood;
	v_bad = colorBad;
	v_state = state;
	v_center = center;
	v_hits[0] = hit0; v_hits[1] = hit1; v_hits[2] = hit2; v_hits[3] = hit3;
	v_hits[4] = hit4; v_hits[5] = hit5; v_hits[6] = hit6; v_hits[7] = hit7;
	v_fade = fade;

	if (fade <= 0.001) {
		gl_Position = vec4(-4.0, -4.0, 0.0, 1.0);
		return;
	}
	gl_Position = cameraViewProj * vec4(wp, 1.0);
}
]]

local fsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack : require
#line 20000

//__ENGINEUNIFORMBUFFERDEFS__

uniform sampler2D mapDepths;
uniform sampler2D modelDepths;

uniform float rimPower;
uniform float fillAlpha;
uniform float backFaceMult;
uniform float cellAlpha;
uniform float cellScroll;
uniform float hitCoreFrames;
uniform float hitRingFrames;
uniform float hitRingSpeed;
uniform float hitRingWidth;
uniform float hitCoreSize;
uniform float lowChargeFlicker;
uniform float intersectRange;
uniform float intersectAlpha;
uniform float personalFlashFrames;
uniform float cloakVeilAlpha;
uniform float cloakRimAlpha;
uniform float cloakRingAlpha;
uniform float cloakNoiseScale;
uniform float cloakNoiseSpeed;

in vec3 v_worldPos;
in vec3 v_normal;
flat in vec4 v_params;   // radius, kind, rimAlpha, backFace
flat in vec4 v_good;
flat in vec4 v_bad;
flat in vec4 v_state;    // spawnFrame, charge, popFrame, visibility
flat in vec4 v_center;   // xyz, lastHitFrame
flat in vec4 v_hits[8];
flat in float v_fade;

out vec4 fragColor;

// ---- 3D cell (Worley) pattern, pole free on the sphere ----
vec3 hash3(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)),
	         dot(p, vec3(269.5, 183.3, 246.1)),
	         dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453123);
}

// returns (F1, F2): distance to nearest and second nearest cell centre
vec2 worley(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float f1 = 8.0, f2 = 8.0;
	for (int z = -1; z <= 1; z++)
	for (int y = -1; y <= 1; y++)
	for (int x = -1; x <= 1; x++) {
		vec3 g = vec3(float(x), float(y), float(z));
		vec3 o = hash3(i + g);
		float d = length(g + o - f);
		if (d < f1) { f2 = f1; f1 = d; }
		else if (d < f2) { f2 = d; }
	}
	return vec2(f1, f2);
}

float hash1(float n) { return fract(sin(n) * 43758.5453123); }

// ---- 3D value noise for the cloak veil ----
float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash3(i + vec3(0.0, 0.0, 0.0)).x;
	float n100 = hash3(i + vec3(1.0, 0.0, 0.0)).x;
	float n010 = hash3(i + vec3(0.0, 1.0, 0.0)).x;
	float n110 = hash3(i + vec3(1.0, 1.0, 0.0)).x;
	float n001 = hash3(i + vec3(0.0, 0.0, 1.0)).x;
	float n101 = hash3(i + vec3(1.0, 0.0, 1.0)).x;
	float n011 = hash3(i + vec3(0.0, 1.0, 1.0)).x;
	float n111 = hash3(i + vec3(1.0, 1.0, 1.0)).x;
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
	           mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

// theta from world +y, phi around y (matches AddHit in Lua)
vec3 sphericalDir(float theta, float phi) {
	float st = sin(theta);
	return vec3(st * cos(phi), cos(theta), st * sin(phi));
}

void main() {
	float frame = timeInfo.x + timeInfo.w;
	float radius = v_params.x;
	float kind = v_params.y;
	float rimAlpha = v_params.z;
	float isBack = v_params.w;
	float charge = v_state.y;

	vec3 n = normalize(v_normal);
	vec3 camPos = cameraViewInv[3].xyz;
	vec3 toCam = camPos - v_worldPos;
	float camDist = length(toCam);
	vec3 v = toCam / camDist;
	float ndv = abs(dot(n, v));
	float fres = pow(1.0 - ndv, rimPower);

	// ---- cells ----
	float cellsPerRadius = max(v_bad.w * radius, 3.0);
	vec3 cellP = n * cellsPerRadius + vec3(0.0, timeInfo.y * cellScroll * cellsPerRadius * 0.05, 0.0);
	vec2 w = worley(cellP);
	float edge = 1.0 - smoothstep(0.0, 0.12, w.y - w.x); // 1 on cell boundaries
	float cellBody = smoothstep(0.05, 0.35, w.y - w.x);  // 1 inside a cell

	// ---- impacts ----
	float core = 0.0;
	float ring = 0.0;
	float plate = 0.0; // lights the cell containing / near an impact
	for (int i = 0; i < 8; i++) {
		vec4 h = v_hits[i];
		float s = h.w;
		if (s <= 0.001) continue;
		float age = frame - h.z;
		if (age < 0.0) continue;
		vec3 hd = sphericalDir(h.x, h.y);
		float ang = acos(clamp(dot(n, hd), -1.0, 1.0));
		float size = hitCoreSize * (0.4 + 0.6 * s);
		float c = exp(-(ang * ang) / (size * size)) * exp(-age / hitCoreFrames);
		float rr = age * hitRingSpeed * (0.6 + 0.4 * s);
		float rw = hitRingWidth * (0.7 + 0.6 * s);
		float r = exp(-((ang - rr) * (ang - rr)) / (rw * rw)) * exp(-age / hitRingFrames);
		r *= smoothstep(0.0, 0.3, rr); // ring starts under the core
		core += s * c;
		ring += s * r * 0.85;
		plate += s * exp(-(ang * ang) / (size * size * 6.0)) * exp(-age / (hitRingFrames * 1.2));
	}
	plate = clamp(plate, 0.0, 1.0);
	float hitGlow = core * 2.2 + ring * 1.2 + plate * cellBody * 0.9 + plate * edge * 1.4;

	// ---- intersection with the scene ----
	vec2 screenUV = gl_FragCoord.xy / viewGeometry.xy;
	float mapdepth = texture(mapDepths, screenUV).x;
	float modeldepth = texture(modelDepths, screenUV).x;
	float worlddepth = min(mapdepth, modeldepth);
	vec4 scenePos = cameraViewProjInv * vec4(screenUV * 2.0 - 1.0, worlddepth, 1.0);
	scenePos.xyz /= scenePos.w;
	float sceneDist = length(scenePos.xyz - v_worldPos);
	float iRange = max(radius * intersectRange, 6.0);
	float intersect = 1.0 - smoothstep(0.0, iRange, sceneDist);
	intersect *= intersect;

	// ---- charge ----
	float chargeT = smoothstep(0.0, 0.6, charge);
	vec3 baseCol = mix(v_bad.rgb, v_good.rgb, chargeT) * v_good.a;
	float chargeAlpha = mix(0.35, 1.0, chargeT);
	float flicker = 1.0;
	if (charge < lowChargeFlicker && kind < 0.5) {
		float f = hash1(floor(frame * 0.7) + floor(v_center.x));
		flicker = 0.55 + 0.45 * step(0.35, f);
	}

	float faceMult = mix(1.0, backFaceMult, isBack);

	float alpha, additive;
	vec3 col;
	if (kind < 0.5) {
		// ---- bubble ----
		float rim = fres * rimAlpha;
		float cells = edge * cellAlpha * (0.4 + 0.6 * chargeT) * (0.5 + 0.5 * fres);
		alpha = (rim + cells + fillAlpha) * chargeAlpha * flicker * faceMult;
		col = baseCol;
		additive = (hitGlow + intersect * intersectAlpha * (0.6 + 0.4 * chargeT)) * faceMult;
		// collapse: everything goes to the bad color and blows out
		if (v_state.z > 0.5) {
			col = mix(col, v_bad.rgb, 0.6);
			additive += fres * 0.8;
		}
	} else if (kind < 1.5) {
		// ---- personal overshield: only the impact and a short body flash ----
		float sinceHit = frame - v_center.w;
		float flash = exp(-max(sinceHit, 0.0) / personalFlashFrames);
		alpha = (fres * 0.30 * flash + 0.015 * flash) * faceMult;
		col = baseCol;
		additive = (hitGlow * 0.8 + fres * flash * 0.5 + edge * flash * 0.12) * faceMult;
	} else {
		// ---- cloak field: dim veil, flowing noise, ground ring ----
		vec3 np = n * cloakNoiseScale + vec3(timeInfo.y * cloakNoiseSpeed * 0.4, timeInfo.y * cloakNoiseSpeed, 0.0);
		float veil = vnoise(np) * 0.6 + vnoise(np * 2.3 + 7.1) * 0.4;
		veil = smoothstep(0.25, 0.85, veil);
		float rim = pow(1.0 - ndv, 1.4) * cloakRimAlpha * (0.5 + 0.5 * veil);
		// the veil is mostly dark: a low alpha with a dark colour darkens what is behind it
		alpha = (cloakVeilAlpha * (0.55 + 0.45 * veil) + rim) * faceMult;
		col = v_good.rgb * v_good.a * (0.25 + 0.5 * veil);
		// ground ring and a faint glint of the noise crests
		additive = (intersect * cloakRingAlpha + veil * veil * 0.05 + rim * 0.35) * faceMult;
		if (v_state.z > 0.5) {
			additive += pow(1.0 - ndv, 1.4) * 0.35; // collapse flash
		}
	}

	alpha = clamp(alpha * v_fade, 0.0, 1.0);
	additive *= v_fade;
	// premultiplied alpha plus an additive glow term
	fragColor = vec4(col * alpha + col * additive, alpha);
}
]]

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local LuaShader
local shader
local meshVBO, indexVBO, instanceVBO, vao
local numIndices = 0
local capacity = 64
local resourcesReady = false
local hasDistortion = false

local numInstances = 0
local instKeys  = {}  -- slot -> key (unitID for bubbles, -unitID for personal)
local instData  = {}  -- slot -> 52 floats
local indexOf   = {}  -- key -> slot
local shields   = {}  -- key -> record
local dirty     = {}  -- slot -> true when the instance needs uploading

-- unitDefID -> shield description, or false
local defShield = {}

local personalColorDef = {}   -- unitDefID -> {r,g,b}
local cloakColorDef = {}      -- unitDefID -> {r,g,b}
local CLOAK_KEY_OFFSET = 1000000 -- cloak instances are keyed unitID + this (bubbles: unitID, personal: -unitID)
local myAllyTeamID = Spring.GetMyAllyTeamID()
local spec, fullview = Spring.GetSpectatingState()
local unitRadiusCache = {}

local gameFrame = 0
local myFrameOffset = 0

local function Fail(msg)
	spEcho("[ShieldsGL4] " .. msg .. ", removing widget")
	widgetHandler:RemoveWidget()
	return false
end

--------------------------------------------------------------------------------
-- Def parsing
--------------------------------------------------------------------------------

local function parseColor(str, default)
	if type(str) ~= "string" then return default end
	local r, g, b = str:match("([%d%.]+)%s+([%d%.]+)%s+([%d%.]+)")
	if r then return { tonumber(r), tonumber(g), tonumber(b) } end
	return default
end

local function BuildDefs()
	for unitDefID = 1, #UnitDefs do
		local ud = UnitDefs[unitDefID]
		local cp = ud.customParams or {}
		local entry = false
		for i, w in ipairs(ud.weapons) do
			local wd = WeaponDefs[w.weaponDef]
			if wd and wd.type == "Shield" and wd.shieldRadius and wd.shieldRadius > 0 then
				local good = parseColor(cp.shield_color_good, nil)
				local bad  = parseColor(cp.shield_color_bad, nil)
				if not good then
					local sg = wd.shieldGoodColor
					good = sg and { sg[1], sg[2], sg[3] } or { 0.0, 0.3, 1.0 }
				end
				if not bad then
					local sb = wd.shieldBadColor
					bad = sb and { sb[1], sb[2], sb[3] } or { 1.0, 0.1, 0.0 }
				end
				-- engine shield colors are often very dark; lift them so the rim reads
				local function lift(c)
					local m = mathMax(c[1], c[2], c[3], 0.001)
					local k = mathMax(1.0, 0.85 / m)
					return { mathMin(c[1] * k, 1.3), mathMin(c[2] * k, 1.3), mathMin(c[3] * k, 1.3) }
				end
				good, bad = lift(good), lift(bad)
				local radius = tonumber(cp.shield_radius) or wd.shieldRadius
				entry = {
					weaponNum = i,
					radius    = radius,
					emitY     = tonumber(cp.shield_emit_height) or 0,
					emitZ     = tonumber(cp.shield_emit_offset) or 0,
					capacity  = tonumber(cp.shield_power) or wd.shieldPower or 1000,
					good      = good,
					bad       = bad,
					colorMult = tonumber(cp.shield_color_mult) or 1,
					rimAlpha  = (radius < 250) and cfg.rimAlphaSmall or cfg.rimAlphaLarge,
					cellScale = tonumber(cp.shield_cell_scale) or cfg.cellScale,
				}
				break
			end
		end
		defShield[unitDefID] = entry
		if cp.isshieldedunit == "1" then
			personalColorDef[unitDefID] = parseColor(cp.personal_shield_color, cfg.personalColor)
		end
		if cp.area_cloak and cp.area_cloak ~= "0" then
			cloakColorDef[unitDefID] = parseColor(cp.area_cloak_color, cfg.cloakColor)
		end
	end
end

--------------------------------------------------------------------------------
-- GL resources
--------------------------------------------------------------------------------

local instanceLayout = {
	{ id = 1,  name = "shieldParams", size = 4 },
	{ id = 2,  name = "colorGood",    size = 4 },
	{ id = 3,  name = "colorBad",     size = 4 },
	{ id = 4,  name = "state",        size = 4 },
	{ id = 5,  name = "center",       size = 4 },
	{ id = 6,  name = "hit0",         size = 4 },
	{ id = 7,  name = "hit1",         size = 4 },
	{ id = 8,  name = "hit2",         size = 4 },
	{ id = 9,  name = "hit3",         size = 4 },
	{ id = 10, name = "hit4",         size = 4 },
	{ id = 11, name = "hit5",         size = 4 },
	{ id = 12, name = "hit6",         size = 4 },
	{ id = 13, name = "hit7",         size = 4 },
}

local function DestroyResources()
	if vao then vao:Delete() end
	if meshVBO then meshVBO:Delete() end
	if indexVBO then indexVBO:Delete() end
	if instanceVBO then instanceVBO:Delete() end
	vao, meshVBO, indexVBO, instanceVBO = nil, nil, nil, nil
	if shader then shader:Finalize() end
	shader = nil
	resourcesReady = false
end

local function BuildSphereMesh(sectors, stacks)
	meshVBO = gl.GetVBO(GL.ARRAY_BUFFER, false)
	indexVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false)
	if not (meshVBO and indexVBO) then return false end

	local verts = {}
	local PI = math.pi
	for j = 0, stacks do
		local stackAngle = PI / 2 - j * PI / stacks
		local xy = math.cos(stackAngle)
		local z = math.sin(stackAngle)
		for i = 0, sectors do
			local sectorAngle = i * 2 * PI / sectors
			verts[#verts + 1] = xy * math.cos(sectorAngle)
			verts[#verts + 1] = z
			verts[#verts + 1] = xy * math.sin(sectorAngle)
		end
	end
	local numVerts = (stacks + 1) * (sectors + 1)
	meshVBO:Define(numVerts, { { id = 0, name = "meshPos", size = 3 } })
	meshVBO:Upload(verts)

	local idx = {}
	for j = 0, stacks - 1 do
		local k1 = j * (sectors + 1)
		local k2 = k1 + sectors + 1
		for i = 0, sectors - 1 do
			if j ~= 0 then
				idx[#idx + 1] = k1 + i; idx[#idx + 1] = k2 + i; idx[#idx + 1] = k1 + i + 1
			end
			if j ~= stacks - 1 then
				idx[#idx + 1] = k1 + i + 1; idx[#idx + 1] = k2 + i; idx[#idx + 1] = k2 + i + 1
			end
		end
	end
	numIndices = #idx
	indexVBO:Define(numIndices)
	indexVBO:Upload(idx)
	return true
end

local function UploadInstance(slot)
	instanceVBO:Upload(instData[slot], nil, slot - 1, 1, INSTSTEP)
	dirty[slot] = nil
end

local function BuildInstanceBuffer(newCapacity)
	if vao then vao:Delete() end
	if instanceVBO then instanceVBO:Delete() end
	capacity = newCapacity
	instanceVBO = gl.GetVBO(GL.ARRAY_BUFFER, true)
	if not instanceVBO then return false end
	instanceVBO:Define(capacity, instanceLayout)

	vao = gl.GetVAO()
	if not vao then return false end
	vao:AttachVertexBuffer(meshVBO)
	vao:AttachInstanceBuffer(instanceVBO)
	vao:AttachIndexBuffer(indexVBO)

	for slot = 1, numInstances do
		UploadInstance(slot)
	end
	return true
end

local function UpdateUniforms()
	if not shader then return end
	shader:ActivateWith(function()
		shader:SetUniform("popFrames", cfg.popFrames)
		shader:SetUniform("spawnFrames", cfg.spawnFrames)
		shader:SetUniform("rimPower", cfg.rimPower)
		shader:SetUniform("fillAlpha", cfg.fillAlpha)
		shader:SetUniform("backFaceMult", cfg.backFaceMult)
		shader:SetUniform("cellAlpha", cfg.cellAlpha)
		shader:SetUniform("cellScroll", cfg.cellScroll)
		shader:SetUniform("hitCoreFrames", cfg.hitCoreFrames)
		shader:SetUniform("hitRingFrames", cfg.hitRingFrames)
		shader:SetUniform("hitRingSpeed", cfg.hitRingSpeed)
		shader:SetUniform("hitRingWidth", cfg.hitRingWidth)
		shader:SetUniform("hitCoreSize", cfg.hitCoreSize)
		shader:SetUniform("lowChargeFlicker", cfg.lowChargeFlicker)
		shader:SetUniform("intersectRange", cfg.intersectRange)
		shader:SetUniform("intersectAlpha", cfg.intersectAlpha)
		shader:SetUniform("personalFlashFrames", cfg.personalFlashFrames)
		shader:SetUniform("cloakVeilAlpha", cfg.cloakVeilAlpha)
		shader:SetUniform("cloakRimAlpha", cfg.cloakRimAlpha)
		shader:SetUniform("cloakRingAlpha", cfg.cloakRingAlpha)
		shader:SetUniform("cloakNoiseScale", cfg.cloakNoiseScale)
		shader:SetUniform("cloakNoiseSpeed", cfg.cloakNoiseSpeed)
	end)
end

local function CreateResources()
	DestroyResources()
	local engineDefs = LuaShader.GetEngineUniformBufferDefs and LuaShader.GetEngineUniformBufferDefs()
	if not engineDefs then return Fail("LuaShader.GetEngineUniformBufferDefs missing (GL4 LuaShader required)") end

	local vs = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineDefs)
	local fs = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineDefs)

	shader = LuaShader({
		vertex = vs,
		fragment = fs,
		uniformInt = { mapDepths = 0, modelDepths = 1 },
		uniformFloat = { backFace = 0 },
	}, "Shields GL4")
	if not shader:Initialize() then return Fail("shader failed to compile") end

	if not BuildSphereMesh(40, 26) then return Fail("could not create sphere mesh") end
	if not BuildInstanceBuffer(mathMax(capacity, 64)) then return Fail("could not create instance buffer") end

	resourcesReady = true
	UpdateUniforms()
	return true
end

--------------------------------------------------------------------------------
-- Instance management
--------------------------------------------------------------------------------

local function MarkDirty(slot)
	dirty[slot] = true
end

local function NewInstanceData(rec)
	local d = {}
	for i = 1, INSTSTEP do d[i] = 0 end
	d[1], d[2], d[3] = rec.radius, rec.kind, rec.rimAlpha
	d[5], d[6], d[7], d[8] = rec.good[1], rec.good[2], rec.good[3], rec.colorMult
	d[9], d[10], d[11], d[12] = rec.bad[1], rec.bad[2], rec.bad[3], rec.cellScale
	d[13], d[14], d[15], d[16] = rec.spawnFrame, rec.charge, 0, rec.visible and 1 or 0
	d[17], d[18], d[19], d[20] = rec.x, rec.y, rec.z, rec.lastHitFrame
	return d
end

local function AddInstance(key, rec)
	if indexOf[key] then return end
	local slot = numInstances + 1
	numInstances = slot
	instKeys[slot] = key
	indexOf[key] = slot
	instData[slot] = NewInstanceData(rec)
	shields[key] = rec
	rec.slot = slot
	if not resourcesReady then return end
	if slot > capacity then
		if not BuildInstanceBuffer(capacity * 2) then Fail("instance buffer grow failed") end
		return
	end
	UploadInstance(slot)
end

local function RemoveInstance(key)
	local slot = indexOf[key]
	if not slot then return end
	local last = numInstances
	local lastKey = instKeys[last]
	local lastData = instData[last]
	instKeys[last] = nil
	instData[last] = nil
	dirty[last] = nil
	indexOf[key] = nil
	shields[key] = nil
	numInstances = last - 1
	if slot ~= last then
		instKeys[slot] = lastKey
		instData[slot] = lastData
		indexOf[lastKey] = slot
		shields[lastKey].slot = slot
		if resourcesReady then UploadInstance(slot) end
	end
end

local function SetCenter(rec, x, y, z)
	local d = instData[rec.slot]
	if d[17] ~= x or d[18] ~= y or d[19] ~= z then
		d[17], d[18], d[19] = x, y, z
		rec.x, rec.y, rec.z = x, y, z
		MarkDirty(rec.slot)
	end
end

local function SetState(rec, charge, popFrame, visible, spawnFrame)
	local d = instData[rec.slot]
	local vis = visible and 1 or 0
	if d[13] ~= spawnFrame or d[14] ~= charge or d[15] ~= popFrame or d[16] ~= vis then
		d[13], d[14], d[15], d[16] = spawnFrame, charge, popFrame, vis
		MarkDirty(rec.slot)
	end
end

--------------------------------------------------------------------------------
-- Hits
--------------------------------------------------------------------------------

local hitDistortionTable = {
	distortionType = "point",
	distortionConfig = {
		posx = 0, posy = 0, posz = 0,
		radius = 90,
		noiseScaleSpace = 0.1,
		noiseStrength = 0.15,
		onlyModelMap = 0,
		lifeTime = 5,
		refractiveIndex = 1.04,
		decay = 3,
		rampUp = 1,
		effectStrength = 2.2,
		startRadius = 0.4,
		shockWidth = -1.2,
		effectType = "airShockwave",
	},
}

local function AddHit(rec, strength, hx, hy, hz)
	local d = instData[rec.slot]
	-- direction from the shield centre, in the sphere's own frame
	local dx, dy, dz = hx - rec.x, hy - rec.y, hz - rec.z
	local len = mathSqrt(dx * dx + dy * dy + dz * dz)
	if len < 1e-3 then dx, dy, dz, len = 0, 1, 0, 1 end
	dx, dy, dz = dx / len, dy / len, dz / len
	-- theta from world +y, phi around y (see sphericalDir in the shader)
	local theta = mathAcos(mathMax(-1, mathMin(1, dy)))
	local phi = mathAtan2(dz, dx)

	local frame = gameFrame
	-- merge with a recent nearby hit (beams, rapid fire)
	local oldestSlot, oldestFrame = 1, mathHuge
	local weakestSlot, weakestStr = 1, mathHuge
	for i = 0, MAX_HITS - 1 do
		local b = 21 + i * 4
		local s = d[b + 3]
		if s > 0 then
			local age = frame - d[b + 2]
			if age <= cfg.hitMergeFrames then
				local dt, dp = theta - d[b], phi - d[b + 1]
				if dp > math.pi then dp = dp - 2 * math.pi elseif dp < -math.pi then dp = dp + 2 * math.pi end
				local ang = mathSqrt(dt * dt + (dp * math.sin(theta)) ^ 2)
				if ang < cfg.hitMergeAngle then
					d[b + 2] = frame
					d[b + 3] = mathMin(1, s + strength * 0.35)
					MarkDirty(rec.slot)
					rec.lastHitFrame = frame
					d[20] = frame
					return
				end
			end
			if d[b + 2] < oldestFrame then oldestFrame, oldestSlot = d[b + 2], i end
			if s < weakestStr then weakestStr, weakestSlot = s, i end
		else
			-- free slot
			d[b], d[b + 1], d[b + 2], d[b + 3] = theta, phi, frame, strength
			d[20] = frame
			rec.lastHitFrame = frame
			MarkDirty(rec.slot)
			return
		end
	end
	-- all slots in use: replace the oldest
	local b = 21 + oldestSlot * 4
	d[b], d[b + 1], d[b + 2], d[b + 3] = theta, phi, frame, strength
	d[20] = frame
	rec.lastHitFrame = frame
	MarkDirty(rec.slot)
end

local function ExpireHits()
	-- clear strengths of hits that have fully faded so the shader loop can skip them
	local cutoff = gameFrame - cfg.hitRingFrames * 5
	for slot = 1, numInstances do
		local d = instData[slot]
		local changed = false
		for i = 0, MAX_HITS - 1 do
			local b = 21 + i * 4
			if d[b + 3] > 0 and d[b + 2] < cutoff then
				d[b + 3] = 0
				changed = true
			end
		end
		if changed then MarkDirty(slot) end
	end
end

--------------------------------------------------------------------------------
-- Bubble shields (engine Shield weapons)
--------------------------------------------------------------------------------

local function ShieldAdd(unitID, unitDefID)
	unitDefID = unitDefID or spGetUnitDefID(unitID)
	local def = unitDefID and defShield[unitDefID]
	if not def then return end
	if shields[unitID] then return end
	local x, y, z = spGetUnitPosition(unitID)
	local rec = {
		kind = 0,
		unitID = unitID,
		unitDefID = unitDefID,
		def = def,
		radius = def.radius,
		rimAlpha = def.rimAlpha,
		good = def.good,
		bad = def.bad,
		colorMult = def.colorMult,
		cellScale = def.cellScale,
		capacity = mathMax(def.capacity, 1),
		spawnFrame = gameFrame,
		charge = 1,
		visible = true,
		popFrame = 0,
		x = (x or 0), y = (y or 0) + def.emitY, z = (z or 0) + def.emitZ,
		lastHitFrame = -1000,
		fallbackCharge = 1,
	}
	AddInstance(unitID, rec)
end

local function ShieldRemove(unitID)
	RemoveInstance(unitID)
end

local function ShieldVisible(unitID, visible)
	local rec = shields[unitID]
	if not rec then return end
	rec.visible = visible and true or false
end

local function ShieldState(unitID, x, y, z, charge)
	local rec = shields[unitID]
	if not rec then return end
	rec.fx, rec.fy, rec.fz = x, y, z
	rec.fallbackCharge = charge
end

local function ShieldHit(unitID, damage, hx, hy, hz)
	local rec = shields[unitID]
	if not rec or not rec.visible then return end
	local strength = mathMin(1, mathMax(cfg.hitStrengthMin, (damage / rec.capacity) * cfg.hitStrengthMult))
	AddHit(rec, strength, hx, hy, hz)
	if strength >= cfg.hitDistortionMin and hasDistortion and WG.distortionsgl4 and WG.distortionsgl4.AddPointEffectAt then
		if spIsSphereInView(hx, hy, hz, 50) then
			hitDistortionTable.distortionConfig.radius = 60 + 90 * strength
			hitDistortionTable.initComplete = nil
			hitDistortionTable.distortionParamTable = nil
			WG.distortionsgl4.AddPointEffectAt(hitDistortionTable, hx, hy, hz)
		end
	end
end

--------------------------------------------------------------------------------
-- Personal overshields
--------------------------------------------------------------------------------

local function PersonalHit(unitID, damage, maxStrength, hx, hy, hz)
	if not spValidUnitID(unitID) then return end
	local key = -unitID
	local rec = shields[key]
	local x, y, z = spGetUnitViewPosition(unitID, true)
	if not x then return end -- not visible to this player
	if not rec then
		local unitDefID = spGetUnitDefID(unitID)
		local radius = unitRadiusCache[unitDefID]
		if not radius then
			local ud = UnitDefs[unitDefID]
			radius = ((ud and ud.radius) or 20) * cfg.personalRadiusMult
			unitRadiusCache[unitDefID] = radius
		end
		local col = personalColorDef[unitDefID] or cfg.personalColor
		rec = {
			kind = 1,
			unitID = unitID,
			radius = radius,
			rimAlpha = cfg.rimAlphaSmall,
			good = col,
			bad = col,
			colorMult = 1,
			cellScale = cfg.cellScale * 2.5,
			capacity = mathMax(maxStrength or 100, 1),
			spawnFrame = gameFrame - cfg.spawnFrames, -- no fade-in
			charge = 1,
			visible = true,
			popFrame = 0,
			x = x, y = y, z = z,
			lastHitFrame = gameFrame,
		}
		AddInstance(key, rec)
	end
	if not hx then
		-- no position: pick a direction from the camera side so it reads on screen
		local cx, cy, cz = spGetCameraPosition()
		hx, hy, hz = x + (cx - x) * 0.01, y + (cy - y) * 0.01 + rec.radius * 0.3, z + (cz - z) * 0.01
	end
	local strength = mathMin(1, mathMax(cfg.hitStrengthMin, (damage / rec.capacity) * cfg.personalStrengthMult))
	AddHit(rec, strength, hx, hy, hz)
end

--------------------------------------------------------------------------------
-- Cloak fields (unit_cloak_shield.lua)
--------------------------------------------------------------------------------

local cloakDistortionTable = {
	distortionType = "point",
	distortionConfig = {
		posx = 0, posy = 0, posz = 0,
		radius = 300,
		noiseScaleSpace = 0.02,
		noiseStrength = 0.3,
		onlyModelMap = 0,
		lifeTime = 0, -- persistent, removed by hand
		effectStrength = 0.9,
		startRadius = 1.0,
		effectType = "shieldSphere",
	},
}

local function CloakVisibleToMe(unitID)
	if fullview then return true end
	local allyTeam = Spring.GetUnitAllyTeam(unitID)
	return allyTeam ~= nil and allyTeam == myAllyTeamID
end

local function CloakSetDistortion(rec, remove)
	if not (WG.distortionsgl4 and WG.distortionsgl4.AddPointEffectAt) then return end
	if remove or cfg.cloakDistortion <= 0 then
		if rec.distID and WG.distortionsgl4.RemovePointEffect then
			WG.distortionsgl4.RemovePointEffect(rec.distID)
		end
		rec.distID = nil
		return
	end
	local dc = cloakDistortionTable.distortionConfig
	dc.radius = rec.radius
	dc.effectStrength = cfg.cloakDistortion
	cloakDistortionTable.initComplete = nil
	cloakDistortionTable.distortionParamTable = nil
	rec.distID = WG.distortionsgl4.AddPointEffectAt(cloakDistortionTable, rec.x, rec.y, rec.z, rec.distID)
	rec.distRadius, rec.distX, rec.distY, rec.distZ = rec.radius, rec.x, rec.y, rec.z
end

local function CloakUpdate(unitID, radius)
	radius = tonumber(radius) or 0
	local key = unitID + CLOAK_KEY_OFFSET
	local rec = shields[key]
	if radius <= 0 then
		if rec then
			rec.targetRadius = 0
			if rec.popFrame == 0 then rec.popFrame = gameFrame end
		end
		return
	end
	if not spValidUnitID(unitID) or not CloakVisibleToMe(unitID) then return end
	if not rec then
		local unitDefID = spGetUnitDefID(unitID)
		local x, y, z = spGetUnitViewPosition(unitID, true)
		if not x then return end
		local col = cloakColorDef[unitDefID] or cfg.cloakColor
		rec = {
			kind = 2,
			unitID = unitID,
			radius = radius * 0.3, -- grows in
			targetRadius = radius,
			rimAlpha = cfg.cloakRimAlpha,
			good = col,
			bad = col,
			colorMult = 1,
			cellScale = cfg.cellScale,
			capacity = 1,
			spawnFrame = gameFrame,
			charge = 1,
			visible = true,
			popFrame = 0,
			x = x, y = y, z = z,
			lastHitFrame = -1000,
		}
		AddInstance(key, rec)
		CloakSetDistortion(rec)
	else
		rec.targetRadius = radius
		if rec.popFrame > 0 then
			-- switched back on mid-collapse
			rec.popFrame = 0
			rec.spawnFrame = gameFrame
			local d = instData[rec.slot]
			d[13], d[15] = gameFrame, 0
			MarkDirty(rec.slot)
		end
	end
end

local function CloakRemoveAll()
	for slot = numInstances, 1, -1 do
		local key = instKeys[slot]
		if key > CLOAK_KEY_OFFSET then
			CloakSetDistortion(shields[key], true)
			RemoveInstance(key)
		end
	end
end

--------------------------------------------------------------------------------
-- Per-frame update
--------------------------------------------------------------------------------

local function UpdateShields()
	local frame = gameFrame
	local toRemove
	for slot = 1, numInstances do
		local key = instKeys[slot]
		local rec = shields[key]
		local unitID = rec.unitID
		if not spValidUnitID(unitID) or spGetUnitIsDead(unitID) then
			toRemove = toRemove or {}
			toRemove[#toRemove + 1] = key
		elseif rec.kind == 0 then
			local def = rec.def
			local x, y, z = spGetUnitViewPosition(unitID, false)
			local charge
			if x then
				local on, power = spGetUnitShieldState(unitID)
				if power then
					charge = mathMax(0, mathMin(1, power / rec.capacity))
					if on == false then charge = 0 end
				end
				-- emit offset follows the unit heading
				if def.emitZ ~= 0 then
					local fx, fy, fz = Spring.GetUnitDirection(unitID)
					if fx then x, y, z = x + fx * def.emitZ, y + fy * def.emitZ, z + fz * def.emitZ end
				end
				y = y + def.emitY
			else
				x, y, z = rec.fx, rec.fy, rec.fz
				if x then y = y + def.emitY; z = z + def.emitZ end
			end
			charge = charge or rec.fallbackCharge or rec.charge
			if x then SetCenter(rec, x, y, z) end

			-- collapse / respawn tracking
			local popFrame = rec.popFrame
			local spawnFrame = rec.spawnFrame
			if rec.charge > 0.01 and charge <= 0.001 then
				popFrame = frame
			elseif charge > 0.03 and popFrame > 0 and frame - popFrame >= cfg.popFrames then
				popFrame = 0
				spawnFrame = frame
			end
			rec.charge = charge
			rec.popFrame = popFrame
			rec.spawnFrame = spawnFrame
			local visible = rec.visible and (popFrame == 0 or frame - popFrame < cfg.popFrames) and x ~= nil
			if charge <= 0.001 and popFrame == 0 then visible = false end
			SetState(rec, charge, popFrame, visible, spawnFrame)
		elseif rec.kind == 1 then
			-- personal: track the unit, expire after the last hit fades
			if frame - rec.lastHitFrame > cfg.personalLife then
				toRemove = toRemove or {}
				toRemove[#toRemove + 1] = key
			else
				local x, y, z = spGetUnitViewPosition(unitID, true)
				if x then SetCenter(rec, x, y, z) end
			end
		else
			-- cloak field: follow the unit, ease the radius, collapse when switched off
			local x, y, z = spGetUnitViewPosition(unitID, true)
			if x then SetCenter(rec, x, y, z) end
			if rec.popFrame > 0 and frame - rec.popFrame >= cfg.popFrames then
				toRemove = toRemove or {}
				toRemove[#toRemove + 1] = key
			else
				local target = (rec.popFrame > 0) and rec.radius or rec.targetRadius
				local r = rec.radius + (target - rec.radius) * cfg.cloakGrowSmooth
				if mathAbs(target - r) < 0.5 then r = target end
				if r ~= rec.radius then
					rec.radius = r
					local d = instData[rec.slot]
					d[1] = r
					MarkDirty(rec.slot)
				end
				SetState(rec, 1, rec.popFrame, true, rec.spawnFrame)
				-- keep the edge refraction in step (cheap: a few cloakers at most)
				if rec.distID and (mathAbs((rec.distRadius or 0) - r) > 2 or mathAbs((rec.distX or 0) - rec.x) > 3
					or mathAbs((rec.distY or 0) - rec.y) > 3 or mathAbs((rec.distZ or 0) - rec.z) > 3) then
					CloakSetDistortion(rec)
				end
			end
		end
	end
	if toRemove then
		for i = 1, #toRemove do
			local rec = shields[toRemove[i]]
			if rec and rec.kind == 2 then CloakSetDistortion(rec, true) end
			RemoveInstance(toRemove[i])
		end
	end
end

--------------------------------------------------------------------------------
-- Draw
--------------------------------------------------------------------------------

local function UploadDirty()
	for slot in pairs(dirty) do
		if slot <= numInstances then UploadInstance(slot) else dirty[slot] = nil end
	end
end

function widget:DrawWorld()
	if not resourcesReady then
		if not CreateResources() then return end
	end
	if numInstances == 0 then return end
	UploadDirty()

	glTexture(0, "$map_gbuffer_zvaltex")
	glTexture(1, "$model_gbuffer_zvaltex")
	glDepthTest(GL.LEQUAL)
	glDepthMask(false)
	glBlending(GL.ONE, GL.ONE_MINUS_SRC_ALPHA)
	shader:Activate()
	-- back faces first, then front faces, so the far side shows through the near side
	glCulling(GL.FRONT)
	shader:SetUniform("backFace", 1)
	vao:DrawElements(GL.TRIANGLES, numIndices, 0, numInstances, 0)
	glCulling(GL.BACK)
	shader:SetUniform("backFace", 0)
	vao:DrawElements(GL.TRIANGLES, numIndices, 0, numInstances, 0)
	shader:Deactivate()
	glCulling(false)
	glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	glDepthMask(true)
	glDepthTest(false)
	glTexture(0, false)
	glTexture(1, false)
end

--------------------------------------------------------------------------------
-- Callins
--------------------------------------------------------------------------------

function widget:Update()
	gameFrame = spGetGameFrame()
	if numInstances > 0 then UpdateShields() end
end

function widget:GameFrame(n)
	gameFrame = n
	if n % 15 == 0 and numInstances > 0 then ExpireHits() end
end

function widget:UnitDestroyed(unitID)
	RemoveInstance(unitID)
	RemoveInstance(-unitID)
	local rec = shields[unitID + CLOAK_KEY_OFFSET]
	if rec then
		CloakSetDistortion(rec, true)
		RemoveInstance(unitID + CLOAK_KEY_OFFSET)
	end
end

function widget:PlayerChanged()
	myAllyTeamID = Spring.GetMyAllyTeamID()
	spec, fullview = Spring.GetSpectatingState()
	-- the gadgets re-send adds/visibility on their own schedule; drop stale
	-- personal flashes and cloak fields (visibility rules may have changed)
	for slot = numInstances, 1, -1 do
		local key = instKeys[slot]
		if key < 0 then RemoveInstance(key) end
	end
	CloakRemoveAll()
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function widget:Initialize()
	if not gl.GetVBO or not gl.GetVAO then
		spEcho("[ShieldsGL4] GL4 VBO API unavailable, removing widget")
		widgetHandler:RemoveWidget()
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
		spEcho("[ShieldsGL4] LuaShader not found, removing widget")
		widgetHandler:RemoveWidget()
		return
	end

	BuildDefs()
	gameFrame = spGetGameFrame()
	resourcesReady = false
	hasDistortion = true

	widgetHandler:RegisterGlobal("ShieldGL4_Add", ShieldAdd)
	widgetHandler:RegisterGlobal("ShieldGL4_Remove", ShieldRemove)
	widgetHandler:RegisterGlobal("ShieldGL4_Visible", ShieldVisible)
	widgetHandler:RegisterGlobal("ShieldGL4_State", ShieldState)
	widgetHandler:RegisterGlobal("ShieldGL4_Hit", ShieldHit)
	widgetHandler:RegisterGlobal("ShieldGL4_PersonalHit", PersonalHit)
	widgetHandler:RegisterGlobal("ShieldGL4_Active", function() return true end)
	widgetHandler:RegisterGlobal("ShieldGL4_Cloak", CloakUpdate)

	-- gadget-independent bootstrap for shields already on the map (the gadget
	-- also re-adds on its next sweep, AddInstance ignores duplicates)
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		local unitDefID = spGetUnitDefID(unitID)
		if unitDefID and defShield[unitDefID] then ShieldAdd(unitID, unitDefID) end
	end

	WG.shieldsgl4 = {
		getConfig = function() return cfg end,
		set = function(k, v)
			if cfg[k] ~= nil then
				cfg[k] = v
				UpdateUniforms()
			end
		end,
		hit = ShieldHit,
		personalHit = PersonalHit,
		cloak = CloakUpdate,
		-- debug: copy of the raw instance floats for a unitID (negative = personal)
		debugInstance = function(key)
			local slot = indexOf[key]
			if not slot then return nil end
			local out = {}
			for i = 1, INSTSTEP do out[i] = instData[slot][i] end
			return out
		end,
	}
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal("ShieldGL4_Add")
	widgetHandler:DeregisterGlobal("ShieldGL4_Remove")
	widgetHandler:DeregisterGlobal("ShieldGL4_Visible")
	widgetHandler:DeregisterGlobal("ShieldGL4_State")
	widgetHandler:DeregisterGlobal("ShieldGL4_Hit")
	widgetHandler:DeregisterGlobal("ShieldGL4_PersonalHit")
	widgetHandler:DeregisterGlobal("ShieldGL4_Active")
	widgetHandler:DeregisterGlobal("ShieldGL4_Cloak")
	CloakRemoveAll()
	DestroyResources()
	WG.shieldsgl4 = nil
end
