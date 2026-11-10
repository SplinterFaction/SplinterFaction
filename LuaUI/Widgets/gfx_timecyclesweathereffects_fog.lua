function widget:GetInfo()
	return {
		name      = "GFX Fog",
		desc      = "Volumetric ground fog: pools in low ground, drifts, takes sun shafts and shadows, and has local coloured volumes. Driven by the Weather widget",
		author    = "trepan, user, aegis, jK, Doo (volumetric rewrite 2026)",
		date      = "2026-11-10",
		version   = "5.0",
		license   = "GNU GPL, v2 or later",
		layer     = 1,
		enabled   = true,
	}
end

--------------------------------------------------------------------------------
--
--  Version 4 treated fog as one uniform slab: the length of the view ray inside
--  it, faded to one colour. This one marches each view ray through a density
--  field at reduced resolution and blends the result over the scene:
--
--    density   falls off with height above a heavily blurred copy of the
--              terrain, so fog lies over the land at every level, pools in
--              whatever is lower than its surroundings and lets ridges and
--              mesas stand clear; two octaves of drifting 3D noise carve it
--              (wisps, a ragged top)
--    light     every step asks the sun's shadow map whether it is lit, so
--              hills and units cast shafts of shadow through the fog and
--              sunlit fog glows, more so looking toward the sun
--    volumes   up to MAX_VOLUMES local blobs with their own colour, density
--              and glow, placed by other widgets (WG.fog.AddVolume) or by
--              gadgets (Script.LuaUI.FogVolumeAdd). Battle smoke uses them.
--
--  How much fog there is still comes from the Weather widget (rain, heat),
--  plus a little standing mist that thickens at night. Colour is Weather's fog
--  colour lit by the scene's sun and ambient light, so it follows the time of
--  day by itself.
--
--  Cost is steps x pixels / RES_DIV^2; the shadow lookups are the dear part.
--  WG.fog.SetQuality(0..3) trades it down: 0 off, 1 low (no shafts),
--  2 medium, 3 high.
--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Tuning
--------------------------------------------------------------------------------

local TUNE = {
	-- how much fog (0..1) before Weather adds rain / heat haze
	baseMist      = 0.20,   -- standing mist by day
	nightMist     = 0.22,   -- more of it at full night
	amountMult    = 1.0,    -- overall multiplier (the options menu sets this)

	-- density
	densityFull   = 0.0042, -- extinction per elmo at the fog base when the amount is 1
	falloff       = 120,    -- scale height (elmos): the fog thins by e every this much above its base
	blurRadius    = 520,    -- the base is the terrain blurred over this radius (elmos)
	baseBias      = -0.25,  -- base offset in scale heights (negative = thinner on level ground)
	topScales     = 3.2,    -- the march stops this many scale heights above the highest base

	-- noise (world elmos per repeat of the 64^3 noise cube)
	noiseScale1   = 1500,
	noiseScale2   = 430,
	noiseAmount   = 0.85,   -- 0 = smooth layer, 1 = fully carved by noise
	noiseHeight   = 0.9,    -- how far (in scale heights) noise pushes the top up and down
	windSpeed     = 14,     -- elmos per second the fog drifts (along the map wind)

	-- colour and light. Fog is near white and takes its colour from the light
	-- that falls on it; only this share comes from the map's own fog colour.
	-- (Painted fully in that colour it vanished on maps whose fog colour
	-- matches their ground, which is most of them.)
	fogWhite      = 0.92,
	mapTint       = 0.35,
	sunScatter    = 1.25,   -- sunlit fog brightness
	ambScatter    = 0.85,   -- shadowed fog brightness
	anisotropy    = 0.55,   -- forward scattering: fog toward the sun glows
	maxDist       = 14000,  -- view rays are not marched past this
	edgeFade      = 1400,   -- the layer fades out over this distance past the map's edge

	-- battle smoke: a dark volume where a unit with a big death explosion died
	battleSmoke   = true,
	smokeMinAoE   = 110,
	smokeLife     = 26,     -- seconds
	smokeColor    = { 0.27, 0.25, 0.23 },
	smokeDensity  = 0.0050,
}

