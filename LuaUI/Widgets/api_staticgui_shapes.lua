function widget:GetInfo()
	return {
		name    = "Static GUI Shapes",
		desc    = "Shared instanced renderer for the Static GUI suite. Replaces immediate-mode rounded rects, plain rects and lines with a single SDF-shaded instanced draw call.",
		author  = "",
		date    = "2026-08-13",
		license = "GNU GPL, v2 or later",
		layer   = -100000,   -- must Initialize before every consumer widget
		enabled = true,
		handler = true,
	}
end

--------------------------------------------------------------------------------
--
-- WHY THIS EXISTS
--
-- Every gui_static_* widget used to draw its panel chrome with gl.Rect,
-- gl.TexRect and gl.BeginEnd/gl.Vertex. Those are OpenGL 1.1 immediate mode:
-- gl.Rect is glRectf, gl.TexRect is a raw glBegin(GL_QUADS), gl.Vertex is
-- glVertex3f. One RectRound was 7 glBegin/glEnd pairs, 28 vertices and 2
-- texture binds.
--
-- Immediate mode is removed from OpenGL core profile entirely, which is the
-- only way to get above GL 2.1 on macOS, and it is the pathological case for
-- any GL-over-Vulkan/Metal translation layer.
--
-- This module accumulates every shape into one instance buffer and issues a
-- single instanced draw call per flush. Rounding is done in the fragment
-- shader with a signed distance function, so there is no corner texture and
-- no tessellation.
--
-- GLSL version is deliberately 330 core: macOS caps OpenGL at 4.1 / GLSL 410,
-- so the 430-version shaders used elsewhere in the GL4 ecosystem cannot run
-- there. 330 is the highest version that works everywhere we ship.
--
--
-- HOW TO USE IT FROM A CONSUMER WIDGET
--
-- At the top of the widget, replace the GL locals:
--
--     local SG = nil   -- resolved on first draw
--     local glColor, glRect, glTexture, glTexRect, RectRound   -- see BindSG()
--
-- and call SG.Flush() at the end of DrawScreen.
--
-- The wrappers below are ordering-safe: SG.Texture, SG.TexRect, SG.Scissor
-- and a font wrapped with SG.WrapFont all flush the pending batch before they
-- run, so anything drawn between shape calls lands in the right z-order
-- without the call site having to think about it.
--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Tunables
--------------------------------------------------------------------------------

-- Instance buffer capacity. 16 floats per instance, so 16384 instances is
-- 1 MB of VRAM. Panel chrome across the whole suite is well under 2000, but
-- the end graph turns every stat line into one capsule per sample interval:
-- 16 teams over a long game can reach five figures on its own.
local MAX_INSTANCES = 16384

-- Antialiasing width in pixels for the SDF edge. 0.5 is a crisp one-pixel
-- edge; raise it if the UI looks harsh on a high-DPI panel.
local DEFAULT_FEATHER = 0.5

local FLOATS_PER_INSTANCE = 16

local MODE_RECT   = 0
local MODE_LINE   = 1
local MODE_ACCENT = 2
local MODE_ICON   = 3

-- Geometry of staticgui_accent.png, reproduced analytically. The texture was
-- 512x16, pure white, binary alpha: a centre bar at y 4..11 running the full
-- width, plus a 16px square cap at each end at full height.
--   cap width  = 16/512 of the strip width
--   bar height =  8/16 of the strip height
-- Keeping the cap as a fraction of width matches how the texture stretched;
-- pass an explicit capFrac to AccentStrip if you would rather it be fixed.
local ACCENT_CAP_FRACTION = 16 / 512
local ACCENT_BAR_FRACTION = 8 / 16

--------------------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------------------

local glCreateShader      = gl.CreateShader
local glDeleteShader      = gl.DeleteShader
local glUseShader         = gl.UseShader
local glGetShaderLog      = gl.GetShaderLog
local glGetUniformLocation = gl.GetUniformLocation
local glUniform           = gl.Uniform
local glBlending          = gl.Blending
local glBlendFuncSeparate = gl.BlendFuncSeparate   -- may be nil on old engines
local glDepthTest         = gl.DepthTest
local glTextureRaw        = gl.Texture

local spGetViewGeometry   = Spring.GetViewGeometry
local spEcho              = Spring.Echo

local mathMin  = math.min
local mathMax  = math.max
local mathSqrt = math.sqrt

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local ready = false          -- shader + buffers all came up

local shader
local uViewportLoc
local uAtlasLoc
local atlasUniformSet = false

local quadVBO                -- 4 unit-quad corners
local instVBO                -- per-instance data
local vao

local vsx, vsy = spGetViewGeometry()

-- Instance accumulation buffer. Flat array of floats, `count` instances deep.
local buf   = {}
local count = 0
local batchHasIcon = false   -- does the pending batch contain an atlased icon?

-- Atlas state that Flush reads. DECLARED HERE, defined in the icon atlas
-- section further down. Flush is compiled before that section, and a Lua
-- closure resolves names when it is created: with the declaration only in the
-- later section, Flush's atlasName silently referred to a nil GLOBAL, the
-- atlas was never bound for any batch, and a sampler with nothing bound reads
-- opaque black in core profile - the black-squares bug, in both atlas
-- implementations, invisible to every test that never asserted the bind.
local atlasName    = nil
local atlasBroken  = false
local AtlasError, DestroyAtlas

-- Texture-cache rendering state, read by Push/Flush/Scissor below. Declared
-- here for the same reason as the atlas state above: those functions are
-- compiled first, and a later declaration would leave them reading globals.
local rttActive = false
local rttW, rttH   = 0, 0
local rttOX, rttOY = 0, 0
local cachePremultiplied = false

-- Current colour, mirrored to gl.Color so untouched immediate-mode call sites
-- (accent strips, icons, font colour) keep working unchanged.
local curR, curG, curB, curA = 1, 1, 1, 1

-- When non-nil, drawing calls append to this list instead of executing. See
-- SG.Record below.
local recording = nil
local replaying = false

local OP_SHAPE, OP_TEXTURE, OP_TEXRECT, OP_SCISSOR = 1, 2, 3, 4
local OP_FONT_BEGIN, OP_FONT_PRINT, OP_FONT_END, OP_FONT_COLOR = 5, 6, 7, 8
local OP_COLOR, OP_ICON = 9, 10

-- Blend mode used when the batch is submitted. Shapes are recorded now and
-- drawn later, so a widget that switches to additive blending has to tell the
-- module rather than just calling gl.Blending: by the time the batch flushes,
-- its gl.Blending call would long since have been undone.
local blendSrc, blendDst = nil, nil   -- resolved on first use; GL is not ready at load

-- Coordinate transform, for widgets that used to wrap their panel in
-- gl.PushMatrix / gl.Translate / gl.Scale. Those are real glTranslatef and
-- glScalef calls in Recoil (the engine even flags them as deprecated GL), and
-- the fixed-function matrix stack does not exist in core profile - nor would it
-- affect a custom shader if it did. So the transform is applied at record time
-- instead: position by offX/offY, and sizes by scale.
local offX, offY, scale = 0, 0, 1

