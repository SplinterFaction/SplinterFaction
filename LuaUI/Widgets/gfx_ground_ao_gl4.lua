local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Ground AO GL4",
		desc      = "Procedural contact ambient occlusion under units and features: SDF plates sized from each model's real bounds, conformed to the heightmap, multiplied into the terrain",
		author    = "SplinterFaction (transform GLSL helpers after Beherith's LuaShader, MIT)",
		date      = "2026-10-01",
		license   = "GPL V2",
		layer     = -1,
		enabled   = true,
	}
end

-- Compared with BAR's ground AO plates:
--   * no per-building texture atlas, no customParams: every unit and feature gets a plate
--     derived from its model bounds, so new kitbashed units need nothing from the artist
--   * the plate is a signed-distance rounded rectangle evaluated per pixel, so it is
--     resolution independent and the falloff is a real contact-AO gradient
--   * the plate mesh is a small grid that samples the heightmap, so it follows slopes
--     instead of being a flat quad pulled forward in the depth buffer
--   * it multiplies into the terrain (dst * src) rather than alpha-blending black,
--     which darkens bright snow and dark rock proportionally, the way real AO does
--   * no geometry shader, no BAR include files; only LuaShader and the engine VBO API

-----------------------------------------------------------------
-- Tunables (also on WG.groundao at runtime)
-----------------------------------------------------------------

local version = 1

local strength      = 0.55  -- occlusion at the footprint edge (0..1). 0.4 subtle, 0.7 heavy
local spreadScale   = 1.0   -- multiplier on how far the gradient reaches past the footprint
local footprintPad  = 0.95  -- plate core is the model bounds times this
local roundness     = 0.85  -- 0 = sharp rectangle, 1 = full ellipse/stadium
local fadeStart     = 2200  -- camera distance where plates begin to fade
local fadeEnd       = 4200  -- camera distance where plates are gone
local heightOffset  = 1.5   -- elmos above the heightmap, avoids z-fighting on flat ground
local zPull         = 48.0  -- depth pull toward the camera, covers terrain LOD deviation
local drawFeatures  = true
local drawMobile    = true  -- false = buildings only, like BAR

-----------------------------------------------------------------
-- Constants
-----------------------------------------------------------------

local GRID       = 8             -- cells per side of the plate mesh
local GRIDVERTS  = (GRID + 1) * (GRID + 1)
local GRIDINDEX  = GRID * GRID * 6
local INSTSTEP   = 12            -- floats per instance (vec4 + vec4 + uvec4)
local VALIDATE_EVERY = 61        -- game frames between stale-ID sweeps

local luaShaderDirs = { "LuaUI/Widgets/Include/", "LuaUI/Include/" }

local spEcho           = Spring.Echo
local spGetGameFrame   = Spring.GetGameFrame
local spGetAllUnits    = Spring.GetAllUnits
local spGetAllFeatures = Spring.GetAllFeatures
local spGetUnitDefID   = Spring.GetUnitDefID
local spGetFeatureDefID = Spring.GetFeatureDefID
local spValidUnitID    = Spring.ValidUnitID
local spValidFeatureID = Spring.ValidFeatureID

local glTexture   = gl.Texture
local glCulling   = gl.Culling
local glDepthTest = gl.DepthTest
local glDepthMask = gl.DepthMask
local glBlending  = gl.Blending

-----------------------------------------------------------------
-- Shader sources
-----------------------------------------------------------------

