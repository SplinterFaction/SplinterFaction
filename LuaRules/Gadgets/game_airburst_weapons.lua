--------------------------------------------------------------------------------
-- game_airburst_weapons.lua
-- Splits a projectile into submunitions at a configurable trigger point.
--
-- CustomParams on the PARENT weapon def:
--
--   airburst             = "1"          -- required: marks this weapon as an airburst
--
-- Trigger (one or both; altitude checked first, timer as fallback):
--   airburst_altitude    = "80"         -- burst when projectile is this many elmos above ground (AGL)
--   airburst_timer       = "2.5"        -- burst after this many seconds of flight
--
-- Submunitions:
--   airburst_sub         = "myweapon"   -- weapondef name of the submunition (required)
--   airburst_count       = "8"          -- number of submunitions to spawn (default: 8)
--   airburst_sub_ttl     = "2.0"        -- manual TTL override in seconds for burnblow simulation
--                                       --   (default: derived from subDef range / weaponVelocity;
--                                       --    set manually for missiles with startVelocity/acceleration)
--
-- Spread:
--   airburst_spread_mode  = "cone"      -- "cone" (forward) or "radial" (perpendicular) (default: cone)
--   airburst_spread_angle = "30"        -- half-angle of spread cone/disc in degrees (default: 30)
--   airburst_even_spread  = "1"         -- 1 = evenly spaced around cone, 0 = random scatter (default: 1)
--
-- Velocity:
--   airburst_speed_inherit = "1.0"      -- fraction of parent speed inherited by subs (default: 1.0)
--   airburst_sub_speed     = "1.0"      -- multiplier on sub speed after inheritance (default: 1.0)
--
-- Parent behaviour on burst:
--   airburst_explode_parent = "0"       -- 1 = trigger parent explosion, 0 = silent delete (default: 0)
--   airburst_burst_ceg      = ""        -- CEG tag to play at burst position when silently deleted
--                                       --   (only used when airburst_explode_parent = 0)
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name    = "Airburst Weapons",
		desc    = "Splits projectiles into submunitions at a configured trigger point",
		author  = "SF",
		version = "1.0",
		layer   = 0,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- Sync guard
--------------------------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then return end

--------------------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------------------
local spGetProjectilePosition  = Spring.GetProjectilePosition
local spGetProjectileVelocity  = Spring.GetProjectileVelocity
local spGetGroundHeight        = Spring.GetGroundHeight
local spDeleteProjectile       = Spring.DeleteProjectile
local spSetProjectileCollision = Spring.SetProjectileCollision
local spSpawnProjectile        = Spring.SpawnProjectile
local spGetGameFrame           = Spring.GetGameFrame
local spGetUnitTeam            = Spring.GetUnitTeam
local spSpawnCEG               = Spring.SpawnCEG  -- may be nil in some envs; guarded at call site

local GAME_SPEED  = Game.gameSpeed  -- frames per second (typically 30)
local PI          = math.pi
local sqrt        = math.sqrt
local cos         = math.cos
local sin         = math.sin
local random      = math.random

-- projectileID -> data table for all tracked airbursts
local tracked = {}

-- projectileID -> expiry frame for submunitions needing burnblow simulation
local trackedSubs = {}

-- Pre-parsed weapon data cache keyed by weaponDefID
-- Avoids re-reading customParams every frame
local airburstDefs = {}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function toboolean(s, default)
	if s == nil then return default end
	return tonumber(s) ~= 0
end

