--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    luarules/configs/simpleai/behaviors/b_construction.lua
--  brief:   Construction behavior for the SimpleAI gadget (stage 4 of the
--           modular split). Owns the entire economy-building brain: the
--           priority-chain project selector, factory queues, constructor
--           self-preservation, and every related tunable.
--
--           Registers services.SelectConstructionProject so other behaviors
--           (the commander) can request "build something sensible here" —
--           this module must therefore appear BEFORE b_commander in the
--           core's BEHAVIOR_FILES manifest.
--
--           Owns ctx state: ctx.pacing.factoryDelay / constructorDelay /
--           lastConStart / lastFacStart; increments ctx.counters.converters
--           optimistically on order.
--           Reads: ctx.intel.airThreat + ctx.IsAATurret + ctx.counters.
--           aaTurrets for the reactive anti-air rung (priority 5a).
--
--           Storage growth (priority 5s): raises team storage toward
--           STOR.GOAL over the game, one project at a time. All
--           stock-ratio thresholds in the chain are measured against the
--           signal pool (cfg.SignalPool, owned by the core), not raw
--           storage, so a big bank does not make the AI hoard.
--
--           Stall response: reads ctx.stall (core). While a team is
--           stalling, factory queues are kept short and no new factories
--           are started; while it is stalling on ENERGY, factories lean
--           toward energy-cheap units and no constructors are queued.
--           (Pausing and cancelling factory work is b_throttle's job.)
--
--           Builder safety (SAFE / Hostile): every rung that sends a
--           builder away from the base (far mex spots, reclaim, forward
--           turrets) first checks the destination and the walk to it for
--           armed enemies.
--
--           Reclaim (REC, rungs R and P12): a scanned field of wrecks, a
--           crew of builders sized to it, targeted area-reclaim orders,
--           and extra constructors when the field is rich.
--
--           Forward defense (FWD, rung 5f): a few turrets at the team's
--           most forward extractors and muster point, facing the enemy.
--
--           Herd control (JOB): caps how many builders may answer the
--           same need at once (generators, turrets), recounted from real
--           command queues each team tick.
--
--           Decision trace: every project selection is tallied by rung
--           into ctx.trace[teamID]; the core publishes it for the game
--           recorder widget. Rung labels match the PRIORITY comments.
--
--  license: GNU GPL, v2 or later
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return function(ctx, lib, cfg, services)

	--------------------------------------------------------------------------
	-- Tunables (owned by this behavior)
	--------------------------------------------------------------------------
	-- Constructor caps
	local CONSTRUCTOR_MAX         = 4   -- max constructors for normal AI teams
	local CONSTRUCTOR_MAX_CON_AI  = 12  -- higher cap for dedicated SimpleConstructorAI teams
	-- Minimum frames between STARTING any new constructor on a team. Because every
	-- factory on a team is evaluated in the same GameFrame tick, without this they
	-- all read the same stale count and queue a constructor at once. This rate-limit
	-- lets the count catch up so the hard cap is actually respected.
	local CON_BUILD_SPACING      = 150  -- ~5s at 30Hz

	-- Higher-tier preference. Per-unit build weight scales with (techTier+1)^bias,
	-- so advanced units/factories are chosen far more often while lower tiers still appear.
	local TECH_UNIT_BIAS    = 1.8    -- combat unit tech preference
	local TECH_FAC_BIAS     = 2.4    -- factory tech preference (want advanced plants to unlock advanced units)

	-- Turret demand model
	local TURRET_BASE        = 2     -- always want at least this many turrets once a factory exists
	local TURRET_PER_FAC     = 1     -- + this many wanted per factory
	local TURRET_PER_MEX_DIV = 3     -- + 1 wanted per this many mexes
	local TURRET_CAP         = 20    -- absolute max turrets to build per team

	-- Anti-air demand model. ctx.intel.airThreat[teamID] carries the frame of
	-- the last enemy-aircraft evidence (armed air spotted inside the base scan
	-- in b_defense, or ANY of our units damaged by enemy air, stamped by the
	-- core). While that stamp is fresh, builders raise DEDICATED AA turrets
	-- toward the count below -- a reactive rung that jumps the queue like the
	-- generic under-attack turret slot, because against bombers a random
	-- ground turret is a dead spend. AA turrets are a subset of IsTurret, so
	-- they also count toward TURRET_CAP and the generic desired-turret model.
	local AA_THREAT_MEMORY   = 1800  -- frames the last air evidence stays "fresh" (~60s)
	local AA_BASE            = 2     -- AA turrets wanted while the threat is fresh...
	local AA_PER_FAC_DIV     = 2     -- ...+1 per this many factories
	local AA_CAP             = 6     -- absolute max AA from this reactive model

	local MEX_TARGET_EARLY  = 2      -- grab this many mexes before anything else
	local MEX_TARGET_MID    = 8      -- expand to this many once economy is running
	local MEX_RANGE_EARLY   = 2000   -- mex search radius before base established
	local MEX_RANGE_MID     = 5000   -- mex search radius once we have 2+ factories
	local CONVERTER_MAX     = 3      -- max energy converters per team
	local FACTORY_MAX       = 12     -- max factories per team
	local LAND_FAC_MIN      = 3      -- build at least this many land factories before any air/sea
	-- Factory build pacing. A flat frame-based limiter (like the constructor one),
	-- so the Nth factory is no slower to start than the 2nd. When resources are
	-- overflowing we build them much faster, since extra production capacity is
	-- the best sink for a surplus.
	local FACTORY_SPACING       = 90   -- normal min frames between starting factories (~3s)
	local FACTORY_SPACING_FLOOD = 45   -- min frames when overflowing (~1.5s)

	-- Storage growth model. The AI used to finish every game on the stock
	-- 1k/1k pool, which late-game income fills and drains inside one AI
	-- tick. It now grows storage steadily toward STOR.GOAL:
	--   wanted = the larger of the tech floor below and
	--            STOR.INCOME_SECS seconds of the bigger income,
	--            capped at the tech ceiling below
	-- and, if both stocks are brimming against REAL storage, it heads for
	-- the tech ceiling right away regardless of the schedule.
	-- Storage per tech: smallstorage (200) at tech 1, mediumstorage (2000)
	-- at tech 2, largestorage (20000) at tech 3. The ceilings keep the AI
	-- from chasing a late-game number with early-game buildings.
	-- One storage project per team at a time, at least STOR.SPACING
	-- frames apart, so the climb is gradual and never eats the economy.
	-- Kept in one table (with the per-team pacing state below) because the
	-- project selector is at Lua 5.1's 60-upvalue limit.
	local STOR = {
		GOAL        = 100000, -- end-of-game storage target (metal and energy each)
		TECH_FLOOR  = {       -- minimum storage wanted at each tech level
			[1] = 2000,       -- stock 1k + five small storages
			[2] = 9000,       -- roughly + three or four medium storages
			[3] = 41000,      -- + two large storages
			[4] = 100000,
		},
		TECH_CEIL   = {       -- most storage income/brimming may ask for at each tech level
			[1] = 3000,
			[2] = 15000,
			[3] = 100000,
			[4] = 100000,
		},
		MAX_STEPS   = 20,     -- ignore a storage size that would need more than this many buildings to close the gap
		DEBUG       = true,   -- echo storage decisions to infolog (set false once storage is confirmed working)
		boOk = 0, boFail = 0, geoOk = 0, geoFail = 0, -- placements since the last project selection (see SimpleBuildOrder)
		stallV = ctx.stall and ctx.stall.v or {},   -- [teamID] = combined stall 0..1 (core-owned, see ctx.stall)
		stallE = ctx.stall and ctx.stall.e or {},   -- [teamID] = energy stall 0..1
		STALL_ON = cfg.STALL_ON or 0.20,            -- stalling threshold (core-owned)
		STALL_QUEUE = 2,                            -- factory queue depth while stalling (normally 10)
		SUPPORT_BASE = 1, SUPPORT_PER_FAC = 3, SUPPORT_MAX = 4,   -- per-type cap on support buildings: 1 + one per 3 factories, at most 4
		support = {},                               -- [defID] = true for customparams.unitrole == "Support Building"
		STALL_CON_FLOOR = 4,                        -- an energy stall never holds the team below this many constructors
		CON_EMERGENCY = 2,                          -- below this many, a factory queues one even at the supply cap
		STALL_COST_POWER = 4,                       -- how hard a stall pushes factories toward cheap units
		dbgAt       = {},     -- [teamID] = next frame a "why not" line may be echoed
		trace       = ctx.trace or {},  -- [teamID] = { [rungKey] = count } decision tallies (core-owned, see ctx.trace)
		INCOME_SECS = 30,     -- also want room for this many seconds of income
		BRIM        = 0.88,   -- both stocks above this fraction of REAL storage = brimming
		SPACING     = 900,    -- min frames between storage starts (~30s)
		PENDING_MAX = 3600,   -- give up waiting on an unfinished storage after this (~120s)
		RETRY       = 150,    -- back-off after a failed placement (~5s)
		COST_SECS   = 150,    -- prefer storage costing at most this many seconds of metal income
		FIT         = 1.5,    -- do not pick a storage bigger than this x the remaining gap

		-- defID-keyed, filled at load
		cap  = {},            -- [defID] = storage capacity
		cost = {},            -- [defID] = metal cost
		-- per-team pacing state (owned here, not shared through ctx)
		lastStart = {},       -- [teamID] = frame the last storage was ordered
		pending   = {},       -- [teamID] = frame a storage was ordered and has not finished
		retryAt   = {},       -- [teamID] = earliest frame to try again after a failed placement
	}

	-- Supply on-order accounting. Supply only rises when a depot FINISHES, so
	-- without this every idle builder sees the same shortfall and they all
	-- queue depots at once, tick after tick, which also starves every rung
	-- below supply (storage growth in particular). Supply already ordered is
	-- now counted toward the max when deciding whether more is needed, so
	-- only as many builders as the shortfall calls for go to depots.
	local SUP = {
		ORDER_MAX = 2700,  -- forget on-order supply after this long with no depot ordered/finished (~90s)
		-- Stop adding depots at the game's own supply cap (the supplycap
		-- modoption), not at a number of the AI's choosing. This used to be a
		-- hard-coded 950: a recorded team sat at 968/970 supply for eight
		-- minutes with a full metal bank and nothing it could spend it on.
		CAP       = tonumber((Spring.GetModOptions() or {}).supplycap) or 10000,
		grant   = {},      -- [defID]  = supply granted by a def (depots and supply-granting storage)
		cost    = {},      -- [defID]  = its metal cost
		COST_SECS = 150,   -- prefer a supply building costing at most this many seconds of metal income
		ordered = {},      -- [teamID] = supply ordered but not yet finished
		stamp   = {},      -- [teamID] = frame of the last depot order or completion
	}

	-- Herd control. A need like "energy is low" does not go away until the
	-- thing built for it FINISHES, so every idle builder used to see the same
	-- need and answer it at once: seven builders on seven fusion plants, all
	-- splitting the same energy, none finishing. (There is no build assist in
	-- SF, so every builder on a rung is a separate building.)
	-- JOB tracks which builders are currently working for which need and
	-- caps how many may answer it at the same time. A builder past the cap
	-- falls through to the next rung instead. The ledger is recounted from
	-- the builders' real command queues every team tick, so a builder that
	-- died, finished, fled or was re-tasked stops counting on its own.
	-- (Supply and storage have their own on-order accounting above; factories
	-- and constructors are spaced by their frame limiters.)
	local JOB = {
		MAX = {
			gen = 2,   -- generators / converters under way at once (rungs P2, P7)
			tur = 2,   -- turrets under way at once (rungs 5a, 5b, 5f, 6b, P13)
			-- (the reclaim crew, need "rec", is sized per team by the field: REC.slots)
		},
		RUNG = { P2 = "gen", P7 = "gen", ["5a"] = "tur", ["5b"] = "tur", ["5f"] = "tur", ["6b"] = "tur", P13 = "tur", R = "rec" },
		of     = {},   -- [teamID] = { [unitID] = need } builders currently on a capped need
		active = {},   -- [teamID] = { gen = n, tur = n } recounted every team tick
	}

	-- Income targets required to trigger each tech upgrade.
	-- Key = current tech level. Values are the income thresholds to AIM for.
	local TECH_INCOME_GOALS = {
		[0] = { m = 10,  e = 170  },
		[1] = { m = 20,  e = 560  },
		[2] = { m = 40,  e = 1040 },
		[3] = { m = 80,  e = 3120 },
	}

	-- How strongly to bias toward economy when below the tech threshold.
	-- 0.5 = balanced: economy prioritised but army still builds.
	local TECH_ECONOMY_BIAS = 0.5

	--------------------------------------------------------------------------
	-- Shared state / config
	--------------------------------------------------------------------------
	local mapsizeX          = cfg.mapsizeX
	local mapsizeZ          = cfg.mapsizeZ
	local FACTORY_OVERFLOW  = cfg.FACTORY_OVERFLOW
	local SignalPool        = cfg.SignalPool
	local AIR_FACTORY_NAMES = cfg.AIR_FACTORY_NAMES
	local SEA_FACTORY_NAMES = cfg.SEA_FACTORY_NAMES

	local IsFactory     = ctx.IsFactory
	local IsConstructor = ctx.IsConstructor

	local SimpleFactoriesCount   = ctx.counters.factories
	local SimpleT1Mexes          = ctx.counters.mexes
	local SimpleConstructorCount = ctx.counters.constructors
	local SimpleConverterCount   = ctx.counters.converters
	local SimpleTurretCount      = ctx.counters.turrets
	local SimpleAATurretCount    = ctx.counters.aaTurrets
	local SimpleLandFacCount     = ctx.counters.landFactories
	local IsAATurret             = ctx.IsAATurret
	local SimpleAirThreat        = ctx.intel.airThreat
	local SimpleFactoryDelay     = ctx.pacing.factoryDelay
	local SimpleConstructorDelay = ctx.pacing.constructorDelay
	local SimpleLastConStart     = ctx.pacing.lastConStart
	local SimpleLastFacStart     = ctx.pacing.lastFacStart
	local SimpleUnderAttack      = ctx.intel.underAttack
	local SimpleEnemyBasePos     = ctx.intel.enemyBase
	local TeamTechLevel          = ctx.techLevel
	local SimpleCommanderDefs    = ctx.commanderDefs

	local GetBuildable            = lib.GetBuildable
	local GetBuildableTechBiased  = lib.GetBuildableTechBiased
	local GetWeightedBuildable    = lib.GetWeightedBuildable
	local CombatRoleWeight        = lib.CombatRoleWeight
	local SimpleGetClosestMexSpot = lib.GetClosestMexSpot
	-- Geothermal placement. Buildings that need a vent (the condenser, the
	-- geothermal power plant, the geo metal maker) cannot go through the
	-- normal "next to a friendly building" search: the engine only accepts
	-- them ON a vent, and that search never lands on one except by luck. For
	-- a long time that is exactly what happened: the condenser is tagged as
	-- storage, outbid the real storage buildings, and then failed to place
	-- ~98% of the time, which is why the AI built no storage at all.
	-- Now any needGeo def is sent to the nearest free vent instead.
	local GEO = {
		RANGE = 3500,     -- how far a builder will walk to a vent (elmos)
		NEAR  = 1200,     -- ...the commander, or anyone before the first factory, only this far
		HOME_RANGE = 4500, -- and never to a vent farther than this from the team's start
		CLAIM = 1800,     -- frames a vent stays reserved for the builder sent to it (~60s)
		need  = {},       -- [defID] = true for needGeo defs
		spots = nil,      -- cached vent positions { {x=,y=,z=}, ... }; built on first use
		claim = {},       -- [spotIndex] = frame the reservation expires
		why   = "none",   -- why the last search found nothing: none (no vents on the map) | far | taken | unsafe
	}
	for defID, ud in pairs(UnitDefs) do
		if ud.needGeo then GEO.need[defID] = true end
	end

	-- Nearest vent within GEO.RANGE of the builder that is unreserved and that
	-- the engine will accept this def on right now (so a vent that already
	-- carries a building is skipped). Returns spotIndex, spot or nil.
	local function GeoSpotFor(unitID, project)
		if not GEO.spots then
			if Spring.GetGameFrame() < 1 then return nil end   -- vents not final yet
			-- Two sources, merged: the vents game_geovent_spot_generator
			-- placed (it publishes them as game rules params), and any
			-- geothermal features the map brings itself.
			local spots = {}
			local function Add(x, z)
				for i = 1, #spots do
					local dx, dz = spots[i].x - x, spots[i].z - z
					if dx * dx + dz * dz < 64 * 64 then return end
				end
				spots[#spots + 1] = { x = x, y = Spring.GetGroundHeight(x, z), z = z }
			end
			for i = 1, (Spring.GetGameRulesParam("customGeovent_count") or 0) do
				local x = Spring.GetGameRulesParam("customGeovent_" .. i .. "_x")
				local z = Spring.GetGameRulesParam("customGeovent_" .. i .. "_z")
				if x and z then Add(x, z) end
			end
			local features = Spring.GetAllFeatures()
			for i = 1, #features do
				local fDef = FeatureDefs[Spring.GetFeatureDefID(features[i])]
				if fDef and fDef.geoThermal then
					local x, _, z = Spring.GetFeaturePosition(features[i])
					if x then Add(x, z) end
				end
			end
			GEO.spots = spots
			Spring.Echo("[SimpleAI] geothermal vents known to the AI: " .. #spots)
		end
		GEO.why = (#GEO.spots == 0) and "none" or "far"
		local ux, _, uz = Spring.GetUnitPosition(unitID)
		if not ux then return nil end
		local teamID = Spring.GetUnitTeam(unitID)
		local now = Spring.GetGameFrame()

		-- How far this unit may go for a vent. A recorded 1v1 was lost in the
		-- opening because the commander walked 3,700 elmos to a mid-map vent
		-- before the team had a factory (first factory at 4:09 against the
		-- opponent's 1:23). So: the commander never leaves the base for a
		-- vent, and nobody does before the first factory is up.
		local reach = GEO.RANGE
		local isCommander = ctx.IsCommander and ctx.IsCommander[Spring.GetUnitDefID(unitID) or 0]
		if isCommander or (SimpleFactoriesCount[teamID] or 0) == 0 then
			reach = GEO.NEAR
		end
		-- ...and the vent itself must be within GEO.HOME_RANGE of home, so a
		-- builder already far forward does not chain on to the enemy's side.
		local home = STOR.FWD and STOR.FWD.home[teamID]
		if not home and STOR.FWD then
			local hx, _, hz = Spring.GetTeamStartPosition(teamID)
			if hx and hx >= 0 then home = { x = hx, z = hz }; STOR.FWD.home[teamID] = home end
		end
		local home2 = GEO.HOME_RANGE * GEO.HOME_RANGE

		local bestI, bestD = nil, reach * reach
		for i = 1, #GEO.spots do
			local s = GEO.spots[i]
			local dx, dz = s.x - ux, s.z - uz
			local d = dx * dx + dz * dz
			local nearHome = true
			if home then
				local hdx, hdz = s.x - home.x, s.z - home.z
				nearHome = (hdx * hdx + hdz * hdz) <= home2
			end
			if d < bestD and nearHome then
				if now < (GEO.claim[i] or 0)
						or Spring.TestBuildOrder(project, s.x, s.y, s.z, 0) ~= 2 then
					GEO.why = "taken"    -- a vent in reach, but reserved, built on or blocked
				elseif STOR.Hostile and STOR.Hostile(teamID, ux, uz, s.x, s.z) then
					GEO.why = "unsafe"   -- armed enemies at the vent or on the way
				else
					bestI, bestD = i, d
				end
			end
		end
		if bestI then return bestI, GEO.spots[bestI] end
		return nil
	end

	-- Every placement goes through here: vent buildings to a vent, everything
	-- else to the normal search. It also counts hits and misses so the
	-- decision trace can report them ("bo" / "bo!", and for vent placements
	-- "geo" / "geo!.none" / "geo!.far" / "geo!.taken" / "geo!.unsafe").
	local function SimpleBuildOrder(unitID, project)
		if GEO.need[project] then
			local i, s = GeoSpotFor(unitID, project)
			if i then
				Spring.GiveOrderToUnit(unitID, -project, { s.x, s.y, s.z, 0 }, { "shift" })
				GEO.claim[i] = Spring.GetGameFrame() + GEO.CLAIM
				STOR.geoOk = STOR.geoOk + 1
				return true
			end
			STOR.geoFail = STOR.geoFail + 1
			STOR.geoWhy  = GEO.why
			return false
		end
		if lib.BuildOrder(unitID, project) then
			STOR.boOk = STOR.boOk + 1
			return true
		end
		STOR.boFail = STOR.boFail + 1
		return false
	end
	STOR.GeoSpotFor = GeoSpotFor   -- the storage pick asks "is there a vent for this builder?"
	STOR.geo        = GEO.need

	-- Builder safety. A recorded 28-minute game lost 9 engineers a minute
	-- across six teams, nearly every one of them thousands of elmos from
	-- home: builders were being sent to far mex spots, wrecks and forward
	-- sites with no look at what stood in the way. Hostile() answers "would
	-- this trip take a builder under enemy guns?": armed enemy units near the
	-- destination, or near the straight line to it. Every rung that sends a
	-- builder away from the base asks first. (The AI already reads enemy
	-- positions directly elsewhere; this is no new information.)
	local SAFE = {
		RADIUS = 700,   -- armed enemies within this of a checked point make it unsafe
		STEP   = 900,   -- check a point every this many elmos along the way
		MAX    = 6,     -- most points checked per trip (destination first)
		ALERT  = 800,   -- a builder reacts to enemies within this range of itself
		FLEE_REISSUE = 150,   -- frames between flee orders for one builder (~5s)
		fleeAt = {},    -- [unitID] = frame the next flee order may be given
	}
	local function ArmedEnemyNear(teamID, x, z)
		local nearby = Spring.GetUnitsInCylinder(x, z, SAFE.RADIUS)
		for i = 1, #nearby do
			local other = Spring.GetUnitTeam(nearby[i])
			if other and other ~= teamID and not Spring.AreTeamsAllied(teamID, other) then
				local ud = UnitDefs[Spring.GetUnitDefID(nearby[i]) or 0]
				if ud and ud.weapons and #ud.weapons > 0 then return true end
			end
		end
		return false
	end
	local function Hostile(teamID, fromX, fromZ, toX, toZ)
		if ArmedEnemyNear(teamID, toX, toZ) then return true end
		local dx, dz = toX - fromX, toZ - fromZ
		local dist = math.sqrt(dx * dx + dz * dz)
		local steps = math.min(SAFE.MAX - 1, math.floor(dist / SAFE.STEP))
		-- walk back from the destination; the builder's own position is not
		-- checked (if enemies are on top of it, its flee logic is already running)
		for i = 1, steps do
			local f = 1 - i / (steps + 1)
			if ArmedEnemyNear(teamID, fromX + dx * f, fromZ + dz * f) then return true end
		end
		return false
	end
	STOR.Hostile = Hostile

	-- Forward defense. Ordinary turret rungs build next to whatever friendly
	-- building the builder happens to be near, which means the base. This
	-- puts a FEW turrets where the team actually meets the enemy:
	--   * candidate sites are the team's own extractors and its army muster
	--     point, i.e. ground it already holds;
	--   * a site only counts as forward if it is clearly closer to the enemy
	--     than the team's start position (FWD.ADVANCE);
	--   * only the FWD.SITES most forward sites are considered, each gets at
	--     most FWD.PER_SITE turrets within FWD.COVER of it.
	-- So the total is small and it follows the frontier as the team expands
	-- or is pushed back. Turrets go on the enemy-facing side of the site.
	local FWD = {
		SITES    = 3,      -- how many of the most forward sites get defended
		PER_SITE = { 1, 2, 2, 2 },   -- turrets per site, by tech level
		COVER    = 500,    -- a turret within this many elmos of a site defends it
		ADVANCE  = 0.15,   -- site must be this much closer to the enemy than home is
		SPACING  = 900,    -- min frames between forward turret starts per team (~30s)
		CLAIM    = 2700,   -- a site ordered but not yet started counts as covered this long (~90s)
		last     = {},     -- [teamID] = frame of the last forward order
		claim    = {},     -- [teamID] = { x=, z=, untilFrame= } site a builder is walking to
		home     = {},     -- [teamID] = { x=, z= } start position (cached)
	}
	local IsExtractorDef = ctx.IsExtractor or {}
	local IsTurretDef    = ctx.IsTurret or {}
	local fwdSites, fwdTurX, fwdTurZ = {}, {}, {}   -- scratch

	-- Find the most forward under-defended site and order `unitID` to build a
	-- turret there. Returns true if an order went out. `units` is the team's
	-- unit list, `turretDefs` the non-AA turrets this builder can make.
	local function ForwardTurretOrder(unitID, teamID, units, turretDefs, techLevel, now)
		local enemy = SimpleEnemyBasePos[teamID]
		if not enemy or #turretDefs == 0 then return false end

		local home = FWD.home[teamID]
		if not home then
			local hx, _, hz = Spring.GetTeamStartPosition(teamID)
			if not hx or hx < 0 then return false end
			home = { x = hx, z = hz }
			FWD.home[teamID] = home
		end
		local hdx, hdz = enemy.x - home.x, enemy.z - home.z
		local homeDist = math.sqrt(hdx * hdx + hdz * hdz)
		if homeDist < 1 then return false end
		local maxDist = homeDist * (1 - FWD.ADVANCE)

		-- One pass over the team: forward extractors become sites, turrets
		-- (finished or not) are remembered for the coverage count.
		local nSites, nTur = 0, 0
		local function AddSite(x, z)
			local dx, dz = enemy.x - x, enemy.z - z
			local d = math.sqrt(dx * dx + dz * dz)
			if d <= maxDist then
				nSites = nSites + 1
				local s = fwdSites[nSites]
				if not s then s = {}; fwdSites[nSites] = s end
				s.x, s.z, s.d = x, z, d
			end
		end
		for i = 1, #units do
			local defID = Spring.GetUnitDefID(units[i])
			if defID then
				if IsExtractorDef[defID] then
					local x, _, z = Spring.GetUnitPosition(units[i])
					if x then AddSite(x, z) end
				elseif IsTurretDef[defID] then
					local x, _, z = Spring.GetUnitPosition(units[i])
					if x then nTur = nTur + 1; fwdTurX[nTur], fwdTurZ[nTur] = x, z end
				end
			end
		end
		local muster = ctx.squad and ctx.squad.muster and ctx.squad.muster[teamID]
		if muster and muster.x then AddSite(muster.x, muster.z) end
		if nSites == 0 then return false end

		local claim = FWD.claim[teamID]
		if claim and now < claim.untilFrame then
			nTur = nTur + 1; fwdTurX[nTur], fwdTurZ[nTur] = claim.x, claim.z
		end

		-- Walk the sites from most forward; stop at the first one short of
		-- its turret allowance. Selection-style pick of the next-closest site
		-- keeps this allocation-free (sites are few).
		local allowance = FWD.PER_SITE[techLevel] or 2
		local cover2    = FWD.COVER * FWD.COVER
		local pick
		for rank = 1, math.min(FWD.SITES, nSites) do
			local bi, bd = nil, math.huge
			for i = 1, nSites do
				local s = fwdSites[i]
				if s.d < bd then bi, bd = i, s.d end
			end
			local s = fwdSites[bi]
			local covered = 0
			for t = 1, nTur do
				local dx, dz = fwdTurX[t] - s.x, fwdTurZ[t] - s.z
				if dx * dx + dz * dz <= cover2 then covered = covered + 1 end
			end
			if covered < allowance then pick = s; break end
			s.d = math.huge   -- fully defended: look at the next most forward
		end
		if not pick then return false end
		-- not if the walk there, or the site itself, is under enemy guns
		local ux, _, uz = Spring.GetUnitPosition(unitID)
		if not ux or Hostile(teamID, ux, uz, pick.x, pick.z) then return false end

		-- Place it on the enemy-facing side of the site: straight toward the
		-- enemy first, then fanning out to either side, then further away.
		local ex, ez = enemy.x - pick.x, enemy.z - pick.z
		local el = math.sqrt(ex * ex + ez * ez)
		ex, ez = ex / el, ez / el
		local turretDef = turretDefs[math.random(1, #turretDefs)]
		for ring = 1, 3 do
			local r = 110 + ring * 70
			for step = 0, 4 do
				for side = -1, 1, 2 do
					if step > 0 or side < 0 then
						local a  = side * step * 0.45
						local ca, sa = math.cos(a), math.sin(a)
						local bx = pick.x + (ex * ca - ez * sa) * r
						local bz = pick.z + (ex * sa + ez * ca) * r
						if bx > 128 and bz > 128 and bx < mapsizeX - 128 and bz < mapsizeZ - 128 then
							local by = Spring.GetGroundHeight(bx, bz)
							if Spring.TestBuildOrder(turretDef, bx, by, bz, 0) == 2
									and #Spring.GetUnitsInRectangle(bx - 48, bz - 48, bx + 48, bz + 48) == 0 then
								Spring.GiveOrderToUnit(unitID, -turretDef, { bx, by, bz, 0 }, { "shift" })
								FWD.last[teamID]  = now
								FWD.claim[teamID] = { x = pick.x, z = pick.z, untilFrame = now + FWD.CLAIM }
								return true
							end
						end
					end
				end
			end
		end
		return false
	end
	STOR.Forward = ForwardTurretOrder
	STOR.FWD     = FWD

	-- Reclaim. Wrecks are a large part of SF's economy and the AI used to
	-- ignore them: its one reclaim rung sat at the bottom of the chain and sent
	-- a builder to area-reclaim around the ENEMY base. This is the replacement:
	--   * FIELD: every REC.SCAN frames all reclaimable features are binned
	--     into a coarse grid (metal per cell, metal-weighted center). One scan
	--     serves every AI team.
	--   * CREW: a team keeps up to REC.MAX builders on reclaim, one per
	--     REC.PER_BUILDER metal within reach of home, never more than half its
	--     constructors (herd control, need "rec").
	--   * TARGET: a crew builder is sent to area-reclaim the best cell in its
	--     reach: most metal for the walk, not already taken by a teammate, and
	--     not sitting under enemy guns.
	--   * BUILDERS: when the field near home is rich (REC.RICH), factories are
	--     asked for more constructors, the way a player queues a batch of
	--     builders to go clean up after a battle.
	-- Wrecks and map features carry ENERGY as well as metal, and both count.
	-- A cell's worth is its metal plus its energy at REC.E_WORTH (tripled
	-- while the team is stalling on energy); a resource whose bank is nearly
	-- full counts for nothing, so a team with full metal still goes out for
	-- energy and the other way round. Reclaim only stops when both are full.
	local REC = {
		CELL        = 512,    -- grid cell size (elmos)
		SCAN        = 300,    -- frames between field scans (~10s)
		E_WORTH     = 0.2,    -- what one unit of energy is worth next to one of metal
		E_STALL_MULT = 3,     -- ...multiplied by this while the team is stalling on energy
		MIN_FEATURE = 5,      -- ignore features worth less than this (metal + energy x E_WORTH)
		MIN_CELL    = 150,    -- a cell needs this much worth to be worth a trip
		RANGE       = 4500,   -- how far a builder will go for a cell (elmos)
		RADIUS      = 420,    -- area-reclaim radius ordered at the cell's center
		MAX         = 4,      -- most builders on reclaim at once
		PER_BUILDER = 800,    -- one crew slot per this much worth within reach of home
		RICH        = 4000,   -- worth within reach of home that makes factories add builders
		CLAIM       = 900,    -- frames a cell stays reserved for the builder sent to it (~30s)
		AVOID       = 900,    -- frames a cell is avoided after enemies were seen at it or on the way
		FULL        = 0.80,   -- a resource whose bank is fuller than this counts for nothing
		lastScan    = -99999,
		cells       = {},     -- [index] = { m = metal, e = energy, x =, z = } (worth-weighted center)
		nCellsX     = math.max(1, math.ceil(mapsizeX / 512)),
		claim       = {},     -- [teamID] = { [index] = frame the reservation expires }
		avoid       = {},     -- [teamID] = { [index] = frame the cell may be tried again }
		near        = ctx.reclaim and ctx.reclaim.near or {},   -- [teamID] = worth within reach of home
		slots       = {},     -- [teamID] = crew size the field currently supports
		reclaimable = {},     -- [featureDefID] = true/false (cached)
	}

	local function ReclaimScan(now)
		REC.lastScan = now
		local cells = REC.cells
		for idx, cell in pairs(cells) do cell.m, cell.e, cell.w, cell.x, cell.z = 0, 0, 0, 0, 0 end
		local features = Spring.GetAllFeatures()
		for i = 1, #features do
			local fid   = features[i]
			local fDefID = Spring.GetFeatureDefID(fid)
			local ok = REC.reclaimable[fDefID]
			if ok == nil then
				local fDef = FeatureDefs[fDefID]
				ok = (fDef and fDef.reclaimable and not fDef.geoThermal) and true or false
				REC.reclaimable[fDefID] = ok
			end
			if ok then
				-- returns remainingMetal, maxMetal, remainingEnergy, ...
				local metal, _, energy = Spring.GetFeatureResources(fid)
				metal, energy = metal or 0, energy or 0
				local worth = metal + energy * REC.E_WORTH
				if worth >= REC.MIN_FEATURE then
					local x, _, z = Spring.GetFeaturePosition(fid)
					if x then
						local idx  = math.floor(x / REC.CELL) + math.floor(z / REC.CELL) * REC.nCellsX
						local cell = cells[idx]
						if not cell then cell = { m = 0, e = 0, w = 0, x = 0, z = 0 }; cells[idx] = cell end
						cell.m = cell.m + metal
						cell.e = cell.e + energy
						cell.w = cell.w + worth
						cell.x = cell.x + x * worth
						cell.z = cell.z + z * worth
					end
				end
			end
		end
		for idx, cell in pairs(cells) do
			if cell.w > 0 then cell.x, cell.z = cell.x / cell.w, cell.z / cell.w end
		end
	end

	-- Per team, once per scan: how much metal lies within reach of home, and
	-- how many builders that is worth.
	local function ReclaimTeamUpdate(teamID, constructorCount)
		local home = FWD.home[teamID]
		if not home then
			local hx, _, hz = Spring.GetTeamStartPosition(teamID)
			if not hx or hx < 0 then REC.near[teamID], REC.slots[teamID] = 0, 0; return end
			home = { x = hx, z = hz }
			FWD.home[teamID] = home
		end
		local range2, total = REC.RANGE * REC.RANGE, 0
		for idx, cell in pairs(REC.cells) do
			if cell.w >= REC.MIN_CELL then
				local dx, dz = cell.x - home.x, cell.z - home.z
				if dx * dx + dz * dz <= range2 then total = total + cell.w end
			end
		end
		REC.near[teamID] = total
		local slots = math.floor(total / REC.PER_BUILDER)
		if slots < 1 and total >= REC.MIN_CELL then slots = 1 end
		local half = math.max(1, math.floor((constructorCount or 0) / 2))
		if slots > half then slots = half end
		if slots > REC.MAX then slots = REC.MAX end
		REC.slots[teamID] = slots
	end

	-- Send `unitID` to area-reclaim the best cell in its reach. wMetal and
	-- wEnergy say what each resource is worth to the team right now (0 = its
	-- bank is full). Returns true if an order went out.
	local function ReclaimOrder(unitID, teamID, now, wMetal, wEnergy)
		local ux, _, uz = Spring.GetUnitPosition(unitID)
		if not ux then return false end
		local claim = REC.claim[teamID]
		if not claim then claim = {}; REC.claim[teamID] = claim end
		local avoid = REC.avoid[teamID]
		if not avoid then avoid = {}; REC.avoid[teamID] = avoid end
		local range2 = REC.RANGE * REC.RANGE

		for attempt = 1, 3 do
			local bestIdx, bestScore, bestCell = nil, 0, nil
			for idx, cell in pairs(REC.cells) do
				local worth = cell.m * wMetal + cell.e * wEnergy
				if worth >= REC.MIN_CELL and now >= (claim[idx] or 0) and now >= (avoid[idx] or 0) then
					local dx, dz = cell.x - ux, cell.z - uz
					local d2 = dx * dx + dz * dz
					if d2 <= range2 then
						local score = worth / (math.sqrt(d2) + 600)
						-- ties broken by index so the pick does not depend on
						-- table iteration order
						if score > bestScore or (score == bestScore and bestIdx and idx < bestIdx) then
							bestIdx, bestScore, bestCell = idx, score, cell
						end
					end
				end
			end
			if not bestIdx then return false end

			-- Not under enemy guns: armed enemies at the cell or along the walk
			-- to it rule it out for a while and the next-best cell is tried.
			local hostile = Hostile(teamID, ux, uz, bestCell.x, bestCell.z)
			if hostile then
				avoid[bestIdx] = now + REC.AVOID
			else
				local y = Spring.GetGroundHeight(bestCell.x, bestCell.z)
				Spring.GiveOrderToUnit(unitID, CMD.RECLAIM, { bestCell.x, y, bestCell.z, REC.RADIUS }, 0)
				claim[bestIdx] = now + REC.CLAIM
				return true
			end
		end
		return false
	end
	STOR.Reclaim = ReclaimOrder
	STOR.REC     = REC

	for defID, ud in pairs(UnitDefs) do
		local cp = ud.customParams
		if cp and cp.simpleaiunittype == "storage" then
			STOR.cap[defID]  = math.min(ud.metalStorage or 0, ud.energyStorage or 0)
			STOR.cost[defID] = ud.metalCost or 0
		end
		if cp and cp.unitrole == "Support Building" then STOR.support[defID] = true end
		-- Anything that grants supply is a supply building, storage included:
		-- large storage gives 500 supply (five medium depots' worth) on top
		-- of its storage, in less ground than the depots would take.
		if cp and (cp.simpleaiunittype == "supplydepot" or cp.simpleaiunittype == "storage") then
			local granted = tonumber(cp.supply_granted) or 0
			if granted > 0 then
				SUP.grant[defID] = granted
				SUP.cost[defID]  = ud.metalCost or 0
			end
		end
	end
	do  -- one line at load: which storage defs the AI found, and their size
		local parts = {}
		for defID, cap in pairs(STOR.cap) do
			parts[#parts + 1] = UnitDefs[defID].name .. "=" .. cap .. (STOR.geo[defID] and "(vent)" or "")
		end
		table.sort(parts)
		Spring.Echo("[SimpleAI] storage defs: "
			.. (#parts > 0 and table.concat(parts, ", ") or "NONE FOUND (customparams.simpleaiunittype = \"storage\")"))
	end

	local B = { name = "construction", order = 40 }

	function B.TeamInit(teamID)
		STOR.lastStart[teamID] = -STOR.SPACING
		JOB.of[teamID]     = {}
		JOB.active[teamID] = { gen = 0, tur = 0, rec = 0 }
		SimpleFactoryDelay[teamID]     = 0
		SimpleConstructorDelay[teamID] = 0
		-- Negative seeds so the very first constructor/factory are not gated
		-- by the spacing limiters at game start.
		SimpleLastConStart[teamID]     = -CON_BUILD_SPACING
		SimpleLastFacStart[teamID]     = -FACTORY_SPACING
	end

	--------------------------------------------------------------------------
	-- CONSTRUCTION PROJECT SELECTION
	-- The shared "build something sensible" engine, used by constructors and
	-- factories here and by the commander via the services registry.
	--------------------------------------------------------------------------
	local function SimpleConstructionProjectSelection(
			unitID, unitDefID, unitTeam, allyTeamID, units, allunits, buildType)

		local success = false
		local rung    = "F"   -- which priority rung took this unit (decision trace)

		local nowFrame   = Spring.GetGameFrame()
		-- Adaptive difficulty pacing: >1 slows every constructor/factory start
		-- window, <1 tightens them. Resolved via the services registry because
		-- this selector is also called from b_commander without a tick in hand.
		-- nil (plain SimpleAI teams, or b_adaptive absent) -> stock 1.0.
		local knobsK     = services.GetKnobs and services.GetKnobs(unitTeam)
		local pacingMult = knobsK and knobsK.pacingMult or 1
		-- True only if enough frames have passed since this team last STARTED a
		-- constructor. Shared by every factory/builder so the whole team starts at
		-- most one constructor per CON_BUILD_SPACING, letting the count catch up.
		local conSpacingOk = (nowFrame - (SimpleLastConStart[unitTeam] or 0))
				>= CON_BUILD_SPACING * pacingMult

		local supplyUsed = math.round(Spring.GetTeamRulesParam(unitTeam, "supplyUsed") or 0)
		local supplyMax  = math.round(Spring.GetTeamRulesParam(unitTeam, "supplyMax")  or 0)
		local mcurrent, mstorage, _, mincome = Spring.GetTeamResources(unitTeam, "metal")
		local ecurrent, estorage, _, eincome = Spring.GetTeamResources(unitTeam, "energy")
		-- Signal pools: the denominators for every stock-ratio threshold
		-- below. Equal to raw storage until storage has been built.
		local mpool = SignalPool(mstorage, mincome)
		local epool = SignalPool(estorage, eincome)
		local unitposx, unitposy, unitposz   = Spring.GetUnitPosition(unitID)
		local buildOptions = UnitDefs[unitDefID].buildOptions
		local techLevel    = TeamTechLevel[unitTeam] or 1

		-- Factory pacing: a single per-team frame limiter (no escalating delay), so
		-- factory #8 starts as readily as factory #2. When both metal and energy are
		-- piling up we drop to the faster "flood" spacing and pour the surplus into
		-- new production lines.
		local overflowing  = mstorage > 0 and estorage > 0
				and mcurrent > mpool * FACTORY_OVERFLOW
				and ecurrent > epool * FACTORY_OVERFLOW
		local facSpacing   = (overflowing and FACTORY_SPACING_FLOOD or FACTORY_SPACING)
				* pacingMult
		local facSpacingOk = (nowFrame - (SimpleLastFacStart[unitTeam] or 0)) >= facSpacing

		-- econPressure: 0 = at target, approaches 1 when far below next tech threshold
		local goal = TECH_INCOME_GOALS[techLevel]
		local econPressure = 0
		if goal and techLevel < 4 then
			local mRatio = (goal.m > 0) and math.min(1, mincome / goal.m) or 1
			local eRatio = (goal.e > 0) and math.min(1, eincome / goal.e) or 1
			econPressure = TECH_ECONOMY_BIAS * (1 - math.min(mRatio, eRatio))
		end

		-- Stall signal (owned by the core): how far demand outruns income,
		-- 0..1. `stalling` (combined, metal discounted) gates adding
		-- factories and keeps factory queues short. `eStalling` (energy
		-- only) is what makes factories lean toward cheap units and stops
		-- new constructors: energy cost climbs with tech, so that is the
		-- stall cheaper production can actually fix.
		local eStall    = STOR.stallE[unitTeam] or 0
		local stalling  = (STOR.stallV[unitTeam] or 0) >= STOR.STALL_ON
		local eStalling = eStall >= STOR.STALL_ON

		-- TryBuild: find first unit from defList that is in our build options,
		-- shuffle so we don't always pick the same one.
		local function TryBuild(defList, orderFn)
			if not defList or #defList == 0 then return false end
			local shuffled = {}
			for _, v in ipairs(defList) do shuffled[#shuffled + 1] = v end
			for d = #shuffled, 2, -1 do
				local j = math.random(1, d)
				shuffled[d], shuffled[j] = shuffled[j], shuffled[d]
			end
			for _, project in ipairs(shuffled) do
				for i2 = 1, #buildOptions do
					if buildOptions[i2] == project then
						orderFn(project)
						return true
					end
				end
			end
			return false
		end

		-- Weighted-random variant: takes {id=,w=} pairs (from GetWeightedBuildable),
		-- filters to what this builder/factory can actually make, and picks one with
		-- probability proportional to weight. Used for combat composition control.
		local function TryBuildWeighted(weighted, orderFn)
			if not weighted or #weighted == 0 then return false end
			local cands, total = {}, 0
			for _, e in ipairs(weighted) do
				for i2 = 1, #buildOptions do
					if buildOptions[i2] == e.id then
						cands[#cands + 1] = e
						total = total + e.w
						break
					end
				end
			end
			if total <= 0 then return false end
			-- While stalling on ENERGY, lean toward units that are cheap in
			-- energy: weight x (cheapest / cost) ^ (POWER x stall). At the
			-- stall threshold that is roughly "ten times the price, a sixth
			-- as likely"; a deep stall all but rules expensive units out.
			-- Energy cost climbs with tech level in SF, so this steers
			-- production back toward lower tiers until income catches up.
			local wOf = nil
			if eStalling then
				local minCost = math.huge
				for _, e in ipairs(cands) do
					local cost = UnitDefs[e.id].energyCost or 0
					if cost < 1 then cost = 1 end
					if cost < minCost then minCost = cost end
				end
				local power = STOR.STALL_COST_POWER * eStall
				wOf, total = {}, 0
				for i2, e in ipairs(cands) do
					local cost = UnitDefs[e.id].energyCost or 0
					if cost < 1 then cost = 1 end
					wOf[i2] = e.w * (minCost / cost) ^ power
					total = total + wOf[i2]
				end
				if total <= 0 then return false end
			end
			local roll, acc = math.random() * total, 0
			for i2, e in ipairs(cands) do
				acc = acc + (wOf and wOf[i2] or e.w)
				if roll <= acc then
					orderFn(e.id)
					return true
				end
			end
			orderFn(cands[#cands].id)   -- float-rounding fallback
			return true
		end

		local function NearMe(project)
			local x, y, z = Spring.GetUnitPosition(unitID)
			-- Use a larger offset so we don't place inside the caller's own footprint.
			-- Also nudge away from map edges.
			local ox = math.random(-256, 256)
			local oz = math.random(-256, 256)
			if x + ox < 256 then ox = math.abs(ox) end
			if x + ox > mapsizeX - 256 then ox = -math.abs(ox) end
			if z + oz < 256 then oz = math.abs(oz) end
			if z + oz > mapsizeZ - 256 then oz = -math.abs(oz) end
			local bx, bz = x + ox, z + oz
			local by = Spring.GetGroundHeight(bx, bz)
			local facing = math.random(0, 3)
			local testpos = Spring.TestBuildOrder(project, bx, by, bz, facing)
			if testpos == 2 then
				Spring.GiveOrderToUnit(unitID, -project, { bx, by, bz, facing }, 0)
			else
				-- Fall back to SimpleBuildOrder if direct placement failed
				SimpleBuildOrder(unitID, project)
			end
		end

		local function AtMex(project, spot)
			Spring.GiveOrderToUnit(unitID, -project,
			                       { spot.x, spot.y, spot.z, 0 }, { "shift" })
		end

		SimpleFactoryDelay[unitTeam]     = SimpleFactoryDelay[unitTeam] - 1
		SimpleConstructorDelay[unitTeam] = SimpleConstructorDelay[unitTeam] - 1

		local r = math.random(0, 20)

		-- Dynamic mex search range: cast a wide net once we have factories running
		local mexRange  = (SimpleFactoriesCount[unitTeam] >= 2) and MEX_RANGE_MID or MEX_RANGE_EARLY
		local mexspot   = SimpleGetClosestMexSpot(unitposx, unitposz, mexRange)
		-- Also look globally for any unclaimed mex (no range limit) for roaming decisions
		local mexAny    = SimpleGetClosestMexSpot(unitposx, unitposz, nil)

		-- Fetch current tech-appropriate lists
		local extractors   = GetBuildable(unitTeam, "extractor")
		local generators   = GetBuildable(unitTeam, "generator")
		local converters   = GetBuildable(unitTeam, "converter")
		local turrets      = GetBuildable(unitTeam, "turret")
		local supplies     = GetBuildable(unitTeam, "supply")
		local storages     = GetBuildable(unitTeam, "storage")
		local factories    = GetBuildableTechBiased(unitTeam, "factory", TECH_FAC_BIAS)
		local constructors = GetBuildable(unitTeam, "constructor")
		local combats      = GetWeightedBuildable(unitTeam, "combat", TECH_UNIT_BIAS, CombatRoleWeight)
		local buildings    = GetBuildable(unitTeam, "building")

		-- Split factories: only offer air/sea once we have enough land factories
		local landFacCount  = SimpleLandFacCount[unitTeam] or 0
		local landFactories = {}
		local extraFactories = {}
		for _, id in ipairs(factories) do
			if AIR_FACTORY_NAMES[UnitDefs[id] and UnitDefs[id].name]
					or SEA_FACTORY_NAMES[UnitDefs[id] and UnitDefs[id].name] then
				extraFactories[#extraFactories + 1] = id
			else
				landFactories[#landFactories + 1] = id
			end
		end
		-- Before LAND_FAC_MIN land factories, only offer land factories
		if landFacCount < LAND_FAC_MIN then
			factories = landFactories
		end

		-- Dedicated AA subset of the buildable turret list. Small list,
		-- filtered per call; the generic turret bucket keeps its AA entries
		-- too, so the random baseline mix is unchanged.
		local aaTurrets = {}
		for _, id in ipairs(turrets) do
			if IsAATurret[id] then aaTurrets[#aaTurrets + 1] = id end
		end

		local turretCount  = SimpleTurretCount[unitTeam] or 0
		local belowTurretCap = turretCount < TURRET_CAP
		-- How many turrets this base actually wants, scaled to its size.
		local desiredTurrets = math.min(TURRET_CAP,
			TURRET_BASE
			+ (SimpleFactoriesCount[unitTeam] or 0) * TURRET_PER_FAC
			+ math.floor((SimpleT1Mexes[unitTeam] or 0) / TURRET_PER_MEX_DIV))
		local underDefended = (SimpleFactoriesCount[unitTeam] or 0) > 0
			and turretCount < desiredTurrets and belowTurretCap
		local canAffordTurret = ecurrent > epool * 0.20 and mcurrent > mpool * 0.15

		-- AA demand: only while air evidence is fresh, only if this faction
		-- actually has AA turrets buildable at current tech, only below the
		-- AA and overall turret caps.
		local airStamp  = SimpleAirThreat[unitTeam]
		local airFresh  = airStamp and (nowFrame - airStamp) < AA_THREAT_MEMORY
		local desiredAA = math.min(AA_CAP, AA_BASE
			+ math.floor((SimpleFactoriesCount[unitTeam] or 0) / AA_PER_FAC_DIV))
		local needAA    = airFresh and #aaTurrets > 0
			and (SimpleAATurretCount[unitTeam] or 0) < desiredAA
			and belowTurretCap and canAffordTurret

		-- Herd control (see JOB). This unit is idle, so whatever it was doing
		-- for a capped need is over.
		local jobs, active = JOB.of[unitTeam], JOB.active[unitTeam]
		if jobs and jobs[unitID] then
			active[jobs[unitID]] = math.max(0, active[jobs[unitID]] - 1)
			jobs[unitID] = nil
		end
		local genRoom = (not active) or active.gen < JOB.MAX.gen
		local turretRoom = (not active) or active.tur < JOB.MAX.tur
		if not turretRoom then
			underDefended, needAA = false, false
		end
		-- Reclaim (see REC). What each resource is worth to the team right
		-- now: nothing if its bank is nearly full, and energy counts triple
		-- while the team is stalling on it. Both zero = nothing to gain.
		local recWM = (mcurrent < mstorage * STOR.REC.FULL) and 1 or 0
		local recWE = (ecurrent < estorage * STOR.REC.FULL)
				and STOR.REC.E_WORTH * (eStalling and STOR.REC.E_STALL_MULT or 1) or 0
		local reclaimUseful = (recWM + recWE) > 0
		-- Reclaim crew: builders only, while the field supports another crew
		-- member.
		local reclaimOk = buildType == "Builder" and active and reclaimUseful
				and active.rec < (STOR.REC.slots[unitTeam] or 0)
				and SimpleFactoriesCount[unitTeam] > 0

		-- Forward defense (see FWD): builders only, one start per spacing
		-- window, never while stalling, and only with room under the turret
		-- cap. Whether a forward site actually needs a turret is decided
		-- inside the rung, by STOR.Forward.
		local forwardOk = buildType == "Builder" and turretRoom and belowTurretCap
				and not stalling
				and SimpleFactoriesCount[unitTeam] > 0
				and (nowFrame - (STOR.FWD.last[unitTeam] or -99999)) >= STOR.FWD.SPACING * pacingMult
		-- The energy rung's own trigger, unchanged; genRoom decides whether
		-- THIS builder may answer it.
		local energyWanted = ecurrent < epool * 0.40 or eincome <= 80
				or (econPressure > 0.5 and goal and eincome < goal.e * 0.6)
				or eStalling   -- demand is outrunning income, whatever the bank says

		local function CanMake(defID)
			for i2 = 1, #buildOptions do
				if buildOptions[i2] == defID then return true end
			end
			return false
		end

		-- Supply demand, counting depots already on order (see SUP above).
		local supplyOrdered = SUP.ordered[unitTeam] or 0
		if supplyOrdered > 0
				and (nowFrame - (SUP.stamp[unitTeam] or 0)) >= SUP.ORDER_MAX then
			supplyOrdered = 0            -- stale: a builder died on the way
			SUP.ordered[unitTeam] = 0
		end
		local supplyPlanned = supplyMax + supplyOrdered
		local needSupply = SimpleFactoriesCount[unitTeam] > 0
				and ((supplyUsed > supplyPlanned * 0.55 and supplyPlanned < SUP.CAP)
					or supplyPlanned < 20)

		-- Storage demand. `storagePick` is the def this builder should
		-- raise right now, or nil. Capacity that is ordered but not yet
		-- finished blocks further starts (STOR.pending), so four idle
		-- builders in the same tick cannot all start one.
		local storagePick
		local haveStorage = math.min(mstorage, estorage)
		local wantStorage = 0
		do
			local ceil = STOR.TECH_CEIL[techLevel] or STOR.GOAL
			wantStorage = math.max(mincome, eincome) * STOR.INCOME_SECS
			if mcurrent > mstorage * STOR.BRIM and ecurrent > estorage * STOR.BRIM then
				wantStorage = ceil   -- brimming: take the next step now
			end
			if wantStorage > ceil then wantStorage = ceil end
			local floor = STOR.TECH_FLOOR[techLevel] or 0
			if wantStorage < floor then wantStorage = floor end
			local gap = wantStorage - haveStorage

			local pendingAt = STOR.pending[unitTeam]
			if pendingAt and (nowFrame - pendingAt) >= STOR.PENDING_MAX then
				STOR.pending[unitTeam] = nil   -- builder died or order was lost
				pendingAt = nil
			end

			-- No "can we afford it" gate here on purpose: a team that spends
			-- everything it earns sits at the bottom of its pool permanently
			-- (AdaptiveAI rests exactly ON the NeverStall floor), so any such
			-- gate reads "broke" forever. The one-at-a-time lock, the spacing
			-- and the income-proportional size pick are the brakes instead.
			local spacingOk = (nowFrame - (STOR.lastStart[unitTeam] or 0))
					>= STOR.SPACING * pacingMult
			if gap > 0 and not pendingAt
					and #storages > 0
					and SimpleFactoriesCount[unitTeam] > 0
					and nowFrame >= (STOR.retryAt[unitTeam] or 0)
					and spacingOk then
				-- Biggest storage this builder can make that is neither out
				-- of proportion to income nor far past the gap; otherwise the
				-- smallest one that is still worth building. Sizes too small
				-- to matter for this gap are skipped, so a tech 2+ base does
				-- not get carpeted in small storages.
				local costBudget = mincome * STOR.COST_SECS
				local minCap     = gap / STOR.MAX_STEPS
				-- Vent storage (the condenser) is a candidate only when a free
				-- vent is within this builder's reach; on equal capacity the
				-- cheaper building wins, which is how the condenser beats
				-- medium storage wherever a vent is available.
				local bestCap, bestCost, smallest, smallestCap = 0, math.huge, nil, math.huge
				for _, id in ipairs(storages) do
					local cap = STOR.cap[id] or 0
					if cap > 0 and cap >= minCap and CanMake(id)
							and (not STOR.geo[id] or STOR.GeoSpotFor(unitID, id)) then
						local cost = STOR.cost[id] or 0
						if cap < smallestCap then smallest, smallestCap = id, cap end
						if (cap > bestCap or (cap == bestCap and cost < bestCost))
								and cost <= costBudget
								and cap <= gap * STOR.FIT then
							storagePick, bestCap, bestCost = id, cap, cost
						end
					end
				end
				storagePick = storagePick or smallest
			end

			if STOR.DEBUG and gap > 0 and not storagePick and not pendingAt and spacingOk
					and buildType ~= "Factory"
					and nowFrame >= (STOR.dbgAt[unitTeam] or 0) then
				STOR.dbgAt[unitTeam] = nowFrame + 900
				Spring.Echo(("[SimpleAI] storage: team %d tech %d has %d wants %d but no pick"
					.. " (storage defs at this tech: %d, factories: %d, builder: %s)"):format(
					unitTeam, techLevel, haveStorage, wantStorage, #storages,
					SimpleFactoriesCount[unitTeam] or 0, UnitDefs[unitDefID].name))
			end
		end

		-- -------------------------------------------------------
		-- BUILDER / COMMANDER priority chain
		-- -------------------------------------------------------
		if buildType == "Builder" or buildType == "Commander" then

			-- PRIORITY 1: early mexes (always grab the first few immediately)
			if mexspot and SimpleT1Mexes[unitTeam] < MEX_TARGET_EARLY then
				rung = "P1"
				success = TryBuild(extractors, function(p) AtMex(p, mexspot) end)

				-- PRIORITY 5s: STORAGE growth. The team is below its storage
				-- schedule (or brimming) and nothing is already on order.
				-- Sits ABOVE the energy rung on purpose. A recorded game showed
				-- why: once income outgrows the bank (9,000 E/s into 2,600
				-- storage) the stock reads near zero every tick, the energy
				-- rung below fires forever, and nothing under it ever runs,
				-- storage included, which is the one thing that would fix the
				-- reading. storagePick already carries the pacing (one project
				-- at a time, spaced out), so this costs one builder briefly.
			elseif storagePick then
				rung = "5s"
				if SimpleBuildOrder(unitID, storagePick) then
					STOR.lastStart[unitTeam] = nowFrame
					STOR.pending[unitTeam]   = nowFrame
					success = true
					if STOR.DEBUG then
						Spring.Echo(("[SimpleAI] storage: team %d tech %d ordered %s (has %d, wants %d)"):format(
							unitTeam, techLevel, UnitDefs[storagePick].name, haveStorage, wantStorage))
					end
				else
					STOR.retryAt[unitTeam] = nowFrame + STOR.RETRY
					-- Why not: tally the placement search's own reasons into
					-- the trace (5s.blocked / 5s.occupied / 5s.crowded /
					-- 5s.noanchor are candidate-site counts).
					local ps    = (not STOR.geo[storagePick]) and lib.placeStats
					local tally = STOR.trace[unitTeam]
					if ps and tally then
						tally["5s.blocked"]  = (tally["5s.blocked"]  or 0) + ps.blocked
						tally["5s.occupied"] = (tally["5s.occupied"] or 0) + ps.occupied
						tally["5s.crowded"]  = (tally["5s.crowded"]  or 0) + ps.crowded
						tally["5s.noanchor"] = (tally["5s.noanchor"] or 0) + ps.noAnchor
					end
					if STOR.DEBUG then
						Spring.Echo(("[SimpleAI] storage: team %d found no place for %s by %s"
							.. " (sites %d: blocked %d, occupied %d, crowded %d; empty rings %d)"):format(
							unitTeam, UnitDefs[storagePick].name, UnitDefs[unitDefID].name,
							ps and ps.sites or -1, ps and ps.blocked or -1, ps and ps.occupied or -1,
							ps and ps.crowded or -1, ps and ps.noAnchor or -1))
					end
					storagePick = nil   -- tried and failed; not "preempted"
				end

				-- PRIORITY 2: energy - urgent if low or econ pressure is high
			elseif energyWanted and genRoom then
				rung = "P2"
				if mcurrent > mpool * 0.60 and SimpleConverterCount[unitTeam] < CONVERTER_MAX then
					if TryBuild(converters, function(p) SimpleBuildOrder(unitID, p) end) then
						SimpleConverterCount[unitTeam] = SimpleConverterCount[unitTeam] + 1
						success = true
					end
				end
				if not success then
					success = TryBuild(generators, function(p) SimpleBuildOrder(unitID, p) end)
				end

				-- PRIORITY 3: metal income low and econ pressure high — grab more mexes
			elseif econPressure > 0.5 and goal and mincome < goal.m * 0.6
					and mexspot and SimpleT1Mexes[unitTeam] < MEX_TARGET_MID then
				rung = "P3"
				success = TryBuild(extractors, function(p) AtMex(p, mexspot) end)

				-- PRIORITY 4: supply if running short, after counting what is
				-- already on order. The building that grants the MOST supply
				-- wins, storage included, as long as income can carry its
				-- price: at tech 3 that is large storage (500 supply and 20k
				-- storage in one footprint) instead of five medium depots.
				-- A recorded 78-minute game ended with 100 to 500 medium
				-- depots per team; this is the fix. If the first choice finds
				-- no site, the next one down is tried in the same breath.
			elseif needSupply then
				rung = "P4"
				local budget = mincome * SUP.COST_SECS
				local tried  = {}
				for attempt = 1, 3 do
					local pick, best, cheapest, cheapestCost = nil, 0, nil, math.huge
					local function Consider(id)
						local g = SUP.grant[id]
						if g and not tried[id] and CanMake(id)
								and (not STOR.geo[id] or STOR.GeoSpotFor(unitID, id)) then
							local cost = SUP.cost[id] or 0
							if cost < cheapestCost then cheapest, cheapestCost = id, cost end
							if g > best and cost <= budget then pick, best = id, g end
						end
					end
					for _, id in ipairs(supplies) do Consider(id) end
					for _, id in ipairs(storages) do Consider(id) end
					pick = pick or cheapest
					if not pick then break end
					tried[pick] = true
					if SimpleBuildOrder(unitID, pick) then
						SUP.ordered[unitTeam] = supplyOrdered + SUP.grant[pick]
						SUP.stamp[unitTeam]   = nowFrame
						success = true
						break
					end
				end

				-- PRIORITY 5: build first factory
			elseif SimpleFactoriesCount[unitTeam] == 0 and SimpleFactoryDelay[unitTeam] <= 0 then
				rung = "P5"
				if TryBuild(factories, function(p) SimpleBuildOrder(unitID, p) end) then
					SimpleFactoryDelay[unitTeam] = 120
					SimpleLastFacStart[unitTeam] = nowFrame
					success = true
				end

				-- PRIORITY 5a: ANTI-AIR — enemy aircraft were seen over the base
				-- or have hit us recently, and we are short of dedicated AA:
				-- raise it immediately. Outranks the generic reactive rung
				-- because when the attacker is a bomber, the generic slot's
				-- random pick is usually a turret that cannot shoot back.
			elseif needAA and buildType ~= "Commander" then
				rung = "5a"
				success = TryBuild(aaTurrets, function(p) SimpleBuildOrder(unitID, p) end)

				-- PRIORITY 5b: REACTIVE defense — if the base is under attack and we
				-- are under-defended, throw up a turret immediately (jumps the queue).
			elseif SimpleUnderAttack[unitTeam] and underDefended and canAffordTurret
					and buildType ~= "Commander" then
				rung = "5b"
				success = TryBuild(turrets, function(p) SimpleBuildOrder(unitID, p) end)

				-- PRIORITY R: RECLAIM crew. A slot is open and wrecks are in
				-- reach: go and collect them. If no safe, unclaimed cell is in
				-- reach of THIS builder it falls through to building this tick
				-- (the open slot is left for a builder who is closer).
			elseif reclaimOk and STOR.Reclaim(unitID, unitTeam, nowFrame, recWM, recWE) then
				rung    = "R"
				success = true

				-- PRIORITY 5f: FORWARD defense. A few turrets at the team's most
				-- forward extractors and its muster point, on the side facing
				-- the enemy. Tried once per spacing window whether or not a
				-- site needed one, so it never holds a builder up.
			elseif forwardOk then
				rung = "5f"
				local ground = {}
				for _, id in ipairs(turrets) do
					if not IsAATurret[id] and CanMake(id) then ground[#ground + 1] = id end
				end
				if STOR.Forward(unitID, unitTeam, units, ground, techLevel, nowFrame) then
					success = true
				else
					-- nothing forward needs a turret (or no room there): do
					-- not ask again until the next window
					STOR.FWD.last[unitTeam] = nowFrame
				end

				-- PRIORITY 5c: OVERFLOW → production. If resources are piling up, the
				-- single best thing to do is add a factory. This jumps ahead of mex
				-- expansion / generators / constructors / roaming so a surplus turns
				-- into production capacity fast instead of sitting in storage.
			elseif overflowing and not stalling and SimpleFactoriesCount[unitTeam] > 0
					and SimpleFactoriesCount[unitTeam] < FACTORY_MAX
					and facSpacingOk then
				rung = "5c"
				if TryBuild(factories, function(p) SimpleBuildOrder(unitID, p) end) then
					SimpleLastFacStart[unitTeam] = nowFrame
					success = true
				end

				-- PRIORITY 6: mid-game mex expansion (factory exists, energy healthy)
			elseif mexspot and SimpleT1Mexes[unitTeam] < MEX_TARGET_MID
					and SimpleFactoriesCount[unitTeam] > 0
					and ecurrent > epool * 0.30
					and not STOR.Hostile(unitTeam, unitposx, unitposz, mexspot.x, mexspot.z) then
				rung = "P6"
				success = TryBuild(extractors, function(p) AtMex(p, mexspot) end)

				-- PRIORITY 6b: STEADY defense — keep building toward the desired turret
				-- count. Gated by a coin-flip so it interleaves with expansion rather
				-- than monopolising the builder. (Builders only; commander keeps teching.)
			elseif underDefended and canAffordTurret and buildType ~= "Commander"
					and math.random(0, 1) == 0 then
				rung = "6b"
				success = TryBuild(turrets, function(p) SimpleBuildOrder(unitID, p) end)

				-- PRIORITY 7: econ-biased generator building (to hit tech income target)
			elseif genRoom and econPressure > 0.3 and goal and eincome < goal.e then
				rung = "P7"
				success = TryBuild(generators, function(p) SimpleBuildOrder(unitID, p) end)

				-- PRIORITY 8: expand constructors
			elseif not stalling and ecurrent > epool * 0.50 and mcurrent > mpool * 0.45
					and conSpacingOk
					and SimpleConstructorCount[unitTeam] < CONSTRUCTOR_MAX
					and supplyUsed < supplyMax - 5 then
				rung = "P8"

				-- A commander may occasionally assist-build another commander; that
				-- does not count against the constructor rate limit.
				if buildType == "Commander" and math.random(0, 2) == 0 then
					success = TryBuild(SimpleCommanderDefs, function(p) NearMe(p) end)
				end
				if not success then
					local builtCon = TryBuild(constructors, function(p) NearMe(p) end)
					if builtCon then
						SimpleLastConStart[unitTeam] = nowFrame
						success = true
					end
				end

				-- PRIORITY 9: more factories (steady expansion when resources allow)
			elseif not stalling and ecurrent > epool * 0.50 and mcurrent > mpool * 0.50
					and SimpleFactoriesCount[unitTeam] < FACTORY_MAX
					and facSpacingOk then
				rung = "P9"
				if TryBuild(factories, function(p) SimpleBuildOrder(unitID, p) end) then
					SimpleLastFacStart[unitTeam] = nowFrame
					success = true
				end

				-- (PRIORITY 10, "storage when overflowing", is gone: it sat below
				-- rungs that always fired first. Storage is priority 5s now.)

				-- PRIORITY 11: roam to any unclaimed mex on the map (builders only)
				-- This fires before turrets so expansion always beats defense building.
			elseif mexAny and buildType ~= "Commander"
					and SimpleFactoriesCount[unitTeam] > 0
					and not STOR.Hostile(unitTeam, unitposx, unitposz, mexAny.x, mexAny.z) then
				rung = "P11"
				success = TryBuild(extractors, function(p) AtMex(p, mexAny) end)

				-- PRIORITY 12: spare-time reclaim. A builder with nothing better
				-- to do collects wrecks too, crew slot or not (same targeting as
				-- rung R: a real cell in reach, never a blind sweep at the enemy
				-- base as this rung used to do).
			elseif buildType == "Builder" and reclaimUseful
					and STOR.Reclaim(unitID, unitTeam, nowFrame, recWM, recWE) then
				rung    = "P12"
				success = true

				-- PRIORITY 13: extra defense only if still under the desired count
				-- (steady/reactive slots above are the primary defense builders).
				-- (There is no repair in SF, so the old area-repair slot is gone;
				-- r == 7 now falls through to the fallback below.)
			elseif (r == 5 or r == 6) and underDefended and canAffordTurret then
				rung = "P13"
				success = TryBuild(turrets, function(p) SimpleBuildOrder(unitID, p) end)

				-- FALLBACK: misc buildings only — no extra turret roll here
			else
				rung = "FB"
				if #buildings > 0 and math.random(0, 1) == 0 then
					-- Support buildings (cloaking towers, heal stations, shield
					-- generators) are worth having and worthless in bulk: one
					-- recorded base had 43 cloaking towers and 29 heal stations.
					-- Each type is capped by base size; other misc buildings
					-- (research centers and so on) are not limited here.
					local cap = math.min(STOR.SUPPORT_MAX,
						STOR.SUPPORT_BASE + math.floor((SimpleFactoriesCount[unitTeam] or 0) / STOR.SUPPORT_PER_FAC))
					local have = {}
					for i = 1, #units do
						local d = Spring.GetUnitDefID(units[i])
						if d and STOR.support[d] then have[d] = (have[d] or 0) + 1 end
					end
					local allowed = {}
					for _, id in ipairs(buildings) do
						if not STOR.support[id] or (have[id] or 0) < cap then
							allowed[#allowed + 1] = id
						end
					end
					success = TryBuild(allowed, function(p) SimpleBuildOrder(unitID, p) end)
				end
				-- If still no success and there are unclaimed mexes, go get one
				if not success and mexAny
						and not STOR.Hostile(unitTeam, unitposx, unitposz, mexAny.x, mexAny.z) then
					success = TryBuild(extractors, function(p) AtMex(p, mexAny) end)
				end
			end

			-- -------------------------------------------------------
			-- FACTORY queue
			-- -------------------------------------------------------
		elseif buildType == "Factory" then
			-- A factory b_throttle has put on WAIT (stall relief) gets nothing
			-- new queued. While stalling the queue is kept short so the
			-- cheaper-unit preference takes effect right away instead of
			-- sitting behind ten pre-committed expensive units.
			local head = Spring.GetFactoryCommands(unitID, 1)
			if head and head[1] and head[1].id == CMD.WAIT then
				rung    = "F.wait"
				success = true
			elseif #Spring.GetFullBuildQueue(unitID, 0) == 0
					and supplyUsed >= supplyMax * 0.95
					and (SimpleConstructorCount[unitTeam] or 0) < STOR.CON_EMERGENCY
					and conSpacingOk then
				-- At the supply cap with almost no builders: without builders
				-- nobody can raise the cap, so one constructor goes to the head
				-- of an empty queue and takes the next supply that frees up.
				rung = "F.con"
				success = TryBuild(constructors, function(p)
					local x, y, z = Spring.GetUnitPosition(unitID)
					Spring.GiveOrderToUnit(unitID, -p, { x, y, z, 0 }, 0)
				end)
				if success then SimpleLastConStart[unitTeam] = nowFrame end
			elseif #Spring.GetFullBuildQueue(unitID, 0) < (stalling and STOR.STALL_QUEUE or 10)
					and supplyUsed < supplyMax * 0.95 then
				local luaAI = Spring.GetTeamLuaAI(unitTeam)
				local isConAI = string.sub(luaAI, 1, 19) == 'SimpleConstructorAI'
				local conCap  = isConAI and CONSTRUCTOR_MAX_CON_AI or CONSTRUCTOR_MAX
				-- Two-part guard against worker floods:
				--   1. Hard cap: never exceed conCap live constructors.
				--   2. Spacing: only ONE constructor may START per team per window.
				-- Without (2) every factory evaluates in the same tick, all see the
				-- same stale count, and all queue a constructor at once. Dedicated
				-- SimpleConstructorAI teams skip the spacing (it's their whole job)
				-- but are still bounded by the higher cap.
				-- A rich reclaim field near home raises the builder cap by one
				-- per crew slot it could fill (up to REC.MAX): the extra hands
				-- are what a player queues up to clean a battlefield.
				local recNear = STOR.REC.near[unitTeam] or 0
				if recNear >= STOR.REC.RICH and not isConAI then
					conCap = conCap + math.min(STOR.REC.MAX, math.floor(recNear / STOR.REC.PER_BUILDER))
				end
				local haveConRoom = (SimpleConstructorCount[unitTeam] or 0) < conCap
				local wantConstructor = haveConRoom
						-- an energy stall is no time for a builder boom, but
						-- builders are also what ends it: never hold the team
						-- below STALL_CON_FLOOR (a recorded team stalled for ten
						-- minutes with one constructor because of exactly that)
						and (isConAI or not eStalling
							or (SimpleConstructorCount[unitTeam] or 0) < STOR.STALL_CON_FLOOR)
						and (isConAI or conSpacingOk)
						and (
							isConAI
							or math.random(0, 5) == 0
							or supplyUsed > supplyMax * 0.85
							or econPressure > 0.4
							-- a rich reclaim field near home is worth extra hands
							or recNear >= STOR.REC.RICH )

				if wantConstructor then
					success = TryBuild(constructors, function(p)
						local x, y, z = Spring.GetUnitPosition(unitID)
						Spring.GiveOrderToUnit(unitID, -p, { x, y, z, 0 }, 0)
					end)
					if success then SimpleLastConStart[unitTeam] = nowFrame end
				end
				if not success then
					success = TryBuildWeighted(combats, function(p)
						local x, y, z = Spring.GetUnitPosition(unitID)
						Spring.GiveOrderToUnit(unitID, -p, { x, y, z, 0 }, 0)
					end)
				end
			else
				success = true
			end
		end

		-- Storage was wanted and this builder could have built it, but a
		-- higher rung took the builder instead. Say which signals were live.
		if STOR.DEBUG and storagePick and STOR.pending[unitTeam] ~= nowFrame
				and nowFrame >= (STOR.dbgAt[unitTeam] or 0) then
			STOR.dbgAt[unitTeam] = nowFrame + 900
			Spring.Echo(("[SimpleAI] storage: team %d tech %d wants %s but a higher rung took the builder"
				.. " (E %d/%d pool, E income %d, econPressure %.2f, supply %d/%d +%d on order, underAttack %s)"):format(
				unitTeam, techLevel, UnitDefs[storagePick].name,
				ecurrent, epool, eincome, econPressure,
				supplyUsed, supplyMax, supplyOrdered, tostring(SimpleUnderAttack[unitTeam] and true or false)))
		end

		-- Decision trace: count which rung took this unit, per team. The core
		-- publishes the tallies every 10s for the game recorder widget
		-- (dbg_game_recorder.lua). Keys: rung label, "C." prefix for the
		-- commander, "F" for a factory queue pick, "!" suffix when the rung
		-- was chosen but could not issue an order.
		-- Herd control: this unit now works for a capped need.
		local need = success and JOB.RUNG[rung]
		if need and jobs then
			jobs[unitID] = need
			active[need] = active[need] + 1
		end

		local tally = STOR.trace[unitTeam]
		if tally then
			-- "P2.cap": energy was wanted but enough builders were already on it
			if energyWanted and not genRoom and buildType ~= "Factory" then
				tally["P2.cap"] = (tally["P2.cap"] or 0) + 1
			end
			local key = rung
			if buildType == "Commander" then key = "C." .. key end
			if not success then key = key .. "!" end
			tally[key] = (tally[key] or 0) + 1
			if STOR.boOk   > 0 then tally["bo"]  = (tally["bo"]  or 0) + STOR.boOk   end
			if STOR.boFail > 0 then tally["bo!"] = (tally["bo!"] or 0) + STOR.boFail end
			if STOR.geoOk   > 0 then tally["geo"]  = (tally["geo"]  or 0) + STOR.geoOk   end
			if STOR.geoFail > 0 then   -- geo!.none / geo!.far / geo!.taken
				local key = "geo!." .. (STOR.geoWhy or "far")
				tally[key] = (tally[key] or 0) + STOR.geoFail
			end
		end
		STOR.boOk, STOR.boFail, STOR.geoOk, STOR.geoFail = 0, 0, 0, 0

		return success
	end

	-- Shared service: the commander behavior builds through this too.
	services.SelectConstructionProject = SimpleConstructionProjectSelection

	--------------------------------------------------------------------------
	-- Storage and supply bookkeeping hooks. A finished storage (or one given to the
	-- team) releases the one-at-a-time lock; so does losing one, since the
	-- casualty may be the nanoframe the lock was waiting on.
	--------------------------------------------------------------------------
	-- A supply depot that finishes or dies comes off the on-order tally the
	-- same way (the real supplyMax has it from here, or it never will).
	local function SupplySettled(unitTeam, unitDefID)
		local g = SUP.grant[unitDefID]
		if g and (SUP.ordered[unitTeam] or 0) > 0 then
			SUP.ordered[unitTeam] = math.max(0, SUP.ordered[unitTeam] - g)
			SUP.stamp[unitTeam]   = Spring.GetGameFrame()
		end
	end

	-- Herd control recount (see JOB): a builder still counts toward its need
	-- only while the order at the head of its queue is a build order. Idle,
	-- dead, fleeing or reclaiming builders drop out here.
	function B.TeamTick(tick)
		local teamID = tick.teamID
		local jobs, active = JOB.of[teamID], JOB.active[teamID]
		if not jobs then return end
		active.gen, active.tur, active.rec = 0, 0, 0
		for unitID, need in pairs(jobs) do
			local queue = Spring.GetCommandQueue(unitID, 1)
			local head  = queue and queue[1]
			-- a reclaimer counts while it is reclaiming; everyone else while
			-- the order at the head of the queue is a build order
			local busy
			if need == "rec" then busy = head and head.id == CMD.RECLAIM
			else busy = head and head.id < 0 end
			if busy then
				active[need] = active[need] + 1
			else
				jobs[unitID] = nil
			end
		end

		-- Reclaim field: one scan serves every team; each team then sizes its
		-- crew from what lies within reach of its home.
		if tick.frame and (tick.frame - REC.lastScan) >= REC.SCAN then
			ReclaimScan(tick.frame)
		end
		ReclaimTeamUpdate(teamID, SimpleConstructorCount[teamID])
	end

	function B.UnitFinished(unitID, unitDefID, unitTeam)
		if STOR.cap[unitDefID] then STOR.pending[unitTeam] = nil end
		SupplySettled(unitTeam, unitDefID)
	end

	function B.UnitLost(unitTeam, unitID, unitDefID)
		SAFE.fleeAt[unitID] = nil
		if STOR.cap[unitDefID] then STOR.pending[unitTeam] = nil end
		SupplySettled(unitTeam, unitDefID)
	end

	--------------------------------------------------------------------------
	-- Ownership: constructors and factories.
	--------------------------------------------------------------------------
	function B.unitFilter(unitDefID)
		return IsConstructor[unitDefID] == true or IsFactory[unitDefID] == true
	end

	--------------------------------------------------------------------------
	-- Per-unit orders for constructors and factories.
	--------------------------------------------------------------------------
	function B.UnitTick(tick, unitID, unitDefID, hpRatio, ux, uy, uz, unitCmds)
		local teamID     = tick.teamID
		local allyTeamID = tick.allyTeamID
		local units      = tick.units
		local allunits   = tick.allUnits

		-- ======== CONSTRUCTORS ========
		if IsConstructor[unitDefID] then

			-- Enemy contact. A healthy builder used to answer ANY enemy within
			-- 600 elmos by walking up to reclaim it, armed or not, which is
			-- how most builders died (recordings: nearly every engineer built
			-- was lost, most of them far from home). Now:
			--   armed enemy near   -> run for home, and keep running
			--   unarmed enemy near -> reclaim it (free metal), if healthy
			local nearEnemy  = Spring.GetUnitNearestEnemy(unitID, SAFE.ALERT, true)
			local enemyArmed = false
			if nearEnemy then
				local eud = UnitDefs[Spring.GetUnitDefID(nearEnemy) or 0]
				enemyArmed = (eud and eud.weapons and #eud.weapons > 0) and true or false
			end

			if nearEnemy and (enemyArmed or hpRatio <= 0.85) then
				-- Run. Home if we know it and are not already there, else
				-- straight away from the enemy. Re-issued at most every
				-- SAFE.FLEE_REISSUE frames so the builder commits to a path
				-- instead of re-rolling a destination every tick.
				local now = tick.frame or 0
				if now >= (SAFE.fleeAt[unitID] or 0) then
					SAFE.fleeAt[unitID] = now + SAFE.FLEE_REISSUE
					local home = FWD.home[teamID]
					if not home then
						local hx, _, hz = Spring.GetTeamStartPosition(teamID)
						if hx and hx >= 0 then home = { x = hx, z = hz }; FWD.home[teamID] = home end
					end
					local tx, tz
					if home and ((home.x - ux) ^ 2 + (home.z - uz) ^ 2) > 600 * 600 then
						tx, tz = home.x, home.z
					else
						local ex, _, ez = Spring.GetUnitPosition(nearEnemy)
						local dx, dz = ux - (ex or ux), uz - (ez or uz)
						local d = math.sqrt(dx * dx + dz * dz)
						if d < 1 then dx, dz, d = 1, 0, 1 end
						tx = math.max(128, math.min(mapsizeX - 128, ux + dx / d * 900))
						tz = math.max(128, math.min(mapsizeZ - 128, uz + dz / d * 900))
					end
					Spring.GiveOrderToUnit(unitID, CMD.MOVE, { tx, Spring.GetGroundHeight(tx, tz), tz }, 0)
				end

			elseif nearEnemy then
				-- unarmed and we are healthy: take it apart
				Spring.GiveOrderToUnit(unitID, CMD.RECLAIM, { nearEnemy }, 0)

			elseif unitCmds == 0 then
				-- Check if we are very close to a factory (within its footprint).
				-- If so, walk away first before trying to build anything,
				-- otherwise SimpleBuildOrder will always fail.
				local tooClose = false
				for fi = 1, #units do
					local candidate = units[fi]
					if candidate ~= unitID then
						local cDefID = Spring.GetUnitDefID(candidate)
						if cDefID and IsFactory[cDefID] then
							local fx, _, fz = Spring.GetUnitPosition(candidate)
							local fdx, fdz = ux - fx, uz - fz
							local ffoot = math.max(
									UnitDefs[cDefID].xsize,
									UnitDefs[cDefID].zsize) * 8 + 200
							if fdx * fdx + fdz * fdz < ffoot * ffoot then
								tooClose = true
								-- Walk in a random direction away from the factory
								local angle = math.random() * 6.28
								local dist  = ffoot + math.random(200, 500)
								local wx = fx + math.cos(angle) * dist
								local wz = fz + math.sin(angle) * dist
								wx = math.max(256, math.min(mapsizeX - 256, wx))
								wz = math.max(256, math.min(mapsizeZ - 256, wz))
								local wy = Spring.GetGroundHeight(wx, wz)
								Spring.GiveOrderToUnit(unitID, CMD.MOVE, { wx, wy, wz }, 0)
								break
							end
						end
					end
				end

				if not tooClose then
					SimpleConstructionProjectSelection(
							unitID, unitDefID, teamID, allyTeamID,
							units, allunits, "Builder")
				end
			end

			-- ======== FACTORIES ========
		else
			if unitCmds == 0 then
				SimpleConstructionProjectSelection(
						unitID, unitDefID, teamID, allyTeamID,
						units, allunits, "Factory")
			end
		end
	end

	return B
end
