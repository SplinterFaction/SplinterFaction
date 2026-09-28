if gl.CreateShader == nil then
	return
end

function widget:GetInfo()
	return {
		name      = "Bloom (Mip Chain)",
		desc      = "Physically-styled bloom: soft-threshold prefilter on the lit frame, 13-tap downsample / tent upsample mip chain, emissive boost from the model gbuffer",
		author    = "SplinterFaction",
		date      = "2026-09-27",
		license   = "GPL V2",
		layer     = 99999,
		enabled   = true,
	}
end

-----------------------------------------------------------------
-- Tunables (all exposed through WG.bloom at runtime)
-----------------------------------------------------------------

local version    = 1

local intensity  = 1.0   -- final multiplier on the bloom contribution
local threshold  = 0.70  -- luma at which a lit pixel starts to bloom (0..1, LDR)
local knee       = 0.30  -- softness of the threshold; 0 = hard cut
local emitBoost  = 1.0   -- extra bloom for emissive model pixels (0 disables)
local scatter    = 0.70  -- how much each level blends toward the wider level (0.5 tight .. 0.9 diffuse)
local radius     = 1.0   -- tent upsample radius in texels of the coarser level
local maxLevels  = 6     -- half, quarter, ... down to 1/64 at most
local minLevelPx = 16    -- stop making levels below this many pixels on the short side
local debugDraw  = false -- show the bloom buffer alone (opaque) instead of adding it to the frame

-----------------------------------------------------------------
-- Constants and shortcuts
-----------------------------------------------------------------

local GL_RGBA8   = 0x8058
local GL_RGBA16F = 0x881A

local luaShaderDir = "LuaUI/Widgets/Include/"

local glTexture        = gl.Texture
local glBlending       = gl.Blending
local glDepthTest      = gl.DepthTest
local glDepthMask      = gl.DepthMask
local glCopyToTexture  = gl.CopyToTexture
local glRenderToTexture = gl.RenderToTexture
local glCreateTexture  = gl.CreateTexture
local glDeleteTexture  = gl.DeleteTexture

local spGetViewGeometry = Spring.GetViewGeometry
local spEcho            = Spring.Echo

-----------------------------------------------------------------
-- Shader sources
-----------------------------------------------------------------

-- Shared full-screen triangle vertex shader. uv is derived from clip space,
-- so it works both for RenderToTexture targets and for the final screen pass.
local vsFullscreen = [[
#version 330
const vec2 verts[3] = vec2[3](
	vec2(-1.0, -1.0),
	vec2( 3.0, -1.0),
	vec2(-1.0,  3.0)
);
out vec2 uv;
void main() {
	vec2 p = verts[gl_VertexID];
	gl_Position = vec4(p, 0.0, 1.0);
	uv = p * 0.5 + 0.5;
}
]]

-- Shared GLSL helpers, prepended to the fragment shaders that need them.
local glslCommon = [[
// 13-tap downsample (Jimenez, "Next Generation Post Processing in Call of Duty: Advanced Warfare").
// Overlapping bilinear boxes give a smooth, alias-free downsample for a fraction of a gaussian's cost.
vec3 Downsample13(sampler2D tex, vec2 uv, vec2 texel) {
	vec3 a = texture(tex, uv + texel * vec2(-2.0, -2.0)).rgb;
	vec3 b = texture(tex, uv + texel * vec2( 0.0, -2.0)).rgb;
	vec3 c = texture(tex, uv + texel * vec2( 2.0, -2.0)).rgb;
	vec3 d = texture(tex, uv + texel * vec2(-2.0,  0.0)).rgb;
	vec3 e = texture(tex, uv).rgb;
	vec3 f = texture(tex, uv + texel * vec2( 2.0,  0.0)).rgb;
	vec3 g = texture(tex, uv + texel * vec2(-2.0,  2.0)).rgb;
	vec3 h = texture(tex, uv + texel * vec2( 0.0,  2.0)).rgb;
	vec3 i = texture(tex, uv + texel * vec2( 2.0,  2.0)).rgb;
	vec3 j = texture(tex, uv + texel * vec2(-1.0, -1.0)).rgb;
	vec3 k = texture(tex, uv + texel * vec2( 1.0, -1.0)).rgb;
	vec3 l = texture(tex, uv + texel * vec2(-1.0,  1.0)).rgb;
	vec3 m = texture(tex, uv + texel * vec2( 1.0,  1.0)).rgb;

	vec3 result = e * 0.125;
	result += (a + c + g + i) * 0.03125;
	result += (b + d + f + h) * 0.0625;
	result += (j + k + l + m) * 0.125;
	return result;
}

// 9-tap tent filter upsample. Wide, cheap, and free of the ringing a box upsample produces.
vec3 UpsampleTent(sampler2D tex, vec2 uv, vec2 texel, float rad) {
	vec4 d = texel.xyxy * vec4(1.0, 1.0, -1.0, 0.0) * rad;
	vec3 s;
	s  = texture(tex, uv - d.xy).rgb;
	s += texture(tex, uv - d.wy).rgb * 2.0;
	s += texture(tex, uv - d.zy).rgb;
	s += texture(tex, uv + d.zw).rgb * 2.0;
	s += texture(tex, uv       ).rgb * 4.0;
	s += texture(tex, uv + d.xw).rgb * 2.0;
	s += texture(tex, uv + d.zy).rgb;
	s += texture(tex, uv + d.wy).rgb * 2.0;
	s += texture(tex, uv + d.xy).rgb;
	return s * (1.0 / 16.0);
}
]]

