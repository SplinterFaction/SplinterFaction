function widget:GetInfo()
	return {
		name      = "Weather",
		desc      = "Day/night cycle, war-weariness tinting, rain fog, and lightning flashes on large explosions",
		author    = "Doo (rewritten 2026)",
		date      = "2026-08-02",
		version   = "2.1",
		license   = "GNU GPL, v2 or later",
		layer     = -4,
		enabled   = true,
	}
end

--------------------------------------------------------------------------------
-- Tuning
--------------------------------------------------------------------------------

local WEATHER_TIME_SCALE = 1   -- speeds up EVERYTHING (sun + rain) for testing; set 5 to fast-forward
local DAY_CYCLE_SPEED = 0.168    -- sun angular speed multiplier
local WAR_RAMP_RATE   = 2000    -- how fast the visible war tint chases accumulated damage (per second)
local WAR_DECAY       = 0.9995  -- per-simframe-equivalent decay of accumulated damage
local WAR_K_DIVISOR   = 3500    -- larger => war tint saturates slower (scaled by map area * player count)
local DAMAGE_CAP      = 1500    -- per-event damage cap fed into the war accumulator
local RAIN_PERIOD     = 50      -- seconds; primary storm oscillator (full cycle ~= 2*pi*this)
local RAIN_THRESHOLD  = 0.15    -- -1..1; lower = rains more often (0.15 ~= raining ~40% of the time)

-- Wet ground: rain soaks in and the ground keeps a wet sheen that dries slowly
local WET_SPEC_RGB    = { 1, 1, 1 } -- ground/unit specular color at full wetness
local WET_EXPONENT    = 256   -- specular exponent at full wetness (higher = tighter, glossier highlights)
local SOAK_TIME       = 8    -- seconds of rain to reach full wet sheen
local DRY_TIME        = 90   -- seconds for the ground to dry out after rain stops
local FLASH_DURATION  = 5       -- seconds for a lightning flash to fully fade (150 frames @30fps originally)
local FLASH_SCALE     = 160     -- larger => weaker flashes (divides the death explosion AoE)
local MIN_FLASH       = 0.025   -- flashes dimmer than this are culled
local DIFFUSE_FLOOR   = 1.5     -- minimum r+g+b of diffuse (prevents pitch black)
local FOG_END         = 15      -- pushed far out so fogStart alone controls density (original behavior)

local SEED_PARAM      = "weather_seed" -- published once per match by LuaRules/Gadgets/weather_seed.lua
local DEBUG           = false   -- echo the seed once it arrives

-- Blend targets: what each channel is pulled toward at full night / full war / full rain.
-- NOTE: fog has no 'war' entry on purpose. War intensity is accumulated from
-- LOS-limited widget callins, so it differs per player; keeping it out of the
-- fog channel is what lets fog stay identical for everyone.
local TARGETS = {
	diffuse  = { night = {0.035, 0.035, 0.07}, war = {0.23, 0.07, 0.035}, rain = {0.5, 0.5, 0.5} },
	specular = { night = {0.12,  0.12,  0.20}, war = {0,    0,    0    } }, -- rain handled by wetness below
	fog      = { night = {0.03,  0.06,  0.20},                             rain = {0.5, 0.5, 0.5} },
	sun      = { night = {0.60,  0.95,  0.10}, war = {1,    0.95, 0.60 }, rain = {0.5, 0.5, 0.5} },
	sky      = { night = {0.03,  0.06,  0.20}, war = {0.20, 0.06, 0.03 }, rain = {0.5, 0.5, 0.5} },
	cloud    = { night = {0,     0,     0   }, war = {0,    0,    0    }, rain = {0.5, 0.5, 0.5} },
}

--------------------------------------------------------------------------------
-- Speedups
--------------------------------------------------------------------------------

local spSetSunLighting  = Spring.SetSunLighting
local spSetAtmosphere   = Spring.SetAtmosphere
local spSetSunDirection = Spring.SetSunDirection
local spGetPlayerRoster = Spring.GetPlayerRoster
local spGetGameFrame    = Spring.GetGameFrame
local spGetGameRulesParam = Spring.GetGameRulesParam
local glGetSun          = gl.GetSun
local glGetAtmosphere   = gl.GetAtmosphere
local mathSin, mathCos  = math.sin, math.cos
local mathSqrt, mathExp = math.sqrt, math.exp
local mathMax           = math.max
local mathMin           = math.min
local spEcho            = Spring.Echo

