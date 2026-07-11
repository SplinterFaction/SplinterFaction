function widget:GetInfo()
	return {
		name    = "Health Bars GL4",
		desc    = "Instanced GL4 healthbars. Port of Beherith's BAR widget, adapted for SplinterFaction (overshields, morphing, self-contained visibility tracking).",
		author  = "Beherith (original), ported for SplinterFaction",
		date    = "2026",
		license = "GNU GPL, v2 or later",
		layer   = -10,
		enabled = true
	}
end

--------------------------------------------------------------------------------
-- How this works, in short:
-- Each visible bar is one instance in an instanced VBO. The vertex/geometry
-- shaders read unit position from the engine matrix SSBO and live values
-- (health, build progress, shield, etc.) from the engine per-unit uniform
-- buffer, so nothing on the CPU runs per bar per frame. The whole set of unit
-- bars is a single draw call; feature bars are three more.
--
-- CPU work is event driven plus a few slow staggered watch loops that only
-- iterate units which actually have a changing value (shielded, EMPd,
-- reloading, morphing, ...). Values are pushed to the GPU with
-- gl.SetUnitBufferUniforms only when they change.
--
-- Per-unit uniform float slots used (userDefined array, 20 floats):
--   0 = build progress, maintained by cus_gl4 (-1 when fully built)
--   2 = shield / reload start frame / stockpile (shared, same as BAR)
--   3 = reload end frame
--   4 = emp / paralyze damage
--   5 = capture progress
--   7 = overshield (personalShield rules param, normalized)
--   8 = morph progress
-- Slots 6, 11 and 12 are owned by cus_gl4 (selectedness, height, cloak). Do
-- not write to them from here.
--------------------------------------------------------------------------------

local mathMin = math.min
local mathMax = math.max

local spGetUnitDefID        = Spring.GetUnitDefID
local spGetUnitHealth       = Spring.GetUnitHealth
local spGetUnitPosition     = Spring.GetUnitPosition
local spGetGameFrame        = Spring.GetGameFrame
local spEcho                = Spring.Echo
local spGetUnitTeam         = Spring.GetUnitTeam
local spGetSpectatingState  = Spring.GetSpectatingState
local spGetFeaturePosition  = Spring.GetFeaturePosition
local spIsPosInLos          = Spring.IsPosInLos
local spGetVisibleUnits     = Spring.GetVisibleUnits
local spGetVisibleFeatures  = Spring.GetVisibleFeatures
local spGetUnitRulesParam   = Spring.GetUnitRulesParam
local spValidUnitID         = Spring.ValidUnitID
local spGetUnitIsDead       = Spring.GetUnitIsDead
local spGetUnitShieldState  = Spring.GetUnitShieldState
local spGetUnitStockpile    = Spring.GetUnitStockpile
local spGetUnitIsStunned    = Spring.GetUnitIsStunned
local spGetUnitWeaponState  = Spring.GetUnitWeaponState
local spGetFeatureDefID     = Spring.GetFeatureDefID
local spGetFeatureHealth    = Spring.GetFeatureHealth
local spGetFeatureResources = Spring.GetFeatureResources

local LuaShader        = VFS.Include("modules/graphics/LuaShader.lua")
local InstanceVBOTable = VFS.Include("modules/graphics/instancevbotable.lua")

local pushElementInstance = InstanceVBOTable.pushElementInstance
local popElementInstance  = InstanceVBOTable.popElementInstance

--------------------------------------------------------------------------------
-- Configurables
--------------------------------------------------------------------------------

local drawWhenGuiHidden = false
local drawEnabled       = true -- toggled by F9

local healthbartexture = "LuaUI/Images/healthbars_gl4_atlas.tga"

local additionalheightaboveunit = 24
local featureHealthDistMult     = 7    -- features must be this much closer for health bars
local featureReclaimDistMult    = 2
local featureResurrectDistMult  = 1
local glphydistmult             = 3.5  -- how much closer than BARFADEEND before numbers/icons draw
local glyphdistmultfeatures     = 1.8

local skipGlyphsNumbers = 0.0 -- 0.0 draws glyphs and numbers, 1.0 numbers only, 2.0 bars only

local minReloadTime = 4 -- weapons reloading slower than this (seconds) get reload bars

local visibleRefreshTime = 0.30 -- seconds between visible unit set refreshes
local featureRefreshTime = 0.50 -- seconds between visible feature reclaim/rez sweeps

local barScale         = 1
local variableBarSizes = true
local barHeight        = 0.9

local debugmode = false

--------------------------------------------------------------------------------
-- Bar types
--------------------------------------------------------------------------------

-- bartype bitmask, must match the shaders
local bitUseOverlay    = 1
local bitShowGlyph     = 2
local bitPercentage    = 4
local bitTimeLeft      = 8
local bitIntegerNumber = 16
local bitGetProgress   = 32
local bitFlashBar      = 64
local bitColorCorrect  = 128

