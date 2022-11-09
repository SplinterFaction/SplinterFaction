local wiName = "Outline (deferred)"
function widget:GetInfo()
	return {
		name      = wiName,
		desc      = "Displays small outline around units based on deferred g-buffer",
		author    = "ivand",
		date      = "2019",
		license   = "GNU GPL, v2 or later",
		layer     = math.huge,
		enabled   = true  --  loaded by default?
	}
end

-----------------------------------------------------------------
-- Accel
-----------------------------------------------------------------
local glMatrixMode = gl.MatrixMode
local glPushMatrix = gl.PushMatrix
local glLoadIdentity = gl.LoadIdentity
local glPopMatrix = gl.PopMatrix
local glDepthTest = gl.DepthTest
local glDepthMask = gl.DepthMask
local glBlending = gl.Blending
local glBlendFunc = gl.BlendFunc
local glTexture = gl.Texture
local glActiveFBO = gl.ActiveFBO
local glCallList = gl.CallList

local GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA = GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA
local GL_MODELVIEW, GL_PROJECTION = GL.MODELVIEW, GL.PROJECTION

-----------------------------------------------------------------
-- Constants
-----------------------------------------------------------------

local GL_COLOR_ATTACHMENT0_EXT = 0x8CE0

-----------------------------------------------------------------
-- Configuration Constants
-----------------------------------------------------------------

local MIN_FPS = 15
local MIN_FPS_DELTA = 10
local AVG_FPS_ELASTICITY = 0.15
local AVG_FPS_ELASTICITY_INV = 1.0 - AVG_FPS_ELASTICITY

local BLUR_HALF_KERNEL_SIZE = 4 -- (BLUR_HALF_KERNEL_SIZE + BLUR_HALF_KERNEL_SIZE + 1) samples are used to perform the blur.
local BLUR_PASSES = 1 -- number of blur passes
local BLUR_SIGMA = 3 -- Gaussian sigma of a single blur pass, other factors like BLUR_HALF_KERNEL_SIZE, BLUR_PASSES and DOWNSAMPLE affect the end result gaussian shape too

local OUTLINE_COLOR = {0.0, 0.0, 0.0, 1.0}
local OUTLINE_STRENGTH = 2.0 -- make it much smaller for softer edges

local USE_MATERIAL_INDICES = true -- for future material indices based SSAO evaluation


-----------------------------------------------------------------
-- File path Constants
-----------------------------------------------------------------

local shadersDir = "LuaUI/Widgets_Evo/Shaders/"
local luaShaderDir = "LuaUI/Widgets_Evo/Include/"

-----------------------------------------------------------------
-- Global Variables
-----------------------------------------------------------------

local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")

local vsx, vsy, vpx, vpy

local screenQuadList
local screenWideList


local shapeTex
local blurTexes = {}

local shapeFBO
local blurFBOs = {}

local shapeShader
local gaussianBlurShader
local applicationShader

local show = true

-----------------------------------------------------------------
-- Local Functions
-----------------------------------------------------------------

local function G(x, sigma)
	return ( 1 / ( math.sqrt(2 * math.pi) * sigma ) ) * math.exp( -(x * x) / (2 * sigma * sigma) )
end

local function GetGaussDiscreteWeightsOffsets(sigma, kernelHalfSize, valMult)
	local weights = {}
	local offsets = {}

	weights[1] = G(0, sigma)
	local sum = weights[1]

	for i = 1, kernelHalfSize - 1 do
		weights[i + 1] = G(i, sigma)
		sum = sum + 2.0 * weights[i + 1]
	end

	for i = 0, kernelHalfSize - 1 do --normalize so the weights sum up to valMult
		weights[i + 1] = weights[i + 1] / sum * valMult
		offsets[i + 1] = i
	end
	return weights, offsets
end

--see http://rastergrid.com/blog/2010/09/efficient-gaussian-blur-with-linear-sampling/
local function GetGaussLinearWeightsOffsets(sigma, kernelHalfSize, valMult)
	local dWeights, dOffsets = GetGaussDiscreteWeightsOffsets(sigma, kernelHalfSize, 1.0)

	local weights = {dWeights[1]}
	local offsets = {dOffsets[1]}

	for i = 1, (kernelHalfSize - 1) / 2 do
		local newWeight = dWeights[2 * i] + dWeights[2 * i + 1]
		weights[i + 1] = newWeight * valMult
		offsets[i + 1] = (dOffsets[2 * i] * dWeights[2 * i] + dOffsets[2 * i + 1] * dWeights[2 * i + 1]) / newWeight
	end
	return weights, offsets