local MAX_VOLUMES = 8

-- per quality: march steps, resolution divisor, shadow lookups
local QUALITY = {
	[1] = { steps = 12, div = 3, shadows = false },
	[2] = { steps = 22, div = 2, shadows = true  },
	[3] = { steps = 40, div = 2, shadows = true  },
}
local quality = 2

local DEBUG = false -- echoes the fog state every 120 draw frames

--------------------------------------------------------------------------------
-- Speedups
--------------------------------------------------------------------------------

local glCreateTexture      = gl.CreateTexture
local glDeleteTexture      = gl.DeleteTexture
local glCopyToTexture      = gl.CopyToTexture
local glRenderToTexture    = gl.RenderToTexture
local glTexture            = gl.Texture
local glBlending           = gl.Blending
local glDepthTest          = gl.DepthTest
local glDepthMask          = gl.DepthMask
local glCulling            = gl.Culling
local glGetAtmosphere      = gl.GetAtmosphere
local spEcho               = Spring.Echo
local spGetWind            = Spring.GetWind
local spGetTimer           = Spring.GetTimer
local spDiffTimers         = Spring.DiffTimers

local max, min, floor, sqrt = math.max, math.min, math.floor, math.sqrt

local GL_DEPTH_COMPONENT24 = 0x81A6
local GL_RGBA16F           = 0x881A
local GL_R32F              = 0x822E

local NOISE_TEX = "modelmaterials_gl4/noise64_cube_3.dds" -- the 3D noise cube CUS GL4 also uses

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local LuaShader, InstanceVBOTable
local marchShader, compositeShader
local quadVAO
local depthTexture, fogTexture
local vsx, vsy, vpx, vpy = 1, 1, 0, 0
local fsx, fsy = 1, 1

local fogBottom, fogTop = 0, 500 -- lowest and highest fog base on the map
local baseTexture                 -- the blurred terrain, one texel per ~1/256 of the map
local baseTextureAge = 1e9
local blurShader
local BASE_TEX_SIZE = 256
local BASE_REFRESH = 20           -- seconds between re-blurs (terrain deforms)
local timer0 = spGetTimer()
local windOffX, windOffZ = 0, 0
local lastNow = 0

-- local volumes: id -> {x, y, z, radius, height, r, g, b, density, emission, noise, born, life, fadeIn, fadeOut}
local volumes = {}
local volumeCount = 0
local nextVolumeID = 1

--------------------------------------------------------------------------------
-- Shaders
--------------------------------------------------------------------------------

local quadVS = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack : require
layout (location = 0) in vec4 pos; // xy = clip position, zw = uv
out vec2 uv;
void main() {
	uv = pos.zw;
	gl_Position = vec4(pos.xy, 0.0, 1.0);
}
]]

local marchFS = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack : require
#line 20000
//__ENGINEUNIFORMBUFFERDEFS__

#define MAX_VOLUMES 8
#define DEPTH_CLIP01 __DEPTH_CLIP01__

uniform sampler2D depthTex;
uniform sampler2DShadow shadowTex;
uniform sampler3D noiseTex;
uniform sampler2D baseTex; // blurred terrain height: where the fog layer sits

uniform vec4 fogColorDensity; // rgb = fog tint, a = extinction per elmo at the base
uniform vec4 fogShape;        // x = base bias (scale heights), y = scale height, z = march bottom, w = march top
uniform vec4 noiseParams;     // x = 1/scale1, y = 1/scale2, z = amount, w = height push (scale heights)
uniform vec4 lightParams;     // x = sun scatter, y = ambient scatter, z = anisotropy, w = 1 if shadows
uniform vec4 marchParams;     // x = steps, y = max distance, z = wind offset x, w = wind offset z