-- uniformindex is the userDefined float slot the shader reads. Values above 20
-- mean "engine health / maxHealth", which needs no CPU updates at all.
local barTypeMap = {
	health = {
		mincolor     = { 1.0, 0.0, 0.0, 1.0 },
		maxcolor     = { 0.0, 1.0, 0.0, 1.0 },
		bartype      = bitPercentage + bitColorCorrect,
		uniformindex = 32,
		uvoffset     = 0.0625,
	},
	shield = { -- engine shieldWeaponDef shields
		mincolor     = { 0.15, 0.4, 0.4, 1.0 },
		maxcolor     = { 0.3, 0.8, 0.8, 1.0 },
		bartype      = bitShowGlyph + bitUseOverlay + bitPercentage,
		uniformindex = 2,
		uvoffset     = 0.3125,
	},
	overshield = { -- SF personalShield rules param (Loz Alliance)
		mincolor     = { 0.25, 0.45, 0.9, 1.0 },
		maxcolor     = { 0.5, 0.75, 1.0, 1.0 },
		bartype      = bitShowGlyph + bitUseOverlay + bitPercentage,
		uniformindex = 7,
		uvoffset     = 0.3125, -- same glyph as shield
	},
	capture = {
		mincolor     = { 0.5, 0.25, 0.0, 1.0 },
		maxcolor     = { 1.0, 0.5, 0.0, 1.0 },
		bartype      = bitShowGlyph + bitUseOverlay + bitPercentage,
		uniformindex = 5,
		uvoffset     = 0.1875,
	},
	stockpile = {
		mincolor     = { 0.1, 0.1, 0.1, 1.0 },
		maxcolor     = { 0.1, 0.1, 0.1, 1.0 },
		bartype      = bitShowGlyph + bitUseOverlay + bitIntegerNumber,
		uniformindex = 2,
		uvoffset     = 0.4375,
	},
	emp_damage = {
		mincolor     = { 0.4, 0.4, 0.8, 1.0 },
		maxcolor     = { 0.6, 0.6, 1.0, 1.0 },
		bartype      = bitShowGlyph + bitUseOverlay + bitPercentage,
		uniformindex = 4,
		uvoffset     = 0.5625,
	},
	reload = {
		mincolor     = { 0.03, 0.4, 0.4, 1.0 },
		maxcolor     = { 0.05, 0.6, 0.6, 1.0 },
		bartype      = bitShowGlyph + bitUseOverlay + bitGetProgress,
		uniformindex = 2, -- and 3, start and end frames
		uvoffset     = 0.6875,
	},
	building = {
		mincolor     = { 1.0, 1.0, 1.0, 1.0 },
		maxcolor     = { 1.0, 1.0, 1.0, 1.0 },
		bartype      = bitShowGlyph + bitUseOverlay + bitPercentage,
		uniformindex = 0, -- maintained by cus_gl4
		uvoffset     = 0.9375,
	},
	morph = { -- SF unit upgrade/morph progress
		mincolor     = { 0.7, 0.9, 0.7, 1.0 },
		maxcolor     = { 0.9, 1.0, 0.9, 1.0 },
		bartype      = bitShowGlyph + bitUseOverlay + bitPercentage,
		uniformindex = 8,
		uvoffset     = 0.9375, -- same glyph as building
	},
	paralyzed = {
		mincolor     = { 0.6, 0.6, 1.0, 1.0 },
		maxcolor     = { 0.6, 0.6, 1.0, 1.0 },
		bartype      = bitShowGlyph + bitUseOverlay + bitFlashBar + bitTimeLeft,
		uniformindex = 4,
		uvoffset     = 0.8125,
	},
	featurehealth = {
		mincolor     = { 0.25, 0.25, 0.25, 1.0 },
		maxcolor     = { 0.65, 0.65, 0.65, 1.0 },
		bartype      = bitShowGlyph + bitPercentage,
		uniformindex = 33,
		uvoffset     = 0.125,
	},
	featurereclaim = {
		mincolor     = { 0.00, 1.00, 0.00, 1.0 },
		maxcolor     = { 0.85, 1.00, 0.85, 1.0 },
		bartype      = bitShowGlyph + bitPercentage,
		uniformindex = 2,
		uvoffset     = 0.5,
	},
	featureresurrect = {
		mincolor     = { 0.75, 0.15, 0.75, 1.0 },
		maxcolor     = { 1.0, 0.2, 1.0, 1.0 },
		bartype      = bitShowGlyph + bitPercentage,
		uniformindex = 1,
		uvoffset     = 0.25,
	},
}

for barname, bt in pairs(barTypeMap) do
	local cache = {}
	for i = 1, 20 do cache[i] = 0 end
	-- cache[1] = height offset, filled per unit
	-- cache[2] = effective scale, filled per unit
	cache[4] = bt.uvoffset
	cache[5] = bt.bartype
	-- cache[6] = bar stacking index, filled per unit
	cache[7] = bt.uniformindex
	cache[9], cache[10], cache[11], cache[12] = bt.mincolor[1], bt.mincolor[2], bt.mincolor[3], bt.mincolor[4]
	cache[13], cache[14], cache[15], cache[16] = bt.maxcolor[1], bt.maxcolor[2], bt.maxcolor[3], bt.maxcolor[4]
	-- cache[17..20] = instData placeholder, filled by pushElementInstance
	bt.cache = cache
end

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local spec, fullview = spGetSpectatingState()
local myAllyTeamID   = Spring.GetMyAllyTeamID()

local chobbyInterface

-- per unitDefID static data
local unitDefIgnore          = {}
local unitDefhasShield       = {} -- engine shield max power
local unitDefOvershieldMax   = {} -- SF personalShield max (customParams.shield_max_strength)
local unitDefCanStockpile    = {}
local unitDefHeights         = {}
local unitDefHideDamage      = {}
local unitDefPrimaryWeapon   = {} -- weapon index for slow-reload weapons
local unitDefReloadFrames    = {} -- reload time in frames for that weapon
local unitDefSizeMultipliers = {}

-- per unitID live state
local trackedUnits       = {} -- unitID -> unitDefID, the currently visible set
local unitBars           = {} -- unitID -> bar count
local unitShieldWatch    = {} -- unitID -> last shield value
local unitOvershieldWatch = {} -- unitID -> last personalShield value
local unitCaptureWatch   = {}
local unitEmpDamagedWatch = {}
local unitParalyzedWatch = {}
local unitStockPileWatch = {}
local unitReloadWatch    = {} -- unitID -> last uploaded reloadFrame

local UnitMorphs = {} -- unitID -> morph table, fed by the morph gadget globals

-- features
local featureDefHeights = {}
local featureDefDrawn   = {} -- has a model, worth barring
local featureBars       = {} -- featureID -> bar count
local featureRezReclaim = {} -- featureID -> {rez, reclaim} last uploaded

local gameFrame = 0

-- morph finished notification (ported from the old widget)
local notificationTimeout = 0
local resourcePrompts     = 1

--------------------------------------------------------------------------------
-- UnitDef / FeatureDef scan
--------------------------------------------------------------------------------

