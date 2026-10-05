function widget:GetInfo()
	return {
		name      = "Unit Headlights",
		desc      = "Mobile units switch on headlights when the day/night cycle gets dark",
		author    = "Scary le Poo",
		date      = "2026-10-02",
		license   = "GNU GPL, v2 or later",
		layer     = 5,
		enabled   = true,
	}
end

--------------------------------------------------------------------------------
-- How it works
--
-- No shader of its own. Headlights are unit-attached cone lights pushed into
-- the deferred lights widget (WG.lightsgl4), so they light terrain and models
-- through the pipeline that is already running, and they follow the unit on the
-- GPU with zero per-frame Lua cost.
--
-- Darkness comes from WG.weather, published by
-- gfx_timecyclesweathereffects_weather.lua: night (0 = noon, 1 = midnight), or a
-- heavy storm (rain near 1) at any time of day. Each unit gets its own slightly
-- different switch-on point so an army lights up over the course of dusk instead
-- of all on the same frame.
--
-- Requires gfx_deferred_rendering_gl4.lua with GetLightVBO("unitConeLightVBO")
-- exposed, and api_unit_tracker_gl4.lua (this widget registers as a listener).
-- Load order does not matter; both are picked up whenever they appear.
--
-- Per-unitdef customparams (all optional):
--     headlights       = "0"                 no headlights on this unit
--     headlight_pieces = "lamp_l,lamp_r"     attach to these pieces (max 4)
--                                            instead of the auto front-center spot;
--                                            light shines along the piece's +Z
--
-- Chat commands:  /headlights on | off | auto
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Tunables
--------------------------------------------------------------------------------

local NIGHT_ON       = 0.45   -- night level where the first units switch on
local NIGHT_SPREAD   = 0.15   -- the last units switch on at NIGHT_ON + NIGHT_SPREAD
local HYSTERESIS     = 0.06   -- a lit unit switches off this far below its own on-point
local CHECK_INTERVAL = 0.25   -- seconds between evaluations

-- Storms count as darkness too: effective darkness = max(night, rain * STORM_WEIGHT).
-- At 0.75 the first units switch on at rain 0.6 and the last at rain 0.8, so only
-- heavy storms trigger headlights in daytime. Raise it for lighter rain, 0 disables.
local STORM_WEIGHT   = 0.75

local INCLUDE_AIRCRAFT = true

local LIGHT_R, LIGHT_G, LIGHT_B = 1.0, 0.95, 0.82
local LIGHT_BRIGHTNESS = 0.6    -- alpha channel of the light
local LIGHT_THETA      = 0.45   -- cone half-angle in radians
local LIGHT_PITCH      = -0.38  -- downward tilt of the beam (y of the direction, with z = 1)
local LIGHT_REACH_BASE = 70     -- beam length in elmos = BASE + PER_RADIUS * unit radius
local LIGHT_REACH_PER_RADIUS = 3.2
local LIGHT_REACH_MIN  = 110
local LIGHT_REACH_MAX  = 360
local LIGHT_MODELFACTOR = 0.3   -- how strongly the beam lights other models vs terrain
local LIGHT_SPECULAR    = 0.4
local LIGHT_SCATTERING  = 1.2   -- visible beam in the air
local LIGHT_LENSFLARE   = 0

local AIR_PITCH = -1.6          -- aircraft point their lamp steeply down, like a landing light
local MAX_PIECES = 4

--------------------------------------------------------------------------------
-- Speedups
--------------------------------------------------------------------------------

local spEcho               = Spring.Echo
local spValidUnitID        = Spring.ValidUnitID
local spGetUnitIsDead      = Spring.GetUnitIsDead
local spGetUnitIsCloaked   = Spring.GetUnitIsCloaked
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetUnitPieceMap    = Spring.GetUnitPieceMap
local spGetUnitDefDimensions = Spring.GetUnitDefDimensions
local mathSqrt, mathMax, mathMin, mathAbs = math.sqrt, math.max, math.min, math.abs

