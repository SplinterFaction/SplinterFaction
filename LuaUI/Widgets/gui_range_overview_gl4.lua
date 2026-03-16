function widget:GetInfo()
	return {
		name    = "Range Overview GL4",
		desc    = "Displays selected unit attack, radar, seismic sensor, sight, and build ranges",
		author  = "OpenAI",
		date    = "2026-03-15",
		license = "GPL v2 or later",
		layer   = -90,
		enabled = false,
		depends = { "gl4" },
	}
end

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

local selectionDisableThreshold = 512
local tacticalFadeStart = 2800
local tacticalFadeEnd   = 8000

local showBuildForSelectedBuildersOnly = true
local showBuildWhilePlacing = true
local enableAnimatedGlow = true

-- performance knobs
local persistentRefreshFrames = 30
local persistentCullDistance = 7000
local persistentCullDistanceSq = persistentCullDistance * persistentCullDistance
local selectedOnlyInnerRings = true
local selectedOnlySweepEffects = true

local colorConfig = {
	drawStencil    = true,
	drawInnerRings = true,

	internalalpha = 0.035,
	fill_alpha    = 0.055,
	externalalpha = 0.72,
	outer_fade_height_difference = 2500,

	attack = {
		color = { 1.00, 0.14, 0.10, 0.62 },
		fadeparams = { 4000, 6000, 1.0, 0.0 },
		groupselectionfadescale = 0.78,
		externallinethickness = 3.0,
		internallinethickness = 1.8,
		stipple = 0,
		stipplePattern = 0,
		sweep = 0,
		alwaysvisible = true,
	},

	radar = {
		color = { 0.05, 1.00, 0.05, 0.72 },
		fadeparams = { 2500, 5000, 1.0, 0.0 },
		groupselectionfadescale = 0.58,
		externallinethickness = 10,
		internallinethickness = 5,
		stipple = 1,
		stipplePattern = 1, -- long dash
		sweep = 1,
		alwaysvisible = false,
	},

	sensor = {
		color = { 0.90, 0.25, 1.00, 0.72 },
		fadeparams = { 2500, 5000, 1.0, 0.0 },
		groupselectionfadescale = 0.58,
		externallinethickness = 5,
		internallinethickness = 2.5,
		stipple = 1,
		stipplePattern = 2, -- dot-dash
		sweep = 0,
		alwaysvisible = false,
	},

	sight = {
		color = { 1, 1, 1, 0.2 },
		fadeparams = { 6000, 12000, 1.0, 0.2 },
		groupselectionfadescale = 0.58,
		externallinethickness = 8,
		internallinethickness = 4,
		stipple = 0,
		stipplePattern = 0, -- sparse dots
		sweep = 0,
		alwaysvisible = true,
	},

	build = {
		color = { 0.45, 0.95, 0.15, 0.50 },
		fadeparams = { 1800, 3500, 1.0, 0.0 },
		groupselectionfadescale = 0.06,
		externallinethickness = 2.3,
		internallinethickness = 1.3,
		stipple = 0,
		stipplePattern = 0,
		sweep = 0,
		alwaysvisible = false,
	},
}

--------------------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------------------

local spGetSelectedUnits      = Spring.GetSelectedUnits
local spGetVisibleUnits       = Spring.GetVisibleUnits
local spGetUnitDefID          = Spring.GetUnitDefID
local spGetUnitPosition       = Spring.GetUnitPosition
local spGetUnitWeaponState    = Spring.GetUnitWeaponState
local spGetUnitTeam           = Spring.GetUnitTeam
local spGetMyTeamID           = Spring.GetMyTeamID
local spIsGUIHidden           = Spring.IsGUIHidden
local spGetCameraPosition     = Spring.GetCameraPosition
local spGetGroundHeight       = Spring.GetGroundHeight
local spGetActiveCommand      = Spring.GetActiveCommand
local spEcho                  = Spring.Echo