for udefID, unitDef in pairs(UnitDefs) do
	local cp = unitDef.customParams
	if cp and cp.nohealthbars then
		unitDefIgnore[udefID] = true
	end

	local shieldDefID = unitDef.shieldWeaponDef
	local shieldPower = (shieldDefID and WeaponDefs[shieldDefID].shieldPower) or -1
	if shieldPower > 1 then
		unitDefhasShield[udefID] = shieldPower
	end

	if cp and cp.isshieldedunit == "1" then
		unitDefOvershieldMax[udefID] = tonumber(cp.shield_max_strength) or 100
	end

	local reloadTime    = 0
	local primaryWeapon = nil
	local weapons       = unitDef.weapons
	for i = 1, #weapons do
		local wd = WeaponDefs[weapons[i].weaponDef]
		if wd and wd.reload and wd.reload > reloadTime then
			reloadTime    = wd.reload
			primaryWeapon = i
		end
	end
	if primaryWeapon and reloadTime >= minReloadTime then
		unitDefPrimaryWeapon[udefID] = primaryWeapon
		unitDefReloadFrames[udefID]  = reloadTime * 30
	end

	unitDefHeights[udefID] = unitDef.height or 32

	local dims   = Spring.GetUnitDefDimensions(udefID)
	local radius = (dims and dims.radius) or 50
	unitDefSizeMultipliers[udefID] = mathMin(1.45, mathMax(0.85, (radius / 150) + mathMin(0.6, (unitDef.power or 1000) / 4000))) + mathMin(0.6, (unitDef.health or 1000) / 22000)

	if unitDef.canStockpile then
		unitDefCanStockpile[udefID] = true
	end
	if unitDef.hideDamage == true then
		unitDefHideDamage[udefID] = true
	end
end

for fdefID, featureDef in pairs(FeatureDefs) do
	featureDefHeights[fdefID] = featureDef.height or 32
	featureDefDrawn[fdefID]   = (featureDef.destructable and featureDef.modelpath ~= nil and featureDef.modelpath ~= '' and featureDef.name ~= 'geovent')
end

--------------------------------------------------------------------------------
-- GL4 backend
--------------------------------------------------------------------------------

local healthBarVBO
local healthBarShader
local featureHealthVBO
local featureResurrectVBO
local featureReclaimVBO
local unitQuadVBO

local useGeometryShader = LuaShader.isGeometryShaderSupported

local shaderConfig = {
	HEIGHTOFFSET           = 3,
	CLIPTOLERANCE          = 1.2,
	MAXVERTICES            = 64,
	BARWIDTH               = 2.56,
	BARHEIGHT              = barHeight,
	BGBOTTOMCOLOR          = "vec4(0.25, 0.25, 0.25, 0.8)",
	BGTOPCOLOR             = "vec4(0.1, 0.1, 0.1, 0.8)",
	BARSCALE               = 4.0,
	PERCENT_VISIBILITY_MAX = 0.99,
	TIMER_VISIBILITY_MIN   = 0.0,
	BARSTEP                = 10,
	BOTTOMDARKENFACTOR     = 0.5,
	BARFADESTART           = 3200,
	BARFADEEND             = 3800,
	ATLASSTEP              = 0.0625,
	MINALPHA               = 0.2,
}
shaderConfig.BARCORNER     = 0.06 + (shaderConfig.BARHEIGHT / 9)
shaderConfig.SMALLERCORNER = shaderConfig.BARCORNER * 0.6
if debugmode then
	shaderConfig.DEBUGSHOW = 1
end

local shaderSourceCache = {
	vssrcpath  = "LuaUI/shaders/healthbars_gl4.vert.glsl",
	gssrcpath  = "LuaUI/shaders/healthbars_gl4.geom.glsl",
	fssrcpath  = "LuaUI/shaders/healthbars_gl4.frag.glsl",
	shaderName = "Health Bars Shader GL4",
	uniformInt = {
		healthbartexture = 0,
	},
	uniformFloat = {
		iconDistance            = 27,
		cameraDistanceMult      = 1.0,
		cameraDistanceMultGlyph = 4.0,
		skipGlyphsNumbers       = 0.0,
		globalSizeMult          = 1.0,
	},
	shaderConfig = shaderConfig,
}

local fallbackShaderSourceCache = {
	vssrcpath  = "LuaUI/shaders/healthbars_gl4_nogs.vert.glsl",
	fssrcpath  = "LuaUI/shaders/healthbars_gl4_nogs.frag.glsl",
	shaderName = "Health Bars Shader GL4 (NoGS)",
	uniformInt = {
		healthbartexture = 0,
	},
	uniformFloat = {
		iconDistance            = 27,
		cameraDistanceMult      = 1.0,
		cameraDistanceMultGlyph = 4.0,
		skipGlyphsNumbers       = 0.0,
		globalSizeMult          = 1.0,
	},
	shaderConfig = shaderConfig,
}

local function goodbye(reason)
	spEcho("Health Bars GL4 exiting: " .. reason)
	widgetHandler:RemoveWidget()
end

local function initializeInstanceVBOTable(myName, usesFeatures)
	local layout
	local unitIDAttribID
	if useGeometryShader then
		layout = {
			{ id = 0, name = 'height_timers', size = 4 },
			{ id = 1, name = 'type_index_ssboloc', size = 4, type = GL.UNSIGNED_INT },
			{ id = 2, name = 'startcolor', size = 4 },
			{ id = 3, name = 'endcolor', size = 4 },
			{ id = 4, name = 'instData', size = 4, type = GL.UNSIGNED_INT },
		}
		unitIDAttribID = 4
	else
		layout = {
			{ id = 2, name = 'height_timers', size = 4 },
			{ id = 3, name = 'type_index_ssboloc', size = 4, type = GL.UNSIGNED_INT },
			{ id = 4, name = 'startcolor', size = 4 },
			{ id = 5, name = 'endcolor', size = 4 },
			{ id = 6, name = 'instData', size = 4, type = GL.UNSIGNED_INT },
		}
		unitIDAttribID = 6
	end
	local newVBOTable = InstanceVBOTable.makeInstanceVBOTable(layout, 256, myName, unitIDAttribID)
	if newVBOTable == nil then
		goodbye("Failed to create " .. myName)
		return nil
	end

	if useGeometryShader then
		local newVAO = gl.GetVAO()
		newVAO:AttachVertexBuffer(newVBOTable.instanceVBO)
		newVBOTable.VAO = newVAO
	else
		newVBOTable.VAO = InstanceVBOTable.makeVAOandAttach(unitQuadVBO, newVBOTable.instanceVBO)
	end
	if usesFeatures then
		newVBOTable.featureIDs = true
	end
	return newVBOTable