-- Minimal subset of the engine's GL4 quaternion transform helpers, for engines
-- where Engine.FeatureSupport.transformsInGL4 is true. Only what this widget needs.
local quaternionDefs = [[
struct Transform {
	vec4 quat;
	vec4 trSc;
};
layout(std140, binding = 0) readonly buffer TransformBuffer {
	Transform transforms[];
};
vec3 RotateByQuaternion(vec4 q, vec3 v) {
	return 2.0 * dot(q.xyz, v) * q.xyz + (q.w * q.w - dot(q.xyz, q.xyz)) * v + 2.0 * q.w * cross(q.xyz, v);
}
vec4 QLerp(vec4 qa, vec4 qb, float t) {
	if (dot(qa, qb) < 0.0) qb = -qb;
	return normalize(mix(qa, qb, t));
}
mat4 GetModelMatrix(uint baseIndex) {
	Transform t0 = transforms[baseIndex + 0u];
	Transform t1 = transforms[baseIndex + 1u];
	vec4 q = QLerp(t0.quat, t1.quat, timeInfo.w);
	vec4 trSc = mix(t0.trSc, t1.trSc, timeInfo.w);
	vec3 ax = RotateByQuaternion(q, vec3(1.0, 0.0, 0.0)) * trSc.w;
	vec3 ay = RotateByQuaternion(q, vec3(0.0, 1.0, 0.0)) * trSc.w;
	vec3 az = RotateByQuaternion(q, vec3(0.0, 0.0, 1.0)) * trSc.w;
	return mat4(vec4(ax, 0.0), vec4(ay, 0.0), vec4(az, 0.0), vec4(trSc.xyz, 1.0));
}
]]

local matrixDefs = [[
layout(std140, binding = 0) readonly buffer MatrixBuffer {
	mat4 UnitPieces[];
};
mat4 GetModelMatrix(uint baseIndex) {
	return UnitPieces[baseIndex];
}
]]

local vsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack : require
#line 10000

layout (location = 0) in vec2  gridPos;      // template mesh, -1..1
layout (location = 1) in vec4  plateSize;    // halfX, halfZ, spread, cornerRadius (elmos)
layout (location = 2) in vec4  plateParams;  // spawnFrame, strength, unused, unused
layout (location = 3) in uvec4 instData;     // filled by the engine

//__ENGINEUNIFORMBUFFERDEFS__
//__TRANSFORMDEFS__

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
layout(std140, binding = 1) readonly buffer UniformsBuffer {
	SUniformsBuffer uni[];
};

uniform sampler2D heightmapTex;
uniform float fadeStart;
uniform float fadeEnd;
uniform float heightOffset;
uniform float zPull;

out vec2 v_local;
flat out vec4 v_size;
flat out float v_strength;

// Same texel alignment the engine uses for $heightmap
vec2 HeightmapUV(vec2 wp) {
	vec2 inv = vec2(1.0) / mapSize.xy;
	wp += vec2(-8.0) * (wp * inv) + vec2(4.0);
	wp = clamp(wp, vec2(8.0), mapSize.xy - vec2(8.0));
	return wp * inv;
}

void main() {
	mat4 modelMatrix = GetModelMatrix(instData.x);
	vec3 center = modelMatrix[3].xyz;

	// yaw only: the mesh conforms to the terrain itself, so unit tilt is not wanted
	vec2 xAxis = modelMatrix[0].xz;
	vec2 zAxis = modelMatrix[2].xz;
	xAxis = (dot(xAxis, xAxis) > 1e-4) ? normalize(xAxis) : vec2(1.0, 0.0);
	zAxis = (dot(zAxis, zAxis) > 1e-4) ? normalize(zAxis) : vec2(0.0, 1.0);

	vec2 extent = plateSize.xy + vec2(plateSize.z);
	vec2 local = gridPos * extent;

	vec3 wp;
	wp.xz = center.xz + xAxis * local.x + zAxis * local.y;
	wp.y = texture(heightmapTex, HeightmapUV(wp.xz)).x + heightOffset;

	float camDist = length(cameraViewInv[3].xyz - center);
	float distFade = 1.0 - smoothstep(fadeStart, fadeEnd, camDist);
	float spawnFade = clamp(((timeInfo.x + timeInfo.w) - plateParams.x) / 12.0, 0.0, 1.0);

	float s = plateParams.y * distFade * spawnFade;
	// drawFlag bits 1|2 = drawn as a full model (visible, not an icon); zero center = no matrix yet
	if ((uni[instData.y].composite & 0x00000003u) == 0u) s = 0.0;
	if (dot(center, center) < 1.0) s = 0.0;

	v_local = local;
	v_size = plateSize;
	v_strength = s;

	if (s <= 0.002) {
		gl_Position = vec4(-4.0, -4.0, 0.0, 1.0); // fully clipped
		return;
	}
	gl_Position = cameraViewProj * vec4(wp, 1.0);
	gl_Position.z -= zPull / gl_Position.w;
}
]]

local fsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack : require
#line 20000

in vec2 v_local;
flat in vec4 v_size;
flat in float v_strength;

out vec4 fragColor;

float sdRoundBox(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
	float d = sdRoundBox(v_local, v_size.xy, v_size.w);
	// 0 at the footprint edge, 1 at the end of the spread
	float t = clamp(d / max(v_size.z, 1.0), 0.0, 1.0);
	// contact AO falls off fast near the object then tails out: cubic ease
	float falloff = (1.0 - t);
	falloff = falloff * falloff * falloff;
	float occ = v_strength * falloff;
	// multiplicative blend: dst * (1 - occ)
	fragColor = vec4(vec3(1.0 - occ), 1.0);
}
]]

-----------------------------------------------------------------
-- State
-----------------------------------------------------------------

local LuaShader
local shader
local templateVBO, indexVBO, instanceVBO, vao
local capacity = 256
local numInstances = 0

-- parallel arrays, 1-based
local instKeys  = {}  -- unitID (>0) or -featureID (<0)
local instData  = {}  -- 12 floats each, instData attribute left as zeros (engine fills it)
local indexOf   = {}  -- key -> slot

local unitPlate    = {}  -- unitDefID -> {hx, hz, spread, corner} or false
local featurePlate = {}  -- featureDefID -> same

local resourcesReady = false
local useQuaternions = (Engine.FeatureSupport and Engine.FeatureSupport.transformsInGL4) and true or false

-----------------------------------------------------------------
-- Plate sizing from defs
-----------------------------------------------------------------

local function PlateFromBounds(minx, maxx, minz, maxz, height, radius)
	local hx, hz
	if minx and maxx and minz and maxz and (maxx - minx) > 1 and (maxz - minz) > 1 then
		hx = (maxx - minx) * 0.5
		hz = (maxz - minz) * 0.5
	elseif radius and radius > 1 then
		hx, hz = radius * 0.8, radius * 0.8
	else
		return false
	end
	hx = hx * footprintPad
	hz = hz * footprintPad
	-- taller objects throw a wider ambient shadow; bounded so towers don't flood the ground
	local h = height or (2 * math.min(hx, hz))
	local short = math.min(hx, hz)
	-- height drives most of it, footprint keeps low wide vehicles from getting a hard edge
	local spread = (math.max(8, math.min(40, h * 0.35)) + short * 0.35) * spreadScale
	local corner = short * math.max(0, math.min(1, roundness))
	return { hx, hz, spread, corner }
end

local function BuildUnitPlates()
	unitPlate = {}
	for id, ud in pairs(UnitDefs) do
		local skip = false
		if ud.canFly then skip = true end
		if ud.moveDef and (ud.moveDef.family == "ship") then skip = true end
		if (not drawMobile) and (not ud.isImmobile) then skip = true end
		if ud.model == nil and (ud.radius or 0) <= 1 then skip = true end
		if skip then
			unitPlate[id] = false
		else
			local m = ud.model or {}
			unitPlate[id] = PlateFromBounds(m.minx, m.maxx, m.minz, m.maxz, ud.height or m.height, ud.radius or m.radius)
			if unitPlate[id] == nil then unitPlate[id] = false end
		end
	end
end

local function BuildFeaturePlates()
	featurePlate = {}
	for id, fd in pairs(FeatureDefs) do
		local skip = false
		if fd.drawType ~= 0 then skip = true end -- engine trees / geo
		if (fd.modelname == nil or fd.modelname == "") then skip = true end
		if skip then
			featurePlate[id] = false
		else
			local m = fd.model or {}
			local p = PlateFromBounds(m.minx, m.maxx, m.minz, m.maxz, fd.height or m.height, fd.radius or m.radius)
			if p == nil or p == false then
				-- fall back to the footprint
				local hx, hz = (fd.xsize or 2) * 4, (fd.zsize or 2) * 4
				p = PlateFromBounds(-hx, hx, -hz, hz, fd.height, nil)
			end
			featurePlate[id] = p or false
		end
	end