uniform float edgeFade;       // elmos past the map edge over which the layer fades out
uniform int numVolumes;
uniform vec4 volPos[MAX_VOLUMES]; // xyz = centre, w = radius
uniform vec4 volCol[MAX_VOLUMES]; // rgb = colour, a = extinction per elmo at the centre
uniform vec4 volExt[MAX_VOLUMES]; // x = radius / height (y squash), y = emission, z = noise amount

in vec2 uv;
out vec4 fragColor;

// Interleaved gradient noise (Jimenez): a cheap dither that blurs away cleanly
float IGN(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

void main() {
	float depth = texture(depthTex, uv).x;
	// the engine uses a 0..1 clip-space depth where the driver allows it
	#if DEPTH_CLIP01
		vec4 wp4 = cameraViewProjInv * vec4(uv * 2.0 - 1.0, depth, 1.0);
	#else
		vec4 wp4 = cameraViewProjInv * vec4(vec3(uv, depth) * 2.0 - 1.0, 1.0);
	#endif
	vec3 worldPos = wp4.xyz / wp4.w;
	vec3 eye = cameraViewInv[3].xyz;
	vec3 toPoint = worldPos - eye;
	float len = length(toPoint);
	vec3 dir = toPoint / max(len, 0.001);
	len = min(len, marchParams.y);

	// the part of the ray between the march bottom and top
	float tmin = 0.0;
	float tmax = len;
	if (abs(dir.y) > 0.0001) {
		float ta = (fogShape.z - eye.y) / dir.y;
		float tb = (fogShape.w - eye.y) / dir.y;
		tmin = max(tmin, min(ta, tb));
		tmax = min(tmax, max(ta, tb));
	} else if (eye.y < fogShape.z || eye.y > fogShape.w) {
		tmax = -1.0;
	}
	if (tmax <= tmin) {
		fragColor = vec4(0.0, 0.0, 0.0, 1.0);
		return;
	}

	int steps = int(marchParams.x);
	float ds = (tmax - tmin) / float(steps);
	float t = tmin + ds * IGN(gl_FragCoord.xy + 5.588238 * mod(timeInfo.z, 64.0));

	// how much light fog scatters toward the eye from the sun's direction
	float g = lightParams.z;
	float cosT = dot(dir, normalize(sunDir.xyz));
	float hg = (1.0 - g * g) / pow(max(1.0 + g * g - 2.0 * g * cosT, 0.001), 1.5);
	float phase = min(mix(1.0, hg, 0.6), 3.5);

	vec3 sunLight = sunDiffuseMap.rgb * lightParams.x * phase;
	vec3 ambLight = (sunAmbientMap.rgb + 0.25 * sunDiffuseMap.rgb) * lightParams.y;
	vec3 windOff = vec3(marchParams.z, 0.0, marchParams.w);

	vec3 scatter = vec3(0.0);
	float trans = 1.0;

	for (int i = 0; i < steps; i++) {
		vec3 p = eye + dir * t;
		t += ds;

		// two octaves of drifting noise, the second drifting the other way a little faster
		vec3 np = p + windOff;
		float n1 = textureLod(noiseTex, np * noiseParams.x, 0.0).a;
		float n2 = textureLod(noiseTex, (p - windOff * 1.7).zyx * noiseParams.y, 0.0).a;
		float n = n1 * 0.65 + n2 * 0.35;

		// the layer: exponential in height, its top pushed up and down by the noise
		float base = textureLod(baseTex, p.xz / mapSize.xy, 0.0).r;
		float h = (p.y - base) / fogShape.y - fogShape.x - (n - 0.5) * noiseParams.w;
		float dGlobal = fogColorDensity.a * exp(-max(h, 0.0));
		dGlobal *= mix(1.0, 2.0 * smoothstep(0.28, 0.72, n), noiseParams.z);
		// no land past the map's edge: the layer thins out into a soft bank there
		vec2 outside = max(max(-p.xz, p.xz - mapSize.xy), vec2(0.0));
		dGlobal *= 1.0 - smoothstep(0.0, edgeFade, length(outside));

		float sigma = dGlobal;
		vec3 albedo = fogColorDensity.rgb * dGlobal;
		vec3 emission = vec3(0.0);

		for (int v = 0; v < numVolumes; v++) {
			vec3 q = p - volPos[v].xyz;
			q.y *= volExt[v].x;
			float d2 = dot(q, q) / (volPos[v].w * volPos[v].w);
			if (d2 < 1.0) {
				float f = 1.0 - d2;
				float dv = volCol[v].a * f * f * mix(1.0, 2.0 * n, volExt[v].z);
				sigma += dv;
				albedo += volCol[v].rgb * dv;
				emission += volCol[v].rgb * dv * volExt[v].y;
			}
		}

		if (sigma > 0.000001) {
			albedo /= sigma;
			float lit = 1.0;
			if (lightParams.w > 0.5) {
				vec3 sc = (shadowView * vec4(p, 1.0)).xyz;
				sc.xy += vec2(0.5);
				if (all(greaterThan(sc.xy, vec2(0.0))) && all(lessThan(sc.xy, vec2(1.0)))) {
					lit = texture(shadowTex, sc);
				}
			}
			float a = 1.0 - exp(-sigma * ds);
			scatter += trans * (a * albedo * (sunLight * lit + ambLight) + emission * ds);
			trans *= 1.0 - a;
			if (trans < 0.01) {
				trans = 0.0;
				break;
			}
		}
	}

	fragColor = vec4(scatter, trans);
}
]]