-- Debug / instrumentation
local debugTint  = false
local debugStats = false
local statDraws, statInstances = 0, 0
local frameDraws, frameInstances = 0, 0
local overflowWarned = false
local unflushedWarned = false

local DEBUG_TINTS = {
	{1.00, 0.20, 0.20},
	{0.20, 1.00, 0.20},
	{0.30, 0.55, 1.00},
	{1.00, 0.90, 0.20},
	{1.00, 0.35, 0.95},
	{0.25, 0.95, 0.95},
}

--------------------------------------------------------------------------------
-- Shader source
--------------------------------------------------------------------------------

local vertexSource = [[
#version 330 core

// Per-vertex: unit quad corner. {0,0} {1,0} {0,1} {1,1} as a TRIANGLE_STRIP.
layout (location = 0) in vec2 aPos;

// Per-instance.
//   mode 0 (rounded rect) : aRect = x1,y1,x2,y2
//   mode 1 (line segment) : aRect = ax,ay,bx,by
//   mode 2 (accent strip) : aRect = x1,y1,x2,y2
//   mode 3 (atlased icon) : aRect = x1,y1,x2,y2, aUV = atlas sub-rect
layout (location = 1) in vec4 aRect;
// mode 0: x = corner radius, y = border width (0 = filled)
// mode 1: y = line width
// mode 2: x = end cap width as a fraction of strip width,
//         y = centre bar height as a fraction of strip height
// all modes: z = edge feather in px, w = mode
layout (location = 2) in vec4 aParams;
layout (location = 3) in vec4 aColor;
// mode 3 (atlased icon): u1, v1, u2, v2 within the atlas page
layout (location = 4) in vec4 aUV;

uniform vec2 uViewport;

out vec2 vPos;      // fragment position in screen pixels
out vec2 vA;        // rect/accent: centre      | line: endpoint A
out vec2 vB;        // rect/accent: half-extent | line: endpoint B
out vec4 vParams;
out vec4 vColor;
out vec4 vUV;

void main()
{
	int   mode    = int(aParams.w + 0.5);
	float feather = max(aParams.z, 0.5);
	vec2  p;

	if (mode == 1) {
		// ---- line segment (capsule) ------------------------------------
		vA = aRect.xy;
		vB = aRect.zw;

		vec2  d   = vB - vA;
		float len = length(d);
		vec2  dir = (len > 1e-6) ? (d / len) : vec2(1.0, 0.0);
		vec2  nrm = vec2(-dir.y, dir.x);

		float hw = aParams.y * 0.5 + feather + 1.0;

		// aPos.x walks A->B, aPos.y walks across. Both are extended by hw so
		// the round caps are not clipped.
		p = mix(vA, vB, aPos.x)
		  + dir * ((aPos.x * 2.0 - 1.0) * hw)
		  + nrm * ((aPos.y * 2.0 - 1.0) * hw);
	} else {
		// ---- axis-aligned box: rounded rect and accent strip -----------
		vec2 lo = min(aRect.xy, aRect.zw);
		vec2 hi = max(aRect.xy, aRect.zw);

		vA = (lo + hi) * 0.5;
		vB = (hi - lo) * 0.5;

		// Grow the quad so the antialiased edge has somewhere to live. Icons
		// must not be padded: the extra fringe would sample past the edge of
		// their atlas tile and pull in the neighbouring icon.
		float pad = (mode == 3) ? 0.0 : (feather + 1.0);
		p = mix(lo - vec2(pad), hi + vec2(pad), aPos);
	}

	vPos    = p;
	vParams = aParams;
	vColor  = aColor;
	vUV     = aUV;

	// DrawScreen is an ortho 0..vsx, 0..vsy projection.
	gl_Position = vec4((p / uViewport) * 2.0 - 1.0, 0.0, 1.0);
}
]]

local fragmentSource = [[
#version 330 core

in vec2 vPos;
in vec2 vA;
in vec2 vB;
in vec4 vParams;
in vec4 vColor;
in vec4 vUV;

out vec4 fragColor;

uniform sampler2D uAtlas;

// Signed distance to a rounded box centred on the origin.
// Negative inside, positive outside, in pixels.
float sdRoundBox(vec2 p, vec2 b, float r)
{
	vec2 q = abs(p) - b + vec2(r);
	return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

float sdBox(vec2 p, vec2 b)
{
	vec2 q = abs(p) - b;
	return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0)));
}

// Signed distance to a line segment a-b.
float sdSegment(vec2 p, vec2 a, vec2 b)
{
	vec2  pa = p - a;
	vec2  ba = b - a;
	float dd = max(dot(ba, ba), 1e-6);
	float h  = clamp(dot(pa, ba) / dd, 0.0, 1.0);
	return length(pa - ba * h);
}

void main()
{
	int   mode    = int(vParams.w + 0.5);
	float feather = max(vParams.z, 0.5);
	float d;

	if (mode == 1) {
		// ---- line segment ----------------------------------------------
		d = sdSegment(vPos, vA, vB) - vParams.y * 0.5;

	} else if (mode == 3) {
		// ---- atlased icon ----------------------------------------------
		// One instance per icon, sampling a sub-rect of the shared atlas.
		// This is what lets the whole build grid batch into a single draw
		// call: without it every icon was its own texture bind, and a bind
		// forces the batch to flush.
		vec2 t  = clamp((vPos - vA) / vB * 0.5 + 0.5, 0.0, 1.0);
		// The blit into the atlas puts v=0 at each cell's bottom edge - the
		// same orientation gl.TexRect uses on screen - so v is not flipped.
		vec2 uv = vec2(mix(vUV.x, vUV.z, t.x), mix(vUV.y, vUV.w, t.y));
		fragColor = texture(uAtlas, uv) * vColor;
		if (fragColor.a <= 0.0) discard;
		return;

	} else if (mode == 2) {
		// ---- accent strip ----------------------------------------------
		// Reproduces staticgui_accent.png analytically: a centre bar running
		// the full width at half height, plus a square end cap at each end at
		// full height. The texture was 512x16 white with binary alpha - a
		// union of three boxes, so min() of three box SDFs is exact, and
		// antialiased where the texture was not.
		vec2  p     = vPos - vA;
		float capW  = vParams.x * (vB.x * 2.0);   // cap width in pixels
		float barH  = vParams.y * vB.y;           // half-height of centre bar
		float capHW = capW * 0.5;

		float bar      = sdBox(p, vec2(vB.x, barH));
		float leftCap  = sdBox(p + vec2(vB.x - capHW, 0.0), vec2(capHW, vB.y));
		float rightCap = sdBox(p - vec2(vB.x - capHW, 0.0), vec2(capHW, vB.y));

		d = min(bar, min(leftCap, rightCap));

	} else {
		// ---- rounded rect ----------------------------------------------
		float radius = clamp(vParams.x, 0.0, min(vB.x, vB.y));
		d = sdRoundBox(vPos - vA, vB, radius);

		// borderWidth > 0 turns the fill into an outline.
		float bw = vParams.y;
		if (bw > 0.0) {
			vec2  innerHalf   = max(vB - vec2(bw), vec2(0.0));
			float innerRadius = clamp(radius - bw, 0.0, min(innerHalf.x, innerHalf.y));
			float di = sdRoundBox(vPos - vA, innerHalf, innerRadius);

			float outer = 1.0 - smoothstep(-feather, feather, d);
			float inner = smoothstep(-feather, feather, di);
			float a = outer * inner;
			if (a <= 0.0) discard;
			fragColor = vec4(vColor.rgb, vColor.a * a);
			return;
		}
	}

	float alpha = 1.0 - smoothstep(-feather, feather, d);
	if (alpha <= 0.0) discard;

	fragColor = vec4(vColor.rgb, vColor.a * alpha);
}
]]

