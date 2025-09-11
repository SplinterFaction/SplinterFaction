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
	},
	-- DEFAULT UNIFORM BINS
	defaultunit = {
		-- by default gadget will assign these options to every unit texture set bin
		bitOptions = defaultBitShaderOptions + OPTION_PBROVERRIDE + OPTION_HEALTH_DISPLACE,
		baseVertexDisplacement = 0.0,
		brightnessFactor = 1.0,
	},
	-- These are the default featureDef uniformBins, you probably don't want to mess with them unless you really know what you're doing
	feature = {
		-- by default gadget will assign these options to every (non-wreck, non-tree) feature texture set bin
		bitOptions = defaultBitShaderOptions + OPTION_PBROVERRIDE,
		baseVertexDisplacement = 0.0,
		brightnessFactor = 1.3,
	},
	featurepbr = {
		-- any feature with featureDef.customParams.cuspbr or with 'pilha_crystal' in the name
		bitOptions = defaultBitShaderOptions,
		baseVertexDisplacement = 0.0,
		brightnessFactor = 1.3,
	},
	treepbr = {
		-- Currently unused?
		bitOptions = defaultBitShaderOptions + OPTION_TREEWIND + OPTION_PBROVERRIDE,
		baseVertexDisplacement = 0.0,
		brightnessFactor = 1.3,
	},
	tree = {
		-- any whitelisted tree in ModelMaterials_GL4/known_feature_trees.lua or with featureDef.customParams.treeshader = 'yes'
		bitOptions = defaultBitShaderOptions + OPTION_TREEWIND + OPTION_PBROVERRIDE,
		baseVertexDisplacement = 0.0,
		brightnessFactor = 1.3,
	},
	wreck = {
		-- any feature referenced in a unitDef.corpse, or featureDef.featureDead or with '_x', '_dead' or '_heap' in the name
		bitOptions = defaultBitShaderOptions + OPTION_VERTEX_AO,
		baseVertexDisplacement = 0.0,
		brightnessFactor = 1.3,
	},
} -- maps uniformbins to a table of uniform names/values

local texToPreload = {
	-- only preload textures not loaded by engine e.g. normals or custom wreckTex
	--[[ BAR example
	"unittextures/Arm_wreck_color_normal.dds",
	"unittextures/Arm_normal.dds",
	"unittextures/cor_color_wreck_normal.dds",
	"unittextures/cor_normal.dds",--]]
	--"unittextures/lego2skin_explorer.dds",
	--"unittextures/lego2skin_explorerglowy.dds",
}
-- BAR example of changing based on ModOption
--[[if Spring.GetModOptions().experimentallegionfaction then
	table.insert(texToPreload, "unittextures/leg_wreck_normal.dds")
end--]]

return uniformBins, texToPreload