-- Blends the reduced-resolution fog over the scene. A 3x3 tent blur removes
-- the march's dither; taps whose scene depth is far from this pixel's are
-- weighted down so fog does not smear across the edges of units and cliffs.
local compositeFS = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack : require
#line 30000
uniform sampler2D fogTex;
uniform sampler2D depthTex;
uniform vec2 fogTexel; // 1 / fog texture size

in vec2 uv;
out vec4 fragColor;

float Lin(float d) { // monotonic stand-in for linear depth, enough for edge weights
	return 1.0 / max(1.0 - d, 0.00002);
}

void main() {
	float here = Lin(texture(depthTex, uv).x);
	vec4 sum = vec4(0.0);
	float wsum = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y)) * fogTexel;
			float there = Lin(texture(depthTex, uv + o).x);
			float w = (2.0 - abs(float(x))) * (2.0 - abs(float(y)));
			w *= 1.0 / (1.0 + 40.0 * abs(there - here) / here);
			sum += texture(fogTex, uv + o) * w;
			wsum += w;
		}
	}
	fragColor = sum / wsum; // rgb = light scattered toward the eye, a = what is left of the scene
}
]]

-- The terrain, blurred: each texel is the average height (sea counted as its
-- surface) of the ground around it. Drawn rarely, into a small texture.
local blurFS = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack : require
#line 40000
uniform sampler2D heightmapTex;
uniform vec2 blurUV; // blur radius as a fraction of the map, per axis

in vec2 uv;
out vec4 fragColor;

void main() {
	float sum = 0.0;
	float wsum = 0.0;
	for (int y = -4; y <= 4; y++) {
		for (int x = -4; x <= 4; x++) {
			vec2 o = vec2(float(x), float(y)) / 4.0;
			float w = exp(-2.5 * dot(o, o));
			float h = textureLod(heightmapTex, clamp(uv + o * blurUV, 0.002, 0.998), 0.0).x;
			sum += max(h, 0.0) * w;
			wsum += w;
		}
	}
	fragColor = vec4(sum / wsum, 0.0, 0.0, 1.0);
}
]]

--------------------------------------------------------------------------------
-- Resources
--------------------------------------------------------------------------------

local function DeleteTextures()
	if depthTexture then glDeleteTexture(depthTexture); depthTexture = nil end
	if fogTexture then glDeleteTexture(fogTexture); fogTexture = nil end
end

local function DrawQuad()
	quadVAO:DrawArrays(GL.TRIANGLES)
end

local function RefreshBaseTexture()
	blurShader:Activate()
	blurShader:SetUniform("blurUV", TUNE.blurRadius / Game.mapSizeX, TUNE.blurRadius / Game.mapSizeZ)
	glTexture(0, "$heightmap")
	glBlending(false)
	glRenderToTexture(baseTexture, DrawQuad)
	glTexture(0, false)
	blurShader:Deactivate()
	baseTextureAge = 0
