function widget:GetInfo()
	return {
		name      = "GFX Heat Shimmer",
		desc      = "Heat-haze distortion: grazing-angle shimmer and top-down convection ripple, driven by the Weather widget",
		author    = "Doo (2026)",
		date      = "2026-09-26",
		version   = "1.1",
		license   = "GNU GPL, v2 or later",
		layer     = 1000, -- late in DrawWorld so the depth copy sees everything, incl. GFX Fog
		enabled   = true,
	}
end

--------------------------------------------------------------------------------
-- Tuning
--------------------------------------------------------------------------------

-- Force override for tuning: set 0..1 to lock heat at that level and ignore
-- the weather driver; -1 = off, follow the weather
local FORCE_HEAT       = -1
local DEBUG            = false  -- echo heat level once per second while tuning

local MIN_VISIBLE      = 0.02   -- skip the pass entirely below this heat level
local AMPLITUDE_PX     = 3.0    -- max UV wobble at 1080p-ish, in pixels (scaled by screen height)
local DIST_NEAR        = 700    -- elmos; no shimmer closer than this to the camera...
local DIST_FAR         = 2800   -- ...full shimmer beyond this
local SHIMMER_HEIGHT   = 500    -- elmos above the terrain over which the shimmer fades out
local SPEED            = 1.0    -- animation speed multiplier

-- Top-down view. Real haze is a grazing-angle effect, so from the usual ~70deg
-- RTS pitch the distance ramp above never engages. When the camera pitches
-- down we instead cover the whole ground with a slow world-space "convection
-- cell" ripple and a faint wavering of the light, which is what hot ground
-- looks like from above.
local TOPDOWN_PITCH    = { 0.35, 0.80 } -- -camDir.y range over which we blend to top-down mode (0.8 ~= 53deg)
local TOPDOWN_AMP_MULT = 2.5    -- wobble amplitude multiplier in top-down mode (px ~= AMPLITUDE_PX * this)
local CELL_SIZE        = 220    -- elmos; size of the convection ripple cells on the ground
local CELL_DRIFT       = 40     -- elmos/s; how fast the cells crawl across the map
local RIPPLE_LIGHT     = 0.06   -- 0..1; brightness wavering at full heat (0 = none)
local SKY_DEPTH        = 0.99999 -- fragments at/after this depth are sky and are left alone

--------------------------------------------------------------------------------
-- Speedups
--------------------------------------------------------------------------------

local glCreateShader       = gl.CreateShader
local glDeleteShader       = gl.DeleteShader
local glGetShaderLog       = gl.GetShaderLog
local glGetUniformLocation = gl.GetUniformLocation
local glUseShader          = gl.UseShader
local glUniform            = gl.Uniform
local glUniformMatrix      = gl.UniformMatrix
local glCreateTexture      = gl.CreateTexture
local glDeleteTexture      = gl.DeleteTexture
local glCopyToTexture      = gl.CopyToTexture
local glTexture            = gl.Texture
local glTexRect            = gl.TexRect
local glBlending           = gl.Blending
local glDepthTest          = gl.DepthTest
local glDepthMask          = gl.DepthMask
local spGetCameraPosition  = Spring.GetCameraPosition
local spGetCameraDirection = Spring.GetCameraDirection
local spGetTimer           = Spring.GetTimer
local spDiffTimers         = Spring.DiffTimers
local spEcho               = Spring.Echo

local GL_NEAREST           = GL.NEAREST
local GL_LINEAR            = GL.LINEAR
local GL_CLAMP_TO_EDGE     = GL.CLAMP_TO_EDGE
local GL_DEPTH_COMPONENT24 = 0x81A6

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local vsx, vsy = 1, 1
local shader
local screenTex, depthTex
local startTimer
local debugLast = 0
local depthValid = false -- set when DrawWorld copied depth this frame

local uScreenTex, uDepthTex, uHeightTex
local uEyePos, uTime, uHeat, uAmp, uDistRange, uShimmerHeight
local uMapSize, uViewPrjInv
local uTopDown, uCell, uRippleLight

--------------------------------------------------------------------------------
-- Shaders
--------------------------------------------------------------------------------

local vertSrc = [[
	void main(void)
	{
		gl_TexCoord[0] = gl_MultiTexCoord0;
		gl_Position    = gl_Vertex;
	}
]]