local function ParseDef(weaponDefID)
	local cached = airburstDefs[weaponDefID]
	if cached ~= nil then return cached end

	local wd = WeaponDefs[weaponDefID]
	if not wd then
		airburstDefs[weaponDefID] = false
		return false
	end

	local cp = wd.customParams
	if not (cp and cp.airburst == "1") then
		airburstDefs[weaponDefID] = false
		return false
	end

	local subName    = cp.airburst_sub
	local subNameDef = subName and WeaponDefNames[subName]
	if not subNameDef then
		Spring.Log("AirburstWeapons", LOG.WARNING,
		           "airburst weapon '" .. (wd.name or "?") .. "' has missing/invalid airburst_sub: " .. tostring(subName))
		airburstDefs[weaponDefID] = false
		return false
	end
	local subDef = WeaponDefs[subNameDef.id]
	if not subDef then
		Spring.Log("AirburstWeapons", LOG.WARNING,
		           "airburst weapon '" .. (wd.name or "?") .. "' could not look up WeaponDefs for sub: " .. tostring(subName))
		airburstDefs[weaponDefID] = false
		return false
	end

	-- Trigger
	local altitudeTrigger = tonumber(cp.airburst_altitude)   -- elmos AGL, or nil
	local timerTrigger    = tonumber(cp.airburst_timer)       -- seconds, or nil

	-- Convert timer from seconds to frames
	local timerFrames = timerTrigger and math.floor(timerTrigger * GAME_SPEED) or nil

	if not altitudeTrigger and not timerFrames then
		Spring.Log("AirburstWeapons", LOG.WARNING,
		           "airburst weapon '" .. (wd.name or "?") .. "' has no trigger defined (airburst_altitude or airburst_timer required)")
		airburstDefs[weaponDefID] = false
		return false
	end

	-- Gravity: if myGravity is 0 the engine uses map gravity, so mirror that here.
	-- SpawnProjectile expects a positive value (applied downward internally),
	-- so always take abs() to guard against negative conventions.
	-- Game.gravity is in elmos/s²; SpawnProjectile expects elmos/frame².
	-- myGravity on the weapondef (if exposed) uses the same s² convention.
	-- Divide by GAME_SPEED² to convert.
	local rawGravity = subDef.mygravity
	if rawGravity == nil or rawGravity == 0 then
		rawGravity = Game.gravity or 130
	end
	local subGravity = -math.abs(rawGravity) / (GAME_SPEED * GAME_SPEED)

	-- TTL in frames: manual override takes priority, otherwise derive from range / projectilespeed.
	-- Note: this is approximate for missiles with startvelocity/acceleration;
	-- use airburst_sub_ttl in those cases to dial it in manually.
	local subTTL
	if cp.airburst_sub_ttl then
		subTTL = math.floor(tonumber(cp.airburst_sub_ttl) * GAME_SPEED)
	elseif subDef.projectilespeed and subDef.projectilespeed > 0 then
		subTTL = math.floor((subDef.range / subDef.projectilespeed) * GAME_SPEED)
	else
		subTTL = 90  -- fallback: 3 seconds
		Spring.Echo("AirburstWeapons: WARNING could not derive subTTL for '" .. tostring(cp.airburst_sub) .. "', defaulting to 3s. Set airburst_sub_ttl explicitly.")
	end

	local data = {
		subDefID      = subNameDef.id,
		subGravity    = subGravity,
		subTTL        = subTTL,

		-- Trigger
		altitudeTrigger = altitudeTrigger,
		timerFrames     = timerFrames,

		-- Submunitions
		count           = math.max(1, math.floor(tonumber(cp.airburst_count) or 8)),

		-- Spread
		spreadMode      = (cp.airburst_spread_mode == "radial") and "radial" or "cone",
		spreadAngle     = math.rad(tonumber(cp.airburst_spread_angle) or 30),  -- stored in radians
		evenSpread      = toboolean(cp.airburst_even_spread, true),

		-- Velocity
		speedInherit    = math.max(0, tonumber(cp.airburst_speed_inherit) or 1.0),
		subSpeedMult    = math.max(0, tonumber(cp.airburst_sub_speed)     or 1.0),

		-- Parent behaviour
		explodeParent   = toboolean(cp.airburst_explode_parent, false),
		burstCEG        = (not toboolean(cp.airburst_explode_parent, false)) and (cp.airburst_burst_ceg or nil) or nil,
	}

	airburstDefs[weaponDefID] = data
	return data
end

--------------------------------------------------------------------------------
-- Spawn submunitions
--------------------------------------------------------------------------------

-- Returns a unit vector perpendicular to (nx, ny, nz).
-- Picks the axis least parallel to the direction to avoid degeneracy.
local function Perp(nx, ny, nz)
	local ax, ay, az
	if math.abs(nx) <= math.abs(ny) and math.abs(nx) <= math.abs(nz) then
		ax, ay, az = 1, 0, 0
	elseif math.abs(ny) <= math.abs(nz) then
		ax, ay, az = 0, 1, 0
	else
		ax, ay, az = 0, 0, 1
	end
	-- cross product: n x a
	local px = ny*az - nz*ay
	local py = nz*ax - nx*az
	local pz = nx*ay - ny*ax
	local len = sqrt(px*px + py*py + pz*pz)
	return px/len, py/len, pz/len
end