end

local function CreateTextures()
	DeleteTextures()
	vsx, vsy, vpx, vpy = Spring.GetViewGeometry()
	local q = QUALITY[quality] or QUALITY[2]
	fsx, fsy = max(1, floor(vsx / q.div)), max(1, floor(vsy / q.div))

	depthTexture = glCreateTexture(vsx, vsy, {
		format     = GL_DEPTH_COMPONENT24,
		min_filter = GL.NEAREST,
		mag_filter = GL.NEAREST,
		wrap_s     = GL.CLAMP_TO_EDGE,
		wrap_t     = GL.CLAMP_TO_EDGE,
	})
	fogTexture = glCreateTexture(fsx, fsy, {
		format     = GL_RGBA16F,
		border     = false,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s     = GL.CLAMP_TO_EDGE,
		wrap_t     = GL.CLAMP_TO_EDGE,
		fbo        = true,
	})
	return depthTexture and fogTexture
end

local function Goodbye(reason)
	spEcho("[GFX Fog] " .. reason .. ", removing")
	widgetHandler:RemoveWidget(widget)
end

--------------------------------------------------------------------------------
-- Local volumes
--------------------------------------------------------------------------------

local function Now()
	return spDiffTimers(spGetTimer(), timer0)
end

-- def: { x, y, z, radius, height (default radius), color = {r, g, b}, density
-- (extinction per elmo at the centre, about 0.002 thin to 0.01 thick),
-- emission (0 = only lit, 1+ = glows), noise (0..1), life (seconds, nil =
-- until removed), fadeIn, fadeOut (seconds) }. Returns an id.
local function AddVolume(def)
	if type(def) ~= "table" or not (def.x and def.z and def.radius) then
		return nil
	end
	local id = nextVolumeID
	nextVolumeID = id + 1
	local color = def.color or {}
	volumes[id] = {
		x = def.x, y = def.y or Spring.GetGroundHeight(def.x, def.z) or 0, z = def.z,
		radius   = max(1, def.radius),
		height   = max(1, def.height or def.radius),
		r = color[1] or def.r or 0.6, g = color[2] or def.g or 0.6, b = color[3] or def.b or 0.6,
		density  = def.density or 0.004,
		emission = def.emission or 0,
		noise    = def.noise or 0.7,
		born     = Now(),
		life     = def.life,
		fadeIn   = def.fadeIn or 1.5,
		fadeOut  = def.fadeOut or 4,
	}
	volumeCount = volumeCount + 1
	return id
end

local function RemoveVolume(id)
	if volumes[id] then
		volumes[id] = nil
		volumeCount = volumeCount - 1
	end
end

local function SetVolume(id, def)
	local v = volumes[id]
	if not v or type(def) ~= "table" then return false end
	for k, value in pairs(def) do
		if k == "color" then
			v.r, v.g, v.b = value[1] or v.r, value[2] or v.g, value[3] or v.b
		elseif v[k] ~= nil or k == "life" then
			v[k] = value
		end
	end
	return true
end

-- The volumes to draw this frame, strongest fade first: {v, fade} pairs.
local active = {}
local function CollectVolumes(now, camX, camY, camZ)
	local n = 0
	for id, v in pairs(volumes) do
		local age = now - v.born
		local fade = min(1, age / max(0.01, v.fadeIn))
		if v.life then
			local left = v.life - age
			if left <= 0 then
				volumes[id] = nil
				volumeCount = volumeCount - 1
				fade = 0
			else
				fade = min(fade, left / max(0.01, v.fadeOut))
			end
		end
		if fade > 0 then
			n = n + 1
			local e = active[n]
			if not e then e = {}; active[n] = e end
			local dx, dy, dz = v.x - camX, v.y - camY, v.z - camZ
			e.v, e.fade, e.dist = v, fade, dx * dx + dy * dy + dz * dz
		end
	end
	for i = n + 1, #active do active[i] = nil end
	if n > MAX_VOLUMES then
		table.sort(active, function(a, b) return a.dist < b.dist end)
		for i = MAX_VOLUMES + 1, n do active[i] = nil end
		n = MAX_VOLUMES
	end
	return n