local glTexture               = gl.Texture
local glClear                 = gl.Clear
local glDepthTest             = gl.DepthTest
local glLineWidth             = gl.LineWidth
local glColorMask             = gl.ColorMask
local glStencilTest           = gl.StencilTest
local glStencilMask           = gl.StencilMask
local glStencilFunc           = gl.StencilFunc
local glStencilOp             = gl.StencilOp

local GL_STENCIL_BUFFER_BIT = GL.STENCIL_BUFFER_BIT or 0x00000400
local GL_TRIANGLE_FAN       = GL.TRIANGLE_FAN       or 0x0006
local GL_LINE_LOOP          = GL.LINE_LOOP          or 0x0002
local GL_LEQUAL             = GL.LEQUAL             or 0x0203
local GL_NOTEQUAL           = GL.NOTEQUAL           or 0x0205
local GL_KEEP               = GL.KEEP               or 0x1E00
local GL_REPLACE            = GL.REPLACE            or 0x1E01

local mathMax   = math.max
local mathSin   = math.sin

--------------------------------------------------------------------------------
-- Includes
--------------------------------------------------------------------------------

local LuaShader = VFS.Include("modules/graphics/LuaShader.lua")
local InstanceVBOTable = VFS.Include("modules/graphics/instancevbotable.lua")

local pushElementInstance = InstanceVBOTable.pushElementInstance
local popElementInstance  = InstanceVBOTable.popElementInstance

--------------------------------------------------------------------------------
-- UnitDef cache
--------------------------------------------------------------------------------

local unitBuilder         = {}
local unitBuildDistance   = {}
local unitSightDistance   = {}
local unitRadarDistance   = {}
local unitSeismicDistance = {}
local unitWeapons         = {}
local unitMaxWeaponRange  = {}

-- per-def quick filters for persistent rings
local unitHasPersistentAlwaysVisible = {}

