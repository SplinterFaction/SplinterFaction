function widget:GetInfo()
	return {
		name      = "GFX Rain",
		desc      = "GL4 rain streaks, ground splashes and war-driven falling ash, driven by the Weather widget",
		author    = "trepan, Argh, The_Yak, Doo (GL4 rewrite 2026)",
		date      = "2026-07-26",
		version   = "3.2",
		license   = "GNU GPL, v2 or later",
		layer     = -24,
		enabled   = true,
	}
end

--------------------------------------------------------------------------------
-- Tuning
--------------------------------------------------------------------------------

-- Force override for tuning: set 0..1 to lock rain at that density and ignore
-- the weather driver entirely (1 = max storm); -1 = off, follow the weather
local FORCE_RAIN       = -1
local DEBUG            = false  -- echo rain/war/drop counts once per second while tuning

-- Rain: how much
local MAX_RAIN_DROPS   = 24000  -- streak count at full density (geometry is allocated once for this many)
local RAIN_DENSITY_EXP = 0.7    -- <1 makes light/moderate weather look rainier; 1 = linear
-- Rain: how it moves
local RAIN_SPEED       = 1100   -- fall speed, elmos/second
local WIND             = { -140, -70 }        -- x/z drift per second; also slants the streaks
local RAIN_VOLUME      = { 3500, 2800, 3500 } -- wrap volume around the camera; smaller = denser look
-- Rain: how it looks
local STREAK_LEN       = { 25, 50 }           -- min/max streak length (elmos)
local LINE_WIDTH       = 1.5    -- streak thickness in pixels
local RAIN_BASE_RGB    = { 0.50, 0.60, 0.80 }
local RAIN_ALPHA       = 0.65   -- streak alpha at full density
local DENSITY_DIMMING  = 0.35   -- 0..1: per-drop brightness reduction at full density (0 = none; higher = storms darker per streak)

-- Rain: ground impacts (land splashes, rings on water). These are not tied to
-- individual streaks; they are an independent layer that tracks rain density
local MAX_SPLASHES     = 6000   -- impacts alive at full density
local SPLASH_AREA      = 3200   -- diameter (elmos) of the impact field around the camera's ground focus; smaller = denser
local SPLASH_LIFE      = 0.6    -- seconds per impact cycle (water rings use all of it, land splashes the first 60%)
local SPLASH_SIZE      = { 12, 30 }  -- world diameter in elmos: land splash, water ring
local SPLASH_RGBA      = { 0.80, 0.88, 1.00, 0.20 }
local SPLASH_ADDITIVE  = false  -- false = alpha blend (reads on bright terrain), true = additive like the streaks
local SPLASH_FADE      = { 3000, 5000 }  -- camera-to-ground distance where impacts start fading / are skipped entirely
local SPLASH_LIFT      = 6      -- elmos each impact is pulled toward the camera so terrain does not z-fight it

-- War-driven ash
local MAX_ASH_MOTES    = 6000
local ASH_VOLUME       = { 3500, 2500, 3500 }
local ASH_FALL         = { -15, 90, -15 }
local ASH_RGBA         = { 0.85, 0.80, 0.75, 0.5 }

local MIN_VISIBLE      = 0.01   -- skip a layer below this density fraction
local RAIN_FALL        = { WIND[1], RAIN_SPEED, WIND[2] }

--------------------------------------------------------------------------------
-- Speedups
--------------------------------------------------------------------------------

local glCreateShader       = gl.CreateShader
local glDeleteShader       = gl.DeleteShader
local glGetShaderLog       = gl.GetShaderLog
local glGetUniformLocation = gl.GetUniformLocation
local glUseShader          = gl.UseShader
local glUniform            = gl.Uniform
local glUniformInt         = gl.UniformInt
local glTexture            = gl.Texture
local glBlending           = gl.Blending
local glDepthTest          = gl.DepthTest
local glDepthMask          = gl.DepthMask
local glPointSprite        = gl.PointSprite
local glPointSize          = gl.PointSize
local glLineWidth          = gl.LineWidth
local glGetAtmosphere      = gl.GetAtmosphere
local spGetCameraPosition  = Spring.GetCameraPosition
local spGetCameraDirection = Spring.GetCameraDirection
local spTraceScreenRay     = Spring.TraceScreenRay
local spGetTimer           = Spring.GetTimer
local spDiffTimers         = Spring.DiffTimers
local spEcho               = Spring.Echo
local mathFloor            = math.floor
local mathSqrt             = math.sqrt
local mathAbs              = math.abs
local mathMax              = math.max
local mathMin              = math.min