end

-----------------------------------------------------------------
-- GL resources
-----------------------------------------------------------------

local function DestroyResources()
	if vao then vao:Delete() end
	if templateVBO then templateVBO:Delete() end
	if indexVBO then indexVBO:Delete() end
	if instanceVBO then instanceVBO:Delete() end
	vao, templateVBO, indexVBO, instanceVBO = nil, nil, nil, nil
	if shader then shader:Finalize() end
	shader = nil
	resourcesReady = false
end

local function Fail(msg)
	spEcho("[GroundAO] " .. msg .. ", removing widget")
	DestroyResources()
	widgetHandler:RemoveWidget()
	return false
end

local function BuildTemplateMesh()
	templateVBO = gl.GetVBO(GL.ARRAY_BUFFER, false)
	indexVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false)
	if not (templateVBO and indexVBO) then return false end

	local verts = {}
	for j = 0, GRID do
		for i = 0, GRID do
			verts[#verts + 1] = (i / GRID) * 2 - 1
			verts[#verts + 1] = (j / GRID) * 2 - 1
		end
	end
	templateVBO:Define(GRIDVERTS, { { id = 0, name = "gridPos", size = 2 } })
	templateVBO:Upload(verts)

	local idx = {}
	local stride = GRID + 1
	for j = 0, GRID - 1 do
		for i = 0, GRID - 1 do
			local a = j * stride + i
			local b = a + 1
			local c = a + stride
			local d = c + 1
			idx[#idx + 1] = a; idx[#idx + 1] = c; idx[#idx + 1] = b
			idx[#idx + 1] = b; idx[#idx + 1] = c; idx[#idx + 1] = d
		end
	end
	indexVBO:Define(GRIDINDEX)
	indexVBO:Upload(idx)
	return true
end

local instanceLayout = {
	{ id = 1, name = "plateSize",   size = 4 },
	{ id = 2, name = "plateParams", size = 4 },
	{ id = 3, name = "instData",    size = 4, type = GL.UNSIGNED_INT },
}

local function UploadInstance(slot)
	local key = instKeys[slot]
	instanceVBO:Upload(instData[slot], nil, slot - 1, 1, INSTSTEP)
	if key > 0 then
		instanceVBO:InstanceDataFromUnitIDs(key, 3, slot - 1)
	else
		instanceVBO:InstanceDataFromFeatureIDs(-key, 3, slot - 1)
	end
end

local function BuildInstanceBuffer(newCapacity)
	if vao then vao:Delete() end
	if instanceVBO then instanceVBO:Delete() end
	capacity = newCapacity
	instanceVBO = gl.GetVBO(GL.ARRAY_BUFFER, true)
	if not instanceVBO then return false end
	instanceVBO:Define(capacity, instanceLayout)

	vao = gl.GetVAO()
	if not vao then return false end
	vao:AttachVertexBuffer(templateVBO)
	vao:AttachInstanceBuffer(instanceVBO)
	vao:AttachIndexBuffer(indexVBO)

	for slot = 1, numInstances do
		UploadInstance(slot)
	end
	return true
end

local function UpdateUniforms()
	if not shader then return end
	shader:ActivateWith(function()
		shader:SetUniform("fadeStart", fadeStart)
		shader:SetUniform("fadeEnd", fadeEnd)
		shader:SetUniform("heightOffset", heightOffset)
		shader:SetUniform("zPull", zPull)
	end)
end

local function CreateResources()
	DestroyResources()

	local engineDefs = LuaShader.GetEngineUniformBufferDefs and LuaShader.GetEngineUniformBufferDefs()
	if not engineDefs then return Fail("LuaShader.GetEngineUniformBufferDefs missing (GL4 LuaShader required)") end

	local vs = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineDefs)
	vs = vs:gsub("//__TRANSFORMDEFS__", useQuaternions and quaternionDefs or matrixDefs)

	shader = LuaShader({
		vertex = vs,
		fragment = fsSrc,
		uniformInt = { heightmapTex = 0 },
	}, "Ground AO GL4")
	if not shader:Initialize() then return Fail("shader failed to compile") end

	if not BuildTemplateMesh() then return Fail("could not create template mesh") end
	if not BuildInstanceBuffer(math.max(capacity, 256)) then return Fail("could not create instance buffer") end

	resourcesReady = true
	UpdateUniforms()
	return true
end

-----------------------------------------------------------------
-- Instance management
-----------------------------------------------------------------

local function AddInstance(key, plate)
	if indexOf[key] then return end
	local slot = numInstances + 1
	numInstances = slot
	instKeys[slot] = key
	indexOf[key] = slot
	instData[slot] = {
		plate[1], plate[2], plate[3], plate[4],
		spGetGameFrame(), strength, 0, 0,
		0, 0, 0, 0,
	}
	if not resourcesReady then return end
	if slot > capacity then
		if not BuildInstanceBuffer(capacity * 2) then Fail("instance buffer grow failed") end
		return
	end
	UploadInstance(slot)
end

local function RemoveInstance(key)
	local slot = indexOf[key]
	if not slot then return end
	local last = numInstances
	if slot ~= last then
		local lastKey = instKeys[last]
		instKeys[slot] = lastKey
		instData[slot] = instData[last]
		indexOf[lastKey] = slot
		if resourcesReady then UploadInstance(slot) end
	end
	instKeys[last] = nil
	instData[last] = nil
	indexOf[key] = nil
	numInstances = last - 1
end

local function AddUnit(unitID, unitDefID)
	unitDefID = unitDefID or spGetUnitDefID(unitID)
	if not unitDefID then return end
	local plate = unitPlate[unitDefID]
	if plate then AddInstance(unitID, plate) end
end

local function AddFeature(featureID)
	if not drawFeatures then return end
	local fdid = spGetFeatureDefID(featureID)
	if not fdid then return end
	local plate = featurePlate[fdid]
	if plate then AddInstance(-featureID, plate) end
end

local function RebuildAll()
	instKeys, instData, indexOf = {}, {}, {}
	numInstances = 0
	for _, unitID in ipairs(spGetAllUnits()) do
		AddUnit(unitID)
	end
	if drawFeatures then
		for _, featureID in ipairs(spGetAllFeatures()) do
			AddFeature(featureID)
		end
	end
	if resourcesReady then
		if numInstances > capacity then
			BuildInstanceBuffer(math.max(256, numInstances * 2))
		else
			for slot = 1, numInstances do UploadInstance(slot) end
		end
	end
end

-- Safety net: catch objects that died or left view without a callin reaching us,
-- so a stale instData never points at a recycled engine slot
local function ValidateInstances()
	local slot = 1
	while slot <= numInstances do
		local key = instKeys[slot]
		local ok
		if key > 0 then ok = spValidUnitID(key) else ok = spValidFeatureID(-key) end
		if ok then
			slot = slot + 1
		else
			RemoveInstance(key) -- swaps the last element into this slot; re-check it
		end
	end
end

-----------------------------------------------------------------
-- Draw
-----------------------------------------------------------------

function widget:DrawWorldPreUnit()
	if not resourcesReady then
		if not CreateResources() then return end
		RebuildAll()
	end
	if numInstances == 0 then return end

	glTexture(0, "$heightmap")
	glCulling(false)
	glDepthTest(GL.LEQUAL)
	glDepthMask(false)
	glBlending(GL.DST_COLOR, GL.ZERO) -- dst * src
	shader:Activate()
	vao:DrawElements(GL.TRIANGLES, GRIDINDEX, 0, numInstances, 0)
	shader:Deactivate()
	glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	glTexture(0, false)
	glDepthTest(false)
end

-----------------------------------------------------------------
-- Callins
-----------------------------------------------------------------

function widget:UnitCreated(unitID, unitDefID)   AddUnit(unitID, unitDefID) end
function widget:UnitEnteredLos(unitID)           AddUnit(unitID) end
function widget:UnitLeftLos(unitID)              RemoveInstance(unitID) end
function widget:UnitDestroyed(unitID)            RemoveInstance(unitID) end
function widget:FeatureCreated(featureID)        AddFeature(featureID) end
function widget:FeatureDestroyed(featureID)      RemoveInstance(-featureID) end
function widget:PlayerChanged()                  RebuildAll() end

function widget:GameFrame(n)
	if n % VALIDATE_EVERY == 0 then ValidateInstances() end
end

-----------------------------------------------------------------
-- Lifecycle
-----------------------------------------------------------------

function widget:Initialize()
	if not gl.GetVBO or not gl.GetVAO then
		spEcho("[GroundAO] GL4 VBO API unavailable, removing widget")
		widgetHandler:RemoveWidget()
		return
	end
	LuaShader = gl.LuaShader
	if not LuaShader then
		for _, dir in ipairs(luaShaderDirs) do
			if VFS.FileExists(dir .. "LuaShader.lua") then
				LuaShader = VFS.Include(dir .. "LuaShader.lua")
				break
			end
		end
	end
	if not LuaShader then
		spEcho("[GroundAO] LuaShader not found, removing widget")
		widgetHandler:RemoveWidget()
		return
	end

	BuildUnitPlates()
	BuildFeaturePlates()
	resourcesReady = false -- GL work happens in the first draw callin

	local function refreshStrength()
		for slot = 1, numInstances do
			instData[slot][6] = strength
			if resourcesReady then UploadInstance(slot) end
		end
	end
	local function refreshSizes()
		BuildUnitPlates()
		BuildFeaturePlates()
		RebuildAll()
	end

	WG.groundao = {
		getStrength     = function() return strength end,
		setStrength     = function(v) strength = v; refreshStrength() end,
		getSpread       = function() return spreadScale end,
		setSpread       = function(v) spreadScale = v; refreshSizes() end,
		getRoundness    = function() return roundness end,
		setRoundness    = function(v) roundness = v; refreshSizes() end,
		getFootprintPad = function() return footprintPad end,
		setFootprintPad = function(v) footprintPad = v; refreshSizes() end,
		getFadeStart    = function() return fadeStart end,
		setFadeStart    = function(v) fadeStart = v; UpdateUniforms() end,
		getFadeEnd      = function() return fadeEnd end,
		setFadeEnd      = function(v) fadeEnd = v; UpdateUniforms() end,
		getHeightOffset = function() return heightOffset end,
		setHeightOffset = function(v) heightOffset = v; UpdateUniforms() end,
		getDrawFeatures = function() return drawFeatures end,
		setDrawFeatures = function(v) drawFeatures = v and true or false; RebuildAll() end,
		getDrawMobile   = function() return drawMobile end,
		setDrawMobile   = function(v) drawMobile = v and true or false; refreshSizes() end,
	}
end

function widget:Shutdown()
	DestroyResources()
	WG.groundao = nil
end

function widget:GetConfigData()
	return {
		version      = version,
		strength     = strength,
		spreadScale  = spreadScale,
		footprintPad = footprintPad,
		roundness    = roundness,
		fadeStart    = fadeStart,
		fadeEnd      = fadeEnd,
		heightOffset = heightOffset,
		drawFeatures = drawFeatures,
		drawMobile   = drawMobile,
	}
end

function widget:SetConfigData(data)
	if data.version ~= version then return end
	if data.strength     ~= nil then strength     = data.strength     end
	if data.spreadScale  ~= nil then spreadScale  = data.spreadScale  end
	if data.footprintPad ~= nil then footprintPad = data.footprintPad end
	if data.roundness    ~= nil then roundness    = data.roundness    end
	if data.fadeStart    ~= nil then fadeStart    = data.fadeStart    end
	if data.fadeEnd      ~= nil then fadeEnd      = data.fadeEnd      end
	if data.heightOffset ~= nil then heightOffset = data.heightOffset end
	if data.drawFeatures ~= nil then drawFeatures = data.drawFeatures end
	if data.drawMobile   ~= nil then drawMobile   = data.drawMobile   end
end