for udid, ud in pairs(UnitDefs) do
	unitBuilder[udid]         = ud.isBuilder and (ud.canAssist or ud.canReclaim) and not (ud.isFactory and #ud.buildOptions > 0)
	unitBuildDistance[udid]   = ud.buildDistance or 0
	unitSightDistance[udid]   = ud.sightDistance or 0
	unitRadarDistance[udid]   = math.max(ud.radarDistance or 0, ud.sonarDistance or 0)
	unitSeismicDistance[udid] = ud.seismicDistance or 0
	unitWeapons[udid]         = ud.weapons or {}
	unitMaxWeaponRange[udid]  = ud.maxWeaponRange or 0
	unitHasPersistentAlwaysVisible[udid] = false
end

--------------------------------------------------------------------------------
-- GL4 setup
--------------------------------------------------------------------------------

local circleSegments = 32
local circleVBO = nil
local rangeShader = nil

local rangeClasses = { "attack", "radar", "sensor", "sight", "build" }
local rangeVAOs = {
	selected = {},
	mine     = {},
	other    = {},
}

local circleInstanceVBOLayout = {
	{ id = 1, name = 'posscale',         size = 4 },
	{ id = 2, name = 'color1',           size = 4 },
	{ id = 3, name = 'visibility',       size = 4 },
	{ id = 4, name = 'projectileParams', size = 4 },
	{ id = 5, name = 'additionalParams', size = 4 },
	{ id = 6, name = 'instData',         size = 4, type = GL.UNSIGNED_INT },
}

local shaderSourceCache = {
	shaderName = 'Range Overview GL4',
	vssrcpath = "LuaUI/Shaders/range_overview_gl4.vert.glsl",
	fssrcpath = "LuaUI/Shaders/range_overview_gl4.frag.glsl",
	shaderConfig = {
		MYGRAVITY = Game.gravity + 0.1,
		STATICUNITS = 0,
		DEBUG = 0,
		MOUSEOVERALPHAMULTIPLIER = 1.0,
		RANGE_OVERVIEW_EXTRAS = 1,
	},
	uniformInt = {
		heightmapTex = 0,
		losTex = 1,
		mapNormalTex = 2,
	},
	uniformFloat = {
		lineAlphaUniform = 1,
		cannonmode = 0,
		fadeDistOffset = 0,
		drawMode = 0,
		selUnitCount = 1.0,
		selBuilderCount = 0.0,
		inMiniMap = 0.0,
		pipVisibleArea = {0, 1, 0, 1},
		timeSeconds = 0.0,
		tacticalAlphaMult = 1.0,
		bucketMode = 0.0, -- 0 selected, 1 mine persistent, 2 other persistent
	},
}

local function goodbye(reason)
	spEcho("Range Overview GL4 exiting: " .. reason)
	widgetHandler:RemoveWidget()
end

local function makeShaders()
	rangeShader = LuaShader.CheckShaderUpdates(shaderSourceCache, 0) or rangeShader
	if not rangeShader then
		goodbye("failed to compile shader")
		return false
	end
	return true
end

local function initGL4()
	circleVBO = InstanceVBOTable.makeCircleVBO(circleSegments)

	for _, bucket in ipairs({ "selected", "mine", "other" }) do
		for _, className in ipairs(rangeClasses) do
			rangeVAOs[bucket][className] = InstanceVBOTable.makeInstanceVBOTable(
					circleInstanceVBOLayout,
					24,
					bucket .. "_" .. className .. "_rangeoverview_gl4",
					6
			)

			rangeVAOs[bucket][className].vertexVBO = circleVBO
			rangeVAOs[bucket][className].VAO = InstanceVBOTable.makeVAOandAttach(
					rangeVAOs[bucket][className].vertexVBO,
					rangeVAOs[bucket][className].instanceVBO
			)
		end
	end

	return makeShaders()
end

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local myTeamID = spGetMyTeamID()

local selectedUnits = {}
local selUnits = {}
local selections = {}
local persistentUnitsMine = {}
local persistentUnitsOther = {}
local selUnitCount = 0
local selBuilderCount = 0
local updateSelection = false
local gameFrame = 0
local isBuilding = false

local cacheTable = {}
for i = 1, 24 do
	cacheTable[i] = 0
end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function ClassAlwaysVisible(className)
	local cfg = colorConfig[className]
	return cfg and cfg.alwaysvisible == true
end

local function AnyAlwaysVisibleClass()
	for _, className in ipairs(rangeClasses) do
		if ClassAlwaysVisible(className) then
			return true
		end
	end
	return false
end

local function RebuildPersistentDefFlags()
	for udid in pairs(UnitDefs) do
		local has = false
		if ClassAlwaysVisible("attack") and (unitMaxWeaponRange[udid] or 0) > 0 then has = true end
		if ClassAlwaysVisible("radar")  and (unitRadarDistance[udid] or 0) > 0 then has = true end
		if ClassAlwaysVisible("sensor") and (unitSeismicDistance[udid] or 0) > 0 then has = true end
		if ClassAlwaysVisible("sight")  and (unitSightDistance[udid] or 0) > 0 then has = true end
		if ClassAlwaysVisible("build")  and unitBuilder[udid] and (unitBuildDistance[udid] or 0) > 0 then has = true end
		unitHasPersistentAlwaysVisible[udid] = has
	end
end

local function GetAttackRange(unitID, unitDefID)
	local weapons = unitWeapons[unitDefID]
	if not weapons or #weapons == 0 then
		return unitMaxWeaponRange[unitDefID] or 0
	end

	local best = 0
	for weaponNum = 1, #weapons do
		local r = spGetUnitWeaponState(unitID, weaponNum, "range")
		if not r then
			local weaponDefID = weapons[weaponNum].weaponDef
			local wd = weaponDefID and WeaponDefs[weaponDefID]
			r = (wd and wd.range) or 0
		end
		if r > best then
			best = r
		end
	end
	return best
end

local function classToStencilMask(className)
	if className == "attack" then return 1 end
	if className == "radar"  then return 2 end
	if className == "sensor" then return 4 end
	if className == "sight"  then return 8 end
	if className == "build"  then return 16 end
	return 1
end

local function classToAdditionalType(className)
	if className == "attack" then
		return 1
	end
	return 2
end

local function classToFlags(className)
	local cfg = colorConfig[className]
	if not cfg then
		return 0
	end

	local flags = 0
	if (cfg.stipple or 0) ~= 0 then
		flags = flags + 1
	end
	if (cfg.sweep or 0) ~= 0 then
		flags = flags + 2
	end
	return flags
end

local function classToStipplePattern(className)
	local cfg = colorConfig[className]
	if not cfg then
		return 0
	end
	return cfg.stipplePattern or 0
end

local function IsBuilderSelected()
	for i = 1, #selectedUnits do
		local unitDefID = spGetUnitDefID(selectedUnits[i])
		if unitDefID and unitBuilder[unitDefID] then
			return true
		end
	end
	return false
end

local function ShouldShowBuildRange(unitDefID)
	if not unitBuilder[unitDefID] then
		return false
	end
	if showBuildForSelectedBuildersOnly and IsBuilderSelected() then
		return true
	end
	if showBuildWhilePlacing and isBuilding then
		return true
	end
	return not showBuildForSelectedBuildersOnly
end

local function GetCameraHeightFactor()
	local cx, cy, cz = spGetCameraPosition()
	if not cy then
		return 1.0, 1.0
	end
	local gh = spGetGroundHeight(cx, cz)
	local camHeight = cy - gh

	if camHeight <= tacticalFadeStart then
		return 1.0, 1.0
	end
	if camHeight >= tacticalFadeEnd then
		return 0.28, 0.65
	end

	local t = (camHeight - tacticalFadeStart) / (tacticalFadeEnd - tacticalFadeStart)
	local alphaMult = 1.0 - t * 0.72
	local thicknessMult = 1.0 - t * 0.35
	return alphaMult, thicknessMult
end

local function MakeInstanceID(unitID, classOffset)
	return unitID * 16 + classOffset
end

local function AddRangeInstance(unitID, className, radius, x, z, vaoBucket)
	if not radius or radius <= 0 then
		return nil
	end

	local cfg = colorConfig[className]
	if not cfg then
		return nil
	end

	cacheTable[1]  = x
	cacheTable[2]  = 0
	cacheTable[3]  = z
	cacheTable[4]  = radius

	cacheTable[5]  = cfg.color[1]
	cacheTable[6]  = cfg.color[2]
	cacheTable[7]  = cfg.color[3]
	cacheTable[8]  = cfg.color[4]

	cacheTable[9]  = cfg.fadeparams[1]
	cacheTable[10] = cfg.fadeparams[2]
	cacheTable[11] = cfg.fadeparams[3]
	cacheTable[12] = cfg.fadeparams[4]

	cacheTable[13] = 1
	cacheTable[14] = 0
	cacheTable[15] = 0
	cacheTable[16] = 0

	cacheTable[17] = cfg.groupselectionfadescale
	cacheTable[18] = classToAdditionalType(className)
	cacheTable[19] = classToFlags(className)
	cacheTable[20] = classToStipplePattern(className)

	cacheTable[21] = unitID
	cacheTable[22] = 0
	cacheTable[23] = 0
	cacheTable[24] = 0

	local classOffset = ({
		attack = 1,
		radar  = 2,
		sensor = 3,
		sight  = 4,
		build  = 5,
	})[className] or 0

	local instanceID = MakeInstanceID(unitID, classOffset)
	pushElementInstance(rangeVAOs[vaoBucket][className], cacheTable, instanceID, true, false, unitID)
	return instanceID
end

local function AddUnitToCollection(unitID, collection, isPersistent)
	if collection[unitID] then
		return
	end

	local unitDefID = spGetUnitDefID(unitID)
	if not unitDefID then
		return
	end

	local x, _, z = spGetUnitPosition(unitID, true, true)
	if not x then
		return
	end

	local vaoBucket
	if collection == selections then
		vaoBucket = "selected"
	elseif collection == persistentUnitsMine then
		vaoBucket = "mine"
	else
		vaoBucket = "other"
	end

	local entry = {
		unitDefID = unitDefID,
		vaokeys = {},
		vaoBucket = vaoBucket,
	}

	local function maybeAdd(className, radius)
		if isPersistent and not ClassAlwaysVisible(className) then
			return
		end
		local id = AddRangeInstance(unitID, className, radius, x, z, vaoBucket)
		if id then
			entry.vaokeys[id] = className
		end
	end

	-- Selected units can compute all rings.
	-- Persistent units avoid unnecessary work for classes that are not alwaysvisible.
	if not isPersistent or ClassAlwaysVisible("attack") then
		maybeAdd("attack", GetAttackRange(unitID, unitDefID))
	end
	if not isPersistent or ClassAlwaysVisible("radar") then
		maybeAdd("radar", unitRadarDistance[unitDefID] or 0)
	end
	if not isPersistent or ClassAlwaysVisible("sensor") then
		maybeAdd("sensor", unitSeismicDistance[unitDefID] or 0)
	end
	if not isPersistent or ClassAlwaysVisible("sight") then
		maybeAdd("sight", unitSightDistance[unitDefID] or 0)
	end
	if not isPersistent or ClassAlwaysVisible("build") then
		local buildRange = ShouldShowBuildRange(unitDefID) and (unitBuildDistance[unitDefID] or 0) or 0
		maybeAdd("build", buildRange)
	end

	collection[unitID] = entry
end

local function RemoveUnitFromCollection(unitID, collection)
	local entry = collection[unitID]
	if not entry then
		return
	end

	for instanceID, vaoKey in pairs(entry.vaokeys) do
		popElementInstance(rangeVAOs[entry.vaoBucket][vaoKey], instanceID)
	end

	collection[unitID] = nil
end

local RefreshSelectedUnits

local function RefreshPersistentUnits()
	if not AnyAlwaysVisibleClass() then
		for unitID in pairs(persistentUnitsMine) do
			RemoveUnitFromCollection(unitID, persistentUnitsMine)
		end
		for unitID in pairs(persistentUnitsOther) do
			RemoveUnitFromCollection(unitID, persistentUnitsOther)
		end
		return
	end

	local cx, _, cz = spGetCameraPosition()
	local visibleUnits = spGetVisibleUnits(-1, nil, false)
	local stillVisibleMine = {}
	local stillVisibleOther = {}

	for i = 1, #visibleUnits do
		local unitID = visibleUnits[i]
		local unitDefID = spGetUnitDefID(unitID)

		if unitDefID and unitHasPersistentAlwaysVisible[unitDefID] and not selections[unitID] then
			local x, _, z = spGetUnitPosition(unitID, true, true)
			if x then
				local dx = x - cx
				local dz = z - cz
				if (dx * dx + dz * dz) <= persistentCullDistanceSq then
					local unitTeam = spGetUnitTeam(unitID)

					if unitTeam == myTeamID then
						stillVisibleMine[unitID] = true
						if not persistentUnitsMine[unitID] then
							AddUnitToCollection(unitID, persistentUnitsMine, true)
						end
					else
						stillVisibleOther[unitID] = true
						if not persistentUnitsOther[unitID] then
							AddUnitToCollection(unitID, persistentUnitsOther, true)
						end
					end
				end
			end
		end
	end

	for unitID in pairs(persistentUnitsMine) do
		if not stillVisibleMine[unitID] or selections[unitID] then
			RemoveUnitFromCollection(unitID, persistentUnitsMine)
		end
	end

	for unitID in pairs(persistentUnitsOther) do
		if not stillVisibleOther[unitID] or selections[unitID] then
			RemoveUnitFromCollection(unitID, persistentUnitsOther)
		end
	end
end

local function RebuildCollections()
	for unitID in pairs(selections) do
		RemoveUnitFromCollection(unitID, selections)
	end
	for unitID in pairs(persistentUnitsMine) do
		RemoveUnitFromCollection(unitID, persistentUnitsMine)
	end
	for unitID in pairs(persistentUnitsOther) do
		RemoveUnitFromCollection(unitID, persistentUnitsOther)
	end
	selUnits = {}
	RefreshSelectedUnits()
	RefreshPersistentUnits()
end

RefreshSelectedUnits = function()
	local newSelUnits = {}

	for i = 1, #selectedUnits do
		local unitID = selectedUnits[i]
		newSelUnits[unitID] = true

		if not selUnits[unitID] and selUnitCount < selectionDisableThreshold then
			if persistentUnitsMine[unitID] then
				RemoveUnitFromCollection(unitID, persistentUnitsMine)
			end
			if persistentUnitsOther[unitID] then
				RemoveUnitFromCollection(unitID, persistentUnitsOther)
			end
			AddUnitToCollection(unitID, selections, false)
		end
	end

	for unitID in pairs(selUnits) do
		if not newSelUnits[unitID] then
			RemoveUnitFromCollection(unitID, selections)

			if AnyAlwaysVisibleClass() then
				local unitDefID = spGetUnitDefID(unitID)
				if unitDefID and unitHasPersistentAlwaysVisible[unitDefID] then
					local unitTeam = spGetUnitTeam(unitID)
					if unitTeam == myTeamID then
						AddUnitToCollection(unitID, persistentUnitsMine, true)
					else
						AddUnitToCollection(unitID, persistentUnitsOther, true)
					end
				end
			end
		end
	end

	selUnits = newSelUnits
end

local function UpdateSelectedUnits()
	selectedUnits = spGetSelectedUnits()
	selUnitCount = #selectedUnits

	selBuilderCount = 0
	for i = 1, #selectedUnits do
		local udid = spGetUnitDefID(selectedUnits[i])
		if udid and unitBuilder[udid] and ShouldShowBuildRange(udid) then
			selBuilderCount = selBuilderCount + 1
		end
	end

	updateSelection = false
	RefreshSelectedUnits()
	RefreshPersistentUnits()
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------

local function DRAWRINGS(bucket, primitiveType, thicknessKey, thicknessMult)
	local ordered = { "build", "radar", "sensor", "sight", "attack" }

	for i = 1, #ordered do
		local className = ordered[i]
		local vao = rangeVAOs[bucket][className]

		if vao and vao.VAO and vao.usedElements and vao.usedElements > 0 then
			if thicknessKey then
				local width = colorConfig[className] and colorConfig[className][thicknessKey]
				if width then
					glLineWidth(width * thicknessMult)
				end
			end

			local stencilMask = classToStencilMask(className)
			glStencilMask(stencilMask)
			glStencilFunc(GL_NOTEQUAL, stencilMask, stencilMask)
			vao.VAO:DrawArrays(primitiveType, circleSegments, 0, vao.usedElements, 0)
		end
	end
end

local function bucketModeValue(bucket)
	if bucket == "selected" then return 0.0 end
	if bucket == "mine" then return 1.0 end
	return 2.0
end

local function DrawStencilPass(bucket, alphaMult, thicknessMult, timeSeconds)
	glClear(GL_STENCIL_BUFFER_BIT)
	glDepthTest(false)

	glStencilTest(true)
	glStencilMask(255)
	glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE)

	rangeShader:SetUniform("selUnitCount", selUnitCount)
	rangeShader:SetUniform("selBuilderCount", selBuilderCount)
	rangeShader:SetUniform("drawMode", 0.0)
	rangeShader:SetUniform("inMiniMap", 0.0)
	rangeShader:SetUniform("drawAlpha", colorConfig.fill_alpha * alphaMult)
	rangeShader:SetUniform("fadeDistOffset", colorConfig.outer_fade_height_difference)
	rangeShader:SetUniform("cannonmode", 0)
	rangeShader:SetUniform("timeSeconds", timeSeconds)
	rangeShader:SetUniform("tacticalAlphaMult", alphaMult)
	rangeShader:SetUniform("bucketMode", bucketModeValue(bucket))

	DRAWRINGS(bucket, GL_TRIANGLE_FAN, nil, thicknessMult)

	glColorMask(true, true, true, true)
	glStencilMask(0)
	glDepthTest(GL_LEQUAL)

	local pulse = 1.0
	if enableAnimatedGlow then
		pulse = 0.92 + 0.08 * mathSin(timeSeconds * 2.2)
	end

	rangeShader:SetUniform("lineAlphaUniform", colorConfig.externalalpha * alphaMult * pulse)
	rangeShader:SetUniform("drawMode", 1.0)
	rangeShader:SetUniform("drawAlpha", 1.0)

	DRAWRINGS(bucket, GL_LINE_LOOP, "externallinethickness", thicknessMult)

	glStencilTest(false)
	glStencilMask(255)
	glStencilOp(GL_KEEP, GL_KEEP, GL_KEEP)
	glClear(GL_STENCIL_BUFFER_BIT)