end

local function initGL4()
	-- Prefer the geometry shader path when it compiles, fall back to instanced quads.
	if useGeometryShader then
		healthBarShader = LuaShader.CheckShaderUpdates(shaderSourceCache, 0)
		useGeometryShader = (healthBarShader ~= nil)
	end

	if not useGeometryShader then
		unitQuadVBO = gl.GetVBO(GL.ARRAY_BUFFER, false)
		if unitQuadVBO == nil then
			goodbye("Failed to create quad VBO")
			return false
		end
		unitQuadVBO:Define(4, {
			{ id = 0, name = 'quadPos', size = 2 },
		})
		unitQuadVBO:Upload({
			0.0, 0.0,
			1.0, 0.0,
			0.0, 1.0,
			1.0, 1.0,
		})
		healthBarShader = LuaShader.CheckShaderUpdates(fallbackShaderSourceCache, 0)
	end

	if not healthBarShader then
		goodbye("Failed to compile Health Bars GL4 shader")
		return false
	end

	healthBarVBO        = initializeInstanceVBOTable("healthBarVBO", false)
	featureHealthVBO    = initializeInstanceVBOTable("featureHealthVBO", true)
	featureResurrectVBO = initializeInstanceVBOTable("featureResurrectVBO", true)
	featureReclaimVBO   = initializeInstanceVBOTable("featureReclaimVBO", true)

	if not (healthBarVBO and featureHealthVBO and featureResurrectVBO and featureReclaimVBO) then
		return false
	end
	return true
end

--------------------------------------------------------------------------------
-- Unit bar add/remove
--------------------------------------------------------------------------------

local uniformcache = { 0.0 }

local function addBarForUnit(unitID, unitDefID, barname)
	unitDefID = unitDefID or spGetUnitDefID(unitID)
	if unitDefID == nil or unitDefIgnore[unitDefID] then
		return nil
	end

	local instanceID = unitID .. '_' .. barname
	if healthBarVBO.instanceIDtoIndex[instanceID] then
		return nil -- already have this bar
	end

	if spValidUnitID(unitID) == false or spGetUnitIsDead(unitID) == true then
		return nil
	end

	unitBars[unitID] = (unitBars[unitID] or 0) + 1

	local effectiveScale = ((variableBarSizes and unitDefSizeMultipliers[unitDefID]) or 1.0) * barScale

	local bt    = barTypeMap[barname]
	local cache = bt.cache
	cache[1] = unitDefHeights[unitDefID] + additionalheightaboveunit * effectiveScale
	cache[2] = effectiveScale
	cache[6] = unitBars[unitID] - 1 -- stacking index

	return pushElementInstance(healthBarVBO, cache, instanceID, true, nil, unitID)
end

local function removeBarFromUnit(unitID, barname)
	local instanceKey = unitID .. "_" .. barname
	if healthBarVBO.instanceIDtoIndex[instanceKey] then
		unitBars[unitID] = (unitBars[unitID] or 1) - 1
		popElementInstance(healthBarVBO, instanceKey)
	end
end

local function updateReloadBar(unitID, unitDefID)
	-- Positional form of GetUnitWeaponState: angleGood, loaded, reloadFrame
	local _, loaded, reloadFrame = spGetUnitWeaponState(unitID, unitDefPrimaryWeapon[unitDefID])
	if loaded == false and reloadFrame and reloadFrame > gameFrame then
		if unitReloadWatch[unitID] ~= reloadFrame then
			unitReloadWatch[unitID] = reloadFrame
			addBarForUnit(unitID, unitDefID, "reload")
			uniformcache[1] = reloadFrame - unitDefReloadFrames[unitDefID]
			gl.SetUnitBufferUniforms(unitID, uniformcache, 2)
			uniformcache[1] = reloadFrame
			gl.SetUnitBufferUniforms(unitID, uniformcache, 3)
		end
	end
end

local function addBarsForUnit(unitID, unitDefID, unitAllyTeam)
	if unitDefID == nil or unitDefIgnore[unitDefID] then
		return
	end
	if spValidUnitID(unitID) == false or spGetUnitIsDead(unitID) == true then
		return
	end

	unitBars[unitID] = unitBars[unitID] or 0
	unitAllyTeam     = unitAllyTeam or Spring.GetUnitAllyTeam(unitID)

	local health, maxHealth, paralyzeDamage, capture, build = spGetUnitHealth(unitID)

	if fullview or (unitAllyTeam == myAllyTeamID) or (unitDefHideDamage[unitDefID] == nil) then
		addBarForUnit(unitID, unitDefID, "health")
	end

	if unitDefhasShield[unitDefID] then
		addBarForUnit(unitID, unitDefID, "shield")
		unitShieldWatch[unitID] = -1.0
	end

	if unitDefOvershieldMax[unitDefID] then
		addBarForUnit(unitID, unitDefID, "overshield")
		unitOvershieldWatch[unitID] = -1.0
		local overshield = spGetUnitRulesParam(unitID, "personalShield")
		if overshield then
			uniformcache[1] = overshield / unitDefOvershieldMax[unitDefID]
			gl.SetUnitBufferUniforms(unitID, uniformcache, 7)
			unitOvershieldWatch[unitID] = overshield
		end
	end

	if unitDefPrimaryWeapon[unitDefID] then
		unitReloadWatch[unitID] = unitReloadWatch[unitID] or 0
		updateReloadBar(unitID, unitDefID)
	end

	if health ~= nil then
		if build < 1 then
			addBarForUnit(unitID, unitDefID, "building")
		end

		if unitDefCanStockpile[unitDefID] and ((unitAllyTeam == myAllyTeamID) or fullview) then
			unitStockPileWatch[unitID] = -1.0
			addBarForUnit(unitID, unitDefID, "stockpile")
		end

		if capture and capture > 0 then
			addBarForUnit(unitID, unitDefID, "capture")
			uniformcache[1] = capture
			gl.SetUnitBufferUniforms(unitID, uniformcache, 5)
			unitCaptureWatch[unitID] = capture
		end

		if paralyzeDamage and paralyzeDamage > 0 and maxHealth and maxHealth > 0 then
			if spGetUnitIsStunned(unitID) then
				if unitParalyzedWatch[unitID] == nil then
					unitParalyzedWatch[unitID] = 0.0
					if unitEmpDamagedWatch[unitID] then
						unitEmpDamagedWatch[unitID] = nil
						removeBarFromUnit(unitID, 'emp_damage')
					end
					addBarForUnit(unitID, unitDefID, "paralyzed")
				end
			else
				if unitEmpDamagedWatch[unitID] == nil then
					unitEmpDamagedWatch[unitID] = 0.0
					addBarForUnit(unitID, unitDefID, "emp_damage")
				end
			end
			uniformcache[1] = paralyzeDamage / maxHealth
			gl.SetUnitBufferUniforms(unitID, uniformcache, 4)
		end
	end

	if UnitMorphs[unitID] then
		addBarForUnit(unitID, unitDefID, "morph")
		uniformcache[1] = UnitMorphs[unitID].progress or 0
		gl.SetUnitBufferUniforms(unitID, uniformcache, 8)
	end
