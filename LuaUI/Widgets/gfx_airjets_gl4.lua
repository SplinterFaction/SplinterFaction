--------------------------------------------------------------------------------
-- Airjets GL4 (SplinterFaction port of BAR's gfx_airjets_gl4)
--
-- Instanced thruster flames, replacing the LUPS AirJet class. One quad per jet,
-- turned about the jet axis to face the camera, with the jet shape and perlin
-- displacement from a texture atlas, drawn additively in one draw call.
--
-- Config comes from the same place the LUPS jets did: the `AirJet` entries in
-- LuaUI/Configs/lupsunitfxs.lua (piece, width, length, color, emitVector,
-- onActive). gfx_distortion_gl4 generates the matching heat haze from that
-- file too, so the flame and its shimmer stay single-sourced.
--
-- SF changes vs BAR:
--   * config read from lupsunitfxs.lua instead of airjet_effects.lua
--   * emitVector is honoured (BAR always used the piece -z axis); SF air
--     plants point their engine jets straight up
--   * onActive jets (LUPS semantics) only show while Spring.GetUnitIsActive,
--     polled every few frames, with the fade-in replayed on each activation
--   * no team color mode, no scavenger variants
--   * gfx_lups_manager skips its AirJet entries while WG.airjets exists
--
-- Original: GoogleFrog, jK, Floris, Beherith, GNU GPL v2.
--------------------------------------------------------------------------------

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name    = "Airjets GL4",
		desc    = "Instanced thruster flames for the AirJet entries in lupsunitfxs.lua",
		author  = "GoogleFrog, jK, Floris, Beherith (SF port)",
		date    = "2026-10-19",
		license = "GNU GPL v2",
		layer   = -1,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------------------

local spEcho              = Spring.Echo
local spGetUnitDefID      = Spring.GetUnitDefID
local spGetTeamUnitsByDefs = Spring.GetTeamUnitsByDefs
local spGetTeamList       = Spring.GetTeamList
local spGetSpectatingState = Spring.GetSpectatingState
local spGetGameFrame      = Spring.GetGameFrame
local spGetUnitPieceMap   = Spring.GetUnitPieceMap
local spGetUnitIsDead     = Spring.GetUnitIsDead
local spIsUnitInLos       = Spring.IsUnitInLos
local spGetUnitIsActive   = Spring.GetUnitIsActive
local spValidUnitID       = Spring.ValidUnitID

local glBlending  = gl.Blending
local glTexture   = gl.Texture
local glCulling   = gl.Culling
local glDepthMask = gl.DepthMask
local glDepthTest = gl.DepthTest
local glAlphaTest = gl.AlphaTest

local GL_ONE = GL.ONE
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA

local mathFloor = math.floor

local ACTIVE_POLL_PERIOD = 4 -- frames between GetUnitIsActive polls for onActive jets

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

local noiseTexture = "bitmaps/GPL/perlin_noise.jpg"
local atlasTexture = "luaui/images/jet_atlas.tga" -- R = opacity (shape), G = perlin displacement strength, 8 columns

local defaultJetType = 0        -- atlas column (0..7)
local defaultXZVelSizeMult = 0  -- XZ velocity -> length multiplier (0 = off)
local defaultYVelSizeMult = 1   -- Y velocity -> length multiplier

-- lupsunitfxs.lua assigns a global `effectUnitDefs` instead of returning; run
-- it in a sandbox to capture the table (same as DistortionGL4Config.lua).
local function loadLupsUnitFx()
	local path = "LuaUI/Configs/lupsunitfxs.lua"
	if not VFS.FileExists(path) then return {} end
	local chunk, err = loadstring(VFS.LoadFile(path), path)
	if not chunk then
		spEcho("[AirjetsGL4] cannot parse " .. path .. ": " .. tostring(err))
		return {}
	end
	-- fall back to this widget's own environment (not _G, which inside a widget
	-- is not the full global table and has no `math`)
	local env = setmetatable({}, { __index = getfenv(1) })
	setfenv(chunk, env)
	local ok, perr = pcall(chunk)
	if not ok then
		spEcho("[AirjetsGL4] error running " .. path .. ": " .. tostring(perr))
		return nil
	end
	return env.effectUnitDefs or {}
end

-- unitDefID -> list of jet defs {piece, width, length, color, emitVector, onActive, ...}
local effectDefs = {}
local effectDefIDList = {}

