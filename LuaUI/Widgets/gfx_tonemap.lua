if gl.CreateShader == nil then
	return
end

function widget:GetInfo()
	return {
		name      = "Tonemap and Color Grade",
		desc      = "Linear-space bloom composite, exposure / contrast / saturation / temperature / lift grading, ACES or Hable filmic tonemap, vignette, 8-bit dither",
		author    = "SplinterFaction",
		date      = "2026-09-27",
		license   = "GPL V2",
		-- Draw* callins run highest layer first, so this must sit ABOVE CAS (2000)
		-- to be applied before sharpening. If your handler iterates forward, use a layer below 2000.
		layer     = 2500,
		enabled   = true,
	}
end

-----------------------------------------------------------------
-- Tunables (all exposed through WG.tonemap at runtime)
-----------------------------------------------------------------

local version = 1

local tonemapper   = 1     -- 0 = none (grade only, clamp), 1 = ACES fitted, 2 = Hable filmic
local exposure     = 0.85  -- linear multiplier before the curve. ACES lifts mids, so slightly under 1 holds overall brightness
local contrast     = 1.0   -- log-space contrast around 18% gray. 1 = neutral
local saturation   = 1.05  -- 0 = grayscale, 1 = neutral
local temperature  = 0.0   -- -1 cool .. +1 warm
local lift         = 0.0   -- raises black level; small values (0.01 .. 0.03) for a filmic lifted-blacks look
local vignette     = 0.0   -- 0 disables. 0.15 .. 0.3 is subtle
local mixAmount    = 1.0   -- 0 = untouched frame, 1 = fully graded. Handy for A/B by eye
local dither       = true  -- adds sub-LSB noise so gradients do not band on 8-bit output
local useBloom     = true  -- composite the bloom widget's result here in linear space (if it is running)

-----------------------------------------------------------------
-- Constants and shortcuts
-----------------------------------------------------------------

local GL_RGBA8 = 0x8058

local luaShaderDir = "LuaUI/Widgets/Include/"

local glTexture       = gl.Texture
local glBlending      = gl.Blending
local glCopyToTexture = gl.CopyToTexture
local glCreateTexture = gl.CreateTexture
local glDeleteTexture = gl.DeleteTexture

local spGetViewGeometry = Spring.GetViewGeometry
local spEcho            = Spring.Echo

-----------------------------------------------------------------
-- Shader sources
-----------------------------------------------------------------

local vsFullscreen = [[
#version 330
uniform float viewPosX;
uniform float viewPosY;
const vec2 verts[3] = vec2[3](
	vec2(-1.0, -1.0),
	vec2( 3.0, -1.0),
	vec2(-1.0,  3.0)
);
out vec2 uv;
out vec2 viewPos;
void main() {
	vec2 p = verts[gl_VertexID];
	gl_Position = vec4(p, 0.0, 1.0);
	uv = p * 0.5 + 0.5;
	viewPos = vec2(viewPosX, viewPosY);
}
]]