local GL_LINES     = GL.LINES
local GL_POINTS    = GL.POINTS
local GL_LEQUAL    = GL.LEQUAL
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE       = GL.ONE
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local rainShader, ashShader, splashShader
local rainVAO, rainVBO
local splashVAO, splashVBO
local splashU = {}
local vsx, vsy = 1920, 1080
local voidWater -- resolved on first draw (nil = unknown yet)
local ashVAO, ashVBO
local rainU = {} -- uniform locations
local ashU  = {}
local startTimer
local debugLast = 0

--------------------------------------------------------------------------------
-- Geometry (built ONCE; the original rebuilt three 15k-line display lists
-- every 150 draw frames and leaked the old ones. All per-drop data is now
-- generated GPU-side from gl_VertexID, so no CPU particle data exists at all)
--------------------------------------------------------------------------------

-- The VBO carries no data anymore (drop positions are hashed from gl_VertexID
-- on the GPU); it exists only so the VAO has a vertex count to draw from.
local function MakeVAO(count, vertsPerParticle)
	local vbo = gl.GetVBO(GL.ARRAY_BUFFER, false)
	if not vbo then
		return nil, nil
	end
	vbo:Define(count * vertsPerParticle, {
		{ id = 0, name = "unused", size = 1 },
	})
	local vao = gl.GetVAO()
	vao:AttachVertexBuffer(vbo)
	return vao, vbo
end

--------------------------------------------------------------------------------
-- Shaders: all animation, wrapping, and density culling happen on the GPU
--------------------------------------------------------------------------------