local function BuildDefs()
	effectDefs, effectDefIDList = {}, {}
	local lupsFx = loadLupsUnitFx()
	if not lupsFx then return false end
	for unitDefName, fxList in pairs(lupsFx) do
		local ud = UnitDefNames[unitDefName]
		if ud and type(fxList) == "table" then
			local jets = {}
			for _, fx in ipairs(fxList) do
				if type(fx) == "table" and fx.class == "AirJet" and fx.options and fx.options.piece then
					local o = fx.options
					local c = o.color or { 1, 0.5, 0 }
					local ev = o.emitVector or { 0, 0, -1 }
					local ex, ey, ez = ev[1] or 0, ev[2] or 0, ev[3] or -1
					local l = math.sqrt(ex * ex + ey * ey + ez * ez)
					if l > 0 then ex, ey, ez = ex / l, ey / l, ez / l else ex, ey, ez = 0, 0, -1 end
					jets[#jets + 1] = {
						piece         = o.piece,
						-- BAR pre-scales by 0.8/0.92 and then 1.4/1.2 at init; net 1.12/1.1
						width         = (tonumber(o.width) or 4) * 0.92 * 1.2,
						length        = (tonumber(o.length) or 20) * 0.8 * 1.4,
						color         = { c[1] or 1, c[2] or 0.5, c[3] or 0 },
						emitVector    = { ex, ey, ez },
						onActive      = o.onActive and true or false,
						jetType       = tonumber(o.jetType) or defaultJetType,
						xzVelSizeMult = tonumber(o.xzVelSizeMult) or defaultXZVelSizeMult,
						yVelSizeMult  = tonumber(o.yVelSizeMult) or defaultYVelSizeMult,
					}
				end
			end
			if #jets > 0 then
				effectDefs[ud.id] = jets
				effectDefIDList[#effectDefIDList + 1] = ud.id
			end
		end
	end
	return true
end

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local unitJetKeys = {}    -- unitID -> { instance keys }
local unitJetActive = {}  -- unitID -> true for units with onActive jets
local unitActiveState = {} -- unitID -> last polled active state

local spec, fullview = spGetSpectatingState()
local myAllyTeamID = Spring.GetLocalAllyTeamID()

local LuaShader = VFS.Include("modules/graphics/LuaShader.lua")
local InstanceVBOTable = VFS.Include("modules/graphics/instancevbotable.lua")
local drawInstanceVBO = InstanceVBOTable.drawInstanceVBO
local popElementInstance = InstanceVBOTable.popElementInstance
local pushElementInstance = InstanceVBOTable.pushElementInstance
local uploadAllElements = InstanceVBOTable.uploadAllElements

local jetInstanceVBO
local jetShader
local quadVBO, quadIndexVBO
local reflectionPassLocation = -1
local lastReflectionPass = false

--------------------------------------------------------------------------------
-- Shaders
--------------------------------------------------------------------------------

local vsSrc = [[#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 10000
uniform int reflectionPass = 0;

layout (location = 0) in vec4 position_xy_uv;

layout (location = 1) in vec3 widthlengthtime; // width, length, spawn frame (fade-in)
layout (location = 2) in vec3 emitdir;         // jet direction in piece space (LUPS emitVector)
layout (location = 3) in vec3 color;
layout (location = 4) in uint pieceIndex;
layout (location = 5) in uvec4 instData;
layout (location = 6) in vec3 jetParams;       // xzVelSizeMult, yVelSizeMult, jetType (atlas column)

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

out DataVS {
	vec4 texCoords;
	vec4 jetcolor;
	flat float jetAtlas;
};

struct SUniformsBuffer {
    uint composite; // u8 drawFlag; u8 unused1; u16 id;
    uint unused2;
    uint unused3;
    uint unused4;
    float maxHealth;
    float health;
    float unused5;
    float unused6;
    vec4 drawPos;
    vec4 speed;
    vec4[4] userDefined;
};

layout(std140, binding=1) readonly buffer UniformsBuffer {
    SUniformsBuffer uni[];
};

#if USEQUATERNIONS == 0
	layout(std140, binding=0) readonly buffer MatrixBuffer {
		mat4 UnitPieces[];
	};
#else
	//__QUATERNIONDEFS__
#endif

#line 10253
void main()
{
	jetcolor.rgb = color;
	jetcolor.a = clamp((timeInfo.x + timeInfo.w - widthlengthtime.z) * 0.053, 0.0, 1.0);
	jetAtlas = jetParams.z;

	texCoords.st = position_xy_uv.zw;
	texCoords.pq = position_xy_uv.zw;
	texCoords.q += (timeInfo.x + timeInfo.w) * 0.1;

	#if USEQUATERNIONS == 0
		uint baseIndex = instData.x;
		mat4 modelMatrix = UnitPieces[baseIndex];
		mat4 pieceMatrix = mat4mix(mat4(1.0), UnitPieces[baseIndex + pieceIndex + 1u], modelMatrix[3][3]);
		mat4 worldMat = modelMatrix * pieceMatrix;
	#else
		mat4 worldMat = TransformToMatrix(GetPieceWorldTransform(instData.x, pieceIndex));
	#endif

	vec4 speedvector = uni[instData.y].speed;

	vec2 modulatedsize = widthlengthtime.xy * 1.5;
	modulatedsize.y *= clamp(speedvector.y * 0.5 * jetParams.y + 1.0, 0.66, 2.0);        // Y velocity -> length
	modulatedsize.y *= clamp(length(speedvector.xz) * 0.5 * jetParams.x + 1.0, 0.33, 4.0); // XZ velocity -> length
	vec2 vertexOffset = position_xy_uv.xy * vec2(modulatedsize.x * 2.0, modulatedsize.y * 0.66); // across, along the jet

	// SF: the jet runs along the piece-space emit vector. The quad's "along"
	// coordinate goes 0 (nozzle) to -1 (tail), so the axis is the negated
	// emit direction; for the LUPS default {0,0,-1} that is the piece +z, as
	// in BAR.
	vec3 jetAxis = mat3(worldMat) * (-emitdir);
	float axisLen = length(jetAxis);
	jetAxis = (axisLen > 1e-5) ? jetAxis / axisLen : worldMat[2].xyz;
	vec3 nozzle = worldMat[3].xyz;
	vec3 worldPos = nozzle + vertexOffset.x * worldMat[0].xyz + vertexOffset.y * jetAxis; // unturned vertex
	vec3 worldCamPos = cameraViewInv[3].xyz;
	vec3 widthAxis = cross(worldCamPos - worldPos, jetAxis);
	widthAxis *= length(worldMat[0].xyz) * inversesqrt(max(dot(widthAxis, widthAxis), 1e-8));

	mat4 VP = (reflectionPass == 0) ? cameraViewProj : reflectionViewProj;
	gl_Position = VP * vec4(nozzle + vertexOffset.x * widthAxis + vertexOffset.y * jetAxis, 1.0);

	// unit not drawn (drawflag) or jet not faded in: collapse the quad outside the clip volume
	if ((uni[instData.y].composite & 0x00000001u) == 0u || jetcolor.a == 0.0) gl_Position = vec4(2.0, 2.0, 2.0, 1.0);

	if (reflectionPass > 0) { // reflections are drawn 3x brighter, without underwater jets
		jetcolor.a *= 3.0;
		if (worldPos.y < -5.0) jetcolor = vec4(0.0);
	}
}
]]

local fsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 20000
uniform sampler2D noiseMap;
uniform sampler2D mask;

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

#define DISTORTION 0.01
#define JET_ATLAS_COLS 8.0
in DataVS {
	vec4 texCoords;
	vec4 jetcolor;
	flat float jetAtlas;
};

out vec4 fragColor;

void main(void)
{
	vec2 displacement = texCoords.pq;
	vec2 cellUV = texCoords.st;

	// per-cell perlin displacement strength from the green channel
	float distortion = texture(mask, vec2((jetAtlas + cellUV.s) / JET_ATLAS_COLS, cellUV.t)).g * DISTORTION;

	vec2 txCoord = cellUV;
	txCoord.s += (texture(noiseMap, displacement * DISTORTION * 20.0).y - 0.5) * 40.0 * distortion;
	txCoord.t +=  texture(noiseMap, displacement).x * (1.0 - cellUV.t) * 15.0 * distortion;

	vec2 atlasUV = vec2((jetAtlas + clamp(txCoord.s, 0.0, 1.0)) / JET_ATLAS_COLS, txCoord.t);
	float opac = texture(mask, atlasUV).r;
	if (opac <= 0.0) discard;

	float opac2 = opac * opac;
	fragColor.rgb  = opac * jetcolor.rgb;
	fragColor.rgb += opac2 * opac2 * opac; // white core
	fragColor.a    = opac * 1.5;
	fragColor.rgba = clamp(fragColor, 0.0, 1.0) * jetcolor.a;
}
]]

