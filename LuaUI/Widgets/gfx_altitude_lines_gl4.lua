local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name    = "Altitude Lines GL4",
		desc    = "A thin line from every aircraft down to the ground under it, ending in a ring on the terrain, so you can tell what it is over",
		author  = "SplinterFaction (after the THIS altitude lines)",
		date    = "2026-10-19",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
--
--  Aircraft fly well above the ground, and from SF's camera it is hard to tell
--  what an aircraft is over. So every aircraft you can see gets a thin line in
--  its team's color straight down to the terrain (or the water surface),
--  ending in a ring laid on the ground: the ring is where the aircraft "is".
--
--  Unlike THIS, where the ships' plane is flat, the ground here is not: the
--  ring is a small mesh that samples the heightmap at every vertex, so it
--  lies on slopes, and the line's foot is the heightmap at the aircraft's
--  x,z (never below the water).
--
--  Two instanced draws in DrawWorldPreUnit: the rings (a 4x4 ground patch
--  per aircraft, ring drawn as a signed distance) and the lines (a strip
--  facing the camera from the ground to the aircraft, faint at the top and
--  clearer at the bottom).
--
--------------------------------------------------------------------------------

local TUNE = {
	minHeight    = 10,    -- elmos above the ground before an aircraft gets a line
	lineWidth    = 1.2,   -- half width of the line in elmos
	lineAlphaTop = 0.10,
	lineAlphaBottom = 0.70,
	ringAlpha    = 0.85,
	ringScale    = 0.35,  -- ring radius = unit radius times this
	ringMin      = 8,
	ringMax      = 40,
	ringWidth    = 0.12,  -- ring thickness as a fraction of its radius
	heightOffset = 1.5,
	zPull        = 16.0,
	fadeStart    = 5000,
	fadeEnd      = 9000,
	maxUnits     = 2048,
}

local spGetVisibleUnits   = Spring.GetVisibleUnits
local spGetUnitDefID      = Spring.GetUnitDefID
local spGetUnitPosition   = Spring.GetUnitPosition
local spGetUnitTeam       = Spring.GetUnitTeam
local spGetUnitTransporter = Spring.GetUnitTransporter
local spGetGroundHeight   = Spring.GetGroundHeight
local spGetTeamColor      = Spring.GetTeamColor
local spIsGUIHidden       = Spring.IsGUIHidden
local spEcho              = Spring.Echo

local glTexture   = gl.Texture
local glCulling   = gl.Culling
local glDepthTest = gl.DepthTest
local glDepthMask = gl.DepthMask
local glBlending  = gl.Blending

local max, min = math.max, math.min
local luaShaderDirs = { "LuaUI/Widgets/Include/", "LuaUI/Include/" }

--------------------------------------------------------------------------------
-- Shaders
--------------------------------------------------------------------------------

local INSTSTEP = 8 -- floats per instance: x, y, z, radius, r, g, b, unused

local commonVS = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack : require
#line 10000
//__ENGINEUNIFORMBUFFERDEFS__

uniform sampler2D heightmapTex;
uniform float heightOffset;
uniform float zPull;
uniform float fadeStart;
uniform float fadeEnd;

vec2 HeightmapUV(vec2 wp) {
	vec2 inv = vec2(1.0) / mapSize.xy;
	wp += vec2(-8.0) * (wp * inv) + vec2(4.0);
	wp = clamp(wp, vec2(8.0), mapSize.xy - vec2(8.0));
	return wp * inv;
}
// the ground, or the water surface where the ground is under it
float GroundY(vec2 xz) {
	return max(texture(heightmapTex, HeightmapUV(xz)).x, 0.0) + heightOffset;
}
float DistFade(vec3 p) {
	float d = length(cameraViewInv[3].xyz - p);
	return 1.0 - smoothstep(fadeStart, fadeEnd, d);
}
]]

local ringVS = commonVS .. [[
layout (location = 0) in vec2 gridPos;   // -1..1
layout (location = 1) in vec4 unitPos;   // x, y, z, ring radius
layout (location = 2) in vec4 unitColor; // rgb, unused

out vec2 v_p;
flat out vec3 v_color;
flat out float v_alpha;

void main() {
	vec2 xz = unitPos.xz + gridPos * unitPos.w * 1.15;
	vec3 wp = vec3(xz.x, GroundY(xz), xz.y);
	v_p = gridPos * 1.15;
	v_color = unitColor.rgb;
	v_alpha = DistFade(wp);
	gl_Position = cameraViewProj * vec4(wp, 1.0);
	gl_Position.z -= zPull / gl_Position.w;
}
]]