-- Sub-simframe interpolation, so the sun still moves smoothly between frames.
-- Guarded because it is the one callout here that is not universally present.
local spGetFrameTimeOffset = Spring.GetFrameTimeOffset or function() return 0 end

local GAME_SPEED = Game.gameSpeed or 30

--------------------------------------------------------------------------------
-- State (all local: the original leaked ~30 globals, including n, r, b, t, p, w)
--------------------------------------------------------------------------------

local base       = nil   -- scene lighting captured at init, restored on shutdown
local baseSunDir = nil

local sunSeed    = 0     -- day/night phase offset for this match (from the shared seed)
local rainSeed   = 0     -- storm phase offset for this match
local seeded     = false
local lastGameTime = nil -- previous frame's game time, for the wetness/war integrators

local damageHeat = 1     -- accumulated, decaying damage total ('b' in the original)
local warRamp    = 1     -- smoothed value chasing damageHeat ('r' in the original)
local wetness    = 0     -- ground wetness: soaks in while raining, dries out slowly
local baseSpecExp = 16
local specExpSupported = false
local mapK       = 1
local flashAge   = nil   -- nil = no active flash
local flashPeak  = 0

-- Per-frame blend weights, shared with blend() below (avoids per-frame closures)
local kBase, kNight, kWar, kRain = 1, 0, 0, 0
-- Separate war-free weights for the fog channel (see TARGETS note above)
local fBase, fNight, fRain = 1, 0, 0

-- Reused parameter tables: the original allocated ~12 tables per draw frame
local sunLighting = {
	groundAmbientColor  = {0, 0, 0},
	groundDiffuseColor  = {0, 0, 0},
	groundSpecularColor = {0, 0, 0},
	unitAmbientColor    = {0, 0, 0},
	unitDiffuseColor    = {0, 0, 0},
	unitSpecularColor   = {0, 0, 0},
}
local atmosphere = {
	fogStart   = 0,
	fogEnd     = FOG_END,
	fogColor   = {0, 0, 0, 0},
	sunColor   = {0, 0, 0},
	skyColor   = {0, 0, 0},
	cloudColor = {0, 0, 0},
}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function CaptureScene()
	local b = {
		diffuse = {}, ambient = {}, specular = {},
		fog = {}, sun = {}, sky = {}, cloud = {},
	}
	b.diffuse[1],  b.diffuse[2],  b.diffuse[3]  = glGetSun("diffuse")
	b.ambient[1],  b.ambient[2],  b.ambient[3]  = glGetSun("ambient")
	b.specular[1], b.specular[2], b.specular[3] = glGetSun("specular")
	b.fogStart = glGetAtmosphere("fogStart")
	b.fogEnd   = glGetAtmosphere("fogEnd")
	b.fog[1],   b.fog[2],   b.fog[3]   = glGetAtmosphere("fogColor")
	b.sun[1],   b.sun[2],   b.sun[3]   = glGetAtmosphere("sunColor")
	b.sky[1],   b.sky[2],   b.sky[3]   = glGetAtmosphere("skyColor")
	b.cloud[1], b.cloud[2], b.cloud[3] = glGetAtmosphere("cloudColor")
	return b
end

-- Time of day and storm phase are pure functions of (shared seed, game frame).
-- Nothing is accumulated across frames, so a client that hitched during load,
-- paused, rejoined, or is watching a replay lands in exactly the same phase as
-- everyone else. The seed is published by the weather_seed gadget; if that
-- gadget is missing the offsets stay at 0, which still matches across clients,
-- it just gives every match the same opening sky.
local TWO_PI = 2 * math.pi

local function ApplySeed(seed)
	-- combined period of the 1/15 and 1/16 sun oscillators is 2*pi*240
	sunSeed  = (seed * 7.137) % (TWO_PI * 240)
	rainSeed = (seed * 13.71) % (TWO_PI * RAIN_PERIOD)
	seeded   = true
	if DEBUG then
		spEcho(string.format("[Weather] seed %d -> sun %.2f rain %.2f", seed, sunSeed, rainSeed))
	end
end

local function GameTime()
	return (spGetGameFrame() + (spGetFrameTimeOffset() or 0)) / GAME_SPEED * WEATHER_TIME_SCALE
end