end

local function removeBarsFromUnit(unitID)
	for barname in pairs(barTypeMap) do
		removeBarFromUnit(unitID, barname)
	end
	unitShieldWatch[unitID]     = nil
	unitOvershieldWatch[unitID] = nil
	unitCaptureWatch[unitID]    = nil
	unitEmpDamagedWatch[unitID] = nil
	unitParalyzedWatch[unitID]  = nil
	unitStockPileWatch[unitID]  = nil
	unitReloadWatch[unitID]     = nil
	unitBars[unitID]            = nil
end

--------------------------------------------------------------------------------
-- Feature bar add/remove
--------------------------------------------------------------------------------

local function addBarToFeature(featureID, barname)
	local featureDefID = spGetFeatureDefID(featureID)
	if featureDefID == nil then
		return
	end

	local bt        = barTypeMap[barname]
	local targetVBO = featureHealthVBO
	if barname == 'featurereclaim' then targetVBO = featureReclaimVBO end
	if barname == 'featureresurrect' then targetVBO = featureResurrectVBO end

	if targetVBO.instanceIDtoIndex[featureID] then
		return
	end

	featureBars[featureID] = (featureBars[featureID] or 0) + 1

	pushElementInstance(
		targetVBO,
		{
			featureDefHeights[featureDefID] + additionalheightaboveunit,
			1.0 * barScale,
			0,
			bt.uvoffset,

			bt.bartype,
			featureBars[featureID] - 1,
			bt.uniformindex,
			0,

			bt.mincolor[1], bt.mincolor[2], bt.mincolor[3], bt.mincolor[4],
			bt.maxcolor[1], bt.maxcolor[2], bt.maxcolor[3], bt.maxcolor[4],
			0, 0, 0, 0,
		},
		featureID,
		true,
		nil,
		featureID)
end

local function removeBarFromFeature(featureID, targetVBO)
	if not targetVBO.instanceIDtoIndex[featureID] then
		return
	end
	popElementInstance(targetVBO, featureID)
	local barCount = featureBars[featureID]
	if barCount then
		barCount = barCount - 1
		featureBars[featureID] = (barCount > 0) and barCount or nil
	end
end

local function removeBarsFromFeature(featureID)
	removeBarFromFeature(featureID, featureHealthVBO)
	removeBarFromFeature(featureID, featureReclaimVBO)
	removeBarFromFeature(featureID, featureResurrectVBO)
end

local rezreclaim = { 0.0, 1.0 }

function widget:FeatureCreated(featureID)
	local featureDefID = spGetFeatureDefID(featureID)
	if featureDefID == nil or not featureDefDrawn[featureDefID] then
		return
	end

	local health, maxhealth, rezProgress = spGetFeatureHealth(featureID)
	if health == nil then
		return
	end

	if gameFrame > 0 then
		addBarToFeature(featureID, 'featurehealth')
	elseif health ~= maxhealth then
		addBarToFeature(featureID, 'featurehealth')
	end

	if not fullview then
		local fx, fy, fz = spGetFeaturePosition(featureID)
		if fx and not spIsPosInLos(fx, fy, fz, myAllyTeamID) then
			return
		end
	end

	local _, _, _, _, reclaimLeft = spGetFeatureResources(featureID)
	reclaimLeft = reclaimLeft or 1

	if rezProgress and rezProgress > 0 then
		addBarToFeature(featureID, 'featureresurrect')
	end
	if reclaimLeft < 1.0 then
		addBarToFeature(featureID, 'featurereclaim')
	end

	if (rezProgress and rezProgress > 0) or reclaimLeft < 1 then
		rezreclaim[1] = rezProgress or 0
		rezreclaim[2] = reclaimLeft
		gl.SetFeatureBufferUniforms(featureID, rezreclaim, 1)
		featureRezReclaim[featureID] = { rezProgress or 0, reclaimLeft }
	end
end

function widget:FeatureDestroyed(featureID)
	removeBarsFromFeature(featureID)
	featureBars[featureID]       = nil
	featureRezReclaim[featureID] = nil
end

--------------------------------------------------------------------------------
-- Init / reinit
--------------------------------------------------------------------------------

local function clearAllUnitState()
	InstanceVBOTable.clearInstanceTable(healthBarVBO)
	trackedUnits        = {}
	unitBars            = {}
	unitShieldWatch     = {}
	unitOvershieldWatch = {}
	unitCaptureWatch    = {}
	unitEmpDamagedWatch = {}
	unitParalyzedWatch  = {}
	unitStockPileWatch  = {}
	unitReloadWatch     = {}