local fsTonemap = [[
#version 330
uniform sampler2D screenTex;
uniform sampler2D bloomTex;

uniform int   tonemapper;
uniform float exposure;
uniform float contrast;
uniform float saturation;
uniform float temperature;
uniform float lift;
uniform float vignette;
uniform float mixAmount;
uniform float bloomIntensity;
uniform int   useBloom;
uniform int   dither;

in vec2 uv;
in vec2 viewPos;
out vec4 fragColor;

// ---- color space ----
vec3 SrgbToLinear(vec3 c) {
	vec3 lo = c / 12.92;
	vec3 hi = pow((c + 0.055) / 1.055, vec3(2.4));
	return mix(lo, hi, step(0.04045, c));
}

vec3 LinearToSrgb(vec3 c) {
	c = max(c, vec3(0.0));
	vec3 lo = c * 12.92;
	vec3 hi = 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055;
	return mix(lo, hi, step(0.0031308, c));
}

// ---- tonemappers ----
// Narkowicz fitted ACES. Cheap, and the standard "filmic" look.
vec3 AcesFitted(vec3 x) {
	return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}

// Hable / Uncharted 2 filmic. Softer shoulder than ACES, less saturated highlights.
vec3 HablePartial(vec3 x) {
	const float A = 0.15, B = 0.50, C = 0.10, D = 0.20, E = 0.02, F = 0.30;
	return ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F;
}
vec3 Hable(vec3 c) {
	const float exposureBias = 2.0;
	const float W = 11.2;
	vec3 cur = HablePartial(c * exposureBias);
	vec3 white = HablePartial(vec3(W));
	return clamp(cur / white, 0.0, 1.0);
}

// ---- dither ----
float Hash21(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
	vec3 srcSrgb = texture(screenTex, uv).rgb;
	vec3 c = SrgbToLinear(srcSrgb);

	// Bloom in linear space, before the curve, so it has real headroom
	if (useBloom == 1) {
		vec3 b = SrgbToLinear(clamp(texture(bloomTex, uv).rgb, 0.0, 1.0));
		c += b * bloomIntensity;
	}

	// ---- grade (linear space) ----
	c *= exposure;

	// temperature: push red/blue against each other, energy-neutral-ish
	c *= vec3(1.0 + 0.10 * temperature, 1.0, 1.0 - 0.10 * temperature);

	// log-space contrast around 18% gray
	{
		const float pivot = 0.18;
		const float eps = 1e-4;
		vec3 l = log2(c + eps);
		l = (l - log2(pivot)) * contrast + log2(pivot);
		c = exp2(l) - eps;
	}

	// saturation
	{
		float luma = dot(c, vec3(0.2126, 0.7152, 0.0722));
		c = mix(vec3(luma), c, saturation);
	}

	// lifted blacks
	c = c + lift * (1.0 - c);

	// ---- tonemap ----
	if (tonemapper == 1) {
		c = AcesFitted(c);
	} else if (tonemapper == 2) {
		c = Hable(c);
	} else {
		c = clamp(c, 0.0, 1.0);
	}

	// vignette (after the curve so it darkens display values evenly)
	if (vignette > 0.0) {
		float d = distance(uv, vec2(0.5)) * 1.4142;
		c *= 1.0 - vignette * smoothstep(0.45, 1.0, d);
	}

	vec3 outSrgb = LinearToSrgb(c);

	// A/B mix against the untouched frame
	outSrgb = mix(srcSrgb, outSrgb, mixAmount);

	// ordered-ish noise, +-0.5 LSB, kills 8-bit banding in skies and fog
	if (dither == 1) {
		float n = Hash21(gl_FragCoord.xy - viewPos) - 0.5;
		outSrgb += n / 255.0;
	}

	fragColor = vec4(outSrgb, 1.0);
}
]]

-----------------------------------------------------------------
-- State
-----------------------------------------------------------------

local LuaShader

local vsx, vsy, vpx, vpy = 1, 1, 0, 0
local screenTex
local shader
local fullTri

local resourcesReady = false
local needsRebuild = true

-----------------------------------------------------------------
-- Resource management (GL work is deferred to draw callins)
-----------------------------------------------------------------

local function DestroyResources()
	if screenTex then glDeleteTexture(screenTex) end
	screenTex = nil
	if shader then shader:Finalize() end
	shader = nil
	if fullTri then fullTri:Delete() end
	fullTri = nil
	resourcesReady = false
end

local function Fail(msg)
	spEcho("[Tonemap] " .. msg .. ", removing widget")
	DestroyResources()
	widgetHandler:RemoveWidget()
end

local function UpdateUniforms()
	if not resourcesReady then return end
	shader:ActivateWith(function()
		shader:SetUniform("viewPosX", vpx)
		shader:SetUniform("viewPosY", vpy)
		shader:SetUniform("tonemapper", tonemapper)
		shader:SetUniform("exposure", exposure)
		shader:SetUniform("contrast", contrast)
		shader:SetUniform("saturation", saturation)
		shader:SetUniform("temperature", temperature)
		shader:SetUniform("lift", lift)
		shader:SetUniform("vignette", vignette)
		shader:SetUniform("mixAmount", mixAmount)
		shader:SetUniform("dither", dither and 1 or 0)
	end)
end

local function CreateResources()
	DestroyResources()

	vsx, vsy, vpx, vpy = spGetViewGeometry()
	vsx = math.max(4, vsx)
	vsy = math.max(4, vsy)

	screenTex = glCreateTexture(vsx, vsy, {
		format = GL_RGBA8,
		min_filter = GL.NEAREST,
		mag_filter = GL.NEAREST,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
	})
	if not screenTex then Fail("could not create screen copy texture"); return false end

	shader = LuaShader({
		vertex = vsFullscreen,
		fragment = fsTonemap,
		uniformInt = { screenTex = 0, bloomTex = 1 },
	}, "Tonemap and Color Grade")
	if not shader:Initialize() then Fail("shader failed to compile"); return false end

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