local rainVertSrc = [[
#version 420 compatibility

// NOTE: no vertex attributes. All per-drop data is generated on the GPU from
// gl_VertexID, so there is no attribute stream that can silently fail to bind
// in a compatibility-profile context.

uniform float time;
uniform vec3  camPos;
uniform float density;   // 0..1 fraction of drops active
uniform float maxCount;
uniform vec3  volume;    // wrap volume around the camera
uniform vec3  fall;      // x/z: drift per second, y: fall speed per second
uniform vec2  streak;    // min length, random variation (elmos)
uniform vec4  color;

out vec4 vColor;

// Dave Hoskins hash: four decorrelated 0..1 values from one drop index
vec4 hash41(float p)
{
	vec4 p4 = fract(vec4(p) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
	p4 += dot(p4, p4.wzxy + 33.33);
	return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

void main()
{
	int  dropID = gl_VertexID / 2;
	bool isTail = (gl_VertexID & 1) == 1;

	// density culling: drops beyond the active fraction collapse off-screen
	if (float(dropID) >= density * maxCount) {
		vColor = vec4(0.0);
		gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
		return;
	}

	vec4 rndv  = hash41(float(dropID) + 0.5);
	float rnd  = rndv.w;
	float speed = fall.y * (0.75 + 0.5 * rnd);

	vec3 pos = rndv.xyz * volume;
	pos.y -= time * speed;
	pos.x += time * fall.x;
	pos.z += time * fall.z;
	pos = mod(pos - camPos, volume) - 0.5 * volume + camPos;

	if (isTail) {
		// tail trails the head along the actual fall direction, so wind
		// visibly slants the streaks
		float len = streak.x + streak.y * rnd;
		vec3 vel = vec3(fall.x, -speed, fall.z);
		pos -= vel * (len / speed);
	}

	vColor = color;
	vColor.a *= isTail ? 0.15 : (0.6 + 0.4 * rnd);

	gl_Position = gl_ModelViewProjectionMatrix * vec4(pos, 1.0);
}
]]

local rainFragSrc = [[
#version 420 compatibility
in vec4 vColor;
void main()
{
	gl_FragColor = vColor;
}
]]

local ashVertSrc = [[
#version 420 compatibility

uniform float time;
uniform vec3  camPos;
uniform float density;
uniform float maxCount;
uniform vec3  volume;
uniform vec3  fall;
uniform vec4  color;

out vec4 vColor;

vec4 hash41(float p)
{
	vec4 p4 = fract(vec4(p) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
	p4 += dot(p4, p4.wzxy + 33.33);
	return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

void main()
{
	if (float(gl_VertexID) >= density * maxCount) {
		vColor = vec4(0.0);
		gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
		return;
	}

	vec4 rndv = hash41(float(gl_VertexID) + 0.7);
	float rnd = rndv.w;

	vec3 pos = rndv.xyz * volume;
	pos.y -= time * fall.y * (0.5 + rnd);
	pos.x += sin(time * (0.5 + rnd)) * 15.0 + time * fall.x;
	pos.z += cos(time * (0.7 + rnd)) * 15.0 + time * fall.z;
	pos = mod(pos - camPos, volume) - 0.5 * volume + camPos;

	vec4 eyePos = gl_ModelViewMatrix * vec4(pos, 1.0);
	gl_PointSize = clamp((2.0 + 3.0 * rnd) * 2000.0 / length(eyePos.xyz), 1.0, 12.0);

	vColor = color;
	vColor.a *= 0.4 + 0.6 * rnd;

	gl_Position = gl_ProjectionMatrix * eyePos;
}
]]

-- Procedural soft dot via gl_PointCoord: no more snowflake .tga dependency
local ashFragSrc = [[
#version 420 compatibility
in vec4 vColor;
void main()
{
	vec2  d  = gl_PointCoord - vec2(0.5);
	float r2 = dot(d, d);
	float a  = smoothstep(0.25, 0.05, r2);
	gl_FragColor = vec4(vColor.rgb, vColor.a * a);
}
]]

-- Ground impacts. Each point picks a fresh hashed XZ spot every life cycle,
-- reads the terrain height from $heightmap, and plays a short expand + fade.
-- Below sea level it sits on the water plane and draws a ring instead.
local splashVertSrc = [[
#version 420 compatibility

uniform sampler2D heightTex;
uniform float time;
uniform vec3  camPos;
uniform vec2  center;     // world xz the field wraps around (camera ground focus)
uniform float density;
uniform float maxCount;
uniform float area;       // field diameter
uniform vec2  mapSize;
uniform float life;       // seconds per impact cycle
uniform vec2  size;       // world diameter: land, water
uniform float viewHeight; // viewport height in pixels
uniform float lift;
uniform float waterRings; // 1 = rings on water, 0 = nothing below sea level (voidwater)
uniform vec4  color;

out vec4  vColor;
out float vPhase;
out float vWater;

// Integer hash (PCG). The float hash used for rain degrades once its input
// grows, and the cycle counter here grows for the whole match
uint pcg(uint v)
{
	uint state = v * 747796405u + 2891336453u;
	uint word  = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}

float unit(uint h)
{
	return float(h >> 8u) * (1.0 / 16777216.0);
}

void cull()
{
	vColor = vec4(0.0);
	vPhase = 0.0;
	vWater = 0.0;
	gl_PointSize = 1.0;
	gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
}

void main()
{
	if (float(gl_VertexID) >= density * maxCount) {
		cull();
		return;
	}

	// stable per-point randoms: cycle rate variation and phase offset
	uint  id   = uint(gl_VertexID);
	uint  h0   = pcg(id);
	float rnd  = unit(h0);
	float offs = unit(pcg(h0));

	float cyc   = time / life * (0.8 + 0.4 * rnd) + offs;
	float phase = fract(cyc);

	// new position every cycle
	uint  h  = pcg(id ^ pcg(uint(cyc) + 0x9E3779B9u));
	float rx = unit(h);
	h = pcg(h);
	float rz = unit(h);

	vec2 xz = vec2(rx, rz) * area;
	xz = mod(xz - center, area) - 0.5 * area + center;

	if (any(lessThan(xz, vec2(0.0))) || any(greaterThan(xz, mapSize))) {
		cull();
		return;
	}

	// heightmap texel i sits at world coordinate 8 * i
	vec2  uv     = (xz / 8.0 + 0.5) / vec2(textureSize(heightTex, 0));
	float ground = textureLod(heightTex, uv, 0.0).r;
	bool  water  = ground < 0.0;

	// land splashes are quicker than water rings
	float p = water ? phase : phase / 0.6;
	if (p >= 1.0 || (water && waterRings < 0.5)) {
		cull();
		return;
	}

	vec3  pos   = vec3(xz.x, max(ground, 0.0), xz.y);
	vec3  toCam = camPos - pos;
	float dist  = max(length(toCam), 1.0);
	pos += toCam / dist * lift;

	// true world-space size in pixels
	float world = (water ? size.y : size.x) * (0.7 + 0.6 * rnd);
	float px    = world * gl_ProjectionMatrix[1][1] * viewHeight * 0.5 / dist;
	gl_PointSize = clamp(px, 1.0, 64.0);

	float fade = 1.0 - p;
	// circular field with a soft rim, so the wrap boundary is never a visible line
	float rim  = 1.0 - smoothstep(0.8, 1.0, length(xz - center) / (0.5 * area));

	vColor = color;
	vColor.a *= fade * (water ? 1.0 : fade) * rim * smoothstep(0.75, 2.5, px);
	vPhase = p;
	vWater = water ? 1.0 : 0.0;

	gl_Position = gl_ModelViewProjectionMatrix * vec4(pos, 1.0);
}
]]

-- Point sprites face the screen, so the shape is squashed vertically by the
-- camera pitch to make it read as lying flat on the ground
local splashFragSrc = [[
#version 420 compatibility

uniform float squash; // |camera forward y|: 1 looking straight down, smaller at grazing angles

in vec4  vColor;
in float vPhase;
in float vWater;

void main()
{
	vec2 d = gl_PointCoord - vec2(0.5);
	d.y /= squash;
	float r = length(d) * 2.0; // 0 at center, 1 at sprite edge

	float a;
	if (vWater > 0.5) {
		// thin ring expanding outward
		float radius = mix(0.15, 0.88, vPhase);
		float width  = mix(0.16, 0.08, vPhase);
		a = 1.0 - smoothstep(0.0, width, abs(r - radius));
	} else {
		// soft burst expanding outward, with a brighter core early on
		float radius = mix(0.35, 1.0, vPhase);
		a = 1.0 - smoothstep(radius * 0.3, radius, r);
		a += (1.0 - vPhase) * (1.0 - smoothstep(0.0, 0.25, r));
		a = min(a, 1.0);
	}

	gl_FragColor = vec4(vColor.rgb, vColor.a * a);
}
]]

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function CompileShader(name, vert, frag)
	local shader = glCreateShader({ vertex = vert, fragment = frag })
	if not shader then
		spEcho("[GFX Rain] " .. name .. " shader compilation failed")
		spEcho(glGetShaderLog())
		return nil
	end
	return shader
end

local function CacheUniforms(shader, t)
	t.time     = glGetUniformLocation(shader, "time")
	t.camPos   = glGetUniformLocation(shader, "camPos")
	t.density  = glGetUniformLocation(shader, "density")
	t.maxCount = glGetUniformLocation(shader, "maxCount")
	t.volume   = glGetUniformLocation(shader, "volume")
	t.fall     = glGetUniformLocation(shader, "fall")
	t.streak   = glGetUniformLocation(shader, "streak")
	t.color    = glGetUniformLocation(shader, "color")
end

local function CacheSplashUniforms(shader, t)
	local names = {
		"heightTex", "time", "camPos", "center", "density", "maxCount", "area", "mapSize",
		"life", "size", "viewHeight", "lift", "waterRings", "color", "squash",
	}
	for i = 1, #names do
		t[names[i]] = glGetUniformLocation(shader, names[i])
	end
end

-- Where the camera is looking on the ground: the impact field wraps around
-- this point, since an RTS camera sits far above the terrain it is viewing
local function GetGroundFocus(cx, cy, cz, dx, dy, dz)
	local _, hit = spTraceScreenRay(vsx * 0.5, vsy * 0.5, true, false, false, false)
	if hit then
		return hit[1], hit[2], hit[3]
	end
	if dy < -0.01 and cy > 0 then
		local k = cy / -dy -- screen center misses the map: intersect the y = 0 plane instead
		return cx + dx * k, 0, cz + dz * k
	end
	return nil
end

local function SetCommonUniforms(u, t, cx, cy, cz, density, maxCount, volume, fall)
	glUniform(u.time, t)
	glUniform(u.camPos, cx, cy, cz)
	glUniform(u.density, density)
	glUniform(u.maxCount, maxCount)
	glUniform(u.volume, volume[1], volume[2], volume[3])
	glUniform(u.fall, fall[1], fall[2], fall[3])
end

-- Kept out of DrawWorld: Lua 5.1 caps a function at 60 upvalues
local function DrawSplashes(t, cx, cy, cz, visDensity, splashCount)
	local dx, dy, dz = spGetCameraDirection()
	local fx, fy, fz = GetGroundFocus(cx, cy, cz, dx, dy, dz)
	if fx then
		local ox, oy, oz = fx - cx, fy - cy, fz - cz
		local camDist = mathSqrt(ox * ox + oy * oy + oz * oz)
		-- zoom fade: impacts are sub-pixel shimmer from far away, so skip the pass
		local fade = (SPLASH_FADE[2] - camDist) / (SPLASH_FADE[2] - SPLASH_FADE[1])
		fade = mathMax(0, mathMin(1, fade))

		if fade > 0 and glTexture(0, "$heightmap") then
			if voidWater == nil then
				-- voidWater is a gl.GetMapRendering key (engine: LuaOpenGL::GetMapRendering).
				-- pcall so an unknown key on some other engine build cannot take the widget down
				local ok, isVoid = pcall(gl.GetMapRendering, "voidWater")
				voidWater = (ok and isVoid) and true or false
			end

			if SPLASH_ADDITIVE then
				glBlending(GL_SRC_ALPHA, GL_ONE)
			else
				glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
			end
			glPointSprite(true, true)

			local u = splashU
			glUseShader(splashShader)
			glUniformInt(u.heightTex, 0)
			glUniform(u.time, t)
			glUniform(u.camPos, cx, cy, cz)
			glUniform(u.center, fx, fz)
			glUniform(u.density, visDensity)
			glUniform(u.maxCount, MAX_SPLASHES)
			glUniform(u.area, SPLASH_AREA)
			glUniform(u.mapSize, Game.mapSizeX, Game.mapSizeZ)
			glUniform(u.life, SPLASH_LIFE)
			glUniform(u.size, SPLASH_SIZE[1], SPLASH_SIZE[2])
			glUniform(u.viewHeight, vsy)
			glUniform(u.lift, SPLASH_LIFT)
			glUniform(u.waterRings, voidWater and 0 or 1)
			glUniform(u.squash, mathMax(0.2, mathAbs(dy)))
			glUniform(u.color, SPLASH_RGBA[1], SPLASH_RGBA[2], SPLASH_RGBA[3], SPLASH_RGBA[4] * fade)
			splashVAO:DrawArrays(GL_POINTS, splashCount)

			glPointSprite(false, false)
			glTexture(0, false)
		end
	end
end

--------------------------------------------------------------------------------
-- Callins
--------------------------------------------------------------------------------

function widget:Initialize()
	if not glCreateShader then
		spEcho("[GFX Rain] no shader support, removing")
		widgetHandler:RemoveWidget()
		return
	end
	if not (gl.GetVBO and gl.GetVAO) then
		spEcho("[GFX Rain] no GL4 VBO/VAO support, removing")
		widgetHandler:RemoveWidget()
		return
	end

	rainShader = CompileShader("rain", rainVertSrc, rainFragSrc)
	ashShader  = CompileShader("ash", ashVertSrc, ashFragSrc)
	if not (rainShader and ashShader) then
		spEcho("[GFX Rain] removing")
		widgetHandler:RemoveWidget()
		return
	end
	CacheUniforms(rainShader, rainU)
	CacheUniforms(ashShader, ashU)

	-- Ground impacts are optional: if anything fails, rain and ash still run
	splashShader = CompileShader("splash", splashVertSrc, splashFragSrc)
	if splashShader then
		CacheSplashUniforms(splashShader, splashU)
		splashVAO, splashVBO = MakeVAO(MAX_SPLASHES, 1) -- 1 vert per impact (point)
		if not splashVAO then
			glDeleteShader(splashShader)
			splashShader = nil
		end
	end
	if not splashShader then
		spEcho("[GFX Rain] ground splashes disabled")
	end
	vsx, vsy = Spring.GetViewGeometry()

	rainVAO, rainVBO = MakeVAO(MAX_RAIN_DROPS, 2) -- 2 verts per drop (line)
	ashVAO,  ashVBO  = MakeVAO(MAX_ASH_MOTES, 1)  -- 1 vert per mote (point)
	if not (rainVAO and ashVAO) then
		spEcho("[GFX Rain] VBO creation failed, removing")
		widgetHandler:RemoveWidget()
		return
	end

	startTimer = spGetTimer()
end

function widget:ViewResize(newX, newY)
	vsx, vsy = newX, newY
end

function widget:Shutdown()
	if splashVAO then splashVAO:Delete() end
	if splashVBO then splashVBO:Delete() end
	if rainVAO then rainVAO:Delete() end
	if rainVBO then rainVBO:Delete() end
	if ashVAO then ashVAO:Delete() end
	if ashVBO then ashVBO:Delete() end
	if glDeleteShader then
		if rainShader then glDeleteShader(rainShader) end
		if ashShader then glDeleteShader(ashShader) end
		if splashShader then glDeleteShader(splashShader) end
	end
end

function widget:DrawWorld()
	if not startTimer then
		return
	end

	-- Intensities from the Weather widget; fall back to reading fogStart back
	-- from the atmosphere (the original's coupling) if it isn't running
	local wg = WG.weather
	local rainAmount, warAmount
	if wg and wg.rain then
		rainAmount = wg.rain
		warAmount  = wg.war or 0
	else
		rainAmount = 1 - (glGetAtmosphere("fogStart") or 1)
		warAmount  = 0
	end
	if FORCE_RAIN >= 0 then
		rainAmount = FORCE_RAIN
	end
	if rainAmount < MIN_VISIBLE and warAmount < MIN_VISIBLE then
		return
	end

	local t = spDiffTimers(spGetTimer(), startTimer)
	local cx, cy, cz = spGetCameraPosition()

	local visDensity = rainAmount ^ RAIN_DENSITY_EXP
	local dropCount = mathFloor(visDensity * MAX_RAIN_DROPS)
	local moteCount = mathFloor(warAmount * MAX_ASH_MOTES)
	local splashCount = splashShader and mathFloor(visDensity * MAX_SPLASHES) or 0

	if DEBUG then
		local now = os.clock()
		if now - debugLast > 1 then
			debugLast = now
			spEcho(string.format(
					"[GFX Rain] src=%s  rain=%.3f  war=%.3f  visDensity=%.3f  drops=%d  splashes=%d  motes=%d  t=%.1f",
					(wg and wg.rain) and "WG.weather" or "atmo-fallback",
					rainAmount, warAmount, visDensity, dropCount, splashCount, moteCount, t))
		end
	end

	glDepthTest(GL_LEQUAL) -- terrain still occludes particles behind hills
	glDepthMask(false)

	-- Ground impacts (drawn first so the streaks layer over them) -------------
	if splashCount > 0 then
		DrawSplashes(t, cx, cy, cz, visDensity, splashCount)
	end

	glBlending(GL_SRC_ALPHA, GL_ONE)

	-- Rain streaks --------------------------------------------------------
	if dropCount > 0 then
		local intensity = 1 - DENSITY_DIMMING * visDensity
		local alpha = RAIN_ALPHA * visDensity ^ 0.25

		glLineWidth(LINE_WIDTH)
		glUseShader(rainShader)
		SetCommonUniforms(rainU, t, cx, cy, cz, visDensity, MAX_RAIN_DROPS, RAIN_VOLUME, RAIN_FALL)
		glUniform(rainU.streak, STREAK_LEN[1], STREAK_LEN[2] - STREAK_LEN[1])
		glUniform(rainU.color,
		          RAIN_BASE_RGB[1] * intensity,
		          RAIN_BASE_RGB[2] * intensity,
		          RAIN_BASE_RGB[3] * intensity,
		          alpha)
		rainVAO:DrawArrays(GL_LINES, dropCount * 2)
		glLineWidth(1.0)
	end

	-- War-driven falling ash (replaces the textured snowflake point sprites) --
	if moteCount > 0 then
		glPointSprite(true, true)
		glPointSize(4.0)

		glUseShader(ashShader)
		SetCommonUniforms(ashU, t, cx, cy, cz, warAmount, MAX_ASH_MOTES, ASH_VOLUME, ASH_FALL)
		glUniform(ashU.color, ASH_RGBA[1], ASH_RGBA[2], ASH_RGBA[3], ASH_RGBA[4])
		ashVAO:DrawArrays(GL_POINTS, moteCount)

		glPointSprite(false, false)
		glPointSize(1.0)
	end

	glUseShader(0)
	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	glDepthMask(true)
	glDepthTest(true)
end