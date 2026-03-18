function widget:GetInfo()
	return {
		name    = "Range Overview GL4",
		desc    = "Fast GL4 range rings for selected units, allied sight, static defenses, and mouseover",
		author  = "OpenAI",
		date    = "2026-03-17",
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

-- Increase for smoother circles, decrease for fewer vertices and slightly better performance
local circleDivs = 48

local showBuildForSelectedBuildersOnly = true
local showBuildWhilePlacing            = true

local persistentRefreshFrames = 20
local persistentCullDistance  = 6500
local persistentCullDistanceSq = persistentCullDistance * persistentCullDistance
local mouseoverRefreshFrames  = 3
local selectedOnlyInnerRings  = true

local persistentAlliedSight         = true
local persistentStaticDefenseAttack = true
local persistentAlliedDefenseAttack = true
local persistentEnemyDefenseAttack  = true
local enableMouseoverRings          = true

-- Per-ring enable flags. Set any of these to false to completely skip maintaining
-- and drawing that ring class. This is the best place to expose player options later.
local ringEnabled = {
	attack = true,
	radar  = true,
	sensor = true,
	sight  = true,
	build  = true,
}

local colorConfig = {
	drawStencil    = true,
	drawInnerRings = false,	-- disabled: merged outer rings only

	internalalpha = 0,
	fill_alpha    = 0,
	externalalpha = 1,
	outer_fade_height_difference = 2500,

	attack = {
		color = { 1.00, 0.14, 0.10, 0.62 },
		fadeparams = { 4000, 6000, 1.0, 0.0 },
		groupselectionfadescale = 0.78,
		externallinethickness = 3.0,
		internallinethickness = 1.8,
	},

	radar = {
		color = { 0.05, 1.00, 0.05, 0.70 },
		fadeparams = { 2500, 5000, 1.0, 0.0 },
		groupselectionfadescale = 0.58,
		externallinethickness = 6.0,
		internallinethickness = 3.0,
	},

	sensor = {
		color = { 0.90, 0.25, 1.00, 0.70 },
		fadeparams = { 2500, 5000, 1.0, 0.0 },
		groupselectionfadescale = 0.58,
		externallinethickness = 4.0,
		internallinethickness = 2.0,
	},

	sight = {
		color = { 1.00, 1.00, 1.00, 0.20 },
		fadeparams = { 6000, 12000, 1.0, 0.2 },
		groupselectionfadescale = 0.58,
		externallinethickness = 10.0,
		internallinethickness = 2.5,
	},

	build = {
		color = { 0.45, 0.95, 0.15, 0.50 },
		fadeparams = { 1800, 3500, 1.0, 0.0 },
		groupselectionfadescale = 0.06,
		externallinethickness = 2.3,
		internallinethickness = 1.3,
	},
}

--------------------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------------------

local spGetSelectedUnits   = Spring.GetSelectedUnits
local spGetVisibleUnits    = Spring.GetVisibleUnits
local spGetUnitDefID       = Spring.GetUnitDefID
local spGetUnitPosition    = Spring.GetUnitPosition
local spGetUnitWeaponState = Spring.GetUnitWeaponState
local spGetUnitTeam        = Spring.GetUnitTeam
local spGetMyTeamID        = Spring.GetMyTeamID
local spGetMyAllyTeamID    = Spring.GetMyAllyTeamID
local spGetUnitAllyTeam    = Spring.GetUnitAllyTeam
local spIsGUIHidden        = Spring.IsGUIHidden
local spGetCameraPosition  = Spring.GetCameraPosition
local spGetGroundHeight    = Spring.GetGroundHeight
local spGetActiveCommand   = Spring.GetActiveCommand
local spGetMouseState      = Spring.GetMouseState
local spTraceScreenRay     = Spring.TraceScreenRay
local spEcho               = Spring.Echo

local glTexture     = gl.Texture
local glClear       = gl.Clear
local glDepthTest   = gl.DepthTest
local glLineWidth   = gl.LineWidth
local glColorMask   = gl.ColorMask
local glStencilTest = gl.StencilTest
local glStencilMask = gl.StencilMask
local glStencilFunc = gl.StencilFunc
local glStencilOp   = gl.StencilOp

local GL_STENCIL_BUFFER_BIT = GL.STENCIL_BUFFER_BIT or 0x00000400
local GL_TRIANGLE_FAN       = GL.TRIANGLE_FAN       or 0x0006
local GL_LINE_LOOP          = GL.LINE_LOOP          or 0x0002
local GL_LEQUAL             = GL.LEQUAL             or 0x0203
local GL_NOTEQUAL           = GL.NOTEQUAL           or 0x0205
local GL_KEEP               = GL.KEEP               or 0x1E00
local GL_REPLACE            = GL.REPLACE            or 0x1E01

--------------------------------------------------------------------------------
-- Includes
--------------------------------------------------------------------------------

local LuaShader        = VFS.Include("modules/graphics/LuaShader.lua")
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
local unitIsStaticDefense = {}

for udid, ud in pairs(UnitDefs) do
	unitBuilder[udid]         = ud.isBuilder and (ud.canAssist or ud.canReclaim) and not (ud.isFactory and #ud.buildOptions > 0)
	unitBuildDistance[udid]   = ud.buildDistance or 0
	unitSightDistance[udid]   = ud.sightDistance or 0
	unitRadarDistance[udid]   = math.max(ud.radarDistance or 0, ud.sonarDistance or 0)
	unitSeismicDistance[udid] = ud.seismicDistance or 0
	unitWeapons[udid]         = ud.weapons or {}
	unitMaxWeaponRange[udid]  = ud.maxWeaponRange or 0

	local hasAttack = (ud.maxWeaponRange or 0) > 0
	local mobile = (ud.speed or 0) > 0 or ud.canMove == true
	local builderOnly = unitBuilder[udid] and not hasAttack
	unitIsStaticDefense[udid] = hasAttack and (not mobile) and (not builderOnly)
end

--------------------------------------------------------------------------------
-- GL4 setup
--------------------------------------------------------------------------------

local circleSegments = math.max(8, circleDivs or 32)
local circleVBO = nil
local rangeShader = nil

local rangeClasses = { "attack", "radar", "sensor", "sight", "build" }
local rangeVAOs = {
	selected  = {},
	mine      = {},
	other     = {},
	mouseover = {},
}

local circleInstanceVBOLayout = {
	{ id = 1, name = "posscale",         size = 4 },
	{ id = 2, name = "color1",           size = 4 },
	{ id = 3, name = "visibility",       size = 4 },
	{ id = 4, name = "projectileParams", size = 4 },
	{ id = 5, name = "additionalParams", size = 4 },
	{ id = 6, name = "instData",         size = 4, type = GL.UNSIGNED_INT },
}

local shaderSourceCache = {
	shaderName = "Range Overview GL4",
	vssrcpath = "LuaUI/Shaders/range_overview_gl4.vert.glsl",
	fssrcpath = "LuaUI/Shaders/range_overview_gl4.frag.glsl",
	shaderConfig = {
		MYGRAVITY = Game.gravity + 0.1,
		STATICUNITS = 0,
		DEBUG = 0,
		MOUSEOVERALPHAMULTIPLIER = 1.0,
		RANGE_OVERVIEW_EXTRAS = 0,
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
		bucketMode = 0.0,
		drawAlpha = 1.0,
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

	for _, bucket in ipairs({ "selected", "mine", "other", "mouseover" }) do
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
local myAllyTeamID = spGetMyAllyTeamID()
local gameFrame = 0
local isBuilding = false

local selectedUnits = {}
local selectedSet = {}
local selections = {}
local persistentUnitsMine = {}
local persistentUnitsOther = {}
local mouseovers = {}
local mouseoverUnitID = nil

local selUnitCount = 0
local selBuilderCount = 0

local dirtySelection = false
local dirtyBuildState = false

local cacheTable = {}
for i = 1, 24 do
	cacheTable[i] = 0
end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local classOffsets = {
	attack = 1,
	radar  = 2,
	sensor = 3,
	sight  = 4,
	build  = 5,
}

local drawOrder = { "build", "radar", "sensor", "sight", "attack" }

local function IsRingClassEnabled(className)
	return ringEnabled[className] ~= false
end

local function WantsClassForMode(mode, className)
	if not IsRingClassEnabled(className) then
		return false
	end
	if mode == "selected" or mode == "mouseover" then
		if className == "build" then
			return true
		end
		return className == "attack" or className == "radar" or className == "sensor" or className == "sight"
	elseif mode == "persistent_sight" then
		return className == "sight"
	elseif mode == "persistent_attack" then
		return className == "attack"
	elseif mode == "persistent_combo" then
		return className == "sight" or className == "attack"
	end
	return false
end

local function IsAllied(unitID)
	return spGetUnitAllyTeam(unitID) == myAllyTeamID
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

local function ShouldShowBuildRange(unitDefID)
	if not unitBuilder[unitDefID] then
		return false
	end
	if showBuildWhilePlacing and isBuilding then
		return true
	end
	if showBuildForSelectedBuildersOnly then
		return selBuilderCount > 0
	end
	return true
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

local function MakeInstanceID(unitID, className, bucket)
	local bucketBase = 0
	if bucket == "mine" then bucketBase = 100000000 end
	if bucket == "other" then bucketBase = 200000000 end
	if bucket == "mouseover" then bucketBase = 300000000 end
	return bucketBase + unitID * 16 + (classOffsets[className] or 0)
end

local function classToStencilMask(className)
	if className == "attack" then return 1 end
	if className == "radar"  then return 2 end
	if className == "sensor" then return 4 end
	if className == "sight"  then return 8 end
	if className == "build"  then return 16 end
	return 1
end

local function bucketModeValue(bucket)
	if bucket == "selected" then return 0.0 end
	if bucket == "mine" then return 1.0 end
	if bucket == "other" then return 2.0 end
	return 0.0
end

local function AddRangeInstance(unitID, className, radius, x, z, vaoBucket, alphaScale)
	if not IsRingClassEnabled(className) then
		return nil
	end
	if not radius or radius <= 0 then
		return nil
	end

	local cfg = colorConfig[className]
	if not cfg then
		return nil
	end

	alphaScale = alphaScale or 1.0

	cacheTable[1]  = x
	cacheTable[2]  = 0
	cacheTable[3]  = z
	cacheTable[4]  = radius

	cacheTable[5]  = cfg.color[1]
	cacheTable[6]  = cfg.color[2]
	cacheTable[7]  = cfg.color[3]
	cacheTable[8]  = cfg.color[4] * alphaScale

	cacheTable[9]  = cfg.fadeparams[1]
	cacheTable[10] = cfg.fadeparams[2]
	cacheTable[11] = cfg.fadeparams[3]
	cacheTable[12] = cfg.fadeparams[4]

	cacheTable[13] = 1
	cacheTable[14] = 0
	cacheTable[15] = 0
	cacheTable[16] = 0

	cacheTable[17] = cfg.groupselectionfadescale
	cacheTable[18] = (className == "attack") and 1 or 2
	cacheTable[19] = 0
	cacheTable[20] = 0

	cacheTable[21] = unitID
	cacheTable[22] = 0
	cacheTable[23] = 0
	cacheTable[24] = 0

	local instanceID = MakeInstanceID(unitID, className, vaoBucket)
	pushElementInstance(rangeVAOs[vaoBucket][className], cacheTable, instanceID, true, false, unitID)
	return instanceID
end

local function RemoveUnitFromCollection(unitID, collection)
	local entry = collection[unitID]
	if not entry then return end

	for className, instanceID in pairs(entry.instances) do
		popElementInstance(rangeVAOs[entry.vaoBucket][className], instanceID)
	end

	collection[unitID] = nil
end

local function AddUnitToCollection(unitID, collection, mode)
	if collection[unitID] then return end

	local unitDefID = spGetUnitDefID(unitID)
	if not unitDefID then return end

	local x, _, z = spGetUnitPosition(unitID, true, true)
	if not x then return end

	local vaoBucket = "selected"
	if collection == persistentUnitsMine then
		vaoBucket = "mine"
	elseif collection == persistentUnitsOther then
		vaoBucket = "other"
	elseif collection == mouseovers then
		vaoBucket = "mouseover"
	end

	local alphaScale = (vaoBucket == "mouseover") and 1.15 or 1.0
	local entry = {
		unitDefID = unitDefID,
		vaoBucket = vaoBucket,
		instances = {},
	}

	local function maybeAdd(className, radius)
		if not WantsClassForMode(mode, className) then
			return
		end
		local instanceID = AddRangeInstance(unitID, className, radius, x, z, vaoBucket, alphaScale)
		if instanceID then
			entry.instances[className] = instanceID
		end
	end

	if mode == "selected" then
		maybeAdd("attack", GetAttackRange(unitID, unitDefID))
		maybeAdd("radar",  unitRadarDistance[unitDefID] or 0)
		maybeAdd("sensor", unitSeismicDistance[unitDefID] or 0)
		maybeAdd("sight",  unitSightDistance[unitDefID] or 0)
		if ShouldShowBuildRange(unitDefID) then
			maybeAdd("build", unitBuildDistance[unitDefID] or 0)
		end
	elseif mode == "persistent_sight" then
		maybeAdd("sight", unitSightDistance[unitDefID] or 0)
	elseif mode == "persistent_attack" then
		maybeAdd("attack", GetAttackRange(unitID, unitDefID))
	elseif mode == "persistent_combo" then
		maybeAdd("sight", unitSightDistance[unitDefID] or 0)
		maybeAdd("attack", GetAttackRange(unitID, unitDefID))
	elseif mode == "mouseover" then
		maybeAdd("attack", GetAttackRange(unitID, unitDefID))
		maybeAdd("radar",  unitRadarDistance[unitDefID] or 0)
		maybeAdd("sensor", unitSeismicDistance[unitDefID] or 0)
		maybeAdd("sight",  unitSightDistance[unitDefID] or 0)
		if ShouldShowBuildRange(unitDefID) then
			maybeAdd("build", unitBuildDistance[unitDefID] or 0)
		end
	end

	if next(entry.instances) then
		collection[unitID] = entry
	end
end

local function RefreshSelectedUnits()
	local newSet = {}
	for i = 1, #selectedUnits do
		newSet[selectedUnits[i]] = true
	end

	for unitID in pairs(selectedSet) do
		if not newSet[unitID] then
			RemoveUnitFromCollection(unitID, selections)
		end
	end

	if selUnitCount < selectionDisableThreshold then
		for i = 1, #selectedUnits do
			local unitID = selectedUnits[i]
			if not selections[unitID] then
				if persistentUnitsMine[unitID] then
					RemoveUnitFromCollection(unitID, persistentUnitsMine)
				end
				if persistentUnitsOther[unitID] then
					RemoveUnitFromCollection(unitID, persistentUnitsOther)
				end
				AddUnitToCollection(unitID, selections, "selected")
			end
		end
	else
		for unitID in pairs(selections) do
			RemoveUnitFromCollection(unitID, selections)
		end
	end

	selectedSet = newSet
end

local function RefreshSelectedBuildRingsOnly()
	for unitID, entry in pairs(selections) do
		local unitDefID = entry.unitDefID
		local hasBuild = entry.instances.build ~= nil
		local shouldHave = IsRingClassEnabled("build") and ShouldShowBuildRange(unitDefID) and (unitBuildDistance[unitDefID] or 0) > 0

		if hasBuild and not shouldHave then
			popElementInstance(rangeVAOs[entry.vaoBucket].build, entry.instances.build)
			entry.instances.build = nil
		elseif shouldHave and not hasBuild then
			local x, _, z = spGetUnitPosition(unitID, true, true)
			if x then
				entry.instances.build = AddRangeInstance(unitID, "build", unitBuildDistance[unitDefID], x, z, entry.vaoBucket)
			end
		end
	end
end

local function UpdateSelectionState()
	selectedUnits = spGetSelectedUnits()
	selUnitCount = #selectedUnits

	selBuilderCount = 0
	for i = 1, #selectedUnits do
		local udid = spGetUnitDefID(selectedUnits[i])
		if udid and unitBuilder[udid] then
			selBuilderCount = selBuilderCount + 1
		end
	end

	RefreshSelectedUnits()
	dirtySelection = false
end

local function RefreshPersistentUnits()
	local cx, _, cz = spGetCameraPosition()
	local visibleUnits = spGetVisibleUnits(-1, nil, false)

	local keepMine = {}
	local keepOther = {}

	for i = 1, #visibleUnits do
		local unitID = visibleUnits[i]
		if not selectedSet[unitID] and unitID ~= mouseoverUnitID then
			local unitDefID = spGetUnitDefID(unitID)
			if unitDefID then
				local x, _, z = spGetUnitPosition(unitID, true, true)
				if x then
					local dx = x - cx
					local dz = z - cz
					if (dx * dx + dz * dz) <= persistentCullDistanceSq then
						local allied = IsAllied(unitID)
						local isStaticDefense = unitIsStaticDefense[unitDefID]
						local wantsAlliedSight = allied and persistentAlliedSight and (unitSightDistance[unitDefID] or 0) > 0
						local wantsAlliedDefenseAttack = allied and persistentAlliedDefenseAttack and persistentStaticDefenseAttack and isStaticDefense
						local wantsEnemyDefenseAttack = (not allied) and persistentEnemyDefenseAttack and persistentStaticDefenseAttack and isStaticDefense

						if allied and (wantsAlliedSight or wantsAlliedDefenseAttack) then
							keepMine[unitID] = true
							local desiredMode = (wantsAlliedSight and wantsAlliedDefenseAttack) and "persistent_combo"
								or (wantsAlliedDefenseAttack and "persistent_attack")
								or "persistent_sight"
							local entry = persistentUnitsMine[unitID]
							local needsSight = desiredMode == "persistent_sight" or desiredMode == "persistent_combo"
							local needsAttack = desiredMode == "persistent_attack" or desiredMode == "persistent_combo"
							if entry then
								local hasSight = entry.instances.sight ~= nil
								local hasAttack = entry.instances.attack ~= nil
								if hasSight ~= needsSight or hasAttack ~= needsAttack then
									RemoveUnitFromCollection(unitID, persistentUnitsMine)
									AddUnitToCollection(unitID, persistentUnitsMine, desiredMode)
								end
							else
								AddUnitToCollection(unitID, persistentUnitsMine, desiredMode)
							end
						elseif wantsEnemyDefenseAttack then
							keepOther[unitID] = true
							if persistentUnitsOther[unitID] then
								local entry = persistentUnitsOther[unitID]
								if not entry.instances.attack or entry.instances.sight then
									RemoveUnitFromCollection(unitID, persistentUnitsOther)
									AddUnitToCollection(unitID, persistentUnitsOther, "persistent_attack")
								end
							else
								AddUnitToCollection(unitID, persistentUnitsOther, "persistent_attack")
							end
						end
					end
				end
			end
		end
	end

	for unitID in pairs(persistentUnitsMine) do
		if not keepMine[unitID] then
			RemoveUnitFromCollection(unitID, persistentUnitsMine)
		end
	end

	for unitID in pairs(persistentUnitsOther) do
		if not keepOther[unitID] then
			RemoveUnitFromCollection(unitID, persistentUnitsOther)
		end
	end
end


local function FullRebuildAllCollections()
	for unitID in pairs(selections) do
		RemoveUnitFromCollection(unitID, selections)
	end
	for unitID in pairs(persistentUnitsMine) do
		RemoveUnitFromCollection(unitID, persistentUnitsMine)
	end
	for unitID in pairs(persistentUnitsOther) do
		RemoveUnitFromCollection(unitID, persistentUnitsOther)
	end
	for unitID in pairs(mouseovers) do
		RemoveUnitFromCollection(unitID, mouseovers)
	end
	selectedSet = {}
	mouseoverUnitID = nil
	dirtySelection = true
	dirtyBuildState = true
end

-- Optional helper for later UI/option wiring:
-- WG.RangeOverviewSetRingEnabled("radar", false)
function widget:SetRingEnabled(className, enabled)
	if ringEnabled[className] == nil then
		return false
	end
	enabled = not not enabled
	if ringEnabled[className] == enabled then
		return true
	end
	ringEnabled[className] = enabled
	FullRebuildAllCollections()
	return true
end

function widget:GetRingEnabled(className)
	return ringEnabled[className]
end

local function RefreshMouseoverUnit()
	if not enableMouseoverRings then
		if mouseoverUnitID then
			RemoveUnitFromCollection(mouseoverUnitID, mouseovers)
			mouseoverUnitID = nil
		end
		return
	end

	local mx, my = spGetMouseState()
	local hitType, hitData = spTraceScreenRay(mx, my)
	local newMouseover = (hitType == "unit") and hitData or nil

	if newMouseover == mouseoverUnitID then
		return
	end

	if mouseoverUnitID and mouseovers[mouseoverUnitID] then
		RemoveUnitFromCollection(mouseoverUnitID, mouseovers)
	end
	mouseoverUnitID = nil

	if newMouseover and not selectedSet[newMouseover] then
		if persistentUnitsMine[newMouseover] then
			RemoveUnitFromCollection(newMouseover, persistentUnitsMine)
		end
		if persistentUnitsOther[newMouseover] then
			RemoveUnitFromCollection(newMouseover, persistentUnitsOther)
		end
		AddUnitToCollection(newMouseover, mouseovers, "mouseover")
		mouseoverUnitID = newMouseover
	end
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------

local function DrawRingBucket(bucket, primitiveType, thicknessKey, thicknessMult)
	for i = 1, #drawOrder do
		local className = drawOrder[i]
		if IsRingClassEnabled(className) then
			local vao = rangeVAOs[bucket][className]

			if vao and vao.VAO and vao.usedElements and vao.usedElements > 0 then
			if thicknessKey then
				local width = colorConfig[className][thicknessKey]
				if bucket == "mouseover" then
					width = width * 1.15
				end
				glLineWidth(width * thicknessMult)
			end

			local stencilMask = classToStencilMask(className)
			glStencilMask(stencilMask)
			glStencilFunc(GL_NOTEQUAL, stencilMask, stencilMask)
			vao.VAO:DrawArrays(primitiveType, circleSegments, 0, vao.usedElements, 0)
			end
		end
	end
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

	DrawRingBucket(bucket, GL_TRIANGLE_FAN, nil, thicknessMult)

	glColorMask(true, true, true, true)
	glStencilMask(0)
	glDepthTest(GL_LEQUAL)

	local outlineAlpha = colorConfig.externalalpha * alphaMult
	if bucket == "mouseover" then
		outlineAlpha = outlineAlpha * 1.15
	end
	rangeShader:SetUniform("lineAlphaUniform", outlineAlpha)
	rangeShader:SetUniform("drawMode", 1.0)
	rangeShader:SetUniform("drawAlpha", 1.0)

	DrawRingBucket(bucket, GL_LINE_LOOP, "externallinethickness", thicknessMult)

	glStencilTest(false)
	glStencilMask(255)
	glStencilOp(GL_KEEP, GL_KEEP, GL_KEEP)
	glClear(GL_STENCIL_BUFFER_BIT)
end


--------------------------------------------------------------------------------
-- Widget callins
--------------------------------------------------------------------------------

function widget:Initialize()
	WG.RangeOverviewSetRingEnabled = function(className, enabled)
		return widget:SetRingEnabled(className, enabled)
	end
	WG.RangeOverviewGetRingEnabled = function(className)
		return widget:GetRingEnabled(className)
	end

	if not initGL4() then
		widgetHandler:RemoveWidget(self)
		return
	end

	myTeamID = spGetMyTeamID()
	myAllyTeamID = spGetMyAllyTeamID()
	dirtySelection = true
	dirtyBuildState = true
end

function widget:Shutdown()
	if WG.RangeOverviewSetRingEnabled then
		WG.RangeOverviewSetRingEnabled = nil
	end
	if WG.RangeOverviewGetRingEnabled then
		WG.RangeOverviewGetRingEnabled = nil
	end
end

function widget:SelectionChanged()
	dirtySelection = true
end

function widget:PlayerChanged()
	myTeamID = spGetMyTeamID()
	myAllyTeamID = spGetMyAllyTeamID()
	dirtySelection = true
	RefreshPersistentUnits()
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
	if mouseovers[unitID] then
		RemoveUnitFromCollection(unitID, mouseovers)
		if mouseoverUnitID == unitID then
			mouseoverUnitID = nil
		end
	end
end

function widget:UnitDestroyed(unitID)
	if selections[unitID] then
		RemoveUnitFromCollection(unitID, selections)
	end
	if persistentUnitsMine[unitID] then
		RemoveUnitFromCollection(unitID, persistentUnitsMine)
	end
	if persistentUnitsOther[unitID] then
		RemoveUnitFromCollection(unitID, persistentUnitsOther)
	end
	if mouseovers[unitID] then
		RemoveUnitFromCollection(unitID, mouseovers)
	end
	selectedSet[unitID] = nil
	if mouseoverUnitID == unitID then
		mouseoverUnitID = nil
	end
end

function widget:Update()
	if dirtySelection and gameFrame % 3 == 0 then
		UpdateSelectionState()
		dirtyBuildState = true
	end

	local _, cmdID = spGetActiveCommand()
	local buildingNow = (cmdID ~= nil and cmdID < 0)
	if buildingNow ~= isBuilding then
		isBuilding = buildingNow
		dirtyBuildState = true
	end

	if dirtyBuildState then
		RefreshSelectedBuildRingsOnly()
		if mouseoverUnitID and mouseovers[mouseoverUnitID] then
			RemoveUnitFromCollection(mouseoverUnitID, mouseovers)
			AddUnitToCollection(mouseoverUnitID, mouseovers, "mouseover")
		end
		dirtyBuildState = false
	end

	if gameFrame % persistentRefreshFrames == 0 then
		RefreshPersistentUnits()
	end

	if gameFrame % mouseoverRefreshFrames == 0 then
		RefreshMouseoverUnit()
	end
end

function widget:DrawWorld()
	if spIsGUIHidden() then
		return
	end

	local hasAny =
		(next(selections) ~= nil) or
		(next(persistentUnitsMine) ~= nil) or
		(next(persistentUnitsOther) ~= nil) or
		(next(mouseovers) ~= nil)

	if not hasAny then
		return
	end

	local alphaMult, thicknessMult = GetCameraHeightFactor()
	local timeSeconds = gameFrame / 30.0

	glTexture(0, "$heightmap")
	glTexture(1, "$info")
	glTexture(2, "$normals")

	rangeShader:Activate()

	if colorConfig.drawStencil then
		DrawStencilPass("selected",  alphaMult, thicknessMult, timeSeconds)
		DrawStencilPass("mine",      alphaMult, thicknessMult, timeSeconds)
		DrawStencilPass("other",     alphaMult, thicknessMult, timeSeconds)
		DrawStencilPass("mouseover", alphaMult, thicknessMult, timeSeconds)
	end


	rangeShader:Deactivate()

	glTexture(0, false)
	glTexture(1, false)
	glTexture(2, false)
	glDepthTest(false)
end