end

local function DrawInnerPass(bucket, alphaMult, thicknessMult)
	rangeShader:SetUniform("lineAlphaUniform", colorConfig.internalalpha * alphaMult)
	rangeShader:SetUniform("drawMode", 2.0)
	rangeShader:SetUniform("fadeDistOffset", 0)
	rangeShader:SetUniform("cannonmode", 0)
	rangeShader:SetUniform("bucketMode", bucketModeValue(bucket))

	DRAWRINGS(bucket, GL_LINE_LOOP, "internallinethickness", thicknessMult)
end

--------------------------------------------------------------------------------
-- Widget callins
--------------------------------------------------------------------------------

function widget:Initialize()
	if not initGL4() then
		widgetHandler:RemoveWidget(self)
		return
	end
	myTeamID = spGetMyTeamID()
	RebuildPersistentDefFlags()
	updateSelection = true
end

function widget:Shutdown()
end

function widget:SelectionChanged()
	updateSelection = true
end

function widget:PlayerChanged()
	myTeamID = spGetMyTeamID()
	updateSelection = true
	RebuildCollections()
end

function widget:GameFrame(gf)
	gameFrame = gf
end

function widget:VisibleUnitRemoved(unitID)
	if persistentUnitsMine[unitID] then
		RemoveUnitFromCollection(unitID, persistentUnitsMine)
	end
	if persistentUnitsOther[unitID] then
		RemoveUnitFromCollection(unitID, persistentUnitsOther)
	end