local LIGHT_PARAM_SIZE = 29   -- instance layout of the deferred lights VBOs
local CONE_VBO_NAME    = "unitConeLightVBO"

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local tracked     = {}   -- unitID -> unitDefID, visible mobile units that can carry headlights
local unitLit     = {}   -- unitID -> true while its lights are in the VBO
local unitBlocked = {}   -- unitID -> true while cloaked or under construction
local unitOnPoint = {}   -- unitID -> night level at which this unit switches on

local defCache    = {}   -- unitDefID -> { lamps = { {pieceName, pieceIndex, params}, ... } } or false

local api, coneVBO = nil, nil   -- WG.lightsgl4 and its unit cone VBO
local tracker = nil             -- WG.unittrackerapi we are registered with
local warnedNoVBO  = false
local waitedForVBO = 0

local mode       = "auto"   -- auto | on | off
local dirty      = true     -- something changed, re-evaluate even if night did not move
local lastNight  = -10
local sinceCheck = 0

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function IsFalsy(v)
	return v == "0" or v == 0 or v == "false" or v == "no" or v == false
end

local function MakeParams(px, py, pz, reach, dx, dy, dz)
	local len = mathSqrt(dx * dx + dy * dy + dz * dz)
	if len < 0.0001 then dx, dy, dz, len = 0, 0, 1, 1 end
	local p = {}
	for i = 1, LIGHT_PARAM_SIZE do p[i] = 0 end
	p[1], p[2], p[3], p[4] = px, py, pz, reach
	p[5], p[6], p[7], p[8] = dx / len, dy / len, dz / len, LIGHT_THETA
	p[9], p[10], p[11], p[12] = LIGHT_R, LIGHT_G, LIGHT_B, LIGHT_BRIGHTNESS
	p[13], p[14], p[15], p[16] = LIGHT_MODELFACTOR, LIGHT_SPECULAR, LIGHT_SCATTERING, LIGHT_LENSFLARE
	-- 17 spawnframe (set by AddLight), 18 lifetime = 0 (never expires), 19 sustain, 20 selfshadowing
	-- 21..24 color2/colortime unused, 25 pieceIndex (set by AddLight)
	return p
end