local fragSrc = [[
	uniform sampler2D screenTex;
	uniform sampler2D depthTex;
	uniform sampler2D heightTex;   // $heightmap, R = terrain height in elmos
	uniform vec3  eyePos;
	uniform float time;
	uniform float heat;
	uniform vec2  amp;             // wobble amplitude in UV units (x, y)
	uniform vec2  distRange;       // near, far (elmos)
	uniform float shimmerHeight;   // fade-out height above terrain (elmos)
	uniform vec2  mapSize;         // map size in elmos, for heightmap lookup
	uniform mat4  viewProjectionInv;
	uniform float topDown;         // 0 = grazing view, 1 = fully top-down
	uniform vec3  cell;            // x: 1/cellSize, y: drift (elmos/s), z: amplitude multiplier
	uniform float rippleLight;

	void main(void)
	{
		vec2 uv = gl_TexCoord[0].st;
		float z = texture2D(depthTex, uv).x;

		// sky: pass through untouched
		if (z >= ]] .. string.format("%.6f", SKY_DEPTH) .. [[) {
			gl_FragColor = texture2D(screenTex, uv);
			return;
		}

		// reconstruct world position from depth (same trick as GFX Fog)
		vec4 ppos      = vec4(vec3(uv, z) * 2.0 - 1.0, 1.0);
		vec4 worldPos4 = viewProjectionInv * ppos;
		vec3 worldPos  = worldPos4.xyz / worldPos4.w;

		// distance weight: nothing close to the camera, full far away when
		// looking along the ground; looking down, the whole ground counts
		float dist = length(worldPos - eyePos);
		float dw   = mix(smoothstep(distRange.x, distRange.y, dist), 1.0, topDown);

		// ground-proximity weight: rising air is strongest at the surface and
		// fades out a few hundred elmos up (so tall units/cliffs shimmer at
		// their base, not their tops)
		float ground = texture2D(heightTex, worldPos.xz / mapSize).x;
		float above  = max(worldPos.y - ground, 0.0);
		float hw     = 1.0 - smoothstep(0.0, shimmerHeight, above);

		float w = heat * dw * hw;
		if (w <= 0.001) {
			gl_FragColor = texture2D(screenTex, uv);
			return;
		}

		float t = time;

		// Grazing view: screen-space sines, a fine fast ripple plus a broader
		// slow roll, mostly vertical like real convection
		vec2 offScreen;
		offScreen.y = sin(uv.x * 140.0 + uv.y * 30.0 + t * 9.0)  * 0.55
		            + sin(uv.x * 43.0  - uv.y * 71.0 + t * 4.7)  * 0.45;
		offScreen.x = sin(uv.y * 120.0 + uv.x * 25.0 - t * 7.3)  * 0.35
		            + cos(uv.y * 37.0  + uv.x * 61.0 + t * 3.1)  * 0.25;

		// Top-down view: slow world-space convection cells anchored to the
		// terrain, so they crawl over the map rather than swim on the screen
		vec2 wp = worldPos.xz * cell.x;
		float drift = t * cell.y * cell.x;
		vec2 offWorld;
		offWorld.x = sin(wp.x * 6.28 + wp.y * 2.1 + t * 1.9 + drift)  * 0.5
		           + sin(wp.y * 4.40 - wp.x * 1.3 - t * 1.3)          * 0.5;
		offWorld.y = cos(wp.y * 6.28 - wp.x * 1.7 + t * 1.6 - drift)  * 0.5
		           + sin(wp.x * 3.90 + wp.y * 2.6 + t * 2.3)          * 0.5;

		vec2  off  = mix(offScreen, offWorld, topDown);
		float ampM = mix(1.0, cell.z, topDown);

		vec2 d = off * amp * ampM * w;
		vec4 c = texture2D(screenTex, uv + d);

		// faint wavering of the light, the other thing hot ground does from above
		float ripple = 1.0 + rippleLight * w * topDown * (offWorld.x + offWorld.y) * 0.5;
		gl_FragColor = vec4(c.rgb * ripple, c.a);
	}
]]

--------------------------------------------------------------------------------
-- Callins
--------------------------------------------------------------------------------

function widget:ViewResize()
	vsx, vsy = gl.GetViewSizes()

	if screenTex then glDeleteTexture(screenTex) screenTex = nil end
	if depthTex  then glDeleteTexture(depthTex)  depthTex  = nil end

	screenTex = glCreateTexture(vsx, vsy, {
		min_filter = GL_LINEAR,
		mag_filter = GL_LINEAR,
		wrap_s     = GL_CLAMP_TO_EDGE,
		wrap_t     = GL_CLAMP_TO_EDGE,
	})
	depthTex = glCreateTexture(vsx, vsy, {
		format     = GL_DEPTH_COMPONENT24,
		min_filter = GL_NEAREST,
		mag_filter = GL_NEAREST,
	})

	if not (screenTex and depthTex) then
		spEcho("[GFX Heat] could not create screen/depth textures, removing")
		widgetHandler:RemoveWidget()
	end
end