local ringFS = [[
#version 420
#line 20000
in vec2 v_p;
flat in vec3 v_color;
flat in float v_alpha;
uniform float ringAlpha;
uniform float ringWidth;
out vec4 fragColor;

void main() {
	float d = length(v_p);
	float w = ringWidth;
	float m = 1.0 - smoothstep(0.0, w, abs(d - 1.0 + w));
	// a soft glow just inside the ring
	m = max(m, 0.25 * (1.0 - smoothstep(0.6, 1.0 - w, d)) * smoothstep(0.3, 1.0 - w, d));
	if (m <= 0.003) discard;
	fragColor = vec4(v_color, m * ringAlpha * v_alpha);
}
]]

local lineVS = commonVS .. [[
layout (location = 0) in vec2 stripPos;  // x -1..1 across, y 0 at the ground .. 1 at the aircraft
layout (location = 1) in vec4 unitPos;   // x, y, z, ring radius
layout (location = 2) in vec4 unitColor; // rgb, unused

uniform float lineWidth;
uniform float alphaTop;
uniform float alphaBottom;

out float v_across;
flat out vec3 v_color;
out float v_alpha;

void main() {
	float groundY = GroundY(unitPos.xz);
	float y = mix(groundY, unitPos.y, stripPos.y);
	// across the camera's right, so the strip always faces the camera
	vec3 right = normalize(cameraViewInv[0].xyz);
	vec3 wp = vec3(unitPos.x, y, unitPos.z) + right * (stripPos.x * lineWidth);
	v_across = stripPos.x;
	v_color = unitColor.rgb;
	v_alpha = mix(alphaBottom, alphaTop, stripPos.y) * DistFade(wp);
	gl_Position = cameraViewProj * vec4(wp, 1.0);
}
]]

local lineFS = [[
#version 420
#line 30000
in float v_across;
flat in vec3 v_color;
in float v_alpha;
out vec4 fragColor;

void main() {
	float m = 1.0 - v_across * v_across; // soft across
	if (m * v_alpha <= 0.003) discard;
	fragColor = vec4(v_color, m * v_alpha);
}
]]

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local LuaShader
local ringShader, lineShader
local ringVAO, lineVAO, ringTemplate, ringIndex, lineTemplate, lineIndex, instanceVBO
local ringIndices, lineIndices = 0, 0
local capacity = 512
local resourcesReady = false

local ringRadius = {}   -- unitDefID -> radius, or false
local teamColor = {}
local data = {}
local count = 0

local function RingRadius(unitDefID)
	local r = ringRadius[unitDefID]
	if r == nil then
		r = false
		local ud = UnitDefs[unitDefID]
		if ud and ud.canFly then
			r = max(TUNE.ringMin, min(TUNE.ringMax, (ud.radius or 30) * TUNE.ringScale))
		end
		ringRadius[unitDefID] = r
	end
	return r
end

local function TeamColor(teamID)
	local c = teamColor[teamID]
	if not c then
		local r, g, b = spGetTeamColor(teamID)
		r, g, b = r or 1, g or 1, b or 1
		local lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
		if lum < 0.35 then
			local k = (0.35 - lum) / max(0.001, 1 - lum)
			r, g, b = r + (1 - r) * k, g + (1 - g) * k, b + (1 - b) * k
		end
		c = { r, g, b }
		teamColor[teamID] = c
	end
	return c
end

-- every aircraft in view that is off the ground: {x, y, z, radius, r, g, b, 0}
local function Collect()
	count = 0
	local units = spGetVisibleUnits(-1, nil, false) or {}
	local n = 0
	for i = 1, #units do
		local unitID = units[i]
		local radius = RingRadius(spGetUnitDefID(unitID))
		if radius and count < TUNE.maxUnits and not spGetUnitTransporter(unitID) then
			local x, y, z = spGetUnitPosition(unitID)
			if x then
				local ground = max(spGetGroundHeight(x, z), 0)
				if y - ground > TUNE.minHeight then
					local c = TeamColor(spGetUnitTeam(unitID))
					data[n + 1], data[n + 2], data[n + 3], data[n + 4] = x, y, z, radius
					data[n + 5], data[n + 6], data[n + 7], data[n + 8] = c[1], c[2], c[3], 0
					n = n + 8
					count = count + 1
				end
			end
		end
	end
	for i = n + 1, #data do data[i] = nil end