function widget:DrawScreenEffects()
	if needsRebuild then
		if not CreateResources() then return end
	end
	if not resourcesReady then return end

	-- Bloom handoff: only when the bloom widget is running and has a result this frame
	local bloomTex, bloomIntensity = nil, 0
	if useBloom and WG.bloom and WG.bloom.getResultTexture then
		bloomTex = WG.bloom.getResultTexture()
		if bloomTex then bloomIntensity = WG.bloom.getIntensity() end
	end
	-- Tell the bloom widget whether we are taking over its composite
	WG.tonemap.compositesBloom = (bloomTex ~= nil)

	glCopyToTexture(screenTex, 0, 0, vpx, vpy, vsx, vsy)

	glTexture(0, screenTex)
	if bloomTex then glTexture(1, bloomTex) end
	glBlending(false)
	shader:Activate()
	shader:SetUniform("useBloom", bloomTex and 1 or 0)
	shader:SetUniform("bloomIntensity", bloomIntensity)
	fullTri:DrawArrays(GL.TRIANGLES, 3)
	shader:Deactivate()
	glBlending(true)
	glTexture(0, false)
	glTexture(1, false)
end

-----------------------------------------------------------------
-- Widget lifecycle
-----------------------------------------------------------------

function widget:Initialize()
	LuaShader = VFS.Include(luaShaderDir .. "LuaShader.lua")
	if not LuaShader then
		spEcho("[Tonemap] LuaShader not found at " .. luaShaderDir .. ", removing widget")
		widgetHandler:RemoveWidget()
		return
	end

	needsRebuild = true

	WG.tonemap = {
		compositesBloom = false, -- read by the bloom widget each frame

		getTonemapper  = function() return tonemapper end,
		setTonemapper  = function(v) tonemapper = math.floor(v); UpdateUniforms() end,
		getExposure    = function() return exposure end,
		setExposure    = function(v) exposure = v; UpdateUniforms() end,
		getContrast    = function() return contrast end,
		setContrast    = function(v) contrast = v; UpdateUniforms() end,
		getSaturation  = function() return saturation end,
		setSaturation  = function(v) saturation = v; UpdateUniforms() end,
		getTemperature = function() return temperature end,
		setTemperature = function(v) temperature = v; UpdateUniforms() end,
		getLift        = function() return lift end,
		setLift        = function(v) lift = v; UpdateUniforms() end,
		getVignette    = function() return vignette end,
		setVignette    = function(v) vignette = v; UpdateUniforms() end,
		getMix         = function() return mixAmount end,
		setMix         = function(v) mixAmount = v; UpdateUniforms() end,
		getDither      = function() return dither end,
		setDither      = function(v) dither = v and true or false; UpdateUniforms() end,
		getUseBloom    = function() return useBloom end,
		setUseBloom    = function(v) useBloom = v and true or false end,
	}
end

function widget:Shutdown()
	DestroyResources()
	WG.tonemap = nil
end

function widget:ViewResize()
	needsRebuild = true
end

function widget:GetConfigData()
	return {
		version     = version,
		tonemapper  = tonemapper,
		exposure    = exposure,
		contrast    = contrast,
		saturation  = saturation,
		temperature = temperature,
		lift        = lift,
		vignette    = vignette,
		mixAmount   = mixAmount,
		dither      = dither,
		useBloom    = useBloom,
	}
end

function widget:SetConfigData(data)
	if data.version ~= version then return end
	if data.tonemapper  ~= nil then tonemapper  = data.tonemapper  end
	if data.exposure    ~= nil then exposure    = data.exposure    end
	if data.contrast    ~= nil then contrast    = data.contrast    end
	if data.saturation  ~= nil then saturation  = data.saturation  end
	if data.temperature ~= nil then temperature = data.temperature end
	if data.lift        ~= nil then lift        = data.lift        end
	if data.vignette    ~= nil then vignette    = data.vignette    end
	if data.mixAmount   ~= nil then mixAmount   = data.mixAmount   end
	if data.dither      ~= nil then dither      = data.dither      end
	if data.useBloom    ~= nil then useBloom    = data.useBloom    end
end