-- Built lazily from the first visible unit of each def, so the model is already
-- loaded and nothing gets force-loaded at widget init.
local function BuildDef(unitDefID, unitID)
	local ud = UnitDefs[unitDefID]
	if not ud or ud.isBuilding or (ud.speed or 0) <= 0 then return false end
	local isAir = ud.canFly or ud.isAirUnit
	if isAir and not INCLUDE_AIRCRAFT then return false end
	local cp = ud.customParams or {}
	if cp.headlights ~= nil and IsFalsy(cp.headlights) then return false end

	local radius = ud.radius or 20
	local reach = mathMax(LIGHT_REACH_MIN, mathMin(LIGHT_REACH_MAX, LIGHT_REACH_BASE + LIGHT_REACH_PER_RADIUS * radius))
	local pitch = LIGHT_PITCH
	if isAir then
		pitch = AIR_PITCH
		local alt = ud.cruiseAltitude or ud.wantedHeight or 0
		reach = mathMax(reach, mathMin(alt * 1.4, 700))
	end

	local lamps = {}

	if cp.headlight_pieces and cp.headlight_pieces ~= "" then
		local pieceMap = spGetUnitPieceMap(unitID)
		for name in string.gmatch(cp.headlight_pieces, "[^,%s]+") do
			if #lamps >= MAX_PIECES then break end
			local idx = pieceMap and pieceMap[name]
			if idx then
				lamps[#lamps + 1] = { pieceIndex = idx, params = MakeParams(0, 0, 0, reach, 0, pitch, 1) }
			else
				spEcho("[Unit Headlights] " .. tostring(ud.name) .. ": no piece named '" .. name .. "', skipped")
			end
		end
	end

	if #lamps == 0 then
		-- One lamp at the front center of the model, about halfway up, in unit space.
		local dims = spGetUnitDefDimensions and spGetUnitDefDimensions(unitDefID)
		local frontZ, lampY
		if dims and dims.maxz and dims.maxy and dims.miny then
			frontZ = dims.maxz * 0.85
			lampY  = dims.miny + (dims.maxy - dims.miny) * 0.5
		else
			frontZ = radius * 0.7
			lampY  = (ud.height or radius) * 0.5
		end
		lampY = mathMax(lampY, 4)
		lamps[1] = { pieceIndex = 0, params = MakeParams(0, lampY, frontZ, reach, 0, pitch, 1) }
	end

	return { lamps = lamps }
end

local function GetDef(unitDefID, unitID)
	local def = defCache[unitDefID]
	if def == nil then
		def = BuildDef(unitDefID, unitID)
		defCache[unitDefID] = def
	end
	return def
end

-- Cheap per-unit spread so lights come on across dusk rather than on one frame.
local function OnPointFor(unitID)
	return NIGHT_ON + ((unitID * 37) % 100) * 0.01 * NIGHT_SPREAD
end

local function TurnOn(unitID, unitDefID)
	local def = defCache[unitDefID]
	if not def or not spValidUnitID(unitID) then return end
	-- A unit that is playing its death animation is still a valid ID, but nothing
	-- will tell us when it is finally deleted, so never attach lights to one.
	if spGetUnitIsDead(unitID) then return end
	local lamps = def.lamps
	for i = 1, #lamps do
		local lamp = lamps[i]
		api.AddLight("hl" .. unitID .. "_" .. i, unitID, lamp.pieceIndex, coneVBO, lamp.params)
	end
	unitLit[unitID] = true
end

-- Removes this unit's lamps from the cone VBO. Only pops instances that are
-- actually in the VBO, so it is safe when the lights widget (or the VBO's own
-- zombie sweep) already dropped them.
local function TurnOff(unitID, unitDefID)
	local def = defCache[unitDefID]
	if def and api and api.RemoveLight then
		local present = coneVBO and coneVBO.instanceIDtoIndex
		for i = 1, #def.lamps do
			local instanceID = "hl" .. unitID .. "_" .. i
			if (not present) or present[instanceID] then
				api.RemoveLight("cone", instanceID, unitID)
			end
		end
	end
	unitLit[unitID] = nil
end

local function Track(unitID, unitDefID)
	if not GetDef(unitDefID, unitID) then return end
	tracked[unitID] = unitDefID
	unitLit[unitID] = nil
	unitOnPoint[unitID] = OnPointFor(unitID)
	unitBlocked[unitID] = (spGetUnitIsCloaked(unitID) or spGetUnitIsBeingBuilt(unitID)) and true or nil
	dirty = true
end

local function Forget(unitID)
	-- We own these lights, so we remove them. Relying on the lights widget to
	-- drop them left dead units' lamps behind in the VBO as zombies.
	if unitLit[unitID] then TurnOff(unitID, tracked[unitID]) end
	tracked[unitID] = nil
	unitLit[unitID] = nil
	unitBlocked[unitID] = nil
	unitOnPoint[unitID] = nil
end

-- SF's widget handler does not broadcast the VisibleUnit* callins, so listeners
-- register with the tracker explicitly. Handles the tracker loading after us or
-- being reloaded mid-game.
local function ResolveTracker()
	local current = WG.unittrackerapi
	if current == tracker then return end
	tracker = current
	if tracker and tracker.RegisterListener then
		tracker.RegisterListener(widget)
		widget:VisibleUnitsChanged(tracker.visibleUnits or {}, nil)
	else
		widget:VisibleUnitsChanged({}, nil)
	end
end

-- Returns true when the lights API and the unit cone VBO are both usable.
local function ResolveAPI(dt)
	local current = WG.lightsgl4
	if current ~= api then
		-- Lights widget appeared, vanished, or was reloaded: whatever we had in
		-- its VBOs is gone, so start clean.
		api, coneVBO = current, nil
		for unitID in pairs(unitLit) do unitLit[unitID] = nil end
		waitedForVBO = 0
		dirty = true
	end
	if not api or not api.AddLight or not api.RemoveLight then return false end
	if not coneVBO then
		coneVBO = (api.GetLightVBO and api.GetLightVBO(CONE_VBO_NAME)) or api[CONE_VBO_NAME]
		if not coneVBO then
			waitedForVBO = waitedForVBO + dt
			if waitedForVBO > 5 and not warnedNoVBO then
				warnedNoVBO = true
				spEcho("[Unit Headlights] Deferred rendering GL4 does not expose '" .. CONE_VBO_NAME
					.. "' through GetLightVBO. Use the patched gfx_deferred_rendering_gl4.lua.")
			end
			return false
		end
	end
	return true
end

local function CurrentNight()
	if mode == "on" then return 2 end
	if mode == "off" then return -1 end
	local w = WG.weather
	if not w then return 0 end
	local night = w.night or 0
	local storm = (w.rain or 0) * STORM_WEIGHT
	return (storm > night) and storm or night
end

local function Evaluate(night)
	for unitID, unitDefID in pairs(tracked) do
		local lit = unitLit[unitID]
		local onPoint = unitOnPoint[unitID]
		local want = (not unitBlocked[unitID]) and (night >= (lit and (onPoint - HYSTERESIS) or onPoint))
		if want and not lit then
			TurnOn(unitID, unitDefID)
		elseif lit and not want then
			TurnOff(unitID, unitDefID)
		end
	end
end

--------------------------------------------------------------------------------
-- Callins
--------------------------------------------------------------------------------

function widget:Update(dt)
	sinceCheck = sinceCheck + dt
	if sinceCheck < CHECK_INTERVAL then return end
	local elapsed = sinceCheck
	sinceCheck = 0

	ResolveTracker()
	if not ResolveAPI(elapsed) then return end

	local night = CurrentNight()
	if not dirty and mathAbs(night - lastNight) < 0.004 then return end
	lastNight = night
	dirty = false
	Evaluate(night)
end

-- Unit tracker listener callins (dispatched by api_unit_tracker_gl4).
function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam)
	Track(unitID, unitDefID)