-- Prefilter: reads the lit frame at full res, writes the first (half-res) bloom level.
-- Soft-knee threshold so pixels near the cutoff fade in rather than pop.
-- Emissive pixels from the model gbuffer get an unconditional boost, gated by
-- the model-vs-map depth test so units behind terrain do not leak glow.
local fsPrefilter = [[
#version 330
uniform sampler2D screenTex;
uniform sampler2D emitTex;
uniform sampler2D modelDepthTex;
uniform sampler2D mapDepthTex;
uniform float threshold;
uniform float knee;
uniform float emitBoost;
uniform int   useEmit;

in vec2 uv;
out vec4 fragColor;
]] .. glslCommon .. [[

vec3 SoftThreshold(vec3 c) {
	float br = max(c.r, max(c.g, c.b));
	float soft = clamp(br - threshold + knee, 0.0, 2.0 * knee);
	soft = soft * soft / (4.0 * knee + 1e-4);
	float contrib = max(soft, br - threshold) / max(br, 1e-4);
	return c * contrib;
}

void main() {
	vec2 texel = 1.0 / vec2(textureSize(screenTex, 0));
	vec3 c = Downsample13(screenTex, uv, texel);
	vec3 bloom = SoftThreshold(c);

	if (useEmit == 1) {
		float modelDepth = texture(modelDepthTex, uv).r;
		float mapDepth   = texture(mapDepthTex,   uv).r;
		float unoccluded = float(modelDepth < mapDepth);
		float emit = texture(emitTex, uv).r * unoccluded;
		bloom += c * emit * emitBoost;
	}

	fragColor = vec4(bloom, 1.0);
}
]]

-- Downsample: one level to the next.
local fsDownsample = [[
#version 330
uniform sampler2D srcTex;
in vec2 uv;
out vec4 fragColor;
]] .. glslCommon .. [[
void main() {
	vec2 texel = 1.0 / vec2(textureSize(srcTex, 0));
	fragColor = vec4(Downsample13(srcTex, uv, texel), 1.0);
}
]]

-- Upsample: blend the wider (coarser) level into the current one.
-- mix() keeps the energy bounded no matter how many levels there are,
-- so intensity behaves the same at 1080p and 4K.
local fsUpsample = [[
#version 330
uniform sampler2D lowTex;   // coarser level, already upsampled below this one
uniform sampler2D highTex;  // this level's downsample
uniform float scatter;
uniform float radius;
in vec2 uv;
out vec4 fragColor;
]] .. glslCommon .. [[
void main() {
	vec2 texel = 1.0 / vec2(textureSize(lowTex, 0));
	vec3 low  = UpsampleTent(lowTex, uv, texel, radius);
	vec3 high = texture(highTex, uv).rgb;
	fragColor = vec4(mix(high, low, scatter), 1.0);
}
]]

-- Composite: additive onto the frame (or opaque in debug mode).
local fsComposite = [[
#version 330
uniform sampler2D bloomTex;
uniform float intensity;
in vec2 uv;
out vec4 fragColor;
void main() {
	fragColor = vec4(texture(bloomTex, uv).rgb * intensity, 1.0);
}
]]

-----------------------------------------------------------------
-- State
-----------------------------------------------------------------

local LuaShader

local vsx, vsy, vpx, vpy = 1, 1, 0, 0
local screenTex
local downTex, upTex = {}, {}
local numLevels = 0

local prefilterShader, downShader, upShader, compositeShader
local fullTri

local useEmit = false
local lastResult = nil
local resourcesReady = false
local needsRebuild = true

-----------------------------------------------------------------
-- Resource management (GL work is deferred to draw callins)
-----------------------------------------------------------------