end

local function refreshVisibleUnits()
	local visible = spGetVisibleUnits(-1, nil, false)
	local visibleSet = {}
	for i = 1, #visible do
		local unitID = visible[i]
		visibleSet[unitID] = true
		if trackedUnits[unitID] == nil then
			local unitDefID = spGetUnitDefID(unitID)
			if unitDefID then
				trackedUnits[unitID] = unitDefID
				addBarsForUnit(unitID, unitDefID, nil)
			end
		end
	end
	for unitID in pairs(trackedUnits) do
		if not visibleSet[unitID] then
			trackedUnits[unitID] = nil
			removeBarsFromUnit(unitID)
		end
	end
end

local function init()
	clearAllUnitState()
	spec, fullview = spGetSpectatingState()
	myAllyTeamID   = Spring.GetMyAllyTeamID()
	refreshVisibleUnits()
end

local function initfeaturebars()
	InstanceVBOTable.clearInstanceTable(featureHealthVBO)
	InstanceVBOTable.clearInstanceTable(featureResurrectVBO)
	InstanceVBOTable.clearInstanceTable(featureReclaimVBO)
	featureBars       = {}
	featureRezReclaim = {}
	for _, featureID in ipairs(Spring.GetAllFeatures()) do
		widget:FeatureCreated(featureID)
	end
end

--------------------------------------------------------------------------------
-- Standard callins replacing BAR's custom unit tracker callins
--------------------------------------------------------------------------------

function widget:UnitDestroyed(unitID)
	if trackedUnits[unitID] then
		trackedUnits[unitID] = nil
	end
	removeBarsFromUnit(unitID)
end

function widget:UnitFinished(unitID)
	removeBarFromUnit(unitID, 'building')
end

function widget:UnitTaken(unitID)
	if trackedUnits[unitID] then
		trackedUnits[unitID] = nil
		removeBarsFromUnit(unitID)
	end
end

function widget:UnitGiven(unitID, unitDefID)
	-- picked up again by the next visible refresh; force it now for responsiveness
	if spValidUnitID(unitID) then
		trackedUnits[unitID] = unitDefID
		addBarsForUnit(unitID, unitDefID, nil)
	end
end

function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
	if not trackedUnits[unitID] then
		return
	end
	if paralyzer then
		if spGetUnitIsStunned(unitID) then
			if unitParalyzedWatch[unitID] == nil then
				unitParalyzedWatch[unitID] = 0.0
				if unitEmpDamagedWatch[unitID] then
					unitEmpDamagedWatch[unitID] = nil
					removeBarFromUnit(unitID, 'emp_damage')
				end
				addBarForUnit(unitID, unitDefID, "paralyzed")
			end
		else
			if unitEmpDamagedWatch[unitID] == nil then
				unitEmpDamagedWatch[unitID] = 0.0
				addBarForUnit(unitID, unitDefID, "emp_damage")
			end
		end
	end
	-- shield and overshield hits get picked up by the watch loops within 3 frames
end

function widget:PlayerChanged(playerID)
	local currentspec, currentfullview = spGetSpectatingState()
	local currentAllyTeamID = Spring.GetMyAllyTeamID()

	if (currentspec ~= spec)
		or (currentfullview ~= fullview)
		or ((currentAllyTeamID ~= myAllyTeamID) and not currentfullview) then
		spec         = currentspec
		fullview     = currentfullview
		myAllyTeamID = currentAllyTeamID
		init()
		initfeaturebars()
	else
		spec         = currentspec
		fullview     = currentfullview
		myAllyTeamID = currentAllyTeamID
	end
end

--------------------------------------------------------------------------------
-- Update: visibility tracking
--------------------------------------------------------------------------------

local unitRefreshTimer    = 0
local featureRefreshTimer = 0

function widget:Update(dt)
	unitRefreshTimer = unitRefreshTimer + dt
	if unitRefreshTimer > visibleRefreshTime then
		unitRefreshTimer = 0
		refreshVisibleUnits()
	end

	featureRefreshTimer = featureRefreshTimer + dt
	if featureRefreshTimer > featureRefreshTime then
		featureRefreshTimer = 0
		-- sweep visible features for reclaim/resurrect activity
		local visibleFeatures = spGetVisibleFeatures(-1, nil, false, false)
		for i = 1, #visibleFeatures do
			local featureID    = visibleFeatures[i]
			local featureDefID = spGetFeatureDefID(featureID)
			if featureDefID and featureDefDrawn[featureDefID] then
				local _, _, rezProgress = spGetFeatureHealth(featureID)
				local _, _, _, _, reclaimLeft = spGetFeatureResources(featureID)
				rezProgress = rezProgress or 0
				reclaimLeft = reclaimLeft or 1
				local last = featureRezReclaim[featureID]
				if (rezProgress > 0 or reclaimLeft < 1) then
					if last == nil or last[1] ~= rezProgress or last[2] ~= reclaimLeft then
						if rezProgress > 0 then
							addBarToFeature(featureID, 'featureresurrect')
						end
						if reclaimLeft < 1 then
							addBarToFeature(featureID, 'featurereclaim')
						end
						rezreclaim[1] = rezProgress
						rezreclaim[2] = reclaimLeft
						gl.SetFeatureBufferUniforms(featureID, rezreclaim, 1)
						if last == nil then
							featureRezReclaim[featureID] = { rezProgress, reclaimLeft }
						else
							last[1] = rezProgress
							last[2] = reclaimLeft
						end
					end
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- GameFrame: staggered watch loops
--------------------------------------------------------------------------------