end

function widget:VisibleUnitRemoved(unitID)
	-- The unit is still a valid ID during this callin, so its lamps pop cleanly.
	Forget(unitID)
end

function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
	-- Remove whatever we still have in the VBO ourselves (a no-op for anything the
	-- lights widget already wiped), then rebuild our list unlit and let the next
	-- Update re-add. Safe whichever listener the tracker dispatches to first.
	for unitID in pairs(unitLit) do
		TurnOff(unitID, tracked[unitID])
	end
	tracked, unitLit, unitBlocked, unitOnPoint = {}, {}, {}, {}
	for unitID, unitDefID in pairs(extVisibleUnits) do
		Track(unitID, unitDefID)
	end
	dirty = true
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if tracked[unitID] then
		unitBlocked[unitID] = spGetUnitIsCloaked(unitID) and true or nil
		dirty = true
	end
end

function widget:UnitCloaked(unitID, unitDefID, unitTeam)
	if tracked[unitID] then
		unitBlocked[unitID] = true
		if unitLit[unitID] then TurnOff(unitID, tracked[unitID]) end
	end
end

function widget:UnitDecloaked(unitID, unitDefID, unitTeam)
	if tracked[unitID] then
		unitBlocked[unitID] = spGetUnitIsBeingBuilt(unitID) and true or nil
		dirty = true
	end
end

function widget:CrashingAircraft(unitID, unitDefID, unitTeam)
	-- Lights go out on a crashing aircraft; Forget removes them from the VBO.
	Forget(unitID)
end

function widget:TextCommand(command)
	local arg = string.match(command, "^headlights%s*(%a*)")
	if not arg then return false end
	if arg == "on" or arg == "off" or arg == "auto" then
		mode = arg
	elseif arg == "" then
		mode = (mode == "auto") and "on" or "auto"
	else
		spEcho("[Unit Headlights] usage: /headlights on | off | auto")
		return true
	end
	dirty = true
	spEcho("[Unit Headlights] mode: " .. mode)
	return true
end

function widget:Initialize()
	ResolveTracker()
end

function widget:Shutdown()
	if tracker and tracker == WG.unittrackerapi and tracker.UnregisterListener then
		tracker.UnregisterListener(widget)
	end
	if api and api == WG.lightsgl4 then
		for unitID, unitDefID in pairs(tracked) do
			if unitLit[unitID] then TurnOff(unitID, unitDefID) end
		end
	end
end