end

-----------------------------------------------------------------
-- Widget Functions
-----------------------------------------------------------------

function widget:ViewResize()
	widget:Shutdown()
	widget:Initialize()
end

function widget:Initialize()
	local canContinue = LuaShader.isDeferredShadingEnabled and LuaShader.GetAdvShadingActive()
	if not canContinue then
		Spring.Echo(string.format("Error in [%s] widget: %s", wiName, "Deferred shading is not enabled or advanced shading is not active"))
	end

	local configName = "AllowDrawModelPostDeferredEvents"
	if Spring.GetConfigInt(configName, 0) == 0 then
		Spring.Echo(string.format("Warning in [%s] widget: %s", wiName, "AllowDrawModelPostDeferredEvents is not enabled, enabling it now"))
		Spring.SetConfigInt(configName, 1) --required to enable receiving DrawUnitsPostDeferred/DrawFeaturesPostDeferred
	end

	vsx, vsy, vpx, vpy = Spring.GetViewGeometry()

	local commonTexOpts = {
		target = GL_TEXTURE_2D,
		border = false,
		min_filter = GL.NEAREST,
		mag_filter = GL.LINEAR,

		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
	}

	shapeTex = gl.CreateTexture(vsx, vsy, commonTexOpts)

	for i = 1, 2 do
		blurTexes[i] = gl.CreateTexture(vsx, vsy, commonTexOpts)
	end



	shapeFBO = gl.CreateFBO({
		color0 = shapeTex,
		drawbuffers = {GL_COLOR_ATTACHMENT0_EXT},
	})

	if not gl.IsValidFBO(shapeFBO) then
		Spring.Echo(string.format("Error in [%s] widget: %s", wiName, "Invalid shapeFBO"))
	end

	for i = 1, 2 do
		blurFBOs[i] = gl.CreateFBO({
			color0 = blurTexes[i],
			drawbuffers = {GL_COLOR_ATTACHMENT0_EXT},
		})
		if not gl.IsValidFBO(blurFBOs[i]) then
			Spring.Echo(string.format("Error in [%s] widget: %s", wiName, string.format("Invalid blurFBOs[%d]", i)))
		end
	end


	local identityShaderVert = VFS.LoadFile(shadersDir.."identity.vert.glsl")

	local shapeShaderFrag = VFS.LoadFile(shadersDir.."outlineShape.frag.glsl")

	shapeShaderFrag = shapeShaderFrag:gsub("###USE_MATERIAL_INDICES###", tostring((USE_MATERIAL_INDICES and 1) or 0))

	shapeShader = LuaShader({
		vertex = identityShaderVert,
		fragment = shapeShaderFrag,
		uniformInt = {
			-- be consistent with gfx_deferred_rendering.lua
			--	glTexture(1, "$model_gbuffer_zvaltex")
			modelDepthTex = 1,
			modelMiscTex = 2,
			mapDepthTex = 3,
		},
		uniformFloat = {
			outlineColor = OUTLINE_COLOR,
		},
	}, wiName..": Shape drawing")
	shapeShader:Initialize()

	local gaussianBlurFrag = VFS.LoadFile(shadersDir.."gaussianBlur.frag.glsl")

	gaussianBlurFrag = gaussianBlurFrag:gsub("###BLUR_HALF_KERNEL_SIZE###", tostring(BLUR_HALF_KERNEL_SIZE))

	gaussianBlurShader = LuaShader({
		vertex = identityShaderVert,
		fragment = gaussianBlurFrag,
		uniformInt = {
			tex = 0,
		},
		uniformFloat = {
			viewPortSize = {vsx, vsy},
		},
	}, wiName..": Gaussian Blur")
	gaussianBlurShader:Initialize()

	local gaussWeights, gaussOffsets = GetGaussLinearWeightsOffsets(BLUR_SIGMA, BLUR_HALF_KERNEL_SIZE, OUTLINE_STRENGTH)

	gaussianBlurShader:ActivateWith( function()
		gaussianBlurShader:SetUniformFloatArrayAlways("weights", gaussWeights)
		gaussianBlurShader:SetUniformFloatArrayAlways("offsets", gaussOffsets)
	end)

	local applicationFrag = VFS.LoadFile(shadersDir.."outlineApplication.frag.glsl")

	applicationShader = LuaShader({
		vertex = identityShaderVert,
		fragment = applicationFrag,
		uniformInt = {
			tex = 0,
			modelDepthTex = 1,
		},
		uniformFloat = {
			viewPortSize = {vsx, vsy},
		},
	}, wiName..": Outline Application")
	applicationShader:Initialize()

	screenQuadList = gl.CreateList(gl.TexRect, -1, -1, 1, 1)
	screenWideList = gl.CreateList(gl.TexRect, -1, -1, 1, 1, false, true)