end

--------------------------------------------------------------------------------
-- Battle smoke
--------------------------------------------------------------------------------

local smokeRadius = {} -- unitDefID -> radius of the smoke its death leaves, or false
local function SmokeRadius(unitDefID)
	local r = smokeRadius[unitDefID]
	if r == nil then
		r = false
		local ud = UnitDefs[unitDefID]
		local wd = ud and ud.deathExplosion and WeaponDefNames[ud.deathExplosion]
		local aoe = wd and wd.damageAreaOfEffect or 0
		if aoe >= TUNE.smokeMinAoE then
			r = max(160, min(700, aoe * 1.7))
		end
		smokeRadius[unitDefID] = r
	end
	return r
end

function widget:UnitDestroyed(unitID, unitDefID)
	if not TUNE.battleSmoke or quality == 0 then return end
	local r = SmokeRadius(unitDefID)
	if not r then return end
	local _, _, _, _, buildProgress = Spring.GetUnitHealth(unitID)
	if buildProgress and buildProgress < 1 then return end
	local x, y, z = Spring.GetUnitPosition(unitID)
	if not x then return end
	if volumeCount >= MAX_VOLUMES * 2 then return end -- a big battle: enough smoke already
	AddVolume({
		x = x, y = y + r * 0.15, z = z, radius = r, height = r * 0.55,
		color = TUNE.smokeColor, density = TUNE.smokeDensity, noise = 0.9,
		life = TUNE.smokeLife, fadeIn = 0.6, fadeOut = TUNE.smokeLife * 0.6,
	})
end

--------------------------------------------------------------------------------
-- Callins
--------------------------------------------------------------------------------

function widget:ViewResize()
	if not CreateTextures() then
		Goodbye("could not create its textures")
	end
end

local function SetQuality(q)
	q = max(0, min(3, floor(tonumber(q) or 2)))
	if q ~= quality then
		quality = q
		if marchShader and q > 0 then CreateTextures() end
	end
end