local function RecalcMapK()
	local roster = spGetPlayerRoster(2)
	local count = 0
	if roster then
		for i = 1, #roster do
			if roster[i][5] == false then -- index 5 = spectator flag
				count = count + 1
			end
		end
	end
	if count < 1 then count = 1 end
	mapK = (Game.mapSizeX * Game.mapSizeZ / WAR_K_DIVISOR) * count
end

local function blend(baseC, targets, i)
	return baseC[i] * kBase
			+ targets.night[i] * kNight
			+ targets.war[i]   * kWar
			+ targets.rain[i]  * kRain
end

-- War-free variant, used only for fog so that fog density and color are
-- identical on every client
local function blendFog(baseC, targets, i)
	return baseC[i] * fBase
			+ targets.night[i] * fNight
			+ targets.rain[i]  * fRain
end

--------------------------------------------------------------------------------
-- Callins
--------------------------------------------------------------------------------

function widget:Initialize()
	base = CaptureScene()
	baseSunDir = { glGetSun() }
	RecalcMapK()
	WG.weather = WG.weather or {}

	local seed = spGetGameRulesParam(SEED_PARAM)
	if seed then
		ApplySeed(seed)
	end

	-- Wet sheen also raises the specular exponent (gloss tightness), but probe
	-- whether this engine build accepts the keys, since SetSunLighting errors
	-- on unknown ones
	local okGet, exp = pcall(glGetSun, "specularExponent")
	baseSpecExp = (okGet and type(exp) == "number" and exp) or 16
	specExpSupported = pcall(spSetSunLighting, {
		groundSpecularExponent = baseSpecExp,
		modelSpecularExponent  = baseSpecExp,
	})
	if not specExpSupported then
		spEcho("[Weather] specular exponent keys unsupported on this engine; wet gloss will use specular color only")
	end
end

-- The original defined a stray global GameStart() that the engine never called.
function widget:GameStart()
	RecalcMapK()
end

function widget:PlayerChanged()
	RecalcMapK()
end

-- The original had this commented out, which left the war-weariness factor
-- permanently at ~0. Restored, with the damage cap the author had sketched.
-- Still deliberately client-local: this only fires for units this player can
-- see, so the war tint is a personal view of the battle, not a shared one.
function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage)
	if damage > 0 then
		if damage > DAMAGE_CAP then damage = DAMAGE_CAP end
		damageHeat = damageHeat + damage
	end
end

function widget:UnitDestroyed(unitID, unitDefID)
	local ud = UnitDefs[unitDefID]
	local explosion = ud and ud.deathExplosion
	if not explosion then return end

	local named = WeaponDefNames[explosion]
	if not named then return end
	local wd = WeaponDefs[named.id] -- resolve to the real def; the name proxy is limited
	if not wd then return end

	local peak = (wd.damageAreaOfEffect or 0) / FLASH_SCALE

	-- Only (re)trigger if brighter than whatever flash is already fading
	local current = 0
	if flashAge then
		current = (flashPeak / (flashAge * 30 + 1)) * 0.5
	end
	if peak * 0.5 > current and peak * 0.5 >= MIN_FLASH then
		flashPeak = peak
		flashAge = 0 -- the original set lightning = false here, so flashes never fired
	end
end