local function goodbye(reason)
	spEcho("[AirjetsGL4] " .. reason .. ", removing widget")
	widgetHandler:RemoveWidget()
end

local jetShaderSourceCache = {
	vsSrc = vsSrc,
	fsSrc = fsSrc,
	shaderName = "JetShader GL4",
	uniformInt = { noiseMap = 0, mask = 1 },
	uniformFloat = {},
	shaderConfig = {
		USEQUATERNIONS = (Engine.FeatureSupport and Engine.FeatureSupport.transformsInGL4) and "1" or "0",
	},
	forceupdate = true,
}

local function initGL4()
	jetShader = LuaShader.CheckShaderUpdates(jetShaderSourceCache)
	if not jetShader then
		goodbye("failed to compile jet shader")
		return false
	end
	reflectionPassLocation = gl.GetUniformLocation(jetShader.shaderObj, "reflectionPass")
	lastReflectionPass = false

	-- one quad: x across the jet, y from 0 (nozzle) to -1 (tail), uv
	quadVBO = gl.GetVBO(GL.ARRAY_BUFFER, false)
	quadIndexVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false)
	if not quadVBO or not quadIndexVBO then
		goodbye("failed to create the jet quad VBO")
		return false
	end
	quadVBO:Define(4, { { id = 0, name = "position_xy_uv", size = 4 } })
	quadVBO:Upload({ -1, 0, 0, 1,   -1, -1, 0, 0,   1, -1, 1, 0,   1, 0, 1, 1 })
	quadIndexVBO:Define(6)
	quadIndexVBO:Upload({ 0, 1, 2, 2, 3, 0 })

	local layout = {
		{ id = 1, name = "widthlengthtime", size = 3 },
		{ id = 2, name = "emitdir", size = 3 },
		{ id = 3, name = "color", size = 3 },
		{ id = 4, name = "pieceIndex", type = GL.UNSIGNED_INT, size = 1 },
		{ id = 5, name = "instData", type = GL.UNSIGNED_INT, size = 4 },
		{ id = 6, name = "jetParams", size = 3 },
	}
	jetInstanceVBO = InstanceVBOTable.makeInstanceVBOTable(layout, 256, "jetInstanceVBO", 5)
	if not jetInstanceVBO then
		goodbye("failed to create the jet instance VBO")
		return false
	end
	jetInstanceVBO.numVertices = 6
	jetInstanceVBO.vertexVBO = quadVBO
	jetInstanceVBO.indexVBO = quadIndexVBO
	jetInstanceVBO.VAO = InstanceVBOTable.makeVAOandAttach(quadVBO, jetInstanceVBO.instanceVBO, quadIndexVBO)
	jetInstanceVBO.primitiveType = GL.TRIANGLES
	return true