function widget:Initialize()
	if not (gl.GetVAO and gl.GetVBO and glRenderToTexture) then
		Goodbye("GL4 buffers or render-to-texture unavailable")
		return
	end
	LuaShader = gl.LuaShader or VFS.Include("modules/graphics/LuaShader.lua")
	InstanceVBOTable = gl.InstanceVBOTable or VFS.Include("modules/graphics/instancevbotable.lua")
	local engineDefs = LuaShader.GetEngineUniformBufferDefs and LuaShader.GetEngineUniformBufferDefs()
	if not engineDefs then
		Goodbye("engine uniform buffer definitions missing")
		return
	end

	marchShader = LuaShader({
		vertex   = quadVS,
		fragment = marchFS:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineDefs)
			:gsub("__DEPTH_CLIP01__", (Platform and Platform.glSupportClipSpaceControl) and "1" or "0"),
		uniformInt = { depthTex = 0, shadowTex = 1, noiseTex = 2, baseTex = 3, numVolumes = 0 },
	}, "GFX Fog march")
	if not marchShader:Initialize() then
		Goodbye("march shader failed to compile")
		return
	end
	compositeShader = LuaShader({
		vertex   = quadVS,
		fragment = compositeFS,
		uniformInt = { fogTex = 0, depthTex = 1 },
	}, "GFX Fog composite")
	if not compositeShader:Initialize() then
		Goodbye("composite shader failed to compile")
		return
	end

	quadVAO = InstanceVBOTable.MakeTexRectVAO()
	if not quadVAO then
		Goodbye("could not create its quad")
		return
	end

	blurShader = LuaShader({
		vertex   = quadVS,
		fragment = blurFS,
		uniformInt = { heightmapTex = 0 },
	}, "GFX Fog base blur")
	if not blurShader:Initialize() then
		Goodbye("blur shader failed to compile")
		return
	end
	baseTexture = glCreateTexture(BASE_TEX_SIZE, BASE_TEX_SIZE, {
		format     = GL_R32F,
		border     = false,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s     = GL.CLAMP_TO_EDGE,
		wrap_t     = GL.CLAMP_TO_EDGE,
		fbo        = true,
	})
	if not baseTexture then
		Goodbye("could not create the fog base texture")
		return
	end

	-- the march runs between the lowest and the highest ground (sea as its surface)
	local minH, maxH = Spring.GetGroundExtremes()
	fogBottom, fogTop = max(minH or 0, 0), max(maxH or 0, 0)

	if not CreateTextures() then
		Goodbye("could not create its textures")
		return
	end

	WG.fog = {
		AddVolume    = AddVolume,
		RemoveVolume = RemoveVolume,
		SetVolume    = SetVolume,
		GetQuality   = function() return quality end,
		SetQuality   = SetQuality,
		GetAmount    = function() return TUNE.amountMult end,
		SetAmount    = function(v) TUNE.amountMult = max(0, min(3, tonumber(v) or 1)) end,
		GetBattleSmoke = function() return TUNE.battleSmoke end,
		SetBattleSmoke = function(v) TUNE.battleSmoke = v and true or false end,
		tune         = TUNE,
	}
	-- for gadgets: Script.LuaUI.FogVolumeAdd(def) -> id, Script.LuaUI.FogVolumeRemove(id)
	widgetHandler:RegisterGlobal("FogVolumeAdd", AddVolume)
	widgetHandler:RegisterGlobal("FogVolumeRemove", RemoveVolume)
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal("FogVolumeAdd")
	widgetHandler:DeregisterGlobal("FogVolumeRemove")
	WG.fog = nil
	DeleteTextures()
	if baseTexture then glDeleteTexture(baseTexture); baseTexture = nil end
	if blurShader then blurShader:Finalize(); blurShader = nil end
	if quadVAO then quadVAO:Delete(); quadVAO = nil end
	if marchShader then marchShader:Finalize(); marchShader = nil end
	if compositeShader then compositeShader:Finalize(); compositeShader = nil end
end

function widget:GetConfigData()
	return { quality = quality, amount = TUNE.amountMult, battleSmoke = TUNE.battleSmoke }
end

function widget:SetConfigData(data)
	if data.quality ~= nil then quality = max(0, min(3, floor(tonumber(data.quality) or 2))) end
	if data.amount ~= nil then TUNE.amountMult = max(0, min(3, tonumber(data.amount) or 1)) end
	if data.battleSmoke ~= nil then TUNE.battleSmoke = data.battleSmoke and true or false end
end

-- the march, into the reduced-resolution texture (run by gl.RenderToTexture)