function widget:GameFrame(n)
	gameFrame = n

	-- engine shields
	if n % 3 == 0 then
		for unitID, oldshieldPower in pairs(unitShieldWatch) do
			local shieldOn, shieldPower = spGetUnitShieldState(unitID)
			if shieldOn == false then shieldPower = 0.0 end
			if oldshieldPower ~= shieldPower then
				if shieldPower == nil then
					removeBarFromUnit(unitID, "shield")
					unitShieldWatch[unitID] = nil
				else
					local udid = spGetUnitDefID(unitID)
					if udid and unitDefhasShield[udid] then
						uniformcache[1] = shieldPower / unitDefhasShield[udid]
						gl.SetUnitBufferUniforms(unitID, uniformcache, 2)
					end
					unitShieldWatch[unitID] = shieldPower
				end
			end
		end

		-- SF overshields (personalShield rules param)
		for unitID, oldOvershield in pairs(unitOvershieldWatch) do
			local overshield = spGetUnitRulesParam(unitID, "personalShield")
			if overshield ~= nil and overshield ~= oldOvershield then
				local udid = spGetUnitDefID(unitID)
				if udid and unitDefOvershieldMax[udid] then
					uniformcache[1] = overshield / unitDefOvershieldMax[udid]
					gl.SetUnitBufferUniforms(unitID, uniformcache, 7)
				end
				unitOvershieldWatch[unitID] = overshield
			end
		end
	end

	-- EMP damaged but not stunned
	if (n + 1) % 3 == 0 then
		for unitID, oldempvalue in pairs(unitEmpDamagedWatch) do
			local _, maxHealth, newparalyzeDamage = spGetUnitHealth(unitID)
			if newparalyzeDamage and oldempvalue ~= newparalyzeDamage then
				if newparalyzeDamage <= 0 then
					unitEmpDamagedWatch[unitID] = nil
					removeBarFromUnit(unitID, "emp_damage")
				else
					uniformcache[1] = newparalyzeDamage / maxHealth
					unitEmpDamagedWatch[unitID] = newparalyzeDamage
					gl.SetUnitBufferUniforms(unitID, uniformcache, 4)
				end
			end
		end
	end

	-- fully stunned
	if (n + 2) % 3 == 0 then
		for unitID in pairs(unitParalyzedWatch) do
			if spGetUnitIsStunned(unitID) then
				local _, maxHealth, paralyzeDamage = spGetUnitHealth(unitID)
				if paralyzeDamage and maxHealth then
					uniformcache[1] = paralyzeDamage / maxHealth
					gl.SetUnitBufferUniforms(unitID, uniformcache, 4)
				end
			else
				unitParalyzedWatch[unitID] = nil
				removeBarFromUnit(unitID, "paralyzed")
				addBarForUnit(unitID, spGetUnitDefID(unitID), "emp_damage")
				unitEmpDamagedWatch[unitID] = 1.0
			end
		end
	end

	-- capture
	if n % 3 == 2 then
		for unitID, captureprogress in pairs(unitCaptureWatch) do
			local capture = select(4, spGetUnitHealth(unitID))
			if capture and capture ~= captureprogress then
				uniformcache[1] = capture
				gl.SetUnitBufferUniforms(unitID, uniformcache, 5)
				unitCaptureWatch[unitID] = capture
			end
			if capture == 0 or capture == nil then
				removeBarFromUnit(unitID, 'capture')
				unitCaptureWatch[unitID] = nil
			end
		end
	end

	-- stockpile
	if n % 5 == 2 then
		for unitID, laststockpile in pairs(unitStockPileWatch) do
			local numStockpiled, numStockpileQued, stockpileBuild = spGetUnitStockpile(unitID)
			if numStockpiled and stockpileBuild then
				local packed = numStockpiled + stockpileBuild
				if packed ~= laststockpile then
					uniformcache[1] = packed
					unitStockPileWatch[unitID] = packed
					gl.SetUnitBufferUniforms(unitID, uniformcache, 2)
				end
			end
		end
	end

	-- reload
	if n % 5 == 4 then
		for unitID in pairs(unitReloadWatch) do
			local udid = spGetUnitDefID(unitID)
			if udid and unitDefPrimaryWeapon[udid] then
				updateReloadBar(unitID, udid)
			end
		end
	end

	-- morph finished notification housekeeping (ported from the old widget)
	if n % 30 == 1 then
		notificationTimeout = notificationTimeout - 1
		local spectator = Spring.GetSpectatingState()
		resourcePrompts = Spring.GetConfigInt("evo_resourceprompts", 1)
		if resourcePrompts == nil then
			resourcePrompts = 1
		end
		if spectator then
			resourcePrompts = 0
		end
	end
end

--------------------------------------------------------------------------------
-- Morph gadget globals (same interface the old widget registered)
--------------------------------------------------------------------------------

local function MorphUpdate(morphTable)
	UnitMorphs = morphTable or {}
	for unitID, morph in pairs(UnitMorphs) do
		if trackedUnits[unitID] then
			addBarForUnit(unitID, trackedUnits[unitID], "morph")
			uniformcache[1] = morph.progress or 0
			gl.SetUnitBufferUniforms(unitID, uniformcache, 8)
		end
	end
end

local function MorphStart(unitID, morphDef)
end

local function MorphStop(unitID)
	UnitMorphs[unitID] = nil
	removeBarFromUnit(unitID, "morph")
end