end

--------------------------------------------------------------------------------
-- Draw
--------------------------------------------------------------------------------

local function DrawJets(isReflection)
	if jetInstanceVBO.usedElements > 0 then
		glCulling(false)
		glDepthMask(false)
		glDepthTest(true)
		glAlphaTest(false)

		glTexture(0, noiseTexture)
		glTexture(1, atlasTexture)
		glBlending(GL_ONE, GL_ONE)
		jetShader:Activate()

		if isReflection ~= lastReflectionPass then
			lastReflectionPass = isReflection
			gl.UniformInt(reflectionPassLocation, isReflection and 1 or 0)
		end

		drawInstanceVBO(jetInstanceVBO)

		jetShader:Deactivate()
		glTexture(0, false)
		glTexture(1, false)
		glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
		glDepthTest(false)
	end
end

--------------------------------------------------------------------------------
-- Unit handling
--------------------------------------------------------------------------------

local function FinishInitialization(unitID, jets)
	local pieceMap = spGetUnitPieceMap(unitID)
	for i = 1, #jets do
		local fx = jets[i]
		fx.piecenum = pieceMap[fx.piece]
		if not fx.piecenum then
			spEcho("[AirjetsGL4] " .. (UnitDefs[spGetUnitDefID(unitID)] or {}).name .. ": no piece '" .. tostring(fx.piece) .. "'")
		end
	end
	jets.finishedInit = true