function widget:Initialize()
	if not glCreateShader then
		spEcho("[GFX Heat] no shader support, removing")
		widgetHandler:RemoveWidget()
		return
	end

	shader = glCreateShader({
		vertex     = vertSrc,
		fragment   = fragSrc,
		uniformInt = { screenTex = 0, depthTex = 1, heightTex = 2 },
	})
	if not shader then
		spEcho("[GFX Heat] shader compilation failed, removing")
		spEcho(glGetShaderLog())
		widgetHandler:RemoveWidget()
		return
	end

	uEyePos        = glGetUniformLocation(shader, "eyePos")
	uTime          = glGetUniformLocation(shader, "time")
	uHeat          = glGetUniformLocation(shader, "heat")
	uAmp           = glGetUniformLocation(shader, "amp")
	uDistRange     = glGetUniformLocation(shader, "distRange")
	uShimmerHeight = glGetUniformLocation(shader, "shimmerHeight")
	uMapSize       = glGetUniformLocation(shader, "mapSize")
	uViewPrjInv    = glGetUniformLocation(shader, "viewProjectionInv")
	uTopDown       = glGetUniformLocation(shader, "topDown")
	uCell          = glGetUniformLocation(shader, "cell")
	uRippleLight   = glGetUniformLocation(shader, "rippleLight")

	startTimer = spGetTimer()
	self:ViewResize()
end

function widget:Shutdown()
	if screenTex then glDeleteTexture(screenTex) end
	if depthTex  then glDeleteTexture(depthTex)  end
	if shader and glDeleteShader then glDeleteShader(shader) end
end

local function CurrentHeat()
	local wg = WG.weather
	local heat = (wg and wg.heat) or 0
	if FORCE_HEAT >= 0 then heat = FORCE_HEAT end
	return heat
end

-- Depth is grabbed at the end of DrawWorld (this widget's layer is high, so
-- the fog pass and everything else has already landed), the color buffer at
-- DrawScreenEffects so the UI on top is never distorted.
function widget:DrawWorld()
	depthValid = false
	if not (shader and depthTex) then return end
	if CurrentHeat() < MIN_VISIBLE then return end

	glCopyToTexture(depthTex, 0, 0, 0, 0, vsx, vsy)
	depthValid = true
end

function widget:DrawScreenEffects()
	if not (depthValid and shader and screenTex) then return end

	local heat = CurrentHeat()
	if heat < MIN_VISIBLE then return end

	local t = spDiffTimers(spGetTimer(), startTimer) * SPEED
	local cx, cy, cz = spGetCameraPosition()

	-- how steeply we are looking down: 0 along the ground, 1 straight down
	local _, dy = spGetCameraDirection()
	local pitch = -(dy or 0)
	local topDown = (pitch - TOPDOWN_PITCH[1]) / (TOPDOWN_PITCH[2] - TOPDOWN_PITCH[1])
	if topDown < 0 then topDown = 0 elseif topDown > 1 then topDown = 1 end
	topDown = topDown * topDown * (3 - 2 * topDown) -- smoothstep

	if DEBUG then
		local now = os.clock()
		if now - debugLast > 1 then
			debugLast = now
			spEcho(string.format("[GFX Heat] heat=%.3f  pitch=%.2f  topDown=%.2f  src=%s",
				heat, pitch, topDown, (WG.weather and WG.weather.heat) and "WG.weather" or "none"))
		end
	end

	glCopyToTexture(screenTex, 0, 0, 0, 0, vsx, vsy)

	glUseShader(shader)
	glUniform(uEyePos, cx, cy, cz)
	glUniform(uTime, t)
	glUniform(uHeat, heat)
	-- amplitude in UV units, scaled so AMPLITUDE_PX means "pixels at 1080p"
	local px = AMPLITUDE_PX * (vsy / 1080)
	glUniform(uAmp, px / vsx, px / vsy)
	glUniform(uDistRange, DIST_NEAR, DIST_FAR)
	glUniform(uShimmerHeight, SHIMMER_HEIGHT)
	glUniform(uMapSize, Game.mapSizeX, Game.mapSizeZ)
	glUniformMatrix(uViewPrjInv, "viewprojectioninverse")
	glUniform(uTopDown, topDown)
	glUniform(uCell, 1 / CELL_SIZE, CELL_DRIFT, TOPDOWN_AMP_MULT)
	glUniform(uRippleLight, RIPPLE_LIGHT)

	glDepthTest(false)
	glDepthMask(false)
	glBlending(false)

	glTexture(0, screenTex)
	glTexture(1, depthTex)
	glTexture(2, "$heightmap")
	glTexRect(-1, -1, 1, 1, 0, 0, 1, 1)
	glTexture(2, false)
	glTexture(1, false)
	glTexture(0, false)

	glUseShader(0)
	glBlending(true)
	glDepthMask(true)
	glDepthTest(true)
end