function widget:Update(dt)
	if not base then return end

	-- Pick up the shared seed as soon as the gadget publishes it. The phase
	-- snap happens at frame 0 with the pregame overlay up, so it is not visible.
	if not seeded then
		local seed = spGetGameRulesParam(SEED_PARAM)
		if seed then
			ApplySeed(seed)
		end
	end

	-- Game-time base. dts is elapsed *game* seconds since the last Update, so
	-- the integrators below pause with the sim and scale with game speed,
	-- exactly like the rain cycle they follow.
	local gameTime = GameTime()
	local dts = 0
	if lastGameTime then
		dts = gameTime - lastGameTime
		if dts < 0 then dts = 0 end -- guard against a rewind (replay seek)
	end
	lastGameTime = gameTime

	local sunTime = sunSeed  + gameTime * DAY_CYCLE_SPEED
	local elapsed = rainSeed + gameTime

	-- Sun direction / night factor ------------------------------------------
	local sy = 1 + mathSin(sunTime / 16)
	spSetSunDirection(mathCos(sunTime / 15), sy, mathSin(sunTime / 15))
	-- x^2 + z^2 == 1, so |dir| = sqrt(1 + sy^2); no need to read the sun back
	local normY = sy / mathSqrt(1 + sy * sy)
	if normY < 0 then normY = 0 end
	local p = 1 - normY -- 0 = noon, 1 = midnight
	if p > 1 then p = 1 end

	-- War weariness -----------------------------------------------------------
	damageHeat = damageHeat * (WAR_DECAY ^ (dts * GAME_SPEED))
	warRamp = warRamp + WAR_RAMP_RATE * dts
	if warRamp > damageHeat then warRamp = damageHeat end
	local w = 1 - mathExp(-warRamp / mapK)
	if w > 1 then w = 1 end

	-- Rain cycle: two incommensurate oscillators, so storms vary in timing and
	-- strength, and heavy rain (near 1.0) happens whenever they align. The
	-- original single sinusoid only went positive 29% of the time and touched
	-- its peak for moments once per ~314s cycle.
	local s1 = mathSin(elapsed / RAIN_PERIOD)
	local s2 = mathSin(elapsed / (RAIN_PERIOD * 0.373) + 1.7)
	local rain = (0.6 * s1 + 0.4 * s2 - RAIN_THRESHOLD) / (1 - RAIN_THRESHOLD)
	if rain < 0 then rain = 0 elseif rain > 1 then rain = 1 end

	-- Ground wetness: soaks toward the current rain level while raining, then
	-- dries out slowly, so the ground keeps its wet sheen after a storm passes
	if rain > wetness then
		wetness = wetness + (rain - wetness) * mathMin(1, dts / SOAK_TIME)
	else
		wetness = mathMax(rain, wetness - dts / DRY_TIME)
	end

	-- Lightning flash (real time, so it still fades while paused; also
	-- client-local, since it is triggered from LOS-limited UnitDestroyed) -----
	local flash = 0
	if flashAge then
		flashAge = flashAge + dt
		if flashAge >= FLASH_DURATION then
			flashAge = nil
		else
			flash = (flashPeak / (flashAge * 30 + 1)) * 0.5
			if flash > 1 then flash = 1 end
			if flash < MIN_FLASH then flash = 0 end
		end
	end

	-- Blend weights -----------------------------------------------------------
	kBase  = (1 - p) * (1 - w) * (1 - rain)
	kNight = p    * (1 - w) * (1 - rain)
	kWar   = w    * (1 - p) * (1 - rain)
	kRain  = rain * (1 - p) * (1 - w)

	-- Fog weights omit war entirely, so fog depends only on the shared
	-- night/rain cycle. Dropping the war term from the weights (not just from
	-- the targets) matters: leaving it in would still shrink the base and night
	-- contributions per player.
	fBase  = (1 - p) * (1 - rain)
	fNight = p * (1 - rain)
	fRain  = rain * (1 - p)

	local dr = blend(base.diffuse, TARGETS.diffuse, 1)
	local dg = blend(base.diffuse, TARGETS.diffuse, 2)
	local db = blend(base.diffuse, TARGETS.diffuse, 3)

	-- Minimum brightness floor. The original's ambient floor scaled by the
	-- *diffuse* sum (copy-paste bug); ambient is passed through untouched here,
	-- matching the "use this if it gets too dark" line the author settled on.
	local sum = dr + dg + db
	if sum > 0 and sum < DIFFUSE_FLOOR then
		local f = DIFFUSE_FLOOR / sum
		dr, dg, db = dr * f, dg * f, db * f
	end
	dr, dg, db = dr + flash, dg + flash, db + flash

	-- Specular: night/war blend as before (matching the original's structure,
	-- whose specular base term never carried a rain factor), then lerp toward
	-- the wet sheen by ground wetness
	local kNW = (1 - p) * (1 - w)
	local ts = TARGETS.specular
	local sr = base.specular[1] * kNW + ts.night[1] * p * (1 - w) + ts.war[1] * w * (1 - p)
	local sg = base.specular[2] * kNW + ts.night[2] * p * (1 - w) + ts.war[2] * w * (1 - p)
	local sb = base.specular[3] * kNW + ts.night[3] * p * (1 - w) + ts.war[3] * w * (1 - p)
	sr = sr + (WET_SPEC_RGB[1] - sr) * wetness
	sg = sg + (WET_SPEC_RGB[2] - sg) * wetness
	sb = sb + (WET_SPEC_RGB[3] - sb) * wetness

	if specExpSupported then
		local specExp = baseSpecExp + (WET_EXPONENT - baseSpecExp) * wetness
		sunLighting.groundSpecularExponent = specExp
		sunLighting.modelSpecularExponent  = specExp
	end

	local ar = base.ambient[1] + flash
	local ag = base.ambient[2] + flash
	local ab = base.ambient[3] + flash

	local sl = sunLighting
	sl.groundAmbientColor[1],  sl.groundAmbientColor[2],  sl.groundAmbientColor[3]  = ar, ag, ab
	sl.unitAmbientColor[1],    sl.unitAmbientColor[2],    sl.unitAmbientColor[3]    = ar, ag, ab
	sl.groundDiffuseColor[1],  sl.groundDiffuseColor[2],  sl.groundDiffuseColor[3]  = dr, dg, db
	sl.unitDiffuseColor[1],    sl.unitDiffuseColor[2],    sl.unitDiffuseColor[3]    = dr, dg, db
	sl.groundSpecularColor[1], sl.groundSpecularColor[2], sl.groundSpecularColor[3] = sr, sg, sb
	sl.unitSpecularColor[1],   sl.unitSpecularColor[2],   sl.unitSpecularColor[3]   = sr, sg, sb
	spSetSunLighting(sl)

	local at = atmosphere
	-- Fog density is now rain-only (was max(rain, war)), so it matches for
	-- every player. Lightning still brightens the fog color briefly, which is
	-- a five-second client-local transient by design.
	at.fogStart      = 1 - rain
	at.fogColor[1]   = blendFog(base.fog, TARGETS.fog, 1) + flash
	at.fogColor[2]   = blendFog(base.fog, TARGETS.fog, 2) + flash
	at.fogColor[3]   = blendFog(base.fog, TARGETS.fog, 3) + flash
	at.sunColor[1]   = blend(base.sun, TARGETS.sun, 1) + flash
	at.sunColor[2]   = blend(base.sun, TARGETS.sun, 2) + flash
	at.sunColor[3]   = blend(base.sun, TARGETS.sun, 3) + flash
	at.skyColor[1]   = blend(base.sky, TARGETS.sky, 1)
	at.skyColor[2]   = blend(base.sky, TARGETS.sky, 2)
	at.skyColor[3]   = blend(base.sky, TARGETS.sky, 3)
	at.cloudColor[1] = blend(base.cloud, TARGETS.cloud, 1) + flash
	at.cloudColor[2] = blend(base.cloud, TARGETS.cloud, 2) + flash
	at.cloudColor[3] = blend(base.cloud, TARGETS.cloud, 3) + flash
	spSetAtmosphere(at)

	-- Publish state for the fog/rain effect widgets. They previously divined
	-- this by reading gl.GetAtmosphere back and re-deriving war level from
	-- their own duplicated damage accumulators.
	local wg = WG.weather
	if wg then
		wg.night    = p
		wg.war      = w
		wg.rain     = rain
		wg.wetness  = wetness
		wg.flash    = flash
		wg.fogStart = at.fogStart
		wg.fogR, wg.fogG, wg.fogB = at.fogColor[1], at.fogColor[2], at.fogColor[3]
	end
end

function widget:Shutdown()
	if not base then return end
	spSetSunLighting({
		                 groundAmbientColor  = base.ambient,
		                 groundDiffuseColor  = base.diffuse,
		                 groundSpecularColor = base.specular,
		                 unitAmbientColor    = base.ambient,
		                 unitDiffuseColor    = base.diffuse,
		                 unitSpecularColor   = base.specular,
	                 })
	spSetAtmosphere({
		                fogStart   = base.fogStart,
		                fogEnd     = base.fogEnd,
		                fogColor   = base.fog,
		                sunColor   = base.sun,
		                skyColor   = base.sky,
		                cloudColor = base.cloud,
	                })
	-- The original never restored the sun direction it had been animating
	if baseSunDir and baseSunDir[1] then
		spSetSunDirection(baseSunDir[1], baseSunDir[2], baseSunDir[3])
	end
	if specExpSupported then
		pcall(spSetSunLighting, {
			groundSpecularExponent = baseSpecExp,
			modelSpecularExponent  = baseSpecExp,
		})
	end
	WG.weather = nil
end