end

local instanceData = {} -- reused, pushElementInstance copies it

local function PushJet(unitID, fx, spawnFrame, noUpload)
	local ev = fx.emitVector
	local c = fx.color
	instanceData[1] = fx.width * 0.4
	instanceData[2] = fx.length
	instanceData[3] = spawnFrame
	instanceData[4] = ev[1]
	instanceData[5] = ev[2]
	instanceData[6] = ev[3]
	instanceData[7] = c[1]
	instanceData[8] = c[2]
	instanceData[9] = c[3]
	instanceData[10] = fx.piecenum - 1
	instanceData[11] = 0
	instanceData[12] = 0
	instanceData[13] = 0
	instanceData[14] = 0
	instanceData[15] = fx.xzVelSizeMult
	instanceData[16] = fx.yVelSizeMult
	instanceData[17] = fx.jetType
	local key = unitID .. "_" .. fx.piecenum
	pushElementInstance(jetInstanceVBO, instanceData, key, true, noUpload, unitID)
	return key
end

local function Activate(unitID, unitDefID, noUpload)
	if spGetUnitIsDead(unitID) == true then return end
	local jets = effectDefs[unitDefID]
	if not jets then return end
	if not jets.finishedInit then
		FinishInitialization(unitID, jets)
	end

	local active
	local keys = {}
	local hasOnActive = false
	for i = 1, #jets do
		local fx = jets[i]
		if fx.piecenum then
			if fx.onActive then
				hasOnActive = true
				if active == nil then active = spGetUnitIsActive(unitID) and true or false end
				if active then
					keys[#keys + 1] = PushJet(unitID, fx, 0, noUpload)
				end
			else
				keys[#keys + 1] = PushJet(unitID, fx, 0, noUpload)
			end
		end
	end
	unitJetKeys[unitID] = keys
	if hasOnActive then
		unitJetActive[unitID] = true
		unitActiveState[unitID] = active
	else
		unitJetActive[unitID] = nil
		unitActiveState[unitID] = nil
	end
end

local function RemoveUnit(unitID)
	local keys = unitJetKeys[unitID]
	if keys then
		unitJetKeys[unitID] = nil
		local instanceIDtoIndex = jetInstanceVBO.instanceIDtoIndex
		for i = 1, #keys do
			if instanceIDtoIndex[keys[i]] then
				popElementInstance(jetInstanceVBO, keys[i])
			end
		end
	end
	unitJetActive[unitID] = nil
	unitActiveState[unitID] = nil
end

-- onActive jets: add or drop the instances when the unit's active state flips
local function PollActive(frame)
	for unitID in pairs(unitJetActive) do
		if not spValidUnitID(unitID) or spGetUnitIsDead(unitID) then
			RemoveUnit(unitID)
		else
			local active = spGetUnitIsActive(unitID) and true or false
			if active ~= unitActiveState[unitID] then
				unitActiveState[unitID] = active
				local jets = effectDefs[spGetUnitDefID(unitID)]
				local keys = unitJetKeys[unitID]
				if jets and keys then
					local instanceIDtoIndex = jetInstanceVBO.instanceIDtoIndex
					for i = 1, #jets do
						local fx = jets[i]
						if fx.onActive and fx.piecenum then
							local key = unitID .. "_" .. fx.piecenum
							if active then
								if not instanceIDtoIndex[key] then
									keys[#keys + 1] = PushJet(unitID, fx, frame) -- fade in from now
								end
							elseif instanceIDtoIndex[key] then
								popElementInstance(jetInstanceVBO, key)
							end
						end
					end
				end
			end
		end
	end
end

local function reInitialize()
	unitJetKeys, unitJetActive, unitActiveState = {}, {}, {}
	InstanceVBOTable.clearInstanceTable(jetInstanceVBO)
	for _, teamID in ipairs(spGetTeamList()) do
		local teamUnits = spGetTeamUnitsByDefs(teamID, effectDefIDList)
		if teamUnits then
			for i = 1, #teamUnits do
				local unitID = teamUnits[i]
				local unitDefID = spGetUnitDefID(unitID)
				if effectDefs[unitDefID] and (fullview or spIsUnitInLos(unitID)) then
					Activate(unitID, unitDefID, true)
				end
			end
		end
	end
	uploadAllElements(jetInstanceVBO)
end

--------------------------------------------------------------------------------
-- Callins
--------------------------------------------------------------------------------

function widget:UnitEnteredLos(unitID, unitTeam, allyTeam, unitDefID)
	if fullview then return end
	unitDefID = unitDefID or spGetUnitDefID(unitID)
	if effectDefs[unitDefID] then
		Activate(unitID, unitDefID)
	end
end

function widget:UnitLeftLos(unitID)
	if not fullview then
		RemoveUnit(unitID)
	end
end

function widget:UnitCreated(unitID, unitDefID)
	if effectDefs[unitDefID] and (fullview or spIsUnitInLos(unitID)) then
		Activate(unitID, unitDefID)
	end
end

function widget:UnitDestroyed(unitID)
	RemoveUnit(unitID)
end

function widget:CrashingAircraft(unitID)
	RemoveUnit(unitID)
end

function widget:RenderUnitDestroyed(unitID)
	RemoveUnit(unitID)
end

function widget:UnitGiven(unitID, unitDefID)
	if effectDefs[unitDefID] and (fullview or spIsUnitInLos(unitID)) then
		Activate(unitID, unitDefID)
	end
end

function widget:UnitTaken(unitID)
	RemoveUnit(unitID)
end

function widget:GameFrame(n)
	if n % ACTIVE_POLL_PERIOD == 0 and next(unitJetActive) then
		PollActive(n)
	end
end

function widget:DrawWorld()
	DrawJets(false)
end

function widget:DrawWorldReflection()
	DrawJets(true)
end

function widget:PlayerChanged()
	local currentspec, currentfullview = spGetSpectatingState()
	local currentAllyTeamID = Spring.GetLocalAllyTeamID()
	local reinit = (currentspec ~= spec) or (currentfullview ~= fullview)
		or ((currentAllyTeamID ~= myAllyTeamID) and not currentfullview)
	spec, fullview, myAllyTeamID = currentspec, currentfullview, currentAllyTeamID
	if reinit then reInitialize() end
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function widget:Initialize()
	if not gl.CreateShader or not gl.GetVBO then
		widgetHandler:RemoveWidget()
		return
	end
	-- if the config cannot be read, leave WG.airjets unset so the LUPS jets stay
	if not BuildDefs() then
		goodbye("could not load lupsunitfxs.lua")
		return
	end
	if next(effectDefs) == nil then
		spEcho("[AirjetsGL4] no AirJet entries found in lupsunitfxs.lua")
	end
	if not initGL4() then return end
	reInitialize()

	WG.airjets = {}
	-- for other widgets: WG.airjets.addAirJet(unitID, piecenum, width, length, {r,g,b}, emitVector, xzVelSizeMult, yVelSizeMult, jetType)
	WG.airjets.addAirJet = function(unitID, piecenum, width, length, color3, emitVector, xzVelSizeMult, yVelSizeMult, jetType)
		local key = tostring(unitID) .. "_" .. tostring(piecenum)
		emitVector = emitVector or { 0, 0, -1 }
		pushElementInstance(jetInstanceVBO, {
			width * 5, length * 5, spGetGameFrame(),
			emitVector[1], emitVector[2], emitVector[3],
			color3[1], color3[2], color3[3],
			piecenum, 0, 0, 0, 0,
			xzVelSizeMult or defaultXZVelSizeMult, yVelSizeMult or defaultYVelSizeMult, jetType or defaultJetType,
		}, key, true, nil, unitID)
		return key
	end
	WG.airjets.removeAirJet = function(key)
		return popElementInstance(jetInstanceVBO, key)
	end
	WG.airjets.reload = function()
		if BuildDefs() then reInitialize() end
	end

	-- the LUPS manager may already have added AirJet particles for existing units
	if WG.lupsManagerRefresh then WG.lupsManagerRefresh() end
end

function widget:Shutdown()
	if jetInstanceVBO then
		jetInstanceVBO:Delete() -- instance VBO and VAO
		jetInstanceVBO = nil
	end
	if quadVBO then quadVBO:Delete() end
	if quadIndexVBO then quadIndexVBO:Delete() end
	if jetShader then
		jetShader:Finalize()
		jetShader = nil
	end
	WG.airjets = nil
	-- hand the jets back to LUPS
	if WG.lupsManagerRefresh then WG.lupsManagerRefresh() end
end