end

function widget:Shutdown()
	if screenQuadList then
		gl.DeleteList(screenQuadList)
	end

	if screenWideList then
		gl.DeleteList(screenWideList)
	end

	gl.DeleteTexture(shapeTex)

	for i = 1, 2 do
		gl.DeleteTexture(blurTexes[i])
	end

	gl.DeleteFBO(shapeFBO)
	for i = 1, 2 do
		gl.DeleteFBO(blurFBOs[i])
	end

	shapeShader:Finalize()
	gaussianBlurShader:Finalize()
	applicationShader:Finalize()
end

local function PrepareOutline()
	glDepthTest(false)
	glDepthMask(false)

	glActiveFBO(shapeFBO, function()
		shapeShader:ActivateWith( function ()
			glTexture(1, "$model_gbuffer_zvaltex")
			if USE_MATERIAL_INDICES then
				glTexture(2, "$model_gbuffer_misctex")
			end
			glTexture(3, "$map_gbuffer_zvaltex")

			glCallList(screenQuadList) -- gl.TexRect(-1, -1, 1, 1)

			--glTexture(1, false) --will reuse later
			if USE_MATERIAL_INDICES then
				glTexture(2, false)
			end
			glTexture(3, false)
		end)
	end)

	glTexture(0, shapeTex)

	for i = 1, BLUR_PASSES do
		gaussianBlurShader:ActivateWith( function ()

			gaussianBlurShader:SetUniform("dir", 1.0, 0.0) --horizontal blur
			glActiveFBO(blurFBOs[1], function()
				glCallList(screenQuadList) -- gl.TexRect(-1, -1, 1, 1)
			end)
			glTexture(0, blurTexes[1])

			gaussianBlurShader:SetUniform("dir", 0.0, 1.0) --vertical blur
			glActiveFBO(blurFBOs[2], function()
				glCallList(screenQuadList) -- gl.TexRect(-1, -1, 1, 1)
			end)
			glTexture(0, blurTexes[2])

		end)
	end

	glTexture(0, false)
	glTexture(1, false)
end

local function DrawOutline(strength, dupd)
	glBlending(true)
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA) --alpha NO pre-multiply

	if dupd then
		glDepthTest(false)
		glDepthMask(false)
	end

	glTexture(0, blurTexes[2])
	glTexture(1, "$model_gbuffer_zvaltex")

	applicationShader:ActivateWith( function ()
		applicationShader:SetUniformFloat("strength", strength or 1.0)
		glCallList(screenWideList)
	end)

	if dupd then
		glBlending(false)
		glDepthTest(true)
		glDepthMask(true)
	end

	glTexture(0, false)
	glTexture(1, false)
end


local accuTime = 0
local lastTime = 0
local averageFPS = MIN_FPS + MIN_FPS_DELTA

function widget:Update(dt)
	accuTime = accuTime + dt
	if accuTime >= lastTime + 1 then
		lastTime = accuTime
		averageFPS = AVG_FPS_ELASTICITY_INV * averageFPS + AVG_FPS_ELASTICITY * Spring.GetFPS()
		if averageFPS < MIN_FPS then
			show = false
		elseif averageFPS > MIN_FPS + MIN_FPS_DELTA then
			show = true
		end
	end
end

local function EnterLeaveScreenSpace(functionName, ...)
	glMatrixMode(GL_MODELVIEW)
	glPushMatrix()
	glLoadIdentity()

		glMatrixMode(GL_PROJECTION)
		glPushMatrix()
		glLoadIdentity();

			functionName(...)

		glMatrixMode(GL_PROJECTION)
		glPopMatrix()

	glMatrixMode(GL_MODELVIEW)
	glPopMatrix()
end

function widget:DrawUnitsPostDeferred()
	if not show then
		return
	end
	EnterLeaveScreenSpace( function()
		PrepareOutline()
		DrawOutline(1.0, true)
	end)
	widgetHandler:RemoveCallIn("DrawWorldPreUnit")
end

function widget:DrawWorldPreUnit()
	if not show then
		return
	end
	EnterLeaveScreenSpace( function()
		PrepareOutline()
		DrawOutline(1.0, false)
	end)
end

function widget:DrawWorld()
	if not show then
		return
	end
	EnterLeaveScreenSpace(DrawOutline, 0.25, false)
end