end

function widget:Update()
	if updateSelection and gameFrame % 3 == 0 then
		UpdateSelectedUnits()
	end

	local _, cmdID = spGetActiveCommand()
	local buildingNow = (cmdID ~= nil and cmdID < 0)

	if buildingNow ~= isBuilding then
		isBuilding = buildingNow
		RebuildCollections()
	end

	if gameFrame % persistentRefreshFrames == 0 then
		RefreshPersistentUnits()
	end
end

function widget:DrawWorld()
	if spIsGUIHidden() then return end

	local hasAny =
	(selUnitCount > 0) or
			(next(persistentUnitsMine) ~= nil) or
			(next(persistentUnitsOther) ~= nil)

	if not hasAny then return end

	local alphaMult, thicknessMult = GetCameraHeightFactor()
	local timeSeconds = gameFrame / 30.0

	glTexture(0, "$heightmap")
	glTexture(1, "$info")
	glTexture(2, "$normals")

	rangeShader:Activate()

	if colorConfig.drawStencil then
		DrawStencilPass("selected", alphaMult, thicknessMult, timeSeconds)
		DrawStencilPass("mine",     alphaMult, thicknessMult, timeSeconds)
		DrawStencilPass("other",    alphaMult, thicknessMult, timeSeconds)
	end

	if colorConfig.drawInnerRings then
		DrawInnerPass("selected", alphaMult, thicknessMult)
		if not selectedOnlyInnerRings then
			DrawInnerPass("mine",  alphaMult, thicknessMult)
			DrawInnerPass("other", alphaMult, thicknessMult)
		end
	end

	rangeShader:Deactivate()

	glTexture(0, false)
	glTexture(1, false)
	glTexture(2, false)
	glDepthTest(false)
end