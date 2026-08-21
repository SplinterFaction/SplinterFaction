-- DistortionGL4Config.lua (SplinterFaction)
--
-- Unit-attached and feature-attached screen-space distortions for
-- gfx_distortion_gl4.lua.
--
-- Returns:
--   unitDefDistortions[unitDefID]     = { name = distortionTable, ... }
--   unitEventDistortions              = { UnitScriptDistortions = {...}, <CallinName> = {...} }
--   featureDefDistortions[featDefID]  = { name = distortionTable, ... }
--
-- A distortionTable:
--   {
--     distortionType = "point" | "cone" | "beam",
--     pieceName = "engine1",       -- nil = world space at unit base
--     aboveUnit = n, alwaysVisible = bool, fraction = n,
--     distortionConfig = {
--       posx, posy, posz, radius,
--       dirx, diry, dirz, theta,          -- cone
--       pos2x, pos2y, pos2z,              -- beam
--       noiseStrength, noiseScaleSpace, distanceFalloff, effectStrength,
--       riseRate, windAffected, onlyModelMap,
--       lifeTime, rampUp, decay, sustain, effectType,
--     },
--   }
--
-- Airjets are generated from LuaUI/Configs/lupsunitfxs.lua (class='AirJet'
-- entries) so thruster placement has one source of truth.
--
-- Original structure: Beherith, GNU GPL v2.
--------------------------------------------------------------------------------

local function copy(t)
	local c = {}
	for k, v in pairs(t) do
		if type(v) == "table" then
			c[k] = copy(v)
		else
			c[k] = v
		end
	end
	return c
end

--------------------------------------------------------------------------------
-- Unit distortions (hand-authored). Keyed by unitdef name.
--------------------------------------------------------------------------------

local unitDistortions = {
	-- Example: heat haze rising from a building vent
	-- lozreactor = {
	-- 	vent = {
	-- 		distortionType = "cone",
	-- 		pieceName = "vent",
	-- 		distortionConfig = {
	-- 			posx = 0, posy = 0, posz = 0, radius = 90,
	-- 			dirx = 0, diry = 1, dirz = 0, theta = 0.25,
	-- 			noiseStrength = 1.2, noiseScaleSpace = 0.9, distanceFalloff = 1.5, effectStrength = 2.0,
	-- 			riseRate = 0.8, windAffected = 0.3, onlyModelMap = 0,
	-- 			lifeTime = 0, effectType = 0,
	-- 		},
	-- 	},
	-- },
}

--------------------------------------------------------------------------------
-- Airjets from the Lups config
--------------------------------------------------------------------------------

do
	local airjetBase = {
		posx = 0,
		posy = 0,
		posz = 0,
		radius = 130,
		dirx = 0,
		diry = 0,
		dirz = -1.0,
		theta = 0.08,
		noiseStrength = 2,
		noiseScaleSpace = 0.85,
		distanceFalloff = 1.5,
		effectStrength = 4.0,
		onlyModelMap = 0,
		lifeTime = 0,
		effectType = 0,
	}

	-- lupsunitfxs.lua assigns a global `effectUnitDefs` instead of returning;
	-- run it in a sandbox to capture the table.
	local function loadLupsUnitFx()
		local path = "LuaUI/Configs/lupsunitfxs.lua"
		if not VFS.FileExists(path) then
			return {}
		end
		local chunk, err = loadstring(VFS.LoadFile(path), path)
		if not chunk then
			Spring.Echo("DistortionGL4Config: cannot parse " .. path .. ": " .. tostring(err))
			return {}
		end
		local env = setmetatable({}, { __index = _G })
		setfenv(chunk, env)
		local ok, perr = pcall(chunk)
		if not ok then
			Spring.Echo("DistortionGL4Config: error running " .. path .. ": " .. tostring(perr))
			return {}
		end
		return env.effectUnitDefs or {}
	end

	local lupsFx = loadLupsUnitFx()
	local jets = 0
	for unitDefName, fxList in pairs(lupsFx) do
		if type(fxList) == "table" then
			for i, fx in ipairs(fxList) do
				if type(fx) == "table" and fx.class == "AirJet" and fx.options and fx.options.piece then
					local o = fx.options
					unitDistortions[unitDefName] = unitDistortions[unitDefName] or {}
					local alreadyHas = false
					for _, d in pairs(unitDistortions[unitDefName]) do
						if d.pieceName == o.piece then
							alreadyHas = true
							break
						end
					end
					if not alreadyHas then
						local cfg = copy(airjetBase)
						local length = tonumber(o.length) or 20
						local width = tonumber(o.width) or 4
						cfg.radius = length * 6
						cfg.theta = math.atan(width / length) * 1.2
						if o.emitVector then
							local ex, ey, ez = o.emitVector[1] or 0, o.emitVector[2] or 0, o.emitVector[3] or -1
							local l = math.sqrt(ex * ex + ey * ey + ez * ez)
							if l > 0 then
								cfg.dirx, cfg.diry, cfg.dirz = ex / l, ey / l, ez / l
							end
						end
						unitDistortions[unitDefName]["airjet" .. i .. o.piece] = {
							distortionType = "cone",
							pieceName = o.piece,
							distortionConfig = cfg,
						}
						jets = jets + 1
					end
				end
			end
		end
	end
	-- Spring.Echo("DistortionGL4Config: generated " .. jets .. " airjet distortions from lupsunitfxs.lua")
