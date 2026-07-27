function widget:GetInfo()
	return {
		name      = "GFX Fog",
		desc      = "Depth-reconstructed ground fog, driven by the Weather widget",
		author    = "trepan, user, aegis, jK, Doo (rewritten 2026)",
		date      = "2026-07-26",
		version   = "4.0",
		license   = "GNU GPL, v2 or later",
		layer     = 1,
		enabled   = true,
	}
end

--------------------------------------------------------------------------------
-- Tuning
--------------------------------------------------------------------------------

local FOG_ATTEN        = 0.00025 -- optical density; larger = thicker fog
local FOG_MAX_FRACTION = 0.8    -- fog ceiling as a fraction of the map's max terrain height...
local FOG_MIN_SLAB     = 10000    -- ...but never lower than this (elmos), so flat maps still get visible fog
local MIN_FOG_HEIGHT   = 5      -- skip drawing entirely below this fog ceiling
local NOISE_PRIME      = 2521   -- dither cycle length in draw frames (prime)
local DEBUG            = false  -- echo fog intensity/height once per second

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
local glGetAtmosphere      = gl.GetAtmosphere
local spGetCameraPosition  = Spring.GetCameraPosition
local spGetDrawFrame       = Spring.GetDrawFrame
local spEcho               = Spring.Echo

local GL_NEAREST           = GL.NEAREST
local GL_SRC_ALPHA         = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_DEPTH_COMPONENT24 = 0x81A6

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local vsx, vsy = 1, 1
local fogSlabMax = FOG_MIN_SLAB

local depthShader
local depthTexture

local uEyePos, uNoise, uFogColor, uFogHeight, uFogAtten, uViewPrjInv

--------------------------------------------------------------------------------
-- Shaders (compiled ONCE; the original baked fog color/height into the source
-- as constants and recompiled the shader every single draw frame)
--------------------------------------------------------------------------------

local vertSrc = [[
	void main(void)
	{
		gl_TexCoord[0] = gl_MultiTexCoord0;
		gl_Position    = gl_Vertex;
	}
]]

local fragSrc = [[
	uniform sampler2D tex0;
	uniform vec3  eyePos;
	uniform vec2  noise;
	uniform vec3  fogColor;
	uniform float fogHeight;
	uniform float fogAtten;
	uniform mat4  viewProjectionInv;

	// source: http://www.ozone3d.net/blogs/lab/20110427/glsl-random-generator/
	float rand(vec2 n)
	{
		return fract(sin(dot(n.xy, vec2(12.9898, 78.233))) * 43758.5453);
	}

	void main(void)
	{
		float z = texture2D(tex0, gl_TexCoord[0].st).x;

		// reconstruct the world position of this fragment from the depth buffer
		vec4 ppos      = vec4(vec3(gl_TexCoord[0].st, z) * 2.0 - 1.0, 1.0);
		vec4 worldPos4 = viewProjectionInv * ppos;
		vec3 worldPos  = worldPos4.xyz / worldPos4.w;
		vec3 toPoint   = worldPos - eyePos;

		// path length travelled through the fog slab [0, fogHeight]
		float h0 = clamp(worldPos.y, 0.0, fogHeight);
		float h1 = clamp(eyePos.y,   0.0, fogHeight);

		float len   = length(toPoint);
		float dist  = len * abs(h1 - h0) / max(abs(toPoint.y), 1.0); // guarded div (the original's FIXME)
		float atten = clamp(1.0 - exp(-dist * fogAtten), 0.0, 1.0);

		// dither to hide banding
		vec2 seed = gl_TexCoord[0].st + noise;
		gl_FragColor = vec4(fogColor + 0.030 * rand(seed), atten);
	}
]]

--------------------------------------------------------------------------------
-- Callins
--------------------------------------------------------------------------------