function widget:DrawWorld()
	if quality == 0 or not (marchShader and depthTexture and fogTexture) then
		return
	end
	local q = QUALITY[quality]

	-- how much fog: standing mist (more at night) plus what Weather asks for
	local wg = WG.weather
	local fogStart, fr, fg, fb, night
	if wg and wg.fogStart then
		fogStart = wg.fogStart
		fr, fg, fb = wg.fogR, wg.fogG, wg.fogB
		night = wg.night or 0
	else
		fogStart = 1
		fr, fg, fb = glGetAtmosphere("fogColor")
		night = 0
	end
	local amount = TUNE.baseMist + TUNE.nightMist * max(0, min(1, night)) + (1 - fogStart)
	amount = max(0, min(1.5, amount * TUNE.amountMult))

	local now = Now()
	local camX, camY, camZ = Spring.GetCameraPosition()
	local nVolumes = CollectVolumes(now, camX, camY, camZ)
	if amount <= 0.01 and nVolumes == 0 then
		return
	end

	-- the fog drifts with the map wind (a breeze even on a still day)
	local dt = max(0, min(0.25, now - lastNow))
	lastNow = now
	local _, _, _, _, wx, _, wz = spGetWind()
	wx, wz = wx or 1, wz or 0
	local wl = sqrt(wx * wx + wz * wz)
	if wl < 0.01 then wx, wz, wl = 1, 0, 1 end
	windOffX = windOffX + wx / wl * TUNE.windSpeed * dt
	windOffZ = windOffZ + wz / wl * TUNE.windSpeed * dt

	-- the march covers the fog layer and every volume
	local bottom = fogBottom - 20
	local top = fogTop + TUNE.falloff * (TUNE.topScales + TUNE.noiseHeight * 0.5)
	if amount <= 0.01 then top = bottom end
	for i = 1, nVolumes do
		local v = active[i].v
		local lo, hi = v.y - v.height, v.y + v.height
		if amount <= 0.01 and i == 1 then bottom, top = lo, hi end
		if lo < bottom then bottom = lo end
		if hi > top then top = hi end
	end

	glCopyToTexture(depthTexture, 0, 0, vpx, vpy, vsx, vsy)

	glDepthTest(false)
	glDepthMask(false)
	glCulling(false)

	baseTextureAge = baseTextureAge + dt
	if baseTextureAge > BASE_REFRESH then
		RefreshBaseTexture()
	end

	-- 1: march into the reduced-resolution texture
	local shadows = q.shadows and Spring.HaveShadows()
	marchShader:Activate()
	local white, tint = TUNE.fogWhite, TUNE.mapTint
	fr = white + ((fr or 0.5) - white) * tint
	fg = white + ((fg or 0.5) - white) * tint
	fb = white + ((fb or 0.5) - white) * tint
	marchShader:SetUniform("fogColorDensity", fr, fg, fb, TUNE.densityFull * amount)
	marchShader:SetUniform("fogShape", TUNE.baseBias, TUNE.falloff, bottom, top)
	marchShader:SetUniform("noiseParams", 1 / TUNE.noiseScale1, 1 / TUNE.noiseScale2, TUNE.noiseAmount, TUNE.noiseHeight)
	marchShader:SetUniform("lightParams", TUNE.sunScatter, TUNE.ambScatter, TUNE.anisotropy, shadows and 1 or 0)
	marchShader:SetUniform("marchParams", q.steps, TUNE.maxDist, windOffX, windOffZ)
	marchShader:SetUniform("edgeFade", TUNE.edgeFade)
	marchShader:SetUniformInt("numVolumes", nVolumes)
	for i = 1, nVolumes do
		local e = active[i]
		local v = e.v
		local k = "[" .. (i - 1) .. "]"
		marchShader:SetUniform("volPos" .. k, v.x, v.y, v.z, v.radius)
		marchShader:SetUniform("volCol" .. k, v.r, v.g, v.b, v.density * e.fade)
		marchShader:SetUniform("volExt" .. k, v.radius / v.height, v.emission, v.noise, 0)
	end
	glTexture(0, depthTexture)
	if shadows then glTexture(1, "$shadow") end
	glTexture(2, NOISE_TEX)
	glTexture(3, baseTexture)
	glBlending(false)
	glRenderToTexture(fogTexture, DrawQuad)
	marchShader:Deactivate()
	glTexture(1, false)
	glTexture(2, false)
	glTexture(3, false)

	-- 2: blend it over the scene: scene x transmittance + scattered light
	compositeShader:Activate()
	compositeShader:SetUniform("fogTexel", 1 / fsx, 1 / fsy)
	glTexture(0, fogTexture)
	glTexture(1, depthTexture)
	glBlending(GL.ONE, GL.SRC_ALPHA)
	quadVAO:DrawArrays(GL.TRIANGLES)
	compositeShader:Deactivate()
	glTexture(0, false)
	glTexture(1, false)

	glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	glDepthMask(true)
	glDepthTest(true)

	if DEBUG and Spring.GetDrawFrame() % 120 == 0 then
		spEcho(string.format("[GFX Fog] amount %.2f  volumes %d  q %d  shadows %s", amount, nVolumes, quality, tostring(shadows)))
	end
end