local function DestroyResources()
	if screenTex then glDeleteTexture(screenTex) end
	screenTex = nil
	for i = 1, #downTex do glDeleteTexture(downTex[i]) end
	for i = 1, #upTex do glDeleteTexture(upTex[i]) end
	downTex, upTex = {}, {}
	numLevels = 0
	lastResult = nil

	if prefilterShader then prefilterShader:Finalize() end
	if downShader      then downShader:Finalize()      end
	if upShader        then upShader:Finalize()        end
	if compositeShader then compositeShader:Finalize() end
	prefilterShader, downShader, upShader, compositeShader = nil, nil, nil, nil

	if fullTri then fullTri:Delete() end
	fullTri = nil

	resourcesReady = false
end

local function Fail(msg)
	spEcho("[Bloom] " .. msg .. ", removing widget")
	DestroyResources()
	widgetHandler:RemoveWidget()
end

local function UpdateUniforms()
	if not resourcesReady then return end
	prefilterShader:ActivateWith(function()
		prefilterShader:SetUniform("threshold", threshold)
		prefilterShader:SetUniform("knee", knee)
		prefilterShader:SetUniform("emitBoost", emitBoost)
		prefilterShader:SetUniform("useEmit", (useEmit and emitBoost > 0) and 1 or 0)
	end)
	upShader:ActivateWith(function()
		upShader:SetUniform("scatter", scatter)
		upShader:SetUniform("radius", radius)
	end)
	compositeShader:ActivateWith(function()
		compositeShader:SetUniform("intensity", intensity)
	end)
end

local function MakeLevelTexture(w, h)
	return glCreateTexture(w, h, {
		fbo = true,
		format = GL_RGBA16F,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
	})
end

local function CreateResources()
	DestroyResources()

	vsx, vsy, vpx, vpy = spGetViewGeometry()
	vsx = math.max(4, vsx)
	vsy = math.max(4, vsy)

	-- Full-res copy of the lit frame
	screenTex = glCreateTexture(vsx, vsy, {
		format = GL_RGBA8,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
	})
	if not screenTex then Fail("could not create screen copy texture"); return false end

	-- Mip chain: level 1 is half res, each further level halves again
	local w, h = vsx, vsy
	for i = 1, maxLevels do
		w, h = math.floor(w / 2), math.floor(h / 2)
		if math.min(w, h) < minLevelPx then break end
		downTex[i] = MakeLevelTexture(w, h)
		if not downTex[i] then Fail("could not create bloom level " .. i); return false end
		numLevels = i
	end
	if numLevels < 1 then Fail("viewport too small for bloom"); return false end
	for i = 1, numLevels - 1 do
		local tw, th = gl.TextureInfo(downTex[i]).xsize, gl.TextureInfo(downTex[i]).ysize
		upTex[i] = MakeLevelTexture(tw, th)
		if not upTex[i] then Fail("could not create bloom upsample level " .. i); return false end
	end

	-- Shaders
	prefilterShader = LuaShader({
		vertex = vsFullscreen,
		fragment = fsPrefilter,
		uniformInt = { screenTex = 0, emitTex = 1, modelDepthTex = 2, mapDepthTex = 3 },
	}, "Bloom: prefilter")
	downShader = LuaShader({
		vertex = vsFullscreen,
		fragment = fsDownsample,
		uniformInt = { srcTex = 0 },
	}, "Bloom: downsample")
	upShader = LuaShader({
		vertex = vsFullscreen,
		fragment = fsUpsample,
		uniformInt = { lowTex = 0, highTex = 1 },
	}, "Bloom: upsample")
	compositeShader = LuaShader({
		vertex = vsFullscreen,
		fragment = fsComposite,
		uniformInt = { bloomTex = 0 },
	}, "Bloom: composite")

	if not prefilterShader:Initialize() then Fail("prefilter shader failed to compile"); return false end
	if not downShader:Initialize()      then Fail("downsample shader failed to compile"); return false end
	if not upShader:Initialize()        then Fail("upsample shader failed to compile"); return false end
	if not compositeShader:Initialize() then Fail("composite shader failed to compile"); return false end

	fullTri = gl.GetVAO()
	if not fullTri then Fail("VAO not supported"); return false end

	resourcesReady = true
	needsRebuild = false
	UpdateUniforms()
	return true
end

-----------------------------------------------------------------
-- Rendering
-----------------------------------------------------------------

local function DrawTri()
	fullTri:DrawArrays(GL.TRIANGLES, 3)
end

