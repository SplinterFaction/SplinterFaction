--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    luarules/configs/simpleai/behaviors/b_adaptive.lua
--  brief:   AdaptiveAI difficulty controller (order 5 -- runs before every
--           other behavior). For teams the core marked ctx.adaptiveTeams,
--           this module measures how the game is going for the OPPOSITION
--           (army value, kill/loss exchange, economy, base pressure), blends
--           that into a "player dominance" estimate, and steers a difficulty
--           scalar D in [0,1] toward a target of "close game, slight player
--           edge". D is mapped onto a knob table other behaviors consume:
--
--             tick.knobs                    (set every team tick; nil for
--                                            plain SimpleAI teams -> stock)
--             services.GetKnobs(teamID)     (same table, for call sites that
--                                            have no tick, e.g. the shared
--                                            construction selector)
--
--           Knob semantics: D = 0.5 reproduces STOCK SimpleAI values exactly
--           (every knob is a three-anchor lerp low/stock/high), so mid
--           difficulty IS today's SimpleAI. Below 0.5 the AI paces slower,
--           launches smaller sloppier waves, aims at the enemy centroid
--           instead of weak points, lets wounded units fight on, never
--           boosts, and builds slower. Above 0.5 all of that sharpens, and
--           its factories/constructors physically build faster via
--           Spring.SetUnitBuildSpeed.
--
--           The controller is deliberately conservative:
--             * 4-minute warmup before D moves at all (no signal yet)
--             * EMA smoothing + a deadband so it does not twitch
--             * per-update step clamps, ASYMMETRIC: it backs off (eases)
--               twice as fast as it ramps up. Rubber-banding that rescues a
--               losing player is forgivable; punishing a winning one is not.
--
--           Owns ctx state: none (all controller state is module-local;
--           the only shared surfaces are tick.knobs / services.GetKnobs).
--           Reads: ctx.adaptiveTeams (written by the core at detection),
--                  ctx.IsCombat / IsFactory / IsConstructor / IsCommander,
--                  tick.allUnits / tick.mInc / tick.units.
--           Hooks consumed from the core: TeamInit, TeamTick, BaseDamaged,
--                  UnitLost, UnitKilled, UnitFinished.
--
--           Debug: publishes game rules params per adaptive team --
--             adaptiveai_d_<teamID>    current difficulty (0..1)
--             adaptiveai_dom_<teamID>  smoothed player-dominance (-1..1)
--
--  usage:   VFS.Include(path)(ctx, lib, cfg, services) -> handler table
--
--  license: GNU GPL, v2 or later
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return function(ctx, lib, cfg, services)

	--------------------------------------------------------------------------
	-- Tunables (owned by this behavior)
	--------------------------------------------------------------------------
	-- Controller cadence / dynamics
	local UPDATE_INTERVAL = 900    -- frames between controller updates (~30s)
	local WARMUP_FRAMES   = 7200   -- no D movement before this (~4 min): too little signal
	local TARGET_DOM      = 0.10   -- aim for the player being SLIGHTLY ahead (~55-60% win feel)
	local DEADBAND        = 0.08   -- |dominance - target| inside this -> no step at all
	local GAIN            = 0.15   -- step per unit of error beyond the deadband
	local MAX_STEP_UP     = 0.035  -- max D increase per update (harder)...
	local MAX_STEP_DOWN   = 0.07   -- ...but it EASES twice as fast (see brief)
	local EMA_KEEP        = 0.6    -- dominance smoothing: new = old*KEEP + raw*(1-KEEP)

	-- Signal weights (must sum to 1). Army value dominates because it is the
	-- most direct "who is winning" reading; exchange captures skill even when
	-- totals are close; economy leads army by a couple of minutes; pressure
	-- (our base taking hits) is the lagging confirmation.
	local W_ARMY  = 0.40
	local W_EXCH  = 0.25
	local W_ECO   = 0.20
	local W_PRESS = 0.15

	-- Exchange accumulators decay each update (~3.3 min half-life at 0.90),
	-- so an early slaughter stops steering D fifteen minutes later.
	local EXCH_DECAY      = 0.90
	local PRESSURE_MEMORY = 1800   -- frames a base hit keeps the pressure signal warm (~60s)

	-- Build-speed application is quantized so we only sweep the team's units
	-- when the multiplier moves a real step, not on every controller nudge.
	local BS_QUANT = 0.05

	-- Starting difficulty; optionally overridden by the adaptiveai_start
	-- modoption (a number 0..1). 0.5 == stock SimpleAI strength.
	local D_START = 0.5
	do
		local mo = Spring.GetModOptions and Spring.GetModOptions()
		local v  = mo and tonumber(mo.adaptiveai_start)
		if v then D_START = math.max(0, math.min(1, v)) end
	end

	--------------------------------------------------------------------------
	-- Shared state / config
	--------------------------------------------------------------------------
	local gaiaTeamID    = cfg.gaiaTeamID

	local AdaptiveTeams = ctx.adaptiveTeams
	local IsCombat      = ctx.IsCombat
	local IsFactory     = ctx.IsFactory
	local IsConstructor = ctx.IsConstructor
	local IsCommander   = ctx.IsCommander

	--------------------------------------------------------------------------
	-- Module-local controller state (all keyed by teamID unless noted)
	--------------------------------------------------------------------------
	local D           = {}   -- difficulty scalar in [0,1]
	local dom         = {}   -- EMA-smoothed player dominance in [-1,1]
	local knobs       = {}   -- derived knob table (mutated in place; consumers may cache it)
	local lastUpdate  = {}   -- frame of last controller update
	local killedVal   = {}   -- decayed metal value of enemy units this team destroyed
	local lostVal     = {}   -- decayed metal value of own units lost to enemies
	local lastBaseHit = {}   -- frame an enemy last damaged one of our buildings
	local appliedBS   = {}   -- quantized build-speed multiplier currently applied (1.0 = untouched)
	local enemySet    = {}   -- [teamID] = { [enemyTeamID]=true }; teams are fixed at game start
	local baseSpeed   = {}   -- [defID] = stock UnitDef buildSpeed (lazy cache)
	local metalCost   = {}   -- [defID] = stock UnitDef metalCost  (lazy cache)

	--------------------------------------------------------------------------
	-- Small helpers
	--------------------------------------------------------------------------
	local function Clamp01(v)
		if v < 0 then return 0 elseif v > 1 then return 1 end
		return v
	end

	-- Three-anchor lerp: d=0 -> lo, d=0.5 -> mid, d=1 -> hi. Anchoring the
	-- midpoint at each knob's STOCK value is what makes D=0.5 exactly today's
	-- SimpleAI -- keep that property when retuning: change lo/hi, not mid.
	local function Tri(lo, mid, hi, d)
		if d <= 0.5 then
			return lo + (mid - lo) * (d * 2)
		end
		return mid + (hi - mid) * ((d - 0.5) * 2)
	end

	local function Round(v)
		return math.floor(v + 0.5)
	end

	local function MetalCost(defID)
		local c = metalCost[defID]
		if c == nil then
			local ud = UnitDefs[defID]
			c = (ud and ud.metalCost) or 1
			metalCost[defID] = c
		end
		return c
	end

	local function BaseSpeed(defID)
		local s = baseSpeed[defID]
		if s == nil then
			local ud = UnitDefs[defID]
			s = (ud and ud.buildSpeed) or 0
			baseSpeed[defID] = s
		end
		return s
	end

	local function IsBuilderDef(defID)
		return IsFactory[defID] or IsConstructor[defID] or IsCommander[defID]
	end

	-- Enemy team set, built once per team on first use (team lists are fixed
	-- for the whole game in Recoil, so no refresh is needed).
	local function EnemySet(teamID)
		local set = enemySet[teamID]
		if set then return set end
		set = {}
		local all = Spring.GetTeamList()
		for i = 1, #all do
			local t = all[i]
			if t ~= teamID and t ~= gaiaTeamID
					and not Spring.AreTeamsAllied(teamID, t) then
				set[t] = true
			end
		end
		enemySet[teamID] = set
		return set
	end

	--------------------------------------------------------------------------
	-- Knob derivation. Every knob's MID anchor is the stock SimpleAI value
	-- from the owning behavior -- keep these in sync if those constants move:
	--   b_combat:       WAVE_COOLDOWN 1500, WAVE_MUSTER_SIZE 4,
	--                   WAVE_BIG_ARMY 9, ATTACK_RETARGET 300, RETREAT_ENTER 0.50
	--   b_construction: pacing multiplier (CON_BUILD_SPACING / FACTORY_SPACING*)
	--   b_economy:      boost allowed
	--   b_upgrades:     UPGRADE_COOLDOWN multiplier
	--------------------------------------------------------------------------
	local function RecomputeKnobs(teamID)
		local d = D[teamID]
		local k = knobs[teamID]
		k.buildSpeedMult   = Tri(0.65, 1.0, 1.35, d)   -- SetUnitBuildSpeed on builders
		k.waveCooldown     = Round(Tri(2700, 1500, 1000, d))
		k.musterSize       = Round(Tri(2, 4, 7, d))
		k.bigArmy          = Round(Tri(5, 9, 15, d))
		k.retargetInterval = Round(Tri(600, 300, 240, d))
		k.weakTargeting    = d >= 0.35                 -- below: dumb centroid attacks
		k.retreatEnter     = Tri(0.20, 0.50, 0.55, d)  -- low D units fight nearly to death
		k.pacingMult       = Tri(1.6, 1.0, 0.75, d)    -- constructor/factory start spacing
		k.boostAllowed     = d >= 0.40                 -- low D never spends RP on boosts
		k.upgradeCdMult    = Tri(3.0, 1.0, 0.7, d)     -- weapons/armor purchase cadence
	end

	local function PublishDebug(teamID)
		Spring.SetGameRulesParam("adaptiveai_d_" .. teamID,
		                         Round(D[teamID] * 1000) / 1000)
		Spring.SetGameRulesParam("adaptiveai_dom_" .. teamID,
		                         Round((dom[teamID] or 0) * 1000) / 1000)
	end

	--------------------------------------------------------------------------
	-- Build-speed application
	--------------------------------------------------------------------------
	local function ApplySpeed(unitID, unitDefID, mult)
		if IsBuilderDef(unitDefID) then
			local bs = BaseSpeed(unitDefID)
			if bs > 0 then
				Spring.SetUnitBuildSpeed(unitID, bs * mult)
			end
		end
	end

	local B = { name = "adaptive", order = 5 }

	function B.TeamInit(teamID)
		if not AdaptiveTeams[teamID] then return end
		D[teamID]           = D_START
		dom[teamID]         = TARGET_DOM   -- start AT target: no phantom step after warmup
		knobs[teamID]       = {}
		lastUpdate[teamID]  = 0
		killedVal[teamID]   = 0
		lostVal[teamID]     = 0
		lastBaseHit[teamID] = nil
		appliedBS[teamID]   = 1.0          -- 1.0 == "no unit has been touched yet"
		RecomputeKnobs(teamID)
		PublishDebug(teamID)
	end

	-- Shared service: knob access for call sites that have no tick in hand
	-- (b_construction's shared selector). Returns nil for non-adaptive teams,
	-- which every consumer treats as "use stock values".
	services.GetKnobs = function(teamID)
		return knobs[teamID]
	end

	--------------------------------------------------------------------------
	-- Per-team tick. ALWAYS stamps tick.knobs (nil for non-adaptive teams) --
	-- tick is a shared table reused across teams, so skipping the stamp would
	-- leak the previous team's knobs into this one.
	--------------------------------------------------------------------------
	function B.TeamTick(tick)
		local teamID = tick.teamID
		local k      = knobs[teamID]
		tick.knobs   = k
		if not k then return end

		local n = tick.frame

		-- ---- Build-speed sweep on band change ----
		-- Quantize so we only touch units when the multiplier moved a real
		-- step. New builders finished between sweeps are caught by the
		-- UnitFinished hook below.
		local q = Round(k.buildSpeedMult / BS_QUANT) * BS_QUANT
		if q ~= appliedBS[teamID] then
			local units = tick.units
			for i = 1, #units do
				local uid    = units[i]
				local uDefID = Spring.GetUnitDefID(uid)
				if uDefID then
					ApplySpeed(uid, uDefID, q)
				end
			end
			appliedBS[teamID] = q
		end

		-- ---- Controller update, every UPDATE_INTERVAL frames ----
		if (n - (lastUpdate[teamID] or 0)) < UPDATE_INTERVAL then return end
		lastUpdate[teamID] = n

		-- Decay the exchange accumulators BEFORE reading them, so old
		-- slaughters fade at a fixed rate regardless of new activity.
		killedVal[teamID] = killedVal[teamID] * EXCH_DECAY
		lostVal[teamID]   = lostVal[teamID]   * EXCH_DECAY

		-- ---- Signal 1: fielded army value, ours vs all enemies ----
		-- tick.allUnits is the core's once-per-tick snapshot; classification
		-- and cost caches are defID-keyed so enemy units are covered too.
		local eset     = EnemySet(teamID)
		local aV, eV   = 0, 0
		local allunits = tick.allUnits
		for i = 1, #allunits do
			local uid = allunits[i]
			local ut  = Spring.GetUnitTeam(uid)
			if ut == teamID or eset[ut] then
				local dID = Spring.GetUnitDefID(uid)
				if dID and IsCombat[dID] then
					local c = MetalCost(dID)
					if ut == teamID then aV = aV + c else eV = eV + c end
				end
			end
		end
		local armyS = 0
		if aV + eV > 0 then armyS = (eV - aV) / (eV + aV) end

		-- ---- Signal 2: kill/loss value exchange ----
		local kd, ls = killedVal[teamID], lostVal[teamID]
		local exchS  = 0
		if kd + ls > 50 then   -- ignore noise until real value has traded
			exchS = (ls - kd) / (ls + kd)
		end

		-- ---- Signal 3: metal income, ours vs all enemies summed ----
		-- The resource FLOOR (core) tops up STOCK, not income, so this stays
		-- a true reading of production on both sides.
		local aI = tick.mInc or 0
		local eI = 0
		for t in pairs(eset) do
			local _, _, _, inc = Spring.GetTeamResources(t, "metal")
			eI = eI + (inc or 0)
		end
		local ecoS = 0
		if aI + eI > 0 then ecoS = (eI - aI) / (eI + aI) end

		-- ---- Signal 4: pressure on our base ----
		local pressS = 0
		local hit = lastBaseHit[teamID]
		if hit then
			pressS = Clamp01(1 - (n - hit) / PRESSURE_MEMORY)
		end

		-- ---- Blend + smooth ----
		local raw = W_ARMY * armyS + W_EXCH * exchS + W_ECO * ecoS + W_PRESS * pressS
		dom[teamID] = dom[teamID] * EMA_KEEP + raw * (1 - EMA_KEEP)

		-- ---- Steer D (after warmup) ----
		if n >= WARMUP_FRAMES then
			local err  = dom[teamID] - TARGET_DOM
			local step = 0
			if err > DEADBAND then
				-- Player more dominant than target: get harder, slowly.
				step = math.min(MAX_STEP_UP, (err - DEADBAND) * GAIN)
			elseif err < -DEADBAND then
				-- Player behind target: ease off, twice as fast.
				step = math.max(-MAX_STEP_DOWN, (err + DEADBAND) * GAIN * 2)
			end
			if step ~= 0 then
				D[teamID] = Clamp01(D[teamID] + step)
				RecomputeKnobs(teamID)
			end
		end

		PublishDebug(teamID)
	end

	--------------------------------------------------------------------------
	-- Event hooks (dispatched by the core)
	--------------------------------------------------------------------------
	-- One of OUR units died to an enemy -> loss value. Weighted by build
	-- progress so a sniped nano-frame is a small loss, not a full one.
	function B.UnitLost(teamID, unitID, unitDefID)
		if not knobs[teamID] then return end
		local _, _, _, _, bp = Spring.GetUnitHealth(unitID)
		lostVal[teamID] = lostVal[teamID] + MetalCost(unitDefID) * (bp or 1)
	end

	-- We destroyed an enemy unit -> kill value, same progress weighting.
	function B.UnitKilled(teamID, unitID, unitDefID)
		if not knobs[teamID] then return end
		local _, _, _, _, bp = Spring.GetUnitHealth(unitID)
		killedVal[teamID] = killedVal[teamID] + MetalCost(unitDefID) * (bp or 1)
	end

	-- An enemy damaged one of our buildings (same event b_combat fast-tracks
	-- waves on): warm the pressure signal.
	function B.BaseDamaged(teamID, frame)
		if not knobs[teamID] then return end
		lastBaseHit[teamID] = frame
	end

	-- A unit of ours finished (or was given to us): if the team's build-speed
	-- band is off stock, stamp new builders immediately so they don't run at
	-- base speed until the next band change.
	function B.UnitFinished(unitID, unitDefID, teamID)
		local k = knobs[teamID]
		if not k then return end
		local q = appliedBS[teamID]
		if q and q ~= 1.0 then
			ApplySpeed(unitID, unitDefID, q)
		end
	end

	return B
end