--------------------------------------------------------------------------------
-- Setup / teardown
--------------------------------------------------------------------------------

local function Teardown()
	if vao      then vao:Delete()      ; vao      = nil end
	if instVBO  then instVBO:Delete()  ; instVBO  = nil end
	if quadVBO  then quadVBO:Delete()  ; quadVBO  = nil end
	if shader   then glDeleteShader(shader) ; shader = nil end
	ready = false
end

local function Setup()
	if not (gl.GetVBO and gl.GetVAO) then
		spEcho("[StaticGUI] gl.GetVBO/gl.GetVAO unavailable - falling back to legacy drawing")
		return false
	end

	shader = glCreateShader({
		vertex   = vertexSource,
		fragment = fragmentSource,
	})

	if not shader then
		spEcho("[StaticGUI] shader compile failed - falling back to legacy drawing")
		spEcho(glGetShaderLog())
		return false
	end

	uViewportLoc = glGetUniformLocation(shader, "uViewport")

	-- The atlas sampler is pointed at texture unit 0 on the first Flush, NOT
	-- here: widget:Initialize is not a Draw callin, and gl.UseShader outside
	-- one raises. Doing it here took the whole module down, which silently
	-- dropped every widget onto its legacy fallback path.
	uAtlasLoc = glGetUniformLocation(shader, "uAtlas")
	atlasUniformSet = false

	-- Unit quad, drawn as a TRIANGLE_STRIP: (0,0) (1,0) (0,1) (1,1)
	quadVBO = gl.GetVBO(GL.ARRAY_BUFFER, false)
	if not quadVBO then Teardown() ; return false end
	quadVBO:Define(4, {
		{ id = 0, name = "aPos", size = 2 },
	})
	quadVBO:Upload({
		0, 0,
		1, 0,
		0, 1,
		1, 1,
	})

	instVBO = gl.GetVBO(GL.ARRAY_BUFFER, true)
	if not instVBO then Teardown() ; return false end
	instVBO:Define(MAX_INSTANCES, {
		{ id = 1, name = "aRect",   size = 4 },
		{ id = 2, name = "aParams", size = 4 },
		{ id = 3, name = "aColor",  size = 4 },
		{ id = 4, name = "aUV",     size = 4 },
	})

	vao = gl.GetVAO()
	if not vao then Teardown() ; return false end
	vao:AttachVertexBuffer(quadVBO)
	vao:AttachInstanceBuffer(instVBO)

	ready = true
	return true
end

--------------------------------------------------------------------------------
-- Recording
--------------------------------------------------------------------------------