local function MorphFinished(unitID)
	if notificationTimeout <= 0 then
		if Spring.GetUnitTeam(unitID) == Spring.GetMyTeamID() then
			if resourcePrompts == 1 and WG.AddNotification then
				WG.AddNotification("morphFinished")
			end
		end
	end
	notificationTimeout = 10
	UnitMorphs[unitID] = nil
	removeBarFromUnit(unitID, "morph")
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1, 19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawScreenEffects()
	-- DrawScreenEffects runs after deferred lighting, distortion and bloom, so
	-- bar colors stay clean. Depth test still occludes against terrain because
	-- the shader does world to clip via the engine camera UBO.
	if not drawEnabled then return end
	if chobbyInterface then return end
	if not drawWhenGuiHidden and Spring.IsGUIHidden() then return end

	if healthBarVBO.usedElements > 0 or featureHealthVBO.usedElements > 0
		or featureResurrectVBO.usedElements > 0 or featureReclaimVBO.usedElements > 0 then

		local disticon = Spring.GetConfigInt("UnitIconDistance", 200) * 27.5
		gl.DepthTest(true)
		gl.DepthMask(true)
		gl.Texture(0, healthbartexture)
		healthBarShader:Activate()
		healthBarShader:SetUniform("iconDistance", disticon)
		if not debugmode then healthBarShader:SetUniform("cameraDistanceMult", 1.0) end
		healthBarShader:SetUniform("cameraDistanceMultGlyph", glphydistmult)
		healthBarShader:SetUniform("skipGlyphsNumbers", skipGlyphsNumbers)

		if healthBarVBO.usedElements > 0 then
			if useGeometryShader then
				healthBarVBO.VAO:DrawArrays(GL.POINTS, healthBarVBO.usedElements)
			else
				healthBarVBO.VAO:DrawArrays(GL.TRIANGLE_STRIP, 4, 0, healthBarVBO.usedElements)
			end
		end

		healthBarShader:SetUniform("cameraDistanceMultGlyph", glyphdistmultfeatures)
		if featureHealthVBO.usedElements > 0 then
			if not debugmode then healthBarShader:SetUniform("cameraDistanceMult", featureHealthDistMult) end
			if useGeometryShader then
				featureHealthVBO.VAO:DrawArrays(GL.POINTS, featureHealthVBO.usedElements)
			else
				featureHealthVBO.VAO:DrawArrays(GL.TRIANGLE_STRIP, 4, 0, featureHealthVBO.usedElements)
			end
		end
		if featureResurrectVBO.usedElements > 0 then
			if not debugmode then healthBarShader:SetUniform("cameraDistanceMult", featureResurrectDistMult) end
			if useGeometryShader then
				featureResurrectVBO.VAO:DrawArrays(GL.POINTS, featureResurrectVBO.usedElements)
			else
				featureResurrectVBO.VAO:DrawArrays(GL.TRIANGLE_STRIP, 4, 0, featureResurrectVBO.usedElements)
			end
		end
		if featureReclaimVBO.usedElements > 0 then
			if not debugmode then healthBarShader:SetUniform("cameraDistanceMult", featureReclaimDistMult) end
			if useGeometryShader then
				featureReclaimVBO.VAO:DrawArrays(GL.POINTS, featureReclaimVBO.usedElements)
			else
				featureReclaimVBO.VAO:DrawArrays(GL.TRIANGLE_STRIP, 4, 0, featureReclaimVBO.usedElements)
			end
		end

		healthBarShader:Deactivate()
		gl.Texture(false)
		gl.DepthTest(false)
		gl.DepthMask(false)
	end
end

--------------------------------------------------------------------------------
-- Actions, config, lifecycle
--------------------------------------------------------------------------------

local function showhealthbars(cmd, line, words)
	if words[1] and words[1] ~= "" then
		drawEnabled = (words[1] == "1")
	else
		drawEnabled = not drawEnabled
	end
end

function widget:TextCommand(command)
	if string.find(command, "debughealthbars", nil, true) == 1 then
		debugmode = not debugmode
		spEcho("Debug mode for Health Bars GL4 set to", debugmode)
		if healthBarVBO then healthBarVBO.debug = debugmode end
	end
end

function widget:Initialize()
	if not gl.CreateShader or not gl.SetUnitBufferUniforms then
		spEcho("Health Bars GL4: engine lacks required GL4 API (gl.SetUnitBufferUniforms), removing widget")
		widgetHandler:RemoveWidget()
		return
	end

	gameFrame = spGetGameFrame()

	-- take over F9 from the engine, like the old widget did
	Spring.SendCommands({ "showhealthbars 0" })
	Spring.SendCommands({ "showrezbars 0" })
	widgetHandler:AddAction("showhealthbars", showhealthbars)
	Spring.SendCommands({ "unbind f9 showhealthbars" })
	Spring.SendCommands({ "bind f9 luaui showhealthbars" })

	-- morph gadget hooks, same globals the old widget registered
	widgetHandler:RegisterGlobal('MorphUpdate', MorphUpdate)
	widgetHandler:RegisterGlobal('MorphFinished', MorphFinished)
	widgetHandler:RegisterGlobal('MorphStart', MorphStart)
	widgetHandler:RegisterGlobal('MorphStop', MorphStop)
	widgetHandler:RegisterGlobal('MorphDrawProgress', function()
		return true
	end)

	WG['healthbars'] = {}
	WG['healthbars'].getScale = function()
		return barScale
	end
	WG['healthbars'].setScale = function(value)
		barScale = value
		init()
		initfeaturebars()
	end
	WG['healthbars'].getVariableSizes = function()
		return variableBarSizes
	end
	WG['healthbars'].setVariableSizes = function(value)
		variableBarSizes = value
		init()
		initfeaturebars()
	end
	WG['healthbars'].getDrawWhenGuiHidden = function()
		return drawWhenGuiHidden
	end
	WG['healthbars'].setDrawWhenGuiHidden = function(value)
		drawWhenGuiHidden = value
	end

	if not initGL4() then
		return
	end

	init()
	initfeaturebars()
end

function widget:Shutdown()
	widgetHandler:RemoveAction("showhealthbars")
	Spring.SendCommands({ "unbind f9 luaui" })
	Spring.SendCommands({ "bind f9 showhealthbars" })

	widgetHandler:DeregisterGlobal('MorphUpdate')
	widgetHandler:DeregisterGlobal('MorphFinished')
	widgetHandler:DeregisterGlobal('MorphStart')
	widgetHandler:DeregisterGlobal('MorphStop')
	widgetHandler:DeregisterGlobal('MorphDrawProgress')

	if healthBarShader then
		healthBarShader:Finalize()
	end
	WG['healthbars'] = nil
end

function widget:GetConfigData(data)
	return {
		barScale          = barScale,
		variableBarSizes  = variableBarSizes,
		drawWhenGuiHidden = drawWhenGuiHidden,
	}
end

function widget:SetConfigData(data)
	barScale = data.barScale or barScale
	if data.variableBarSizes ~= nil then
		variableBarSizes = data.variableBarSizes
	end
	if data.drawWhenGuiHidden ~= nil then
		drawWhenGuiHidden = data.drawWhenGuiHidden
	end
end