end

--------------------------------------------------------------------------------
-- GL
--------------------------------------------------------------------------------

local function DestroyResources()
	for _, o in ipairs({ ringVAO, lineVAO, ringTemplate, ringIndex, lineTemplate, lineIndex, instanceVBO }) do
		pcall(function() o:Delete() end)
	end
	ringVAO, lineVAO, ringTemplate, ringIndex, lineTemplate, lineIndex, instanceVBO = nil, nil, nil, nil, nil, nil, nil
	if ringShader then ringShader:Finalize() end
	if lineShader then lineShader:Finalize() end
	ringShader, lineShader = nil, nil
	resourcesReady = false
end

local function Fail(msg)
	spEcho("[Altitude Lines] " .. msg .. ", removing widget")
	DestroyResources()
	widgetHandler:RemoveWidget(widget)
	return false
end

-- a grid of (sub+1)^2 vertices from (x0,y0) to (x1,y1)
local function Grid(x0, y0, x1, y1, sub)
	local vbo = gl.GetVBO(GL.ARRAY_BUFFER, false)
	local ibo = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false)
	if not (vbo and ibo) then return nil end
	local verts, idx = {}, {}
	for j = 0, sub do
		for i = 0, sub do
			verts[#verts + 1] = x0 + (x1 - x0) * i / sub
			verts[#verts + 1] = y0 + (y1 - y0) * j / sub
		end
	end
	local stride = sub + 1
	for j = 0, sub - 1 do
		for i = 0, sub - 1 do
			local a = j * stride + i
			idx[#idx + 1] = a; idx[#idx + 1] = a + stride; idx[#idx + 1] = a + 1
			idx[#idx + 1] = a + 1; idx[#idx + 1] = a + stride; idx[#idx + 1] = a + stride + 1
		end
	end
	vbo:Define(#verts / 2, { { id = 0, name = "pos", size = 2 } })
	vbo:Upload(verts)
	ibo:Define(#idx)
	ibo:Upload(idx)
	return vbo, ibo, #idx
end

local instanceLayout = {
	{ id = 1, name = "unitPos",   size = 4 },
	{ id = 2, name = "unitColor", size = 4 },
}

local function BuildInstanceBuffer(newCapacity)
	capacity = newCapacity
	if ringVAO then ringVAO:Delete() end
	if lineVAO then lineVAO:Delete() end
	if instanceVBO then instanceVBO:Delete() end
	instanceVBO = gl.GetVBO(GL.ARRAY_BUFFER, true)
	if not instanceVBO then return false end
	instanceVBO:Define(capacity, instanceLayout)
	ringVAO = gl.GetVAO()
	lineVAO = gl.GetVAO()
	if not (ringVAO and lineVAO) then return false end
	ringVAO:AttachVertexBuffer(ringTemplate)
	ringVAO:AttachInstanceBuffer(instanceVBO)
	ringVAO:AttachIndexBuffer(ringIndex)
	lineVAO:AttachVertexBuffer(lineTemplate)
	lineVAO:AttachInstanceBuffer(instanceVBO)
	lineVAO:AttachIndexBuffer(lineIndex)
	return true
end

local function UpdateUniforms()
	for _, shader in ipairs({ ringShader, lineShader }) do
		shader:ActivateWith(function()
			shader:SetUniform("heightOffset", TUNE.heightOffset)
			shader:SetUniform("zPull", TUNE.zPull)
			shader:SetUniform("fadeStart", TUNE.fadeStart)
			shader:SetUniform("fadeEnd", TUNE.fadeEnd)
		end)
	end
	ringShader:ActivateWith(function()
		ringShader:SetUniform("ringAlpha", TUNE.ringAlpha)
		ringShader:SetUniform("ringWidth", TUNE.ringWidth)
	end)
	lineShader:ActivateWith(function()
		lineShader:SetUniform("lineWidth", TUNE.lineWidth)
		lineShader:SetUniform("alphaTop", TUNE.lineAlphaTop)
		lineShader:SetUniform("alphaBottom", TUNE.lineAlphaBottom)
	end)
end

local function CreateResources()
	DestroyResources()
	local engineDefs = LuaShader.GetEngineUniformBufferDefs and LuaShader.GetEngineUniformBufferDefs()
	if not engineDefs then return Fail("LuaShader.GetEngineUniformBufferDefs missing") end

	ringShader = LuaShader({
		vertex = ringVS:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineDefs),
		fragment = ringFS,
		uniformInt = { heightmapTex = 0 },
		uniformFloat = { ringAlpha = 1, ringWidth = 0.1 },
	}, "Altitude rings")
	if not ringShader:Initialize() then return Fail("ring shader failed to compile") end
	lineShader = LuaShader({
		vertex = lineVS:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineDefs),
		fragment = lineFS,
		uniformInt = { heightmapTex = 0 },
		uniformFloat = { lineWidth = 1, alphaTop = 0.1, alphaBottom = 0.7 },
	}, "Altitude lines")
	if not lineShader:Initialize() then return Fail("line shader failed to compile") end

	ringTemplate, ringIndex, ringIndices = Grid(-1, -1, 1, 1, 4)
	lineTemplate, lineIndex, lineIndices = Grid(-1, 0, 1, 1, 1)
	if not (ringTemplate and lineTemplate) then return Fail("could not create templates") end
	-- the line template's attribute is named stripPos in its shader; the
	-- VAO binds by location, so the name in Grid does not matter
	if not BuildInstanceBuffer(capacity) then return Fail("could not create instance buffer") end
	resourcesReady = true
	UpdateUniforms()
	return true
end

--------------------------------------------------------------------------------
-- Callins
--------------------------------------------------------------------------------

function widget:PlayerChanged()
	teamColor = {}
end

function widget:DrawWorldPreUnit()
	if spIsGUIHidden() then return end
	if not resourcesReady then
		if not CreateResources() then return end
	end
	Collect()
	if count == 0 then return end
	if count > capacity then
		if not BuildInstanceBuffer(max(capacity * 2, count)) then return Fail("instance buffer grow failed") end
	end
	instanceVBO:Upload(data, nil, 0)

	glTexture(0, "$heightmap")
	glCulling(false)
	glDepthMask(false)
	glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	-- rings on the ground, depth tested so hills in front hide them
	glDepthTest(GL.LEQUAL)
	ringShader:Activate()
	ringVAO:DrawElements(GL.TRIANGLES, ringIndices, 0, count, 0)
	ringShader:Deactivate()

	-- lines through the air, drawn over everything so the ground never cuts them
	glDepthTest(false)
	lineShader:Activate()
	lineVAO:DrawElements(GL.TRIANGLES, lineIndices, 0, count, 0)
	lineShader:Deactivate()

	glTexture(0, false)
	glDepthTest(false)
end

function widget:Initialize()
	if not gl.GetVBO or not gl.GetVAO then
		spEcho("[Altitude Lines] GL4 VBO API unavailable, removing widget")
		widgetHandler:RemoveWidget(widget)
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
		spEcho("[Altitude Lines] LuaShader not found, removing widget")
		widgetHandler:RemoveWidget(widget)
		return
	end
	WG.altitudelines = {
		getRingAlpha = function() return TUNE.ringAlpha end,
		setRingAlpha = function(v) TUNE.ringAlpha = v; if resourcesReady then UpdateUniforms() end end,
		getLineAlpha = function() return TUNE.lineAlphaBottom end,
		setLineAlpha = function(v) TUNE.lineAlphaBottom = v; TUNE.lineAlphaTop = v * 0.15; if resourcesReady then UpdateUniforms() end end,
	}
end

function widget:Shutdown()
	DestroyResources()
	WG.altitudelines = nil
end

function widget:GetConfigData()
	return { ringAlpha = TUNE.ringAlpha, lineAlphaBottom = TUNE.lineAlphaBottom }
end

function widget:SetConfigData(d)
	if d.ringAlpha then TUNE.ringAlpha = d.ringAlpha end
	if d.lineAlphaBottom then TUNE.lineAlphaBottom = d.lineAlphaBottom; TUNE.lineAlphaTop = d.lineAlphaBottom * 0.15 end
end