local function Push(x1, y1, x2, y2, radius, border, feather, mode, r, g, b, a, u1, v1, u2, v2)
	if recording then
		-- Capture post-transform, exactly as a display list captured the
		-- coordinates that were current when it was built.
		local sc, ox, oy = scale, offX, offY
		local rr = (mode == MODE_ACCENT) and radius or radius * sc
		local bw = (mode == MODE_ACCENT) and border or border * sc
		recording[#recording + 1] = {
			OP_SHAPE, x1 * sc + ox, y1 * sc + oy, x2 * sc + ox, y2 * sc + oy,
			rr, bw, feather, mode, r, g, b, a, u1, v1, u2, v2,
		}
		return
	end

	local pushScale, pushOffX, pushOffY = scale, offX, offY
	if rttActive then
		pushOffX, pushOffY = pushOffX - rttOX, pushOffY - rttOY
	end
	if replaying then
		-- Replayed ops already carry the transform that was current when they
		-- were recorded - but not the cache origin, which is a property of
		-- where the replay is happening, not of the recording.
		pushScale, pushOffX, pushOffY = 1, 0, 0
		if rttActive then
			pushOffX, pushOffY = -rttOX, -rttOY
		end
	end

	if count >= MAX_INSTANCES then
		if not overflowWarned then
			spEcho("[StaticGUI] instance buffer full (" .. MAX_INSTANCES ..
			       ") - raise MAX_INSTANCES in api_staticgui_shapes.lua")
			overflowWarned = true
		end
		return
	end

	if debugTint then
		local t = DEBUG_TINTS[(count % #DEBUG_TINTS) + 1]
		r, g, b = t[1], t[2], t[3]
		a = 0.85
	end

	local o = count * FLOATS_PER_INSTANCE

	buf[o + 1]  = x1 * pushScale + pushOffX
	buf[o + 2]  = y1 * pushScale + pushOffY
	buf[o + 3]  = x2 * pushScale + pushOffX
	buf[o + 4]  = y2 * pushScale + pushOffY

	-- Corner radius, border width and line width are all lengths, so they
	-- scale with the geometry. The accent strip's cap and bar values are
	-- fractions of the strip, so they must not.
	if mode == MODE_ACCENT then
		buf[o + 5]  = radius
		buf[o + 6]  = border
	else
		buf[o + 5]  = radius * pushScale
		buf[o + 6]  = border * pushScale
	end
	buf[o + 7]  = feather
	buf[o + 8]  = mode

	buf[o + 9]  = r
	buf[o + 10] = g
	buf[o + 11] = b
	buf[o + 12] = a

	if mode == MODE_ICON then
		batchHasIcon = true
	end

	buf[o + 13] = u1 or 0
	buf[o + 14] = v1 or 0
	buf[o + 15] = u2 or 0
	buf[o + 16] = v2 or 0

	count = count + 1
end

--------------------------------------------------------------------------------
-- Flush
--------------------------------------------------------------------------------

local function Flush()
	if count == 0 then return end

	if not ready then
		count = 0
		return
	end

	instVBO:Upload(buf, -1, 0, 1, count * FLOATS_PER_INSTANCE)

	-- The atlas is bound for the whole batch when it holds any icon, so icons
	-- cost no bind of their own. A batch with no icons must not touch texture
	-- state at all - widgets that draw their own textured quads rely on it
	-- being left alone.
	local useAtlas = batchHasIcon and atlasName
	if useAtlas then
		if gl.Texture(0, atlasName) == false then
			-- A sampler with nothing bound reads opaque black in core profile:
			-- exactly the black-squares symptom. Fail loudly and stop.
			AtlasError("bind failed at draw time", atlasName)
			spEcho("[StaticGUI] atlas texture will not bind - disabling the atlas")
			DestroyAtlas()
			atlasBroken = true
			useAtlas = false
			glTextureRaw(false)
		end
	else
		glTextureRaw(false)
	end
	glDepthTest(false)
	-- Inside a texture cache the accumulation must be straight-to-premultiplied:
	-- colour gets normal alpha blending, alpha gets true coverage (ONE, 1-a).
	-- This CANNOT be set once by TexCache, because this very function resets
	-- blend state on every call and the batch is drawn right here - which is
	-- how the first premultiplied-alpha fix ended up applying to nothing and
	-- cached panels stayed washed out.
	if rttActive and glBlendFuncSeparate then
		glBlendFuncSeparate(blendSrc or GL.SRC_ALPHA, blendDst or GL.ONE_MINUS_SRC_ALPHA,
		                    GL.ONE, GL.ONE_MINUS_SRC_ALPHA)
	else
		glBlending(blendSrc or GL.SRC_ALPHA, blendDst or GL.ONE_MINUS_SRC_ALPHA)
	end

	glUseShader(shader)
	if not atlasUniformSet and uAtlasLoc and gl.UniformInt then
		pcall(gl.UniformInt, uAtlasLoc, 0)
		atlasUniformSet = true
	end
	if rttActive then
		glUniform(uViewportLoc, rttW, rttH)
	else
		glUniform(uViewportLoc, vsx, vsy)
	end
	vao:DrawArrays(GL.TRIANGLE_STRIP, 4, 0, count)
	glUseShader(0)

	if useAtlas then
		gl.Texture(0, false)
	end

	glBlending(true)

	frameDraws     = frameDraws + 1
	frameInstances = frameInstances + count
	count = 0
	batchHasIcon = false
end

--------------------------------------------------------------------------------
-- Icon atlas
--
-- Unit build pictures are separate textures ("#123" for unitDefID 123). Drawing
-- one meant gl.Texture + gl.TexRect, and because a texture bind forces the
-- shape batch to flush, a 60 item build menu cost ~60 binds and ~60 draw calls
-- every frame.
--
-- This is a SELF-BUILT atlas: one gl.CreateTexture FBO target, and each icon is
-- blitted into a free grid cell with gl.RenderToTexture from inside a Draw
-- callin. The engine's gl.CreateTextureAtlas API is deliberately not used - it
-- reads textures back through glGetTexImage with format assumptions this module
-- cannot verify, it cannot be extended after finalizing (so a new icon forced a
-- full rebuild, and a rebuild loop is exactly how the build menu went black),
-- and its sampling semantics are outside this module's control. The FBO path is
-- plain Lua GL, incremental, and never rebuilds anything.
--
-- Until an icon is blitted it falls back to the old bind-and-blit, so nothing
-- is ever missing - it just is not batched yet.
--------------------------------------------------------------------------------

-- OFF by default until it has been seen working in a real game: turn on with
-- "/staticgui atlas on" and check the build menu. The previous, engine-API
-- implementation produced black icons in-game twice; this one shares none of
-- that code path, but it earns default-on by being verified, not by argument.
local atlasEnabled = false

local ATLAS_SIZE     = 2048
local ATLAS_CELL     = 128   -- grid cell, fits build pictures comfortably
local ATLAS_PAD      = 2     -- transparent border per cell against bleeding
local BLITS_PER_FRAME = 8    -- spread work to avoid a visible hitch

local ATLAS_COLS  = math.floor(ATLAS_SIZE / ATLAS_CELL)
local ATLAS_SLOTS = ATLAS_COLS * ATLAS_COLS

local atlasUV      = {}       -- texName -> { u1, v1, u2, v2 }  (v1 = bottom)
local atlasWanted  = {}       -- texName -> true, requested but not yet blitted
local atlasQueue   = {}       -- request order
local atlasPending = 0
local atlasUsed    = 0        -- grid cells taken
local atlasFailed  = {}       -- texName -> true, blit failed; never retry
local atlasBlits   = 0        -- total successful blits, for /staticgui atlas
local atlasErrors  = 0        -- reported failures; first few go to the console
local atlasDebug   = false    -- /staticgui atlasdebug: draw the raw atlas

AtlasError = function(what, err)
	atlasErrors = atlasErrors + 1
	if atlasErrors <= 4 then
		spEcho("[StaticGUI] atlas " .. what .. ": " .. tostring(err))
	end
end

local function AtlasSupported()
	return atlasEnabled and gl.CreateTexture and gl.RenderToTexture
end

DestroyAtlas = function()
	if atlasName then
		if gl.DeleteTextureFBO then
			pcall(gl.DeleteTextureFBO, atlasName)
		elseif gl.DeleteTexture then
			pcall(gl.DeleteTexture, atlasName)
		end
	end
	atlasName = nil
	atlasUV   = {}
	atlasUsed = 0
end

local function EnsureAtlasTexture()
	if atlasName then return true end
	local ok, name = pcall(gl.CreateTexture, ATLAS_SIZE, ATLAS_SIZE, {
		format     = GL.RGBA8,
		fbo        = true,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s     = GL.CLAMP_TO_EDGE,
		wrap_t     = GL.CLAMP_TO_EDGE,
	})
	if not ok or not name then
		AtlasError("CreateTexture failed", ok and "returned nil" or name)
		spEcho("[StaticGUI] could not create the icon atlas texture, using per-icon binds")
		atlasBroken = true
		return false
	end
	atlasName = name

	-- Start from known-transparent so cell padding really is empty. Blending
	-- must be OFF for this: under the alpha blending that Flush leaves active,
	-- writing (0,0,0,0) changes nothing at all and the texture would keep its
	-- undefined initial contents.
	local clr, cerr = pcall(gl.RenderToTexture, atlasName, function()
		gl.Blending(false)
		gl.Color(0, 0, 0, 0)
		gl.Rect(-1, -1, 1, 1)
		gl.Color(1, 1, 1, 1)
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	end)
	if not clr then AtlasError("clear failed", cerr) end
	return true
end

-- Blits one texture into the next free grid cell. Runs inside a Draw callin.
local function BlitIcon(texName)
	if atlasUsed >= ATLAS_SLOTS then
		-- Full. Everything already packed stays valid; latecomers just keep
		-- the fallback path. No rebuilds, so nothing already on screen breaks.
		atlasFailed[texName] = true
		return false
	end

	local slot = atlasUsed
	local col  = slot % ATLAS_COLS
	local row  = math.floor(slot / ATLAS_COLS)

	-- Pixel rect of the padded drawing area inside the cell.
	local px1 = col * ATLAS_CELL + ATLAS_PAD
	local py1 = row * ATLAS_CELL + ATLAS_PAD
	local px2 = (col + 1) * ATLAS_CELL - ATLAS_PAD
	local py2 = (row + 1) * ATLAS_CELL - ATLAS_PAD

	local ok, berr = pcall(gl.RenderToTexture, atlasName, function()
		-- Copy the source verbatim, alpha included: blending here would
		-- composite against whatever the cell held before, and if the build
		-- picture's own alpha is meaningful the written alpha could end up at
		-- zero - which the icon shader then discards, leaving invisible icons.
		gl.Blending(false)
		gl.Texture(texName)
		gl.Color(1, 1, 1, 1)
		-- NDC sub-rect of the cell. The FBO write is GL-convention (v=0 is the
		-- cell's bottom row), and the icon shader samples with an unflipped v,
		-- so write and read agree. (Raw gl.TexRect would NOT agree: its
		-- default texcoords assume image-convention textures.)
		gl.TexRect(px1 / ATLAS_SIZE * 2 - 1, py1 / ATLAS_SIZE * 2 - 1,
		           px2 / ATLAS_SIZE * 2 - 1, py2 / ATLAS_SIZE * 2 - 1)
		gl.Texture(false)
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	end)

	if not ok then
		AtlasError("blit of " .. tostring(texName) .. " failed", berr)
		atlasFailed[texName] = true
		return false
	end

	atlasUsed = atlasUsed + 1
	atlasBlits = atlasBlits + 1
	atlasUV[texName] = { px1 / ATLAS_SIZE, py1 / ATLAS_SIZE,
	                     px2 / ATLAS_SIZE, py2 / ATLAS_SIZE }
	return true
end

-- Called once per frame from the module's DrawScreen (a Draw callin, which
-- gl.RenderToTexture requires). Incremental: a few blits per frame, no
-- rebuild step, existing cells are never touched again.
local function MaintainAtlas()
	if atlasBroken or atlasPending == 0 then return end
	if not AtlasSupported() then return end
	if not EnsureAtlasTexture() then return end

	local done = 0
	while atlasPending > 0 and done < BLITS_PER_FRAME do
		local texName = table.remove(atlasQueue, 1)
		atlasPending = atlasPending - 1
		if texName and atlasWanted[texName] and not atlasUV[texName]
		   and not atlasFailed[texName] then
			BlitIcon(texName)
			done = done + 1
		end
		if texName then atlasWanted[texName] = nil end
	end
end

local function RequestAtlasSlot(texName)
	if atlasEnabled and not atlasBroken and not atlasFailed[texName]
	   and not atlasWanted[texName] and not atlasUV[texName] then
		atlasWanted[texName] = true
		atlasQueue[#atlasQueue + 1] = texName
		atlasPending = atlasPending + 1
	end
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

local SG = {}

-- Sets the colour used by subsequent shape calls, and mirrors it to gl.Color
-- so any immediate-mode call left in the widget (accent strips, icons, font
-- tinting) behaves exactly as before.
-- Accepts (r, g, b, a) or a {r, g, b, a} table.
function SG.Color(r, g, b, a)
	if type(r) == "table" then
		r, g, b, a = r[1], r[2], r[3], r[4]
	end
	curR, curG, curB, curA = r or 1, g or 1, b or 1, a or 1
	if recording then
		-- Shapes capture their own colour, but textured quads read gl.Color at
		-- draw time. Without recording this, a replayed icon picks up whatever
		-- colour happened to be set when the list was replayed.
		recording[#recording + 1] = { OP_COLOR, curR, curG, curB, curA }
		return
	end
	gl.Color(curR, curG, curB, curA)
end

-- Drop-in replacement for gl.Rect.
function SG.Rect(x1, y1, x2, y2)
	Push(x1, y1, x2, y2, 0, 0, DEFAULT_FEATHER, MODE_RECT, curR, curG, curB, curA)
end

-- Drop-in replacement for the per-widget `local function RectRound(px, py, sx, sy, cs)`.
-- Uses the colour last set via SG.Color.
function SG.RectRound(px, py, sx, sy, cs)
	Push(px, py, sx, sy, cs or 0, 0, DEFAULT_FEATHER, MODE_RECT, curR, curG, curB, curA)
end

-- Explicit-colour variant, for call sites that would rather not rely on
-- current-colour state.
function SG.RoundedRect(x1, y1, x2, y2, radius, color)
	local r, g, b, a = curR, curG, curB, curA
	if color then r, g, b, a = color[1], color[2], color[3], color[4] or 1 end
	Push(x1, y1, x2, y2, radius or 0, 0, DEFAULT_FEATHER, MODE_RECT, r, g, b, a)
end

-- Rounded outline. `width` is the border thickness in pixels, drawn inward.
function SG.RoundedOutline(x1, y1, x2, y2, radius, color, width)
	local r, g, b, a = curR, curG, curB, curA
	if color then r, g, b, a = color[1], color[2], color[3], color[4] or 1 end
	Push(x1, y1, x2, y2, radius or 0, mathMax(width or 1, 0.1),
	     DEFAULT_FEATHER, MODE_RECT, r, g, b, a)
end

-- A single line segment, drawn as a capsule so joins and caps are round.
function SG.LineSegment(x1, y1, x2, y2, width, color)
	local r, g, b, a = curR, curG, curB, curA
	if color then r, g, b, a = color[1], color[2], color[3], color[4] or 1 end
	Push(x1, y1, x2, y2, 0, mathMax(width or 1, 0.1),
	     DEFAULT_FEATHER, MODE_LINE, r, g, b, a)
end

-- The accent strip that sits under each panel's top edge. Replaces the
-- gl.Texture(accentImg) / gl.TexRect / gl.Texture(false) trio, which cost two
-- texture binds and a glBegin(GL_QUADS) per strip and, because a texture bind
-- forces the batch to flush, was the main reason a panel needed several draw
-- calls instead of one.
--
-- capFrac and barFrac default to the proportions of the original texture.
function SG.AccentStrip(x1, y1, x2, y2, color, capFrac, barFrac)
	local r, g, b, a = curR, curG, curB, curA
	if color then r, g, b, a = color[1], color[2], color[3], color[4] or 1 end
	Push(x1, y1, x2, y2,
	     capFrac or ACCENT_CAP_FRACTION,
	     barFrac or ACCENT_BAR_FRACTION,
	     DEFAULT_FEATHER, MODE_ACCENT, r, g, b, a)
end

-- Draws one icon with final (already transformed) coordinates. Shared by the
-- live path and by Replay, so a list recorded before the atlas existed starts
-- using it as soon as it is built - without the widget having to invalidate.
local function DrawIconResolved(x1, y1, x2, y2, texName, r, g, b, a)
	local uv = atlasUV[texName]
	if uv then
		Push(x1, y1, x2, y2, 0, 0, 0, MODE_ICON, r, g, b, a, uv[1], uv[2], uv[3], uv[4])
		return
	end

	RequestAtlasSlot(texName)

	-- Not packed yet: bind and blit, exactly as before.
	Flush()
	gl.Color(r, g, b, a)
	gl.Texture(texName)
	gl.TexRect(x1, y1, x2, y2)
	gl.Texture(false)
	gl.Color(curR, curG, curB, curA)
end

-- Draws a unit icon (or any texture) as part of the shared batch.
--
-- If the texture is already packed into the atlas this is a single instance and
-- costs no texture bind at all. If it is not, the icon requests a place in the
-- atlas and falls back to bind-and-blit for now - correct immediately, batched
-- within a second or so.
--
-- Replaces the DrawIcon pattern of glColor / glTexture / glTexRect / glTexture.
function SG.Icon(x1, y1, x2, y2, texName, color)
	local r, g, b, a = curR, curG, curB, curA
	if color then r, g, b, a = color[1], color[2], color[3], color[4] or 1 end

	local sc, ox, oy = scale, offX, offY
	local fx1, fy1 = x1 * sc + ox, y1 * sc + oy
	local fx2, fy2 = x2 * sc + ox, y2 * sc + oy

	if recording then
		-- Store the texture name, not the UVs. The atlas may not exist yet, and
		-- a list recorded now must pick it up later without being re-recorded.
		recording[#recording + 1] = { OP_ICON, fx1, fy1, fx2, fy2, texName, r, g, b, a }
		RequestAtlasSlot(texName)
		return
	end

	DrawIconResolved(fx1, fy1, fx2, fy2, texName, r, g, b, a)
end

function SG.AtlasStats()
	local packed = 0
	for _ in pairs(atlasUV) do packed = packed + 1 end
	return packed, atlasPending, atlasBroken
end

-- Polyline from a flat coordinate array {x1, y1, x2, y2, ...}.
-- Replaces gl.BeginEnd(GL.LINE_STRIP, ...) + gl.LineWidth, which is important
-- beyond performance: line widths above 1.0 are not required to be supported
-- in OpenGL core profile and are commonly clamped to 1.0 on macOS.
function SG.LineStrip(points, width, color)
	local n = #points
	if n < 4 then return end

	local r, g, b, a = curR, curG, curB, curA
	if color then r, g, b, a = color[1], color[2], color[3], color[4] or 1 end

	local w = mathMax(width or 1, 0.1)
	for i = 1, n - 3, 2 do
		Push(points[i], points[i + 1], points[i + 2], points[i + 3],
		     0, w, DEFAULT_FEATHER, MODE_LINE, r, g, b, a)
	end
end

-- Replaces a gl.PushMatrix / gl.Translate(dx, dy, 0) / gl.Scale(s, s, 1) block
-- for shape drawing. Shapes recorded after this are placed at
-- (x * s + dx, y * s + dy) with their radii and widths scaled to match.
--
-- Text and any remaining textured blits are NOT affected: the engine's font
-- renderer and gl.TexRect know nothing about this. Those call sites have to
-- apply the same transform themselves.
function SG.SetTransform(dx, dy, s)
	offX, offY, scale = dx or 0, dy or 0, s or 1
end

-- Translation only, for panels that move but do not scale.
function SG.SetOffset(dx, dy)
	offX, offY, scale = dx or 0, dy or 0, 1
end

function SG.ClearOffset()
	offX, offY, scale = 0, 0, 1
end

SG.ClearTransform = SG.ClearOffset

function SG.Flush()
	Flush()
end

-- Switches the blend mode used for subsequent shapes. Flushes first, so what
-- was already recorded is drawn under the old mode. Mirrors the mode to
-- gl.Blending as well, so any immediate-mode drawing between here and the next
-- SetBlend behaves the same as it did before.
function SG.SetBlend(src, dst)
	Flush()
	blendSrc, blendDst = src, dst
	glBlending(src, dst)
end

function SG.ResetBlend()
	Flush()
	blendSrc, blendDst = nil, nil
	glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
end

--------------------------------------------------------------------------------
-- Ordering-safe wrappers.
--
-- Because shapes are batched, anything drawn by another code path between two
-- shape calls has to force a flush first or it will end up underneath them.
-- These wrappers do that automatically so call sites do not have to.
--------------------------------------------------------------------------------

function SG.Texture(tex)
	if recording then
		recording[#recording + 1] = { OP_TEXTURE, tex }
		return
	end
	Flush()
	gl.Texture(tex)
end

function SG.TexRect(x1, y1, x2, y2, ...)
	if recording then
		recording[#recording + 1] = { OP_TEXRECT,
			x1 * scale + offX, y1 * scale + offY,
			x2 * scale + offX, y2 * scale + offY }
		return
	end
	Flush()
	gl.TexRect(x1 * scale + offX, y1 * scale + offY,
	           x2 * scale + offX, y2 * scale + offY, ...)
end

function SG.Scissor(a, b, c, d)
	if recording then
		recording[#recording + 1] = { OP_SCISSOR, a, b, c, d }
		return
	end
	Flush()
	if a == false then
		gl.Scissor(false)
	elseif rttActive then
		gl.Scissor(a - rttOX, b - rttOY, c, d)
	else
		gl.Scissor(a, b, c, d)
	end
end

-- Wraps a font handle so shapes and text keep the z-order they had under
-- immediate mode.
--
-- The engine's font renderer accumulates into its own RenderBuffer and does
-- not draw anything until font:End(). Under immediate mode a gl.Rect issued
-- between Begin and End hit the framebuffer straight away, so it ended up
-- UNDER the text. Batching breaks that: without a flush at End, those shapes
-- stay pending until the next Begin and paint over the text instead.
--
-- So both ends flush. Begin drains anything recorded before the block; End
-- drains anything recorded inside it, before the real End() emits the glyphs.
-- Everything else forwards straight through, so existing font:Print /
-- font:SetTextColor / font:GetTextWidth call sites are untouched.
function SG.WrapFont(font)
	if not font then return nil end

	-- Tracks whether we are inside a Begin/End block. A bare font:Print outside
	-- one draws immediately rather than queueing, so the batch has to be
	-- flushed before it or the shapes recorded so far land on top of the text.
	local inBlock = false

	local proxy = {
		__rawfont = font,
		Begin = function(self, ...)
			if recording then
				recording[#recording + 1] = { OP_FONT_BEGIN, font }
				return
			end
			Flush()
			inBlock = true
			if rttActive then
				-- Flush just applied the separate premultiplied blend funcs;
				-- true = userDefinedBlending stops the font from replacing
				-- them with plain alpha during glyph submission, which wrote
				-- alpha-squared at glyph edges and made cached text look
				-- slightly transparent.
				return font:Begin(true)
			end
			return font:Begin(...)
		end,
		End = function(self, ...)
			if recording then
				recording[#recording + 1] = { OP_FONT_END, font }
				return
			end
			Flush()
			inBlock = false
			return font:End(...)
		end,
		-- Recording a Print captures the already-fitted string and size, which
		-- is the point: the caller's text measurement and ellipsis trimming
		-- happen once at record time rather than every frame.
		Print = function(self, text, x, y, size, opts)
			if recording then
				recording[#recording + 1] = { OP_FONT_PRINT, font, text, x, y, size, opts }
				return
			end
			if not inBlock then
				-- A bare Print draws immediately through its own implicit
				-- begin/end; inside a cache, wrap it so the blend state is
				-- ours (see Begin above).
				if rttActive then
					Flush()
					font:Begin(true)
					font:Print(text, x, y, size, opts)
					return font:End()
				end
				Flush()
			end
			return font:Print(text, x, y, size, opts)
		end,
		SetTextColor = function(self, r, g, b, a)
			if recording then
				recording[#recording + 1] = { OP_FONT_COLOR, font, r, g, b, a }
				return
			end
			return font:SetTextColor(r, g, b, a)
		end,
	}

	setmetatable(proxy, {
		__index = function(_, key)
			local v = font[key]
			if type(v) == "function" then
				local fn = function(_, ...) return v(font, ...) end
				rawset(proxy, key, fn)
				return fn
			end
			return v
		end,
	})

	return proxy
end

-- gl.DeleteFont needs the real handle, not the proxy.
function SG.DeleteFont(font)
	if not font then return end
	gl.DeleteFont(font.__rawfont or font)
end

--------------------------------------------------------------------------------
-- Texture caches
--
-- The next step past SG.Record. A recorded list still replays in Lua - the
-- Build/Order Menu's ~700 ops and ~200 font prints per frame kept it above 20%
-- of LuaUI time even fully cached. A texture cache renders the whole layer
-- into an FBO texture once, on the widget's own dirty flag, and each frame
-- costs a single textured quad: no iteration, no text, no allocation.
--
--     if staticDirty then
--         myCache = SG.TexCache(myCache, x1, y1, x2, y2, DrawEverything)
--         staticDirty = false
--     end
--     SG.DrawCache(myCache, x1, y1)
--
-- Inside the cached function everything works as on screen: batched shapes,
-- recorded lists, icons, text (the matrix stack maps engine font output into
-- the texture) and scissors, all in ordinary screen coordinates. TexCache must
-- be called from a Draw callin - gl.RenderToTexture requires one - which is
-- why it belongs behind a dirty flag in DrawScreen, not in event handlers.
--------------------------------------------------------------------------------

local function FreeCacheTexture(cache)
	if cache and cache.tex then
		if gl.DeleteTextureFBO then
			pcall(gl.DeleteTextureFBO, cache.tex)
		elseif gl.DeleteTexture then
			pcall(gl.DeleteTexture, cache.tex)
		end
		cache.tex = nil
	end
end

function SG.FreeCache(cache)
	FreeCacheTexture(cache)
end

function SG.TexCache(cache, x1, y1, x2, y2, fn, ...)
	cache = cache or {}
	-- Snap to the pixel grid. A cache rendered or blitted at a fractional
	-- origin is sampled between texels by the LINEAR filter, which smears
	-- every glyph edge: text looks blurry AND slightly transparent. Snapped,
	-- LINEAR sampling is texel-exact and the blit is a 1:1 copy.
	x1, y1 = math.floor(x1), math.floor(y1)
	local w = math.ceil(x2) - x1
	local h = math.ceil(y2) - y1
	if w <= 0 or h <= 0 then return cache end
	cache.ox, cache.oy = x1, y1

	if cache.tex and (cache.w ~= w or cache.h ~= h) then
		FreeCacheTexture(cache)
	end
	if not cache.tex then
		-- NEAREST, deliberately. A cache is only ever blitted at native size,
		-- where NEAREST and LINEAR are identical when the mapping is exactly
		-- 1:1 - and when anything in the driver or texcoord path is off by a
		-- sub-texel, LINEAR smears every glyph while NEAREST still maps each
		-- screen pixel to exactly one texel. In-game comparison against the
		-- legacy direct-draw path showed cached small text softer; this makes
		-- the cache bit-identical to what the font rasterized.
		local ok, name = pcall(gl.CreateTexture, w, h, {
			format     = GL.RGBA8,
			fbo        = true,
			min_filter = GL.NEAREST,
			mag_filter = GL.NEAREST,
			wrap_s     = GL.CLAMP_TO_EDGE,
			wrap_t     = GL.CLAMP_TO_EDGE,
		})
		if not ok or not name then
			spEcho("[StaticGUI] TexCache: could not create a " .. w .. "x" .. h
			       .. " texture: " .. tostring(name))
			return cache
		end
		cache.tex, cache.w, cache.h = name, w, h
	end

	-- Anything pending belongs to the screen, not to this cache.
	Flush()

	rttActive, rttW, rttH, rttOX, rttOY = true, w, h, x1, y1
	local args = { ... }
	local ok, err = pcall(gl.RenderToTexture, cache.tex, function()
		-- Verbatim clear: under alpha blending a (0,0,0,0) fill is a no-op.
		gl.Blending(false)
		gl.Color(0, 0, 0, 0)
		gl.Rect(-1, -1, 1, 1)

		-- Premultiplied-alpha accumulation for anything drawn before the first
		-- Flush (engine text, raw texture blits). Flush re-applies the same
		-- separate functions for every shape batch - see the comment there.
		if gl.BlendFuncSeparate then
			gl.BlendFuncSeparate(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA,
			                     GL.ONE,       GL.ONE_MINUS_SRC_ALPHA)
		else
			gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		end
		gl.Color(1, 1, 1, 1)

		-- Map pixel coordinates into the texture for everything that does NOT
		-- go through the shape batch: engine text and raw textured quads.
		-- Batched shapes use the rtt viewport uniform instead.
		gl.PushMatrix()
		gl.Translate(-1, -1, 0)
		gl.Scale(2 / w, 2 / h, 1)
		gl.Translate(-x1, -y1, 0)

		fn(unpack(args))
		Flush()   -- the recorded shapes land inside the texture

		gl.PopMatrix()
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	end)
	rttActive = false
	cachePremultiplied = (glBlendFuncSeparate ~= nil)

	if not ok then
		spEcho("[StaticGUI] TexCache render failed: " .. tostring(err))
		FreeCacheTexture(cache)
	end
	return cache
end

-- Draws a cache built by TexCache at (x1, y1): one bind and one quad.
function SG.DrawCache(cache, x1, y1)
	if not (cache and cache.tex) then return false end
	-- Same snapping as TexCache: a fractional destination un-does the
	-- texel-exact render.
	x1, y1 = math.floor(x1), math.floor(y1)
	Flush()
	-- The cache holds premultiplied colour (see TexCache), so it composites
	-- with (ONE, 1-srcA): applying source alpha again here is exactly the
	-- double-transparency bug.
	if cachePremultiplied then
		gl.Blending(GL.ONE, GL.ONE_MINUS_SRC_ALPHA)
	end
	gl.Color(1, 1, 1, 1)
	gl.Texture(cache.tex)
	-- The sixth argument flips the t coordinates. gl.TexRect's DEFAULT puts
	-- t=1 at y1: the engine compensates for image files being stored top row
	-- first ("Spring's textures get loaded with a vertical flip" - engine
	-- source). An FBO texture is GL-convention - row 0 is the BOTTOM - so the
	-- default mapping draws a cache mirrored; the flip restores it.
	gl.TexRect(x1, y1, x1 + cache.w, y1 + cache.h, false, true)
	gl.Texture(false)
	if cachePremultiplied then
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	end
	return true
end

--------------------------------------------------------------------------------
-- Recorded lists
--
-- A portable replacement for gl.CreateList / gl.CallList.
--
-- The display lists these replace were not only caching GL commands. Because
-- the widget's layout walk, table building and text fitting all lived inside
-- the gl.CreateList(function() ... end) closure, the list was caching that Lua
-- work too, and it only ran when the widget flagged itself dirty. Rebuilding
-- everything per frame instead put the Static Build/Order Menu at 30% of total
-- LuaUI time and 13 MB/s of allocation.
--
-- Record() captures shapes, texture binds, textured quads, scissor changes and
-- text - including the *already fitted* strings and sizes - into a plain Lua
-- array. Replay() walks that array and allocates nothing.
--
-- Usage mirrors the display list it replaces:
--
--     myList = SG.NewList()
--     ...
--     SG.Record(myList, function() DrawEverything() end)   -- when dirty
--     SG.Replay(myList)                                    -- every frame
--------------------------------------------------------------------------------

function SG.NewList()
	return {}
end

-- Clears `list` and records everything `fn` draws into it.
function SG.Record(list, fn, ...)
	if recording then
		spEcho("[StaticGUI] SG.Record called while already recording - ignoring")
		return list
	end

	-- Anything pending belongs to the frame, not to this list.
	Flush()

	for i = #list, 1, -1 do
		list[i] = nil
	end

	recording = list
	local ok, err = pcall(fn, ...)
	recording = nil

	if not ok then
		spEcho("[StaticGUI] error while recording a list: " .. tostring(err))
		for i = #list, 1, -1 do
			list[i] = nil
		end
	end
	return list
end

function SG.Replay(list)
	if not list then return end

	local savedR, savedG, savedB, savedA = curR, curG, curB, curA
	replaying = true

	-- Same rule as the live path: a Print outside a Begin/End block draws
	-- immediately, so the batch has to go down first or the shapes recorded
	-- before it land on top of the text.
	local inFontBlock = false

	for i = 1, #list do
		local op = list[i]
		local k  = op[1]

		if k == OP_SHAPE then
			Push(op[2], op[3], op[4], op[5], op[6], op[7], op[8], op[9],
			     op[10], op[11], op[12], op[13], op[14], op[15], op[16], op[17])

		elseif k == OP_TEXTURE then
			Flush()
			gl.Texture(op[2])

		elseif k == OP_TEXRECT then
			Flush()
			gl.TexRect(op[2], op[3], op[4], op[5])

		elseif k == OP_SCISSOR then
			Flush()
			if op[2] == false then
				gl.Scissor(false)
			else
				gl.Scissor(op[2], op[3], op[4], op[5])
			end

		elseif k == OP_FONT_BEGIN then
			Flush()
			inFontBlock = true
			if rttActive then op[2]:Begin(true) else op[2]:Begin() end

		elseif k == OP_FONT_PRINT then
			if not inFontBlock then
				Flush()
			end
			op[2]:Print(op[3], op[4], op[5], op[6], op[7])

		elseif k == OP_FONT_END then
			Flush()
			inFontBlock = false
			op[2]:End()

		elseif k == OP_FONT_COLOR then
			op[2]:SetTextColor(op[3], op[4], op[5], op[6])

		elseif k == OP_ICON then
			DrawIconResolved(op[2], op[3], op[4], op[5], op[6], op[7], op[8], op[9], op[10])

		elseif k == OP_COLOR then
			curR, curG, curB, curA = op[2], op[3], op[4], op[5]
			gl.Color(curR, curG, curB, curA)
		end
	end
	replaying = false

	curR, curG, curB, curA = savedR, savedG, savedB, savedA
	gl.Color(curR, curG, curB, curA)
end

function SG.ListSize(list)
	return list and #list or 0
end

--------------------------------------------------------------------------------
-- Debug
--------------------------------------------------------------------------------

-- Cycles every instance through a palette of flat colours so each shape is
-- individually visible, and prints per-frame draw call / instance counts.
-- This is the direct answer to "translucent grey boxes are impossible to
-- debug" - with tint on, every rect is a distinct solid colour.
function SG.SetDebug(tint, stats)
	debugTint  = tint and true or false
	debugStats = stats and true or false
end

function SG.GetStats()
	return statDraws, statInstances
end

function SG.IsReady()
	return ready
end

--------------------------------------------------------------------------------
-- Widget callins
--------------------------------------------------------------------------------

function widget:Initialize()
	if not Setup() then
		-- Leave WG.StaticGUI nil. Consumer widgets are written to fall back to
		-- their own legacy drawing when it is absent, so a driver that cannot
		-- compile the shader degrades to the old behaviour rather than to a
		-- blank screen.
		widgetHandler:RemoveWidget()
		return
	end

	vsx, vsy = spGetViewGeometry()
	WG.StaticGUI = SG
end

function widget:Shutdown()
	DestroyAtlas()
	Teardown()
	if WG.StaticGUI == SG then
		WG.StaticGUI = nil
	end
end

function widget:ViewResize(nx, ny)
	vsx, vsy = nx or spGetViewGeometry(), ny
	if not ny then vsx, vsy = spGetViewGeometry() end
end

-- Runs at layer -100000, so this is the first DrawScreen of the frame. Anything
-- still pending here was recorded last frame and never flushed, which means a
-- consumer widget is missing its SG.Flush(). Drop it and say so once.
function widget:DrawScreen()
	if count > 0 then
		if not unflushedWarned then
			spEcho("[StaticGUI] " .. count .. " unflushed instances carried across a frame " ..
			       "- a consumer widget is missing SG.Flush() at the end of DrawScreen")
			unflushedWarned = true
		end
		count = 0
	end

	if debugStats and (frameDraws > 0) then
		spEcho(string.format("[StaticGUI] %d draw calls, %d instances", frameDraws, frameInstances))
	end

	-- gl.RenderToTexture does real GL work, so blits can only run from inside a
	-- Draw callin. This is one.
	MaintainAtlas()

	-- Diagnostic overlay: the raw atlas texture, drawn with plain immediate
	-- mode so it does not depend on the icon shader path at all. If icons are
	-- broken on screen, this view says whether the fault is in the blits
	-- (cells wrong here too) or in the sampling (cells fine here).
	if atlasDebug and atlasName then
		local size = math.min(vsy - 80, 768)
		gl.Color(1, 0, 1, 1)
		gl.Rect(36, 36, 44 + size, 44 + size)   -- magenta frame
		gl.Color(1, 1, 1, 1)
		gl.Texture(atlasName)
		gl.TexRect(40, 40, 40 + size, 40 + size)
		gl.Texture(false)
	end

	statDraws, statInstances = frameDraws, frameInstances
	frameDraws, frameInstances = 0, 0
end

--------------------------------------------------------------------------------
-- Console hooks
--------------------------------------------------------------------------------

function widget:TextCommand(command)
	if command == "staticgui debug" then
		debugTint = not debugTint
		spEcho("[StaticGUI] debug tint " .. (debugTint and "on" or "off"))
		return true
	elseif command == "staticgui atlasdebug" then
		atlasDebug = not atlasDebug
		spEcho("[StaticGUI] atlas debug view " .. (atlasDebug and "on" or "off"))
		return true
	elseif command == "staticgui atlas" or command == "staticgui atlas on"
	    or command == "staticgui atlas off" then
		if command == "staticgui atlas on" then
			atlasEnabled = true
			atlasBroken  = false
			atlasFailed  = {}
			spEcho("[StaticGUI] icon atlas enabled")
		elseif command == "staticgui atlas off" then
			atlasEnabled = false
			DestroyAtlas()
			atlasWanted  = {}
			atlasQueue   = {}
			atlasPending = 0
			spEcho("[StaticGUI] icon atlas disabled, using per-icon binds")
		end
		local packed, pending, broken = SG.AtlasStats()
		spEcho(string.format(
			"[StaticGUI] atlas: %s, %d packed, %d pending, %d/%d cells, %d error(s)%s",
			atlasEnabled and "on" or "off", packed, pending, atlasUsed, ATLAS_SLOTS,
			atlasErrors, broken and ", GIVEN UP" or ""))
		return true
	elseif command == "staticgui stats" then
		debugStats = not debugStats
		spEcho("[StaticGUI] draw stats " .. (debugStats and "on" or "off"))
		return true
	end
	return false
end