local function SpawnSubmunitions(data, ownerID, teamID, px, py, pz, vx, vy, vz, spawnFrame)
	local speed  = sqrt(vx*vx + vy*vy + vz*vz)
	local count  = data.count
	local angle  = data.spreadAngle
	local mode   = data.spreadMode

	-- Parent direction (unit vector)
	local nx, ny, nz
	if speed > 0 then
		nx, ny, nz = vx/speed, vy/speed, vz/speed
	else
		nx, ny, nz = 0, -1, 0  -- straight down if somehow stationary
	end

	-- Base speed for subs
	local baseSpeed = speed * data.speedInherit * data.subSpeedMult

	-- Build a perpendicular basis for lateral offsets
	local rx, ry, rz = Perp(nx, ny, nz)
	-- Second perpendicular: n x r
	local ux = ny*rz - nz*ry
	local uy = nz*rx - nx*rz
	local uz = nx*ry - ny*rx

	for i = 1, count do
		local azimuth
		if data.evenSpread then
			azimuth = (i - 1) / count * 2 * PI
		else
			azimuth = random() * 2 * PI
		end

		-- Polar angle from axis: random within [0, spreadAngle] for random,
		-- or use the full angle for even spread (rim of the cone)
		local polar
		if data.evenSpread then
			polar = angle
		else
			-- Random within cone (uniform area distribution)
			polar = math.acos(1 - random() * (1 - cos(angle)))
		end

		local sinPolar = sin(polar)
		local cosPolar = cos(polar)
		local sinAz    = sin(azimuth)
		local cosAz    = cos(azimuth)

		local dvx, dvy, dvz

		if mode == "cone" then
			-- Direction: rotate nx,ny,nz by polar around the azimuth axis
			-- lateral = sinPolar * (cosAz * r + sinAz * u)
			local lx = sinPolar * (cosAz * rx + sinAz * ux)
			local ly = sinPolar * (cosAz * ry + sinAz * uy)
			local lz = sinPolar * (cosAz * rz + sinAz * uz)
			dvx = cosPolar * nx + lx
			dvy = cosPolar * ny + ly
			dvz = cosPolar * nz + lz
		else
			-- Radial: perpendicular to parent direction, no forward component
			dvx = cosAz * rx + sinAz * ux
			dvy = cosAz * ry + sinAz * uy
			dvz = cosAz * rz + sinAz * uz
		end

		-- dvx/dvy/dvz is already unit length by construction; scale to baseSpeed
		local subProjID = spSpawnProjectile(data.subDefID, {
			pos     = { px, py, pz },
			speed   = { dvx * baseSpeed, dvy * baseSpeed, dvz * baseSpeed },
			owner   = ownerID,
			team    = teamID,
			gravity = data.subGravity,
		})
		if subProjID then
			trackedSubs[subProjID] = spawnFrame + data.subTTL
		end
	end
end

--------------------------------------------------------------------------------
-- Burst trigger
--------------------------------------------------------------------------------

local function DoBurst(projID, data, ownerID, teamID, px, py, pz, vx, vy, vz, spawnFrame)
	-- Spawn subs first (before the projectile vanishes)
	SpawnSubmunitions(data, ownerID, teamID, px, py, pz, vx, vy, vz, spawnFrame)

	if data.explodeParent then
		-- Trigger the parent's normal explosion (hits terrain/units at current pos)
		spSetProjectileCollision(projID)
	else
		-- Silently remove the parent
		if data.burstCEG and data.burstCEG ~= "" and spSpawnCEG then
			spSpawnCEG(data.burstCEG, px, py, pz, 0, 0, 0)
		end
		spDeleteProjectile(projID)
	end
end

--------------------------------------------------------------------------------
-- Gadget callbacks
--------------------------------------------------------------------------------

function gadget:Initialize()
	Spring.Echo("AirburstWeapons: loaded, Game.gravity = " .. tostring(Game.gravity)
			            .. " -> per-frame = " .. tostring(-math.abs(Game.gravity) / (GAME_SPEED * GAME_SPEED)))
end

function gadget:ProjectileCreated(projID, ownerID, weaponDefID)
	if not weaponDefID then return end
	local data = ParseDef(weaponDefID)
	if not data then return end

	local teamID = ownerID and spGetUnitTeam(ownerID) or nil

	tracked[projID] = {
		data      = data,
		ownerID   = ownerID,
		teamID    = teamID,
		spawnFrame = spGetGameFrame(),
	}
end

function gadget:GameFrame(n)
	for projID, info in pairs(tracked) do
		local px, py, pz = spGetProjectilePosition(projID)

		if px == nil then
			-- Projectile already gone (hit something before triggering)
			tracked[projID] = nil
		else
			local data = info.data

			-- Check altitude trigger first
			local triggered = false
			if data.altitudeTrigger then
				local groundY = spGetGroundHeight(px, pz)
				if (py - groundY) <= data.altitudeTrigger then
					triggered = true
				end
			end

			-- Check timer trigger (fallback or sole trigger)
			if not triggered and data.timerFrames then
				if (n - info.spawnFrame) >= data.timerFrames then
					triggered = true
				end
			end

			if triggered then
				local vx, vy, vz = spGetProjectileVelocity(projID)
				DoBurst(projID, data, info.ownerID, info.teamID, px, py, pz, vx, vy, vz, n)
				tracked[projID] = nil
			end
		end
	end

	-- Burnblow simulation: trigger collision on subs that have reached their TTL
	for subProjID, expiryFrame in pairs(trackedSubs) do
		if n >= expiryFrame then
			local sx = spGetProjectilePosition(subProjID)
			if sx ~= nil then
				spSetProjectileCollision(subProjID)
			end
			trackedSubs[subProjID] = nil
		end
	end
end

function gadget:ProjectileDestroyed(projID)
	tracked[projID] = nil
	trackedSubs[projID] = nil
end
