local OPTION_SHADOWMAPPING		= 1		-- Self shadowing
local OPTION_NORMALMAPPING		= 2		-- Applies normalmapping
local OPTION_SHIFT_RGBHSV		= 4 	-- userDefined[2].rgb (gl.SetUnitBufferUniforms(unitID, {math.random(),math.random()-0.5,math.random()-0.5}, 8) -- shift Hue, saturation, valence )
local OPTION_VERTEX_AO			= 8		-- Per vertex Ambient Occlusion
local OPTION_FLASHLIGHTS		= 16	-- All emissive (tex2.red) will strobe in brightness
local OPTION_TREADS_U     	 	= 32	-- Treads that scroll left-right (texture U coord)
local OPTION_TREADS_V			= 64	-- Treads that scroll up-down (texture V coord)
local OPTION_HEALTH_TEXTURING	= 128	-- Gradually overlays wreck texture as unit gets damaged (units only)
local OPTION_HEALTH_DISPLACE	= 256	-- Gradually bends vertices out of shape as unit gets damaged
local OPTION_HEALTH_TEXRAPTORS	= 512	-- Progressive blood pooling on damaged raptors based on low heightmap values stored in alpha channel of normal map
local OPTION_MODELSFOG			= 1024	-- Applies linear fog effect to units based on zoom level
local OPTION_TREEWIND			= 2048	-- Makes trees sway gently in the breeze
local OPTION_PBROVERRIDE		= 4096	-- Forces Recoil default tex2 (non PBR) behaviour
local OPTION_TEX2_SPECULAR		= 8192	-- SF unit skins: tex2 red = glow (scaled), green = reflectivity (metalness and polish), blue ignored. Tuned by tex2Params

local defaultBitShaderOptions = OPTION_SHADOWMAPPING + OPTION_NORMALMAPPING + OPTION_MODELSFOG
local defaultUnitBitShaderOptions = defaultBitShaderOptions + OPTION_VERTEX_AO + OPTION_HEALTH_TEXTURING + OPTION_HEALTH_DISPLACE

local uniformBins = {
	-- Special overriding uniformBins go here, i.e. so that you can set different:
		-- bitOptions, baseVertexDisplacement, brightnessFactor, treadRect, treadLinkWidth, treadSpeedMult
	-- To force a unit or feature into any uniformBin, assign customParams.uniformbin = binName,
	-- this method is preferred to the mix of BAR customparams which are kept for backwards compat
	
	-- myunitswithflashinglights = {
	--		bitOptions = defaultUnitBitShaderOptions + OPTION_FLASHLIGHTS,
	--		baseVertexDisplacement = 0.0,
	--		brightnessFactor = 1.5,
	-- },
	treads = {
		-- MCL track textures are top-bottom so use OPTION_TREADS_V
		bitOptions = defaultUnitBitShaderOptions + OPTION_TREADS_V,
		baseVertexDisplacement = 0.0,
		brightnessFactor = 1.1,
		treadRect = {933, 0, 1024 - 933, 1024}, -- Pixels; left, top, width, height
		treadLinkWidth = 22, -- single track link width in Pixels
		treadSpeedMult = 4.0, -- TODO: double check with Behe what the point of texSpeedMult was
		materialIndex = 0,
	},
	-- DEFAULT UNIFORM BINS
	defaultunit = {
		-- by default gadget will assign these options to every unit texture set bin
		-- Tex2 guide (stock CUS, without OPTION_TEX2_SPECULAR): red is glow, green is metalicity, blue is roughness
		-- With OPTION_TEX2_SPECULAR (what the lego2skin texture was painted for): red is glow, green is reflectivity
		bitOptions = OPTION_NORMALMAPPING + OPTION_VERTEX_AO + OPTION_HEALTH_DISPLACE + OPTION_SHADOWMAPPING + OPTION_TEX2_SPECULAR,
		baseVertexDisplacement = 0.0,
		brightnessFactor = 1.3,	-- scales the lit result, glow included
		albedoFactor = 1.1,		-- scales the base colour before lighting: "make the unit brighter" without more glow
		-- OPTION_TEX2_SPECULAR tuning: { glow, metal, roughMax, roughSlope }
		--   glow       self-illumination per unit of tex2 red (1 = stock CUS: the whole unit is self-lit and blooms)
		--   metal      metalness per unit of tex2 green (metal loses its paint colour, keep it low)
		--   roughMax   roughness where green is 0 (panel seams, dark paint)
		--   roughSlope roughness taken off per unit of green (higher = shinier light paint)
		tex2Params = {0.3, 0.4, 0.95, 1.1},
		-- extra glow on team-coloured surfaces (tex1 alpha is the mask); 0 = none, 1 = strong
		teamGlow = 0.6,
		materialIndex = 1,
	},
	-- These are the default featureDef uniformBins, you probably don't want to mess with them unless you really know what you're doing
	feature = {
		-- by default gadget will assign these options to every (non-wreck, non-tree) feature texture set bin
		bitOptions = defaultBitShaderOptions + OPTION_PBROVERRIDE,
		baseVertexDisplacement = 0.0,
		brightnessFactor = 1.3,
		materialIndex = 0,
	},
	featurepbr = {
		-- any feature with featureDef.customParams.cuspbr or with 'pilha_crystal' in the name
		bitOptions = defaultBitShaderOptions,
		baseVertexDisplacement = 0.0,
		brightnessFactor = 1.3,
		materialIndex = 0,
	},
	treepbr = {
		-- Currently unused?
		bitOptions = defaultBitShaderOptions + OPTION_TREEWIND + OPTION_PBROVERRIDE,
		baseVertexDisplacement = 0.0,
		brightnessFactor = 1.3,
		materialIndex = 0,
	},
	tree = {
		-- any whitelisted tree in ModelMaterials_GL4/known_feature_trees.lua or with featureDef.customParams.treeshader = 'yes'
		bitOptions = defaultBitShaderOptions + OPTION_TREEWIND + OPTION_PBROVERRIDE,
		baseVertexDisplacement = 0.0,
		brightnessFactor = 1.3,
		materialIndex = 0,
	},
	wreck = {
		-- any feature referenced in a unitDef.corpse, or featureDef.featureDead or with '_x', '_dead' or '_heap' in the name
		bitOptions = defaultBitShaderOptions + OPTION_VERTEX_AO,
		baseVertexDisplacement = 0.0,
		brightnessFactor = 1.3,
		materialIndex = 0,
	},
} -- maps uniformbins to a table of uniform names/values

local texToPreload = {
	-- only preload textures not loaded by engine e.g. normals or custom wreckTex
	--[[ BAR example
	"unittextures/Arm_wreck_color_normal.dds",
	"unittextures/Arm_normal.dds",
	"unittextures/cor_color_wreck_normal.dds",
	"unittextures/cor_normal.dds",--]]
	"unittextures/lego2skin_explorer.dds",
	"unittextures/lego2skin_explorerglowy.dds",
	"unittextures/lego2skin_explorernormal.dds",
}
-- BAR example of changing based on ModOption
--[[if Spring.GetModOptions().experimentallegionfaction then
	table.insert(texToPreload, "unittextures/leg_wreck_normal.dds")
end--]]

return uniformBins, texToPreload