function widget:ViewResize()
	vsx, vsy = gl.GetViewSizes()

	if depthTexture then
		glDeleteTexture(depthTexture)
		depthTexture = nil
	end

	depthTexture = glCreateTexture(vsx, vsy, {
		format     = GL_DEPTH_COMPONENT24,
		min_filter = GL_NEAREST,
		mag_filter = GL_NEAREST,
	})

	if not depthTexture then
		spEcho("[GFX Fog] could not create depth texture, removing")
		widgetHandler:RemoveWidget()
	end
end

function widget:Initialize()
	if not glCreateShader then
		spEcho("[GFX Fog] no shader support, removing")
		widgetHandler:RemoveWidget()
		return
	end

	depthShader = glCreateShader({
		vertex     = vertSrc,
		fragment   = fragSrc,
		uniformInt = { tex0 = 0 },
	})

	if not depthShader then
		spEcho("[GFX Fog] shader compilation failed, removing")
		spEcho(glGetShaderLog())
		widgetHandler:RemoveWidget()
		return
	end

	uEyePos     = glGetUniformLocation(depthShader, "eyePos")
	uNoise      = glGetUniformLocation(depthShader, "noise")
	uFogColor   = glGetUniformLocation(depthShader, "fogColor")
	uFogHeight  = glGetUniformLocation(depthShader, "fogHeight")
	uFogAtten   = glGetUniformLocation(depthShader, "fogAtten")
	uViewPrjInv = glGetUniformLocation(depthShader, "viewProjectionInv")

	-- Fog ceiling: fraction of the map's max terrain height, but floored so
	-- flat maps still get a visible slab (the original tied it directly to
	-- terrain height, which made fog invisible on low-relief maps)
	local _, max = Spring.GetGroundExtremes()
	fogSlabMax = math.max((max or 0) * FOG_MAX_FRACTION, FOG_MIN_SLAB)

	self:ViewResize()
end

function widget:Shutdown()
	if depthTexture then
		glDeleteTexture(depthTexture)
		depthTexture = nil
	end
	if depthShader and glDeleteShader then
		glDeleteShader(depthShader)
		depthShader = nil
	end
end

function widget:DrawWorld()
	if not (depthShader and depthTexture) then
		return
	end

	-- Fog ceiling and color from the Weather widget; fall back to reading the
	-- atmosphere directly if it isn't running
	local wg = WG.weather
	local fogStart, fr, fg, fb
	if wg and wg.fogStart then
		fogStart = wg.fogStart
		fr, fg, fb = wg.fogR, wg.fogG, wg.fogB
	else
		fogStart = glGetAtmosphere("fogStart") or 1
		fr, fg, fb = glGetAtmosphere("fogColor")
	end

	local intensity = 1 - fogStart
	local fogHeight = fogSlabMax * intensity

	if DEBUG then
		local df = spGetDrawFrame()
		if df % 60 == 0 then
			spEcho(string.format("[GFX Fog] intensity %.2f  height %.0f  drawing %s",
				intensity, fogHeight, tostring(fogHeight > MIN_FOG_HEIGHT)))
		end
	end

	if fogHeight <= MIN_FOG_HEIGHT then
		return -- clear skies
	end

	-- grab the current depth buffer (texture itself is reused; the original
	-- deleted and recreated it every frame)
	glCopyToTexture(depthTexture, 0, 0, 0, 0, vsx, vsy)

	glUseShader(depthShader)

	local cpx, cpy, cpz = spGetCameraPosition()
	glUniform(uEyePos, cpx, cpy, cpz)

	local noise1 = (spGetDrawFrame() / NOISE_PRIME) % 1
	glUniform(uNoise, noise1 + (cpx % 1), noise1 + (cpz % 1))

	glUniform(uFogColor, fr or 0.5, fg or 0.5, fb or 0.5)
	glUniform(uFogHeight, fogHeight)
	glUniform(uFogAtten, FOG_ATTEN)
	glUniformMatrix(uViewPrjInv, "viewprojectioninverse")

	glDepthTest(false)
	glDepthMask(false)
	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

	glTexture(0, depthTexture)
	glTexRect(-1, -1, 1, 1, 0, 0, 1, 1)
	glTexture(0, false)

	glUseShader(0)
	glDepthMask(true)
	glDepthTest(true)
end