end

--------------------------------------------------------------------------------
-- Unit event distortions
--------------------------------------------------------------------------------

local unitEventDistortionsNames = {
	UnitScriptDistortions = {},
}

--------------------------------------------------------------------------------
-- Resolve names -> defIDs
--------------------------------------------------------------------------------

local unitDefDistortions = {}
for unitName, list in pairs(unitDistortions) do
	if UnitDefNames[unitName] then
		unitDefDistortions[UnitDefNames[unitName].id] = list
	end
end
unitDistortions = nil

local unitEventDistortions = {}
for eventName, unitTable in pairs(unitEventDistortionsNames) do
	unitEventDistortions[eventName] = {}
	for unitName, list in pairs(unitTable) do
		if UnitDefNames[unitName] then
			unitEventDistortions[eventName][UnitDefNames[unitName].id] = list
		end
	end
end
unitEventDistortionsNames = nil

--------------------------------------------------------------------------------
-- Feature distortions
--------------------------------------------------------------------------------

local featureDefDistortions = {}

-- Wreck heat haze: rises from fresh wrecks, fades with the ember light.
local WreckHazeBase = {
	distortionType = "point",
	distortionConfig = {
		posx = 0,
		posy = 6,
		posz = 0,
		radius = 30,
		onlyModelMap = 0,
		riseRate = 0.9,
		windAffected = 0.4,
		noiseStrength = 0.6,
		noiseScaleSpace = 1.4,
		distanceFalloff = 1.3,
		effectStrength = 1.2,
		lifeTime = 360,
		rampUp = 10,
		decay = 120,
		effectType = 0,
	},
}

for featureDefID, featureDef in pairs(FeatureDefs) do
	if string.sub(featureDef.name, -5) == "_dead" then
		local featureSize = math.sqrt((featureDef.xsize or 1) * (featureDef.zsize or 1)) / 2.1
		local d = copy(WreckHazeBase)
		d.distortionConfig.radius = 18 + featureSize * 14
		d.distortionConfig.posy = 4 + featureSize * 3
		featureDefDistortions[featureDefID] = { FeatureCreated = d }
	end
end

-- Crystal shimmer (pilha_crystal*), a gentle persistent ripple.
local crystalBase = {
	distortionType = "point",
	distortionConfig = {
		posx = 0,
		posy = 8,
		posz = 0,
		radius = 20,
		onlyModelMap = 0,
		riseRate = 0.5,
		windAffected = -0.5,
		noiseStrength = 0.4,
		noiseScaleSpace = 2.2,
		distanceFalloff = 1.2,
		effectStrength = 0.6,
		lifeTime = 0,
		effectType = 0,
	},
}

for featureDefID, featureDef in pairs(FeatureDefs) do
	if not featureDefDistortions[featureDefID] then
		local lname = string.lower(featureDef.name)
		local size = tonumber(lname:match("pilha_crystal[%a_]*(%d)$"))
		if size then
			local d = copy(crystalBase)
			d.distortionConfig.radius = (size + 0.2) * (crystalBase.distortionConfig.radius * 0.6)
			d.distortionConfig.posy = (size + 1.5) * crystalBase.distortionConfig.posy
			featureDefDistortions[featureDefID] = { crystal = d }
		end
	end
end

return {
	unitEventDistortions = unitEventDistortions,
	unitDefDistortions = unitDefDistortions,
	featureDefDistortions = featureDefDistortions,
}