local function RenderBloom()
	-- 1. Grab the lit frame
	glCopyToTexture(screenTex, 0, 0, vpx, vpy, vsx, vsy)

	-- 2. Prefilter into level 1
	glTexture(0, screenTex)
	if useEmit then
		glTexture(1, "$model_gbuffer_emittex")
		glTexture(2, "$model_gbuffer_zvaltex")
		glTexture(3, "$map_gbuffer_zvaltex")
	end
	prefilterShader:Activate()
	glRenderToTexture(downTex[1], DrawTri)
	prefilterShader:Deactivate()
	glTexture(1, false)
	glTexture(2, false)
	glTexture(3, false)

	-- 3. Downsample chain
	downShader:Activate()
	for i = 2, numLevels do
		glTexture(0, downTex[i - 1])
		glRenderToTexture(downTex[i], DrawTri)
	end
	downShader:Deactivate()

	-- 4. Upsample chain, coarsest to finest
	local result = downTex[numLevels]
	if numLevels > 1 then
		upShader:Activate()
		for i = numLevels - 1, 1, -1 do
			glTexture(0, result)      -- coarser level
			glTexture(1, downTex[i])  -- this level
			glRenderToTexture(upTex[i], DrawTri)
			result = upTex[i]
		end
		upShader:Deactivate()
		glTexture(1, false)
	end

	lastResult = result

	-- 5. Composite onto the frame, unless a tonemap widget will do it in linear space
	if WG.tonemap and WG.tonemap.compositesBloom then
		glTexture(0, false)
		return
	end
	glDepthTest(false)
	glDepthMask(false)
	if debugDraw then
		glBlending(false)
	else
		glBlending(GL.ONE, GL.ONE)
	end
	glTexture(0, result)
	compositeShader:Activate()
	DrawTri()
	compositeShader:Deactivate()
	glTexture(0, false)
	glBlending("reset")
	glDepthMask(true)
	glDepthTest(true)
end

function widget:DrawWorld()
	if needsRebuild then
		if not CreateResources() then return end
	end
	if not resourcesReady then return end
	RenderBloom()
end

-----------------------------------------------------------------
-- Widget lifecycle
-----------------------------------------------------------------

function widget:Initialize()
	LuaShader = VFS.Include(luaShaderDir .. "LuaShader.lua")
	if not LuaShader then
		spEcho("[Bloom] LuaShader not found at " .. luaShaderDir .. ", removing widget")
		widgetHandler:RemoveWidget()
		return
	end

	local hasModelGbuffer = (Spring.GetConfigString("AllowDeferredModelRendering") == "1")
	local hasMapGbuffer   = (Spring.GetConfigString("AllowDeferredMapRendering")   == "1")
	useEmit = hasModelGbuffer and hasMapGbuffer
	if not useEmit then
		spEcho("[Bloom] deferred model/map rendering is off, emissive boost disabled (threshold bloom still active)")
	end

	needsRebuild = true

	-- Runtime API
	WG.bloom = {
		getIntensity = function() return intensity end,
		setIntensity = function(v) intensity = v; UpdateUniforms() end,
		getThreshold = function() return threshold end,
		setThreshold = function(v) threshold = v; UpdateUniforms() end,
		getKnee      = function() return knee end,
		setKnee      = function(v) knee = v; UpdateUniforms() end,
		getEmitBoost = function() return emitBoost end,
		setEmitBoost = function(v) emitBoost = v; UpdateUniforms() end,
		getScatter   = function() return scatter end,
		setScatter   = function(v) scatter = v; UpdateUniforms() end,
		getRadius    = function() return radius end,
		setRadius    = function(v) radius = v; UpdateUniforms() end,
		getDebug     = function() return debugDraw end,
		-- for a downstream tonemap/composite pass: raw (unscaled) bloom result for this frame, or nil
		getResultTexture = function() return lastResult end,
		setDebug     = function(v) debugDraw = v and true or false end,
	}

	-- Compatibility shim so an existing options menu wired to the old widget keeps working
	WG.bloomdeferred = {
		getBrightness = WG.bloom.getIntensity,
		setBrightness = WG.bloom.setIntensity,
		getBlursize   = WG.bloom.getScatter,
		setBlursize   = WG.bloom.setScatter,
		getPreset     = function() return 1 end,
		setPreset     = function() end,
	}
end

function widget:Shutdown()
	DestroyResources()
	WG.bloom = nil
	WG.bloomdeferred = nil
end

function widget:ViewResize()
	needsRebuild = true
end

function widget:GetConfigData()
	return {
		version   = version,
		intensity = intensity,
		threshold = threshold,
		knee      = knee,
		emitBoost = emitBoost,
		scatter   = scatter,
		radius    = radius,
	}
end

function widget:SetConfigData(data)
	if data.version ~= version then return end
	if data.intensity ~= nil then intensity = data.intensity end
	if data.threshold ~= nil then threshold = data.threshold end
	if data.knee      ~= nil then knee      = data.knee      end
	if data.emitBoost ~= nil then emitBoost = data.emitBoost end
	if data.scatter   ~= nil then scatter   = data.scatter   end
	if data.radius    ~= nil then radius    = data.radius    end
end
